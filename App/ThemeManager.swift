import SwiftUI
import Combine

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "system"
    case light  = "light"
    case dark   = "dark"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "gear"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }
}

@MainActor
final class ThemeManager: ObservableObject {
    private static let storageKey = "appTheme"

    @Published var selectedTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: Self.storageKey)
        }
    }

    /// Returns the `ColorScheme` to pass to `.preferredColorScheme()`.
    /// `nil` means "follow the system setting".
    var colorScheme: ColorScheme? {
        switch selectedTheme {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: Self.storageKey) ?? AppTheme.dark.rawValue
        self.selectedTheme = AppTheme(rawValue: raw) ?? .dark
    }
}
