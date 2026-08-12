#!/usr/bin/env python3
"""
add_translation.py
==================

Haengt eine Uebersetzung an eine bestehende `bible.sqlite` an, ohne die
vorhandenen neu zu schreiben.

Warum nicht einfach den Konverter neu laufen lassen: der vergibt
`translation.id` nach `TRANSLATION_ORDER`, die ausgelieferte Datenbank hat
ihre ids aber noch aus der urspruenglichen Quellenreihenfolge (KJV traegt
`id` 3 bei `sort_order` 2, siehe README). Ein voller Neulauf wuerde damit die
`verse.id`-Bereiche von KJV und DAR vertauschen — und `test_fixtures.json`
haengt an genau diesen Bereichen. Anhaengen laesst alles Bestehende in Ruhe:
die neue Uebersetzung bekommt die naechste freie `translation.id` und einen
Versblock hinter dem letzten belegten `verse.id`.

Gelesen werden dieselben Quellformate wie im Konverter (OSIS, USFM) ueber
dessen Parser — es gibt keinen zweiten Leser. Die Stammdaten (Sprache,
Copyright-Zeile, Anzeigename, Reihenfolge) kommen aus `tables.py`.

    python3 tools/add_translation.py bible.sqlite --usfm riv=./ita1927 --check
    python3 tools/add_translation.py bible.sqlite --usfm riv=./ita1927

Nur Standardbibliothek.
"""

from __future__ import annotations

import argparse
import os
import sqlite3
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from quotepas_to_sqlite import parse_osis, parse_usfm  # noqa: E402
from tables import (  # noqa: E402
    SCHEMA_VERSION, TRANSLATION_META, TRANSLATION_NAMES, TRANSLATION_ORDER,
)


def buchcodes(con: sqlite3.Connection) -> dict[str, int]:
    return {code: bid for bid, code in con.execute("SELECT id, code FROM book")}


def vorhandene(con: sqlite3.Connection) -> dict[str, int]:
    return {code: tid for tid, code in con.execute(
        "SELECT id, code FROM translation")}


def lies(quelle: tuple[str, str, str], bekannte: set[str]) -> tuple[list, str, str]:
    """(art, code, pfad) -> (Verse, abbrev, name). Parser des Konverters."""
    art, code, pfad = quelle
    leser = parse_usfm if art == "usfm" else parse_osis
    verse, info, hinweise = leser(pfad, code, bekannte)
    for h in hinweise:
        print(f"  Hinweis: {h}")
    abbrev, name = TRANSLATION_NAMES.get(code, (code.upper(), code.upper()))
    return verse, info.get("abbrev", abbrev), info.get("name", name)


def anhaengen(con: sqlite3.Connection, code: str, verse: list,
              abbrev: str, name: str, swiss: bool) -> dict:
    books = buchcodes(con)
    fehlend = sorted({b for _t, b, _c, _v, _x in verse} - set(books))
    if fehlend:
        raise SystemExit(f"Abbruch: unbekannte Buchcodes {', '.join(fehlend)}")

    sprache, copyright_ = TRANSLATION_META.get(code, ("", None))
    if not sprache:
        raise SystemExit(
            f"Abbruch: {code} fehlt in TRANSLATION_META (tables.py). "
            "Ohne Sprache und Copyright-Zeile darf nichts geschrieben werden.")

    # ss-Wandlung nur fuer deutsche Texte — dieselbe Ersetzung wie in
    # build_database() des Konverters.
    if swiss and sprache == "de":
        verse = [(t, b, c, v, x.replace("ß", "ss"))
                 for t, b, c, v, x in verse]

    naechste_id = (con.execute(
        "SELECT COALESCE(MAX(id), 0) FROM translation").fetchone()[0]) + 1
    erste_vers_id = (con.execute(
        "SELECT COALESCE(MAX(id), 0) FROM verse").fetchone()[0]) + 1

    # Kanonreihenfolge der Datenbank, damit der Versblock zusammenhaengend und
    # in derselben Ordnung liegt wie bei den uebrigen Uebersetzungen.
    reihenfolge = {code_: i for i, (code_,) in enumerate(
        con.execute("SELECT code FROM book ORDER BY sort_order"))}
    verse = sorted(verse, key=lambda r: (reihenfolge[r[1]], r[2], r[3]))

    zeilen, kapitel = [], defaultdict(int)
    for i, (_t, b, c, v, x) in enumerate(verse):
        zeilen.append((erste_vers_id + i, naechste_id, books[b], c, v, x))
        kapitel[(books[b], c)] = max(kapitel[(books[b], c)], v)
    letzte_vers_id = erste_vers_id + len(zeilen) - 1

    con.executemany("INSERT INTO verse (id, translation_id, book_id, chapter,"
                    " verse, text) VALUES (?,?,?,?,?,?)", zeilen)
    con.executemany("INSERT INTO chapter_meta (translation_id, book_id,"
                    " chapter, verse_count) VALUES (?,?,?,?)",
                    [(naechste_id, b, c, n) for (b, c), n in kapitel.items()])
    con.execute(
        "INSERT INTO translation (id, code, abbrev, name, language, copyright,"
        " verse_count, first_verse_id, last_verse_id, sort_order)"
        " VALUES (?,?,?,?,?,?,?,?,?,?)",
        (naechste_id, code, abbrev, name, sprache, copyright_, len(zeilen),
         erste_vers_id, letzte_vers_id, naechste_id))
    return {"id": naechste_id, "verse": len(zeilen), "kapitel": len(kapitel),
            "von": erste_vers_id, "bis": letzte_vers_id, "sprache": sprache}


