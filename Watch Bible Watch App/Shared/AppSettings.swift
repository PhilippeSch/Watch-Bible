import SwiftUI

/// Benutzereinstellungen. Bewusst nur @AppStorage — kein eigener Speicher,
/// keine Datei, keine Synchronisation. Das haelt das Privacy-Manifest bei
/// einem einzigen Eintrag (NSPrivacyAccessedAPICategoryUserDefaults).
///
/// @AppStorage und @Observable vertragen sich nicht von selbst: die Speicher-
/// Properties sind @ObservationIgnored, sonst kollidieren die Property-Wrapper.
/// Damit die Oberflaeche Aenderungen trotzdem sieht, laeuft jeder Zugriff ueber
/// beobachtete computed Properties, deren Setter `revision` erhoehen.
@Observable
final class AppSettings {

    /// Beobachteter Zaehler; jede Aenderung invalidiert die lesenden Views.
    private var revision = 0

    enum RandomMode: String, CaseIterable, Identifiable {
        case wholeBible = "whole"
        case curated    = "curated"

        var id: String { rawValue }
        var label: String {
            switch self {
            case .wholeBible: String(localized: "random.mode.whole")
            case .curated:    String(localized: "random.mode.curated")
            }
        }
    }

    enum TextScale: String, CaseIterable, Identifiable {
        case small, medium, large

        var id: String { rawValue }
        var label: String {
            switch self {
            case .small:  String(localized: "settings.textSize.small")
            case .medium: String(localized: "settings.textSize.medium")
            case .large:  String(localized: "settings.textSize.large")
            }
        }
        /// Verstext-Grundgroesse gemaess Designspezifikation (14 / 16 / 18 pt).
        var verseSize: CGFloat {
            switch self {
            case .small:  14
            case .medium: 16
            case .large:  18
            }
        }
    }

    /// Darstellung: Tag, Nacht oder automatisch zwischen zwei Uhrzeiten.
    enum Appearance: String, CaseIterable, Identifiable {
        case day, night, auto

        var id: String { rawValue }
        var label: String {
            switch self {
            case .day:   String(localized: "settings.appearance.day")
            case .night: String(localized: "settings.appearance.night")
            case .auto:  String(localized: "settings.appearance.auto")
            }
        }
    }

    // MARK: - Speicher (nicht direkt verwenden, Zugriff ueber die computed Properties)

    @ObservationIgnored
    @AppStorage("translationCode") private var translationCodeStorage: String = "elb"

    @ObservationIgnored
    @AppStorage("randomMode") private var randomModeRaw: String = RandomMode.curated.rawValue

    @ObservationIgnored
    @AppStorage("textScale") private var textScaleRaw: String = TextScale.medium.rawValue

    @ObservationIgnored
    @AppStorage("haptics") private var hapticsStorage: Bool = true

    @ObservationIgnored
    @AppStorage("appearance") private var appearanceRaw: String = Appearance.auto.rawValue

    /// Nachtfenster bei `Automatisch`, Minuten seit Mitternacht. Vorgabe 20:00–07:00.
    @ObservationIgnored
    @AppStorage("nightStart") private var nightStartStorage: Int = 20 * 60

    @ObservationIgnored
    @AppStorage("nightEnd") private var nightEndStorage: Int = 7 * 60

    /// Zuletzt gelesene Stelle, damit die App dort wieder anbietet weiterzulesen.
    @ObservationIgnored
    @AppStorage("lastReference") private var lastReferenceJSON: String = ""

    // MARK: - Beobachtete Zugriffe

    var translationCode: String {
        get { _ = revision; return translationCodeStorage }
        set { translationCodeStorage = newValue; revision += 1 }
    }

    var randomMode: RandomMode {
        get { _ = revision; return RandomMode(rawValue: randomModeRaw) ?? .curated }
        set { randomModeRaw = newValue.rawValue; revision += 1 }
    }

    var textScale: TextScale {
        get { _ = revision; return TextScale(rawValue: textScaleRaw) ?? .medium }
        set { textScaleRaw = newValue.rawValue; revision += 1 }
    }

    var hapticsEnabled: Bool {
        get { _ = revision; return hapticsStorage }
        set { hapticsStorage = newValue; revision += 1 }
    }

    var appearance: Appearance {
        get { _ = revision; return Appearance(rawValue: appearanceRaw) ?? .auto }
        set { appearanceRaw = newValue.rawValue; revision += 1 }
    }

    var nightStartMinutes: Int {
        get { _ = revision; return nightStartStorage }
        set { nightStartStorage = newValue; revision += 1 }
    }

    var nightEndMinutes: Int {
        get { _ = revision; return nightEndStorage }
        set { nightEndStorage = newValue; revision += 1 }
    }

    var lastReference: VerseReference? {
        get {
            _ = revision
            guard let data = lastReferenceJSON.data(using: .utf8), !data.isEmpty else { return nil }
            return try? JSONDecoder().decode(VerseReference.self, from: data)
        }
        set {
            guard let newValue, let data = try? JSONEncoder().encode(newValue),
                  let json = String(data: data, encoding: .utf8) else {
                lastReferenceJSON = ""
                revision += 1
                return
            }
            lastReferenceJSON = json
            revision += 1
        }
    }

    /// Gilt zur angegebenen Zeit die Nachtpalette? `isLuminanceReduced` wird
    /// separat behandelt (immer Nacht) und gehoert nicht hierher.
    func isNight(at date: Date) -> Bool {
        switch appearance {
        case .day:   return false
        case .night: return true
        case .auto:
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            let now = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            let start = nightStartMinutes, end = nightEndMinutes
            // Fenster ueber Mitternacht (20:00–07:00) oder innerhalb des Tages.
            return start <= end ? (now >= start && now < end)
                                : (now >= start || now < end)
        }
    }

    /// True beim allerersten Start — dann darf die Sprachvorgabe die
    /// Uebersetzung setzen. Danach nie wieder (siehe Localization.swift).
    static var hasStoredTranslation: Bool {
        UserDefaults.standard.string(forKey: "translationCode") != nil
    }
}
