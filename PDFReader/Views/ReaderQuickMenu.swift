import SwiftUI

struct ReaderQuickMenu: View {
    @Binding var preferences: ReaderPreferences

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "textformat")
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                Picker("字体", selection: $preferences.fontChoice) {
                    ForEach(ReaderFontChoice.allCases) { font in
                        Text(font.title).tag(font)
                    }
                }
                .pickerStyle(.menu)

                Spacer()
            }

            HStack(spacing: 12) {
                Image(systemName: "textformat.size.smaller")
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                Slider(value: $preferences.textSize, in: ReaderPreferences.textSizeRange, step: 1)

                Image(systemName: "textformat.size.larger")
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
            }

            HStack {
                Text("字号 \(Int(preferences.textSize))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("重置") {
                    preferences = ReaderPreferences()
                }
                .font(.footnote.weight(.semibold))
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
