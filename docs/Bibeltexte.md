# Die Bibeltexte — Herkunft, Prüfung, Lizenz

Zehn Übersetzungen in sechs Sprachen, alle gemeinfrei oder frei lizenziert. Dieses Dokument hält für jede fest, aus welcher Quelldatei sie stammt, woran geprüft wurde, dass es wirklich die angenommene Ausgabe ist, und welche Eingriffe am Quelltext dokumentiert sind.

Der wiederkehrende Punkt: bei fast jeder dieser Übersetzungen gibt es eine jüngere, **geschützte** Revision mit fast demselben Namen — Luther 1984 statt 1912, Segond 21 statt 1910, RVR1960 statt 1909, 新標點和合本 statt 和合本, Schlachter 2000 statt 1951. Eine Verwechslung fällt im Text nicht auf, wohl aber vor Gericht. Darum steht hier bei jeder Übersetzung, woran die richtige zu erkennen ist.

| Kürzel | Übersetzung | Sprache | Verse | Quelle |
|---|---|---|---:|---|
| ELB | Elberfelder 1905 | Deutsch | 31'103 | quotepas-Quelldatei `bible.db` |
| SCH | Schlachter 1951 | Deutsch | 31'172 | `de/sch1951.xml`, gratis-bible |
| LUT | Luther 1912 | Deutsch | 31'171 | `de/luth1912.xml`, gratis-bible |
| KJV | King James Version | Englisch | 31'102 | quotepas-Quelldatei `bible.db` |
| DAR | Darby Bible | Englisch | 30'996 | quotepas-Quelldatei `bible.db` |
| BSB | Berean Standard Bible | Englisch | 31'084 | `usfm-bible/examples.bsb` |
| RVR | Reina-Valera 1909 | Spanisch | 31'102 | `es/sparv.xml`, gratis-bible |
| LSG | Louis Segond 1910 | Französisch | 31'102 | `fr/fren.xml`, gratis-bible |
| CUV | 和合本（繁體） | Chinesisch trad. | 31'101 | `chi.xml`, gratis-bible |
| CUVS | 和合本（简体） | Chinesisch vereinf. | 31'101 | aus CUV erzeugt, siehe unten |

`gratis-bible` steht für `github.com/gratis-bible/bible`.

---

## Schlachter 1951

Gegenprobe gegen die Schlachter 2000 in derselben Quelle: von 400 zufälligen Versen weichen 358 ab. Es ist also nachweislich die Fassung von 1951 und nicht versehentlich die geschützte Revision. 66 Bücher, 1'189 Kapitel, 31'172 Verse, keine XML-Reste, keine leeren Verse.

**Lizenz.** Die Genfer Bibelgesellschaft hat den Text unter CC BY 4.0 gestellt. Namensnennung ist damit Pflicht; die Zeile steht in `translation.copyright` und erscheint dadurch im Impressum der App.

**Zwei offene Punkte, ehrlich benannt:**

- Die verwendete Datei `sch1951.xml` stammt aus dem Jahr 2009 und trägt im Kopf noch einen älteren, engeren Lizenzvermerk («Nutzung nur erlaubt mit MyBible»). Die CC-BY-Fassung liegt bei **ebible.org/deu1951**. Für einen sauberen Nachweis wäre die USFM-Ausgabe von dort zu holen, nach OSIS zu wandeln und die Datenbank neu zu erzeugen — derselbe Befehl, dieselbe Ausgabe. Der Text ist inhaltlich geprüft; es geht allein um den Lizenzweg.
- **Der `--swiss`-Schalter ist eine Bearbeitung.** Er wandelt ß zu ss, auch in der Schlachter 1951. CC BY 4.0 verlangt, Änderungen kenntlich zu machen — also entweder im Impressum vermerken oder für diese eine Übersetzung darauf verzichten.

**Schlachter 2000** bleibt urheberrechtlich geschützt (© 2000 Genfer Bibelgesellschaft) und ist deshalb nicht dabei. Der Konverter kennt dafür `--exclude slt`; der App-Code bleibt unverändert.

