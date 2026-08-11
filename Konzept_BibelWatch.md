# Bibel-Watch — Konzept und Umsetzungsplan

Stand: 6. August 2026 · Zielplattform: eigenständige Apple-Watch-App · Vertrieb: App Store

---

## 0. Entscheide, die diesem Konzept zugrunde liegen

| Punkt | Entscheid |
|---|---|
| Vertrieb | Öffentlich im App Store |
| Zufallsvers | Zwei Modi, in den Einstellungen umschaltbar: ganze Bibel gleichverteilt oder kuratierte Kernverse |
| Übersetzungen | Alle vorhandenen (es sind 4, nicht 5); Entfernen einzelner Übersetzungen erfolgt über einen Konverter-Schalter, nicht über Codeänderungen |
| Datenformat | SQLite, schreibgeschützt im App-Bundle |
| iPhone | Nicht erforderlich; die Uhr funktioniert autonom |

---

## 1. Rahmenbedingungen (belegt)

**Platz.** <cite index="5-1">Apple-Watch-Apps müssen unkomprimiert unter 75 MB bleiben.</cite> <cite index="9-1">watchOS unterstützt keine On-Demand-Resources</cite> — nachladbare Datenpakete fallen also weg, alles muss ins Bundle. **Gemessen an deiner Datei: 20.6 MB** für alle vier Übersetzungen inklusive Indizes — also gut ein Viertel des Limits. Selbst mit zwei weiteren Übersetzungen bliebe genug Luft. Der Konverter meldet die Grösse bei jedem Lauf und warnt ab 70 MB.

**Lizenzen.** Deine Datei enthält vier Übersetzungen: Schlachter 2000, Elberfelder 1905, Darby Bible und King James Version — eine fünfte ist nicht deklariert und kommt auch in keinem Verslabel vor. Elberfelder 1905, Darby und KJV sind gemeinfrei. Schlachter 2000 nicht: <cite index="16-1">Copyright © 2000 Genfer Bibelgesellschaft, Wiedergabe nur mit deren Genehmigung.</cite> Für eine App-Store-Veröffentlichung brauchst du entweder eine schriftliche Genehmigung der Genfer Bibelgesellschaft oder du lässt die Übersetzung weg — dafür genügt beim Konverter `--exclude slt`, der App-Code bleibt unverändert. Ohne Schlachter 2000 schrumpft die Datenbank auf rund 15 MB.

Falls du Ersatz für eine zeitgenössische deutsche Übersetzung suchst: Schlachter 1951 steht <cite index="12-1">unter CC BY 4.0</cite> und wäre mit Namensnennung frei verwendbar.

**Datenbankzugriff.** SQLite ist in watchOS enthalten und über `import SQLite3` direkt ansprechbar. Die verbreitete Bibliothek GRDB unterstützt zwar <cite index="38-1">watchOS ab 7.0</cite> und ist MIT-lizenziert, dokumentiert aber einen <cite index="36-1">Xcode-Fehler, der beim Einbinden in andere Targets als die Haupt-App — namentlich Watch-Extensions — zu «No such module 'CSQLite'» führt.</cite> Weil die App eine Widget-Extension bekommt, die dieselbe Datenbank liest, empfehle ich die C-API direkt: rund 120 Zeilen Wrapper, null Abhängigkeiten, kein Risiko im Extension-Target.

**Privatsphäre.** <cite index="23-1">Seit dem 1. Mai 2024 nimmt App Store Connect keine Apps mehr an, die ihre Verwendung von «Required Reason APIs» nicht im Privacy-Manifest deklarieren.</cite> Die App nutzt UserDefaults für die Einstellungen, also braucht sie eine `PrivacyInfo.xcprivacy` mit `NSPrivacyAccessedAPICategoryUserDefaults`. <cite index="24-1">Reason CA92.1 gilt, wenn nur die App selbst zugreift; teilen sich App und Extension die Einstellungen über eine App Group, gilt stattdessen 1C8F.1.</cite>

---

## 2. Warum SQLite und nicht etwas anderes

