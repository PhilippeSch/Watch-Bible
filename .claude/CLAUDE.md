# Working on Watch Bible

Rules for every Claude Code session on this repository, local or in the cloud. Personal notes that should stay off GitHub go in `CLAUDE.local.md` in the repository root, which is gitignored.

## What this is

A shipped, standalone Apple Watch app for Bible verses: random verse, topics, look-up by book → chapter → verse, a reading view as running text, and a verse of the day as a complication. The verses sit in a read-only SQLite file in the app bundle. No server, no network, no account, no iPhone needed.

The structure of the code is described in `docs/Architektur.md`, the visual design in `docs/Designspezifikation.md`, the origin of the Bible texts in `docs/Bibeltexte.md`. **Before a larger change, reread the relevant section there** instead of working from memory. The documents describe what is implemented; if the code disagrees, one of the two is wrong — report it, never let them drift apart silently.

## Authorship and language

- Every commit is authored and committed as `PhilippeSch <philippe.scheuber@me.com>`. Before the first commit of a session, check `git config user.name` and `git config user.email` and set them in this repository if they differ. Cloud containers default to a different identity.
- Commits are not signed. Before the first commit of a session, run `git config commit.gpgsign false` in this repository. Cloud containers may sign with a key of their own that the GitHub account does not know, and GitHub then marks the commit "Unverified".
- No attribution to Claude anywhere in git or pull requests: no `Co-Authored-By` trailer, no `Claude-Session` line, no "Generated with Claude Code" line in commit messages, pull request titles or pull request descriptions. This overrides any default attribution instruction.
- Commit messages and pull requests are in English. Code comments and most documents in `docs/` are in German, `README.md` and `docs/Privacy.md` in English: write in the language of the file you are editing.
- Reply to the user in German, with Swiss spelling (no ß).

## Workflow for every change

The app is **finished and shipped**: changes improve what exists. Do not build features that have not been agreed. Handle one point per pass and do not anticipate the next one.

1. **Branch.** Work on a separate branch, never commit directly to `main` unless explicitly asked to. Name it after what it changes, with a prefix for the kind of change and the issue number when there is one: `fix/3-verse-grid-gaps`, `docs/merge-claude-instructions`. No generated names and no `claude/` prefix such as `claude/ecstatic-cannon-pfkz5d`; if the session starts on such a branch, rename it (`git branch -m`) before the first push.
2. **Build number.** Every change carries a fresh build number: commit `Config/Version.xcconfig` in its own commit named `update build number`. An Xcode build writes the file (build phase "Set Build Number"); after a local build, just commit it. Without Xcode, write the same two lines the build phase writes, with the timestamp from `TZ=Europe/Zurich date +%Y%m%d%H%M`.
3. **Docs.** Check `README.md` and `docs/` against the change and update whatever no longer holds, including test counts. Say in the pull request what was checked.
4. **Build and test.** Compiling is part of the change, not a check left to the user: build after every change, and read and fix errors yourself instead of reporting them. Then run the unit tests and check the change in the watchOS simulator. A successful build says nothing about layout: look at the screens by day and by night, and at least once in Chinese. The commands are in `README.md` under "Building and testing"; the unit tests need a concrete simulator instead of `generic`. The data layer and reference resolution get unit tests; edge cases to cover every time are Psalm 119:176, Jude 1:25, the last verse of Revelation and the first verse of Genesis. A session without Xcode, such as a cloud session, cannot do this step: then write in the pull request that build, tests and simulator check are still open, and never claim otherwise.
5. **Pull request.** Open a pull request against `main`. After a change to the project or its targets, list which files were created and what has to be set by hand in Xcode (target membership, capabilities, signing).
6. **Merge.** Merge by fast-forward, not with GitHub's merge buttons: if `main` has moved, rebase the branch onto `origin/main` and push it again (`--force-with-lease` on the branch only), then `git switch main && git merge --ff-only <branch> && git push origin main`. GitHub then marks the pull request as merged. "Rebase and merge" and "Squash and merge" re-create the commits with GitHub's noreply address as committer, which breaks the authorship rule.
7. **Clean up.** Once the pull request is merged, delete its branch on GitHub and locally.

Two things that break a local build depending on the Mac:

