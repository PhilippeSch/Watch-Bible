#!/usr/bin/env python3
"""
quotepas_to_sqlite.py
=====================

Wandelt die LaTeX-/quotepas-Datenbank mit Bibelversen in eine SQLite-Datei um,
die in der watchOS-App als schreibgeschuetzte Ressource mitgeliefert wird.

Aufbau der Quelldatei (aus dem gelieferten Auszug abgeleitet):

    <quotepas><label>1Mo</label><block>1. Mose</block></quotepas>       -> Buch
    <quotepas><label>shortslt</label><block>SLT</block></quotepas>      -> Uebersetzung (Kuerzel)
    <quotepas><label>longslt</label><block>Schlachter 2000</block></quotepas> -> Uebersetzung (Name)
    <quotepas><label>slt1Mo1v1</label><block>Im Anfang ...</block></quotepas> -> Vers

Verslabel = <uebersetzungscode><buchcode><kapitel>v<vers>.
Weil Buchcodes selber Ziffern enthalten (1Mo, 2Kor, 1Joh), wird nicht blind
per Regex getrennt, sondern gegen die in der Datei deklarierten Buchcodes
gematcht (laengste Uebereinstimmung zuerst).

Aufruf:
    python3 quotepas_to_sqlite.py bibel.db -o bible.sqlite
    python3 quotepas_to_sqlite.py bibel.db -o bible.sqlite --exclude slt
    python3 quotepas_to_sqlite.py bibel.db --dry-run
    python3 quotepas_to_sqlite.py bibel.db -o bible.sqlite --curated curated_verses.json

Nur Standardbibliothek, keine Abhaengigkeiten.
"""

from __future__ import annotations

import argparse
import html
import json
import os
import re
import sqlite3
import sys
import unicodedata
from collections import Counter, defaultdict
from datetime import datetime, timezone

SCHEMA_VERSION = 2
APPLICATION_ID = 0x42494257  # "BIBW"

# ---------------------------------------------------------------------------
# Kanon-Wissen: nur fuer Testament-Zuordnung und englische Namen.
# Die Reihenfolge selbst wird aus der Quelldatei uebernommen.
# ---------------------------------------------------------------------------

NT_CODES = {
    "Mt", "Mk", "Lk", "Joh", "Apg", "Rom", "1Kor", "2Kor", "Gal", "Eph",
    "Phil", "Kol", "1Th", "2Th", "1Tim", "2Tim", "Tit", "Phlm", "Hebr",
    "Jak", "1Pt", "2Pt", "1Joh", "2Joh", "3Joh", "Jud", "Offb",
}

ENGLISH_NAMES = {
    "1Mo": "Genesis", "2Mo": "Exodus", "3Mo": "Leviticus", "4Mo": "Numbers",
    "5Mo": "Deuteronomy", "Jos": "Joshua", "Ri": "Judges", "Rt": "Ruth",
    "1Sam": "1 Samuel", "2Sam": "2 Samuel", "1Kon": "1 Kings", "2Kon": "2 Kings",
    "1Chr": "1 Chronicles", "2Chr": "2 Chronicles", "Esr": "Ezra",
    "Neh": "Nehemiah", "Est": "Esther", "Hi": "Job", "Ps": "Psalms",
    "Spr": "Proverbs", "Pred": "Ecclesiastes", "Hl": "Song of Solomon",
    "Jes": "Isaiah", "Jer": "Jeremiah", "Kla": "Lamentations",
    "Hes": "Ezekiel", "Dan": "Daniel", "Hos": "Hosea", "Joel": "Joel",
    "Am": "Amos", "Ob": "Obadiah", "Jon": "Jonah", "Mi": "Micah",
    "Nah": "Nahum", "Hab": "Habakkuk", "Zeph": "Zephaniah", "Hag": "Haggai",
    "Sach": "Zechariah", "Mal": "Malachi", "Mt": "Matthew", "Mk": "Mark",
    "Lk": "Luke", "Joh": "John", "Apg": "Acts", "Rom": "Romans",
    "1Kor": "1 Corinthians", "2Kor": "2 Corinthians", "Gal": "Galatians",
    "Eph": "Ephesians", "Phil": "Philippians", "Kol": "Colossians",
    "1Th": "1 Thessalonians", "2Th": "2 Thessalonians", "1Tim": "1 Timothy",
    "2Tim": "2 Timothy", "Tit": "Titus", "Phlm": "Philemon",
    "Hebr": "Hebrews", "Jak": "James", "1Pt": "1 Peter", "2Pt": "2 Peter",
    "1Joh": "1 John", "2Joh": "2 John", "3Joh": "3 John", "Jud": "Jude",
    "Offb": "Revelation",
}

# Buchnamen der uebrigen Oberflaechensprachen. Die App zeigt Buchnamen immer
# in ihrer Anzeigesprache, unabhaengig von der gewaehlten Uebersetzung — sie
# gehoeren deshalb in die Datenbank und nicht in den String Catalog.
#
# Wo die Schreibweise schwankt, gilt die der mitgelieferten Uebersetzung
# derselben Sprache; nachgeprueft am Verstext selbst:
#   Spanisch (RVR1909): Ruth, Esther, Nahum, Haggeo — nicht Rut/Ester/Hageo.
#   Franzoesisch (LSG): Habakuk, Ésaïe — nicht Habacuc/Esaïe.

SPANISH_NAMES = {
    "1Mo": "Génesis", "2Mo": "Éxodo", "3Mo": "Levítico", "4Mo": "Números",
    "5Mo": "Deuteronomio", "Jos": "Josué", "Ri": "Jueces", "Rt": "Ruth",
    "1Sam": "1 Samuel", "2Sam": "2 Samuel", "1Kon": "1 Reyes", "2Kon": "2 Reyes",
    "1Chr": "1 Crónicas", "2Chr": "2 Crónicas", "Esr": "Esdras",
    "Neh": "Nehemías", "Est": "Esther", "Hi": "Job", "Ps": "Salmos",
    "Spr": "Proverbios", "Pred": "Eclesiastés", "Hl": "Cantares",
    "Jes": "Isaías", "Jer": "Jeremías", "Kla": "Lamentaciones",
    "Hes": "Ezequiel", "Dan": "Daniel", "Hos": "Oseas", "Joel": "Joel",
    "Am": "Amós", "Ob": "Abdías", "Jon": "Jonás", "Mi": "Miqueas",
    "Nah": "Nahum", "Hab": "Habacuc", "Zeph": "Sofonías", "Hag": "Haggeo",
    "Sach": "Zacarías", "Mal": "Malaquías", "Mt": "Mateo", "Mk": "Marcos",
    "Lk": "Lucas", "Joh": "Juan", "Apg": "Hechos", "Rom": "Romanos",
    "1Kor": "1 Corintios", "2Kor": "2 Corintios", "Gal": "Gálatas",
    "Eph": "Efesios", "Phil": "Filipenses", "Kol": "Colosenses",
    "1Th": "1 Tesalonicenses", "2Th": "2 Tesalonicenses", "1Tim": "1 Timoteo",
    "2Tim": "2 Timoteo", "Tit": "Tito", "Phlm": "Filemón",
    "Hebr": "Hebreos", "Jak": "Santiago", "1Pt": "1 Pedro", "2Pt": "2 Pedro",
    "1Joh": "1 Juan", "2Joh": "2 Juan", "3Joh": "3 Juan", "Jud": "Judas",
    "Offb": "Apocalipsis",
}