---

## Luther 1912

Aus `de/luth1912.xml`, dessen OSIS-Kopf «Public Domain» führt. Es ist die Revision von **1912**, deren Schutzfrist abgelaufen ist — nicht die Lutherbibel 1984 oder 2017, die bei der Deutschen Bibelgesellschaft geschützt sind. 66 Bücher, 1'189 Kapitel, 31'171 Verse, keine XML-Reste, keine leeren Verse.

**Gegenprobe an einer zweiten Quelle.** Dieselbe Revision liegt bei **ebible.org/deu1912** als USFM. Von 31'171 Verstexten stimmen 29'871 zeichengleich mit der OSIS-Ausgabe überein; es ist also nachweislich derselbe Revisionsstand. Die Restunterschiede sind auf beiden Seiten kleine Zeichensetzungsschäden («um um das ganze Mohrenland» bei ebible, ein hängendes Fragezeichen in 1Mo 5,1 bei gratis-bible) — sowie ein systematischer Unterschied, der die Wahl entschieden hat.

**Verwendet wird die OSIS-Ausgabe, weil sie deutsch zählt.** Die ebible-Fassung ist auf die englische Versifikation umgestellt und trägt die Originalnummer als Präfix im Verstext (`[5:27] Die Kinder Levis waren…` unter 1Chr 6,1). Das wäre hier die falsche Grundlage: die deutsche Zählung ist genau das, was `BibleRepository.resolve` gegen die englischen Übersetzungen abgleicht. Luther zählt Joel mit vier und Maleachi mit drei Kapiteln, Elberfelder umgekehrt — Joel 4 gibt es in der ELB nicht, Maleachi 4 nicht in der Luther. Solche Kapitel müssen `.unavailable` melden. Gegen Schlachter 1951 unterscheiden sich nur drei Kapitel in der Verszahl, gegen Elberfelder 124, gegen die KJV 142; alle Fälle stehen in `test_fixtures.json`.

**Drei dokumentierte Eingriffe am Quelltext**, jeder im Konverter aufgeführt und bei jedem Lauf gemeldet:

- `SOURCE_FIXES`: In 1Mo 5,1 hängt ein Fragezeichen hinter dem Semikolon, mit dem der Vers endet. Gedruckt und in der ebible-Ausgabe steht dort nur das Semikolon.
- `TYPOGRAPHY_FIXUPS`: 24 Verse tragen ein Leerzeichen vor dem Satzzeichen, wo im Druck eine Fussnotenmarke stand («heisst Hiddekel , das fliesst vor Assyrien»).
- `TYPOGRAPHY_FIXUPS`: Das Modul setzt ASCII-Anführungszeichen. In 586 Versen sind sie auf « » gesetzt, weil quotepas-Quelle und Schlachter 1951 Guillemets verwenden und die deutschen Übersetzungen sonst zwei Systeme mischten. Ein `"` öffnet am Textanfang und nach Leerzeichen oder öffnender Klammer, sonst schliesst es; nicht über Paare gezählt, weil 177 Zitate über Versgrenzen laufen und in sechs Kapiteln das öffnende Zeichen in der Quelle fehlt.

Diese Eingriffe sind an den Übersetzungscode gebunden und nicht allgemein: im Französischen gehört das Leerzeichen vor `;:!?` zur Rechtschreibung, und die übrigen Quellen bringen ihre Anführungszeichen typografisch mit. Da die Revision gemeinfrei ist, verlangt keine Lizenz einen Änderungsvermerk — anders als bei der Schlachter 1951.

---

## Berean Standard Bible

Aus `github.com/usfm-bible/examples.bsb` — einer USFM-Aufbereitung des offiziellen Textes vom 26. August 2024, deren `metadata.json` `"publicDomain": true` führt. Die Rechteinhaber haben den Text am 30. April 2023 in die Public Domain entlassen; eine Lizenzierung ist für keine Verwendung nötig. Fussnoten und Querverweise sind entfernt, `\nd`-Auszeichnungen für den Gottesnamen in Grossbuchstaben gesetzt.

