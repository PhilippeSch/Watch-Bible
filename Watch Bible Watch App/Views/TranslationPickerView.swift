import SwiftUI

struct TranslationPickerView: View {
    let translations: [BibleDatabase.Translation]
    @Binding var selectedTranslation: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List(translations) { translation in
            Button {
                selectedTranslation = translation.id
                dismiss()
            } label: {
                HStack {
                    Text(translation.name)
                    Spacer()
                    if translation.id == selectedTranslation {
                        Image(systemName: "checkmark")
                    }
                }
            }
        }
        .navigationTitle("Übersetzung")
    }
} 