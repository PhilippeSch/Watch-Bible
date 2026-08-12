#!/usr/bin/env python3
"""
tables.py
=========

Die Nachschlagetabellen, die in die Datenbank geschrieben werden: Kanonwissen,
Buchnamen und Buchkuerzel der acht Oberflaechensprachen, Reihenfolge und
Copyright-Zeilen der Uebersetzungen, dazu Schema-Version und das DDL der
Tabelle `curated`.

Eine Sprache dazunehmen heisst: eine Namens- und eine Kuerzeltabelle
schreiben und beide in BOOK_NAME_TABLES / BOOK_ABBREV_TABLES eintragen.
Konverter und Nachtragsskripte lesen ausschliesslich diese beiden
Verzeichnisse — es gibt keine zweite Stelle, an der Spalten aufgezaehlt
werden.

Warum getrennt vom Konverter: `quotepas_to_sqlite.py` beschreibt, **wie** die
Quellen gelesen werden (quotepas-LaTeX, OSIS, USFM) — dieses Modul, **was** in
der Datenbank steht. Die Nachtragsskripte (`add_book_names.py`,
`reorder_translations.py`, `update_curated.py`) brauchen nur das Zweite und
importieren darum hier, nicht den Konverter. Es gibt weiterhin nur eine Quelle:
beide Wege lesen dieselben Tabellen.

Nicht ausfuehrbar, enthaelt nur Daten. Nur Standardbibliothek.
"""

from __future__ import annotations

SCHEMA_VERSION = 4
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

# Italienisch, Namensgebung der Riveduta 1927. Aus den \h-Kopfzeilen der
# USFM-Quelle uebernommen, mit einer Korrektur: die Kopfzeile schreibt
# «Giosué», der Verstext 225-mal «Giosuè» und nur 5-mal «Giosué» — es gilt
# die Form des Textes.
ITALIAN_NAMES = {
    "1Mo": "Genesi", "2Mo": "Esodo", "3Mo": "Levitico", "4Mo": "Numeri",
    "5Mo": "Deuteronomio", "Jos": "Giosuè", "Ri": "Giudici", "Rt": "Rut",
    "1Sam": "1 Samuele", "2Sam": "2 Samuele", "1Kon": "1 Re", "2Kon": "2 Re",
    "1Chr": "1 Cronache", "2Chr": "2 Cronache", "Esr": "Esdra",
    "Neh": "Neemia", "Est": "Ester", "Hi": "Giobbe", "Ps": "Salmi",
    "Spr": "Proverbi", "Pred": "Ecclesiaste", "Hl": "Cantico dei Cantici",
    "Jes": "Isaia", "Jer": "Geremia", "Kla": "Lamentazioni",
    "Hes": "Ezechiele", "Dan": "Daniele", "Hos": "Osea", "Joel": "Gioele",
    "Am": "Amos", "Ob": "Abdia", "Jon": "Giona", "Mi": "Michea",
    "Nah": "Nahum", "Hab": "Abacuc", "Zeph": "Sofonia", "Hag": "Aggeo",
    "Sach": "Zaccaria", "Mal": "Malachia", "Mt": "Matteo", "Mk": "Marco",
    "Lk": "Luca", "Joh": "Giovanni", "Apg": "Atti", "Rom": "Romani",
    "1Kor": "1 Corinzi", "2Kor": "2 Corinzi", "Gal": "Galati",
    "Eph": "Efesini", "Phil": "Filippesi", "Kol": "Colossesi",
    "1Th": "1 Tessalonicesi", "2Th": "2 Tessalonicesi", "1Tim": "1 Timoteo",
    "2Tim": "2 Timoteo", "Tit": "Tito", "Phlm": "Filemone",
    "Hebr": "Ebrei", "Jak": "Giacomo", "1Pt": "1 Pietro", "2Pt": "2 Pietro",
    "1Joh": "1 Giovanni", "2Joh": "2 Giovanni", "3Joh": "3 Giovanni",
    "Jud": "Giuda", "Offb": "Apocalisse",
}

