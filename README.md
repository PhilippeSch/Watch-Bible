# Bible Watch — Projektdateien

Eigenständige Apple-Watch-App für Bibelverse. Zwei Funktionen: zufälliger Vers mit Weiterschalten, und gezieltes Nachschlagen über Buch → Kapitel → Vers. Deutsch und Englisch. Kein Netzwerk, kein Konto, kein iPhone nötig.

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

### Ein Wort zu synchronisierten Ordnern

Das Projekt liegt unter `~/Documents/X-Code Projects/Watch Bible`. Auch der Documents-Ordner wird auf diesem Rechner von einem File Provider synchronisiert (nachgewiesen am `com.apple.fileprovider`-Attribut auf Build-Produkten) — Quelldateien sind unkritisch, aber Derived Data gehört deshalb zwingend nach `~/Library/Developer/` (siehe Merkpunkte oben).

Der Pfad enthält Leerzeichen. In Befehlen also immer in Anführungszeichen setzen.

## Die zwei Datenbanken

Eine davon auswählen und **als `bible.sqlite` ins Projekt kopieren**. Beide enthalten dieselben 66 Bücher, 1'189 Kapitel und dieselbe kuratierte Auswahl. Sie unterscheiden sich nur in den enthaltenen Übersetzungen.

| Datei | Übersetzungen | Verse | Grösse | Verwendung |
|---|---|---:|---:|---|
| `bible_frei_9-Uebersetzungen.sqlite` | 9 Übersetzungen in 6 Sprachen | 279'863 | 43.5 MB | **Für die Veröffentlichung.** Alle frei verwendbar. |
| `bible_mit-SLT_10-Uebersetzungen.sqlite` | zusätzlich Schlachter 2000 | 311'034 | 48.8 MB | Nur mit schriftlicher Genehmigung der Genfer Bibelgesellschaft. |

| Kürzel | Übersetzung | Sprache | Verse |
|---|---|---|---:|
| ELB | Elberfelder 1905 | Deutsch | 31'103 |
| SCH | Schlachter 1951 | Deutsch | 31'172 |
| BSB | Berean Standard Bible | Englisch | 31'084 |
| KJV | King James Version | Englisch | 31'102 |
| DAR | Darby Bible | Englisch | 30'996 |
| RVR | Reina-Valera 1909 | Spanisch | 31'102 |
| LSG | Louis Segond 1910 | Französisch | 31'102 |
| CUV | 和合本（繁體） | Chinesisch traditionell | 31'101 |
| CUVS | 和合本（简体） | Chinesisch vereinfacht | 31'101 |

Die App lädt die Datei unter dem Ressourcennamen **`bible`** — welche der beiden du nimmst, benennst du beim Einfügen ins Xcode-Projekt entsprechend um. `BibleDatabase.swift` ändert sich dabei nicht.

Achtung bei einem Wechsel: die Übersetzungen bekommen ihre `id` nach Reihenfolge in der Datenbank. In der grossen Datei ist Schlachter Nummer 1 und Leitübersetzung, in der kleinen Elberfelder. Deshalb liest die App Übersetzungen und Leitübersetzung immer zur Laufzeit aus der Datenbank und nie aus fest verdrahteten Zahlen.

## Alle Dateien

### Daten
| Datei | Inhalt |
|---|---|
| `bible_frei_9-Uebersetzungen.sqlite` | Datenbank, frei verwendbare Übersetzungen |
| `bible_mit-SLT_10-Uebersetzungen.sqlite` | Datenbank inklusive Schlachter 2000 |
| `cuv_simplified.xml` | Vereinfachte Fassung des 和合本, maschinell aus der traditionellen erzeugt (siehe unten) |
| `quotepas_to_sqlite.py` | Konverter. Liest die LaTeX-Quelldatei, zusätzlich OSIS-XML (`--osis CODE=DATEI`) und USFM-Verzeichnisse (`--usfm CODE=ORDNER`). Im Repository behalten, damit die Datenbank reproduzierbar bleibt. |
| `curated_verses.json` | 180 Kernverse aus 50 Büchern für den kuratierten Zufallsmodus |
| `test_fixtures.json` | Erwartungswerte für Unit-Tests, erzeugt gegen `bible_frei_9-Uebersetzungen.sqlite`, inklusive aller Versifikations-Abweichungen für fünf Übersetzungspaare |

### Dokumente
| Datei | Inhalt |
|---|---|
| `Konzept_BibelWatch.md` | Architektur, Schema, Abfragen, Meilensteinplan, App-Store-Checkliste |
| `Designspezifikation.md` | Farben, Typografie, Geometrie, Bildschirme, Zweisprachigkeit — verbindlich |
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
| `Resources/Localizable.xcstrings` | 45 Schlüssel, Deutsch und Englisch vollständig |
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
        --osis sch1951=sch1951.xml --osis cuv=chi.xml --osis cuvs=cuv_simplified.xml \
        --osis rvr1909=sparv.xml --osis lsg=fren.xml --usfm bsb=./bsb_usfm \
        --exclude slt --curated curated_verses.json --swiss \
        -o bible_frei_9-Uebersetzungen.sqlite

# zusätzlich mit Schlachter 2000
python3 quotepas_to_sqlite.py bible.db \
        --osis sch1951=sch1951.xml --osis cuv=chi.xml --osis cuvs=cuv_simplified.xml \
        --osis rvr1909=sparv.xml --osis lsg=fren.xml --usfm bsb=./bsb_usfm \
        --curated curated_verses.json --swiss \
        -o bible_mit-SLT_10-Uebersetzungen.sqlite
```

## Offene Punkte vor der Veröffentlichung

**Schlachter 1951 aus der richtigen Quelle beziehen.** Die mitgelieferten Datenbanken sind aus `sch1951.xml` von `github.com/gratis-bible/bible` erzeugt. Diese Datei stammt aus dem Jahr 2009 und trägt im Kopf einen älteren, engeren Lizenzvermerk («Nutzung nur erlaubt mit MyBible»). Die Genfer Bibelgesellschaft hat den Text inzwischen unter CC BY 4.0 gestellt; diese Fassung liegt bei **ebible.org/deu1951**. Für einen sauberen Nachweis lade dort die USFM-Ausgabe herunter, wandle sie nach OSIS und erzeuge die Datenbank neu — derselbe Befehl, dieselbe Ausgabe. Der Text ist inhaltlich geprüft (siehe unten), es geht allein um den Lizenzweg.

**Namensnennung ist Pflicht.** CC BY 4.0 verlangt sie. Die Zeile steht bereits in `translation.copyright` und erscheint dadurch automatisch im Impressum.

**Der `--swiss`-Schalter ist eine Bearbeitung.** Er wandelt ß zu ss, auch in Schlachter 1951. CC BY 4.0 verlangt, Änderungen kenntlich zu machen — also entweder im Impressum vermerken oder für diese Übersetzung darauf verzichten.

**Schlachter 2000** bleibt urheberrechtlich geschützt (© 2000 Genfer Bibelgesellschaft). Mit Schlachter 1951 in der freien Datenbank brauchst du sie nicht mehr.

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
