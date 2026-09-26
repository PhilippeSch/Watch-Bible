#!/bin/bash
#
# xcode_check.sh
# ==============
# Bau-, Test- und Archivpruefung mit dem installierten Xcode. Geschrieben fuer
# den Umstieg auf Xcode 27 und das watchOS-27-SDK (Issue #4), aber nicht daran
# gebunden: das Skript prueft gegen das Xcode, das `xcodebuild` findet.
#
# Laeuft auf dem Mac, nicht in der Cloud. Ablauf:
#   0  Umgebung (macOS, Xcode, SDK, Runtimes, Simulator)
#   1  Debug- und Release-Build mit vollstaendiger Warnungsliste
#   2  Unit-Tests (Swift Testing), danach der ganze Testplan
#   3  Screenshots im Simulator: Einstieg Nacht, Tag und auf Chinesisch
#   4  Paketstruktur des Widgets (Datenbank liegt in der App, nicht im Widget)
#   5  Archiv mit SDK-Nachweis und Groessenkontrolle (75-MB-Grenze)
#
# Der Bericht steht danach in build/xcode-check/report.md (build/ ist in
# .gitignore) und laesst sich so ins Issue stellen:
#     gh issue comment 4 --body-file build/xcode-check/report.md
#
# Das Skript aendert nichts am Repo. Nur die Build-Phase "Set Build Number"
# schreibt wie bei jedem Build Config/Version.xcconfig.
#
# Umgebungsvariablen:
#   DEVICE_ID       UDID eines Watch-Simulators. Ohne Angabe nimmt das Skript
#                   den ersten Simulator der neuesten watchOS-Runtime.
#   DD              DerivedData, Vorgabe ~/Library/Developer/WatchBible-build
#   SKIP_TESTS=1    Schritt 2 auslassen
#   SKIP_SIM=1      Schritt 3 auslassen
#   SKIP_ARCHIVE=1  Schritt 5 auslassen
#
# Rueckgabewert 1, sobald eine Pruefung fehlschlaegt.

set -u
set -o pipefail

cd "$(dirname "$0")/.." || exit 1

PROJECT="Watch Bible.xcodeproj"
SCHEME="Watch Bible Watch App"
APP_NAME="Watch Bible Watch App"
WIDGET_NAME="BibelWatchWidget"
BUNDLE_ID="Scheuber.Watch-Bible.watchkitapp"
README_DEVICE="Apple Watch Ultra 3 (49mm)"
DEPLOYMENT_TARGET="11.2"
SIZE_LIMIT_MB=75

DD="${DD:-$HOME/Library/Developer/WatchBible-build}"
OUT="build/xcode-check"
REPORT="$OUT/report.md"
# Was waehrend xcodebuild auf dem Bildschirm erscheint; das volle Log liegt
# daneben in build/xcode-check/*.log.
SHOW=' (error|warning): |BUILD |ARCHIVE |TEST |Test run with|Executed '

mkdir -p "$DD" "$OUT"
: > "$REPORT"
FAILURES=0

say()   { printf '%s\n' "$*"; }
rep()   { printf '%s\n' "$*" >> "$REPORT"; }
both()  { say "$*"; rep "$*"; }
title() { both ""; both "## $*"; both ""; }
ok()    { both "OK: $*"; }
fail()  { FAILURES=$((FAILURES + 1)); both "**FEHLER:** $*"; }
# Befehl ausfuehren, Ausgabe zeigen und als Beleg in den Bericht schreiben.
cap() {
    local out rc
    out=$(eval "$1" 2>&1); rc=$?
    say "$out"
    rep '```'; rep "\$ $1"; rep "$out"; rep '```'
    return $rc
}
# xcodebuild mit Log: auf dem Bildschirm nur die Kernzeilen, Rueckgabewert
# ist der von xcodebuild.
xcb() {
    local log="$1"; shift
    xcodebuild "$@" 2>&1 | tee "$log" | { grep -E "$SHOW" || true; }
    return "${PIPESTATUS[0]}"
}
# Warnungen und Fehler eines Logs, dedupliziert, in den Bericht.
diagnostics() {
    local log="$1" lines
    lines=$(grep -E ' (error|warning): ' "$log" | sort -u || true)
    if [ -n "$lines" ]; then
        rep '```'; rep "$lines"; rep '```'
    else
        both "Keine Warnungen, keine Fehler."
    fi
    if grep -q 'range of supported deployment target versions' "$log"; then
        fail "Deployment Target ausserhalb des von diesem Xcode unterstuetzten Bereichs (siehe Log). Die Watch-Targets stehen auf $DEPLOYMENT_TARGET, der iOS-Container auf 15.0."
    fi
    if grep -qE 'used before being initialized|use before initialization' "$log"; then
        fail "@State-Makro: Zuweisung im init trifft auf einen Standardwert in der Deklaration. Regel von Apple: Standardwert entfernen, Backing-Storage im init ueber _name = State(initialValue:) setzen."
    fi
    if grep -q 'variable initialization expression of' "$log"; then
        fail "Linker: bekannter Fehlerbericht zum @State-Makro (Xcode 27.1, Debug-Builds). Nicht selbst umbauen, melden."
    fi
    # Nur Diagnosezeilen: das Log enthaelt auch Compiler-Flags wie
    # -Wdeprecated-declarations, die sonst jedes Mal anschlagen.
    if grep -E ' (error|warning): ' "$log" | grep -qi 'deprecated'; then
        both "Hinweis: Deprecation-Warnungen vorhanden, siehe Liste. Beheben nur, wenn der Ersatz ab watchOS $DEPLOYMENT_TARGET verfuegbar ist."
    fi
}