# Portugiesisch, Namensgebung der Biblia Livre (Almeida-Linie). Aus den
# \h-Kopfzeilen der USFM-Quelle uebernommen.
PORTUGUESE_NAMES = {
    "1Mo": "Gênesis", "2Mo": "Êxodo", "3Mo": "Levítico", "4Mo": "Números",
    "5Mo": "Deuteronômio", "Jos": "Josué", "Ri": "Juízes", "Rt": "Rute",
    "1Sam": "1 Samuel", "2Sam": "2 Samuel", "1Kon": "1 Reis", "2Kon": "2 Reis",
    "1Chr": "1 Crônicas", "2Chr": "2 Crônicas", "Esr": "Esdras",
    "Neh": "Neemias", "Est": "Ester", "Hi": "Jó", "Ps": "Salmos",
    "Spr": "Provérbios", "Pred": "Eclesiastes", "Hl": "Cantares",
    "Jes": "Isaías", "Jer": "Jeremias", "Kla": "Lamentações",
    "Hes": "Ezequiel", "Dan": "Daniel", "Hos": "Oseias", "Joel": "Joel",
    "Am": "Amós", "Ob": "Obadias", "Jon": "Jonas", "Mi": "Miqueias",
    "Nah": "Naum", "Hab": "Habacuque", "Zeph": "Sofonias", "Hag": "Ageu",
    "Sach": "Zacarias", "Mal": "Malaquias", "Mt": "Mateus", "Mk": "Marcos",
    "Lk": "Lucas", "Joh": "João", "Apg": "Atos", "Rom": "Romanos",
    "1Kor": "1 Coríntios", "2Kor": "2 Coríntios", "Gal": "Gálatas",
    "Eph": "Efésios", "Phil": "Filipenses", "Kol": "Colossenses",
    "1Th": "1 Tessalonicenses", "2Th": "2 Tessalonicenses",
    "1Tim": "1 Timóteo", "2Tim": "2 Timóteo", "Tit": "Tito",
    "Phlm": "Filemom", "Hebr": "Hebreus", "Jak": "Tiago", "1Pt": "1 Pedro",
    "2Pt": "2 Pedro", "1Joh": "1 João", "2Joh": "2 João", "3Joh": "3 João",
    "Jud": "Judas", "Offb": "Apocalipse",
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
    "it": ITALIAN_NAMES,
    "pt": PORTUGUESE_NAMES,
    "zh_hant": CHINESE_TRAD_NAMES,
    "zh_hans": CHINESE_SIMP_NAMES,
}

# ---------------------------------------------------------------------------
# Buchkuerzel je Sprache.
#
# Sie sind die kurze Form fuer enge Stellen — das Register der Buchliste und
# die runde Komplikation. Genommen ist jeweils der in der Sprache uebliche
# Satz, nicht eine selbstgebaute Kuerzung:
#
#   de  Elberfelder/Schlachter, also 1Mo statt des Loccumer «Gen». Die
#       deutschen Buchnamen der Datenbank stehen in derselben Tradition
#       («1. Mose», «Hiob», «Prediger»); Loccum wuerde dazu nicht passen.
#   en  SBL Handbook of Style, der akademische Standard des englischen
#       Sprachraums (Gen, Exod, 1 Sam, Matt, Rev).
#   es  Reina-Valera in der Form der Sociedades Biblicas Unidas.
#   fr  Louis Segond in der Form der Alliance biblique francaise.
#   zh  Der Kuerzelsatz des 和合本 (創, 出, 撒上, 林前, 啟).
#
# `book.code` bleibt davon unberuehrt: der ist Schluessel (curated_verses.json,
# test_fixtures.json, OSIS-Zuordnung) und keine Anzeige.
# ---------------------------------------------------------------------------

GERMAN_ABBREV = {
    "1Mo": "1Mo", "2Mo": "2Mo", "3Mo": "3Mo", "4Mo": "4Mo", "5Mo": "5Mo",
    "Jos": "Jos", "Ri": "Ri", "Rt": "Rt", "1Sam": "1Sam", "2Sam": "2Sam",
    "1Kon": "1Kö", "2Kon": "2Kö", "1Chr": "1Chr", "2Chr": "2Chr",
    "Esr": "Esr", "Neh": "Neh", "Est": "Est", "Hi": "Hi", "Ps": "Ps",
    "Spr": "Spr", "Pred": "Pred", "Hl": "Hld", "Jes": "Jes", "Jer": "Jer",
    "Kla": "Kla", "Hes": "Hes", "Dan": "Dan", "Hos": "Hos", "Joel": "Joel",
    "Am": "Am", "Ob": "Ob", "Jon": "Jon", "Mi": "Mi", "Nah": "Nah",
    "Hab": "Hab", "Zeph": "Zeph", "Hag": "Hag", "Sach": "Sach", "Mal": "Mal",
    "Mt": "Mt", "Mk": "Mk", "Lk": "Lk", "Joh": "Joh", "Apg": "Apg",
    "Rom": "Röm", "1Kor": "1Kor", "2Kor": "2Kor", "Gal": "Gal",
    "Eph": "Eph", "Phil": "Phil", "Kol": "Kol", "1Th": "1Thes", "2Th": "2Thes",
    "1Tim": "1Tim", "2Tim": "2Tim", "Tit": "Tit", "Phlm": "Phlm",
    "Hebr": "Hebr", "Jak": "Jak", "1Pt": "1Petr", "2Pt": "2Petr",
    "1Joh": "1Joh", "2Joh": "2Joh", "3Joh": "3Joh", "Jud": "Jud",
    "Offb": "Offb",
}

