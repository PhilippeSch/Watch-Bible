# App Review Information — Notes (en)

Answer to the Guideline 2.1 rejection of 15 August 2026. The block below covers points 2 to 7
of Apple's list; point 1, the screen recording, is made separately — a shot list is at the end
of this file.

Paste the block into **App Store Connect › App Review Information › Notes** and reply to App
Review with the recording attached. The Notes field holds 4000 characters; the block uses 3989.

```
Watch Bible is a standalone watchOS app; the iOS container has no user interface, so please run it on the paired Apple Watch. There is no account, no purchase, no user-generated content and no permission prompt anywhere in the app, so none appear in the recording.

1. SCREEN RECORDING
Recorded on a physical Apple Watch on the latest watchOS, starting with the app launch: home, random verse, topics, look-up, reading, translation change, settings, complication.

2. DEVICES AND OPERATING SYSTEMS TESTED
- Physical: Apple Watch Ultra (1st gen), watchOS 26.6, paired with iPhone 16 Pro, iOS 26.5
- Simulator: Apple Watch Ultra 3 (49 mm), Apple Watch SE 3 (40 mm)
- Tested in all eight interface languages, day and night appearance, all three text sizes, and Airplane Mode.

3. PURPOSE AND TARGET AUDIENCE
The app puts the complete Bible on the wrist. Bible apps for the watch usually mirror an iPhone app or fetch text from a server, and fail without the phone or a connection. Watch Bible carries twelve translations in eight languages inside the app: random verse, 26 topics, look-up by book, chapter and verse, a reading view that runs on chapter by chapter, and a verse of the day complication. It behaves identically in Airplane Mode. Audience: readers of the Bible of any denomination who want scripture at a glance without taking out a phone.

4. SETUP AND ACCESS
No login, no demo account, no sample files, no configuration: install on the watch, open the app, everything is there.
- Home: Random verse, Topics, Look up, Settings, and "Continue" with the last place read.
- Random verse: tap it or swipe up for the next. Settings > Random mode switches between the whole Bible and 463 key verses.
- Look up: book > chapter > verse, in three-column grids.
- Reading view: the chapter as running text, Digital Crown scrolls, buttons at its end step to the next or previous chapter. The button at the top right changes translation; where two editions number a chapter differently (Numbers 17, Joel 3), both verse counts are shown rather than a silently different passage.
- Complication: watch face > Edit > Complications > "Verse of the day"; also in the Smart Stack.

5. EXTERNAL SERVICES, TOOLS OR PLATFORMS
None. The app has no networking code and no third-party code at all: no data provider, authentication, payment processor, analytics, advertising, AI service or SDK. The translations ship in the app bundle as a read-only SQLite file; only Apple frameworks are used (SwiftUI, WidgetKit, Foundation, SQLite3). The privacy manifest has one entry, NSPrivacyAccessedAPICategoryUserDefaults with reason CA92.1, for settings and reading position stored on the watch. Nothing leaves the device; no permission is requested.

6. REGIONAL DIFFERENCES
None. There is no server and no remote configuration, so nothing can vary by region: every user gets the same app and all twelve translations. The interface follows the watch's system language among the app's eight languages and falls back to English - a display language, not a regional restriction.

7. RIGHTS TO THE BIBLE TEXTS
Not a regulated industry. Every text is public domain or freely licensed; no copyrighted modern translation is included.
- Public domain: Elberfelder 1905, Luther 1912, King James, Darby, Reina-Valera 1909, Segond 1910, Riveduta 1927, Chinese Union Version 1919 (both scripts); Berean Standard Bible, released into the public domain by its rights holders on 30 April 2023.
- CC BY 4.0, attribution under Settings > About > Bible texts: Schlachter 1951, (c) 1951 Genfer Bibelgesellschaft; Biblia Livre, (c) 2018 Diego Santos, Mario Sergio, Marco Teles.
Sources: gratis-bible, ebible.org and usfm-bible/examples.bsb, each carrying those licence statements. Where a newer revision of the same name is copyrighted (Segond 21, RVR1960, Schlachter 2000), the older free edition is shipped. Provenance and licence of each text, in German:
https://github.com/PhilippeSch/Watch-Bible/blob/main/docs/Bibeltexte.md
```

## Optional sentence for section 7 — the King James

The repository states openly that the KJV is public domain **outside** the United Kingdom,
where a Crown letters patent persists. Naming it is the fuller answer to question 7; leaving
it out is no misstatement, since the patent concerns printing in one country and the app
ships no text under copyright in the ordinary sense. If it goes in, drop the sentence
beginning «Where a newer revision» to stay under 4000 characters:

```
The King James Version is public domain except in the United Kingdom, where a Crown letters patent covers its printing.
```

## Shot list for the recording

Not part of the Notes. One take, beginning with the app launch, 60 to 90 seconds, physical
watch on the current watchOS. Airplane Mode on for the whole recording makes the offline
claim visible in the status area.

1. Home screen right after launch — shows there is no login, no splash, no dialog.
2. Random verse: two or three swipes upward. The translation's abbreviation is bottom right.
3. Back, Topics: open one topic, scroll with the Digital Crown, tap a verse.
4. «Read in context»: reading view, Crown scrolling, the step button on to the next chapter.
5. Back to Home, Look up: book list with the index, chapter grid, verse grid, a verse.
6. In the reader, change translation on a chapter whose verse counts differ (Numbers 17 or
   Joel 3) so the versification notice appears.
7. Settings: appearance day/night, text size, About › Bible texts with the licences.
8. Watch face: the «Verse of the day» complication, tapped once to open the app.
