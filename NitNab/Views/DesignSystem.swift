import SwiftUI

// MARK: - Brand Design System

/// Single source of truth for NitNab's visual identity.
/// Derived from the app icon: white microphone on blue-to-indigo gradient.
/// See Brand/Brand_Guidelines.md for full specification.
enum Brand {

    // MARK: Colors (asset catalog references)

    /// Primary brand blue — #007AFF light, #0A84FF dark (system blue)
    static let primary = Color("NitNabBlue")

    /// Brand indigo for gradient end and pressed states — #5856D6 light, #5E5CE6 dark
    static let primaryDark = Color("NitNabBlueDark")

    /// Subtle brand blue background — ~5% blue on surface
    static let primaryLight = Color("NitNabBlueLight")

    /// Medium brand blue for tags and chips — ~20% blue on surface
    static let primaryMedium = Color("NitNabBlueMedium")

    /// Completed/success state — #30D158
    static let success = Color("NitNabSuccess")

    /// Failed/error state — #FF453A light, #FF6961 dark
    static let error = Color("NitNabError")

    /// Warning state — #FF9F0A light, #FFB340 dark
    static let warning = Color("NitNabWarning")

    /// Brand gradient matching the app icon — 135° blue (#007AFF) to indigo (#5856D6)
    static let gradient = LinearGradient(
        colors: [primary, primaryDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: Corner Radii (per Implementation Plan §5)

    enum Radius {
        /// Buttons, chips, small controls
        static let sm: CGFloat = 8
        /// Cards, list rows
        static let md: CGFloat = 12
        /// Panels, grouped containers
        static let lg: CGFloat = 16
        /// Modals, sheets
        static let xl: CGFloat = 22
        /// Pills, full-round buttons
        static let pill: CGFloat = 980
    }

    // MARK: Spacing (Apple 8pt grid, per Implementation Plan §4)

    enum Spacing {
        /// Icon-to-label inline gap
        static let xxs: CGFloat = 4
        /// Chip internal, tight groupings
        static let xs: CGFloat = 8
        /// Related element pairs
        static let sm: CGFloat = 12
        /// Standard content padding
        static let md: CGFloat = 16
        /// Card internal, form fields
        static let lg: CGFloat = 20
        /// Section separation
        static let xl: CGFloat = 24
        /// Group separation
        static let xxl: CGFloat = 32
        /// Major layout divisions
        static let xxxl: CGFloat = 40
        /// Hero/header regions
        static let xxxxl: CGFloat = 64
    }

    // MARK: Icon Sizes

    enum IconSize {
        /// Inline with body text
        static let inline: CGFloat = 16
        /// Action buttons
        static let button: CGFloat = 20
        /// Section headers
        static let section: CGFloat = 24
        /// Empty states, feature callouts
        static let feature: CGFloat = 48
        /// Onboarding, about screen, hero
        static let hero: CGFloat = 80
    }
}

// MARK: - Brand View Modifiers

extension View {

    /// Continuous superellipse corner clip (Tahoe style).
    func continuousRadius(_ r: CGFloat) -> some View {
        self.clipShape(.rect(cornerRadius: r, style: .continuous))
    }

    /// Glass material with continuous corners.
    func brandGlass(radius: CGFloat = Brand.Radius.lg) -> some View {
        self.glassEffect(
            .regular,
            in: .rect(cornerRadius: radius, style: .continuous)
        )
    }

    /// Card-style glass background with standard radius.
    func brandCard() -> some View {
        self.glassEffect(
            .regular,
            in: .rect(cornerRadius: Brand.Radius.md, style: .continuous)
        )
    }

    /// Tag/chip styling with brand colors and continuous corners.
    func brandTag(selected: Bool) -> some View {
        self
            .padding(.horizontal, 10)
            .padding(.vertical, Brand.Spacing.xxs)
            .background(selected ? Brand.primary : Brand.primaryMedium)
            .foregroundStyle(selected ? .white : Brand.primary)
            .continuousRadius(Brand.Radius.sm)
    }

    /// Status-dependent background color for file rows.
    func brandStatusBackground(_ status: String) -> some View {
        self.background(
            Group {
                switch status {
                case "completed":
                    Brand.success.opacity(0.08)
                case "failed":
                    Brand.error.opacity(0.08)
                case "processing":
                    Brand.primaryLight
                default:
                    Color.clear
                }
            }
        )
    }
}
