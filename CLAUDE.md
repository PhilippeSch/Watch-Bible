# CLAUDE.md — Projektanweisungen Watch Bible

## Was das hier ist

Eine ausgelieferte, eigenständige Apple-Watch-App für Bibelverse: Zufallsvers, Themen, Nachschlagen über Buch → Kapitel → Vers, Leseansicht als Fliesstext, Vers des Tages als Komplikation. Die Verse liegen als schreibgeschützte SQLite-Datei im App-Bundle. Kein Server, kein Netzwerk, kein Konto, kein iPhone nötig.

Der Aufbau steht in `docs/Architektur.md`, die Gestaltung in `docs/Designspezifikation.md`, die Herkunft der Bibeltexte in `docs/Bibeltexte.md`. **Lies vor einer grösseren Änderung den betreffenden Abschnitt dort neu**, statt aus dem Gedächtnis zu arbeiten. Die Dokumente beschreiben den umgesetzten Stand; weicht der Code davon ab, ist eines von beiden falsch — melden, nicht stillschweigend auseinanderlaufen lassen.

## Technische Leitplanken

- Swift 6, SwiftUI, Deployment Target watchOS 11.2. Kein UIKit, kein WatchKit-Storyboard.
- **Keine externen Abhängigkeiten.** Datenbankzugriff über `import SQLite3` direkt, nicht über GRDB oder SQLite.swift — die Widget-Extension braucht denselben Zugriff, und SPM-Pakete machen dort erfahrungsgemäss Ärger.
- Datenbank read-only öffnen (`SQLITE_OPEN_READONLY`), Verbindung einmal beim Start herstellen und halten, vorbereitete Statements zwischenspeichern. Niemals pro Abfrage neu öffnen.
- Datenbankzugriffe laufen nicht auf dem Main-Actor; Rückgabewerte sind `Sendable`-Structs.
- Kein `try!`, kein `as!`, keine stillschweigend verschluckten Fehler. Ein fehlender Vers ist ein `nil`, kein Absturz.
- Keine Netzwerk-APIs, keine Analytics, keine Berechtigungsabfragen, keine App Group. Wenn eine Lösung Netzwerk brauchen würde, ist es die falsche Lösung. Eine App Group würde ausserdem den Reason-Code im Privacy-Manifest von CA92.1 auf 1C8F.1 heben.

## Datenmodell

Schema und die fünf Abfragen stehen in `docs/Architektur.md`, Kapitel 3 und 4. Nicht selber erfinden. Zwei Dinge sind bewusst so gebaut:

- `verse.id` ist lückenlos und je Übersetzung zusammenhängend, dazu `translation.first_verse_id` / `last_verse_id`. Zufallsvers = ein Primärschlüsselzugriff. **Nie `ORDER BY RANDOM()`** über die Verstabelle.
- `chapter_meta` ist vorberechnet. Für Auswahlräder keine `COUNT`-Abfragen schreiben.

Übersetzungen, Bücher, Themen und Copyright-Zeilen werden **zur Laufzeit aus der Datenbank gelesen**, nie im Code hartkodiert. Wird eine Übersetzung aus der Datenbank entfernt, muss die App ohne Codeänderung weiterlaufen.

## Versifikation

Bibelübersetzungen zählen unterschiedlich (Psalmenüberschriften, Jes 9,5 vs. 9,6). Eine Stelle, die in einer Übersetzung existiert, kann in einer anderen fehlen. Gemessen an der ausgelieferten Datenbank: 29 Kapitel unterscheiden sich zwischen ELB und KJV in der Verszahl, 139 zwischen SCH 1951 und KJV, 140 zwischen LUT und KJV. Es verschieben sich auch ganze Kapitelgrenzen (4Mo 16/17, 3Mo 5/6, Joel 3/4, Mal 3/4) — die falsche Stelle sieht dann völlig plausibel aus.

Beim Zählen die beiden Fälle auseinanderhalten: abweichende Verszahl in einem Kapitel, das es in beiden gibt, ist `.divergent`; ein Kapitel, das einer Übersetzung ganz fehlt (Joel 4, Mal 4), ist `.unavailable`. Wer beides zusammenzählt, bekommt andere Zahlen als `test_fixtures.json`.

Die Trennlinie folgt **nicht** der Sprache: in 4Mo 16/17 zählen Elberfelder und King James gleich, Schlachter und Luther anders. Wer eine Faustregel «deutsch so, englisch so» einbaut, liegt falsch.

`BibleRepository.resolve` liefert deshalb `.exact`, `.divergent`, `.clamped` oder `.unavailable`. **Jeder dieser Fälle ausser `.exact` muss in der Oberfläche sichtbar sein.** Wer das zu einem stillen Fallback vereinfacht, baut einen Fehler ein, der den falschen Bibeltext anzeigt, ohne zu warnen.