FRENCH_NAMES = {
    "1Mo": "Genèse", "2Mo": "Exode", "3Mo": "Lévitique", "4Mo": "Nombres",
    "5Mo": "Deutéronome", "Jos": "Josué", "Ri": "Juges", "Rt": "Ruth",
    "1Sam": "1 Samuel", "2Sam": "2 Samuel", "1Kon": "1 Rois", "2Kon": "2 Rois",
    "1Chr": "1 Chroniques", "2Chr": "2 Chroniques", "Esr": "Esdras",
    "Neh": "Néhémie", "Est": "Esther", "Hi": "Job", "Ps": "Psaumes",
    "Spr": "Proverbes", "Pred": "Ecclésiaste", "Hl": "Cantique des cantiques",
    "Jes": "Ésaïe", "Jer": "Jérémie", "Kla": "Lamentations",
    "Hes": "Ézéchiel", "Dan": "Daniel", "Hos": "Osée", "Joel": "Joël",
    "Am": "Amos", "Ob": "Abdias", "Jon": "Jonas", "Mi": "Michée",
    "Nah": "Nahum", "Hab": "Habakuk", "Zeph": "Sophonie", "Hag": "Aggée",
    "Sach": "Zacharie", "Mal": "Malachie", "Mt": "Matthieu", "Mk": "Marc",
    "Lk": "Luc", "Joh": "Jean", "Apg": "Actes", "Rom": "Romains",
    "1Kor": "1 Corinthiens", "2Kor": "2 Corinthiens", "Gal": "Galates",
    "Eph": "Éphésiens", "Phil": "Philippiens", "Kol": "Colossiens",
    "1Th": "1 Thessaloniciens", "2Th": "2 Thessaloniciens",
    "1Tim": "1 Timothée", "2Tim": "2 Timothée", "Tit": "Tite",
    "Phlm": "Philémon", "Hebr": "Hébreux", "Jak": "Jacques",
    "1Pt": "1 Pierre", "2Pt": "2 Pierre", "1Joh": "1 Jean", "2Joh": "2 Jean",
    "3Joh": "3 Jean", "Jud": "Jude", "Offb": "Apocalypse",
}

# Chinesisch traditionell, Namensgebung des 和合本.
CHINESE_TRAD_NAMES = {
    "1Mo": "創世記", "2Mo": "出埃及記", "3Mo": "利未記", "4Mo": "民數記",
    "5Mo": "申命記", "Jos": "約書亞記", "Ri": "士師記", "Rt": "路得記",
    "1Sam": "撒母耳記上", "2Sam": "撒母耳記下", "1Kon": "列王紀上",
    "2Kon": "列王紀下", "1Chr": "歷代志上", "2Chr": "歷代志下",
    "Esr": "以斯拉記", "Neh": "尼希米記", "Est": "以斯帖記", "Hi": "約伯記",
    "Ps": "詩篇", "Spr": "箴言", "Pred": "傳道書", "Hl": "雅歌",
    "Jes": "以賽亞書", "Jer": "耶利米書", "Kla": "耶利米哀歌",
    "Hes": "以西結書", "Dan": "但以理書", "Hos": "何西阿書", "Joel": "約珥書",
    "Am": "阿摩司書", "Ob": "俄巴底亞書", "Jon": "約拿書", "Mi": "彌迦書",
    "Nah": "那鴻書", "Hab": "哈巴谷書", "Zeph": "西番雅書", "Hag": "哈該書",
    "Sach": "撒迦利亞書", "Mal": "瑪拉基書", "Mt": "馬太福音", "Mk": "馬可福音",
    "Lk": "路加福音", "Joh": "約翰福音", "Apg": "使徒行傳", "Rom": "羅馬書",
    "1Kor": "哥林多前書", "2Kor": "哥林多後書", "Gal": "加拉太書",
    "Eph": "以弗所書", "Phil": "腓立比書", "Kol": "歌羅西書",
    "1Th": "帖撒羅尼迦前書", "2Th": "帖撒羅尼迦後書", "1Tim": "提摩太前書",
    "2Tim": "提摩太後書", "Tit": "提多書", "Phlm": "腓利門書",
    "Hebr": "希伯來書", "Jak": "雅各書", "1Pt": "彼得前書", "2Pt": "彼得後書",
    "1Joh": "約翰一書", "2Joh": "約翰二書", "3Joh": "約翰三書", "Jud": "猶大書",
    "Offb": "啟示錄",
}

# Chinesisch vereinfacht. Geprueft gegen die Zeichenabbildung, die sich aus
# den 31'101 ausgerichteten Verspaaren cuv/cuvs der Datenbank ergibt —
# jedes Zeichen ist im Bibeltext belegt, keine Abweichung.
CHINESE_SIMP_NAMES = {
    "1Mo": "创世记", "2Mo": "出埃及记", "3Mo": "利未记", "4Mo": "民数记",
    "5Mo": "申命记", "Jos": "约书亚记", "Ri": "士师记", "Rt": "路得记",
    "1Sam": "撒母耳记上", "2Sam": "撒母耳记下", "1Kon": "列王纪上",
    "2Kon": "列王纪下", "1Chr": "历代志上", "2Chr": "历代志下",
    "Esr": "以斯拉记", "Neh": "尼希米记", "Est": "以斯帖记", "Hi": "约伯记",
    "Ps": "诗篇", "Spr": "箴言", "Pred": "传道书", "Hl": "雅歌",
    "Jes": "以赛亚书", "Jer": "耶利米书", "Kla": "耶利米哀歌",
    "Hes": "以西结书", "Dan": "但以理书", "Hos": "何西阿书", "Joel": "约珥书",
    "Am": "阿摩司书", "Ob": "俄巴底亚书", "Jon": "约拿书", "Mi": "弥迦书",
    "Nah": "那鸿书", "Hab": "哈巴谷书", "Zeph": "西番雅书", "Hag": "哈该书",
    "Sach": "撒迦利亚书", "Mal": "玛拉基书", "Mt": "马太福音", "Mk": "马可福音",
    "Lk": "路加福音", "Joh": "约翰福音", "Apg": "使徒行传", "Rom": "罗马书",
    "1Kor": "哥林多前书", "2Kor": "哥林多后书", "Gal": "加拉太书",
    "Eph": "以弗所书", "Phil": "腓立比书", "Kol": "歌罗西书",
    "1Th": "帖撒罗尼迦前书", "2Th": "帖撒罗尼迦后书", "1Tim": "提摩太前书",
    "2Tim": "提摩太后书", "Tit": "提多书", "Phlm": "腓利门书",
    "Hebr": "希伯来书", "Jak": "雅各书", "1Pt": "彼得前书", "2Pt": "彼得后书",
    "1Joh": "约翰一书", "2Joh": "约翰二书", "3Joh": "约翰三书", "Jud": "犹大书",
    "Offb": "启示录",
}

