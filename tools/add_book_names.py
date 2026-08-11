#!/usr/bin/env python3
"""
add_book_names.py
=================

Traegt Buchnamen und Buchkuerzel der Oberflaechensprachen in eine bestehende
`bible.sqlite` nach: Spalten `name_es`, `name_fr`, `name_zh_hant`,
`name_zh_hans`, `abbrev_de`, `abbrev_en`, `abbrev_es`, `abbrev_fr`,
`abbrev_zh_hant`, `abbrev_zh_hans` und die Schema-Version.

Warum es dieses Skript ueberhaupt gibt: `quotepas_to_sqlite.py` erzeugt die
Datenbank seit denselben Aenderungen mit diesen Spalten — dafuer braucht es aber
alle Quelldateien (quotepas-Datei, OSIS-XML, USFM-Verzeichnisse). Wer die nicht
zur Hand hat, bringt die ausgelieferte Datenbank hiermit auf denselben Stand.
Beide Wege lesen dieselben Tabellen aus `quotepas_to_sqlite.py` und liefern
Zeichen fuer Zeichen dasselbe Ergebnis. Von Hand wird an der Datenbank nichts
geaendert.

Aufruf (Projektwurzel):
    python3 tools/add_book_names.py "Watch Bible Watch App/Resources/bible.sqlite"
    python3 tools/add_book_names.py … --check      # nur pruefen, nichts schreiben
    python3 tools/add_book_names.py … --check-zh   # vereinfachte Zeichen pruefen

Nur Standardbibliothek, keine Abhaengigkeiten.
"""

from __future__ import annotations

import argparse
import os
import sqlite3
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from quotepas_to_sqlite import (  # noqa: E402
    BOOK_ABBREV_TABLES, BOOK_NAME_TABLES, SCHEMA_VERSION,
)

# Spalte -> Tabelle. `name` (Deutsch) und `name_en` stehen seit jeher in der
# Datenbank und werden hier nicht angeruehrt; alle uebrigen kommen dazu.
def spaltenplan() -> dict[str, dict[str, str]]:
    plan = {f"name_{k}": t for k, t in BOOK_NAME_TABLES.items() if k != "en"}
    plan.update({f"abbrev_{k}": t for k, t in BOOK_ABBREV_TABLES.items()})
    return plan


def spalten(con: sqlite3.Connection) -> list[str]:
    return [r[1] for r in con.execute("PRAGMA table_info(book)")]


def pruefe(con: sqlite3.Connection) -> int:
    """Meldet, was fehlt oder abweicht. Rueckgabe: Anzahl Beanstandungen."""
    vorhanden = spalten(con)
    plan = spaltenplan()
    fehlend = [s for s in plan if s not in vorhanden]
    if fehlend:
        print(f"Spalten fehlen: {', '.join(fehlend)}")
        return len(fehlend)

    beanstandet = 0
    for spalte, tabelle in plan.items():
        for code, wert in con.execute(f"SELECT code, {spalte} FROM book"):
            erwartet = tabelle.get(code)
            if wert != erwartet:
                print(f"{spalte} {code}: {wert!r} statt {erwartet!r}")
                beanstandet += 1

    # Kuerzel muessen je Sprache eindeutig sein — zwei Buecher mit demselben
    # Kuerzel waeren im Register nicht auseinanderzuhalten.
    for spalte in (s for s in plan if s.startswith("abbrev_")):
        doppelt = con.execute(
            f"SELECT {spalte}, COUNT(*) c FROM book GROUP BY {spalte}"
            " HAVING c > 1").fetchall()
        for wert, anzahl in doppelt:
            print(f"{spalte}: {wert!r} kommt {anzahl}× vor")
            beanstandet += 1

    version = con.execute("PRAGMA user_version").fetchone()[0]
    if version != SCHEMA_VERSION:
        print(f"user_version {version} statt {SCHEMA_VERSION}")
        beanstandet += 1
    return beanstandet


