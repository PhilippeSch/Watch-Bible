# Watch Bible

Eine eigenständige Bibel-App für die Apple Watch. Zehn Übersetzungen in sechs Sprachen liegen als schreibgeschützte SQLite-Datei im App-Bundle — kein iPhone nötig, kein Konto, kein Netzwerk, keine Datenerfassung.

<p>
  <img src="AppStore/Screenshots-de/02-Zufallsvers.png" width="180" alt="Zufallsvers">
  <img src="AppStore/Screenshots-de/01-Leseansicht.png" width="180" alt="Leseansicht">
  <img src="AppStore/Screenshots-de/03-Buchliste-Register.png" width="180" alt="Buchliste mit Register">
  <img src="AppStore/Screenshots-de/04-Versraster.png" width="180" alt="Versraster">
</p>

## Was die App kann

**Zufallsvers.** Jede Seite ein Vers, Wischen nach oben oder Tippen auf die Fläche schaltet weiter, mit Haptik. Wahlweise über die ganze Bibel gleichverteilt oder aus 463 kuratierten Kernversen. Die letzten zwanzig Verse werden gemerkt und nicht sofort wiederholt. Ein Tipp auf die Stellenangabe öffnet den Zusammenhang.

**Themen.** Dieselben 463 Verse, geordnet in 26 Themen — Trost, Hoffnung, Nachfolge, Vergebung und weitere. Ein Tipp öffnet den Zufallsvers, auf dieses Thema beschränkt.

**Nachschlagen.** Buch → Kapitel → Vers. Die Buchliste hat ein Register mit sieben Sprungmarken, Kapitel und Verse stehen in einem dreispaltigen Raster. Verse, die es im Kapitel nicht gibt, bleiben sichtbar, aber blass — so ist die Kapitelgrenze zu sehen und fehlt nicht bloss.

**Leseansicht.** Das ganze Kapitel als Fliesstext mit hochgestellten Verszahlen, wie im Druck. Der gewählte Vers steht in voller Deckkraft, die übrigen gedämpft. Die Digital Crown scrollt, ein Bändchen links zeigt die Position. Die zuletzt gelesene Stelle wird gemerkt und auf dem Startbildschirm als «Weiterlesen» angeboten.

