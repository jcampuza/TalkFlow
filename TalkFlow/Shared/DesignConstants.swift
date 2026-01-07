import SwiftUI

/// Design constants for consistent light-theme styling across the app.
/// IMPORTANT: Always use these constants instead of system-adaptive colors like
/// `.primary`, `.secondary`, `NSColor.controlBackgroundColor`, etc.
/// This ensures the UI looks correct regardless of system dark/light mode.
enum DesignConstants {
    // MARK: - Background Colors (explicit light theme - don't adapt to dark mode)

    /// Main sidebar background color
    static let sidebarBackground = Color(red: 0.96, green: 0.96, blue: 0.96)

    /// Content area background (slightly lighter than sidebar)
    static let contentBackground = Color(red: 0.98, green: 0.98, blue: 0.98)

    /// Background for selected sidebar items
    static let selectedItemBackground = Color(red: 0.90, green: 0.90, blue: 0.90)

    /// Divider/separator lines
    static let dividerColor = Color(red: 0.88, green: 0.88, blue: 0.88)

    /// Quick-start tip card background (warm cream)
    static let tipCardBackground = Color(red: 1.0, green: 0.98, blue: 0.92)

    /// Quick-start tip card border
    static let tipCardBorder = Color(red: 0.95, green: 0.90, blue: 0.75)

    /// Search bar and input field backgrounds
    static let searchBarBackground = Color(red: 0.94, green: 0.94, blue: 0.94)

    /// Keyboard shortcut key cap background
    static let keyCapBackground = Color(red: 0.95, green: 0.95, blue: 0.95)

    /// Hover state background
    static let hoverBackground = Color(red: 0.96, green: 0.96, blue: 0.96)

    /// Settings section/card background
    static let settingsSectionBackground = Color(red: 0.97, green: 0.97, blue: 0.97)

    // MARK: - Text Colors (explicit light theme)

    /// Primary text color (near-black)
    static let primaryText = Color(red: 0.1, green: 0.1, blue: 0.1)

    /// Secondary/muted text color (medium gray)
    static let secondaryText = Color(red: 0.45, green: 0.45, blue: 0.45)

    /// Tertiary/disabled text color (light gray)
    static let tertiaryText = Color(red: 0.70, green: 0.70, blue: 0.70)

    // MARK: - Accent Colors

    /// Brand accent color (#5635c0 - purple from app icon)
    static let accentColor = Color(red: 86/255, green: 53/255, blue: 192/255)

    /// Blue accent for interactive elements (legacy, prefer accentColor)
    static let accentBlue = Color.blue

    // MARK: - Sizing

    /// Width of the main sidebar
    static let sidebarWidth: CGFloat = 200

    /// Corner radius for content area inset
    static let contentCornerRadius: CGFloat = 6

    /// Corner radius for interactive items (buttons, tabs)
    static let itemCornerRadius: CGFloat = 8

    /// Size for sidebar icons
    static let iconSize: CGFloat = 18

    /// Height of sidebar navigation items
    static let sidebarItemHeight: CGFloat = 36

    /// Horizontal padding within sidebar
    static let sidebarPadding: CGFloat = 12
}
