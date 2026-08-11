# Bible Watch — Projektdateien

Eigenständige Apple-Watch-App für Bibelverse. Zwei Funktionen: zufälliger Vers mit Weiterschalten, und gezieltes Nachschlagen über Buch → Kapitel → Vers. Oberfläche in sechs Sprachen — in jeder, für die eine Bibelübersetzung mitgeliefert wird. Kein Netzwerk, kein Konto, kein iPhone nötig.

## Ausgangslage

Ein erster Prototyp steht bereits. Es geht also **nicht** darum, das Projekt neu aufzusetzen, sondern den bestehenden Stand mit den Unterlagen hier abzugleichen und schrittweise darauf zu bringen. Der gelieferte Code ist ein geprüfter Entwurf, kein Ersatz für Vorhandenes: wo der Prototyp schon etwas Gleichwertiges hat, bleibt es.

Projekt: `~/Library/CloudStorage/OneDrive-Persönlich/Dokumente/Programme/Watch Bible/`

Claude Code im **Projektwurzelverzeichnis** starten, also dort, wo die `.xcodeproj` liegt — eine Ebene über `Watch Bible Watch App/`. Aus dem Zielordner heraus sieht Claude Code die Projektdatei nicht und kann nicht bauen.

### Erster Auftrag an Claude Code

> Lies `README.md`, `CLAUDE.md`, `Konzept_BibelWatch.md` und `Designspezifikation.md`. **Ändere noch nichts.**
>
> Verschaff dir zuerst einen Überblick über den bestehenden Prototyp: welche Targets, welche Dateien, welche Bildschirme, wie die Datenbank angebunden ist, ob lokalisiert wird. Baue ihn einmal (siehe «Bauen und prüfen») und berichte, ob er durchläuft.
>
> Erstelle dann eine Abweichungsliste in `MIGRATION.md`: was schon der Spezifikation entspricht, was abweicht, was fehlt. Sortiere nach Aufwand und Risiko und schlag eine Reihenfolge vor. Erst wenn ich die freigebe, fängst du an zu ändern.

Danach jeweils ein Punkt der Liste pro Durchgang, mit einem Build am Ende jedes Durchgangs.

### Reihenfolge, wenn die Liste steht

Die Datenschicht zuerst — sie bestimmt alles andere. `Data/Models.swift`, `Data/BibleDatabase.swift` und `Data/BibleRepository.swift` übernehmen, statt eine vorhandene Lösung anzupassen: die SQL-Strings und Spaltenindizes darin sind gegen die echte Datenbank verifiziert. Dann `Shared/Localization.swift` und die String Catalogs, dann die Oberfläche nach `Designspezifikation.md`, zuletzt Widget und Privacy-Manifest.

## Bauen und prüfen

Claude Code soll nach jeder Änderung selbst kompilieren und die Fehler selbst lesen, statt sie dir zu melden. Alle Befehle im Projektwurzelverzeichnis.

```bash
# Einmalig prüfen: zeigen die Kommandozeilenwerkzeuge auf Xcode?
xcode-select -p          # muss auf /Applications/Xcode.app/... zeigen
# falls nicht:  sudo xcode-select -s /Applications/Xcode.app

# Schemata und Targets des Projekts auflisten
xcodebuild -list -project "Watch Bible.xcodeproj"

# Verfügbare Watch-Simulatoren
xcrun simctl list devices available | grep -i watch

# Bauen. Nur die Fehler anzeigen, Exit-Code sagt, ob es geklappt hat.
xcodebuild -project "Watch Bible.xcodeproj" \
           -scheme "Watch Bible Watch App" \
           -destination 'generic/platform=watchOS Simulator' \
           -derivedDataPath "$HOME/Library/Developer/WatchBible-build" \
           -quiet build 2>&1 | grep -E "error:|warning:|BUILD"

# Unit-Tests gegen test_fixtures.json (braucht einen konkreten Simulator)
xcodebuild -project "Watch Bible.xcodeproj" \
           -scheme "Watch Bible Watch App" \
           -destination 'platform=watchOS Simulator,name=Apple Watch Ultra 3 (49mm)' \
           -derivedDataPath "$HOME/Library/Developer/WatchBible-build" \
           test 2>&1 | grep -E "error:|failed|passed"
```