**Übersetzung wechseln, ohne die Stelle zu verlieren** — und ohne stillschweigend die falsche anzuzeigen (siehe [Versifikation](#versifikation)).

**Vers des Tages als Komplikation.** Ein Widget für Smart Stack und Zifferblatt (`accessoryRectangular` und `accessoryCircular`). Der Vers steht von Mitternacht bis Mitternacht; Tippen öffnet die App an derselben Stelle.

**Tag und Nacht.** Papier bei Tag, Schwarz bei Nacht, umschaltbar von Hand oder automatisch zwischen zwei selbst gesetzten Uhrzeiten. Bei gesenktem Handgelenk (`isLuminanceReduced`) immer die Nachtpalette.

**Einstellungen.** Übersetzung, Zufallsmodus, Darstellung, Schriftgrösse, Haptik, Impressum.

## Bibelübersetzungen und Lizenzen

Alle mitgelieferten Texte sind gemeinfrei oder frei lizenziert. Die Copyright-Zeile jeder Übersetzung steht in der Datenbank und erscheint dadurch von selbst im Impressum der App.

| Kürzel | Übersetzung | Sprache | Verse | Rechtslage |
|---|---|---|---:|---|
| ELB | Elberfelder 1905 | Deutsch | 31'103 | gemeinfrei |
| SCH | Schlachter 1951 | Deutsch | 31'172 | CC BY 4.0, © 1951 Genfer Bibelgesellschaft |
| LUT | Luther 1912 | Deutsch | 31'171 | gemeinfrei |
| KJV | King James Version | Englisch | 31'102 | gemeinfrei ausserhalb des Vereinigten Königreichs |
| DAR | Darby Bible | Englisch | 30'996 | gemeinfrei |
| BSB | Berean Standard Bible | Englisch | 31'084 | Public Domain seit 30. April 2023 |
| RVR | Reina-Valera 1909 | Spanisch | 31'102 | gemeinfrei |
| LSG | Louis Segond 1910 | Französisch | 31'102 | gemeinfrei |
| CUV | 和合本（繁體） | Chinesisch traditionell | 31'101 | gemeinfrei, Schutzfrist abgelaufen |
| CUVS | 和合本（简体） | Chinesisch vereinfacht | 31'101 | gemeinfrei, maschinell aus CUV (OpenCC) |

66 Bücher, 1'189 Kapitel, 311'034 Verse, 50.9 MB. Woher jeder Text stammt, wie er geprüft wurde und welche Eingriffe am Quelltext dokumentiert sind, steht in **[docs/Bibeltexte.md](docs/Bibeltexte.md)** — samt der Begründung, warum jeweils genau diese Ausgabe und nicht die naheliegende andere genommen wurde.

Geschützte Übersetzungen sind bewusst nicht dabei. Die Schlachter 2000 lässt sich mit einer schriftlichen Genehmigung der Genfer Bibelgesellschaft nachrüsten — dafür genügt ein Schalter am Konverter, der App-Code bleibt unverändert.

## Sprachen

Die Oberfläche gibt es in jeder Sprache, für die eine Bibelübersetzung mitgeliefert wird: **Deutsch, Englisch, Spanisch, Französisch, Chinesisch traditionell und Chinesisch vereinfacht.** Sie folgt der Systemsprache; eine eigene Spracheinstellung gibt es nicht.

Übersetzt ist mehr als die Beschriftung:

- **Buchnamen und Buchkürzel** kommen aus der Datenbank, je Sprache im dort üblichen Satz — Elberfelder für Deutsch, SBL Handbook of Style für Englisch, Reina-Valera für Spanisch, Segond für Französisch, der Kürzelsatz des 和合本 für Chinesisch. Das Register der Buchliste zeigt sie: 1Mo · Jos · Ps · Jes · Mt · Röm · Offb auf Deutsch, 創 · 書 · 詩 · 賽 · 太 · 羅 · 啟 auf Chinesisch.
- **Die Stellenangabe selbst.** Deutsche Bibeln schreiben «Johannes 3,16», alle übrigen Sprachen der App «John 3:16».
- **Zahlen folgen der Region, nicht der Sprache:** 18’463 in der Schweiz, 18,463 in den USA.
- **Chinesisch braucht mehr Fläche:** grössere Schrift, dichterer Zeilenfall, kein erzwungener Serifenschnitt.

Beim allerersten Start wählt die App die erste Übersetzung der Anzeigesprache in Datenbankreihenfolge. Danach nie wieder: eine einmal gewählte Übersetzung wird von einem Sprachwechsel des Systems nicht überschrieben.

## Versifikation

Bibelübersetzungen zählen unterschiedlich, und es geht nicht nur um Psalmenüberschriften — **ganze Kapitelgrenzen verschieben sich.** In 4. Mose hat Kapitel 16 in der Schlachter 35 Verse, in der King James 50; die Stelle 4Mo 17,2 zeigt entsprechend in beiden einen anderen Text. Weil beide Kapitel mit «Und der HERR redete zu Mose» beginnen, sieht Vers 1 identisch aus — der Fehler wird erst ab Vers 2 sichtbar. Die Trennlinie folgt dabei nicht der Sprache: Elberfelder und King James zählen hier gleich, Schlachter und Luther anders.

Die App tut deshalb beim Übersetzungswechsel nicht so, als sei es dieselbe Stelle. `BibleRepository.resolve` liefert `.exact`, `.divergent`, `.clamped` oder `.unavailable`, und **jeder Fall ausser `.exact` wird angezeigt**: eine zweizeilige Tabelle mit beiden Verszahlen des Kapitels, bei geklemmten Versen eine Zeile mehr. Keine Signalfarbe, kein Symbol, nichts zum Wegklicken — zwei Zahlen erklären den Sachverhalt vollständig.

## Datenschutz

Die App erfasst nichts. Keine Netzwerk-APIs, kein Konto, keine Analytics, keine Berechtigungsabfragen, keine App Group. Gespeichert werden ausschliesslich die eigenen Einstellungen, in `UserDefaults` auf dem Gerät. Das Privacy-Manifest hat genau einen Eintrag (`NSPrivacyAccessedAPICategoryUserDefaults`, Reason CA92.1).

## Technik

- **Swift 6, SwiftUI, watchOS 11.2**, kein UIKit, kein WatchKit-Storyboard.
- **Keine externen Abhängigkeiten.** SQLite direkt über `import SQLite3` — die Widget-Extension braucht denselben Zugriff, und SPM-Pakete machen dort erfahrungsgemäss Ärger.
- Die Datenbank wird **einmal beim Start schreibgeschützt geöffnet** (`SQLITE_OPEN_READONLY`), vorbereitete Statements bleiben zwischengespeichert. Abfragen laufen ausserhalb des Main-Actors, Rückgabewerte sind `Sendable`-Structs.
- **Kein `ORDER BY RANDOM()`:** `verse.id` ist lückenlos und je Übersetzung zusammenhängend, ein Zufallsvers ist damit ein einziger Primärschlüsselzugriff. `chapter_meta` ist vorberechnet, die Auswahlraster brauchen keine `COUNT`-Abfragen.
- **Nichts ist hartkodiert:** Übersetzungen, Bücher, Buchnamen, Kürzel, Themen und Copyright-Zeilen liest die App zur Laufzeit aus der Datenbank. Fällt eine Übersetzung weg, läuft die App ohne Codeänderung weiter.
- **29 Unit-Tests** (Swift Testing) prüfen Datenschicht, Versifikation, Sprachen und Themen gegen `test_fixtures.json`.

Architektur, Schema und die Abfragen im Einzelnen: **[docs/Architektur.md](docs/Architektur.md)**. Farben, Typografie, Rastergeometrie und das Verhalten aller Bildschirme: **[docs/Designspezifikation.md](docs/Designspezifikation.md)**.

## Projektaufbau

```
Watch Bible.xcodeproj
├── Watch Bible/                      iOS-Container (leere Hülle, watchOS-only App)
├── Watch Bible Watch App/            die App
│   ├── Data/                         SQLite-Zugriff, Repository, Modelle
│   ├── Features/                     Home · Random · Topics · Lookup · Reader · Settings
│   ├── Shared/                       AppModel, AppSettings, Localization, Theme
│   ├── Resources/                    bible.sqlite, String Catalogs
│   ├── Assets.xcassets/              je Farbrolle zwei Colorsets (Day/Night)
│   └── PrivacyInfo.xcprivacy
├── BibelWatchWidget/                 Vers des Tages
├── Watch Bible Watch AppTests/       Unit-Tests + test_fixtures.json
├── Config/Version.xcconfig           Build-Nummer, wird beim Bauen gesetzt
├── tools/                            Konverter und Nachtragsskripte (Python)
├── AppStore/                         Screenshots
└── docs/                             Architektur, Design, Bibeltexte, Migration
```

Fünf Targets: der iOS-Container, die Watch-App, das Widget, Unit-Tests und UI-Tests.

## Bauen und prüfen

```bash
xcodebuild -project "Watch Bible.xcodeproj" \
           -scheme "Watch Bible Watch App" \
           -destination 'generic/platform=watchOS Simulator' \
           -derivedDataPath "$HOME/Library/Developer/WatchBible-build" \
           -quiet build 2>&1 | grep -E "error:|warning:|BUILD"
```

Tests brauchen einen konkreten Simulator statt `generic`:

```bash
xcrun simctl list devices available | grep -i watch     # Namen nachsehen

xcodebuild -project "Watch Bible.xcodeproj" \
           -scheme "Watch Bible Watch App" \
           -destination 'platform=watchOS Simulator,name=Apple Watch Ultra 3 (49mm)' \
           -derivedDataPath "$HOME/Library/Developer/WatchBible-build" \
           test 2>&1 | grep -E "error:|failed|passed"
```

Merkpunkte:

- Zeigt `xcode-select -p` auf die CommandLineTools statt auf Xcode, vor dem Befehl `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` setzen.
- **Derived Data nie in den Projektordner legen.** Wird das Verzeichnis von einem File Provider synchronisiert (OneDrive, iCloud Drive, auch `~/Documents`), hängt dieser den Build-Produkten erweiterte Attribute an, und codesign bricht mit «resource fork, Finder information, or similar detritus not allowed» ab.
- Ein erfolgreicher Build sagt nichts über das Layout. Bildschirme gehören in den Simulator angesehen — Tag und Nacht, und wenigstens einmal auf Chinesisch.
- Der Pfad enthält Leerzeichen; in Befehlen also immer in Anführungszeichen setzen.

### Die Build-Nummer setzt sich selbst

Das Target «Watch Bible Watch App» hat als letzte Build-Phase ein Skript «Set Build Number». Es schreibt den aktuellen Zeitstempel im Format `YYYYMMDDHHMM` als `BUILD_TIMESTAMP` nach `Config/Version.xcconfig`. Diese Datei ist Basiskonfiguration beider Projekt-Konfigurationen; alle Targets setzen `CURRENT_PROJECT_VERSION = $(BUILD_TIMESTAMP)` und bleiben so automatisch auf derselben Nummer.

Vier Punkte dazu:

- **Geschrieben wird nur die xcconfig, nie `project.pbxproj`.** Das ist der ganze Grund für diese Konstruktion: eine geänderte Projektdatei lässt Xcode das Projekt mitten im Lauf neu laden und bricht den laufenden Vorgang ab — ohne Fehler, ohne Meldung. Die frühere Fassung rief `xcrun agvtool new-version` auf und ist genau daran gescheitert: jeder Testlauf aus Xcode heraus (⌘U) brach nach dem Build ab, ohne einen einzigen Test auszuführen. Über die Kommandozeile lief derselbe Lauf durch, weil `xcodebuild` kein Projekt neu lädt.
- **Beim Archivieren läuft das Skript bewusst gar nicht** (es prüft `$ACTION = install` und steigt aus). Das Archiv trägt die Nummer des letzten normalen Builds; wer vor dem Hochladen eine frische will, drückt vorher einmal ⌘B.
- Der Zeitstempel wirkt erst im **nächsten** Build: Xcode löst die Build-Einstellungen zu Beginn auf. Für den App Store genügt das, die Nummer steigt monoton.
- `Config/Version.xcconfig` **gehört ins Repository** — fehlt sie, ist `CURRENT_PROJECT_VERSION` leer. Dafür ändert jeder Build diese eine Zeile, `git status` zeigt sie also immer als geändert. `ENABLE_USER_SCRIPT_SANDBOXING` ist für dieses eine Target auf `NO` gesetzt, weil die Sandbox das Schreiben ins Projektverzeichnis verbietet.

## Die Datenbank

`Watch Bible Watch App/Resources/bible.sqlite` wird **nicht von Hand bearbeitet.** Stimmt etwas am Inhalt nicht, wird das Skript in `tools/` angepasst und die Datei neu erzeugt.

| Werkzeug | Aufgabe |
|---|---|
| `tools/quotepas_to_sqlite.py` | Der Konverter. Liest die LaTeX-Quelldatei, dazu OSIS-XML (`--osis CODE=DATEI`) und USFM-Verzeichnisse (`--usfm CODE=ORDNER`), und schreibt die Datenbank. Nur Standardbibliothek. |
| `tools/tables.py` | Die Nachschlagetabellen: Kanonwissen, Buchnamen und Kürzel der sechs Sprachen, `TRANSLATION_ORDER`, Copyright-Zeilen, Schema-Version. Konverter **und** Nachtragsskripte importieren hier — eine Quelle. |
| `tools/add_book_names.py` | Trägt Buchnamen und Kürzel in eine bestehende Datenbank nach. `--check-zh` prüft die vereinfachten Zeichen gegen die Abbildung, die sich aus CUV/CUVS ergibt. |
| `tools/reorder_translations.py` | Setzt `translation.sort_order` auf `TRANSLATION_ORDER` — und damit auch die Vorgabeübersetzung je Sprache. |
| `tools/update_curated.py` | Trägt Kernverse und Themen nach. Prüft jede Referenz gegen die Leitübersetzung und schreibt nichts, solange eine Stelle fehlt. |

Alle Nachtragsskripte kennen `--check`: prüfen, ohne zu schreiben.

So entsteht die ausgelieferte Datei:

```bash
python3 tools/quotepas_to_sqlite.py bible.db \
        --osis sch1951=sch1951.xml --osis lut=luth1912.xml \
        --osis cuv=chi.xml --osis cuvs=cuv_simplified.xml \
        --osis rvr1909=sparv.xml --osis lsg=fren.xml --usfm bsb=./bsb_usfm \
        --exclude slt --curated tools/curated_verses.json --swiss \
        -o "Watch Bible Watch App/Resources/bible.sqlite"
```

Die fremden Quelldateien — die quotepas-Datei `bible.db`, die OSIS-Ausgaben und das USFM-Verzeichnis — liegen nicht im Repository; woher sie kommen, steht in [docs/Bibeltexte.md](docs/Bibeltexte.md). Was hier entstanden ist, liegt bei: `tools/cuv_simplified.xml` (aus der traditionellen Fassung erzeugt) und `tools/curated_verses.json`.

**Die Reihenfolge der Quellenangaben bestimmt `translation.id` und die `verse.id`-Bereiche.** Wer sie verschiebt, verschiebt alle nachfolgenden Verse — die App liest beides zur Laufzeit, `test_fixtures.json` muss dann aber nachgerechnet werden. Die **Anzeigereihenfolge** dagegen steht in `TRANSLATION_ORDER` und lässt sich mit `reorder_translations.py` nachträglich ändern, ohne die Verstabelle anzufassen; `id` und `sort_order` laufen dabei auseinander (KJV hat `id` 3 und `sort_order` 2), und die App liest ausschliesslich `ORDER BY sort_order`.

## Dokumentation

| Datei | Inhalt |
|---|---|
| [docs/Architektur.md](docs/Architektur.md) | Datenmodell, Schema, die Abfragen, Versifikation, Aufbau der App, der Konverter |
| [docs/Designspezifikation.md](docs/Designspezifikation.md) | Farben, Typografie, Geometrie, alle Bildschirme, Mehrsprachigkeit |
| [docs/Bibeltexte.md](docs/Bibeltexte.md) | Herkunft, Prüfung und Lizenz jeder einzelnen Übersetzung |
| [docs/Migration.md](docs/Migration.md) | Wie aus dem Prototyp die heutige App wurde — abgeschlossen, als Nachweis behalten |
| [CLAUDE.md](CLAUDE.md) | Projektanweisungen für die Arbeit mit Claude Code |

## Lizenz

Der Code steht unter der **GNU General Public License v3.0** (siehe [LICENSE](LICENSE)).

Die Bibeltexte stehen **nicht** unter dieser Lizenz. Jede Übersetzung bringt ihre eigene Rechtslage mit; die Tabelle oben nennt sie, `docs/Bibeltexte.md` begründet sie, und die Copyright-Zeile jeder Übersetzung steht in der Datenbank und erscheint im Impressum der App. Für die Schlachter 1951 (CC BY 4.0) ist die Namensnennung Pflicht — sie ist dort erfüllt.
