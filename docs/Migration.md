# Vom Prototyp zur heutigen App

**Abgeschlossen im August 2026.** Dieses Dokument ist ein Nachweis, keine Aufgabenliste: es hält fest, was der Prototyp war, was daraus wurde und was sich dabei als nicht offensichtlich herausgestellt hat. Für den heutigen Aufbau gilt [Architektur.md](Architektur.md).

## Was der Prototyp war

- Lud die rohe LaTeX-Quelldatei `bible.db` (25 MB) beim Start **komplett in den Speicher** und suchte Verse per String-Suche. Kein SQLite.
- Buchliste, Verszahlen und Übersetzungen waren **im Code hartkodiert** (`verseCountMap`, `getBooks()`, `getTranslations()`).
- Oberfläche: eine Picker-Kette (Übersetzung → Testament → Buch → Kapitel → Vers) als Listen im Standard-Look. Keine Lokalisierung, kein Zufallsvers, keine Einstellungen.
- Kein Privacy-Manifest, keine Tests, kein Tag/Nacht-Thema, kein Widget.

## Was daraus wurde

| # | Punkt | Vorher | Nachher |
|---|---|---|---|
| 1 | Datenschicht | String-Parser über LaTeX-Datei | SQLite read-only, Actor, Statement-Cache (`Data/`) |
| 2 | Datenbank | `bible.db` (Rohtext, 25 MB) | `bible.sqlite` (10 Übersetzungen, 50.9 MB) |
| 3 | Stammdaten | hartkodiert | zur Laufzeit aus der Datenbank |
| 4 | Lokalisierung | deutsch, Klartext in Views | sechs Sprachen über String Catalogs, `Localization.swift` |
| 5 | Einstellungen | keine | Übersetzung, Zufallsmodus, Darstellung, Schrift, Haptik, Impressum |
| 6 | Zufallsvers | fehlte | zwei Modi, Wiederholungssperre, Wischen + Tippen, Haptik |
| 7 | Nachschlagen | Listen-Picker | Register (Bücher) + dreispaltiges Raster (Kapitel/Verse) |
| 8 | Leseansicht | Einzelvers | Kapitel als Fliesstext, hochgestellte Verszahlen, Bändchen |
| 9 | Versifikation | ignoriert | `resolve` mit sichtbarem `.divergent` / `.clamped` / `.unavailable` |
| 10 | Gestaltung | Standard | «Dünndruck» Tag/Nacht, Asset-Katalog, `isLuminanceReduced` |
| 11 | Privacy-Manifest | fehlte | `PrivacyInfo.xcprivacy`, UserDefaults CA92.1 |
| 12 | Unit-Tests | leere Vorlage | Datenschicht, Versifikation, Sprachen, Themen gegen `test_fixtures.json` |
| 13 | Widget | fehlte | Vers des Tages, `accessoryRectangular` + `accessoryCircular`, Deep Link |

Danach kamen die Themen (`curated.topic` als eigener Bildschirm) und die Ausweitung der Oberfläche auf alle sechs Übersetzungssprachen dazu.

## Erkenntnisse, die den Aufwand geprägt haben

**watchOS wertet Any/Dark-Farbvarianten nicht aus** und ignoriert auch `\.colorScheme` für benannte Farben (im Simulator verifiziert). Statt der ursprünglich vorgesehenen Any/Dark-Assets gibt es je Rolle zwei Colorsets (`…Day` / `…Night`); `ThemeState` in `Shared/Theme.swift` schaltet zentral und beobachtbar. Die Farbwerte liegen weiterhin nur im Asset-Katalog. Der Bildschirmtitel gehorcht weder `\.colorScheme` noch `.tint` — er nimmt ausschliesslich `AccentColor`, weshalb dort ein einziger mittlerer Grauton steht, der auf beiden Gründen trägt.

**Synchronisierte Ordner vertragen keine Build-Produkte.** codesign scheitert an den erweiterten Attributen, die der File Provider den Dateien anhängt («detritus») — das gilt auch für den Documents-Ordner. Derived Data deshalb immer nach `~/Library/Developer/WatchBible-build`.