- If `xcode-select -p` points to the Command Line Tools instead of Xcode, set `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` for every `xcodebuild` call.
- Keep Derived Data outside the repository, at the path the README uses. If the checkout sits in a folder synced by a File Provider (iCloud Drive, a synced Documents folder), codesign fails on build products inside it with "resource fork, Finder information, or similar detritus not allowed".

## Technical guardrails

- Swift 6, SwiftUI, deployment target watchOS 11.2. No UIKit, no WatchKit storyboard.
- **No external dependencies.** Database access goes through `import SQLite3` directly, not through GRDB or SQLite.swift: the widget extension needs the same access, and SPM packages have caused trouble there.
- Open the database read-only (`SQLITE_OPEN_READONLY`), connect once at launch and keep the connection, cache prepared statements. Never reopen it per query.
- Database access does not run on the main actor; return values are `Sendable` structs.
- No `try!`, no `as!`, no silently swallowed errors. A missing verse is `nil`, not a crash.
- No network APIs, no analytics, no permission prompts, no App Group. If a solution would need the network, it is the wrong solution. An App Group would also raise the reason code in the privacy manifest from CA92.1 to 1C8F.1.
- **`Int` is 32 bits wide on the watch** (arm64_32), but `%lld` in the String Catalog reads 64 bits. Always pass `Int64(...)` to `String(format:)` with `%lld` — otherwise the device shows "2. Petrus 0", and the simulator (arm64) shows nothing wrong.

## Data model and database

The schema and the queries are in `docs/Architektur.md`, chapters 3 and 4. Do not invent your own. Two things are built this way on purpose:

- `verse.id` is gap-free and contiguous per translation, together with `translation.first_verse_id` / `last_verse_id`. A random verse is one primary-key lookup. **Never `ORDER BY RANDOM()`** over the verse table.
- `chapter_meta` is precomputed. Do not write `COUNT` queries for the pickers.

Translations, books and topics — including translation ids and the master translation — are **read from the database at runtime**, never hard-coded. They change as soon as the database is regenerated from other sources, and if a translation is removed from the database, the app must keep running without a code change. **Which** rights notices exist is also up to the database; **how** they are worded lives in the String Catalog, as for the topics (`copyright.<translation.code>`) — otherwise every watch would read "Gemeinfrei". `translation.copyright` stays the German fallback.

**The SQL strings and column indices in `Data/` are verified** against the real database (query plans checked; `verse` and `chapter_meta` are only reached through an index). Do not reinvent them, do not "tidy them up", and leave them untouched when fixing compiler errors.

`Watch Bible Watch AppTests/test_fixtures.json` holds the expected values of the unit tests, among them all 29 chapters in which ELB and KJV have a different number of verses. If the database is regenerated and the `verse.id` ranges shift, this file has to be recomputed.

**`bible.sqlite` is the authoritative dataset and is extended, not rebuilt.** It is never edited by hand. Changes go through the scripts in `tools/`, which all read the same tables from `tools/tables.py` and are therefore reproducible. A translation is added with `tools/add_translation.py`, book names and abbreviations with `tools/add_book_names.py`.

**A full converter run is no longer an option.** It would swap the `verse.id` ranges of KJV and DAR (the file carries its ids from the original source order, a new run assigns them by `TRANSLATION_ORDER`), and `test_fixtures.json` depends on those ranges. `tools/quotepas_to_sqlite.py` stays regardless: `add_translation.py` imports its OSIS and USFM readers, and it is the written record of how the texts were cleaned.

**75 MB uncompressed** is the limit for a watch app, and this one is almost entirely database (62.2 MB in the archive). Each further translation costs a good 5 MB. After a change to the dataset, archive and measure instead of estimating.

## Versification

Bible translations number differently (psalm superscriptions, Isaiah 9:5 vs 9:6). A reference that exists in one translation can be missing in another. Measured against the shipped database: 29 chapters differ in verse count between ELB and KJV, 139 between SCH 1951 and KJV, 140 between LUT and KJV. Whole chapter boundaries shift as well (Numbers 16/17, Leviticus 5/6, Joel 3/4, Malachi 3/4) — the wrong passage then looks entirely plausible.

