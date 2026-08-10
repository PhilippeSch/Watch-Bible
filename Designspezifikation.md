# Designspezifikation — BibelWatch «Dünndruck»

Ein Entwurf, zwei Zustände: Papier bei Tag, Schwarz bei Nacht. Gleiche Struktur, gleiche Typografie, nur die Farbwerte tauschen. Auswahl über Register (Bücher) und Raster (Kapitel, Verse).

Referenz-Bildschirme: `Design_TagNacht.html`. Diese Datei ist die verbindliche Fassung — bei Widersprüchen gilt sie.

---

## 1. Farben

Als Asset-Katalog anlegen, nicht als Konstanten im Code. Jede Farbe bekommt eine Any/Dark-Variante, damit der Themenwechsel über `.environment(\.colorScheme, …)` läuft und nirgends von Hand geprüft werden muss.

| Rolle | Asset-Name | Tag | Nacht |
|---|---|---|---|
| Grund | `Ground` | `#E4E2DA` | `#000000` |
| Text | `Ink` | `#14161A` | `#E8E6E1` |
| Verszahl, aktive Auswahl | `Carmine` | `#8C1D2B` | `#C4525C` |
| Bändchen (Position) | `Brass` | `#A8842E` | `#C8A44D` |
| Sekundärtext, Zahlen | `Secondary` | `#8E8B7E` | `#7E858C` |
| Trennlinie | `Rule` | `#C9C5B8` | `#1F2124` |
| Feldfläche (Raster, Register) | `Field` | `#D8D5CA` | `#141618` |

Zwei Akzente, mehr nicht: **Karmin** trägt Verszahl und aktive Auswahl, **Messing** trägt ausschliesslich die Position. Keine dritte Farbe, keine Signalfarbe für Warnungen.

### Themenwechsel

| Auslöser | Verhalten |
|---|---|
| Einstellung `Tag` / `Nacht` | fest |
| Einstellung `Automatisch` (Standard) | Nacht zwischen zwei selbst gesetzten Uhrzeiten, Vorgabe 20:00–07:00 |
| `@Environment(\.isLuminanceReduced)` | **immer** Nachtpalette, unabhängig von der Einstellung |

Kein Standortzugriff und kein Sonnenuntergang: das würde eine Berechtigung und einen zweiten Eintrag im Privacy-Manifest nach sich ziehen, für einen Nutzen, den zwei Uhrzeiten ebenso erbringen.

Bei `isLuminanceReduced` zusätzlich: Zählerzeile ausblenden, Verstext auf die ersten Zeilen kürzen, keine Animation.

---

## 2. Typografie

Systemschrift SF Compact, im Fliesstext die serife Variante (`.font(.system(.body, design: .serif))`). Verszahlen, Bedienelemente und Zahlen serifenlos — der Bruch ist beabsichtigt und entspricht dem Satz einer gedruckten Bibel.

| Rolle | Grösse | Schnitt | Farbe |
|---|---|---|---|
| Verstext, gross | 18 pt | Serif, Regular | `Ink` |
| Verstext, mittel (Vorgabe) | 16 pt | Serif, Regular | `Ink` |
| Verstext, klein | 14 pt | Serif, Regular | `Ink` |
| Hochgestellte Verszahl | 0.6 × Verstext, Grundlinie +0.44 em | Sans, Bold | `Carmine` |
| Stellenangabe über dem Vers | 11 pt, Versalien, Sperrung 0.15 em | Sans, Semibold | `Carmine` |
| Bildschirmtitel, Uhrzeit | 10.5 pt | Sans, Semibold | `Secondary` |
| Rasterziffern | 17 pt, tabellarisch | Sans, Semibold | `Ink` bzw. `Ground` auf Karmin |
| Zählerzeile, Verszahlen in Listen | 9 pt, tabellarisch | Mono | `Secondary` |
| Registerbeschriftung | 9.5 pt | Sans, Bold | `Secondary` bzw. `Ground` auf Karmin |

Alle Grössen sind Ausgangswerte für die erste Umsetzung. Die Ersatzschrift im HTML rendert breiter als SF Compact — **Zeilenumbrüche im Simulator prüfen, bevor die Werte festgeschrieben werden.** Dynamische Schriftgrössen des Systems müssen weiterhin greifen; die drei Stufen der Einstellung skalieren zusätzlich.

---

## 3. Geometrie

Bezug ist die 45-mm-Uhr: 396 × 484 px = **198 × 242 pt**. Kleinere Gehäuse verkleinern proportional, das Raster bleibt dreispaltig.