**Ein Build-Skript, das in `project.pbxproj` schreibt, ist mit Testen unvereinbar.** Die erste Fassung der automatischen Build-Nummer rief `xcrun agvtool new-version` auf; jeder Testlauf aus Xcode heraus (⌘U) brach danach ab, ohne einen einzigen Test auszuführen — ohne Fehler, ohne Meldung, im `.xcresult` nur `"status": "cancelled"` bei `errorCount: 0`. Xcode lädt das Projekt neu, sobald die Projektdatei sich ändert, und bricht den laufenden Vorgang ab. Über die Kommandozeile lief derselbe Testlauf durch, weil `xcodebuild` kein Projekt neu lädt. Einen Ausweg über `$ACTION` gibt es nicht: bei ⌘U steht `ACTION` genauso auf `build` wie bei ⌘B. Geschrieben wird jetzt ausschliesslich `Config/Version.xcconfig`.

**`prefix(2)` auf der Sprachkennung war ein Fehler.** `zh-Hant` und `zh-Hans` unterscheiden sich in der Schrift; gekürzt auf `zh` hätte keine der beiden chinesischen Übersetzungen je gegriffen. `Localization.normalized` bildet Systemkennungen vollständig ab (`zh-TW` → `zh-Hant`, `zh` → `zh-Hans`).

**`Int` ist auf der Uhr 32 Bit breit.** `%lld` im String Catalog liest 64 Bit; ohne `Int64(...)` stand auf dem Gerät «2. Petrus 0». Im Simulator (arm64) ist davon nichts zu sehen — der Fehler trat erst auf der echten Uhr auf.

**Die Namens- und Kürzelspalten werden zur Laufzeit gesucht** (`PRAGMA table_info`), nicht fest in die Abfrage geschrieben: eine Datenbank aus einem älteren Konverterlauf kennt sie nicht, und ein `no such column` beim Vorbereiten hätte die App beim Start scheitern lassen.

**Die Vorgabe je Sprache steht in der Datenbank, nicht im Code.** Die Regel «erste Übersetzung dieser Sprache» liest `sort_order`. In der ersten Fassung stand dort DAR vor KJV, Englisch bekam also Darby. `tools/reorder_translations.py` trägt eine geänderte Reihenfolge nach und ändert dabei **nur** `sort_order` — `translation.id`, `first_verse_id`/`last_verse_id` und die Verstabelle bleiben, wie sie sind, sonst würde `test_fixtures.json` ungültig. `id` und `sort_order` laufen dadurch auseinander (KJV: `id` 3, `sort_order` 2); die App liest nur `ORDER BY sort_order`.

**Das Widget teilt die Datenbank mit der App**, statt sie zu kopieren: es liest `bible.sqlite` zwei Ebenen über der `.appex` aus dem App-Bundle. Eine eigene Kopie hätte das Paket verdoppelt und das 75-MB-Limit gesprengt. Bewusst ohne App Group — das Widget folgt der Systemsprache statt der gewählten Übersetzung, dafür bleibt das Privacy-Manifest bei CA92.1.

**Der iOS-Container braucht ein eigenes Deployment Target.** Die Hülle einer watchOS-only App hatte gar kein `IPHONEOS_DEPLOYMENT_TARGET` und fiel damit auf den SDK-Vorgabewert 13.0 zurück; App Store Connect beanstandet das. Jetzt fest auf 15.0. Die Hülle wird nie ausgeführt, ihr Wert steuert nur die Annahme im Store — die Uhr selbst bleibt bei watchOS 11.2.

**Export Compliance wird am iOS-Container geprüft**, nicht an der Watch-App: `ITSAppUsesNonExemptEncryption` muss in beiden Targets stehen.

## Offen geblieben

**In der BSB fehlt Klagelieder 2,1** — das Kapitel beginnt bei Vers 2, der einzige solche Fall in der ganzen Datenbank. Die App zeigt die Lücke sauber an; zu klären bleibt, ob die Quelle den Vers wirklich nicht führt. Siehe [Bibeltexte.md](Bibeltexte.md).

**Die Schlachter 1951 sollte aus der CC-BY-Quelle bei ebible.org neu bezogen werden.** Der verwendete Text ist inhaltlich geprüft, die Quelldatei trägt aber noch einen älteren, engeren Lizenzvermerk im Kopf. Ebenfalls in [Bibeltexte.md](Bibeltexte.md).