ENGLISH_ABBREV = {
    "1Mo": "Gen", "2Mo": "Exod", "3Mo": "Lev", "4Mo": "Num", "5Mo": "Deut",
    "Jos": "Josh", "Ri": "Judg", "Rt": "Ruth", "1Sam": "1 Sam", "2Sam": "2 Sam",
    "1Kon": "1 Kgs", "2Kon": "2 Kgs", "1Chr": "1 Chr", "2Chr": "2 Chr",
    "Esr": "Ezra", "Neh": "Neh", "Est": "Esth", "Hi": "Job", "Ps": "Ps",
    "Spr": "Prov", "Pred": "Eccl", "Hl": "Song", "Jes": "Isa", "Jer": "Jer",
    "Kla": "Lam", "Hes": "Ezek", "Dan": "Dan", "Hos": "Hos", "Joel": "Joel",
    "Am": "Amos", "Ob": "Obad", "Jon": "Jonah", "Mi": "Mic", "Nah": "Nah",
    "Hab": "Hab", "Zeph": "Zeph", "Hag": "Hag", "Sach": "Zech", "Mal": "Mal",
    "Mt": "Matt", "Mk": "Mark", "Lk": "Luke", "Joh": "John", "Apg": "Acts",
    "Rom": "Rom", "1Kor": "1 Cor", "2Kor": "2 Cor", "Gal": "Gal",
    "Eph": "Eph", "Phil": "Phil", "Kol": "Col", "1Th": "1 Thess",
    "2Th": "2 Thess", "1Tim": "1 Tim", "2Tim": "2 Tim", "Tit": "Titus",
    "Phlm": "Phlm", "Hebr": "Heb", "Jak": "Jas", "1Pt": "1 Pet",
    "2Pt": "2 Pet", "1Joh": "1 John", "2Joh": "2 John", "3Joh": "3 John",
    "Jud": "Jude", "Offb": "Rev",
}

SPANISH_ABBREV = {
    "1Mo": "Gn", "2Mo": "Ex", "3Mo": "Lv", "4Mo": "Nm", "5Mo": "Dt",
    "Jos": "Jos", "Ri": "Jue", "Rt": "Rt", "1Sam": "1 S", "2Sam": "2 S",
    "1Kon": "1 R", "2Kon": "2 R", "1Chr": "1 Cr", "2Chr": "2 Cr",
    "Esr": "Esd", "Neh": "Neh", "Est": "Est", "Hi": "Job", "Ps": "Sal",
    "Spr": "Pr", "Pred": "Ec", "Hl": "Cnt", "Jes": "Is", "Jer": "Jer",
    "Kla": "Lm", "Hes": "Ez", "Dan": "Dn", "Hos": "Os", "Joel": "Jl",
    "Am": "Am", "Ob": "Abd", "Jon": "Jon", "Mi": "Miq", "Nah": "Nah",
    "Hab": "Hab", "Zeph": "Sof", "Hag": "Hag", "Sach": "Zac", "Mal": "Mal",
    "Mt": "Mt", "Mk": "Mr", "Lk": "Lc", "Joh": "Jn", "Apg": "Hch",
    "Rom": "Ro", "1Kor": "1 Co", "2Kor": "2 Co", "Gal": "Gá",
    "Eph": "Ef", "Phil": "Fil", "Kol": "Col", "1Th": "1 Ts", "2Th": "2 Ts",
    "1Tim": "1 Ti", "2Tim": "2 Ti", "Tit": "Tit", "Phlm": "Flm",
    "Hebr": "He", "Jak": "Stg", "1Pt": "1 P", "2Pt": "2 P",
    "1Joh": "1 Jn", "2Joh": "2 Jn", "3Joh": "3 Jn", "Jud": "Jud",
    "Offb": "Ap",
}

