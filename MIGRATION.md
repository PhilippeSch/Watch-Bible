# Abweichungsliste — Prototyp gegen Spezifikation

Stand: 10. August 2026. Baseline: Prototyp baut fehlerfrei (2 Warnungen im alten Parser).

> **Status: Punkte 1–12 umgesetzt** (Durchgang vom 10. August 2026). Build grün
> unter Swift 6, alle Unit-Tests bestehen, Bildschirme im Simulator geprüft
> (Tag und Nacht, Deutsch und Englisch, Abweichungsfall 3Mo 5 ELB↔KJV).
> Offen: Punkt 13 (Widget) sowie die Hinweise unter «Erkenntnisse».

## Erkenntnisse aus der Umsetzung

- **watchOS wertet Any/Dark-Farbvarianten nicht aus** und ignoriert auch
  `\.colorScheme` für benannte Farben (im Simulator verifiziert). Statt der in
  der Designspezifikation vorgesehenen Any/Dark-Assets gibt es je Rolle zwei
  Colorsets (`…Day`/`…Night`); `ThemeState` in `Shared/Theme.swift` schaltet
  zentral und beobachtbar. Die Farbwerte liegen weiterhin nur im Asset-Katalog.
- **OneDrive verträgt keine Build-Produkte:** codesign scheitert an den
  xattrs («detritus»), die OneDrive den Dateien anhängt. Derived Data muss
  ausserhalb des synchronisierten Ordners liegen (nicht `./build`).
- **Datenfund:** In der BSB fehlt Klagelieder 2,1 (Kapitel beginnt bei Vers 2)
  — einziger solcher Fall in der ganzen Datenbank. Quelle prüfen, Datenbank
  neu erzeugen (eigene Aufgabe).
- `xcode-select` zeigt auf die CommandLineTools; Befehle brauchen
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

## Was der Prototyp heute macht

- Lädt die rohe LaTeX-Quelldatei `bible.db` (25 MB) beim Start **komplett in den Speicher** und sucht Verse per String-Suche. Kein SQLite.
- Buchliste, Verszahlen und Übersetzungen sind **im Code hartkodiert** (`verseCountMap`, `getBooks()`, `getTranslations()`).
- UI: Picker-Kette (Übersetzung → Testament → Buch → Kapitel → Vers) als Listen, Standard-Look, keine Lokalisierung, kein Zufallsvers, keine Einstellungen.
- Kein Privacy-Manifest, keine Tests, kein Tag/Nacht-Thema.

## Abweichungen (sortiert nach Reihenfolge der Umsetzung)

| # | Punkt | Prototyp | Spezifikation | Aufwand |
|---|---|---|---|---|
| 1 | Datenschicht | String-Parser über LaTeX-Datei | SQLite read-only, Actor, Statement-Cache (`Data/`) | mittel — Code liegt vor |
| 2 | Datenbank | `bible.db` (Rohtext, 25 MB) | `bible.sqlite` (frei, 9 Übersetzungen, 44 MB) | klein |
| 3 | Stammdaten | hartkodiert | zur Laufzeit aus der Datenbank | fällt mit 1 weg |
| 4 | Lokalisierung | deutsch, Klartext in Views | de+en über String Catalogs, `Localization.swift` | klein — Kataloge liegen vor |
| 5 | Einstellungen | keine | Übersetzung, Zufallsmodus, Darstellung, Schrift, Haptik, Impressum | mittel |
| 6 | Zufallsvers | fehlt | zwei Modi, Wiederholungssperre, Wischen+Tippen, Haptik | mittel |
| 7 | Nachschlagen | Listen-Picker | Register (Bücher) + 3-Spalten-Raster (Kapitel/Verse) | mittel |
| 8 | Leseansicht | Einzelvers | Kapitel als Fliesstext, hochgestellte Verszahlen, Bändchen | mittel |
| 9 | Versifikation | ignoriert | `resolve` mit sichtbarem `.divergent`/`.clamped`/`.unavailable` | Code liegt vor, UI nötig |
| 10 | Gestaltung | Standard | «Dünndruck» Tag/Nacht, Asset-Katalog, `isLuminanceReduced` | mittel |
| 11 | Privacy-Manifest | fehlt | `PrivacyInfo.xcprivacy`, UserDefaults CA92.1 | klein — liegt vor |
| 12 | Unit-Tests | leere Vorlage | Datenschicht + Versifikation gegen `test_fixtures.json` | mittel |
| 13 | Widget | fehlt | Vers des Tages (M6) | **zurückgestellt** — braucht neues Target |

## Entscheide

- **Datenbank:** `bible.sqlite` (9 freie Übersetzungen) gemäss README — die SLT-Variante nur mit Genehmigung der Genfer Bibelgesellschaft.
- **Deployment Target** bleibt watchOS 11.2 (Prototyp-Stand, über der Mindestvorgabe 10.0).
- Alte Dateien (`Models/BibleDatabase.swift`, `Views/*`, `Resources/bible.db`) werden ersetzt; Git behält die Historie.
- Widget (M6) und Archive-Prüfung (M7) folgen in eigenen Durchgängen.