| Grösse | Wert |
|---|---|
| Rand links (mit Bändchen) | 22 pt |
| Rand links (ohne Bändchen) | 14 pt |
| Rand rechts | 14 pt |
| Rand oben (unter Titelzeile) | 26 pt |
| Rand unten | 13 pt |
| Bändchen | 2.5 pt breit, links bei 11 pt, oben 25 pt bis unten 16 pt |
| Register rechts | 62 px = 31 pt breit, Ecken links 10 pt gerundet |

### Raster für Kapitel und Verse

**Drei Spalten, 12 pt Abstand, Zellhöhe 52 pt.** Nachgerechnet: (198 − 2 × 14 − 2 × 6) ÷ 3 = **52.7 pt** pro Zelle. Vier Spalten ergäben 38 pt, fünf Spalten 29 pt — beides unterschreitet die übliche Mindestgrösse von 44 pt für Tippziele.

**Register und Raster schliessen sich aus.** Mit Register bleiben pro Zelle nur 42 pt. Das Register ist deshalb der Buchwahl vorbehalten, wo es 66 Einträge erschliesst; Kapitel und Verse bekommen das volle Raster.

---

## 4. Bildschirme

### 4.1 Einstieg
`NavigationStack` mit zwei Zeilen — **Zufallsvers**, **Nachschlagen** — darunter **Einstellungen**. Gab es eine zuletzt gelesene Stelle, erscheint sie als dritte Zeile: «Weiterlesen · Psalm 23,3». Kein Startbildschirm, kein Onboarding.

### 4.2 Zufallsvers
- Stellenangabe oben in Versalien, Karmin.
- Verstext als Fliesstext, hochgestellte Verszahl vorangestellt.
- Bändchen links zeigt die Position des Verses im Kapitel.
- Zählerzeile unten: `18 463 / 31 103` links, Übersetzungskürzel rechts. Die Zahl ist die `verse.id` aus der Datenbank, keine Berechnung fürs Layout.
- Weiterschalten: Wischen nach oben (`TabView`, `.verticalPage`) **und** Tippen auf die gesamte Fläche. Haptik `.click`, abschaltbar.
- Die letzten 20 Verse merken und nicht wiederholen.
- Tippen auf die Stellenangabe öffnet die Leseansicht am selben Vers.

### 4.3 Nachschlagen — Bücher
- Liste, in Abschnitte `Altes Testament` / `Neues Testament` geteilt.
- Rechts das Register mit sieben Sprungmarken: `1Mo · Jos · Ps · Jes · Mt · Rom · Offb`. Aktive Marke in Karmin.
- Je Zeile: Buchname links, Kapitelzahl rechts in Monoschrift.

### 4.4 Nachschlagen — Kapitel und Verse
- Dreispaltiges Raster, Zellen mit `Field` hinterlegt, 14 pt gerundet.
- Aktueller Eintrag in Karmin, Ziffer in Grundfarbe.
- **Nicht vorhandene Verse bleiben sichtbar, aber auf 32 % Deckkraft gesetzt** statt ausgeblendet. Damit wird die Grenze des Kapitels begreifbar, statt nur zu fehlen.
- Zählerzeile unten: `6 Verse`, Übersetzungskürzel.

### 4.5 Leseansicht
- Das ganze Kapitel als **Fliesstext**, nicht Zeile pro Vers. Hochgestellte Verszahlen wie im Druck.
- Der gewählte Vers in voller Deckkraft, die übrigen auf 70 % — kein Farbwechsel, kein Rahmen.
- Krone scrollt, das Bändchen bewegt sich mit.
- Werkzeugleiste: Übersetzung wechseln.

### 4.6 Abweichungsfall
Löst `BibleRepository.resolve` etwas anderes als `.exact` auf, erscheint unter dem Verstext eine zweizeilige Tabelle mit beiden Verszahlen des Kapitels, darunter eine Zeile mit Karminstrich links:

```
Elberfelder            26 Verse
King James             19 Verse
│ Vers 26 angefragt, Kapitelende gezeigt.
```

Keine Signalfarbe, kein Symbol, nichts zum Wegklicken. Zwei Zahlen erklären den Sachverhalt vollständig; eine Warnung würde ihn dramatisieren, ohne mehr zu sagen.

| Fall | Anzeige |
|---|---|
| `.exact` | nichts |
| `.divergent` | Tabelle mit beiden Verszahlen |
| `.clamped` | Tabelle plus Zeile «Vers *n* angefragt, Kapitelende gezeigt.» |
| `.unavailable` | «Dieses Kapitel gibt es in der *X* nicht.» und Rücksprung zur Buchwahl |