both "# Xcode-Pruefung Watch Bible"
both ""
both "Datum: $(date '+%Y-%m-%d %H:%M'), Branch: $(git rev-parse --abbrev-ref HEAD), Commit: $(git rev-parse --short HEAD)"

# ---------------------------------------------------------------- Schritt 0
title "Schritt 0: Umgebung"
cap "sw_vers"
cap "xcodebuild -version"
XCODE_VERSION=$(xcodebuild -version 2>/dev/null | awk '/^Xcode/ {print $2}')
XCODE_MAJOR=${XCODE_VERSION%%.*}
if [ "${XCODE_MAJOR:-0}" -ge 27 ] 2>/dev/null; then
    ok "Xcode $XCODE_VERSION"
else
    fail "Xcode 27 oder neuer erwartet, gefunden: ${XCODE_VERSION:-unbekannt}"
fi
cap "xcodebuild -showsdks | grep -i watchos"
cap "xcrun simctl list runtimes | grep -i watchos"
if [ -n "$(git status --short)" ]; then
    both "Hinweis: Arbeitskopie nicht sauber (git status --short):"
    cap "git status --short"
else
    ok "Arbeitskopie sauber."
fi

DEVICES=$(xcrun simctl list devices available 2>/dev/null)
if [ -z "${DEVICE_ID:-}" ]; then
    # Neueste watchOS-Runtime ist der letzte "-- watchOS ... --"-Abschnitt,
    # darin das erste Geraet.
    SECTION=$(printf '%s\n' "$DEVICES" | grep -E '^-- watchOS' | tail -1)
    LINE=$(printf '%s\n' "$DEVICES" \
        | awk -v s="$SECTION" '$0 == s {f = 1; next} /^--/ {f = 0} f' \
        | grep -E '\([0-9A-F-]{36}\)' | head -1)
    DEVICE_ID=$(printf '%s\n' "$LINE" \
        | grep -oE '[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}' | head -1)
fi
DEVICE_LINE=$(printf '%s\n' "$DEVICES" | grep -F "${DEVICE_ID:-NICHTS}" | head -1)
DEVICE_NAME=$(printf '%s\n' "$DEVICE_LINE" \
    | sed -E 's/^[[:space:]]+//; s/ \([0-9A-F-]{36}\).*$//')
if [ -n "${DEVICE_ID:-}" ] && [ -n "$DEVICE_NAME" ]; then
    ok "Simulator: $DEVICE_NAME ($DEVICE_ID)"
else
    fail "Kein Watch-Simulator gefunden. DEVICE_ID setzen oder in Xcode eine watchOS-Runtime laden."
    DEVICE_ID=""
fi
if printf '%s\n' "$DEVICES" | grep -qF "$README_DEVICE"; then
    ok "Der in der README genannte Simulator «$README_DEVICE» existiert."
else
    both "Hinweis: «$README_DEVICE» aus der README gibt es hier nicht, Testbefehl in der README anpassen (Schritt 7 im Issue)."
fi

# ---------------------------------------------------------------- Schritt 1
title "Schritt 1: Build"
BUILD_OK=1
for CFG in Debug Release; do
    both "### $CFG"
    LOG="$OUT/build-$CFG.log"
    if xcb "$LOG" -project "$PROJECT" -scheme "$SCHEME" -configuration "$CFG" \
           -destination 'generic/platform=watchOS Simulator' \
           -derivedDataPath "$DD" build; then
        ok "$CFG: BUILD SUCCEEDED"
    else
        fail "$CFG: Build fehlgeschlagen, Log: $LOG"
        BUILD_OK=0
    fi
    diagnostics "$LOG"
done

# ---------------------------------------------------------------- Schritt 2
title "Schritt 2: Tests"
if [ "${SKIP_TESTS:-0}" = 1 ]; then
    both "Uebersprungen (SKIP_TESTS=1)."
