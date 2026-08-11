#!/usr/bin/env python3
"""
reorder_translations.py
=======================

Setzt `translation.sort_order` einer bestehenden `bible.sqlite` auf die
Reihenfolge, die `TRANSLATION_ORDER` in `quotepas_to_sqlite.py` vorgibt.

Wozu: `sort_order` bestimmt, in welcher Reihenfolge die App die Uebersetzungen
anbietet — und damit auch die Vorgabe, denn beim allerersten Start waehlt sie
die erste Uebersetzung der Anzeigesprache. Der Konverter erzeugt die Datenbank
seit derselben Aenderung gleich in dieser Reihenfolge; dieses Skript bringt
eine bereits erzeugte Datei auf denselben Stand, ohne sie neu zu bauen.

Warum nur `sort_order`: `translation.id`, `first_verse_id`/`last_verse_id` und
die 300'000 Zeilen in `verse` bleiben unberuehrt. Sie sind Schluessel, keine
Reihenfolge — sie umzunummerieren wuerde die Datenbank stundenlang umschreiben
und `test_fixtures.json` entwerten. `id` und `sort_order` koennen danach
auseinanderlaufen; die App liest ausschliesslich `ORDER BY sort_order`.

Aufruf (Projektwurzel):
    python3 tools/reorder_translations.py "Watch Bible Watch App/Resources/bible.sqlite"
    python3 tools/reorder_translations.py … --check     # nur pruefen

Nur Standardbibliothek, keine Abhaengigkeiten.
"""

from __future__ import annotations

import argparse
import os
import sqlite3
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from quotepas_to_sqlite import TRANSLATION_ORDER  # noqa: E402


def gewuenschte_reihenfolge(codes: list[str]) -> list[str]:
    """Bekannte Codes nach TRANSLATION_ORDER, unbekannte stabil dahinter."""
    return sorted(codes, key=lambda c: TRANSLATION_ORDER.index(c)
                  if c in TRANSLATION_ORDER else len(TRANSLATION_ORDER))


def zustand(con: sqlite3.Connection) -> tuple[list[str], list[str]]:
    ist = [r[0] for r in con.execute(
        "SELECT code FROM translation ORDER BY sort_order")]
    return ist, gewuenschte_reihenfolge(ist)


def zeige(con: sqlite3.Connection) -> None:
    for pos, code, name, sprache in con.execute(
            "SELECT sort_order, code, name, language FROM translation"
            " ORDER BY sort_order"):
        con2 = con.execute(
            "SELECT MIN(sort_order) FROM translation WHERE language = ?",
            (sprache,)).fetchone()[0]
        marke = "  ← Vorgabe" if con2 == pos else ""
        print(f"  {pos:>2}  {code:<8} {sprache:<8} {name}{marke}")


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
        ist, soll = zustand(con)
        if ist == soll:
            print("Reihenfolge stimmt bereits:")
            zeige(con)
            return 0
        print(f"ist : {', '.join(ist)}")
        print(f"soll: {', '.join(soll)}")
        if args.check:
            return 1

        # In zwei Schritten, weil sort_order eindeutig bleiben soll: erst weit
        # nach hinten schieben, dann auf die Zielwerte setzen.
        versatz = len(soll) + 100
        con.executemany("UPDATE translation SET sort_order = sort_order + ?"
                        " WHERE code = ?", [(versatz, c) for c in soll])
        con.executemany("UPDATE translation SET sort_order = ? WHERE code = ?",
                        [(i + 1, c) for i, c in enumerate(soll)])
        con.commit()

        ist, soll = zustand(con)
        if ist != soll:
            print("Abbruch: Reihenfolge stimmt nach dem Schreiben nicht.")
            return 2
        print("neu geschrieben:")
        zeige(con)
        return 0
    finally:
        con.close()


if __name__ == "__main__":
    raise SystemExit(main())