### 4.7 Einstellungen
Übersetzung · Zufallsmodus · Darstellung (Tag / Nacht / Automatisch, bei Automatisch zwei Uhrzeiten) · Schriftgrösse · Haptik · Impressum. Die Copyright-Zeilen im Impressum kommen aus `translation.copyright`, nicht aus dem Code.

---

## 5. Zweisprachigkeit

Die App erscheint auf Deutsch und Englisch. Die Anzeigesprache folgt dem System; eine eigene Spracheinstellung gibt es nicht.

**Texte** liegen in `Resources/Localizable.xcstrings` (String Catalog, 45 Schlüssel, beide Sprachen vollständig), der App-Name in `Resources/InfoPlist.xcstrings` — «Bibel» beziehungsweise «Bible», kurz gehalten, weil unter dem Symbol auf der Uhr wenig Platz ist. Schlüssel sind semantisch benannt (`settings.textSize`), nicht der englische Text selbst: bei zwei Sprachen, von denen eine Schweizer Orthografie verwendet, sind sprechende Schlüssel weniger fehleranfällig.

**Vorgabe der Bibelübersetzung nach Anzeigesprache:** Deutsch → Elberfelder 1905, Englisch → King James Version. Das gilt **nur beim ersten Start**. Wer einmal eine Übersetzung gewählt hat, behält sie, auch nach einem Sprachwechsel des Systems. Ist die Vorgabe nicht in der Datenbank, greift die erste Übersetzung derselben Sprache, sonst die erste überhaupt. Umgesetzt in `Shared/Localization.swift`.

**Buchnamen** kommen aus der Datenbank, nicht aus dem String Catalog: `book.name` für Deutsch, `book.name_en` für Englisch. Beide Spalten sind für alle 66 Bücher gefüllt.

**Die Stellenangabe ist selbst lokalisiert.** Deutsche Bibeln schreiben «Johannes 3,16», englische «John 3:16» — Komma gegen Doppelpunkt. Der Trenner steht deshalb im String Catalog (`reference.format`) und darf nirgends fest verdrahtet werden. Ebenso die Zahlen der Zählerzeile: 18’463 auf Deutsch (Schweiz), 18,463 auf Englisch, über `formatted(.number)`.

**Pluralformen** für «%lld Kapitel» und «%lld Verse» sind als Varianten hinterlegt. Im Englischen unterscheiden sich Einzahl und Mehrzahl, im Deutschen bei «Kapitel» nicht — beides ist im Katalog korrekt abgebildet.

Was nicht übersetzt wird: die Namen der Bibelübersetzungen selbst («Elberfelder 1905», «King James Version») sind Eigennamen und kommen unverändert aus `translation.name`.

## 5a. Chinesische Schrift

Die Datenbank enthält das 和合本 in traditionellen und vereinfachten Zeichen. Für die Darstellung heisst das:

- **Schriftgrösse anheben.** Chinesische Schriftzeichen brauchen bei gleicher Lesbarkeit mehr Fläche als lateinische. Ausgangswert: Verstext 18 pt statt 16 pt, wenn `translation.language` mit `zh` beginnt.
- **Zeilenabstand erhöhen** auf etwa 1.6 statt 1.42 — CJK-Schriften füllen die Zeile dichter.
- **Keine serife Variante erzwingen.** Das System setzt PingFang SC bzw. TC; ein Serif-Design-Parameter greift dort nicht wie bei lateinischer Schrift.
- **U+3000 nie wegkürzen.** Der ideographische Abstand vor 神 ist Teil des Textes, keine überflüssige Formatierung.
- Die Textmenge ist unkritisch: längster chinesischer Vers 108 Zeichen gegenüber 503 im Deutschen.

Die Bedienoberfläche bleibt deutsch und englisch. Buchnamen und Stellenangaben erscheinen deshalb auch bei chinesischem Verstext in der Anzeigesprache — «Johannes 3,16» über einem chinesischen Vers. Das ist bei mehrsprachigen Bibelprogrammen üblich und bewusst so.

## 6. Was bewusst fehlt

- **Goldschnitt am Bildschirmrand.** War in Entwurf A die Fortschrittsanzeige, das macht jetzt das Bändchen. Zwei Positionsanzeigen auf 45 mm sind eine zu viel.
- **Register für Kapitel und Verse.** Rechnerisch unmöglich neben einem Raster.
- **Eine dritte Akzentfarbe.** Karmin und Messing tragen je genau eine Bedeutung.
- **Animationen ausser dem Seitenwechsel.** Auf einer Uhr kostet jede Bewegung Zeit, die der Nutzer nicht hat.
