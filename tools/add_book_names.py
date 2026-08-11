#!/usr/bin/env python3
"""
add_book_names.py
=================

Traegt die Buchnamen der Oberflaechensprachen in eine bestehende
`bible.sqlite` nach: Spalten `name_es`, `name_fr`, `name_zh_hant`,
`name_zh_hans` und Schema-Version 2.

Warum es dieses Skript ueberhaupt gibt: `quotepas_to_sqlite.py` erzeugt die
Datenbank seit derselben Aenderung mit diesen Spalten — dafuer braucht es aber
alle Quelldateien (quotepas-Datei, OSIS-XML, USFM-Verzeichnisse). Wer die nicht
zur Hand hat, bringt die ausgelieferte Datenbank hiermit auf denselben Stand.
Beide Wege lesen dieselben Tabellen aus `quotepas_to_sqlite.py` und liefern
Zeichen fuer Zeichen dasselbe Ergebnis. Von Hand wird an der Datenbank nichts
geaendert.

Aufruf (Projektwurzel):
    python3 tools/add_book_names.py "Watch Bible Watch App/Resources/bible.sqlite"
    python3 tools/add_book_names.py … --check     # nur pruefen, nichts schreiben

Nur Standardbibliothek, keine Abhaengigkeiten.
"""

from __future__ import annotations

import argparse
import os
import sqlite3
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from quotepas_to_sqlite import BOOK_NAME_TABLES, SCHEMA_VERSION  # noqa: E402

# Nur die nachgetragenen Spalten; `name_en` steht seit jeher in der Datenbank.
NEUE_SPALTEN = ["name_es", "name_fr", "name_zh_hant", "name_zh_hans"]


def spalten(con: sqlite3.Connection) -> list[str]:
    return [r[1] for r in con.execute("PRAGMA table_info(book)")]


def pruefe(con: sqlite3.Connection) -> int:
    """Meldet, was fehlt. Rueckgabe: Anzahl Beanstandungen."""
    vorhanden = spalten(con)
    fehlend = [s for s in NEUE_SPALTEN if s not in vorhanden]
    if fehlend:
        print(f"Spalten fehlen: {', '.join(fehlend)}")
        return len(fehlend)

    beanstandet = 0
    for spalte, tabelle in (
        (f"name_{k}", t) for k, t in BOOK_NAME_TABLES.items()
    ):
        if spalte not in vorhanden:
            continue
        for code, name in con.execute(f"SELECT code, {spalte} FROM book"):
            erwartet = tabelle.get(code)
            if name != erwartet:
                print(f"{spalte} {code}: {name!r} statt {erwartet!r}")
                beanstandet += 1
    version = con.execute("PRAGMA user_version").fetchone()[0]
    if version != SCHEMA_VERSION:
        print(f"user_version {version} statt {SCHEMA_VERSION}")
        beanstandet += 1
    return beanstandet


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("datenbank")
    parser.add_argument("--check", action="store_true",
                        help="nur pruefen, nichts schreiben")
    args = parser.parse_args()

    if not os.path.exists(args.datenbank):
        print(f"Datei nicht gefunden: {args.datenbank}")
        return 2

    con = sqlite3.connect(args.datenbank)
    try:
        if args.check:
            offen = pruefe(con)
            print("in Ordnung" if offen == 0 else f"{offen} Beanstandungen")
            return 0 if offen == 0 else 1

        vorhanden = spalten(con)
        for spalte in NEUE_SPALTEN:
            if spalte not in vorhanden:
                con.execute(f"ALTER TABLE book ADD COLUMN {spalte} TEXT")
                print(f"Spalte {spalte} angelegt")

        buecher = [r[0] for r in con.execute("SELECT code FROM book")]
        for kennung, tabelle in BOOK_NAME_TABLES.items():
            fehlend = [c for c in buecher if c not in tabelle]
            if fehlend:
                print(f"Abbruch: name_{kennung} kennt {', '.join(fehlend)} nicht")
                return 2
            con.executemany(
                f"UPDATE book SET name_{kennung} = ? WHERE code = ?",
                [(tabelle[c], c) for c in buecher],
            )
            print(f"name_{kennung}: {len(buecher)} Buchnamen geschrieben")

        con.execute(f"PRAGMA user_version = {SCHEMA_VERSION}")
        con.commit()

        offen = pruefe(con)
        print("in Ordnung" if offen == 0 else f"{offen} Beanstandungen")
        return 0 if offen == 0 else 1
    finally:
        con.close()


if __name__ == "__main__":
    raise SystemExit(main())