Merkpunkte:

- `generic/platform=watchOS Simulator` genügt zum Bauen und vermeidet, dass ein Gerätename fest verdrahtet wird. Zum **Testen** braucht es einen konkreten Simulator aus der `simctl`-Liste.
- **Derived Data nie in den Projektordner legen** (kein `-derivedDataPath ./build`): sowohl OneDrive- als auch Documents-Ordner werden auf diesem Rechner von einem File Provider synchronisiert, der den Build-Produkten erweiterte Attribute anhängt — codesign bricht dann mit «resource fork, Finder information, or similar detritus not allowed» ab. `~/Library/Developer/WatchBible-build` liegt ausserhalb jeder Synchronisierung.
- Fehlschläge erkennt man am Exit-Code (`$?` ungleich 0), nicht nur an der Ausgabe.
- Der Build braucht eine installierte watchOS-Simulator-Laufzeit. Fehlt sie, meldet `xcodebuild` das eindeutig — dann in Xcode unter Einstellungen → Components nachinstallieren.
- Layout auf der Uhr lässt sich damit **nicht** beurteilen. Kompilieren heisst nicht, dass es gut aussieht: Bildschirme weiterhin im Simulator ansehen.

### Die Build-Nummer setzt sich selbst

Das Target «Watch Bible Watch App» hat als letzte Build-Phase ein Skript «Set Build Number». Es ruft `xcrun agvtool new-version` mit dem aktuellen Zeitstempel im Format `YYYYMMDDHHMM` auf und schreibt damit `CURRENT_PROJECT_VERSION` in **alle** Targets — App, Widget und Tests bleiben so automatisch auf derselben Nummer. `CFBundleVersion` kommt bei allen Targets aus `GENERATE_INFOPLIST_FILE`, also braucht es keine Handarbeit an Info.plist-Dateien mehr. Dasselbe Verfahren läuft im Projekt Swiss-News.

Vier Punkte dazu:

- **Beim Archivieren läuft das Skript bewusst nicht** (es prüft `$ACTION = install` und steigt sofort aus). Schreibt es während eines Archive-Vorgangs in die Projektdatei, lädt Xcode das Projekt mitten im Lauf neu und stoppt ihn — im Log steht dann nur «Build stopped», der Issue Navigator bleibt leer und es entsteht kein Archiv. Das Archiv erhält darum die Nummer des letzten normalen Builds. Wer vor dem Hochladen eine frische Nummer will, drückt vorher einmal ⌘B.
- Das Skript schreibt in `project.pbxproj`, also **verändert jeder Build die Projektdatei**. Ein `git status` nach dem Bauen zeigt sie darum immer als geändert.
- Der Zeitstempel wirkt erst im **nächsten** Build: Xcode löst die Build-Einstellungen zu Beginn auf, das Bundle des laufenden Builds trägt darum noch die Nummer vom vorherigen Lauf. Für den App Store genügt das, die Nummer steigt monoton.
- Dafür ist `ENABLE_USER_SCRIPT_SANDBOXING` für dieses eine Target auf `NO` gesetzt (projektweit bleibt es `YES`) — die Sandbox verbietet das Schreiben ins Projektverzeichnis. `VERSIONING_SYSTEM = apple-generic` auf Projektebene ist die Voraussetzung dafür, dass `agvtool` überhaupt greift.

### Ein Wort zu synchronisierten Ordnern

Das Projekt liegt unter `~/Documents/X-Code Projects/Watch Bible`. Auch der Documents-Ordner wird auf diesem Rechner von einem File Provider synchronisiert (nachgewiesen am `com.apple.fileprovider`-Attribut auf Build-Produkten) — Quelldateien sind unkritisch, aber Derived Data gehört deshalb zwingend nach `~/Library/Developer/` (siehe Merkpunkte oben).