FRENCH_ABBREV = {
    "1Mo": "Gn", "2Mo": "Ex", "3Mo": "Lv", "4Mo": "Nb", "5Mo": "Dt",
    "Jos": "Jos", "Ri": "Jg", "Rt": "Rt", "1Sam": "1 S", "2Sam": "2 S",
    "1Kon": "1 R", "2Kon": "2 R", "1Chr": "1 Ch", "2Chr": "2 Ch",
    "Esr": "Esd", "Neh": "Né", "Est": "Est", "Hi": "Jb", "Ps": "Ps",
    "Spr": "Pr", "Pred": "Ec", "Hl": "Ct", "Jes": "És", "Jer": "Jr",
    "Kla": "Lm", "Hes": "Éz", "Dan": "Dn", "Hos": "Os", "Joel": "Jl",
    "Am": "Am", "Ob": "Ab", "Jon": "Jon", "Mi": "Mi", "Nah": "Na",
    "Hab": "Ha", "Zeph": "So", "Hag": "Ag", "Sach": "Za", "Mal": "Ml",
    "Mt": "Mt", "Mk": "Mc", "Lk": "Lc", "Joh": "Jn", "Apg": "Ac",
    "Rom": "Rm", "1Kor": "1 Co", "2Kor": "2 Co", "Gal": "Ga",
    "Eph": "Ép", "Phil": "Ph", "Kol": "Col", "1Th": "1 Th", "2Th": "2 Th",
    "1Tim": "1 Tm", "2Tim": "2 Tm", "Tit": "Tt", "Phlm": "Phm",
    "Hebr": "Hé", "Jak": "Jc", "1Pt": "1 P", "2Pt": "2 P",
    "1Joh": "1 Jn", "2Joh": "2 Jn", "3Joh": "3 Jn", "Jud": "Jude",
    "Offb": "Ap",
}

# Italienisch: der in italienischen Bibelausgaben uebliche Satz (CEI /
# Nuova Riveduta). Die USFM-Quelle taugt hier nicht — ihr \toc3 wiederholt
# bloss den vollen Namen. Beachte Gen (Genesi) gegen Gn (Giona): die
# italienische Tradition trennt die beiden genau so.
ITALIAN_ABBREV = {
    "1Mo": "Gen", "2Mo": "Es", "3Mo": "Lv", "4Mo": "Nm", "5Mo": "Dt",
    "Jos": "Gs", "Ri": "Gdc", "Rt": "Rt", "1Sam": "1Sam", "2Sam": "2Sam",
    "1Kon": "1Re", "2Kon": "2Re", "1Chr": "1Cr", "2Chr": "2Cr",
    "Esr": "Esd", "Neh": "Ne", "Est": "Est", "Hi": "Gb", "Ps": "Sal",
    "Spr": "Pr", "Pred": "Ec", "Hl": "Ct", "Jes": "Is", "Jer": "Ger",
    "Kla": "Lam", "Hes": "Ez", "Dan": "Dn", "Hos": "Os", "Joel": "Gl",
    "Am": "Am", "Ob": "Abd", "Jon": "Gn", "Mi": "Mi", "Nah": "Na",
    "Hab": "Ab", "Zeph": "Sof", "Hag": "Ag", "Sach": "Zc", "Mal": "Ml",
    "Mt": "Mt", "Mk": "Mc", "Lk": "Lc", "Joh": "Gv", "Apg": "At",
    "Rom": "Rm", "1Kor": "1Cor", "2Kor": "2Cor", "Gal": "Gal",
    "Eph": "Ef", "Phil": "Flp", "Kol": "Col", "1Th": "1Ts", "2Th": "2Ts",
    "1Tim": "1Tm", "2Tim": "2Tm", "Tit": "Tt", "Phlm": "Flm",
    "Hebr": "Eb", "Jak": "Gc", "1Pt": "1Pt", "2Pt": "2Pt",
    "1Joh": "1Gv", "2Joh": "2Gv", "3Joh": "3Gv", "Jud": "Gd",
    "Offb": "Ap",
}

