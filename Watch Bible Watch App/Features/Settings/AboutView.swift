import SwiftUI

/// Impressum. Die Copyright-Zeilen kommen aus translation.copyright — wird
/// eine Uebersetzung aus der Datenbank genommen, verschwindet ihre Zeile
/// automatisch mit (docs/Architektur.md, Kap. 9).
struct AboutView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: appVersion)
                        .font(Typo.counter)
                        .foregroundStyle(Color.secondaryInk)
                    if let buildLine {
                        Text(verbatim: buildLine)
                            .font(Typo.counter)
                            .foregroundStyle(Color.secondaryInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }

                Text("about.bibleTexts")
                    .font(Typo.eyebrow)
                    .kerning(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.secondaryInk)
                    .padding(.top, 4)

                ForEach(model.translations) { translation in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(verbatim: translation.name)
                            .font(Typo.bookRow)
                            .foregroundStyle(Color.ink)
                        if let copyright = translation.copyright, !copyright.isEmpty {
                            Text(verbatim: copyright)
                                .font(.caption2)
                                .foregroundStyle(Color.secondaryInk)
                        }
                    }
                    .padding(.bottom, 4)
                }

                Text("about.noNetwork")
                    .font(.caption2)
                    .foregroundStyle(Color.secondaryInk)
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
        .containerBackground(Color.ground, for: .navigation)
        .navigationTitle(Text("settings.about"))
    }

    private var appVersion: String {
        let version = Bundle.main
            .object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        return "Watch Bible \(version)"
    }

    /// Build-Nummer aus `CURRENT_PROJECT_VERSION` — ein zwoelfstelliger
    /// Zeitstempel (YYYYMMDDHHMM). Neben der Version ergaebe das auf der
    /// kleinsten Uhr eine zu lange Zeile, darum steht sie eine Zeile tiefer.
    private var buildLine: String? {
        guard let build = Bundle.main
            .object(forInfoDictionaryKey: "CFBundleVersion") as? String,
              !build.isEmpty else { return nil }
        return String(format: String(localized: "about.build %@"), build)
    }
}