Der Pfad enthält Leerzeichen. In Befehlen also immer in Anführungszeichen setzen.

## Die zwei Datenbanken

Eine davon auswählen und **als `bible.sqlite` ins Projekt kopieren**. Beide enthalten dieselben 66 Bücher, 1'189 Kapitel und dieselbe kuratierte Auswahl. Sie unterscheiden sich nur in den enthaltenen Übersetzungen.

| Datei | Übersetzungen | Verse | Grösse | Verwendung |
|---|---|---:|---:|---|
| `bible_frei_10-Uebersetzungen.sqlite` | 10 Übersetzungen in 6 Sprachen | 311'034 | 48.5 MB | **Für die Veröffentlichung.** Alle frei verwendbar. |
| `bible_mit-SLT_11-Uebersetzungen.sqlite` | zusätzlich Schlachter 2000 | 342'205 | 53.8 MB | Nur mit schriftlicher Genehmigung der Genfer Bibelgesellschaft. |

| Kürzel | Übersetzung | Sprache | Verse |
|---|---|---|---:|
| ELB | Elberfelder 1905 | Deutsch | 31'103 |
| SCH | Schlachter 1951 | Deutsch | 31'172 |
| LUT | Luther 1912 | Deutsch | 31'171 |
| BSB | Berean Standard Bible | Englisch | 31'084 |
| KJV | King James Version | Englisch | 31'102 |
| DAR | Darby Bible | Englisch | 30'996 |
| RVR | Reina-Valera 1909 | Spanisch | 31'102 |
| LSG | Louis Segond 1910 | Französisch | 31'102 |
| CUV | 和合本（繁體） | Chinesisch traditionell | 31'101 |
| CUVS | 和合本（简体） | Chinesisch vereinfacht | 31'101 |

Die App lädt die Datei unter dem Ressourcennamen **`bible`** — welche der beiden du nimmst, benennst du beim Einfügen ins Xcode-Projekt entsprechend um. `BibleDatabase.swift` ändert sich dabei nicht.

Achtung bei einem Wechsel: die Übersetzungen bekommen ihre `id` nach Reihenfolge in der Datenbank. In der grossen Datei ist Schlachter Nummer 1 und Leitübersetzung, in der kleinen Elberfelder. Deshalb liest die App Übersetzungen und Leitübersetzung immer zur Laufzeit aus der Datenbank und nie aus fest verdrahteten Zahlen.

**Die Reihenfolge bestimmt auch die Vorgabe.** Beim allerersten Start wählt die App die erste Übersetzung der Anzeigesprache in Datenbankreihenfolge (`sort_order`), und dieselbe steht in der Auswahl zuoberst. Wer für eine Sprache eine andere Vorgabe will, ändert nicht den Code, sondern die Liste `TRANSLATION_ORDER` in `tools/quotepas_to_sqlite.py` — die einzige Stelle, an der die Reihenfolge festgelegt ist. `--include` hat weiterhin Vorrang, wenn er angegeben wird.

Für eine bereits erzeugte Datenbank trägt `tools/reorder_translations.py` dieselbe Reihenfolge nach, ohne sie neu zu bauen:

```bash
python3 tools/reorder_translations.py "Watch Bible Watch App/Resources/bible.sqlite" --check
python3 tools/reorder_translations.py "Watch Bible Watch App/Resources/bible.sqlite"
```

Es ändert **nur** `sort_order`. `translation.id`, `first_verse_id`/`last_verse_id` und die Verstabelle bleiben unberührt — sonst müssten 300'000 Zeilen umgeschrieben werden und `test_fixtures.json` würde ungültig. Danach können `id` und `sort_order` auseinanderlaufen (in der ausgelieferten Datei hat KJV `id` 3 und `sort_order` 2); die App liest ausschliesslich `ORDER BY sort_order`.

