import AppKit
import SwiftUI

/// A one-time, installation-scoped language choice. It deliberately writes to
/// the same AppSettings field used by Settings so there is only one source of
/// truth for localization throughout the app.
struct LanguageOnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selectedLanguage: String

    init() {
        let suggestion = Locale.preferredLanguages.first?.hasPrefix("zh") == true ? "zh-Hans" : "en"
        _selectedLanguage = State(initialValue: suggestion)
    }

    private var isEnglish: Bool { selectedLanguage == "en" }

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor).ignoresSafeArea()

            VStack(spacing: 30) {
                VStack(spacing: 14) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 76, height: 76)
                        .accessibilityHidden(true)
                    Text(isEnglish ? "Welcome to GrokDesk" : "欢迎使用 GrokDesk")
                        .font(.system(size: 30, weight: .semibold))
                    Text(isEnglish ? "Choose the language used throughout the app." : "选择 GrokDesk 的界面语言。")
                        .font(GrokTypography.body)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 14) {
                    languageOption(
                        code: "zh-Hans",
                        title: "简体中文",
                        detail: "使用简体中文界面",
                        symbol: "character.book.closed"
                    )
                    languageOption(
                        code: "en",
                        title: "English",
                        detail: "Use GrokDesk in English",
                        symbol: "textformat.abc"
                    )
                }

                Button(isEnglish ? "Continue" : "继续") {
                    model.completeLanguageOnboarding(language: selectedLanguage)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
            .frame(maxWidth: 620)
            .padding(.horizontal, 48)
            .padding(.vertical, 56)
        }
        .animation(.easeInOut(duration: 0.16), value: selectedLanguage)
    }

    private func languageOption(code: String, title: String, detail: String, symbol: String) -> some View {
        Button {
            selectedLanguage = code
        } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .medium))
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: title)
                        .font(GrokTypography.item(.semibold))
                    Text(verbatim: detail)
                        .font(GrokTypography.metadata)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
                Image(systemName: selectedLanguage == code ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(selectedLanguage == code ? Color.accentColor : Color.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
            .padding(.horizontal, 18)
            .background(Color.primary.opacity(selectedLanguage == code ? 0.075 : 0.035),
                        in: RoundedRectangle(cornerRadius: 13))
            .overlay {
                RoundedRectangle(cornerRadius: 13)
                    .stroke(selectedLanguage == code ? Color.accentColor : Color.primary.opacity(0.10),
                            lineWidth: selectedLanguage == code ? 1.5 : 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedLanguage == code ? .isSelected : [])
    }
}