## Gestaltung

`docs/Designspezifikation.md` ist verbindlich: Farbwerte, Schriftgrössen, Abstände, Rastergeometrie und das Verhalten aller Bildschirme stehen dort. Farbwerte gehören in den Asset-Katalog, nicht als Konstanten in den Code.

Drei Punkte, die keine Geschmacksfragen sind:

- Raster **immer dreispaltig** (vier Spalten ergeben 38 pt Zellen und unterschreiten die 44 pt für Tippziele).
- Bei `@Environment(\.isLuminanceReduced)` **immer** die Nachtpalette, unabhängig von der Einstellung.
- **watchOS wertet Any/Dark-Varianten eines Assets nicht aus** und ignoriert auch `\.colorScheme` für benannte Farben (im Simulator verifiziert). Darum je Rolle zwei Colorsets (`…Day` / `…Night`) und der beobachtbare Schalter `ThemeState` in `Shared/Theme.swift`. `\.colorScheme` wird zusätzlich gesetzt — nicht für diese Farben, sondern für alles, was das System selbst zeichnet.

## Mehrsprachigkeit

**Die App gibt es in jeder Sprache, für die eine Bibelübersetzung mitgeliefert wird** — zurzeit `de`, `en`, `es`, `fr`, `it`, `pt`, `zh-Hant`, `zh-Hans`. Die Liste steht in `Localization.supportedLanguages` und muss deckungsgleich mit den `translation.language`-Werten der Datenbank bleiben; ein Unit-Test prüft das in beide Richtungen. Anzeigesprache folgt dem System, eine eigene Einstellung gibt es nicht.

Alle Texte über `Resources/Localizable.xcstrings` — **kein Klartext in Views**. Buchnamen und Buchkürzel kommen aus der Datenbank, nicht aus dem Katalog: `name`, `name_en` … `name_zh_hans` sowie `abbrev_de` … `abbrev_zh_hans`. Welche Spalten es gibt, sagen `BOOK_NAME_TABLES` und `BOOK_ABBREV_TABLES` in `tools/tables.py` — der Konverter zählt sie nirgends auf. Die Kürzel sind je Sprache der dort übliche Satz (Elberfelder, SBL, Reina-Valera, Segond, CEI, Almeida, 和合本) und stehen im Register der Buchliste und in der runden Komplikation. **`book.code` ist kein Kürzel**, sondern Schlüssel — er bleibt in jeder Sprache gleich.

Wird eine Sprache dazugenommen, gehören Tests angepasst, die eine **nicht** unterstützte Sprache brauchen: dort stand einmal `it`, heute `ja`. Der Weg im Ganzen steht in `docs/Bibeltexte.md` unter «Eine Übersetzung dazunehmen».

**Sprachkennungen nie auf zwei Zeichen kürzen.** `zh-Hant` und `zh-Hans` unterscheiden sich in der Schrift; `prefix(2)` trifft keine der beiden chinesischen Übersetzungen. Normalisierung läuft über `Localization.normalized`.

**Themennamen dagegen stehen im Katalog**, unter `topic.<deutscher Wert>` — der deutsche Wert aus `curated.topic` ist zugleich der Schlüssel. Der Unterschied zu den Buchnamen ist die Bindung an den Text: ein Buchname muss der Rechtschreibung der Übersetzung folgen, in der der Vers steht, ein Themenname ist blosse Beschriftung. Die Datenbank sagt, **welche** Themen es gibt, der Katalog, **wie sie geschrieben werden**; ein Unit-Test hält beides deckungsgleich.

Der Trenner der Stellenangabe unterscheidet sich: «Johannes 3,16» gegen «John 3:16». Nie fest verdrahten, immer über `reference.format`.

Vorgabe der Bibelübersetzung: die **erste Übersetzung der Anzeigesprache in Datenbankreihenfolge** — dieselbe, die in der Auswahl zuoberst steht. Keine fest verdrahteten Codes. Das gilt **nur beim ersten Start**; eine vom Nutzer gewählte Übersetzung wird nie durch einen Sprachwechsel überschrieben. Logik liegt in `Shared/Localization.swift`.

**`Int` ist auf der Uhr 32 Bit breit** (arm64_32), `%lld` im String Catalog liest aber 64 Bit. Bei `String(format:)` mit `%lld` immer `Int64(...)` übergeben — sonst steht auf dem Gerät «2. Petrus 0», und im Simulator (arm64) sieht man nichts davon.

## Bedienung auf einer Uhr

