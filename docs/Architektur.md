# Architektur

Wie Watch Bible aufgebaut ist: Datenmodell, Schema, Abfragen, Versifikationslogik, Schichten der App. Dieses Dokument beschreibt den umgesetzten Stand, nicht einen Plan. Die Gestaltung steht in [Designspezifikation.md](Designspezifikation.md), die Herkunft der Texte in [Bibeltexte.md](Bibeltexte.md).

## 1. Rahmenbedingungen

**Platz — die bindende Grenze.** Apple-Watch-Apps müssen unkomprimiert unter 75 MB bleiben, und watchOS unterstützt keine On-Demand-Resources — nachladbare Datenpakete fallen also weg, alles muss ins Bundle. Die Datenbank mit zwölf Übersetzungen misst 61.5 MB, die archivierte Watch-App **62.2 MB**. Es bleiben rund 12 MB, also gut zwei weitere Übersetzungen zu je etwa 5 MB. Der Konverter meldet die Grösse bei jedem Lauf und warnt ab 70 MB; verlassen sollte man sich darauf nicht, sondern nach dem Archivieren messen (Befehl im README).

Deshalb liegt `bible.sqlite` auch nur **einmal** im Paket: das Widget liest sie aus dem Bundle der App, zwei Ebenen über der `.appex`. Eine eigene Kopie würde die Grenze auf einen Schlag sprengen.

**Kein Netzwerk.** Die App fragt nichts ab und lädt nichts nach. Das ist keine Sparsamkeit, sondern die Grundlage von allem Weiteren: keine Berechtigungen, kein Konto, kein zweiter Eintrag im Privacy-Manifest, keine Latenz auf einer Uhr ohne Empfang.

**Privatsphäre.** Seit dem 1. Mai 2024 nimmt App Store Connect keine Apps mehr an, die ihre Verwendung von «Required Reason APIs» nicht im Privacy-Manifest deklarieren. Die App nutzt `UserDefaults` für die Einstellungen, also braucht sie eine `PrivacyInfo.xcprivacy` mit `NSPrivacyAccessedAPICategoryUserDefaults`. Reason CA92.1 gilt, wenn nur die App selbst zugreift; teilen sich App und Extension die Einstellungen über eine App Group, gilt stattdessen 1C8F.1. Das Widget kommt deshalb bewusst ohne App Group aus — es folgt der Systemsprache statt der gewählten Übersetzung, dafür bleibt der Manifest-Eintrag bei CA92.1.

**Keine externen Abhängigkeiten.** SQLite ist in watchOS enthalten und über `import SQLite3` direkt ansprechbar. GRDB unterstützt zwar watchOS ab 7.0 und ist MIT-lizenziert, dokumentiert aber einen Xcode-Fehler, der beim Einbinden in andere Targets als die Haupt-App — namentlich Watch-Extensions — zu «No such module 'CSQLite'» führt. Weil die Widget-Extension dieselbe Datenbank liest, ist die C-API direkt angebunden: rund 100 Zeilen Wrapper, null Abhängigkeiten, kein Risiko im Extension-Target.

## 2. Warum SQLite und nicht etwas anderes

| Option | Bewertung |
|---|---|
| **SQLite** | Die Datei wird nicht in den Speicher geladen, sondern seitenweise gelesen — auf der Uhr entscheidend. Einzelvers-Zugriff und Kapitelabruf in Millisekunden. Erzeugung mit Python-Bordmitteln. Read-only, keine Migrationslogik. |
| JSON | Müsste komplett geparst und im RAM gehalten werden — auf der Watch riskant bezüglich Speicher und Startzeit. |
| SwiftData / Core Data | Für einen unveränderlichen Datenbestand unnötiger Aufwand: Store vorbefüllen ist umständlich, Modellmigrationen sind ein Risiko ohne Nutzen. |
| Property List | Wie JSON, nur unhandlicher. |
| Ein Blob pro Kapitel im Bundle | Schnell, aber 1'189 Dateien und selbstgeschriebene Indexlogik ohne Gegenwert. |

