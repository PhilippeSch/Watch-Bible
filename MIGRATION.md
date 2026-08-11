# Abweichungsliste — Prototyp gegen Spezifikation

Stand: 10. August 2026. Baseline: Prototyp baut fehlerfrei (2 Warnungen im alten Parser).

> **Status: alle Punkte 1–13 umgesetzt** (M6 Widget und M7 Archiv am
> 10. August 2026 nachgezogen). Build grün unter Swift 6, alle Unit-Tests
> bestehen, Bildschirme im Simulator geprüft (Tag und Nacht, Deutsch und
> Englisch, Abweichungsfall 3Mo 5 ELB↔KJV). Archiv signiert und validiert:
> **47.0 MB unkomprimiert** (Limit 75 MB), Privacy-Manifest als Plist gültig.
>
> **Deployment Targets.** Die watchOS-Ziele stehen auf 11.2. Der iOS-Container
> («Watch Bible.app», reine Hülle einer Watch-only-App) hatte gar kein
> `IPHONEOS_DEPLOYMENT_TARGET` und fiel damit auf den SDK-Vorgabewert 13.0
> zurück — App Store Connect beanstandet das, weil ab Frühjahr 2027 mindestens
> 15.0 verlangt wird. Jetzt fest auf **15.0** gesetzt (beide Konfigurationen
> des Container-Targets); im Archiv geprüft: `MinimumOSVersion` = 15.0.
> Die Hülle wird nie ausgeführt, ihr Wert steuert nur die Store-Annahme —
> die Uhr selbst bleibt bei watchOS 11.2.
>
> **Build-Nummern.** `CURRENT_PROJECT_VERSION` gilt in allen fünf Targets
> gemeinsam; Container, Watch-App und Widget müssen dieselbe `CFBundleVersion`
> tragen. Build 1 wurde am 10. August 2026 verbraucht (zwei Uploads, der zweite
> als Dublette abgewiesen) — **jede weitere Lieferung braucht eine höhere
> Nummer**, aktuell steht sie auf 2. `MARKETING_VERSION` bleibt 1.0.
>
> **Archivieren mit dem Schema `Watch Bible Watch App`.** Xcode legte beim
> Anlegen des Widgets automatisch ein Schema `BibelWatchWidget` an; archiviert
> man damit, ist das Ergebnis inhaltlich korrekt, heisst im Organizer aber nach
> der Extension.
>
> **M6 (Widget):** Target `BibelWatchWidget` (accessoryRectangular +
> accessoryCircular), deterministischer Tagesvers, Zeitleiste 7 Tage,
> Deep Link `watchbible://verse/<buch>/<kapitel>/<vers>`. Das Widget teilt
> Datenschicht und String-Katalog mit der App (Exception-Set im Projekt),
> liest `bible.sqlite` aber **aus dem App-Bundle** (zwei Ebenen über der
> .appex) — eine eigene Kopie hätte das Paket auf 90.5 MB verdoppelt.
> Bewusst ohne App Group: das Widget folgt der Systemsprache statt der
> gewählten Übersetzung, dafür bleibt das Privacy-Manifest bei CA92.1.
> Von Hand zu prüfen: Widget im Simulator zum Smart Stack hinzufügen.

## Erkenntnisse aus der Umsetzung

- **watchOS wertet Any/Dark-Farbvarianten nicht aus** und ignoriert auch
  `\.colorScheme` für benannte Farben (im Simulator verifiziert). Statt der in
  der Designspezifikation vorgesehenen Any/Dark-Assets gibt es je Rolle zwei
  Colorsets (`…Day`/`…Night`); `ThemeState` in `Shared/Theme.swift` schaltet
  zentral und beobachtbar. Die Farbwerte liegen weiterhin nur im Asset-Katalog.
- **Synchronisierte Ordner vertragen keine Build-Produkte:** codesign
  scheitert an den xattrs («detritus»), die der File Provider den Dateien
  anhängt — das gilt auch für den Documents-Ordner am neuen Projektort.
  Derived Data deshalb immer nach `~/Library/Developer/WatchBible-build`
  (README und CLAUDE.md sind angepasst).
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

## Nachtrag 11. August 2026 — Oberfläche in allen Übersetzungssprachen

Die App erschien bis dahin nur auf Deutsch und Englisch, obwohl die Datenbank
Übersetzungen in sechs Sprachen führt. Jetzt gilt: **eine Oberflächensprache je
Übersetzungssprache** — `de`, `en`, `es`, `fr`, `zh-Hant`, `zh-Hans`.

| Was | Wo |
|---|---|
| Buchnamen der vier neuen Sprachen | `book.name_es`, `name_fr`, `name_zh_hant`, `name_zh_hans`; Schema-Version 2 |
| Namenstabellen und Konverter | `tools/quotepas_to_sqlite.py`, Nachtrag über `tools/add_book_names.py` |
| Sprachlogik | `Shared/Localization.swift` — `supportedLanguages`, `normalized`, `languageOrder` |
| Texte | `Localizable.xcstrings` 58 Schlüssel × 6 Sprachen, `InfoPlist.xcstrings`, `knownRegions` |
| Auswahl und Vorgabe | erste Übersetzung der Anzeigesprache in Datenbankreihenfolge, ihr Abschnitt zuoberst |
| Tests | `SprachenTests` — 8 Prüfungen, darunter der Abgleich Übersetzungssprachen ↔ Oberflächensprachen |

Drei Punkte, die dabei nicht offensichtlich sind:

- **`prefix(2)` auf der Sprachkennung war ein Fehler.** `zh-Hant` und `zh-Hans`
  unterscheiden sich in der Schrift; gekürzt auf `zh` hätte keine der beiden
  chinesischen Übersetzungen je gegriffen. `Localization.normalized` bildet
  Systemkennungen jetzt vollständig ab (`zh-TW` → `zh-Hant`, `zh` → `zh-Hans`).
- **Die Vorgabe je Sprache steht in der Datenbank, nicht im Code.** Die Regel
  «erste Übersetzung dieser Sprache» liest `sort_order`. In der ersten Fassung
  stand dort DAR vor KJV, Englisch bekam also Darby; die Reihenfolge ist am
  11. August 2026 auf **KJV vor DAR** geändert worden. Festgelegt wird sie an
  genau einer Stelle: `TRANSLATION_ORDER` in `tools/quotepas_to_sqlite.py`.
  `tools/reorder_translations.py` trägt dieselbe Liste in eine bereits erzeugte
  Datenbank nach und ändert dabei **nur** `sort_order` — `translation.id`,
  `first_verse_id`/`last_verse_id` und die Verstabelle bleiben, wie sie sind,
  sonst würde `test_fixtures.json` ungültig. `id` und `sort_order` laufen
  dadurch auseinander (KJV: `id` 3, `sort_order` 2); die App liest nur
  `ORDER BY sort_order`.
- **Die Buchnamensspalten werden zur Laufzeit gesucht** (`PRAGMA table_info`),
  nicht fest in die Abfrage geschrieben: eine Datenbank aus einem älteren
  Konverterlauf kennt sie nicht, und ein `no such column` beim Vorbereiten
  hätte die App beim Start scheitern lassen. Fehlt eine Spalte, steht für diese
  Sprache der deutsche Buchname — `tools/add_book_names.py` trägt sie nach.

Geprüft: Build ohne Warnung, 18 Unit-Tests grün, App im Simulator in allen
sechs Sprachen aufgerufen (Startbildschirm, Buchliste mit Register,
Einstellungen, Übersetzungswahl, Zufallsvers).