# Sprachkennung -> Namenstabelle. Die Spalte heisst name_<kennung mit _>.
BOOK_NAME_TABLES = {
    "en": ENGLISH_NAMES,
    "es": SPANISH_NAMES,
    "fr": FRENCH_NAMES,
    "zh_hant": CHINESE_TRAD_NAMES,
    "zh_hans": CHINESE_SIMP_NAMES,
}

# Sprache und Copyright-Zeile je Uebersetzungscode. Wird in die DB geschrieben
# und in der App im Impressum angezeigt. Bei Bedarf hier ergaenzen.
TRANSLATION_META = {
    "slt": ("de", "Schlachter 2000, \u00a9 2000 Genfer Bibelgesellschaft. "
                  "Verwendung nur mit Genehmigung."),
    "sch1951": ("de", "Schlachter 1951, \u00a9 1951 Genfer Bibelgesellschaft. "
                      "Lizenziert unter Creative Commons Attribution 4.0 "
                      "(CC BY 4.0)."),
    "elb": ("de", "Elberfelder Bibel 1905. Gemeinfrei."),
    "dar": ("en", "Darby Bible (J. N. Darby). Gemeinfrei."),
    "kjv": ("en", "King James Version (1611/1769). "
                  "Gemeinfrei ausserhalb des Vereinigten Koenigreichs."),
    "lut": ("de", "Luther 1912. Gemeinfrei."),
    "meng": ("de", "Menge-Bibel. Gemeinfrei."),
    "bsb": ("en", "Berean Standard Bible (BSB). Gemeinfrei; von den Rechteinhabern "
                  "am 30. April 2023 in die Public Domain entlassen."),
    "cuv":  ("zh-Hant", "\u548c\u5408\u672c Chinese Union Version (1919). "
                        "Gemeinfrei, Schutzfrist abgelaufen."),
    "rvr1909": ("es", "Reina-Valera 1909. Gemeinfrei."),
    "lsg":  ("fr", "Louis Segond 1910. Gemeinfrei."),
    "cuvs": ("zh-Hans", "\u548c\u5408\u672c Chinese Union Version (1919). "
                        "Gemeinfrei, Schutzfrist abgelaufen. Vereinfachte Zeichen "
                        "maschinell aus der traditionellen Ausgabe (OpenCC t2s)."),
}

# Anzeigename je Code, falls die Quelle keinen mitliefert.
TRANSLATION_NAMES = {
    "sch1951": ("SCH", "Schlachter 1951"),
    "lut": ("LUT", "Luther 1912"),
    "meng": ("MENG", "Menge-Bibel"),
    "bsb": ("BSB", "Berean Standard Bible"),
    "cuv":  ("CUV", "\u548c\u5408\u672c\uff08\u7e41\u9ad4\uff09"),
    "rvr1909": ("RVR", "Reina-Valera 1909"),
    "lsg":  ("LSG", "Louis Segond 1910"),
    "cuvs": ("CUVS", "\u548c\u5408\u672c\uff08\u7b80\u4f53\uff09"),
}

# OSIS-Buchkuerzel -> Buchcode der quotepas-Datei.
OSIS_BOOKS = {
    "Gen": "1Mo", "Exod": "2Mo", "Lev": "3Mo", "Num": "4Mo", "Deut": "5Mo",
    "Josh": "Jos", "Judg": "Ri", "Ruth": "Rt", "1Sam": "1Sam", "2Sam": "2Sam",
    "1Kgs": "1Kon", "2Kgs": "2Kon", "1Chr": "1Chr", "2Chr": "2Chr",
    "Ezra": "Esr", "Neh": "Neh", "Esth": "Est", "Job": "Hi", "Ps": "Ps",
    "Prov": "Spr", "Eccl": "Pred", "Song": "Hl", "Isa": "Jes", "Jer": "Jer",
    "Lam": "Kla", "Ezek": "Hes", "Dan": "Dan", "Hos": "Hos", "Joel": "Joel",
    "Amos": "Am", "Obad": "Ob", "Jonah": "Jon", "Mic": "Mi", "Nah": "Nah",
    "Hab": "Hab", "Zeph": "Zeph", "Hag": "Hag", "Zech": "Sach", "Mal": "Mal",
    "Matt": "Mt", "Mark": "Mk", "Luke": "Lk", "John": "Joh", "Acts": "Apg",
    "Rom": "Rom", "1Cor": "1Kor", "2Cor": "2Kor", "Gal": "Gal", "Eph": "Eph",
    "Phil": "Phil", "Col": "Kol", "1Thess": "1Th", "2Thess": "2Th",
    "1Tim": "1Tim", "2Tim": "2Tim", "Titus": "Tit", "Phlm": "Phlm",
    "Heb": "Hebr", "Jas": "Jak", "1Pet": "1Pt", "2Pet": "2Pt",
    "1John": "1Joh", "2John": "2Joh", "3John": "3Joh", "Jude": "Jud",
    "Rev": "Offb",
}

OSIS_VERSE_RE = re.compile(r"<verse[^>]*osisID=['\"]([^'\"]+)['\"][^>]*>(.*?)</verse>",
                           re.DOTALL)
OSIS_TITLE_RE = re.compile(r"<title>(.*?)</title>", re.DOTALL)

# Manche CJK-Module setzen zwischen jedes Schriftzeichen ein Leerzeichen.
# Entfernt werden nur ASCII-Leerzeichen zwischen zwei Nicht-ASCII-Zeichen; das
# ideographische Leerzeichen U+3000 bleibt, weil es im Chinesischen bedeutungs-
# tragend ist (Ehrfurchtsabstand vor 神).
CJK_SPACE_RE = re.compile(r"(?<=[^\x00-\x7F])[ ]+(?=[^\x00-\x7F])")
CJK_CHAR_RE = re.compile(r"[\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]")


def is_cjk(samples: list[str]) -> bool:
    joined = "".join(samples)
    if not joined:
        return False
    return len(CJK_CHAR_RE.findall(joined)) / len(joined) > 0.3


# Nachweisbare Zeichenschaeden einzelner Quelldateien. Jede Korrektur ist
# einzeln aufgefuehrt und wird beim Lauf gemeldet - es wird nichts still
# veraendert. Schluessel: (Uebersetzungscode, Buchcode, Kapitel, Vers).
SOURCE_FIXES = {
    # Das elektronische Modul gibt die Aposiopese in 2Mo 32,32 als ASCII-Punkte
    # wieder; gedruckt steht dort die chinesische Auslassung.
    ("cuv", "2Mo", 32, 32): [("\u3001 ... ... \u4e0d\u7136", "\u2026\u2026\u4e0d\u7136")],
    ("cuvs", "2Mo", 32, 32): [("\u3001 ... ... \u4e0d\u7136", "\u2026\u2026\u4e0d\u7136")],
    # In Jes 1,23 ist ein Schriftzeichen verlorengegangen und durch ein
    # Apostroph ersetzt worden. Gedruckt steht dort 贓私 (unrechter Gewinn).
    ("cuv", "Jes", 1, 23): [("\u8ffd\u6c42 ' \u79c1", "\u8ffd\u6c42\u8d13\u79c1")],
    ("cuvs", "Jes", 1, 23): [("\u8ffd\u6c42 ' \u79c1", "\u8ffd\u6c42\u8d43\u79c1")],
    # Im Luther-Modul haengt in 1Mo 5,1 ein Fragezeichen hinter dem Semikolon,
    # mit dem der Vers endet. Gedruckt und in der Ausgabe von ebible.org
    # (deu1912) steht dort nur das Semikolon.
    ("lut", "1Mo", 5, 1): [("Bilde Gottes;?", "Bilde Gottes;")],
}


