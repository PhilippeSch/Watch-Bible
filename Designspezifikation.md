# Designspezifikation — BibelWatch «Dünndruck»

Ein Entwurf, zwei Zustände: Papier bei Tag, Schwarz bei Nacht. Gleiche Struktur, gleiche Typografie, nur die Farbwerte tauschen. Auswahl über Register (Bücher) und Raster (Kapitel, Verse).

Referenz-Bildschirme: `Design_TagNacht.html`. Diese Datei ist die verbindliche Fassung — bei Widersprüchen gilt sie.

---

## 1. Farben

Als Asset-Katalog anlegen, nicht als Konstanten im Code. Jede Rolle bekommt zwei Colorsets (`…Day` / `…Night`): watchOS wertet die Any/Dark-Variante eines Assets nicht aus, `Color("Ground")` bliebe im Tagmodus schwarz. Umgeschaltet wird zentral in `ThemeState`. `\.colorScheme` wird zusätzlich gesetzt — nicht für diese Farben, sondern für alles, was das System selbst zeichnet (Picker-Wert, Warnhinweise, `.secondary`).

| Rolle | Asset-Name | Tag | Nacht |
|---|---|---|---|
| Grund | `Ground` | `#E4E2DA` | `#000000` |
| Text | `Ink` | `#14161A` | `#E8E6E1` |
| Verszahl, aktive Auswahl | `Carmine` | `#8C1D2B` | `#C4525C` |
| Bändchen (Position) | `Brass` | `#A8842E` | `#C8A44D` |
| Sekundärtext, Zahlen | `Secondary` | `#5E5B4C` | `#7E858C` |
| Trennlinie | `Rule` | `#C9C5B8` | `#1F2124` |
| Feldfläche (Raster, Register) | `Field` | `#D8D5CA` | `#141618` |
| Bildschirmtitel (Systemleiste) | `AccentColor` | `#706C5F` | `#706C5F` |

Zwei Akzente, mehr nicht: **Karmin** trägt Verszahl und aktive Auswahl, **Messing** trägt ausschliesslich die Position. Keine dritte Farbe, keine Signalfarbe für Warnungen.

Der Tagwert von `Secondary` war ursprünglich `#8E8B7E` und erreichte auf der Feldfläche nur 2,3 : 1 — auf einer Uhr im Freien nicht lesbar. `#5E5B4C` bringt 4,6 : 1 auf `Field` und 5,3 : 1 auf `Ground`.

`AccentColor` ist die einzige Stellschraube für den Bildschirmtitel: watchOS zieht dafür weder `\.colorScheme` noch `.tint`, und die Dark-Variante des Assets wird nie ausgewertet (im Simulator geprüft). Der eine Wert muss deshalb auf beiden Gründen tragen — `#706C5F` ergibt 4,0 : 1 auf Papier wie auf Schwarz, das Maximum, das ein einzelner Wert für beide Zustände zulässt.

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
| Bildschirmtitel | 10.5 pt | Sans, Semibold | `AccentColor` (Grösse und Schnitt gibt watchOS vor) |
| Uhrzeit | — | — | zeichnet watchOS, weiss, nicht beeinflussbar |
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
`NavigationStack` mit drei Zeilen — **Zufallsvers**, **Themen**, **Nachschlagen** — darunter **Einstellungen**. Gab es eine zuletzt gelesene Stelle, erscheint sie als weitere Zeile: «Weiterlesen · Psalm 23,3». Kein Startbildschirm, kein Onboarding.

### 4.2 Zufallsvers
- Stellenangabe oben in Versalien, Karmin.
- Verstext als Fliesstext, hochgestellte Verszahl vorangestellt.
- Bändchen links zeigt die Position des Verses im Kapitel.
- Zählerzeile unten: `18 463 / 31 103` links, Übersetzungskürzel rechts. Die Zahl ist die `verse.id` aus der Datenbank, keine Berechnung fürs Layout.
- Weiterschalten: Wischen nach oben (`TabView`, `.verticalPage`) **und** Tippen auf die gesamte Fläche. Haptik `.click`, abschaltbar.
- Die letzten 20 Verse merken und nicht wiederholen.
- Tippen auf die Stellenangabe öffnet die Leseansicht am selben Vers.

### 4.2a Themen
- Liste wie die Buchwahl, aber **ohne Register**: 26 Einträge erschliessen sich mit der Krone, 66 nicht mehr. Je Zeile der Themenname links, die Anzahl Verse rechts in Monoschrift.
- Themen und Anzahl kommen zur Laufzeit aus `curated`; ein Thema mehr in der Datenbank ist eine Zeile mehr, ohne Codeänderung.
- Sortiert nach dem Namen der **Anzeigesprache**, nicht nach dem deutschen Schlüssel — «Amour» steht im Französischen vorn.
- Ein Tipp öffnet den Zufallsvers, auf dieses Thema beschränkt: dieselbe Ansicht wie 4.2, mit dem Thema als Bildschirmtitel. Die Wiederholungssperre greift dort über die **Stelle** statt über `verse.id` und umfasst die halbe Themenliste, höchstens aber 20 — ein Thema mit zehn Versen kann keine zwanzig sperren.

