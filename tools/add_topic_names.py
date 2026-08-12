#!/usr/bin/env python3
"""
add_topic_names.py
==================

Traegt die Themen des Versregisters in den uebrigen Oberflaechensprachen in eine
bestehende `bible.sqlite` nach: Spalten `topic_en`, `topic_es`, `topic_fr`,
`topic_zh_hant`, `topic_zh_hans` in der Tabelle `curated` und die Schema-Version.

Warum es dieses Skript ueberhaupt gibt: `quotepas_to_sqlite.py` erzeugt die
Datenbank seit denselben Aenderungen mit diesen Spalten — dafuer braucht es aber
alle Quelldateien (quotepas-Datei, OSIS-XML, USFM-Verzeichnisse). Wer die nicht
zur Hand hat, bringt die ausgelieferte Datenbank hiermit auf denselben Stand.
Beide Wege lesen dieselbe Tabelle `TOPIC_NAMES` aus `quotepas_to_sqlite.py` und
liefern Zeichen fuer Zeichen dasselbe Ergebnis. Von Hand wird an der Datenbank
nichts geaendert.

Warum ueberhaupt Spalten und nicht Katalogschluessel: die Themenliste ist
Datenbankinhalt. Sie entsteht in `curated_verses.json` und kommt ueber
`update_curated.py` in die Datenbank; kommt dort ein Thema dazu, muss die App es
ohne Codeaenderung anzeigen — dieselbe Regel wie bei Uebersetzungen und
Buchnamen. Der deutsche Wert in `curated.topic` bleibt der Schluessel.

Aufruf (Projektwurzel):
    python3 tools/add_topic_names.py "Watch Bible Watch App/Resources/bible.sqlite"
    python3 tools/add_topic_names.py … --check      # nur pruefen, nichts schreiben
    python3 tools/add_topic_names.py … --check-zh   # vereinfachte Zeichen pruefen

Nur Standardbibliothek, keine Abhaengigkeiten.
"""

from __future__ import annotations

import argparse
import os
import sqlite3
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from quotepas_to_sqlite import (  # noqa: E402
    SCHEMA_VERSION, TOPIC_NAME_TABLES,
)


def spaltenplan() -> dict[str, dict[str, str]]:
    """Spalte -> Themenstabelle. `topic` (Deutsch) ist der Schluessel und wird
    hier nie angeruehrt."""
    return {f"topic_{k}": t for k, t in TOPIC_NAME_TABLES.items()}


def spalten(con: sqlite3.Connection) -> list[str]:
    return [r[1] for r in con.execute("PRAGMA table_info(curated)")]


def themen(con: sqlite3.Connection) -> list[str]:
    """Die deutschen Themen der Datenbank, in Datenbankreihenfolge."""
    return [r[0] for r in con.execute(
        "SELECT DISTINCT topic FROM curated WHERE topic IS NOT NULL"
        " ORDER BY topic")]


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
        for thema, wert in con.execute(
                f"SELECT DISTINCT topic, {spalte} FROM curated"
                " WHERE topic IS NOT NULL ORDER BY topic"):
            erwartet = tabelle.get(thema)
            if wert != erwartet:
                print(f"{spalte} {thema!r}: {wert!r} statt {erwartet!r}")
                beanstandet += 1

    # Themennamen muessen je Sprache eindeutig sein — zwei Themen mit demselben
    # Namen waeren in der Liste nicht auseinanderzuhalten.
    for spalte in plan:
        doppelt = con.execute(
            f"SELECT {spalte}, COUNT(DISTINCT topic) c FROM curated"
            f" WHERE {spalte} IS NOT NULL GROUP BY {spalte} HAVING c > 1"
        ).fetchall()
        for wert, anzahl in doppelt:
            print(f"{spalte}: {wert!r} steht fuer {anzahl} verschiedene Themen")
            beanstandet += 1

    version = con.execute("PRAGMA user_version").fetchone()[0]
    if version != SCHEMA_VERSION:
        print(f"user_version {version} statt {SCHEMA_VERSION}")
        beanstandet += 1
    return beanstandet


def zeichenabbildung(con: sqlite3.Connection) -> dict[str, str]:
    """Traditionell -> vereinfacht, aus der Datenbank selbst abgeleitet.

    cuv und cuvs enthalten dieselben Verse in beiden Schriften; daraus laesst
    sich die Abbildung gewinnen, ohne OpenCC zu installieren. Gleiches Verfahren
    wie in `add_book_names.py`.
    """
    paare = con.execute("""
        SELECT t.text, s.text FROM verse t
          JOIN translation tt ON tt.id = t.translation_id AND tt.code = 'cuv'
          JOIN translation ts ON ts.code = 'cuvs'
          JOIN verse s ON s.translation_id = ts.id AND s.book_id = t.book_id
                      AND s.chapter = t.chapter AND s.verse = t.verse
    """).fetchall()
    abbildung: dict[str, set[str]] = {}
    for trad, simp in paare:
        if len(trad) != len(simp):
            continue          # unterschiedlich lang: nicht zeichenweise
        for a, b in zip(trad, simp):
            abbildung.setdefault(a, set()).add(b)
    if paare:
        print(f"Zeichenabbildung aus {len(paare)} Versparen abgeleitet")
    return {a: next(iter(b)) for a, b in abbildung.items() if len(b) == 1}


def pruefe_zh(con: sqlite3.Connection) -> int:
    """Vereinfachte Themennamen gegen die traditionellen pruefen."""
    eindeutig = zeichenabbildung(con)
    if not eindeutig:
        print("cuv/cuvs nicht in dieser Datenbank — Pruefung entfaellt")
        return 0

    trad_tab = TOPIC_NAME_TABLES["zh_hant"]
    simp_tab = TOPIC_NAME_TABLES["zh_hans"]
    beanstandet, unbekannt = 0, 0
    for thema, trad in trad_tab.items():
        erwartet = ""
        for zeichen in trad:
            if zeichen not in eindeutig:
                unbekannt += 1
                erwartet = None
                break
            erwartet += eindeutig[zeichen]
        if erwartet is None:
            continue
        if simp_tab[thema] != erwartet:
            print(f"{thema}: {simp_tab[thema]!r} statt {erwartet!r} (aus {trad!r})")
            beanstandet += 1
    if unbekannt:
        print(f"{unbekannt} Themen uebersprungen "
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
                con.execute(f"ALTER TABLE curated ADD COLUMN {spalte} TEXT")
                print(f"Spalte {spalte} angelegt")

        vorhandene_themen = themen(con)
        for spalte, tabelle in plan.items():
            fehlend = [t for t in vorhandene_themen if t not in tabelle]
            if fehlend:
                print(f"Abbruch: {spalte} kennt {', '.join(fehlend)} nicht"
                      " — TOPIC_NAMES in quotepas_to_sqlite.py ergaenzen")
                return 2
            con.executemany(
                f"UPDATE curated SET {spalte} = ? WHERE topic = ?",
                [(tabelle[t], t) for t in vorhandene_themen],
            )
            print(f"{spalte}: {len(vorhandene_themen)} Themen geschrieben")

        con.execute(f"PRAGMA user_version = {SCHEMA_VERSION}")
        con.commit()
        con.execute("ANALYZE")
        con.commit()

        offen = pruefe(con)
        print("in Ordnung" if offen == 0 else f"{offen} Beanstandungen")
        return 0 if offen == 0 else 1
    finally:
        con.close()


if __name__ == "__main__":
    raise SystemExit(main())