Zwei Auffälligkeiten in dieser Ausgabe: die Datei zu Prediger hat keinen `\id`-Marker, der Konverter bestimmt das Buch dort aus dem Dateinamen und meldet das. Und der Text verwendet U+02BC als Apostroph, was der Konverter auf das übliche U+2019 vereinheitlicht.

**Bekannter Datenfund:** In der BSB fehlt Klagelieder 2,1 — das Kapitel beginnt bei Vers 2. Das ist der einzige solche Fall in der ganzen Datenbank. Die App zeigt die Lücke sauber an (die Zelle im Versraster bleibt blass); zu klären bleibt, ob die Quelle den Vers wirklich nicht führt.

---

## Reina-Valera 1909 und Louis Segond 1910

Beide aus `gratis-bible`: `es/sparv.xml` und `fr/fren.xml`.

**Reina-Valera 1909** — die klassische spanische Protestantenbibel und direkte Vorläuferin der RVR1960, die selbst bei den Sociedades Bíblicas Unidas geschützt ist. Erkennbar an der alten Rechtschreibung: «crió Dios los cielos», «á su Hijo unigénito». Die Datei `es/rva.xml` aus demselben Repository ist **nicht** genommen: das ist die Reina-Valera Actualizada 1989 von Editorial Mundo Hispano und geschützt. Die spanische Quelle enthielt `<note>`-Elemente; sie sind entfernt.

**Louis Segond 1910** — die Standardbibel des französischsprachigen Protestantismus. Segond starb 1885, die Revision von 1910 ist gemeinfrei; der OSIS-Kopf führt entsprechend «Public Domain». Nicht verwechseln mit der Nouvelle Édition de Genève 1979 oder Segond 21, die beide geschützt sind.

Beide folgen der englischen Verszählung: null Abweichungen gegen die KJV in allen 1'189 Kapiteln.

---

## 和合本 (Chinese Union Version)

Aus `chi.xml` von `gratis-bible`, dessen OSIS-Kopf «Public Domain» führt. Die Chinese Union Version erschien 1919; ihr Urheberrecht ist abgelaufen. Es ist die Originalfassung von 1919, nicht das 新標點和合本 von 1988 — dessen Rechte liegen bei der Hong Kong Bible Society. Erkennbar an der alten Interpunktion mit 、．〔〕 statt ，「」（）.

Die vereinfachte Fassung ist **nicht** die Datei `chius.xml` aus demselben Repository: die ist eine andere Ausgabe mit moderner Interpunktion und enthält zudem einen sinnentstellenden Fehler (Mt 5,3 «虚心的人冇福了» statt 有福了 — «nicht gesegnet» statt «gesegnet»). Stattdessen ist `tools/cuv_simplified.xml` mit OpenCC aus der geprüften traditionellen Fassung erzeugt:

```python
import opencc
conv = opencc.OpenCC('t2s')
src = open('chi.xml', encoding='utf-8').read()
head, sep, body = src.partition('</header>')
open('cuv_simplified.xml', 'w', encoding='utf-8').write(head + sep + conv.convert(body))
```

Die Richtung traditionell → vereinfacht ist nahezu eindeutig und damit unkritisch; umgekehrt wäre sie es nicht.

**Zwei dokumentierte Korrekturen** am Quelltext, beide in `SOURCE_FIXES` im Konverter aufgeführt und bei jedem Lauf gemeldet: In 2Mo 32,32 gab das Modul die Aposiopese als ASCII-Punkte wieder, gedruckt steht dort ……. In Jes 1,23 war ein Schriftzeichen verlorengegangen und durch ein Apostroph ersetzt; gedruckt steht 贓私. Danach enthält der chinesische Text kein einziges ASCII-Zeichen mehr.

**Der Ehrfurchtsabstand bleibt erhalten.** Vor 神 steht in der CUV ein ideographisches Leerzeichen U+3000 — in 3'337 Versen. Der Konverter entfernt nur ASCII-Leerzeichen zwischen Schriftzeichen und lässt U+3000 stehen.