### 4.3 Nachschlagen — Bücher
- Liste, in Abschnitte `Altes Testament` / `Neues Testament` geteilt.
- Rechts das Register mit sieben Sprungmarken (1. Mose · Josua · Psalmen · Jesaja · Matthäus · Römer · Offenbarung), beschriftet mit dem Buchkürzel der Anzeigesprache aus der Datenbank. Aktive Marke in Karmin.
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

## 5. Mehrsprachigkeit

**Die App erscheint in jeder Sprache, für die sie eine Bibelübersetzung mitbringt** — zurzeit sechs: Deutsch, Englisch, Spanisch, Französisch, Chinesisch traditionell und Chinesisch vereinfacht. Die Anzeigesprache folgt dem System; eine eigene Spracheinstellung gibt es nicht. Die Liste steht in `Localization.supportedLanguages` und ist in derselben Schreibweise geführt wie `translation.language`, damit Anzeige- und Übersetzungssprache ohne Umrechnung vergleichbar sind. Ein Unit-Test hält beide Mengen deckungsgleich: kommt eine siebte Übersetzungssprache in die Datenbank, ohne dass die Oberfläche nachzieht, schlägt er fehl.

**Chinesisch nie auf zwei Zeichen kürzen.** `zh-Hant` und `zh-Hans` unterscheiden sich in der Schrift, nicht in der Sprache; ein `String(code.prefix(2))` trifft weder die eine noch die andere Übersetzung. `Localization.normalized` bildet Systemkennungen ab: `de-CH` → `de`, `zh-TW` → `zh-Hant`, `zh` → `zh-Hans`.

**Texte** liegen in `Resources/Localizable.xcstrings` (String Catalog, 58 Schlüssel, alle sechs Sprachen vollständig), der App-Name in `Resources/InfoPlist.xcstrings` — «Bibel», «Bible», «Biblia», «Bible», 聖經, 圣经, kurz gehalten, weil unter dem Symbol auf der Uhr wenig Platz ist. Schlüssel sind semantisch benannt (`settings.textSize`), nicht der englische Text selbst.

**Vorgabe der Bibelübersetzung nach Anzeigesprache:** die **erste Übersetzung dieser Sprache in der Reihenfolge der Datenbank** (`sort_order`) — also genau die, die in der Auswahl auch zuoberst steht: Deutsch Elberfelder 1905, Englisch King James, Chinesisch das 和合本 der jeweiligen Schrift, Spanisch Reina-Valera, Französisch Louis Segond. Nichts davon ist fest verdrahtet; die Reihenfolge selbst steht in `TRANSLATION_ORDER` im Konverter, und fällt eine Übersetzung weg, rückt die nächste derselben Sprache nach. Das gilt **nur beim ersten Start**: wer einmal eine Übersetzung gewählt hat, behält sie, auch nach einem Sprachwechsel des Systems. Gibt es zur Anzeigesprache keine Übersetzung, greift bei Chinesisch die andere Schriftvariante, sonst Englisch, zuletzt die erste überhaupt. Umgesetzt in `Shared/Localization.swift`.

**Die Übersetzungsauswahl beginnt bei der eigenen Sprache.** Der Abschnitt der Anzeigesprache steht zuoberst, die übrigen folgen in Datenbankreihenfolge (`Localization.languageOrder`).

**Buchnamen** kommen aus der Datenbank, nicht aus dem String Catalog: `book.name` für Deutsch, dazu `name_en`, `name_es`, `name_fr`, `name_zh_hant`, `name_zh_hans`. Alle sechs Spalten sind für alle 66 Bücher gefüllt. Wo die Schreibweise schwankt, gilt die der mitgelieferten Übersetzung derselben Sprache — spanisch «Ruth», «Esther», «Haggeo» nach RVR1909, französisch «Habakuk», «Ésaïe» nach LSG; sonst stünde in der Buchliste etwas anderes als im Verstext.

**Buchkürzel** stehen ebenfalls in der Datenbank: `abbrev_de`, `abbrev_en`, `abbrev_es`, `abbrev_fr`, `abbrev_zh_hant`, `abbrev_zh_hans`. Genommen ist je Sprache der dort übliche Satz, nicht eine selbstgebaute Kürzung — Elberfelder für Deutsch (1Mo, nicht das Loccumer «Gen»; die deutschen Buchnamen der Datenbank stehen in derselben Tradition), SBL Handbook of Style für Englisch, Reina-Valera für Spanisch, Segond für Französisch, der Kürzelsatz des 和合本 für Chinesisch. Sie sind je Sprache eindeutig; ein Unit-Test prüft das.