- Tippziele mindestens 44 × 44 Punkte. Kapitel- und Versauswahl als `LazyVGrid`, nicht als Liste.
- Digital Crown zum Scrollen in langen Texten und langen Listen anbinden.
- Dynamische Schriftgrössen verwenden, nichts unter `.caption2`.
- Haptik beim Weiterschalten (`WKInterfaceDevice.current().play(.click)`), abschaltbar.
- Beim Zufallsvers die letzten 20 Verse merken und nicht sofort wiederholen.

## Verifizierter Code

Die **SQL-Strings und Spaltenindizes in `Data/`** sind gegen die echte Datenbank verifiziert (Abfragepläne geprüft, kein Table Scan). Nicht neu erfinden, nicht «aufräumen». Beim Beheben von Compilerfehlern bleiben sie unangetastet.

`Watch Bible Watch AppTests/test_fixtures.json` enthält die Erwartungswerte der Unit-Tests, darunter alle 29 Kapitel, in denen ELB und KJV unterschiedlich viele Verse haben. Wird die Datenbank neu erzeugt und verschieben sich dabei die `verse.id`-Bereiche, muss diese Datei nachgerechnet werden.

## Bauen — nach jeder Änderung

Kompilieren gehört zum Durchgang, nicht zur Nachkontrolle durch den Nutzer. Im Projektwurzelverzeichnis:

```bash
xcodebuild -project "Watch Bible.xcodeproj" \
           -scheme "Watch Bible Watch App" \
           -destination 'generic/platform=watchOS Simulator' \
           -derivedDataPath "$HOME/Library/Developer/WatchBible-build" \
           -quiet build 2>&1 | grep -E "error:|warning:|BUILD"
```

Zwei Eigenheiten dieses Rechners: `xcode-select` zeigt auf die CommandLineTools — vor xcodebuild `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` setzen. Und Derived Data **nie** in den Projektordner legen (Documents wird von einem File Provider synchronisiert; codesign scheitert sonst an «detritus»-xattrs).

Fehler selbst lesen und beheben, statt sie zu melden. Weiterführende Befehle und Fallstricke stehen im `README.md` unter «Bauen und prüfen».

Zwei Grenzen: ein erfolgreicher Build sagt nichts über das Layout — Bildschirme gehören in den Simulator angesehen, Tag und Nacht und wenigstens einmal auf Chinesisch. Und die Unit-Tests brauchen einen konkreten Simulator statt `generic` (Befehl im README).

## Arbeitsweise

- Die App ist **fertig und ausgeliefert**; Änderungen sind Verbesserungen an Vorhandenem. Keine Funktionen bauen, die nicht besprochen sind.
- Ein Punkt pro Durchgang. Nicht vorgreifen.
- Datenschicht und Referenzauflösung bekommen Unit-Tests. Randfälle, die immer zu prüfen sind: Ps 119,176, Jud 1,25, letzter Vers von Offb, erster Vers von 1. Mose.
- Nach einer Änderung an Projekt oder Targets kurz auflisten, welche Dateien entstanden sind und was in Xcode von Hand einzustellen ist (Target-Membership, Capabilities, Signing).
- Übersetzungs-`id` und Leitübersetzung **nie** fest verdrahten, immer zur Laufzeit aus der Datenbank lesen — sie ändern sich, sobald die Datenbank mit anderen Quellen neu erzeugt wird.
- **`bible.sqlite` ist der massgebliche Bestand und wird fortgeschrieben, nicht neu gebaut.** Von Hand bearbeitet wird sie nie; Änderungen laufen über die Skripte in `tools/`, die alle dieselben Tabellen aus `tools/tables.py` lesen und damit reproduzierbar sind. Eine Übersetzung kommt über `tools/add_translation.py` dazu, Namen und Kürzel über `tools/add_book_names.py`.
- **Ein voller Konverterlauf ist kein gangbarer Weg mehr.** Er würde die `verse.id`-Bereiche von KJV und DAR vertauschen (die Datei trägt ihre ids aus der ursprünglichen Quellenreihenfolge, ein Neulauf vergibt sie nach `TRANSLATION_ORDER`), und `test_fixtures.json` hängt an diesen Bereichen. Ausserdem liegt die LaTeX-Quelle, aus der Elberfelder, KJV und Darby stammen, nicht mehr vor. `tools/quotepas_to_sqlite.py` bleibt trotzdem: `add_translation.py` importiert dessen OSIS- und USFM-Leser, und er ist der schriftliche Nachweis, wie die Texte bereinigt wurden.
- **75 MB unkomprimiert** sind die Grenze für eine Watch-App, und diese hier ist fast nur Datenbank (62.2 MB im Archiv). Jede weitere Übersetzung kostet gut 5 MB. Nach einer Änderung am Datenbestand archivieren und messen, nicht schätzen.
- Antworten auf Deutsch, Schweizer Rechtschreibung, kein ß.
