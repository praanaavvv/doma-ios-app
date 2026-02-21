import SwiftUI

struct AppearanceSettingsView: View {
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // Theme preview cards
                HStack(spacing: 12) {
                    ForEach(AppTheme.allCases) { theme in
                        ThemeCard(
                            theme: theme,
                            isSelected: themeManager.selectedTheme == theme
                        ) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                themeManager.selectedTheme = theme
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // Info text
                Text("Choose how DomaSecure looks. Selecting **System** will automatically match your device's appearance.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.bottom, 40)
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Theme Card

private struct ThemeCard: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                // Mini preview
                RoundedRectangle(cornerRadius: 12)
                    .fill(previewBackground)
                    .frame(height: 80)
                    .overlay(
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(previewForeground.opacity(0.15))
                                .frame(height: 10)
                                .padding(.horizontal, 10)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(previewForeground.opacity(0.10))
                                .frame(height: 10)
                                .padding(.horizontal, 10)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(previewForeground.opacity(0.07))
                                .frame(height: 10)
                                .padding(.horizontal, 10)
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2.5)
                    )

                // Label + icon
                HStack(spacing: 4) {
                    Image(systemName: theme.icon)
                        .font(.system(size: 12, weight: .semibold))
                    Text(theme.label)
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(isSelected ? .blue : .secondary)

                // Selection indicator
                Circle()
                    .fill(isSelected ? Color.blue : Color.clear)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.blue : Color(.systemGray3), lineWidth: 1.5)
                    )
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private var previewBackground: Color {
        switch theme {
        case .light:  return Color(.systemGray6)
        case .dark:   return Color(.darkGray)
        case .system: return Color(.systemGray5)
        }
    }

    private var previewForeground: Color {
        switch theme {
        case .light:  return .black
        case .dark:   return .white
        case .system: return .primary
        }
    }
}
