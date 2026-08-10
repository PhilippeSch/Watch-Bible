# CLAUDE.md — Projektanweisungen Watch Bible

## Was das hier ist

Ein bestehender Prototyp einer eigenständigen Apple-Watch-App, die Bibelverse anzeigt. Zwei Funktionen: zufälliger Vers mit Weiterschalten, und gezieltes Nachschlagen über Buch → Kapitel → Vers. Die Verse liegen als schreibgeschützte SQLite-Datei im App-Bundle. Kein Server, kein Netzwerk, kein Konto, kein iPhone nötig.

Das ausführliche Konzept steht in `Konzept_BibelWatch.md`. **Lies vor jedem Meilenstein den betreffenden Abschnitt dort neu**, statt aus dem Gedächtnis zu arbeiten.

## Technische Leitplanken

- Swift 6, SwiftUI, Deployment Target watchOS 10.0. Kein UIKit, kein WatchKit-Storyboard.
- **Keine externen Abhängigkeiten.** Datenbankzugriff über `import SQLite3` direkt, nicht über GRDB oder SQLite.swift — die Widget-Extension braucht denselben Zugriff, und SPM-Pakete machen dort erfahrungsgemäss Ärger.
- Datenbank read-only öffnen (`SQLITE_OPEN_READONLY`), Verbindung einmal beim Start herstellen und halten, vorbereitete Statements zwischenspeichern. Niemals pro Abfrage neu öffnen.
- Datenbankzugriffe laufen nicht auf dem Main-Actor; Rückgabewerte sind `Sendable`-Structs.
- Kein `try!`, kein `as!`, keine stillschweigend verschluckten Fehler. Ein fehlender Vers ist ein `nil`, kein Absturz.
- Keine Netzwerk-APIs, keine Analytics, keine Berechtigungsabfragen. Wenn eine Lösung Netzwerk brauchen würde, ist es die falsche Lösung.

## Datenmodell

Schema und die vier benötigten Abfragen stehen in `Konzept_BibelWatch.md`, Kapitel 3 und 4. Nicht selber erfinden. Zwei Dinge sind bewusst so gebaut:

- `verse.id` ist lückenlos und je Übersetzung zusammenhängend, dazu `translation.first_verse_id` / `last_verse_id`. Zufallsvers = ein Primärschlüsselzugriff. **Nie `ORDER BY RANDOM()`** über die Verstabelle.
- `chapter_meta` ist vorberechnet. Für Auswahlräder keine `COUNT`-Abfragen schreiben.

Übersetzungen, Bücher und Copyright-Zeilen werden **zur Laufzeit aus der Datenbank gelesen**, nie im Code hartkodiert. Wird eine Übersetzung aus der Datenbank entfernt, muss die App ohne Codeänderung weiterlaufen.

## Versifikation

Deutsche und englische Bibeln zählen unterschiedlich (Psalmenüberschriften, Jes 9,5 vs. 9,6). Eine Stelle, die in einer Übersetzung existiert, kann in einer anderen fehlen. Gemessen: 29 Kapitel unterscheiden sich zwischen ELB und KJV in der Verszahl, 136 zwischen SLT und KJV. Es verschieben sich auch ganze Kapitelgrenzen (4Mo 16/17, 3Mo 5/6, Joel 3/4) — die falsche Stelle sieht dann völlig plausibel aus. `BibleRepository.resolve` liefert deshalb `.exact`, `.divergent`, `.clamped` oder `.unavailable`. **Jeder dieser Fälle ausser `.exact` muss in der Oberfläche sichtbar sein.** Wer das zu einem stillen Fallback vereinfacht, baut einen Fehler ein, der den falschen Bibeltext anzeigt, ohne zu warnen.

## Gestaltung

`Designspezifikation.md` ist verbindlich: Farbwerte, Schriftgrössen, Abstände, Rastergeometrie und das Verhalten aller Bildschirme stehen dort. `Design_TagNacht.html` zeigt dieselben Bildschirme gezeichnet. Farben gehören in einen Asset-Katalog mit Any/Dark-Variante, nicht als Konstanten in den Code.

Zwei Punkte, die keine Geschmacksfragen sind: Raster **immer dreispaltig** (vier Spalten ergeben 38 pt Zellen und unterschreiten die 44 pt für Tippziele), und bei `@Environment(\.isLuminanceReduced)` **immer** die Nachtpalette, unabhängig von der Einstellung.

## Zweisprachigkeit