def apply_source_fixes(verses: list, code: str) -> tuple[list, list]:
    """Wendet die Korrekturtabelle an und meldet jede einzelne Aenderung."""
    notes, out = [], []
    for c, b, ch, vs, t in verses:
        for old, new in SOURCE_FIXES.get((code, b, ch, vs), []):
            if old in t:
                t = t.replace(old, new)
                notes.append(f"Korrektur {code} {b} {ch},{vs}: "
                             f"{old.strip()!r} -> {new!r}")
            else:
                notes.append(f"WARNUNG: Korrektur {code} {b} {ch},{vs} nicht "
                             f"anwendbar, Muster nicht gefunden")
        out.append((c, b, ch, vs, t))
    return out, notes


# Uebersetzungen, deren Zeichensetzung nachgezogen wird. Bewusst an den Code
# gebunden und nicht allgemein, weil beide Schritte sonst Schaden anrichten:
# im Franzoesischen (lsg) gehoert das Leerzeichen vor ; : ! ? zur Rechtschreibung,
# und die uebrigen Quellen bringen ihre Anfuehrungszeichen typografisch mit.
#
# Das Luther-Modul braucht beides. Es setzt ASCII-Anfuehrungszeichen, waehrend
# die quotepas-Quelle (\flqq/\frqq) und Schlachter 1951 « » verwenden - ohne
# Angleichung mischten die deutschen Uebersetzungen zwei Systeme. Und es laesst
# an 24 Stellen ein Leerzeichen vor dem Satzzeichen stehen, wo im Druck eine
# Fussnotenmarke stand («heisst Hiddekel , das fliesst vor Assyrien»).
TYPOGRAPHY_FIXUPS = {"lut"}

# Ein " oeffnet am Textanfang und nach Leerzeichen oder oeffnender Klammer,
# sonst schliesst es. Nicht ueber Paare gezaehlt: 177 Zitate laufen ueber
# Versgrenzen, und in sechs Kapiteln fehlt in der Quelle das oeffnende Zeichen -
# dort setzt die Regel richtig ein schliessendes, statt eines zu erfinden.
QUOTE_OPENERS = " ([{«„"
SPACE_BEFORE_PUNCT_RE = re.compile(r" +([,.;:!?])")


def set_guillemets(text: str) -> str:
    return "".join(
        ch if ch != '"' else
        ("«" if i == 0 or text[i - 1] in QUOTE_OPENERS else "»")
        for i, ch in enumerate(text)
    )


def apply_typography(verses: list, code: str) -> tuple[list, list]:
    """Zieht die Zeichensetzung einzelner Quellen nach und meldet den Umfang."""
    if code not in TYPOGRAPHY_FIXUPS:
        return verses, []
    out, spaced, quoted = [], 0, 0
    for c, b, ch, vs, t in verses:
        tight = SPACE_BEFORE_PUNCT_RE.sub(r"\1", t)
        spaced += tight != t
        text = set_guillemets(tight)
        quoted += text != tight
        out.append((c, b, ch, vs, text))
    notes = []
    if spaced:
        notes.append(f"Typografie {code}: Leerzeichen vor Satzzeichen in "
                     f"{spaced} Versen entfernt")
    if quoted:
        notes.append(f"Typografie {code}: ASCII-Anfuehrungszeichen in "
                     f"{quoted} Versen auf « » gesetzt")
    return out, notes

# USFM-Buchkuerzel -> Buchcode der quotepas-Datei.
USFM_BOOKS = {
    "GEN": "1Mo", "EXO": "2Mo", "LEV": "3Mo", "NUM": "4Mo", "DEU": "5Mo",
    "JOS": "Jos", "JDG": "Ri", "RUT": "Rt", "1SA": "1Sam", "2SA": "2Sam",
    "1KI": "1Kon", "2KI": "2Kon", "1CH": "1Chr", "2CH": "2Chr", "EZR": "Esr",
    "NEH": "Neh", "EST": "Est", "JOB": "Hi", "PSA": "Ps", "PRO": "Spr",
    "ECC": "Pred", "SNG": "Hl", "ISA": "Jes", "JER": "Jer", "LAM": "Kla",
    "EZK": "Hes", "DAN": "Dan", "HOS": "Hos", "JOL": "Joel", "AMO": "Am",
    "OBA": "Ob", "JON": "Jon", "MIC": "Mi", "NAM": "Nah", "HAB": "Hab",
    "ZEP": "Zeph", "HAG": "Hag", "ZEC": "Sach", "MAL": "Mal", "MAT": "Mt",
    "MRK": "Mk", "LUK": "Lk", "JHN": "Joh", "ACT": "Apg", "ROM": "Rom",
    "1CO": "1Kor", "2CO": "2Kor", "GAL": "Gal", "EPH": "Eph", "PHP": "Phil",
    "COL": "Kol", "1TH": "1Th", "2TH": "2Th", "1TI": "1Tim", "2TI": "2Tim",
    "TIT": "Tit", "PHM": "Phlm", "HEB": "Hebr", "JAS": "Jak", "1PE": "1Pt",
    "2PE": "2Pt", "1JN": "1Joh", "2JN": "2Joh", "3JN": "3Joh", "JUD": "Jud",
    "REV": "Offb",
}

# Marker, deren Zeileninhalt NICHT zum laufenden Vers gehoert: Ueberschriften,
# Parallelstellen, Psalmenueberschriften, Buchtitel.
USFM_BREAK = {"s", "r", "d", "ms", "mt", "mte", "h", "toc", "id", "ide", "rem",
              "cl", "cp", "sp", "periph", "iot", "io", "ip", "is", "imt", "ib"}

USFM_ID_RE = re.compile(r"^\\id\s+(\w+)", re.MULTILINE)
USFM_FILENAME_RE = re.compile(r"^\d{2}([A-Z0-9]{3})")
USFM_C_RE = re.compile(r"^\\c\s+(\d+)")
USFM_V_RE = re.compile(r"^\\v\s+(\d+)\s*(.*)$")
USFM_MARKER_RE = re.compile(r"^\\([a-z]+\d*)\*?\s*(.*)$")
USFM_NOTE_RE = re.compile(r"\\(f|fe|x)\b.*?\\\1\*", re.DOTALL)
USFM_ND_RE = re.compile(r"\\nd\s*(.*?)\\nd\*", re.DOTALL)
USFM_WORD_RE = re.compile(r"\\\+?w\s*([^|\\]*?)(?:\|[^\\]*?)?\\\+?w\*")