elif [ -z "$DEVICE_ID" ] || [ "$BUILD_OK" = 0 ]; then
    both "Uebersprungen: kein Simulator oder Build fehlgeschlagen."
else
    DEST="platform=watchOS Simulator,id=$DEVICE_ID"
    both "### Unit-Tests"
    LOG="$OUT/test-unit.log"
    if xcb "$LOG" -project "$PROJECT" -scheme "$SCHEME" -destination "$DEST" \
           -derivedDataPath "$DD" -only-testing:"$SCHEME"Tests test; then
        ok "Unit-Tests bestanden."
    else
        fail "Unit-Tests fehlgeschlagen, Log: $LOG"
    fi
    cap "grep -E 'Test run with|Executed |Test Suite .*(passed|failed)|error:' '$LOG' | sort -u"
    both "### Ganzer Testplan (mit UI-Tests)"
    LOG="$OUT/test-all.log"
    if xcb "$LOG" -project "$PROJECT" -scheme "$SCHEME" -destination "$DEST" \
           -derivedDataPath "$DD" test; then
        ok "Testplan bestanden."
    else
        fail "Testplan fehlgeschlagen, Log: $LOG"
    fi
    cap "grep -E 'Test run with|Executed |Test Suite .*(passed|failed)|error:' '$LOG' | sort -u"
fi

# ---------------------------------------------------------------- Schritt 3
APP="$DD/Build/Products/Debug-watchsimulator/$APP_NAME.app"
title "Schritt 3: Screenshots im Simulator"
if [ "${SKIP_SIM:-0}" = 1 ]; then
    both "Uebersprungen (SKIP_SIM=1)."
elif [ -z "$DEVICE_ID" ] || [ ! -d "$APP" ]; then
    both "Uebersprungen: kein Simulator oder kein Debug-Build unter $APP."
else
    shot() { # shot <appearance> <datei> [Startargumente ...]
        local appearance="$1" file="$2"; shift 2
        xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true
        if ! xcrun simctl spawn "$DEVICE_ID" defaults write "$BUNDLE_ID" appearance -string "$appearance" >/dev/null 2>&1; then
            both "Hinweis: Darstellung «$appearance» liess sich nicht per defaults setzen, Screenshot zeigt die aktuelle Einstellung."
        fi
        xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID" "$@" >/dev/null 2>&1 || true
        sleep 4
        if xcrun simctl io "$DEVICE_ID" screenshot "$OUT/$file" >/dev/null 2>&1; then
            both "Screenshot: $OUT/$file"
        else
            fail "Screenshot $file fehlgeschlagen."
        fi
    }
    xcrun simctl bootstatus "$DEVICE_ID" -b >/dev/null 2>&1 || true
    if xcrun simctl install "$DEVICE_ID" "$APP" >/dev/null 2>&1; then
        ok "App installiert."
        shot night home-night.png
        shot day home-day.png
        # Chinesisch, Sprache nur fuer diesen Start. Den Deep Link des Widgets
        # kann simctl openurl nicht zustellen: das Schema ist bewusst nicht als
        # URL-Typ registriert (Shared/DeepLink.swift), ihn pruefen die
        # DeepLinkTests und das Antippen der Komplikation.
        shot night home-zh-hans.png -AppleLanguages '(zh-Hans)' -AppleLocale zh_CN
        xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true
        xcrun simctl spawn "$DEVICE_ID" defaults delete "$BUNDLE_ID" appearance >/dev/null 2>&1 || true
        both "Sichtpruefung der Bilder: Einstieg mit vier Zeilen auf Feldflaechen, Tag- und Nachtpalette, Titel lesbar, auf Chinesisch keine abgeschnittenen Zeilen."
    else
        fail "App liess sich nicht auf dem Simulator installieren."
    fi
fi

# ---------------------------------------------------------------- Schritt 4
title "Schritt 4: Paketstruktur des Widgets"
if [ ! -d "$APP" ]; then
    both "Uebersprungen: kein Debug-Build unter $APP."
else
    APPEX="$APP/PlugIns/$WIDGET_NAME.appex"
    if [ -d "$APPEX" ]; then ok "Widget liegt unter PlugIns/."; else fail "Widget fehlt: $APPEX"; fi
    if [ -f "$APP/bible.sqlite" ]; then ok "bible.sqlite liegt in der App."; else fail "bible.sqlite fehlt in der App."; fi
    if [ -e "$APPEX/bible.sqlite" ]; then
        fail "bible.sqlite liegt zusaetzlich im Widget (doppelte 60 MB)."
    else
        ok "Keine zweite Datenbank im Widget."
    fi
    cap "plutil -p '$APPEX/Info.plist' | grep -E 'NSExtensionPointIdentifier|MinimumOSVersion|DTSDKName'"
    if plutil -p "$APPEX/Info.plist" 2>/dev/null | grep -q 'com.apple.widgetkit-extension'; then
        ok "Extension Point widgetkit-extension."
    else
        fail "Extension Point stimmt nicht."
    fi