def reihenfolge_setzen(con: sqlite3.Connection) -> None:
    """`sort_order` aller Uebersetzungen aus TRANSLATION_ORDER.

    Aendert **nur** `sort_order` — ids und Versbloecke bleiben unberuehrt.
    Codes, die dort fehlen, haengen sich hinten an, nach id sortiert.
    """
    codes = [c for (c,) in con.execute("SELECT code FROM translation ORDER BY id")]
    bekannt = [c for c in TRANSLATION_ORDER if c in codes]
    rest = [c for c in codes if c not in TRANSLATION_ORDER]
    for i, code in enumerate(bekannt + rest, start=1):
        con.execute("UPDATE translation SET sort_order = ? WHERE code = ?",
                    (i, code))


def bericht(con: sqlite3.Connection) -> None:
    print("\n  id  code       kuerzel  sprache   verse   sort  bereich")
    for row in con.execute(
            "SELECT id, code, abbrev, language, verse_count, sort_order,"
            " first_verse_id, last_verse_id FROM translation ORDER BY sort_order"):
        tid, code, abbrev, lang, n, so, a, b = row
        print(f"  {tid:2d}  {code:10s} {abbrev:8s} {lang:9s} {n:6d}  {so:4d}"
              f"  {a}–{b}")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("datenbank")
    ap.add_argument("--osis", action="append", default=[], metavar="CODE=DATEI")
    ap.add_argument("--usfm", action="append", default=[], metavar="CODE=ORDNER")
    ap.add_argument("--swiss", action="store_true",
                    help="ss statt ß in deutschen Texten (wie im Konverter)")
    ap.add_argument("--check", action="store_true",
                    help="nur pruefen und berichten, nichts schreiben")
    args = ap.parse_args()

    if not os.path.exists(args.datenbank):
        print(f"Datei nicht gefunden: {args.datenbank}")
        return 2

    quellen = ([("osis", *x.split("=", 1)) for x in args.osis]
               + [("usfm", *x.split("=", 1)) for x in args.usfm])
    if not quellen:
        print("Keine Quelle angegeben (--osis oder --usfm).")
        return 2

    con = sqlite3.connect(args.datenbank)
    try:
        da = vorhandene(con)
        bekannte = set(buchcodes(con))
        if args.check:
            print(f"{args.datenbank}: {len(da)} Uebersetzungen, "
                  f"{len(bekannte)} Buecher")
            for art, code, pfad in quellen:
                print(f"  {code}: {'BEREITS VORHANDEN' if code in da else 'neu'}"
                      f" — {art} {pfad}"
                      f"{'' if os.path.exists(pfad) else '  (Pfad fehlt!)'}"
                      f"{'' if code in TRANSLATION_META else '  (nicht in TRANSLATION_META!)'}")
            bericht(con)
            return 0

        for quelle in quellen:
            code = quelle[1]
            if code in da:
                print(f"{code} ist bereits in der Datenbank — uebersprungen.")
                continue
            print(f"{code}: lese {quelle[2]}")
            verse, abbrev, name = lies(quelle, bekannte)
            info = anhaengen(con, code, verse, abbrev, name, args.swiss)
            print(f"  {name} ({abbrev}, {info['sprache']}): {info['verse']} Verse "
                  f"in {info['kapitel']} Kapiteln, id {info['id']}, "
                  f"verse.id {info['von']}–{info['bis']}")

        reihenfolge_setzen(con)
        con.execute("UPDATE meta SET value = ? WHERE key = 'schema_version'",
                    (str(SCHEMA_VERSION),))
        con.execute(f"PRAGMA user_version = {SCHEMA_VERSION}")
        con.commit()
        con.execute("ANALYZE")
        con.commit()
        bericht(con)
        return 0
    finally:
        con.close()


if __name__ == "__main__":
    raise SystemExit(main())