def clean_usfm(text: str) -> str:
    text = USFM_NOTE_RE.sub("", text)                     # Fussnoten, Querverweise
    text = USFM_ND_RE.sub(lambda m: m.group(1).upper(), text)   # Gottesname -> HERR
    text = USFM_WORD_RE.sub(r"\1", text)                  # \w Wort|strong=…\w*
    text = re.sub(r"\\\+?[a-z]+\d*\*", "", text)          # schliessende Marker
    text = re.sub(r"\\\+?[a-z]+\d*\s?", "", text)         # oeffnende Marker
    text = text.replace("\u02bc", "\u2019")               # Apostroph vereinheitlichen
    text = unicodedata.normalize("NFC", re.sub(r"\s+", " ", text))
    return re.sub(r"\s+([,.;:!?])", r"\1", text).strip()


def parse_usfm(folder: str, code: str, known_books: set[str]) -> tuple[list, dict, list]:
    """Liest ein Verzeichnis mit USFM-Dateien (eine je Buch).

    Verse koennen sich ueber mehrere Zeilen erstrecken (Poesie mit \\q1/\\q2);
    sie werden zusammengefuehrt. Ueberschriften und Psalmenueberschriften (\\d)
    gehoeren nicht zum Verstext und beenden den laufenden Vers.
    """
    abbrev, name = TRANSLATION_NAMES.get(code, (code.upper(), code.upper()))
    files = sorted(f for f in os.listdir(folder) if f.lower().endswith((".usfm", ".sfm")))
    if not files:
        raise SystemExit(f"Keine USFM-Dateien in {folder} gefunden.")

    verses, warnings, unknown = [], [], set()
    for fname in files:
        raw = open(os.path.join(folder, fname), "r", encoding="utf-8-sig").read()
        m = USFM_ID_RE.search(raw)
        if m:
            usfm_code = m.group(1).upper()
        else:
            # Manche Ausgaben lassen den \id-Marker weg. Dann aus dem Dateinamen
            # ableiten: zwei Ziffern Buchnummer, dann das dreistellige Kuerzel.
            fm = USFM_FILENAME_RE.match(fname.upper())
            if not fm or fm.group(1) not in USFM_BOOKS:
                warnings.append(f"{fname}: kein \\id-Marker und kein Kuerzel im "
                                f"Dateinamen, uebersprungen")
                continue
            usfm_code = fm.group(1)
            warnings.append(f"{fname}: \\id fehlt, Buch aus Dateiname bestimmt "
                            f"({usfm_code})")
        bcode = USFM_BOOKS.get(usfm_code)
        if bcode is None or bcode not in known_books:
            unknown.add(m.group(1))
            continue

        chapter, vnum, buf = 0, None, []

        def flush():
            if vnum is not None and buf:
                t = clean_usfm(" ".join(buf))
                if t:
                    verses.append((code, bcode, chapter, vnum, t))

        for line in raw.splitlines():
            line = line.rstrip()
            if not line:
                continue
            mc = USFM_C_RE.match(line)
            if mc:
                flush(); vnum, buf = None, []
                chapter = int(mc.group(1))
                continue
            mv = USFM_V_RE.match(line)
            if mv:
                flush()
                vnum, buf = int(mv.group(1)), [mv.group(2)]
                continue
            mm = USFM_MARKER_RE.match(line)
            if mm:
                base = re.sub(r"\d+$", "", mm.group(1))
                if base in USFM_BREAK:
                    flush(); vnum, buf = None, []
                elif vnum is not None and mm.group(2):
                    buf.append(mm.group(2))
                continue
            if vnum is not None:
                buf.append(line)
        flush()

    if unknown:
        warnings.append(f"USFM-Buecher ohne Zuordnung uebersprungen: {sorted(unknown)}")
    return verses, {"abbrev": abbrev, "name": name}, warnings


def parse_osis(path: str, code: str, known_books: set[str]) -> tuple[list, dict, list]:
    """Liest eine OSIS-XML-Bibel. Gibt (Verse, Metadaten, Warnungen) zurueck.

    Erwartet Verse als <verse osisID='Gen.1.1'>Text</verse>. Eingebettete
    <note>-Elemente werden entfernt, sonstiges Markup abgestreift.
    """
    raw = open(path, "r", encoding="utf-8").read()
    head, _, body = raw.partition("</header>")
    title = OSIS_TITLE_RE.search(head)
    abbrev, name = TRANSLATION_NAMES.get(code, (code.upper(), code.upper()))
    if title and code not in TRANSLATION_NAMES:
        name = re.sub(r"\s+", " ", title.group(1)).strip() or name

    verses, warnings = [], []
    unknown = set()
    for m in OSIS_VERSE_RE.finditer(body or raw):
        osis_id, text = m.group(1), m.group(2)
        parts = osis_id.split(".")
        if len(parts) != 3:
            continue                      # Versbereiche o.ae. ueberspringen
        obook, chapter, verse = parts
        bcode = OSIS_BOOKS.get(obook)
        if bcode is None or bcode not in known_books:
            unknown.add(obook)
            continue
        t = re.sub(r"<note[^>]*>.*?</note>", "", text, flags=re.DOTALL)
        t = re.sub(r"<[^>]+>", "", t)
        t = html.unescape(t)
        # Bewusst nicht \s: das umfasst U+3000, und der ideographische Abstand
        # ist im Chinesischen bedeutungstragend (Ehrfurchtsabstand vor 神).
        t = unicodedata.normalize("NFC", re.sub(r"[ \t\r\n\f\v]+", " ", t)).strip()
        if not t:
            continue
        verses.append((code, bcode, int(chapter), int(verse), t))
    if unknown:
        warnings.append(f"OSIS-Buecher ohne Zuordnung uebersprungen: {sorted(unknown)}")

    # CJK-Quellen: Leerzeichen zwischen den Schriftzeichen entfernen.
    if verses and is_cjk([v[4] for v in verses[:200]]):
        before = sum(v[4].count(" ") for v in verses)
        verses = [(c, b, ch, vs, CJK_SPACE_RE.sub("", t).strip())
                  for c, b, ch, vs, t in verses]
        after = sum(v[4].count(" ") for v in verses)
        warnings.append(f"CJK-Quelle erkannt: {before - after} Zeichenzwischenraeume "
                        f"entfernt, U+3000 erhalten")
    verses, fix_notes = apply_source_fixes(verses, code)
    warnings.extend(fix_notes)
    verses, typo_notes = apply_typography(verses, code)
    warnings.extend(typo_notes)
    return verses, {"abbrev": abbrev, "name": name}, warnings

# ---------------------------------------------------------------------------
# Parsing
# ---------------------------------------------------------------------------

ENTRY_RE = re.compile(
    r"<quotepas>\s*<label>(?P<label>.*?)</label>\s*<block>(?P<block>.*?)</block>\s*</quotepas>",
    re.DOTALL,
)
VERSE_TAIL_RE = re.compile(r"^(?P<chapter>\d+)v(?P<verse>\d+)$")

