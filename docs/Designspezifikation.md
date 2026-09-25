# Designspezifikation — Watch Bible «Dünndruck»

Ein Entwurf, zwei Zustände: Papier bei Tag, Schwarz bei Nacht. Gleiche Struktur, gleiche Typografie, nur die Farbwerte tauschen. Auswahl über Register (Bücher) und Raster (Kapitel, Verse).

Diese Datei beschreibt die umgesetzte Gestaltung und bleibt für Änderungen daran verbindlich: Farbwerte, Schriftgrössen, Abstände und Rastergeometrie stehen hier, nicht als Konstanten im Code. Wie es aussieht, zeigen die Aufnahmen in `AppStore/Screenshots-de/`; der frühere HTML-Entwurf `Design_TagNacht.html` ist damit erledigt und entfernt.

---

## 1. Farben

Als Asset-Katalog anlegen, nicht als Konstanten im Code. Jede Rolle bekommt zwei Colorsets (`…Day` / `…Night`): watchOS wertet die Any/Dark-Variante eines Assets nicht aus, `Color("Ground")` bliebe im Tagmodus schwarz. Umgeschaltet wird zentral in `ThemeState`. `\.colorScheme` wird zusätzlich gesetzt — nicht für diese Farben, sondern für alles, was das System selbst zeichnet (Picker-Wert, Warnhinweise, `.secondary`).

| Rolle | Asset-Name | Tag | Nacht |
|---|---|---|---|
| Grund | `Ground` | `#E4E2DA` | `#000000` |
| Text | `Ink` | `#14161A` | `#E8E6E1` |
| Verszahl, aktive Auswahl | `Carmine` | `#8C1D2B` | `#C4525C` |
| Bändchen (Position) | `Brass` | `#A8842E` | `#C8A44D` |
| Bändchen (Spur darunter) | `RibbonTrack` | `#CFCBBD` | `#26241E` |
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

Die Werte stehen in `Shared/Theme.swift` als `enum Typo`; Verstext und Verszahl leiten sich aus der eingestellten Grundgrösse ab (Verszahl 0.6 ×, Grundlinie +0.44 em, Zeilenabstand 0.42 ×). Wer eine Grösse ändert, prüft die **Zeilenumbrüche im Simulator** nach — auf der 41-mm-Uhr zuerst. Dynamische Schriftgrössen des Systems greifen weiterhin; die drei Stufen der Einstellung skalieren zusätzlich.

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

**Drei Spalten, 6 pt Abstand, Zellhöhe 52 pt.** Nachgerechnet: (198 − 2 × 14 − 2 × 6) ÷ 3 = **52.7 pt** pro Zelle. Vier Spalten ergäben 38 pt, fünf Spalten 29 pt — beides unterschreitet die übliche Mindestgrösse von 44 pt für Tippziele.

**Register und Raster schliessen sich aus.** Mit Register bleiben pro Zelle nur 42 pt. Das Register ist deshalb der Buchwahl vorbehalten, wo es 66 Einträge erschliesst; Kapitel und Verse bekommen das volle Raster.

### Wer die 14 pt trägt

Der Seitenrand gilt für **Text ohne eigene Fläche** — Listenzeilen und Impressum; er steht als `Layout.textInset` in `Shared/Theme.swift`. Der Einstieg kommt auf denselben Wert, nur anders zusammengesetzt: dort liegt der Text auf einer Feldfläche, die bei 2 pt beginnt und innen 12 pt Luft lässt.

**Rasterzellen tragen ihre Fläche selbst und bleiben bei 2 pt.** 14 pt ergäben auf der 40-mm-Uhr (162 pt breit) Zellen von 40.7 pt und unterschritten die 44 pt für Tippziele — die Rechnung oben geht von der 45-mm-Uhr aus.

In der Buchliste kostet der Rand Breite, die dort schon das Register beansprucht: «Apostelgeschichte» ist der längste Buchname und passt auf der 40-mm-Uhr erst ab `minimumScaleFactor(0.65)`, während 0.7 in den übrigen Listen reicht.

---

## 4. Bildschirme

### 4.1 Einstieg
`NavigationStack` mit drei Zeilen — **Zufallsvers**, **Themen**, **Nachschlagen** — darunter **Einstellungen**. Gab es eine zuletzt gelesene Stelle, erscheint sie als weitere Zeile: «Weiterlesen · Psalm 23,3». Kein Startbildschirm, kein Onboarding.