def pruefe_zh(con: sqlite3.Connection) -> int:
    """Vereinfachte Zeichen gegen die Datenbank selbst pruefen.

    cuv und cuvs enthalten dieselben Verse in traditioneller und vereinfachter
    Schrift. Daraus laesst sich die Zeichenabbildung ableiten, ohne OpenCC zu
    installieren — und damit pruefen, ob die vereinfachten Namen und Kuerzel
    zur traditionellen Fassung passen.
    """
    paare = con.execute("""
        SELECT t.text, s.text FROM verse t
          JOIN translation tt ON tt.id = t.translation_id AND tt.code = 'cuv'
          JOIN translation ts ON ts.code = 'cuvs'
          JOIN verse s ON s.translation_id = ts.id AND s.book_id = t.book_id
                      AND s.chapter = t.chapter AND s.verse = t.verse
    """).fetchall()
    if not paare:
        print("cuv/cuvs nicht in dieser Datenbank — Pruefung entfaellt")
        return 0

    abbildung: dict[str, set[str]] = {}
    for trad, simp in paare:
        if len(trad) != len(simp):
            continue          # unterschiedlich lang: nicht zeichenweise
        for a, b in zip(trad, simp):
            abbildung.setdefault(a, set()).add(b)
    eindeutig = {a: next(iter(b)) for a, b in abbildung.items() if len(b) == 1}
    print(f"Zeichenabbildung aus {len(paare)} Versparen: "
          f"{len(eindeutig)} eindeutige Zeichen")

    # 3Joh ist die dokumentierte Ausnahme: 參 wird mechanisch zu 参 (wie in
    # 参加), gemeint ist aber die foermliche Ziffer Drei, vereinfacht 叁.
    ausnahmen = {("abbrev", "3Joh")}

    beanstandet, unbekannt = 0, 0
    for art, trad_tab, simp_tab in (
        ("name", BOOK_NAME_TABLES["zh_hant"], BOOK_NAME_TABLES["zh_hans"]),
        ("abbrev", BOOK_ABBREV_TABLES["zh_hant"], BOOK_ABBREV_TABLES["zh_hans"]),
    ):
        for code, trad in trad_tab.items():
            if (art, code) in ausnahmen:
                continue
            erwartet = ""
            for zeichen in trad:
                if zeichen not in eindeutig:
                    unbekannt += 1
                    erwartet = None
                    break
                erwartet += eindeutig[zeichen]
            if erwartet is None:
                continue
            if simp_tab[code] != erwartet:
                print(f"{art} {code}: {simp_tab[code]!r} statt {erwartet!r}"
                      f" (aus {trad!r})")
                beanstandet += 1
    if unbekannt:
        print(f"{unbekannt} Eintraege uebersprungen "
              "(Zeichen kommt im Bibeltext nicht eindeutig vor)")
    return beanstandet


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("datenbank")
    parser.add_argument("--check", action="store_true",
                        help="nur pruefen, nichts schreiben")
    parser.add_argument("--check-zh", action="store_true",
                        help="vereinfachte Zeichen gegen cuv/cuvs pruefen")
    args = parser.parse_args()

    if not os.path.exists(args.datenbank):
        print(f"Datei nicht gefunden: {args.datenbank}")
        return 2

    con = sqlite3.connect(args.datenbank)
    try:
        if args.check_zh:
            offen = pruefe_zh(con)
            print("in Ordnung" if offen == 0 else f"{offen} Beanstandungen")
            return 0 if offen == 0 else 1

        if args.check:
            offen = pruefe(con)
            print("in Ordnung" if offen == 0 else f"{offen} Beanstandungen")
            return 0 if offen == 0 else 1

        vorhanden = spalten(con)
        plan = spaltenplan()
        for spalte in plan:
            if spalte not in vorhanden:
                con.execute(f"ALTER TABLE book ADD COLUMN {spalte} TEXT")
                print(f"Spalte {spalte} angelegt")

        buecher = [r[0] for r in con.execute("SELECT code FROM book")]
        for spalte, tabelle in plan.items():
            fehlend = [c for c in buecher if c not in tabelle]
            if fehlend:
                print(f"Abbruch: {spalte} kennt {', '.join(fehlend)} nicht")
                return 2
            con.executemany(
                f"UPDATE book SET {spalte} = ? WHERE code = ?",
                [(tabelle[c], c) for c in buecher],
            )
            print(f"{spalte}: {len(buecher)} Einträge geschrieben")

        con.execute(f"PRAGMA user_version = {SCHEMA_VERSION}")
        con.commit()

        offen = pruefe(con)
        print("in Ordnung" if offen == 0 else f"{offen} Beanstandungen")
        return 0 if offen == 0 else 1
    finally:
        con.close()


if __name__ == "__main__":
    raise SystemExit(main())