**Nach einem Wechsel einmal die Buchnamen prüfen.** Eine Datenbank aus einem Konverterlauf vor dem 11. August 2026 hat die Spalten `name_es`, `name_fr`, `name_zh_hant`, `name_zh_hans` noch nicht. Die App läuft trotzdem — sie zeigt für diese Sprachen dann aber den deutschen Buchnamen:

```bash
python3 tools/add_book_names.py "Watch Bible Watch App/Resources/bible.sqlite" --check
python3 tools/add_book_names.py "Watch Bible Watch App/Resources/bible.sqlite"
```

## Alle Dateien

### Daten
| Datei | Inhalt |
|---|---|
| `bible_frei_10-Uebersetzungen.sqlite` | Datenbank, frei verwendbare Übersetzungen |
| `bible_mit-SLT_11-Uebersetzungen.sqlite` | Datenbank inklusive Schlachter 2000 |
| `cuv_simplified.xml` | Vereinfachte Fassung des 和合本, maschinell aus der traditionellen erzeugt (siehe unten) |
| `quotepas_to_sqlite.py` | Konverter. Liest die LaTeX-Quelldatei, zusätzlich OSIS-XML (`--osis CODE=DATEI`) und USFM-Verzeichnisse (`--usfm CODE=ORDNER`). Im Repository behalten, damit die Datenbank reproduzierbar bleibt. Führt auch die Buchnamen aller sechs Oberflächensprachen. |
| `reorder_translations.py` | Setzt `translation.sort_order` einer bestehenden Datenbank auf `TRANSLATION_ORDER` aus dem Konverter — damit auch die Vorgabeübersetzung je Sprache. `--check` prüft, ohne zu schreiben. |
| `add_book_names.py` | Trägt die Buchnamen der Oberflächensprachen (`name_es`, `name_fr`, `name_zh_hant`, `name_zh_hans`) in eine bestehende Datenbank nach und setzt die Schema-Version auf 2. Dieselben Tabellen wie im Konverter — für den Fall, dass die Quelldateien nicht zur Hand sind. `--check` prüft, ohne zu schreiben. |
| `curated_verses.json` | 180 Kernverse aus 50 Büchern für den kuratierten Zufallsmodus |
| `test_fixtures.json` | Erwartungswerte für Unit-Tests, erzeugt gegen `bible_frei_10-Uebersetzungen.sqlite`: 28 Stichproben und alle Versifikations-Abweichungen für vierzehn Übersetzungspaare |

### Dokumente
| Datei | Inhalt |
|---|---|
| `Konzept_BibelWatch.md` | Architektur, Schema, Abfragen, Meilensteinplan, App-Store-Checkliste |
| `Designspezifikation.md` | Farben, Typografie, Geometrie, Bildschirme, Mehrsprachigkeit — verbindlich |
| `Design_TagNacht.html` | Bildschirmentwürfe, massstabsgetreu auf 45 mm |
| `CLAUDE.md` | Projektanweisungen, gehört ins Repository-Wurzelverzeichnis |

### Code
| Datei | Inhalt |
|---|---|
| `Data/Models.swift` | `Translation`, `Book`, `Verse`, `VerseReference`, `VerseResolution` |
| `Data/BibleDatabase.swift` | Actor um die sqlite3-C-API, schreibgeschützt, Statement-Cache |
| `Data/BibleRepository.swift` | Alle Abfragen, Zufallsvers, Vers des Tages, Versifikationslogik |
| `Shared/AppSettings.swift` | Einstellungen über `@AppStorage` |
| `Shared/Localization.swift` | Anzeigesprache, Übersetzungsvorgabe, Buchnamen, Stellenformat |
| `Resources/Localizable.xcstrings` | 58 Schlüssel, alle sechs Oberflächensprachen vollständig |
| `Resources/InfoPlist.xcstrings` | App-Name «Bibel» / «Bible» |
| `PrivacyInfo.xcprivacy` | Privacy-Manifest, ein Eintrag für UserDefaults |

## Stand der Prüfung

**Verifiziert:** Datenbanken, Konverter, alle SQL-Abfragen (Abfragepläne ohne Table Scan), kuratierte Liste, Rastergeometrie, String Catalogs als JSON, Privacy-Manifest als Plist.