Der Vorgänger dieser App hielt die 25 MB grosse Rohtextdatei komplett im Speicher und suchte Verse per String-Suche. Das war der Ausgangspunkt der Migration (siehe [Migration.md](Migration.md)).

## 3. Datenbankschema

```sql
meta          (key, value)                    -- Schema-Version, Erzeugungsdatum, Quelle,
                                              -- Leitübersetzung, Anzahl kuratierter Verse
translation   (id, code, abbrev, name, language, copyright,
               verse_count, first_verse_id, last_verse_id, sort_order)
book          (id, code, name, name_en, name_es, name_fr, name_it, name_pt,
               name_zh_hant, name_zh_hans, abbrev_de, abbrev_en, abbrev_es,
               abbrev_fr, abbrev_it, abbrev_pt, abbrev_zh_hant, abbrev_zh_hans,
               testament, chapter_count, sort_order)
verse         (id, translation_id, book_id, chapter, verse, text)
chapter_meta  (translation_id, book_id, chapter, verse_count)
curated       (id, book_id, chapter, verse, topic)
```

Schema-Version 4 (`PRAGMA user_version` **und** `meta.schema_version`), `application_id` 0x42494257 («BIBW»). Die Sprachspalten sind mit Version 3 (August 2026) dazugekommen, Italienisch und Portugiesisch mit Version 4.

**Die sprachabhängigen Spalten stehen nirgends aufgezählt.** DDL und `INSERT` des Konverters leiten sie aus `BOOK_NAME_TABLES` und `BOOK_ABBREV_TABLES` in `tools/tables.py` ab; eine Sprache dazunehmen heisst, dort eine Tabelle einzutragen. Auf der Swift-Seite steht die Zuordnung Spalte → Sprache noch als Liste in `BibleRepository.load()`, weil sie zusätzlich die Kennung der Datenbank auf die der App abbildet (`zh_hant` → `zh-Hant`).

Zwei Kniffe, die den Watch-Code einfach halten:

1. **`verse.id` ist lückenlos und je Übersetzung zusammenhängend.** `translation` speichert `first_verse_id` und `last_verse_id`. Ein Zufallsvers ist damit ein einziger Primärschlüsselzugriff — `Int.random(in: first...last)` — statt `ORDER BY RANDOM()` über 31'000 Zeilen. Dieselbe Eigenschaft trägt die Zählerzeile des Zufallsverses («18’463 / 31’103»): die Zahl ist die normierte `verse.id`, keine Berechnung fürs Layout.
2. **`chapter_meta` ist vorberechnet.** Die Auswahlraster für Kapitel und Verse brauchen keine `COUNT`-Abfragen, sondern nur einen Indexzugriff. Kostet wenige hundert Kilobyte.

Dazu `CREATE UNIQUE INDEX idx_verse_ref ON verse(translation_id, book_id, chapter, verse)` — bedient die Stellensuche und den Übersetzungswechsel bei gleichbleibender Stelle.

**Buchnamen und Kürzel stehen in der Datenbank, nicht im String Catalog**, weil ein Buchname der Rechtschreibung der Übersetzung folgen muss, in der der Vers steht («Ruth» nach Reina-Valera). Die Spalten werden zur Laufzeit über `PRAGMA table_info` gesucht statt fest in die Abfrage geschrieben: eine Datenbank aus einem älteren Konverterlauf kennt sie nicht, und ein `no such column` beim Vorbereiten würde die App beim Start scheitern lassen. Fehlt eine Spalte, steht für diese Sprache der deutsche Buchname beziehungsweise im Register der Buchcode.

**`book.code` ist kein Kürzel**, sondern Schlüssel — er steht in `curated_verses.json`, `test_fixtures.json` und der OSIS-Zuordnung und bleibt in jeder Sprache gleich.

## 4. Die Abfragen