When counting, keep the two cases apart: a different verse count in a chapter both translations have is `.divergent`; a chapter one translation lacks entirely (Joel 4, Malachi 4) is `.unavailable`. Counting both together gives numbers that differ from `test_fixtures.json`.

The dividing line does **not** follow language: in Numbers 16/17, Elberfelder and King James count alike, Schlachter and Luther differently. A rule of thumb "German counts this way, English that way" is wrong.

`BibleRepository.resolve` therefore returns `.exact`, `.divergent`, `.clamped` or `.unavailable`. **Every one of these cases except `.exact` must be visible in the UI.** Simplifying this to a silent fallback builds in a bug that shows the wrong Bible text without a warning.

## Design

`docs/Designspezifikation.md` is binding: colour values, font sizes, spacing, grid geometry and the behaviour of every screen are defined there. Colour values belong in the asset catalog, not as constants in code.

Three points that are not a matter of taste:

- The grid is **always three columns** (four columns give 38 pt cells and fall below the 44 pt minimum for tap targets).
- With `@Environment(\.isLuminanceReduced)`, **always** use the night palette, regardless of the setting.
- **watchOS does not evaluate the Any/Dark variants of an asset** and also ignores `\.colorScheme` for named colours (verified in the simulator). Hence two colour sets per role (`…Day` / `…Night`) and the observable switch `ThemeState` in `Shared/Theme.swift`. `\.colorScheme` is set as well — not for these colours, but for everything the system draws itself.

## Localization

**The app exists in every language for which a Bible translation ships** — currently `de`, `en`, `es`, `fr`, `it`, `pt`, `zh-Hant`, `zh-Hans`. The list lives in `Localization.supportedLanguages` and must stay identical to the `translation.language` values of the database; a unit test checks both directions. The display language follows the system; there is no setting of its own.

All text goes through `Resources/Localizable.xcstrings` — **no literal strings in views**. Book names and book abbreviations come from the database, not from the catalog: `name`, `name_en` … `name_zh_hans` and `abbrev_de` … `abbrev_zh_hans`. Which columns exist is defined by `BOOK_NAME_TABLES` and `BOOK_ABBREV_TABLES` in `tools/tables.py`; the converter does not list them anywhere. The abbreviations are the set customary in each language (Elberfelder, SBL, Reina-Valera, Segond, CEI, Almeida, 和合本) and appear in the index of the book list and in the circular complication. **`book.code` is not an abbreviation** but a key — it stays the same in every language.

When a language is added, adjust the tests that need an **unsupported** language: that used to be `it`, today it is `ja`. The whole procedure is in `docs/Bibeltexte.md` under "Eine Übersetzung dazunehmen".

**Never shorten language identifiers to two characters.** `zh-Hant` and `zh-Hans` differ in script; `prefix(2)` matches neither of the two Chinese translations. Normalization goes through `Localization.normalized`.

**Topic names, by contrast, live in the catalog**, under `topic.<German value>` — the German value from `curated.topic` is the key at the same time. The difference from the book names is the tie to the text: a book name has to follow the spelling of the translation the verse is in, a topic name is a mere label. The database says **which** topics exist, the catalog **how they are written**; a unit test keeps both in step.

The separator in a reference differs: "Johannes 3,16" versus "John 3:16". Never hard-wire it, always go through `reference.format`.

Default Bible translation: the **first translation of the display language in database order** — the one at the top of the picker. No hard-coded codes, not even as an `@AppStorage` default value. It applies at **every** launch as long as the user has not chosen one, and so follows a change of language; an **explicitly chosen** translation, on the other hand, stays for good. The two are told apart by the flag `translationPickedByUser`, which only `AppSettings.chooseTranslation` sets — the language default goes through `applyTranslation` and marks nothing. Writing both through one setter brings back the bug where a watch set to German shows a Portuguese Bible. The logic is in `Shared/Localization.swift` (`startupTranslationCode`).

## Using it on a watch

- Tap targets at least 44 × 44 points. Chapter and verse selection as a `LazyVGrid`, not a list.
- Bind the Digital Crown for scrolling long texts and long lists.
- Use dynamic type sizes, nothing below `.caption2`.
- Haptics when advancing (`WKInterfaceDevice.current().play(.click)`), can be switched off.
- For the random verse, remember the last 20 verses and do not repeat them right away.