**Nicht kompiliert:** sämtlicher Swift-Code. Es stand kein Compiler zur Verfügung. Die SQL-Strings und Spaltenindizes darin stimmen nachweislich mit der Datenbank überein, die Swift-Syntax drumherum ist ungetestet. Genau dafür ist der Abschnitt «Bauen und prüfen» da: Claude Code soll die Dateien einsetzen, bauen und die Meldungen des Compilers selbst abarbeiten — ohne die verifizierten SQL-Strings anzutasten.

**Nicht vorbereitet:** SwiftUI-Ansichten und Widget-Target. Die Xcode-Projektdatei existiert im Prototyp bereits und wird nicht ersetzt.

## So werden die Datenbanken erzeugt

```bash
# frei verwendbar, für die Veröffentlichung
python3 quotepas_to_sqlite.py bible.db \
        --osis sch1951=sch1951.xml --osis lut=luth1912.xml \
        --osis cuv=chi.xml --osis cuvs=cuv_simplified.xml \
        --osis rvr1909=sparv.xml --osis lsg=fren.xml --usfm bsb=./bsb_usfm \
        --exclude slt --curated curated_verses.json --swiss \
        -o bible_frei_10-Uebersetzungen.sqlite

# zusätzlich mit Schlachter 2000
python3 quotepas_to_sqlite.py bible.db \
        --osis sch1951=sch1951.xml --osis lut=luth1912.xml \
        --osis cuv=chi.xml --osis cuvs=cuv_simplified.xml \
        --osis rvr1909=sparv.xml --osis lsg=fren.xml --usfm bsb=./bsb_usfm \
        --curated curated_verses.json --swiss \
        -o bible_mit-SLT_11-Uebersetzungen.sqlite
```

Die Reihenfolge der Quellenangaben bestimmt `translation.id` und `sort_order`. Luther steht deshalb hinter Schlachter, damit die drei deutschen Übersetzungen zusammenliegen. Wer sie verschiebt, verschiebt alle nachfolgenden `verse.id` — die App liest beides zur Laufzeit aus der Datenbank, `test_fixtures.json` muss dann aber nachgerechnet werden.

## Offene Punkte vor der Veröffentlichung

**Schlachter 1951 aus der richtigen Quelle beziehen.** Die mitgelieferten Datenbanken sind aus `sch1951.xml` von `github.com/gratis-bible/bible` erzeugt. Diese Datei stammt aus dem Jahr 2009 und trägt im Kopf einen älteren, engeren Lizenzvermerk («Nutzung nur erlaubt mit MyBible»). Die Genfer Bibelgesellschaft hat den Text inzwischen unter CC BY 4.0 gestellt; diese Fassung liegt bei **ebible.org/deu1951**. Für einen sauberen Nachweis lade dort die USFM-Ausgabe herunter, wandle sie nach OSIS und erzeuge die Datenbank neu — derselbe Befehl, dieselbe Ausgabe. Der Text ist inhaltlich geprüft (siehe unten), es geht allein um den Lizenzweg.

**Namensnennung ist Pflicht.** CC BY 4.0 verlangt sie. Die Zeile steht bereits in `translation.copyright` und erscheint dadurch automatisch im Impressum.

**Der `--swiss`-Schalter ist eine Bearbeitung.** Er wandelt ß zu ss, auch in Schlachter 1951. CC BY 4.0 verlangt, Änderungen kenntlich zu machen — also entweder im Impressum vermerken oder für diese Übersetzung darauf verzichten.

**Schlachter 2000** bleibt urheberrechtlich geschützt (© 2000 Genfer Bibelgesellschaft). Mit Schlachter 1951 in der freien Datenbank brauchst du sie nicht mehr.

## Herkunft der Lutherbibel

