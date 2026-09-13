import SwiftUI

enum SlateTheme {
    static let mint = Color(red: 0.45, green: 0.95, blue: 0.66)
    static let deepMint = Color(red: 0.12, green: 0.55, blue: 0.35)
    static let graphite = Color(red: 0.07, green: 0.09, blue: 0.09)
    static let softGraphite = Color(red: 0.13, green: 0.16, blue: 0.16)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let background = Color(uiColor: .systemGroupedBackground)
}

enum AppearancePreference: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

struct SlateBackground: ViewModifier {
    func body(content: Content) -> some View {
        content.background(SlateTheme.background.ignoresSafeArea())
    }
}

extension View {
    func slateBackground() -> some View { modifier(SlateBackground()) }
}