```sql
-- 1. Zufallsvers, ganze Bibel  (id vorher in Swift gewürfelt)
SELECT b.name, v.chapter, v.verse, v.text
  FROM verse v JOIN book b ON b.id = v.book_id
 WHERE v.id = ?;

-- 2. Zufallsvers, kuratiert  (offset vorher in Swift gewürfelt)
SELECT b.name, c.chapter, c.verse, v.text
  FROM curated c
  JOIN book b   ON b.id = c.book_id
  JOIN verse v  ON v.translation_id = ?
                AND v.book_id = c.book_id
                AND v.chapter = c.chapter
                AND v.verse   = c.verse
 LIMIT 1 OFFSET ?;

-- 3. Stelle nachschlagen
SELECT text FROM verse
 WHERE translation_id = ? AND book_id = ? AND chapter = ? AND verse = ?;

-- 4. Auswahlräder füllen
SELECT id, code, name, testament, chapter_count FROM book ORDER BY sort_order;
SELECT chapter, verse_count FROM chapter_meta
 WHERE translation_id = ? AND book_id = ? ORDER BY chapter;

-- 5. Themenregister  (einmal beim Start; die Ziehung selbst läuft in Swift)
SELECT topic, book_id, chapter, verse
  FROM curated WHERE topic IS NOT NULL ORDER BY topic, id;
```

Die fünfte Abfrage liest wenige hundert Zeilen und wird nie wiederholt: Themenliste, Anzahl Verse je Thema und die Stellen des Themenmodus stehen danach im Speicher. Ein Zufallsvers innerhalb eines Themas kostet damit genau eine Stellenabfrage (Nr. 3), keinen Durchlauf über `curated`.

Die Abfragepläne sind gegen die echte Datenbank geprüft — kein Table Scan. **Die SQL-Strings und Spaltenindizes in `Data/` gelten deshalb als verifiziert und werden nicht «aufgeräumt».**

## 5. Versifikation

Der gefährlichste Punkt im Projekt. Die Referenzmengen aller Übersetzungen sind vollständig gegeneinander abgeglichen:

| Vergleich | Kapitel mit abweichender Verszahl (von 1'189) |
|---|---:|
| LUT ↔ KJV | 140 |
| SCH 1951 ↔ KJV | 139 |
| ELB ↔ SCH 1951 | 123 |
| LUT ↔ ELB | 122 |
| ELB ↔ BSB | 44 |
| CUV ↔ ELB | 32 |
| ELB ↔ KJV | 29 |
| RIV ↔ ELB | 29 |
| BLV ↔ ELB | 29 |
| BSB ↔ KJV | 17 |
| DAR ↔ KJV | 6 |
| CUV ↔ KJV | 5 |
| LUT ↔ SCH 1951 | 3 |
| RVR · LSG · RIV · BLV ↔ KJV | 0 |

Gezählt sind Kapitel, die es in **beiden** Übersetzungen gibt und die unterschiedlich viele Verse haben — das sind die `.divergent`-Fälle. Kapitel, die einer Übersetzung ganz fehlen, sind hier nicht mitgezählt; sie sind `.unavailable` und ein anderer Fall. In dieser Datenbank gibt es davon genau zwei: Joel 4 (in LUT und SCH, nicht in ELB und KJV) und Maleachi 4 (umgekehrt). Wer beides zusammenzählt, bekommt zwei mehr je Paar — und vermischt zwei Zustände, die die App bewusst auseinanderhält.

Fünf Übersetzungen folgen der englischen Zählung exakt: Reina-Valera, Segond, Riveduta, Bíblia Livre und (bis auf 17 Kapitel) die BSB.

Es geht nicht nur um Psalmenüberschriften. **Ganze Kapitelgrenzen verschieben sich.** Beispiel 4. Mose 16/17, nachgezählt in der ausgelieferten Datenbank:

| | Kap. 16 | Kap. 17 |
|---|---:|---:|
| SCH 1951, LUT | 35 Verse | 28 Verse |
| ELB, KJV | 50 Verse | 13 Verse |

SCH 4Mo 17,2 («Sage zu Eleasar, dem Sohn Aarons … dass er die Räucherpfannen aus dem Brande aufhebe») entspricht KJV 4Mo 16,37. Unter KJV 4Mo 17,2 steht dagegen ein völlig anderer Text (die Stäbe der Stammesfürsten). Und weil **beide** Kapitel mit «Und der HERR redete zu Mose und sprach» beginnen, sieht Vers 1 in beiden Übersetzungen identisch aus — der Fehler wird erst ab Vers 2 sichtbar, ohne jede Warnung.

Dass diese Grenze ausgerechnet zwischen zwei **deutschen** Übersetzungen verläuft, macht es nicht harmloser, sondern schlimmer: Elberfelder und King James zählen hier gleich, Schlachter und Luther anders. Die Trennlinie folgt nicht der Sprache, und eine Faustregel «deutsch zählt so, englisch so» gibt es nicht.

Weitere betroffene Stellen ELB ↔ KJV, alle 29 im Einzelnen: 3Mo 5/6 · 4Mo 30 · 5Mo 28 · 1Sam 20/23/24 · 1Kön 22 · 2Kön 11/15 · Hi 39/40/41 · Ps 13 · Pred 6 · Hes 20/21 · Dan 5/6 · Hos 11/12 · Jon 1/2 · Mi 4/5 · Lk 17 · 2Kor 13 · 3Joh 1 · Offb 12. Und es fehlen ganze Kapitel: Luther und Schlachter zählen Joel mit vier und Maleachi mit drei Kapiteln, Elberfelder und King James umgekehrt — Joel 4 gibt es in der ELB nicht, Maleachi 4 nicht in der Luther. Solche Kapitel müssen `.unavailable` melden. Die vollständigen Listen liegen in `test_fixtures.json`.

**Die Konsequenz.** Eine echte Versifikations-Zuordnungstabelle zu bauen, wäre ein eigenes Projekt. Der pragmatische und ehrliche Weg:

1. Beim Übersetzungswechsel die Verszahl des Kapitels in beiden Übersetzungen vergleichen (ein Indexzugriff auf `chapter_meta`). Weichen sie ab, ist das Ergebnis **abweichend** und die Oberfläche zeigt es an, statt so zu tun, als sei es dieselbe Stelle.
2. Existiert der Vers gar nicht, auf den letzten Vers des Kapitels **klemmen** — ebenfalls sichtbar gekennzeichnet.
3. Nach einem Wechsel immer das **ganze Kapitel** anzeigen, nicht nur den Einzelvers. Der Leser sieht dann selbst, wo er gelandet ist.

Das bildet `VerseResolution` ab: `.exact` · `.divergent` · `.clamped(verse, requested)` · `.unavailable`. Wie jeder Fall dargestellt wird, steht in [Designspezifikation.md](Designspezifikation.md), Abschnitt 4.6. **Wer das zu einem stillen Fallback vereinfacht, baut einen Fehler ein, der nicht abstürzt, sondern den falschen Bibeltext anzeigt.**

Kuratierte Verse folgen der Zählung der Leitübersetzung (`meta.master_translation`, in der ausgelieferten Datenbank `elb`).

## 6. Aufbau der App

**Fünf Targets**

| Target | Zweck |
|---|---|
| `Watch Bible` | iOS-Container, leere Hülle einer watchOS-only App. Wird nie ausgeführt; sein `IPHONEOS_DEPLOYMENT_TARGET` steuert nur die Annahme im Store und steht auf 15.0. |
| `Watch Bible Watch App` | die eigentliche App, eigenständig lauffähig, watchOS 11.2 |
| `BibelWatchWidget` | Vers des Tages für Smart Stack und Zifferblatt |
| `Watch Bible Watch AppTests` | Unit-Tests für Datenschicht, Versifikation, Sprachen, Themen |
| `Watch Bible Watch AppUITests` | Startprüfung |

**Schichten**

```
Watch Bible Watch App/
├── Data/
│   ├── BibleDatabase.swift     Actor um die sqlite3-C-API, read-only, Statement-Cache
│   ├── BibleRepository.swift   alle Abfragen, Zufallsvers, Vers des Tages, resolve
│   └── Models.swift            Translation · Book · Verse · VerseReference ·
│                               VerseResolution · Topic
├── Features/
│   ├── Home/HomeView.swift
│   ├── Random/RandomVerseView.swift        (auch der Themenmodus)
│   ├── Topics/TopicListView.swift
│   ├── Lookup/{BookListView,ChapterGridView,VerseGridView}.swift
│   ├── Reader/ReaderView.swift             (inkl. Abweichungstabelle)
│   └── Settings/{SettingsView,AboutView}.swift
├── Shared/
│   ├── AppModel.swift          Zustand, Stammdaten, Navigationsziele (Route)
│   ├── AppSettings.swift       @AppStorage hinter @Observable
│   ├── Localization.swift      Sprache, Vorgaben, Buchnamen, Stellenformat
│   └── Theme.swift             ThemeState, Typo, Grid3, Ribbon, Haptik
├── Resources/                  bible.sqlite, Localizable.xcstrings, InfoPlist.xcstrings
└── PrivacyInfo.xcprivacy
```

`bible.sqlite` liegt **nur einmal** im Paket, im Bundle der App. Das Widget steckt als `.appex` in `<App>.app/PlugIns/` und greift zwei Ebenen höher auf dieselbe Datei zu; eine eigene Kopie hätte das Paket verdoppelt und das 75-MB-Limit gesprengt.

**Regeln für die Datenschicht**

- Datenbank einmal beim Start öffnen (`SQLITE_OPEN_READONLY`), Verbindung in einem Aktor halten. Öffnen pro Abfrage kostet auf der Uhr spürbar Zeit.
- Vorbereitete Statements zwischenspeichern und wiederverwenden.
- Kein Schreibzugriff, kein WAL — die Datei liegt im schreibgeschützten Bundle.
- Alle Abfragen ausserhalb des Main-Actors, Ergebnisse als `Sendable`-Structs.
- Kein `try!`, kein `as!`, keine stillschweigend verschluckten Fehler. Ein fehlender Vers ist ein `nil`, kein Absturz. Eine fehlende `bible.sqlite` ist ein Paketierungsfehler und wird als solcher gemeldet, statt die App leer dastehen zu lassen.

**Zustand und Navigation.** `AppModel` öffnet die Datenbank beim Start und hält Übersetzungen, Bücher und Themen. Navigationsziele sind Werte (`enum Route`), keine Views — so wandern Stellen als Daten durch den `NavigationStack`, und der Deep Link des Widgets kann denselben Weg nehmen.

## 7. Bedienlogik

**Einstieg.** `NavigationStack` mit drei Zeilen — Zufallsvers, Themen, Nachschlagen — darunter Einstellungen. Gab es eine zuletzt gelesene Stelle, erscheint sie als «Weiterlesen»-Zeile. Kein Splash, kein Onboarding.

**Zufallsvers.** Ein `TabView` im Stil `.verticalPage`: jede Seite ein Vers, Wischen nach oben erzeugt den nächsten; ein Tipp auf die Fläche tut dasselbe, damit es auch einhändig oder mit Handschuhen geht. Beim Weiterschalten `WKInterfaceDevice.current().play(.click)`, abschaltbar. Die Ansicht hält immer zwei Seiten Vorlauf, damit nie gewartet wird. Die letzten zwanzig Verse werden gemerkt und nicht wiederholt — echte Gleichverteilung fühlt sich sonst kaputt an.

**Themen.** Dieselbe Ansicht, auf die Stellen eines Themas beschränkt. Die Wiederholungssperre greift dort über die **Stelle** statt über `verse.id` (dieselbe Stelle hat je Übersetzung eine andere id) und umfasst die halbe Themenliste, höchstens aber zwanzig — ein Thema mit zehn Versen kann keine zwanzig sperren, sonst bliebe nichts zu ziehen.

**Nachschlagen.** Drei Ebenen, jede mit der Krone schnell durchfahrbar: Buchliste mit Register, Kapitelraster, Versraster. Raster statt Liste, weil Psalm 150 Einträge hat. Drei Spalten sind keine Geschmacksfrage — auf 198 pt Breite ergeben sie 52.7 pt pro Zelle, vier Spalten nur 38 pt und damit weniger als die üblichen 44 pt für Tippziele.

**Leseansicht.** Das ganze Kapitel als Fliesstext, der gewählte Vers hervorgehoben, die Krone scrollt. Damit ist der Zusammenhang ohne zusätzliche Navigation da. Ein Fliesstext hat keine Ankerpunkte je Vers; die Startposition wird deshalb über den Zeichenanteil vor dem gewählten Vers geschätzt.

**Wie lang sind Verse wirklich?** Ausgezählt über die ganze Datenbank: Median 122–128 Zeichen, 90. Perzentil 209–218, 99. Perzentil rund 300. Der längste Vers ist Jeremia 21,7 mit 503 Zeichen. Rund 91 % aller Verse bleiben unter 220 Zeichen und passen bei mittlerer Schrift ohne Scrollen auf eine 45-mm-Uhr. Für die restlichen 9 % braucht es zwingend die Krone — `.minimumScaleFactor` löst das nicht, Scrollen schon. Der längste chinesische Vers hat 108 Zeichen.

## 8. Vers des Tages

Eine WidgetKit-Extension mit `accessoryRectangular` (Smart Stack, Zifferblatt) und `accessoryCircular` (nur die Stellenangabe, für kleine Komplikationen). Jeder Kalendertag zieht **einen eigenen Zufallsvers aus der kuratierten Auswahl** — mit der Nummer des Tages als Startwert des Zufallsgenerators:

```swift
let day = Calendar.current.ordinality(of: .day, in: .era, for: date)!
let verse = try await repository.randomCuratedVerse(in: translation, seed: UInt64(day))
```

Der Vers steht damit von Mitternacht bis Mitternacht, und jede Neuberechnung der Zeitleiste liefert denselben. Ein ungeseedeter `Int.random`-Aufruf wäre falsch: WidgetKit berechnet die Zeitleiste mehrmals, der Vers würde mitten am Tag wechseln. Es gibt deshalb auch keine eigene `verseOfDay`-Abfrage — Widget und Zufallsmodus teilen sich `randomCuratedVerse`, das Widget setzt zusätzlich den Startwert.

Die Zeitleiste trägt sieben Tage vor und lädt danach neu (`.atEnd`). Tippen öffnet die App auf demselben Vers, über `widgetURL` und das Schema `watchbible://verse/<buchID>/<kapitel>/<vers>`.

Die runde Komplikation zeigt das **Buchkürzel der Anzeigesprache** aus der Datenbank, nicht `book.code` — der ist deutsch geprägt.

## 9. Einstellungen

| Einstellung | Werte | Speicherung |
|---|---|---|
| Übersetzung | dynamisch aus der `translation`-Tabelle | `@AppStorage("translationCode")` |
| Zufallsmodus | ganze Bibel / kuratierte Kernverse | `@AppStorage("randomMode")` |
| Darstellung | Tag / Nacht / Automatisch | `@AppStorage("appearance")` |
| Nachtfenster (bei Automatisch) | zwei Uhrzeiten in Halbstundenschritten | `@AppStorage("nightStart")`, `("nightEnd")` |
| Schriftgrösse | klein / mittel / gross (14 / 16 / 18 pt) | `@AppStorage("textScale")` |
| Haptik | ein / aus | `@AppStorage("haptics")` |
| Zuletzt gelesen | Stelle als JSON | `@AppStorage("lastReference")` |
| Impressum | Copyright-Zeilen aus `translation.copyright` | — |

Bewusst nur `@AppStorage`: kein eigener Speicher, keine Datei, keine Synchronisation. Das hält das Privacy-Manifest bei einem einzigen Eintrag.

`@AppStorage` und `@Observable` vertragen sich nicht von selbst — die Speicher-Properties sind `@ObservationIgnored`, sonst kollidieren die Property-Wrapper. Damit die Oberfläche Änderungen trotzdem sieht, läuft jeder Zugriff über beobachtete computed Properties, deren Setter einen Revisionszähler erhöhen.

Der Impressumsbildschirm wird nicht hartkodiert, sondern aus der Datenbank gefüllt. Wird eine Übersetzung herausgenommen, verschwindet ihre Copyright-Zeile automatisch mit.

**Kein Standortzugriff für den Sonnenuntergang.** Das würde eine Berechtigung und einen zweiten Eintrag im Privacy-Manifest nach sich ziehen, für einen Nutzen, den zwei Uhrzeiten ebenso erbringen.

## 10. Tests

29 Unit-Tests (Swift Testing) in sechs Suiten, alle gegen die echte Datenbank und `test_fixtures.json`:

| Suite | Prüft |
|---|---|
| `ZaehlwerteTests` | 66 Bücher, 1'189 Kapitel, Verszahlen und `verse.id`-Bereiche je Übersetzung |
| `StichprobenTests` | 36 Stellen wörtlich; ein fehlender Vers ergibt `nil`, keinen Absturz |
| `VersifikationTests` | `.divergent`, `.clamped`, `.unavailable` an den bekannten Fällen |
| `SprachenTests` | Übersetzungssprachen ↔ Oberflächensprachen, Normalisierung, Vorgaben, Buchnamen, Kürzel, Stellenformat |
| `ZufallTests` | Grenzen, Streuung, Determinismus des Tagesverses, Abdeckung der Liste |
| `ThemenTests` | Themen aus der Datenbank, Übersetzung in allen acht Sprachen, Wiederholungssperre |

Randfälle, die immer mitlaufen: Ps 119,176 · Jud 1,25 · letzter Vers der Offenbarung · erster Vers von 1. Mose.

Der Abgleich «jede Übersetzungssprache hat eine Oberfläche» läuft in beide Richtungen: kommt eine neunte Sprache in die Datenbank, ohne dass die Oberfläche nachzieht, schlägt der Test fehl. Dasselbe gilt für Themen — jedes Thema der Datenbank braucht in allen acht Sprachen einen Eintrag im String Catalog.

## 11. App Store

- `PrivacyInfo.xcprivacy` mit `NSPrivacyAccessedAPICategoryUserDefaults`, Reason CA92.1 (ohne App Group).
- Nutrition Label: «Keine Daten erfasst» — trifft zu, die App hat keinerlei Netzwerkzugriff.
- Impressumsbildschirm mit allen Copyright- und Lizenzzeilen; für CC-BY-Werke zwingend.
- Bundle-Grösse nach dem Build gegen die 75-MB-Grenze prüfen (unkomprimiert).
- Altersfreigabe 4+, keine Werbung, kein Nutzerinhalt.
- Keine Netzwerk-Entitlements anfordern — vereinfacht die Prüfung spürbar.
- **Export Compliance:** App Store Connect prüft die Info.plist des **iOS-Containers**, nicht die der Watch-App. `ITSAppUsesNonExemptEncryption` muss in beiden Targets stehen.
- **Archivieren mit dem Schema «Watch Bible Watch App».** Xcode legt beim Anlegen des Widgets automatisch ein Schema `BibelWatchWidget` an; archiviert man damit, ist das Ergebnis inhaltlich korrekt, heisst im Organizer aber nach der Extension.
- `CURRENT_PROJECT_VERSION` gilt in allen fünf Targets gemeinsam; Container, Watch-App und Widget müssen dieselbe `CFBundleVersion` tragen. Jede Lieferung braucht eine höhere Nummer — darum der Zeitstempel als Build-Nummer (siehe README).