Aus `de/luth1912.xml` von `github.com/gratis-bible/bible`, dessen OSIS-Kopf «Public Domain» führt. Es ist die Revision von **1912**, deren Schutzfrist abgelaufen ist — nicht die Lutherbibel 1984 oder 2017, die bei der Deutschen Bibelgesellschaft geschützt sind. 66 Bücher, 1'189 Kapitel, 31'171 Verse, keine XML-Reste, keine leeren Verse.

**Gegenprobe an einer zweiten Quelle.** Dieselbe Revision liegt bei **ebible.org/deu1912** als USFM. Von 31'171 Verstexten stimmen 29'871 zeichengleich mit der OSIS-Ausgabe überein; es ist also nachweislich derselbe Revisionsstand. Die Restunterschiede sind auf beiden Seiten kleine Zeichensetzungsschäden («um um das ganze Mohrenland» bei ebible, ein hängendes Fragezeichen in 1Mo 5,1 bei gratis-bible) — sowie ein systematischer Unterschied, der die Wahl entschieden hat.

**Verwendet wird die OSIS-Ausgabe, weil sie deutsch zählt.** Die ebible-Fassung ist auf die englische Versifikation umgestellt und trägt die Originalnummer als Präfix im Verstext (`[5:27] Die Kinder Levis waren…` unter 1Chr 6,1). Das wäre für diese App die falsche Grundlage: die deutsche Zählung ist genau das, was `BibleRepository.resolve` gegen die englischen Übersetzungen abgleicht. Luther zählt Joel mit vier und Maleachi mit drei Kapiteln, Elberfelder umgekehrt — Joel 4 gibt es in der ELB nicht, Maleachi 4 nicht in der Luther. Solche Kapitel müssen `.unavailable` melden. Gegen Schlachter 1951 unterscheiden sich nur drei Kapitel in der Verszahl, gegen Elberfelder 122, gegen die KJV 140; alle Fälle stehen in `test_fixtures.json`.

**Drei dokumentierte Eingriffe am Quelltext**, jeder im Konverter aufgeführt und bei jedem Lauf gemeldet:

- `SOURCE_FIXES`: In 1Mo 5,1 hängt ein Fragezeichen hinter dem Semikolon, mit dem der Vers endet. Gedruckt und in der ebible-Ausgabe steht dort nur das Semikolon.
- `TYPOGRAPHY_FIXUPS`: 24 Verse tragen ein Leerzeichen vor dem Satzzeichen, wo im Druck eine Fussnotenmarke stand («heisst Hiddekel , das fliesst vor Assyrien»).
- `TYPOGRAPHY_FIXUPS`: Das Modul setzt ASCII-Anführungszeichen. In 586 Versen sind sie auf « » gesetzt, weil quotepas-Quelle und Schlachter 1951 Guillemets verwenden und die deutschen Übersetzungen sonst zwei Systeme mischten. Ein `"` öffnet am Textanfang und nach Leerzeichen oder öffnender Klammer, sonst schliesst es; nicht über Paare gezählt, weil 177 Zitate über Versgrenzen laufen und in sechs Kapiteln das öffnende Zeichen in der Quelle fehlt.

Beide Eingriffe sind an den Übersetzungscode gebunden und nicht allgemein: im Französischen gehört das Leerzeichen vor `;:!?` zur Rechtschreibung, und die übrigen Quellen bringen ihre Anführungszeichen typografisch mit. Da die Revision gemeinfrei ist, verlangt keine Lizenz einen Änderungsvermerk — anders als bei Schlachter 1951 (siehe oben).

## Herkunft der Berean Standard Bible

Aus `github.com/usfm-bible/examples.bsb` — einer USFM-Aufbereitung des offiziellen Textes vom 26.&nbsp;August 2024, deren `metadata.json` `"publicDomain": true` führt. <cite index="58-1">Die Rechteinhaber haben den Text am 30. April 2023 in die Public Domain entlassen; eine Lizenzierung ist für keine Verwendung nötig.</cite> Fussnoten und Querverweise sind entfernt, `\nd`-Auszeichnungen für den Gottesnamen in Grossbuchstaben gesetzt.