### 4.2 Zufallsvers
- Stellenangabe oben in Versalien, Karmin.
- Verstext als Fliesstext, hochgestellte Verszahl vorangestellt.
- Bändchen links zeigt die Position des Verses im Kapitel.
- Zählerzeile unten: `3 / 463` links, Übersetzungskürzel rechts. Gezählt wird **das Blättern in dieser Gruppe**, nicht die Lage des Verses in der Übersetzung: links die wievielte Seite dieses Durchgangs, rechts, wie viele Verse der Topf hat, aus dem gezogen wird — das Thema, das Versregister (463) oder die ganze Übersetzung (31'103). Die Zählung beginnt bei jedem Öffnen wieder bei 1; eine Ziehung hat keine Reihenfolge, in die sich ein Vers dauerhaft einordnen liesse. Wer länger blättert, als die Gruppe Verse hat, beginnt wieder bei 1, statt über die Gesamtzahl hinauszuzählen — erreichbar nur in den kleinen Themen.
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
- Je Zeile: Buchname links, Kapitelzahl rechts in Monoschrift. Die Zahl zählt die Kapitel der **aktiven Übersetzung** (`BibleRepository.chapterCounts`, eine Abfrage über alle 66 Bücher), nicht `book.chapter_count` — sonst verspräche die Liste in der Schlachter ein Maleachi 4, das das Raster einen Tipp später nicht anbietet, und verschwiege dort Joel 4. Es ist dieselbe Regel wie beim Weiterblättern (4.5).

### 4.4 Nachschlagen — Kapitel und Verse
- Dreispaltiges Raster, Zellen mit `Field` hinterlegt, 14 pt gerundet.
- Aktueller Eintrag in Karmin, Ziffer in Grundfarbe.
- **Nicht vorhandene Verse bleiben sichtbar, aber auf 32 % Deckkraft gesetzt** statt ausgeblendet. Damit wird die Grenze des Kapitels begreifbar, statt nur zu fehlen.
  - Das gilt auch für Lücken mitten im Kapitel: in der BSB fehlen 18 Verse (Mt 17,21, Klgl 2,1 …). Das Raster reicht deshalb bis zur **höchsten vorhandenen Versnummer**, nicht bis zur Anzahl Verse — sonst wäre die fehlende Nummer antippbar und der letzte Vers nicht. Die Zählerzeile nennt die vorhandenen Verse: BSB Mt 17 zeigt 27 Zellen und «26 Verse».
- Zählerzeile unten: `6 Verse`, Übersetzungskürzel.

### 4.5 Leseansicht
- Das ganze Kapitel als **Fliesstext**, nicht Zeile pro Vers. Hochgestellte Verszahlen wie im Druck.
- Der gewählte Vers in voller Deckkraft, die übrigen auf 70 % — kein Farbwechsel, kein Rahmen. **Nur beim Ankommen**: sobald der Leser scrollt (mehr als 12 pt, also etwa eine Zeile), gehen alle Verse auf volle Deckkraft und bleiben so. Die Hervorhebung beantwortet die Frage «wo bin ich gelandet» und tritt dann beiseite; sonst läse man den ganzen weiteren Text in blasser Schrift.
  - Mitlaufen kann die Hervorhebung nicht: das Kapitel ist **ein** zusammengesetzter `Text`, es gibt keine Geometrie je Vers. Wollte man wissen, welcher Vers gerade auf dem Bildschirm steht, müsste je Vers eine eigene Ansicht her — und damit wäre der Fliesstext dahin.
  - Ob gescrollt wurde, wird gegen eine **beobachtete** Ruhelage geprüft, nicht gegen den berechneten Zielwert des automatischen Hinscrollens: `scrollTo(y:)` und `onScrollGeometryChange` messen nicht dasselbe (Letzteres rechnet `contentInsets.top` hinzu).
  - Beim Weiterblättern gibt es keinen gewählten Vers und damit nie eine Abblendung.
- Krone scrollt, das Bändchen bewegt sich mit.
- Werkzeugleiste: Übersetzung wechseln.
- **Weiterblättern** am Ende des Kapitels: zwei Knöpfe nebeneinander, je 44 pt hoch, beschriftet mit dem Ziel — Buchkürzel der Anzeigesprache und Kapitelzahl, «‹ Mt 4» und «Mt 6 ›». Karmin auf Feldfläche wie die Rasterzellen. Am Kanonrand bleibt die betreffende Hälfte leer, statt dass der verbleibende Knopf über die volle Breite springt.
  - Kein Wischen quer: das ist auf watchOS die Rücknavigation. Keine Krone über das Kapitelende hinaus: die Krone scrollt bereits, und ein Weiterblättern aus Versehen wäre schlimmer als ein Knopf mehr.
  - Der Wechsel **tauscht die Stelle in derselben Ansicht aus**, statt eine weitere auf den `NavigationStack` zu legen — sonst wüchse der Stapel mit jedem gelesenen Kapitel. Neues Kapitel heisst: oben beginnen, kein hervorgehobener Vers, Abweichungstabelle des alten Kapitels verworfen, Haptik wie beim Zufallsvers. Das alte Kapitel bleibt stehen, bis das neue samt Nachbarkapiteln geladen ist; dann wechseln Titel, Text und Knöpfe in einem Zug. Wird der Text vorher geleert, steht kurz ein leeres Kapitel unter den Knöpfen des alten.
  - **Die Kapitelgrenzen kommen aus `chapter_meta` der aktiven Übersetzung, nie aus `book.chapter_count`.** Dort steht das Maximum über alle Übersetzungen: Joel führt vier Kapitel, hat aber in zehn von zwölf nur drei, Maleachi umgekehrt. Nach `chapter_count` geblättert landet man auf einer leeren Seite. Umgesetzt in `BibleRepository.adjacentChapter`, festgehalten von `WeiterblaetternTests`.

### 4.6 Abweichungsfall
Löst `BibleRepository.resolve` etwas anderes als `.exact` auf, erscheint unter dem Verstext eine zweizeilige Tabelle mit beiden Verszahlen des Kapitels, darunter eine Zeile mit Karminstrich links:

```
Elberfelder            26 Verse
King James             19 Verse
│ Vers 26 angefragt, Kapitelende gezeigt.
```

Keine Signalfarbe, kein Symbol, nichts zum Wegklicken. Zwei Zahlen erklären den Sachverhalt vollständig; eine Warnung würde ihn dramatisieren, ohne mehr zu sagen.

Dasselbe gilt für den Deep Link des Widgets: das Widget zeigt den Vers in der Vorgabeübersetzung der Systemsprache, die App öffnet ihn in der gewählten. Der Link trägt den Code der Widget-Übersetzung, die Leseansicht löst die Stelle beim ersten Laden von dort in die aktive Übersetzung auf und zeigt die Tabelle wie nach einem Wechsel (Architektur, Kapitel 8).

| Fall | Anzeige |
|---|---|
| `.exact` | nichts |
| `.divergent` | Tabelle mit beiden Verszahlen |
| `.clamped` | Tabelle plus Zeile «Vers *n* angefragt, Kapitelende gezeigt.» |
| `.unavailable` | «Dieses Kapitel gibt es in der *X* nicht.» — der Wechsel wird abgebrochen, die bisherige Übersetzung bleibt stehen. Beim Deep Link des Widgets ausgeschlossen: jedes kuratierte Kapitel gibt es in allen Übersetzungen (`DeepLinkTests`) |

### 4.7 Einstellungen
Übersetzung · Zufallsmodus · Darstellung (Tag / Nacht / Automatisch, bei Automatisch zwei Uhrzeiten) · Schriftgrösse · Haptik · Impressum. **Welche** Übersetzungen im Impressum stehen, sagt die Datenbank; **wie** ihre Rechteangabe geschrieben wird, der String Catalog unter `copyright.<code>` — dieselbe Arbeitsteilung wie bei den Themen (Kapitel 5). Rechteinhaber, Werktitel und der Lizenzname «Creative Commons Attribution 4.0 (CC BY 4.0)» bleiben in jeder Sprache wörtlich stehen; übersetzt wird nur der Satz drumherum. Fehlt ein Katalogeintrag, bleibt die deutsche Zeile aus `translation.copyright` stehen — eine Rechteangabe darf nie ganz fehlen.

---

## 5. Mehrsprachigkeit

**Die App erscheint in jeder Sprache, für die sie eine Bibelübersetzung mitbringt** — zurzeit acht: Deutsch, Englisch, Spanisch, Französisch, Italienisch, Portugiesisch, Chinesisch traditionell und Chinesisch vereinfacht. Die Anzeigesprache folgt dem System; eine eigene Spracheinstellung gibt es nicht. Die Liste steht in `Localization.supportedLanguages` und ist in derselben Schreibweise geführt wie `translation.language`, damit Anzeige- und Übersetzungssprache ohne Umrechnung vergleichbar sind. Ein Unit-Test hält beide Mengen deckungsgleich: kommt eine neunte Übersetzungssprache in die Datenbank, ohne dass die Oberfläche nachzieht, schlägt er fehl.

**Chinesisch nie auf zwei Zeichen kürzen.** `zh-Hant` und `zh-Hans` unterscheiden sich in der Schrift, nicht in der Sprache; ein `String(code.prefix(2))` trifft weder die eine noch die andere Übersetzung. `Localization.normalized` bildet Systemkennungen ab: `de-CH` → `de`, `zh-TW` → `zh-Hant`, `zh` → `zh-Hans`.

**Texte** liegen in `Resources/Localizable.xcstrings` (String Catalog, 93 Schlüssel, alle acht Sprachen vollständig), der App-Name in `Resources/InfoPlist.xcstrings` — «Bibel», «Bible», «Biblia», «Bible», «Bibbia», «Bíblia», 聖經, 圣经, kurz gehalten, weil unter dem Symbol auf der Uhr wenig Platz ist. Schlüssel sind semantisch benannt (`settings.textSize`), nicht der englische Text selbst.

**Vorgabe der Bibelübersetzung nach Anzeigesprache:** die **erste Übersetzung dieser Sprache in der Reihenfolge der Datenbank** (`sort_order`) — also genau die, die in der Auswahl auch zuoberst steht: Deutsch Elberfelder 1905, Englisch King James, Chinesisch das 和合本 der jeweiligen Schrift, Spanisch Reina-Valera, Französisch Louis Segond. Nichts davon ist fest verdrahtet; die Reihenfolge selbst steht in `TRANSLATION_ORDER` in `tools/tables.py`, und fällt eine Übersetzung weg, rückt die nächste derselben Sprache nach. Die Vorgabe gilt bei **jedem** Start, solange der Nutzer nicht selbst gewählt hat: stellt jemand die Uhr von Portugiesisch auf Deutsch, wechselt die Bibel mit. Wer dagegen **einmal eine Übersetzung gewählt** hat, behält sie, auch nach einem Sprachwechsel des Systems — auf einer deutschen Uhr bleibt die King James die King James. Gibt es zur Anzeigesprache keine Übersetzung, greift bei Chinesisch die andere Schriftvariante, sonst Englisch, zuletzt die erste überhaupt. Umgesetzt in `Shared/Localization.swift`.

**Die Übersetzungsauswahl beginnt bei der eigenen Sprache.** Der Abschnitt der Anzeigesprache steht zuoberst, die übrigen folgen in Datenbankreihenfolge (`Localization.languageOrder`).

**Buchnamen** kommen aus der Datenbank, nicht aus dem String Catalog: `book.name` für Deutsch, dazu `name_en`, `name_es`, `name_fr`, `name_it`, `name_pt`, `name_zh_hant`, `name_zh_hans`. Alle acht Spalten sind für alle 66 Bücher gefüllt. Wo die Schreibweise schwankt, gilt die der mitgelieferten Übersetzung derselben Sprache — spanisch «Ruth», «Esther», «Haggeo» nach RVR1909, französisch «Habakuk», «Ésaïe» nach LSG; sonst stünde in der Buchliste etwas anderes als im Verstext.

**Buchkürzel** stehen ebenfalls in der Datenbank: `abbrev_de`, `abbrev_en`, `abbrev_es`, `abbrev_fr`, `abbrev_it`, `abbrev_pt`, `abbrev_zh_hant`, `abbrev_zh_hans`. Genommen ist je Sprache der dort übliche Satz, nicht eine selbstgebaute Kürzung — Elberfelder für Deutsch (1Mo, nicht das Loccumer «Gen»; die deutschen Buchnamen der Datenbank stehen in derselben Tradition), SBL Handbook of Style für Englisch, Reina-Valera für Spanisch, Segond für Französisch, CEI / Nuova Riveduta für Italienisch, die Bíblia Livre für Portugiesisch, der Kürzelsatz des 和合本 für Chinesisch. Sie sind je Sprache eindeutig; ein Unit-Test prüft das.

**Themennamen** stehen als einzige Beschriftung des Registers **nicht** in der Datenbank, sondern im String Catalog unter «topic.<deutscher Wert>» — der deutsche Wert aus `curated.topic` ist zugleich der Schlüssel. Der Unterschied zu den Buchnamen ist kein Zufall: ein Buchname folgt der Rechtschreibung der Übersetzung, in der der Vers steht («Ruth» nach Reina-Valera), er hängt also am Text. Ein Themenname hängt an nichts. Die Datenbank sagt, **welche** Themen es gibt, der Katalog, **wie sie geschrieben werden**. Genommen ist je Sprache das in Bibelausgaben übliche Wort, nicht die wörtliche Übersetzung: «Nachfolge» heisst englisch Discipleship, «Umkehr» spanisch Arrepentimiento. Ein Unit-Test hält beide Seiten deckungsgleich — jedes Thema der Datenbank braucht in allen acht Sprachen einen Eintrag, sonst stünde auf einer französischen Uhr still «Wort Gottes».

**Das Register der Buchliste ist damit lokalisiert.** Es zeigt das Kürzel der Anzeigesprache aus der Datenbank, nicht `book.code` — der ist Schlüssel und deutsch geprägt. Die sieben Sprungmarken lauten 1Mo · Jos · Ps · Jes · Mt · Röm · Offb auf Deutsch, Gen · Josh · Ps · Isa · Matt · Rom · Rev auf Englisch, Gn · Jos · Sal · Is · Mt · Ro · Ap auf Spanisch, Gn · Jos · Ps · És · Mt · Rm · Ap auf Französisch, Gen · Gs · Sal · Is · Mt · Rm · Ap auf Italienisch, Gn · Js · Sl · Is · Mt · Rm · Ap auf Portugiesisch und 創 · 書 · 詩 · 賽 · 太 · 羅 · 啟 beziehungsweise 创 · 书 · 诗 · 赛 · 太 · 罗 · 启 auf Chinesisch. Vier Zeichen sind die Obergrenze — mehr passt nicht in die 31 pt Registerbreite.

**Die Stellenangabe ist selbst lokalisiert.** Deutsche Bibeln schreiben «Johannes 3,16», alle übrigen Sprachen der App «John 3:16» — Komma gegen Doppelpunkt. Der Trenner steht deshalb im String Catalog (`reference.format`) und darf nirgends fest verdrahtet werden. Die Zahlen der Zählerzeile folgen dagegen der **Region**, nicht der Sprache: 31’103 in der Schweiz, 31,103 in den USA, über `formatted(.number)`.

**Pluralformen** für «%lld Kapitel» und «%lld Verse» sind als Varianten hinterlegt: Englisch, Spanisch, Französisch, Italienisch und Portugiesisch unterscheiden Einzahl und Mehrzahl, Deutsch bei «Kapitel» nicht, Chinesisch kennt nur eine Form.

Was nicht übersetzt wird: die Namen der Bibelübersetzungen selbst («Elberfelder 1905», «King James Version») sind Eigennamen und kommen unverändert aus `translation.name`.

## 5a. Chinesische Schrift

Die Datenbank enthält das 和合本 in traditionellen und vereinfachten Zeichen. Für die Darstellung heisst das:

- **Schriftgrösse anheben.** Chinesische Schriftzeichen brauchen bei gleicher Lesbarkeit mehr Fläche als lateinische. Ausgangswert: Verstext 18 pt statt 16 pt, wenn `translation.language` mit `zh` beginnt.
- **Zeilenabstand erhöhen** auf etwa 1.6 statt 1.42 — CJK-Schriften füllen die Zeile dichter.
- **Keine serife Variante erzwingen.** Das System setzt PingFang SC bzw. TC; ein Serif-Design-Parameter greift dort nicht wie bei lateinischer Schrift.
- **U+3000 nie wegkürzen.** Der ideographische Abstand vor 神 ist Teil des Textes, keine überflüssige Formatierung.
- Die Textmenge ist unkritisch: längster chinesischer Vers 109 Zeichen gegenüber 474 im Deutschen.

Die Bedienoberfläche gibt es seit August 2026 auch auf Chinesisch (siehe Kapitel 5). Buchnamen und Stellenangaben folgen weiterhin der **Anzeigesprache**, nicht der gewählten Übersetzung: über einem chinesischen Vers steht «Johannes 3,16», wenn die Uhr auf Deutsch läuft, und 約翰福音 3:16, wenn sie auf Chinesisch läuft. Das ist bei mehrsprachigen Bibelprogrammen üblich und bewusst so.

## 6. Was bewusst fehlt

- **Goldschnitt am Bildschirmrand.** War in Entwurf A die Fortschrittsanzeige, das macht jetzt das Bändchen. Zwei Positionsanzeigen auf 45 mm sind eine zu viel.
- **Register für Kapitel und Verse.** Rechnerisch unmöglich neben einem Raster.
- **Eine dritte Akzentfarbe.** Karmin und Messing tragen je genau eine Bedeutung.
- **Animationen ausser dem Seitenwechsel.** Auf einer Uhr kostet jede Bewegung Zeit, die der Nutzer nicht hat.