---

## Elberfelder 1905, King James Version, Darby Bible

Diese drei kommen aus der quotepas-Quelldatei `bible.db`, dem Ausgangsbestand des Projekts. Alle drei sind gemeinfrei; die KJV mit der üblichen Einschränkung, dass im Vereinigten Königreich ein Kronrecht (letters patent) fortbesteht.

Kontrollwerte des Konverterlaufs: 66 Bücher (39 AT / 27 NT), 1'189 Kapitel, KJV mit exakt 31'102 Versen wie erwartet, keine Duplikate, keine leeren Blöcke, keine LaTeX-Reste. Die Abweichungen der übrigen Übersetzungen sind Zählunterschiede, keine Fehler.

**Die Elberfelder 1905 ist die Leitübersetzung** (`meta.master_translation = elb`): die kuratierten Verse folgen ihrer Zählung, und `update_curated.py` prüft jede Referenz gegen sie.

---

## Was der Konverter aus dem Quellformat macht

Die quotepas-Datei enthält genau fünf LaTeX-Befehle; alle werden klammerbewusst verarbeitet, auch verschachtelt:

| Befehl | Vorkommen | Behandlung |
|---|---:|---|
| `\textsc{Herr}` / `\textsc{Herrn}` | 6'654 | → `HERR` / `HERRN` in Grossbuchstaben. Damit bleibt die Unterscheidung zwischen dem Gottesnamen und `Herr` erhalten — Kapitälchen gehen im reinen Text sonst verloren. |
| `\flqq` / `\frqq` | 3'785 | → « » (Schweizer Anführungszeichen) |
| `\biblefootnote{…}` | 1'381 | wird entfernt, samt Leerzeichenkorrektur vor Satzzeichen. Fussnoten sind auf einer 41-mm-Uhr unbrauchbar. |
| `\textit{…}` | 769 | Klammern weg, Text bleibt (kursiv markiert ergänzte Wörter) |

Dazu: `~` → geschütztes Leerzeichen, `--`/`---` → Halbgeviert-/Geviertstrich, Zeilenumbrüche im Block → einfaches Leerzeichen, Unicode-Normalisierung NFC. Befehle, die er nicht kennt, **löscht er nicht** — er zählt sie und listet sie im Bericht auf.

**Wie er die Verslabels liest.** Verslabels werden nicht blind per Regex zerlegt: weil Buchcodes selber Ziffern enthalten (`1Mo`, `2Kor`, `1Joh`), wird zuerst der Übersetzungscode und dann der **längste passende Buchcode** abgezogen; der Rest muss exakt `<Kapitel>v<Vers>` sein. Geprüft mit `slt1Joh1v9` gegen `sltJoh3v16` und mit einkapiteligen Büchern wie `sltJud1v24`.

**Was er meldet.** Verse pro Übersetzung, erkannte Bücher, Duplikate, leere Blöcke, nicht klassifizierbare Labels, LaTeX-Reste, Dateigrösse, sowie jede kuratierte Referenz, die es in der Leitübersetzung nicht gibt. Mit `--strict` bricht er bei unklassifizierten Labels ab, statt sie zu überspringen. Ab 70 MB warnt er wegen des 75-MB-Limits für Watch-Apps.

## Die kuratierte Auswahl

`tools/curated_verses.json` enthält 463 Kernverse aus 54 Büchern in 26 Themen. Sie speisen den kuratierten Zufallsmodus, die Themenliste und das Widget. Die Referenzen folgen der Zählung der Leitübersetzung; `update_curated.py` prüft jede einzelne gegen die Datenbank und schreibt nichts, solange auch nur eine Stelle fehlt.

Die Themennamen stehen **nicht** in der Datenbank, sondern im String Catalog unter `topic.<deutscher Wert>`. Die Datenbank sagt, welche Themen es gibt; der Katalog, wie sie in den sechs Sprachen geschrieben werden.