**Themennamen** stehen als einzige Beschriftung des Registers **nicht** in der Datenbank, sondern im String Catalog unter «topic.<deutscher Wert>» — der deutsche Wert aus `curated.topic` ist zugleich der Schlüssel. Der Unterschied zu den Buchnamen ist kein Zufall: ein Buchname folgt der Rechtschreibung der Übersetzung, in der der Vers steht («Ruth» nach Reina-Valera), er hängt also am Text. Ein Themenname hängt an nichts. Die Datenbank sagt, **welche** Themen es gibt, der Katalog, **wie sie geschrieben werden**. Genommen ist je Sprache das in Bibelausgaben übliche Wort, nicht die wörtliche Übersetzung: «Nachfolge» heisst englisch Discipleship, «Umkehr» spanisch Arrepentimiento. Ein Unit-Test hält beide Seiten deckungsgleich — jedes Thema der Datenbank braucht in allen sechs Sprachen einen Eintrag, sonst stünde auf einer französischen Uhr still «Wort Gottes».

**Das Register der Buchliste ist damit lokalisiert.** Es zeigt das Kürzel der Anzeigesprache aus der Datenbank, nicht `book.code` — der ist Schlüssel und deutsch geprägt. Die sieben Sprungmarken lauten 1Mo · Jos · Ps · Jes · Mt · Röm · Offb auf Deutsch, Gen · Josh · Ps · Isa · Matt · Rom · Rev auf Englisch, Gn · Jos · Sal · Is · Mt · Ro · Ap auf Spanisch, Gn · Jos · Ps · És · Mt · Rm · Ap auf Französisch und 創 · 書 · 詩 · 賽 · 太 · 羅 · 啟 beziehungsweise 创 · 书 · 诗 · 赛 · 太 · 罗 · 启 auf Chinesisch. Vier Zeichen sind die Obergrenze — mehr passt nicht in die 31 pt Registerbreite.

**Die Stellenangabe ist selbst lokalisiert.** Deutsche Bibeln schreiben «Johannes 3,16», alle übrigen Sprachen der App «John 3:16» — Komma gegen Doppelpunkt. Der Trenner steht deshalb im String Catalog (`reference.format`) und darf nirgends fest verdrahtet werden. Die Zahlen der Zählerzeile folgen dagegen der **Region**, nicht der Sprache: 18’463 in der Schweiz, 18,463 in den USA, über `formatted(.number)`.

**Pluralformen** für «%lld Kapitel» und «%lld Verse» sind als Varianten hinterlegt: Englisch, Spanisch und Französisch unterscheiden Einzahl und Mehrzahl, Deutsch bei «Kapitel» nicht, Chinesisch kennt nur eine Form.

Was nicht übersetzt wird: die Namen der Bibelübersetzungen selbst («Elberfelder 1905», «King James Version») sind Eigennamen und kommen unverändert aus `translation.name`.

## 5a. Chinesische Schrift

Die Datenbank enthält das 和合本 in traditionellen und vereinfachten Zeichen. Für die Darstellung heisst das:

- **Schriftgrösse anheben.** Chinesische Schriftzeichen brauchen bei gleicher Lesbarkeit mehr Fläche als lateinische. Ausgangswert: Verstext 18 pt statt 16 pt, wenn `translation.language` mit `zh` beginnt.
- **Zeilenabstand erhöhen** auf etwa 1.6 statt 1.42 — CJK-Schriften füllen die Zeile dichter.
- **Keine serife Variante erzwingen.** Das System setzt PingFang SC bzw. TC; ein Serif-Design-Parameter greift dort nicht wie bei lateinischer Schrift.
- **U+3000 nie wegkürzen.** Der ideographische Abstand vor 神 ist Teil des Textes, keine überflüssige Formatierung.
- Die Textmenge ist unkritisch: längster chinesischer Vers 108 Zeichen gegenüber 503 im Deutschen.

Die Bedienoberfläche gibt es seit August 2026 auch auf Chinesisch (siehe Kapitel 5). Buchnamen und Stellenangaben folgen weiterhin der **Anzeigesprache**, nicht der gewählten Übersetzung: über einem chinesischen Vers steht «Johannes 3,16», wenn die Uhr auf Deutsch läuft, und 約翰福音 3:16, wenn sie auf Chinesisch läuft. Das ist bei mehrsprachigen Bibelprogrammen üblich und bewusst so.

## 6. Was bewusst fehlt

- **Goldschnitt am Bildschirmrand.** War in Entwurf A die Fortschrittsanzeige, das macht jetzt das Bändchen. Zwei Positionsanzeigen auf 45 mm sind eine zu viel.
- **Register für Kapitel und Verse.** Rechnerisch unmöglich neben einem Raster.
- **Eine dritte Akzentfarbe.** Karmin und Messing tragen je genau eine Bedeutung.
- **Animationen ausser dem Seitenwechsel.** Auf einer Uhr kostet jede Bewegung Zeit, die der Nutzer nicht hat.