Zwei Auffälligkeiten in dieser Ausgabe: die Datei zu Prediger hat keinen `\id`-Marker, der Konverter bestimmt das Buch dort aus dem Dateinamen und meldet das. Und der Text verwendet U+02BC als Apostroph, was der Konverter auf das übliche U+2019 vereinheitlicht.

## Herkunft von Reina-Valera und Louis Segond

Beide aus `github.com/gratis-bible/bible`: `es/sparv.xml` und `fr/fren.xml`.

**Reina-Valera 1909** — die klassische spanische Protestantenbibel und direkte Vorläuferin der RVR1960, die selbst bei den Sociedades Bíblicas Unidas geschützt ist. Erkennbar an der alten Rechtschreibung: «crió Dios los cielos», «á su Hijo unigénito». Die Datei `es/rva.xml` aus demselben Repository habe ich **nicht** genommen: das ist die Reina-Valera Actualizada 1989 von Editorial Mundo Hispano und geschützt. Die spanische Quelle enthielt `<note>`-Elemente; sie sind entfernt.

**Louis Segond 1910** — die Standardbibel des französischsprachigen Protestantismus. Segond starb 1885, die Revision von 1910 ist gemeinfrei; der OSIS-Kopf führt entsprechend «Public Domain». Nicht verwechseln mit der Nouvelle Édition de Genève 1979 oder Segond 21, die beide geschützt sind.

Beide folgen der englischen Verszählung: null Abweichungen gegen die KJV in allen 1'189 Kapiteln.

## Herkunft des 和合本

Aus `chi.xml` von `github.com/gratis-bible/bible`, dessen OSIS-Kopf `Public Domain` führt. <cite index="57-1">Die Chinese Union Version erschien 1919; ihr Urheberrecht ist abgelaufen.</cite> Es ist die Originalfassung von 1919, nicht das 新標點和合本 von 1988 — dessen Rechte liegen bei der Hong Kong Bible Society. Erkennbar an der alten Interpunktion mit 、．〔〕 statt ，「」（）.

Die vereinfachte Fassung ist **nicht** die Datei `chius.xml` aus demselben Repository: die ist eine andere Ausgabe mit moderner Interpunktion und enthält zudem einen sinnentstellenden Fehler (Mt 5,3 «虚心的人冇福了» statt 有福了 — «nicht gesegnet» statt «gesegnet»). Stattdessen ist `cuv_simplified.xml` mit OpenCC aus der geprüften traditionellen Fassung erzeugt:

```python
import opencc
conv = opencc.OpenCC('t2s')
src = open('chi.xml', encoding='utf-8').read()
head, sep, body = src.partition('</header>')
open('cuv_simplified.xml','w',encoding='utf-8').write(head+sep+conv.convert(body))
```

Die Richtung traditionell → vereinfacht ist nahezu eindeutig und damit unkritisch; umgekehrt wäre sie es nicht.

**Zwei dokumentierte Korrekturen** am Quelltext, beide in `SOURCE_FIXES` im Konverter aufgeführt und bei jedem Lauf gemeldet: In 2Mo 32,32 gab das Modul die Aposiopese als ASCII-Punkte wieder, gedruckt steht dort ……. In Jes 1,23 war ein Schriftzeichen verlorengegangen und durch ein Apostroph ersetzt; gedruckt steht 贓私. Danach enthält der chinesische Text kein einziges ASCII-Zeichen mehr.

**Der Ehrfurchtsabstand bleibt erhalten.** Vor 神 steht in der CUV ein ideographisches Leerzeichen U+3000 — in 3'337 Versen. Der Konverter entfernt nur ASCII-Leerzeichen zwischen Schriftzeichen und lässt U+3000 stehen.

## Prüfung von Schlachter 1951

Gegenprobe gegen die Schlachter 2000 in derselben Quelle: von 400 zufälligen Versen weichen 358 ab. Es ist also nachweislich die Fassung von 1951 und nicht versehentlich die geschützte Revision. 66 Bücher, 1'189 Kapitel, 31'172 Verse, keine XML-Reste, keine leeren Verse.