# Portugiesisch: die \toc3-Felder der Biblia-Livre-Quelle, mit einer
# Korrektur. Die Quelle gibt sowohl Jó (Hiob) als auch João «Jo» — im
# Register waeren die beiden nicht auseinanderzuhalten. Der uebliche
# brasilianische Satz trennt sie ueber den Akzent: Jó gegen Jo.
PORTUGUESE_ABBREV = {
    "1Mo": "Gn", "2Mo": "Ex", "3Mo": "Lv", "4Mo": "Nm", "5Mo": "Dt",
    "Jos": "Js", "Ri": "Jz", "Rt": "Rt", "1Sam": "1Sm", "2Sam": "2Sm",
    "1Kon": "1Rs", "2Kon": "2Rs", "1Chr": "1Cr", "2Chr": "2Cr",
    "Esr": "Esd", "Neh": "Ne", "Est": "Est", "Hi": "Jó", "Ps": "Sl",
    "Spr": "Prv", "Pred": "Ec", "Hl": "Ct", "Jes": "Is", "Jer": "Jr",
    "Kla": "Lm", "Hes": "Ez", "Dan": "Dn", "Hos": "Os", "Joel": "Jl",
    "Am": "Am", "Ob": "Ob", "Jon": "Jn", "Mi": "Mq", "Nah": "Na",
    "Hab": "Hab", "Zeph": "Sf", "Hag": "Ag", "Sach": "Zc", "Mal": "Ml",
    "Mt": "Mt", "Mk": "Mc", "Lk": "Lc", "Joh": "Jo", "Apg": "At",
    "Rom": "Rm", "1Kor": "1Co", "2Kor": "2Co", "Gal": "Gl",
    "Eph": "Ef", "Phil": "Fp", "Kol": "Cl", "1Th": "1Ts", "2Th": "2Ts",
    "1Tim": "1Tm", "2Tim": "2Tm", "Tit": "Tt", "Phlm": "Flm",
    "Hebr": "Hb", "Jak": "Tg", "1Pt": "1Pd", "2Pt": "2Pd",
    "1Joh": "1Jo", "2Joh": "2Jo", "3Joh": "3Jo", "Jud": "Jd",
    "Offb": "Ap",
}

CHINESE_TRAD_ABBREV = {
    "1Mo": "創", "2Mo": "出", "3Mo": "利", "4Mo": "民",
    "5Mo": "申", "Jos": "書", "Ri": "士", "Rt": "得",
    "1Sam": "撒上", "2Sam": "撒下", "1Kon": "王上",
    "2Kon": "王下", "1Chr": "代上", "2Chr": "代下",
    "Esr": "拉", "Neh": "尼", "Est": "斯", "Hi": "伯",
    "Ps": "詩", "Spr": "箴", "Pred": "傳", "Hl": "歌",
    "Jes": "賽", "Jer": "耶", "Kla": "哀", "Hes": "結",
    "Dan": "但", "Hos": "何", "Joel": "珥", "Am": "摩",
    "Ob": "俄", "Jon": "拿", "Mi": "彌", "Nah": "鴻",
    "Hab": "哈", "Zeph": "番", "Hag": "該", "Sach": "亞",
    "Mal": "瑪", "Mt": "太", "Mk": "可", "Lk": "路",
    "Joh": "約", "Apg": "徒", "Rom": "羅", "1Kor": "林前",
    "2Kor": "林後", "Gal": "加", "Eph": "弗", "Phil": "腓",
    "Kol": "西", "1Th": "帖前", "2Th": "帖後",
    "1Tim": "提前", "2Tim": "提後", "Tit": "多",
    "Phlm": "門", "Hebr": "來", "Jak": "雅",
    "1Pt": "彼前", "2Pt": "彼後", "1Joh": "約壹",
    "2Joh": "約貳", "3Joh": "約參", "Jud": "猶",
    "Offb": "啟",
}