Deutsch und Englisch, Anzeigesprache folgt dem System. Alle Texte über `Resources/Localizable.xcstrings` — **kein Klartext in Views**. Buchnamen kommen aus der Datenbank (`name` / `name_en`), nicht aus dem Katalog.

Der Trenner der Stellenangabe unterscheidet sich: «Johannes 3,16» gegen «John 3:16». Nie fest verdrahten, immer über `reference.format`.

Vorgabe der Bibelübersetzung: Deutsch → `elb`, Englisch → `kjv`, aber **nur beim ersten Start**. Eine vom Nutzer gewählte Übersetzung wird nie durch einen Sprachwechsel überschrieben. Logik liegt in `Shared/Localization.swift`.

## Bedienung auf einer Uhr

- Tippziele mindestens 44 × 44 Punkte. Kapitel- und Versauswahl als `LazyVGrid`, nicht als Liste.
- Digital Crown zum Scrollen in langen Texten und langen Listen anbinden.
- Dynamische Schriftgrössen verwenden, nichts unter `.caption2`.
- Haptik beim Weiterschalten (`WKInterfaceDevice.current().play(.click)`), abschaltbar.
- Beim Zufallsvers die letzten 20 Verse merken und nicht sofort wiederholen.

## Bereits gelieferter Code

`Data/Models.swift`, `Data/BibleDatabase.swift`, `Data/BibleRepository.swift`, `Shared/AppSettings.swift` und `PrivacyInfo.xcprivacy` liegen vor. Die **SQL-Strings und Spaltenindizes darin sind gegen die echte Datenbank verifiziert** (Abfragepläne geprüft, kein Table Scan). Nicht neu erfinden, nicht «aufräumen». Der Swift-Code wurde jedoch nie kompiliert — korrigiere, was der Compiler bemängelt, und sonst nichts.

`test_fixtures.json` enthält Erwartungswerte für die Unit-Tests, darunter alle 29 Kapitel, in denen ELB und KJV unterschiedlich viele Verse haben.

## Bauen — nach jeder Änderung

Kompilieren gehört zum Durchgang, nicht zur Nachkontrolle durch den Nutzer. Im Projektwurzelverzeichnis:

```bash
xcodebuild -project "Watch Bible.xcodeproj" \
           -scheme "Watch Bible Watch App" \
           -destination 'generic/platform=watchOS Simulator' \
           -derivedDataPath ./build -quiet build 2>&1 | grep -E "error:|warning:|BUILD"
```

Fehler selbst lesen und beheben, statt sie zu melden. Weiterführende Befehle und Fallstricke stehen im `README.md` unter «Bauen und prüfen».

Zwei Grenzen: ein erfolgreicher Build sagt nichts über das Layout — Bildschirme gehören in den Simulator angesehen. Und beim Beheben von Compilerfehlern bleiben die SQL-Strings und Spaltenindizes in `Data/` unangetastet; sie sind gegen die echte Datenbank verifiziert.

## Arbeitsweise

- Der Prototyp wird **verbessert, nicht ersetzt**. Vorhandenes, das der Spezifikation schon entspricht, bleibt. Vor der ersten Änderung eine Abweichungsliste erstellen und freigeben lassen (siehe `README.md`, «Erster Auftrag»).
- Ein Punkt der Liste pro Durchgang. Nicht vorgreifen, keine Funktionen bauen, die im Konzept nicht stehen.
- Nach jedem Meilenstein: kurz auflisten, welche Dateien entstanden sind und was in Xcode von Hand einzustellen ist (Target-Membership, Capabilities, Signing).
- Datenschicht und Referenzauflösung bekommen Unit-Tests. Randfälle, die immer zu prüfen sind: Ps 119,176, Jud 1,25, letzter Vers von Offb, erster Vers von 1. Mose.
- Es gibt zwei ausgelieferte Datenbanken (siehe `README.md`); die gewählte liegt im Projekt als `bible.sqlite`. Übersetzungs-`id` und Leitübersetzung unterscheiden sich zwischen beiden — deshalb **nie** fest verdrahten, immer zur Laufzeit aus der Datenbank lesen.
- Die Datei `bible.sqlite` wird nicht von Hand bearbeitet. Stimmt etwas am Inhalt nicht, wird `tools/quotepas_to_sqlite.py` angepasst und die Datenbank neu erzeugt.
- Antworten auf Deutsch, Schweizer Rechtschreibung, kein ß.