fi

# ---------------------------------------------------------------- Schritt 5
title "Schritt 5: Archiv mit SDK-Nachweis"
if [ "${SKIP_ARCHIVE:-0}" = 1 ]; then
    both "Uebersprungen (SKIP_ARCHIVE=1)."
elif [ "$BUILD_OK" = 0 ]; then
    both "Uebersprungen: Build fehlgeschlagen."
else
    ARCHIVE="$DD/WatchBible-check.xcarchive"
    rm -rf "$ARCHIVE"
    LOG="$OUT/archive.log"
    SIGNED="signiert"
    if xcb "$LOG" -project "$PROJECT" -scheme "$SCHEME" \
           -destination 'generic/platform=watchOS' -derivedDataPath "$DD" \
           -archivePath "$ARCHIVE" -allowProvisioningUpdates archive; then
        ok "ARCHIVE SUCCEEDED ($SIGNED)."
    else
        both "Archiv mit Signatur fehlgeschlagen, zweiter Versuch ohne Signatur (fuer den SDK-Nachweis genuegt das)."
        SIGNED="unsigniert"
        LOG="$OUT/archive-unsigned.log"
        if xcb "$LOG" -project "$PROJECT" -scheme "$SCHEME" \
               -destination 'generic/platform=watchOS' -derivedDataPath "$DD" \
               -archivePath "$ARCHIVE" archive \
               CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO; then
            ok "ARCHIVE SUCCEEDED ($SIGNED)."
        else
            fail "Archiv fehlgeschlagen, Log: $LOG"
        fi
    fi
    diagnostics "$LOG"
    PLIST=$(find "$ARCHIVE/Products" -path "*/$APP_NAME.app/Info.plist" 2>/dev/null | head -1)
    if [ -n "$PLIST" ]; then
        cap "plutil -p '$PLIST' | grep -E 'DTSDKName|DTXcode|DTPlatformVersion|MinimumOSVersion|CFBundleVersion|CFBundleShortVersionString'"
        SDK=$(plutil -p "$PLIST" | grep -oE 'watchos[0-9]+' | head -1)
        SDK_MAJOR=${SDK#watchos}
        if [ "${SDK_MAJOR:-0}" -ge 27 ] 2>/dev/null; then
            ok "Gebaut mit dem $SDK-SDK, erfuellt die App-Store-Anforderung ab April 2027."
        else
            fail "DTSDKName ist «${SDK:-unbekannt}», erwartet watchos27 oder neuer."
        fi
        if plutil -p "$PLIST" | grep -q "\"MinimumOSVersion\" => \"$DEPLOYMENT_TARGET\""; then
            ok "MinimumOSVersion $DEPLOYMENT_TARGET unveraendert."
        else
            fail "MinimumOSVersion ist nicht $DEPLOYMENT_TARGET."
        fi
        SIZE_MB=$(du -sm "$ARCHIVE/Products/Applications" | awk '{print $1}')
        cap "du -sm '$ARCHIVE/Products/Applications'"
        if [ "${SIZE_MB:-0}" -lt "$SIZE_LIMIT_MB" ]; then
            ok "$SIZE_MB MB unkomprimiert, unter der Grenze von $SIZE_LIMIT_MB MB (Xcode 26: 62.2 MB)."
        else
            fail "$SIZE_MB MB unkomprimiert, Grenze $SIZE_LIMIT_MB MB."
        fi
    else
        fail "Info.plist der App im Archiv nicht gefunden."
    fi
fi

# ---------------------------------------------------------------- Ergebnis
title "Ergebnis"
if [ "$FAILURES" = 0 ]; then
    both "Alle automatischen Pruefungen bestanden."
else
    both "$FAILURES Pruefung(en) fehlgeschlagen, siehe FEHLER oben."
fi
both ""
both "Offen, nur von Hand pruefbar:"
both "- Zufallsvers: zehnmal schnell nach oben wischen, Haptik beim Einrasten, nie eine leere Seite."
both "- Leseansicht: Blatt «Uebersetzung wechseln» auf Papiergrund, nicht auf dem grauen Systemblatt."
both "- Einstellungen: Picker-Werte im Tagmodus lesbar."
both "- Komplikation «Vers des Tages» auf ein Zifferblatt legen, Tippen oeffnet den Vers."
both "- In Xcode «Update to recommended settings», danach den Diff der Projektdatei pruefen."
both ""
both "Bericht: $REPORT, Logs und Screenshots daneben in $OUT/."
[ "$FAILURES" = 0 ]