# Vereinfachte Kuerzel. Bis auf eine Ausnahme die Zeichenentsprechung der
# traditionellen Form; `add_book_names.py --check-zh` prueft das gegen die
# Zeichenabbildung, die sich aus cuv/cuvs der Datenbank selbst ergibt.
#
# Ausnahme 3Joh: 約參 wird mechanisch zu 约参 (wie in 参加), gemeint ist aber
# die foermliche Ziffer Drei. Die lautet vereinfacht 叁, also 约叁.
CHINESE_SIMP_ABBREV = {
    "1Mo": "创", "2Mo": "出", "3Mo": "利", "4Mo": "民",
    "5Mo": "申", "Jos": "书", "Ri": "士", "Rt": "得",
    "1Sam": "撒上", "2Sam": "撒下", "1Kon": "王上",
    "2Kon": "王下", "1Chr": "代上", "2Chr": "代下",
    "Esr": "拉", "Neh": "尼", "Est": "斯", "Hi": "伯",
    "Ps": "诗", "Spr": "箴", "Pred": "传", "Hl": "歌",
    "Jes": "赛", "Jer": "耶", "Kla": "哀", "Hes": "结",
    "Dan": "但", "Hos": "何", "Joel": "珥", "Am": "摩",
    "Ob": "俄", "Jon": "拿", "Mi": "弥", "Nah": "鸿",
    "Hab": "哈", "Zeph": "番", "Hag": "该", "Sach": "亚",
    "Mal": "玛", "Mt": "太", "Mk": "可", "Lk": "路",
    "Joh": "约", "Apg": "徒", "Rom": "罗", "1Kor": "林前",
    "2Kor": "林后", "Gal": "加", "Eph": "弗", "Phil": "腓",
    "Kol": "西", "1Th": "帖前", "2Th": "帖后",
    "1Tim": "提前", "2Tim": "提后", "Tit": "多",
    "Phlm": "门", "Hebr": "来", "Jak": "雅",
    "1Pt": "彼前", "2Pt": "彼后", "1Joh": "约壹",
    "2Joh": "约贰", "3Joh": "约叁", "Jud": "犹",
    "Offb": "启",
}

# Sprachkennung -> Kuerzeltabelle. Die Spalte heisst abbrev_<kennung mit _>.
# Anders als bei den Namen ist auch Deutsch dabei: `book.name` traegt den
# deutschen Namen, aber `book.code` ist ausdruecklich kein Kuerzel.
BOOK_ABBREV_TABLES = {
    "de": GERMAN_ABBREV,
    "en": ENGLISH_ABBREV,
    "es": SPANISH_ABBREV,
    "fr": FRENCH_ABBREV,
    "it": ITALIAN_ABBREV,
    "pt": PORTUGUESE_ABBREV,
    "zh_hant": CHINESE_TRAD_ABBREV,
    "zh_hans": CHINESE_SIMP_ABBREV,
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
    "riv": ("it", "Riveduta 1927 (Giovanni Luzzi). Gemeinfrei."),
    # CC BY 4.0 verlangt die Namensnennung; sie steht deshalb hier und
    # erscheint dadurch im Impressum der App.
    "blivre": ("pt", "B\u00edblia Livre, \u00a9 2018 Diego Santos, "
                     "Mario S\u00e9rgio, Marco Teles. Lizenziert unter "
                     "Creative Commons Attribution 4.0 (CC BY 4.0)."),
}

# Reihenfolge, in der die Uebersetzungen in der App erscheinen (sort_order).
#
# Sie ist keine Kosmetik: die App waehlt beim allerersten Start die **erste
# Uebersetzung der Anzeigesprache** aus dieser Reihenfolge, und dieselbe steht
# in der Auswahl zuoberst. Wer fuer eine Sprache eine andere Vorgabe will,
# aendert diese Liste — nicht den Swift-Code.
#
# Je Sprache steht die Leitausgabe vorn: Deutsch Elberfelder, Englisch King
# James, Chinesisch die traditionelle Ausgabe. Codes, die hier fehlen, haengen
# sich hinten in der Reihenfolge der Quelle an.
TRANSLATION_ORDER = [
    "elb", "kjv", "dar", "slt", "sch1951", "lut", "meng",
    "cuv", "cuvs", "rvr1909", "lsg", "riv", "blivre", "bsb",
]

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
    "riv":  ("RIV", "Riveduta 1927"),
    "blivre": ("BLV", "B\u00edblia Livre"),
}

# ---------------------------------------------------------------------------
# Tabelle `curated`: das Themenregister.
#
# Steht hier und nicht nur im DDL des Konverters, weil `update_curated.py` die
# Tabelle neu aufbauen koennen muss — und zwar in genau derselben Gestalt.
#
# `topic` ist deutsch und zugleich der Schluessel, wie `book.code`. Wie ein
# Thema geschrieben wird, steht nicht hier, sondern in
# Resources/Localizable.xcstrings unter «topic.<deutscher Wert>»: die
# Schreibweise ist Oberflaeche, die Liste selbst ist Inhalt.
# ---------------------------------------------------------------------------

CURATED_DDL = """
CREATE TABLE curated (
    id      INTEGER PRIMARY KEY,
    book_id INTEGER NOT NULL,
    chapter INTEGER NOT NULL,
    verse   INTEGER NOT NULL,
    topic   TEXT
);

CREATE UNIQUE INDEX idx_curated_ref ON curated (book_id, chapter, verse);
"""