| Option | Bewertung |
|---|---|
| **SQLite (Empfehlung)** | Datei wird nicht in den Speicher geladen, sondern seitenweise gelesen — auf der Uhr entscheidend. Einzelvers-Zugriff und Kapitelabruf in Millisekunden. Erzeugung mit Python-Bordmitteln. Read-only, keine Migrationslogik. |
| JSON | Müsste komplett geparst und im RAM gehalten werden (~20 MB) — auf der Watch riskant bezüglich Speicher und Startzeit. |
| SwiftData / Core Data | Für einen unveränderlichen Datenbestand unnötiger Aufwand: Store vorbefüllen ist umständlich, Modellmigrationen sind ein Risiko ohne Nutzen. |
| Property List | Wie JSON, nur unhandlicher. |
| Ein Blob pro Kapitel im Bundle | Schnell, aber 1'189 Dateien und selbstgeschriebene Indexlogik ohne Gegenwert. |

---

## 3. Datenbankschema

```sql
meta          (key, value)                    -- Schema-Version, Erzeugungsdatum, Quelle
translation   (id, code, abbrev, name, language, copyright,
               verse_count, first_verse_id, last_verse_id, sort_order)
book          (id, code, name, name_en, name_es, name_fr, name_zh_hant,
               name_zh_hans, testament, chapter_count, sort_order)
verse         (id, translation_id, book_id, chapter, verse, text)
chapter_meta  (translation_id, book_id, chapter, verse_count)
curated       (id, book_id, chapter, verse, topic)
```

Zwei Kniffe, die den Watch-Code einfach halten:

1. **`verse.id` ist lückenlos und je Übersetzung zusammenhängend.** `translation` speichert `first_verse_id` und `last_verse_id`. Ein Zufallsvers ist damit ein einziger Primärschlüsselzugriff — `Int.random(in: first...last)` — statt `ORDER BY RANDOM()` über 31'000 Zeilen.
2. **`chapter_meta` ist vorberechnet.** Die Auswahlräder für Kapitel und Vers brauchen keine `COUNT`-Abfragen, sondern nur einen Indexzugriff. Kostet wenige hundert Kilobyte.

Zusätzlich `CREATE UNIQUE INDEX idx_verse_ref ON verse(translation_id, book_id, chapter, verse)` — bedient die Stellensuche und den Übersetzungswechsel bei gleichbleibender Stelle.

---

## 4. Die vier Abfragen, die die App braucht

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
```

---

## 5. Der Konverter

`quotepas_to_sqlite.py` — nur Standardbibliothek, läuft auf jedem Mac ohne Installation.

```bash
python3 quotepas_to_sqlite.py bible.db --dry-run                  # nur Bericht
python3 quotepas_to_sqlite.py bible.db -o bible.sqlite \
        --curated curated_verses.json --swiss                     # empfohlener Lauf
