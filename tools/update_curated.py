#!/usr/bin/env python3
"""
update_curated.py
=================

Traegt das Themenregister aus `curated_verses.json` in eine bestehende
`bible.sqlite` nach: Tabelle `curated` und der Zaehlwert `curated_count` in
`meta`.

Warum es dieses Skript ueberhaupt gibt: `quotepas_to_sqlite.py` fuellt die
Tabelle beim Erzeugen der Datenbank — dafuer braucht es aber alle Quelldateien
(quotepas-Datei, OSIS-XML, USFM-Verzeichnisse). Wer die nicht zur Hand hat,
bringt die ausgelieferte Datenbank hiermit auf denselben Stand. Beide Wege
lesen dieselbe JSON-Datei, pruefen jede Referenz gegen dieselbe Leit-
uebersetzung und vergeben die `id` in derselben Reihenfolge; das Ergebnis ist
Zeile fuer Zeile dasselbe. Von Hand wird an der Datenbank nichts geaendert.

Aufruf (Projektwurzel):
    python3 tools/update_curated.py "Watch Bible Watch App/Resources/bible.sqlite"
    python3 tools/update_curated.py … --check      # nur pruefen, nichts schreiben
    python3 tools/update_curated.py … --json datei.json

Verszaehlung: die Referenzen folgen der Leituebersetzung (`meta.master_-
translation`, zurzeit `elb`). Deutsche und englische Bibeln zaehlen
unterschiedlich — eine Stelle, die hier nicht gefunden wird, ist darum kein
Tippfehler, sondern meist eine Verschiebung um einen Vers. Das Skript meldet
jede solche Stelle und schreibt in dem Fall nichts.

Nur Standardbibliothek, keine Abhaengigkeiten.
"""

from __future__ import annotations

import argparse
import json
import os
import sqlite3
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from quotepas_to_sqlite import TOPIC_NAME_TABLES  # noqa: E402

VORGABE_JSON = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                            "curated_verses.json")


def lies_liste(pfad: str) -> list[dict]:
    with open(pfad, "r", encoding="utf-8") as fh:
        return json.load(fh)["verses"]


def leituebersetzung(con: sqlite3.Connection) -> tuple[int, str]:
    """Id und Code der Uebersetzung, gegen die geprueft wird."""
    zeile = con.execute(
        "SELECT value FROM meta WHERE key = 'master_translation'").fetchone()
    if zeile is None:
        # Aeltere Datenbanken ohne den Eintrag: die erste in Anzeigereihenfolge.
        zeile = con.execute(
            "SELECT code FROM translation ORDER BY sort_order LIMIT 1").fetchone()
    code = zeile[0]
    tid = con.execute("SELECT id FROM translation WHERE code = ?",
                      (code,)).fetchone()
    if tid is None:
        raise SystemExit(f"Leituebersetzung '{code}' fehlt in der Datenbank.")
    return tid[0], code


def pruefe(con: sqlite3.Connection, liste: list[dict]) -> tuple[list, list]:
    """Loest die Referenzen auf. Rueckgabe: (aufgeloest, beanstandet)."""
    tid, code = leituebersetzung(con)
    buecher = {c: i for c, i in con.execute("SELECT code, id FROM book")}
    abfrage = ("SELECT 1 FROM verse WHERE translation_id = ? AND book_id = ?"
               " AND chapter = ? AND verse = ?")

    aufgeloest, beanstandet, gesehen = [], [], set()
    for eintrag in liste:
        bcode, kap, vers = eintrag["book"], eintrag["chapter"], eintrag["verse"]
        stelle = f"{bcode} {kap},{vers}"
        if bcode not in buecher:
            beanstandet.append(f"{stelle}: Buch unbekannt")
            continue
        if (bcode, kap, vers) in gesehen:
            beanstandet.append(f"{stelle}: steht doppelt in der Liste")
            continue
        if con.execute(abfrage, (tid, buecher[bcode], kap, vers)).fetchone() is None:
            beanstandet.append(f"{stelle}: in {code} nicht vorhanden")
            continue
        gesehen.add((bcode, kap, vers))
        aufgeloest.append((buecher[bcode], kap, vers, eintrag.get("topic")))
    return aufgeloest, beanstandet


def schreibe(con: sqlite3.Connection, aufgeloest: list) -> None:
    con.execute("DELETE FROM curated")
    con.executemany(
        "INSERT INTO curated (book_id, chapter, verse, topic) VALUES (?,?,?,?)",
        aufgeloest,
    )
    # Themen in den uebrigen Oberflaechensprachen wieder auffuellen: das DELETE
    # oben nimmt sie mit, und eine Datenbank ohne sie zeigt in der Themenliste
    # ueberall Deutsch. Dieselbe Tabelle wie in add_topic_names.py und im
    # Konverter — es gibt nur eine Quelle.
    spalten = [r[1] for r in con.execute("PRAGMA table_info(curated)")]
    themen = sorted({t for *_, t in aufgeloest if t})
    for kennung, tabelle in TOPIC_NAME_TABLES.items():
        spalte = f"topic_{kennung}"
        if spalte not in spalten:
            continue
        con.executemany(f"UPDATE curated SET {spalte} = ? WHERE topic = ?",
                        [(tabelle.get(t), t) for t in themen])
    fehlend = [t for t in themen if t not in TOPIC_NAME_TABLES["en"]]
    for thema in fehlend:
        print(f"    Thema ohne Uebersetzung (bleibt deutsch): {thema}"
              " — TOPIC_NAMES in quotepas_to_sqlite.py ergaenzen")
    con.execute("INSERT OR REPLACE INTO meta (key, value) VALUES (?,?)",
                ("curated_count", str(len(aufgeloest))))
    con.commit()
    con.execute("ANALYZE")
    con.commit()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("datenbank")
    parser.add_argument("--json", default=VORGABE_JSON,
                        help="Liste der Kernverse (Vorgabe: tools/curated_verses.json)")
    parser.add_argument("--check", action="store_true",
                        help="nur pruefen, nichts schreiben")
    args = parser.parse_args()

    for pfad in (args.datenbank, args.json):
        if not os.path.exists(pfad):
            print(f"Datei nicht gefunden: {pfad}")
            return 2

    liste = lies_liste(args.json)
    con = sqlite3.connect(args.datenbank)
    try:
        _, code = leituebersetzung(con)
        aufgeloest, beanstandet = pruefe(con, liste)
        print(f"Liste           : {len(liste)} Referenzen aus "
              f"{os.path.basename(args.json)}")
        print(f"Leituebersetzung: {code}")
        print(f"Aufgeloest      : {len(aufgeloest)}")
        for meldung in beanstandet:
            print(f"    Beanstandung: {meldung}")
        if beanstandet:
            print("Nichts geschrieben — erst die Beanstandungen klaeren.")
            return 1
        if args.check:
            themen = {t for *_, t in aufgeloest if t}
            print(f"Themen          : {len(themen)}")
            print("in Ordnung")
            return 0

        vorher = con.execute("SELECT COUNT(*) FROM curated").fetchone()[0]
        schreibe(con, aufgeloest)
        themen = con.execute(
            "SELECT COUNT(DISTINCT topic) FROM curated").fetchone()[0]
        print(f"Geschrieben     : {len(aufgeloest)} Verse in {themen} Themen "
              f"(vorher {vorher})")
        return 0
    finally:
        con.close()


if __name__ == "__main__":
    raise SystemExit(main())
