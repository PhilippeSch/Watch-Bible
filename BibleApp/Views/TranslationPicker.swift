import SwiftUI

struct TranslationPicker: View {
    @Binding var selection: String
    private let database = BibleDatabase()
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        List(database.getTranslations(), id: \.id) { translation in
            Button(action: {
                selection = translation.id
                presentationMode.wrappedValue.dismiss()
            }) {
                HStack {
                    Text(translation.name)
                    if translation.id == selection {
                        Spacer()
                        Image(systemName: "checkmark")
                    }
                }
            }
            .frame(minHeight: 44) // Following Apple's touch target guidelines
        }
    }
} 