python3 quotepas_to_sqlite.py bible.db -o bible.sqlite --exclude slt
```

Zusätzliche Schalter: `--swiss` wandelt ß zu ss in den deutschen Texten (aus, weil es einen historischen Text verändert), `--exclude`/`--include` steuern die Übersetzungsauswahl, `--strict` bricht bei unklassifizierbaren Labels ab.

**Wie er dein Format liest.** Er sammelt aus `short…`/`long…` die Übersetzungen und aus den übrigen Nicht-Vers-Labels die Buchcodes. Verslabels werden nicht blind per Regex zerlegt — weil Buchcodes selber Ziffern enthalten (`1Mo`, `2Kor`, `1Joh`), wird zuerst der Übersetzungscode und dann der **längste passende Buchcode** abgezogen; der Rest muss exakt `<Kapitel>v<Vers>` sein. Getestet mit `slt1Joh1v9` gegen `sltJoh3v16` und mit einkapiteligen Büchern wie `sltJud1v24`.

**Was er bereinigt.** Deine Datei enthält genau fünf LaTeX-Befehle; alle werden klammerbewusst verarbeitet, auch verschachtelt:

| Befehl | Vorkommen | Behandlung |
|---|---:|---|
| `\textsc{Herr}` / `\textsc{Herrn}` | 6'654 | → `HERR` / `HERRN` in Grossbuchstaben. Damit bleibt die Unterscheidung zwischen dem Gottesnamen und `Herr` erhalten — Kapitälchen gehen im reinen Text sonst verloren. |
| `\flqq` / `\frqq` | 3'785 | → « » (Schweizer Anführungszeichen) |
| `\biblefootnote{…}` | 1'381 | wird entfernt, samt anschliessender Leerzeichenkorrektur vor Satzzeichen. Fussnoten sind auf einer 41-mm-Uhr unbrauchbar und wären zudem der urheberrechtlich heikelste Teil des Schlachter-Materials. Mit einer Codeänderung liessen sie sich stattdessen einbetten. |
| `\textit{…}` | 769 | Klammern weg, Text bleibt (kursiv markiert ergänzte Wörter) |

Dazu: `~` → geschütztes Leerzeichen, `--`/`---` → Halbgeviert-/Geviertstrich, Zeilenumbrüche im Block → einfaches Leerzeichen, Unicode-Normalisierung NFC. Befehle, die er nicht kennt, **löscht er nicht** — er zählt sie und listet sie im Bericht auf.

**Was er meldet.** Verse pro Übersetzung, erkannte Bücher, Duplikate, leere Blöcke, nicht klassifizierbare Labels, LaTeX-Reste, Dateigrösse, sowie jede kuratierte Referenz, die es in der Leitübersetzung nicht gibt. Mit `--strict` bricht er bei unklassifizierten Labels ab, statt sie zu überspringen.

### Ergebnis deiner Datei (Lauf vom 7. August 2026)

```
Quelle          : bible.db  (124'446 Eintraege, 25.1 MB)
Uebersetzungen  : slt=SLT (Schlachter 2000), elb=ELB (Elberfelder 1905),
                  dar=DAR (Darby Bible), kjv=KJV (King James Version)
Buecher         : 66        Kapitel: 1'189        Verse gesamt: 124'372
  slt     31'171     elb     31'103     dar     30'996     kjv     31'102
Duplikate: 0   Leere Bloecke: 0   Unklassifiziert: 0   LaTeX-Reste: 0
Kuratiert       : 180 von 180 Referenzen gefunden
Geschrieben     : bible.sqlite  (20.6 MB)
```

Alle Kontrollwerte stimmen: 66 Bücher (39 AT / 27 NT), 1'189 Kapitel, KJV mit exakt 31'102 Versen wie erwartet. Die Abweichungen der anderen Übersetzungen sind Zählunterschiede, keine Fehler. Stichproben quer durch die Datenbank (1Mo 1,1 · Ps 23,1 · Ps 119,176 · Joh 3,16 · Jud 1,25 · Offb 22,21) sind in allen vier Übersetzungen sauber. Auf dem Testrechner: 1'000 Zufallsverse in 24 ms, 1'000-mal Psalm 119 komplett (176 Verse) in 133 ms — die Uhr ist langsamer, aber die Grössenordnung stimmt.

---

## 6. Versifikation — der gefährlichste Punkt im Projekt

Ich habe die Referenzmengen aller vier Übersetzungen vollständig gegeneinander abgeglichen. Das Ergebnis ist gravierender als erwartet:

| Vergleich | Kapitel mit abweichender Verszahl (von 1'189) |
|---|---:|
| SLT ↔ ELB | 121 |
| ELB ↔ SCH 1951 | 123 |
| SCH 1951 ↔ KJV | 139 |
| ELB ↔ BSB | 44 |
| BSB ↔ KJV | 17 |
| CUV ↔ KJV | 5 |
| CUV ↔ ELB | 32 |
| RVR 1909 ↔ KJV | 0 |
| LSG ↔ KJV | 0 |
| SLT ↔ KJV | 136 |
| ELB ↔ KJV | **29** |
| DAR ↔ KJV | 6 |

Es geht nicht nur um Psalmenüberschriften. **Ganze Kapitelgrenzen verschieben sich.** Beispiel 4. Mose 16/17, geprüft in der Datenbank:

| | Kap. 16 | Kap. 17 |
|---|---:|---:|
| SLT | 35 Verse | 28 Verse |
| KJV | 50 Verse | 13 Verse |

SLT 4Mo 17,2 («Sage zu Eleasar … dass er die Räucherpfannen aus dem Brand aufheben soll») entspricht KJV 4Mo 16,37. Unter KJV 4Mo 17,2 steht dagegen ein völlig anderer Text (die Stäbe der Stammesfürsten). Und weil **beide** Kapitel mit «Und der HERR redete zu Mose» beginnen, sieht Vers 1 in beiden Übersetzungen identisch aus — der Fehler wird erst ab Vers 2 sichtbar, ohne jede Warnung.

Weitere betroffene Stellen ELB ↔ KJV: 3Mo 5/6, 4Mo 30, 5Mo 28, 1Sam 20/23/24, 1Kön 22, Joel 3/4. Die vollständige Liste der 29 Fälle liegt in `test_fixtures.json`.

**Konsequenz für den Entwurf.** Eine echte Versifikations-Zuordnungstabelle zu bauen, wäre ein eigenes Projekt. Der pragmatische und ehrliche Weg:

1. Beim Übersetzungswechsel die Verszahl des Kapitels in beiden Übersetzungen vergleichen (ein Indexzugriff auf `chapter_meta`). Weichen sie ab, wird das Ergebnis als **abweichend** markiert und die Oberfläche zeigt einen sichtbaren Hinweis, statt so zu tun, als sei es dieselbe Stelle.
2. Existiert der Vers gar nicht, auf den letzten Vers des Kapitels klemmen — ebenfalls sichtbar gekennzeichnet.
3. Nach einem Wechsel immer das **ganze Kapitel** anzeigen, nicht nur den Einzelvers. Der Leser sieht dann selbst, wo er gelandet ist.

Genau das bildet der Rückgabetyp `VerseResolution` (`.exact` / `.divergent` / `.clamped` / `.unavailable`) in der bereits geschriebenen Datenschicht ab. Wer das wegoptimiert, baut einen Fehler ein, der nicht abstürzt, sondern still den falschen Bibeltext anzeigt.

Kuratierte Verse folgen der Zählung der Leitübersetzung (`meta.master_translation`, in der ausgelieferten Datenbank `elb`).

## 7. Architektur der App

**Targets**

| Target | Zweck |
|---|---|
| `BibelWatch Watch App` | die eigentliche App, eigenständig lauffähig |
| `BibelWatchWidget` | Vers des Tages für Smart Stack und Zifferblatt |
| optional `BibelWatchTests` | Unit-Tests für Datenschicht und Referenzauflösung |

**Schichten**

```
BibelWatch/
├── Data/
│   ├── bible.sqlite            ✔ fertig — Target-Membership: App + Widget
│   ├── BibleDatabase.swift     ✔ fertig — sqlite3-Wrapper, Actor, Statement-Cache
│   ├── BibleRepository.swift   ✔ fertig — alle Abfragen, Versifikationslogik
│   └── Models.swift            ✔ fertig — Book, Translation, Verse, VerseResolution
├── Features/
│   ├── Random/RandomVerseView.swift
│   ├── Lookup/{BookListView,ChapterGridView,VerseGridView}.swift
│   ├── Reader/VerseDetailView.swift
│   └── Settings/{SettingsView,AboutView}.swift
├── Shared/
│   ├── AppSettings.swift       ✔ fertig — @AppStorage, @Observable
│   └── Localization.swift      ✔ fertig — Sprache, Vorgaben, Stellenformat
├── Resources/
│   ├── Localizable.xcstrings   ✔ fertig — 58 Schlüssel, sechs Sprachen
│   └── InfoPlist.xcstrings     ✔ fertig — App-Name
└── PrivacyInfo.xcprivacy       ✔ fertig — validiert
```

**Regeln für die Datenschicht**

- Datenbank einmal beim Start öffnen (`SQLITE_OPEN_READONLY`), Verbindung in einem Aktor oder Singleton halten. Öffnen pro Abfrage kostet auf der Uhr spürbar Zeit.
- Vorbereitete Statements zwischenspeichern und wiederverwenden.
- Kein Schreibzugriff, kein WAL — die Datei liegt im schreibgeschützten Bundle.
- Alle Abfragen ausserhalb des Main-Actors, Ergebnisse als `Sendable`-Structs zurückgeben.

---

## 8. Bedienkonzept

> **Verbindlich ist `Designspezifikation.md`** (Richtung «Dünndruck», Tag/Nacht) samt den Bildschirmentwürfen in `Design_TagNacht.html`. Dieses Kapitel beschreibt die Bedienlogik, die Spezifikation die Gestaltung. Bei Widersprüchen gilt die Spezifikation.


**Einstieg.** `NavigationStack` mit zwei grossen Zeilen: **Zufallsvers** und **Nachschlagen**, darunter **Einstellungen**. Kein Splash, kein Onboarding — die App ist in einem Tipp am Ziel.

**Zufallsvers.** Ein `TabView` im Stil `.verticalPage`: jede Seite ist ein Vers, Wischen nach oben erzeugt den nächsten. Zusätzlich unten eine flächige Schaltfläche «Nächster», damit es auch mit Handschuhen oder einhändig geht. Die Digital Crown scrollt innerhalb langer Verse. Beim Weiterschalten ein `WKInterfaceDevice.current().play(.click)`. Stellenangabe oben klein, Vers gross, Übersetzungskürzel unten rechts. Ein Tipp auf die Stellenangabe öffnet den Vers im Nachschlagemodus, damit man den Zusammenhang lesen kann.

Wichtig: die letzten ~20 gezeigten Verse merken und nicht sofort wiederholen; echte Gleichverteilung fühlt sich sonst kaputt an.

**Wie lang sind Verse wirklich?** Ausgezählt über die ganze Datenbank: Median 122–128 Zeichen, 90. Perzentil 209–218, 99. Perzentil rund 300. Der längste Vers ist Jeremia 21,7 mit 503 Zeichen (Schlachter); es folgen Jer 44,12, Est 8,9 und 2Kön 16,15. Rund 91 % aller Verse bleiben unter 220 Zeichen und passen damit bei mittlerer Schrift ohne Scrollen auf eine 45-mm-Uhr. Für die restlichen 9 % braucht es zwingend die Krone — der Layoutentwurf muss also mit 500 Zeichen umgehen können, ohne den Text abzuschneiden oder unlesbar zu skalieren. `.minimumScaleFactor` löst das nicht, Scrollen schon.

**Nachschlagen.** Drei Ebenen, jede für sich mit der Krone schnell durchfahrbar:

1. Buchliste, in Abschnitte AT/NT geteilt, mit Kurzcode als Sekundärtext.
2. Kapitel als Raster mit 3 Spalten (`LazyVGrid`), nicht als Liste — bei Psalm 150 Einträgen ist eine Liste unbrauchbar. Drei Spalten sind keine Geschmacksfrage: auf 198 pt Breite ergeben sie 52.7 pt pro Zelle, vier Spalten nur 38 pt und damit weniger als die üblichen 44 pt für Tippziele.
3. Verse ebenso als Raster. Nicht vorhandene Verse bleiben sichtbar, aber blass.

Nach der Auswahl die Leseansicht: der gewählte Vers hervorgehoben, davor und danach die Nachbarverse in gedämpfter Farbe, Krone scrollt durch das ganze Kapitel. Damit ist der Kontext ohne zusätzliche Navigation da. Toolbar-Schaltfläche schaltet die Übersetzung um, ohne die Stelle zu verlieren.

**Watch-spezifisches, das man leicht vergisst**

- Dynamische Schriftgrössen respektieren (`.font(.body)` statt fixer Punktgrössen) und `.minimumScaleFactor` nur sparsam einsetzen.
- `.containerBackground(.gray.gradient, for: .navigation)` gibt der App optische Tiefe, ohne den Kontrast zu ruinieren.
- Alle Tippziele mindestens 44 × 44 Punkte.
- Kein Text unter der Grösse `.caption2` — auf einer 41-mm-Uhr unlesbar.
- Die zuletzt gelesene Stelle in `@AppStorage` sichern und beim Start anbieten.

---

## 9. Vers des Tages als Widget

Eine WidgetKit-Extension mit `accessoryRectangular` (Smart Stack, Zifferblatt) und `accessoryCircular` (nur Referenz, für kleine Komplikationen). Jeder Kalendertag zieht **einen eigenen Zufallsvers aus der kuratierten Auswahl** — mit der Nummer des Tages als Startwert des Zufallsgenerators. Der Vers steht damit von Mitternacht bis Mitternacht, und jede Neuberechnung der Zeitleiste liefert denselben. Ein ungeseedeter `Int.random`-Aufruf wäre falsch: WidgetKit berechnet die Zeitleiste mehrmals, der Vers würde mitten am Tag wechseln.

```swift
let day = Calendar.current.ordinality(of: .day, in: .era, for: date)!
let verse = try await repository.randomCuratedVerse(in: translation, seed: UInt64(day))
```

Es gibt also keine eigene `verseOfDay`-Abfrage — Widget und Zufallsmodus der App teilen sich `randomCuratedVerse`, das Widget setzt zusätzlich den Startwert.

`TimelineProvider` liefert Einträge für die nächsten sieben Tage mit `.after(mitternacht)`. Tippen öffnet die App auf demselben Vers (Deep Link über `widgetURL`).

Falls App und Widget die Einstellungen teilen sollen, brauchst du eine App Group — und damit im Privacy-Manifest den Reason-Code 1C8F.1 statt CA92.1.

---

## 10. Einstellungen

| Einstellung | Werte | Speicherung |
|---|---|---|
| Übersetzung | dynamisch aus `translation`-Tabelle | `@AppStorage("translationCode")` |
| Zufallsmodus | ganze Bibel / kuratierte Kernverse | `@AppStorage("randomMode")` |
| Schriftgrösse | klein / mittel / gross | `@AppStorage("textScale")` |
| Haptik | ein / aus | `@AppStorage("haptics")` |
| Impressum | Copyright-Zeilen aus `translation.copyright` | — |

Der Impressumsbildschirm wird nicht hartkodiert, sondern aus der Datenbank gefüllt. Nimmst du eine Übersetzung heraus, verschwindet ihre Copyright-Zeile automatisch mit.

---

## 11. App-Store-Checkliste

- [ ] `PrivacyInfo.xcprivacy` mit `NSPrivacyAccessedAPICategoryUserDefaults`, Reason CA92.1 (ohne App Group) bzw. 1C8F.1 (mit)
- [ ] Nutrition Label: «Keine Daten erfasst» — trifft zu, die App hat keinerlei Netzwerkzugriff
- [ ] Impressumsbildschirm mit allen Copyright-/Lizenzzeilen, für CC-BY-Werke zwingend
- [ ] Schlachter 2000 entweder mit Genehmigung der Genfer Bibelgesellschaft oder per `--exclude slt` draussen
- [ ] Bundle-Grösse nach dem Build gegen die 75-MB-Grenze prüfen
- [ ] Altersfreigabe: 4+ (keine bedenklichen Inhalte, kein Nutzerinhalt, keine Werbung)
- [ ] Screenshots für alle geforderten Watch-Grössen
- [ ] Keine Netzwerk-Entitlements anfordern — vereinfacht die Prüfung spürbar
- [ ] App-Name prüfen: Begriffe wie «Bibel» sind frei, aber Namen bestehender Apps meiden

---

## 12. Was bereits fertig ist

Vorarbeit, die du nicht mehr machen musst — und ebenso wichtig: was davon **geprüft** ist und was nicht.

### Geliefert und gegen die echte Datenbank verifiziert

| Datei | Inhalt | Prüfung |
|---|---|---|
| `bible_frei_10-Uebersetzungen.sqlite` | 10 frei verwendbare Übersetzungen in 6 Sprachen, 311'034 Verse, 48.5 MB | Integrität, Stichproben, Zählwerte — **die Datei für die Veröffentlichung** |
| `bible_mit-SLT_11-Uebersetzungen.sqlite` | zusätzlich Schlachter 2000, 342'205 Verse, 53.8 MB | dito |
| `quotepas_to_sqlite.py` | Konverter, reproduzierbar | Läuft fehlerfrei über die volle Quelle |
| `curated_verses.json` | 180 Kernverse aus 50 Büchern, 25 Themen | Alle 180 Referenzen in der Datenbank vorhanden |
| `test_fixtures.json` | Erwartungswerte für Unit-Tests, inkl. aller 29 Versifikations-Abweichungen ELB ↔ KJV | direkt aus der Datenbank erzeugt |
| `PrivacyInfo.xcprivacy` | Privacy-Manifest | Als Plist geparst, Struktur gültig |
| `Localizable.xcstrings` | 58 Schlüssel in sechs Sprachen, inklusive Pluralformen | Als JSON geparst, keine Lücke in einer Sprache |
| `InfoPlist.xcstrings` | App-Name «Bibel» / «Bible» | dito |
| `Designspezifikation.md` + `Design_TagNacht.html` | Farben, Typografie, Geometrie, Bildschirme | Rastergeometrie nachgerechnet |

**Abfragepläne geprüft.** Alle Abfragen aus Kapitel 4 wurden mit `EXPLAIN QUERY PLAN` gegen die echte Datenbank gefahren:

```
Zufallsvers        SEARCH v USING INTEGER PRIMARY KEY (rowid=?)
Stelle nachschlagen SEARCH verse USING INDEX idx_verse_ref (…4 Spalten…)
Kapitel lesen      SEARCH verse USING INDEX idx_verse_ref (…3 Spalten…)
Auswahlrad Kapitel SEARCH chapter_meta USING PRIMARY KEY
Kuratierter Vers   SCAN c USING COVERING INDEX (180 Zeilen) + Indexzugriff
```

Kein einziger Table Scan über die Verstabelle. Messung auf dem Testrechner: 1'000 Zufallsverse in 24 ms, 1'000-mal Psalm 119 vollständig (176 Verse) in 133 ms.

### Geliefert, aber **nicht kompiliert**

Für Swift stand hier kein Compiler zur Verfügung. Die folgenden Dateien sind fachlich sorgfältig gegen das geprüfte Schema geschrieben, aber **Syntax und Typprüfung stehen aus** — der erste Xcode-Build wird vermutlich Kleinigkeiten anmahnen:

- `Models.swift` — `Translation`, `Book`, `Verse`, `VerseReference`, `VerseResolution`
- `BibleDatabase.swift` — Actor um die sqlite3-C-API, read-only, Statement-Cache, `deinit` mit `sqlite3_finalize`
- `BibleRepository.swift` — alle Abfragen typisiert, dazu `randomVerse`, `randomCuratedVerse` (mit optionalem Startwert für das Widget), `chapter`, `resolve`
- `AppSettings.swift` — `@Observable` mit `@AppStorage`
- `Localization.swift` — Anzeigesprache, Übersetzungsvorgabe (erste Übersetzung dieser Sprache in Datenbankreihenfolge), Buchnamen, Stellenformat

Behandle sie als geprüften Entwurf, nicht als fertigen Code: die SQL-Strings und Spaltenindizes darin stimmen nachweislich mit der Datenbank überein, die Swift-Syntax drumherum ist ungetestet.

### Nicht vorbereitet

Sämtliche SwiftUI-Ansichten, das Widget-Target und die Xcode-Projektdatei. Das ist Absicht: Layout auf einer Uhr lässt sich ohne Simulator nicht sinnvoll blind schreiben, und eine von Hand erfundene `.pbxproj` ist eine Fehlerquelle ohne Gegenwert.

---

## 13. Umsetzungsplan für Claude Code

Die Meilensteine sind so geschnitten, dass nach jedem etwas Lauffähiges auf dem Simulator steht.

| # | Ergebnis | Prüfung |
|---|---|---|
| ~~M0~~ | ~~Datenbank erzeugt~~ | **erledigt**, Bericht in Kapitel 5 |
| M1 | Xcode-Projekt, Watch-Target, Datenbank und die vier vorbereiteten Swift-Dateien eingebunden, Kompilierfehler bereinigt | Testansicht gibt 1. Mose 1,1 aus |
| M2 | Unit-Tests gegen `test_fixtures.json` | Randfälle: Ps 119,176, Jud 1,25, Offb 22,21, sowie `.divergent` bei 3Mo 5 (ELB 26 / KJV 19 Verse) |
| M3 | Nachschlagen komplett (Buch → Kapitel → Vers → Leseansicht) | Navigation bis Offb 22,21 und zurück |
| M4 | Zufallsvers mit beiden Modi, Wischen, Schaltfläche, Haptik, Wiederholungssperre | 200-mal weiterschalten ohne Ruckler |
| M5 | Einstellungen inkl. Übersetzungswechsel mit Zählungs-Fallback | Wechsel auf KJV bei Ps 34,19 klemmt sauber |
| M6 | Widget «Vers des Tages» mit Deep Link | Datum im Simulator vorstellen, Vers wechselt einmal täglich |
| M7 | Privacy-Manifest, Impressum, Icon, Archive-Build | Grösse < 75 MB, Validierung in Xcode ohne Warnung |

**Einstiegsprompt für Claude Code** (im leeren Projektordner, mit `Konzept_BibelWatch.md` und `CLAUDE.md` darin):

> Lies `Konzept_BibelWatch.md` und `CLAUDE.md`. Setze Meilenstein M1 um: ein Xcode-Projekt für eine eigenständige watchOS-App namens BibelWatch, Deployment Target watchOS 10.0, SwiftUI, Swift 6, keine externen Abhängigkeiten. Die Dateien `Models.swift`, `BibleDatabase.swift`, `BibleRepository.swift`, `AppSettings.swift`, `Localization.swift`, `Localizable.xcstrings`, `InfoPlist.xcstrings` und `PrivacyInfo.xcprivacy` liegen bereits vor — übernimm sie unverändert, soweit sie kompilieren, und korrigiere nur, was der Compiler tatsächlich bemängelt. **Die SQL-Strings und Spaltenindizes darin sind gegen die echte Datenbank verifiziert; ändere sie nicht.** Binde die gewählte Datenbank als `bible.sqlite` ins Bundle ein (siehe `README.md`) und richte Deutsch und Englisch als Lokalisierungen ein. Zeige zum Abschluss eine Testansicht mit 1. Mose 1,1. Erkläre mir am Ende, welche Änderungen du am gelieferten Code vornehmen musstest und was ich in Xcode noch von Hand einstellen muss.

Danach jeweils: *«Setze Meilenstein Mx gemäss Konzept um»* — mit dem Hinweis, den betreffenden Konzeptabschnitt nochmals zu lesen.

---

## 14. Entscheide, die noch offen sind

1. **Schlachter 2000.** Genehmigung bei der Genfer Bibelgesellschaft einholen oder mit `--exclude slt` weglassen. Das ist der einzige echte Blocker für die Veröffentlichung — alles andere ist Handwerk. Die Anfrage lohnt sich früh, weil eine Antwort dauern kann.
2. **Fussnoten.** Aktuell entfernt. Für eine Watch-App halte ich das für richtig; sag Bescheid, falls du sie doch haben willst.
3. **ß oder ss.** Elberfelder 1905 schreibt historisch «daß». Der Lauf mit `--swiss` macht «dass» daraus, verändert damit aber einen historischen Text. Deine Entscheidung — technisch ist beides fertig.
4. **Sprachtrennung.** Darby und KJV sind englisch. Gleichberechtigt in der Übersetzungsliste oder unter einer eigenen Überschrift «Englisch»?
5. **Suche.** Bewusst weggelassen — Texteingabe auf der Uhr ist mühsam, und SQLite-FTS5 würde die Datenbank etwa verdoppeln. Falls doch gewünscht, ist der Zeitpunkt vor M1, weil es das Schema betrifft.