# In der Quelldatei kommen genau fuenf LaTeX-Befehle vor (vollstaendig ausgezaehlt):
#   \textsc{Herr}      6654x  Kapitaelchen fuer den Gottesnamen -> HERR
#   \frqq \flqq        3785x  Schweizer Anfuehrungszeichen     -> « »
#   \biblefootnote{}   1381x  Fussnote                          -> entfaellt (Option)
#   \textit{}           769x  Kursiv fuer ergaenzte Woerter    -> Text bleibt
# Die uebrigen Eintraege unten sind Vorsorge, falls die Quelle spaeter waechst.

QUOTE_COMMANDS = {
    "flqq": "\u00ab", "frqq": "\u00bb",
    "glqq": "\u201e", "grqq": "\u201c", "glq": "\u201a", "grq": "\u2018",
    "dots": "\u2026", "ldots": "\u2026", "textellipsis": "\u2026",
}
# Zeichen-Escapes: kein Leerzeichen schlucken.
LATEX_REPLACEMENTS = [
    (r"\%", "%"), (r"\&", "&"), (r"\_", "_"), (r"\#", "#"),
    (r"\$", "$"), (r"\{", "{"), (r"\}", "}"),
    (r"\,", "\u202f"), (r"\-", ""),
]
QUOTE_RE = re.compile(
    r"\\(" + "|".join(sorted(QUOTE_COMMANDS, key=len, reverse=True))
    + r")(?![A-Za-z])(?:\{\})?[ ]?"
)
EMPTY_GROUP_RE = re.compile(r"\{\}")
# Befehle mit Argument: Name -> Umgang mit dem Inhalt.
UNWRAP_COMMANDS = ("textit", "emph", "textbf", "mbox", "text")
UPPER_COMMANDS = ("textsc",)
DROP_COMMANDS = ("biblefootnote", "footnote")


def _balanced(text: str, start: int):
    """start zeigt auf '{'. Gibt (Inhalt, Index nach '}') oder (None, None)."""
    depth = 0
    for i in range(start, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return text[start + 1:i], i + 1
    return None, None


def _apply_command(text: str, name: str, mode: str) -> str:
    """mode: 'unwrap' | 'upper' | 'drop'. Beachtet verschachtelte Klammern."""
    token = "\\" + name
    out, i = [], 0
    while True:
        j = text.find(token, i)
        if j < 0:
            out.append(text[i:])
            return "".join(out)
        k = j + len(token)
        if k < len(text) and text[k].isalpha():   # laengerer Befehlsname
            out.append(text[i:k])
            i = k
            continue
        m = k
        while m < len(text) and text[m] == " ":
            m += 1
        if m >= len(text) or text[m] != "{":
            out.append(text[i:k])
            i = k
            continue
        inner, end = _balanced(text, m)
        if inner is None:                          # unbalanciert: unveraendert
            out.append(text[i:k])
            i = k
            continue
        out.append(text[i:j])
        if mode == "unwrap":
            out.append(inner)
        elif mode == "upper":
            out.append(inner.upper())
        i = end

GROUP_CMD_RE = re.compile(r"\\(?:emph|textit|textbf|textsc|text|mbox)\{([^{}]*)\}")
EMPTY_GROUP_RE = re.compile(r"\{\}")


def clean_text(raw: str, keep_footnotes: bool = False) -> tuple[str, list[str]]:
    """Gibt (bereinigter Text, Liste verbliebener LaTeX-Reste) zurueck."""
    text = raw
    for _ in range(5):                      # bis sich nichts mehr aendert
        before = text
        for name in DROP_COMMANDS:
            text = _apply_command(text, name, "unwrap" if keep_footnotes else "drop")
        for name in UPPER_COMMANDS:
            text = _apply_command(text, name, "upper")
        for name in UNWRAP_COMMANDS:
            text = _apply_command(text, name, "unwrap")
        if text == before:
            break
    text = QUOTE_RE.sub(lambda m: QUOTE_COMMANDS[m.group(1)], text)
    for src, dst in LATEX_REPLACEMENTS:
        text = text.replace(src, dst)
    text = text.replace("\\\\", " ")
    text = text.replace("~", "\u00a0")
    text = text.replace("---", "\u2014").replace("--", "\u2013")
    text = EMPTY_GROUP_RE.sub("", text)
    # Steuerwort-Regel hat das Trennzeichen geschluckt, wo es zum Wort gehoert.
    text = re.sub(r"([\u2026\u201c\u2018\u00bb])(?=[^\W\d_])", r"\1 ", text)
    text = unicodedata.normalize("NFC", text)
    text = re.sub(r"[ \t\r\n]+", " ", text)
    text = re.sub(r" ([,.;:!?])", r"\1", text)          # Fussnote vor Satzzeichen
    text = re.sub(r"\(\s*\)|\[\s*\]", "", text).strip()
    leftovers = re.findall(r"\\[A-Za-z@]+", text)
    return text, leftovers


def parse_source(path: str, encoding: str) -> list[tuple[str, str]]:
    with open(path, "r", encoding=encoding, errors="strict") as fh:
        content = fh.read()
    entries = [(m.group("label").strip(), m.group("block"))
               for m in ENTRY_RE.finditer(content)]
    if not entries:
        raise SystemExit("Keine <quotepas>-Eintraege gefunden. Falsches Format "
                         "oder falsche Kodierung?")
    return entries


class ParseResult:
    def __init__(self) -> None:
        self.translations: dict[str, dict] = {}   # code -> {abbrev, name}
        self.books: dict[str, str] = {}           # code -> deutscher Name
        self.book_order: list[str] = []
        self.verses: list[tuple] = []             # (tcode, bcode, ch, vs, text)
        self.unclassified: list[str] = []
        self.leftovers: Counter = Counter()
        self.duplicates: list[str] = []
        self.empty: list[str] = []


def classify(entries: list[tuple[str, str]]) -> ParseResult:
    res = ParseResult()

    # Durchgang 1: Uebersetzungen und Buchkandidaten einsammeln.
    candidates: list[str] = []
    for label, block in entries:
        text, _ = clean_text(block)
        if label.startswith("short") and len(label) > 5:
            res.translations.setdefault(label[5:], {})["abbrev"] = text
        elif label.startswith("long") and len(label) > 4:
            res.translations.setdefault(label[4:], {})["name"] = text
        elif not re.search(r"\d+v\d+$", label):
            candidates.append(label)
            res.books[label] = text

    tcodes = sorted(res.translations, key=len, reverse=True)
    bcodes = sorted(candidates, key=len, reverse=True)
    if not tcodes:
        raise SystemExit("Keine Uebersetzungen (short.../long...) gefunden.")

    # Durchgang 2: Verse aufloesen.
    seen: set[tuple] = set()
    used_books: set[str] = set()
    for label, block in entries:
        if label.startswith(("short", "long")) or label in res.books:
            continue
        tcode = next((t for t in tcodes if label.startswith(t)), None)
        if tcode is None:
            res.unclassified.append(label)
            continue
        rest = label[len(tcode):]
        bcode = next((b for b in bcodes if rest.startswith(b)), None)
        if bcode is None:
            res.unclassified.append(label)
            continue
        m = VERSE_TAIL_RE.match(rest[len(bcode):])
        if not m:
            res.unclassified.append(label)
            continue
        chapter, verse = int(m.group("chapter")), int(m.group("verse"))
        text, leftovers = clean_text(block)
        for lo in leftovers:
            res.leftovers[lo] += 1
        key = (tcode, bcode, chapter, verse)
        if key in seen:
            res.duplicates.append(label)
            continue
        if not text:
            res.empty.append(label)
            continue
        seen.add(key)
        used_books.add(bcode)
        res.verses.append((tcode, bcode, chapter, verse, text))

    # Buchkandidaten ohne Verse sind Metadaten, keine Buecher.
    res.book_order = [b for b in candidates if b in used_books]
    for b in list(res.books):
        if b not in used_books:
            res.unclassified.append(f"(Buchkandidat ohne Verse) {b}")
            del res.books[b]
    return res


# ---------------------------------------------------------------------------
# SQLite-Ausgabe
# ---------------------------------------------------------------------------

DDL = """
PRAGMA journal_mode = OFF;
PRAGMA synchronous  = OFF;

CREATE TABLE meta (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

CREATE TABLE translation (
    id             INTEGER PRIMARY KEY,
    code           TEXT NOT NULL UNIQUE,
    abbrev         TEXT NOT NULL,
    name           TEXT NOT NULL,
    language       TEXT NOT NULL,
    copyright      TEXT,
    verse_count    INTEGER NOT NULL,
    first_verse_id INTEGER NOT NULL,
    last_verse_id  INTEGER NOT NULL,
    sort_order     INTEGER NOT NULL
);

CREATE TABLE book (
    id            INTEGER PRIMARY KEY,
    code          TEXT NOT NULL UNIQUE,
    name          TEXT NOT NULL,
    name_en       TEXT,
    name_es       TEXT,
    name_fr       TEXT,
    name_zh_hant  TEXT,
    name_zh_hans  TEXT,
    testament     TEXT NOT NULL,
    chapter_count INTEGER NOT NULL,
    sort_order    INTEGER NOT NULL
);

CREATE TABLE verse (
    id             INTEGER PRIMARY KEY,
    translation_id INTEGER NOT NULL,
    book_id        INTEGER NOT NULL,
    chapter        INTEGER NOT NULL,
    verse          INTEGER NOT NULL,
    text           TEXT NOT NULL
);

CREATE UNIQUE INDEX idx_verse_ref
    ON verse (translation_id, book_id, chapter, verse);

CREATE TABLE chapter_meta (
    translation_id INTEGER NOT NULL,
    book_id        INTEGER NOT NULL,
    chapter        INTEGER NOT NULL,
    verse_count    INTEGER NOT NULL,
    PRIMARY KEY (translation_id, book_id, chapter)
) WITHOUT ROWID;

CREATE TABLE curated (
    id      INTEGER PRIMARY KEY,
    book_id INTEGER NOT NULL,
    chapter INTEGER NOT NULL,
    verse   INTEGER NOT NULL,
    topic   TEXT
);

CREATE UNIQUE INDEX idx_curated_ref ON curated (book_id, chapter, verse);
"""


def build_database(res: ParseResult, out_path: str, source_name: str,
                   curated: list[dict], keep: list[str],
                   swiss: bool = False) -> dict:
    if os.path.exists(out_path):
        os.remove(out_path)
    con = sqlite3.connect(out_path)
    con.executescript(DDL)
    con.execute(f"PRAGMA application_id = {APPLICATION_ID}")
    con.execute(f"PRAGMA user_version = {SCHEMA_VERSION}")

    book_id = {code: i + 1 for i, code in enumerate(res.book_order)}
    trans_id = {code: i + 1 for i, code in enumerate(keep)}

    # Buecher
    chapters_per_book: dict[str, set] = defaultdict(set)
    for _t, b, c, _v, _x in res.verses:
        chapters_per_book[b].add(c)
    con.executemany(
        "INSERT INTO book (id, code, name, name_en, name_es, name_fr,"
        " name_zh_hant, name_zh_hans, testament, chapter_count,"
        " sort_order) VALUES (?,?,?,?,?,?,?,?,?,?,?)",
        [(book_id[c], c, res.books[c], ENGLISH_NAMES.get(c),
          SPANISH_NAMES.get(c), FRENCH_NAMES.get(c),
          CHINESE_TRAD_NAMES.get(c), CHINESE_SIMP_NAMES.get(c),
          "NT" if c in NT_CODES else "AT",
          max(chapters_per_book[c]) if chapters_per_book[c] else 0,
          book_id[c]) for c in res.book_order],
    )

    # Verse: fortlaufende ids, je Uebersetzung ein zusammenhaengender Block.
    by_trans: dict[str, list] = defaultdict(list)
    for t, b, c, v, x in res.verses:
        if t in trans_id:
            by_trans[t].append((b, c, v, x))

    next_id = 1
    stats = {}
    for code in keep:
        rows = sorted(by_trans[code], key=lambda r: (book_id[r[0]], r[1], r[2]))
        if not rows:
            raise SystemExit(f"Uebersetzung '{code}' enthaelt keine Verse.")
        meta = TRANSLATION_META.get(code, ("de", None))
        if swiss and meta[0] == "de":
            rows = [(b, c, v, x.replace("\u00df", "ss")) for b, c, v, x in rows]
        first_id = next_id
        payload = []
        for b, c, v, x in rows:
            payload.append((next_id, trans_id[code], book_id[b], c, v, x))
            next_id += 1
        con.executemany("INSERT INTO verse VALUES (?,?,?,?,?,?)", payload)
        last_id = next_id - 1
        info = res.translations.get(code, {})
        con.execute(
            "INSERT INTO translation (id, code, abbrev, name, language,"
            " copyright, verse_count, first_verse_id, last_verse_id, sort_order)"
            " VALUES (?,?,?,?,?,?,?,?,?,?)",
            (trans_id[code], code, info.get("abbrev", code.upper()),
             info.get("name", code.upper()), meta[0], meta[1],
             len(rows), first_id, last_id, trans_id[code]),
        )
        stats[code] = len(rows)

    con.execute(
        "INSERT INTO chapter_meta (translation_id, book_id, chapter, verse_count)"
        " SELECT translation_id, book_id, chapter, COUNT(*) FROM verse"
        " GROUP BY translation_id, book_id, chapter"
    )

    # Kuratierte Auswahl: jede Referenz gegen die Leituebersetzung pruefen.
    master = trans_id[keep[0]]
    curated_ok, curated_missing = 0, []
    for i, item in enumerate(curated, start=1):
        bcode = item["book"]
        if bcode not in book_id:
            curated_missing.append(f"{bcode} {item['chapter']},{item['verse']} (Buch unbekannt)")
            continue
        row = con.execute(
            "SELECT 1 FROM verse WHERE translation_id=? AND book_id=? AND"
            " chapter=? AND verse=?",
            (master, book_id[bcode], item["chapter"], item["verse"]),
        ).fetchone()
        if row is None:
            curated_missing.append(f"{bcode} {item['chapter']},{item['verse']}")
            continue
        con.execute(
            "INSERT OR IGNORE INTO curated (book_id, chapter, verse, topic)"
            " VALUES (?,?,?,?)",
            (book_id[bcode], item["chapter"], item["verse"], item.get("topic")),
        )
        curated_ok += 1

    con.executemany("INSERT INTO meta VALUES (?,?)", [
        ("schema_version", str(SCHEMA_VERSION)),
        ("generated_at", datetime.now(timezone.utc).isoformat(timespec="seconds")),
        ("source_file", source_name),
        ("generator", "quotepas_to_sqlite.py"),
        ("master_translation", keep[0]),
        ("curated_count", str(curated_ok)),
    ])

    con.commit()
    con.execute("ANALYZE")
    con.commit()
    con.execute("VACUUM")
    con.close()
    return {"per_translation": stats, "curated_ok": curated_ok,
            "curated_missing": curated_missing, "books": len(res.book_order)}


# ---------------------------------------------------------------------------

def main() -> int:
    ap = argparse.ArgumentParser(description="quotepas-Datenbank nach SQLite")
    ap.add_argument("source", help="Pfad zur quotepas-.db-Datei")
    ap.add_argument("-o", "--out", default="bible.sqlite", help="Zieldatei")
    ap.add_argument("--encoding", default="utf-8")
    ap.add_argument("--include", help="nur diese Codes, kommagetrennt (z.B. elb,kjv)")
    ap.add_argument("--exclude", help="diese Codes weglassen (z.B. slt)")
    ap.add_argument("--curated", help="JSON-Datei mit kuratierten Versen")
    ap.add_argument("--osis", action="append", default=[], metavar="CODE=DATEI",
                    help="zusaetzliche Uebersetzung im OSIS-XML-Format, "
                         "mehrfach angebbar (z.B. sch1951=sch1951.xml)")
    ap.add_argument("--usfm", action="append", default=[], metavar="CODE=ORDNER",
                    help="zusaetzliche Uebersetzung als USFM-Verzeichnis, "
                         "mehrfach angebbar (z.B. bsb=./bsb_usfm)")
    ap.add_argument("--dry-run", action="store_true", help="nur Bericht, keine DB")
    ap.add_argument("--swiss", action="store_true",
                    help="Schweizer Orthografie: \u00df -> ss in deutschen Texten")
    ap.add_argument("--strict", action="store_true",
                    help="Abbruch bei nicht klassifizierten Labels")
    args = ap.parse_args()

    entries = parse_source(args.source, args.encoding)
    res = classify(entries)

    # Zusaetzliche Quellen anhaengen: OSIS-XML und USFM-Verzeichnisse.
    osis_notes = []
    for spec, reader, kind in ([(x, parse_osis, "OSIS") for x in args.osis] +
                               [(x, parse_usfm, "USFM") for x in args.usfm]):
        if "=" not in spec:
            raise SystemExit(f"--{kind.lower()} erwartet CODE=PFAD, erhalten: {spec}")
        code, path = spec.split("=", 1)
        code = code.strip()
        if code in res.translations:
            raise SystemExit(f"Code '{code}' ist bereits belegt.")
        verses, meta, warn = reader(path, code, set(res.book_order))
        if not verses:
            raise SystemExit(f"{kind}-Quelle {path} enthielt keine verwertbaren Verse.")
        res.translations[code] = meta
        res.verses.extend(verses)
        osis_notes.append((kind, code, path, len(verses), meta["name"]))
        res.unclassified.extend(warn)

    codes = list(res.translations)
    if args.include:
        wanted = [c.strip() for c in args.include.split(",")]
        unknown = [c for c in wanted if c not in codes]
        if unknown:
            raise SystemExit(f"Unbekannte Codes in --include: {unknown}")
        keep = wanted
    else:
        keep = codes
    if args.exclude:
        drop = {c.strip() for c in args.exclude.split(",")}
        keep = [c for c in keep if c not in drop]
    if not keep:
        raise SystemExit("Nach Filterung bleibt keine Uebersetzung uebrig.")

    print("=" * 68)
    print(f"Quelle          : {args.source}  ({len(entries)} Eintraege)")
    print(f"Uebersetzungen  : " + ", ".join(
        f"{c}={res.translations[c].get('abbrev', '?')}"
        f" ({res.translations[c].get('name', '?')})" for c in codes))
    print(f"Uebernommen     : {', '.join(keep)}")
    for kind, code, path, n, name in osis_notes:
        print(f"{kind}-Quelle     : {code} = {name}  ({n} Verse aus {os.path.basename(path.rstrip('/'))})")
    print(f"Buecher         : {len(res.book_order)}")
    print(f"Verse gesamt    : {len(res.verses)}")
    counts = Counter(t for t, *_ in res.verses)
    for c in codes:
        flag = "" if c in keep else "   [uebersprungen]"
        print(f"  {c:<5} {counts[c]:>7} Verse{flag}")
    if len(set(counts[c] for c in keep)) > 1:
        print("  Hinweis: abweichende Verszahlen sind normal "
              "(Versifikation DE/EN, z.B. Psalmenueberschriften).")
    if res.duplicates:
        print(f"Duplikate       : {len(res.duplicates)} -> {res.duplicates[:5]}")
    if res.empty:
        print(f"Leere Bloecke   : {len(res.empty)} -> {res.empty[:5]}")
    if res.leftovers:
        print(f"LaTeX-Reste     : {dict(res.leftovers.most_common(10))}")
        print("  -> LATEX_REPLACEMENTS im Skript ergaenzen und neu laufen lassen.")
    if res.unclassified:
        print(f"Unklassifiziert : {len(res.unclassified)} -> {res.unclassified[:8]}")
        if args.strict:
            return 1

    if args.dry_run:
        print("Dry run - keine Datei geschrieben.")
        return 0

    curated = []
    if args.curated:
        with open(args.curated, "r", encoding="utf-8") as fh:
            curated = json.load(fh)["verses"]

    stats = build_database(res, args.out, os.path.basename(args.source),
                           curated, keep, swiss=args.swiss)
    size_mb = os.path.getsize(args.out) / 1024 / 1024
    print("-" * 68)
    print(f"Geschrieben     : {args.out}  ({size_mb:.1f} MB)")
    if curated:
        print(f"Kuratiert       : {stats['curated_ok']} uebernommen, "
              f"{len(stats['curated_missing'])} nicht gefunden")
        for miss in stats["curated_missing"][:10]:
            print(f"    fehlt: {miss}")
    if size_mb > 70:
        print("WARNUNG: Watch-App-Bundle darf unkomprimiert 75 MB nicht "
              "ueberschreiten. Uebersetzungen reduzieren.")
    print("=" * 68)
    return 0


if __name__ == "__main__":
    sys.exit(main())
