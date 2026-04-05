// DesignSystem.swift
// Design tokens extracted from Stitch HTML/CSS — Deep Sea Productivity design language.
// All hex values are exact matches from the Stitch color system.

import SwiftUI

// MARK: - Design Tokens

enum DesignTokens {

    // MARK: Colors — exact Stitch palette

    enum Colors {
        // Primary surfaces
        static let background          = Color(hex: "#f7f9fc") // surface / background
        static let surfaceLowest       = Color(hex: "#ffffff") // surface-container-lowest
        static let surfaceLow          = Color(hex: "#f2f4f7") // surface-container-low
        static let surface             = Color(hex: "#eceef1") // surface-container
        static let surfaceHigh         = Color(hex: "#e6e8eb") // surface-container-high
        static let surfaceHighest      = Color(hex: "#e0e3e6") // surface-container-highest
        static let surfaceDim          = Color(hex: "#d8dadd") // surface-dim

        // Primary brand — deep navy/teal
        static let primary             = Color(hex: "#00334d") // primary
        static let primaryContainer    = Color(hex: "#004b6e") // primary-container
        static let primaryFixed        = Color(hex: "#c9e6ff") // primary-fixed
        static let primaryFixedDim     = Color(hex: "#97cdf6") // primary-fixed-dim
        static let onPrimary              = Color(hex: "#ffffff") // on-primary
        static let onPrimaryFixed         = Color(hex: "#001e2f") // on-primary-fixed
        static let onPrimaryFixedVariant  = Color(hex: "#014b6e") // on-primary-fixed-variant
        static let onPrimaryContainer     = Color(hex: "#85bae3") // on-primary-container
        static let inversePrimary         = Color(hex: "#97cdf6") // inverse-primary

        // Secondary
        static let secondary           = Color(hex: "#53606b") // secondary
        static let secondaryContainer  = Color(hex: "#d4e1ee") // secondary-container
        static let secondaryFixed      = Color(hex: "#d7e4f1") // secondary-fixed
        static let secondaryFixedDim   = Color(hex: "#bbc8d5") // secondary-fixed-dim
        static let onSecondary         = Color(hex: "#ffffff")
        static let onSecondaryContainer = Color(hex: "#57646f") // on-secondary-container
        static let onSecondaryFixed    = Color(hex: "#101d26")
        static let onSecondaryFixedVariant = Color(hex: "#3b4853")

        // Tertiary (warm accent — deep red/coral)
        static let tertiary            = Color(hex: "#601200") // tertiary
        static let tertiaryContainer   = Color(hex: "#852205") // tertiary-container
        static let tertiaryFixed       = Color(hex: "#ffdbd2") // tertiary-fixed
        static let tertiaryFixedDim    = Color(hex: "#ffb4a1") // tertiary-fixed-dim
        static let onTertiary          = Color(hex: "#ffffff")
        static let onTertiaryContainer = Color(hex: "#ff9a7f") // on-tertiary-container
        static let onTertiaryFixed     = Color(hex: "#3c0800")
        static let onTertiaryFixedVariant = Color(hex: "#862206")

        // On-surface text
        static let onSurface           = Color(hex: "#191c1e") // on-surface
        static let onBackground        = Color(hex: "#191c1e") // on-background
        static let onSurfaceVariant    = Color(hex: "#41484e") // on-surface-variant

        // Outline
        static let outline             = Color(hex: "#71787f") // outline
        static let outlineVariant      = Color(hex: "#c1c7cf") // outline-variant

        // Inverse
        static let inverseSurface      = Color(hex: "#2d3133") // inverse-surface
        static let inverseOnSurface    = Color(hex: "#eff1f4") // inverse-on-surface

        // Error
        static let error               = Color(hex: "#ba1a1a")
        static let errorContainer      = Color(hex: "#ffdad6")
        static let onError             = Color(hex: "#ffffff")
        static let onErrorContainer    = Color(hex: "#93000a")

        // Convenience aliases used in components
        static let accent              = primary             // primary is the main accent
        static let accentContainer     = primaryContainer
        static let accentFixed         = primaryFixed
        static let textPrimary         = onSurface
        static let textSecondary       = onSurfaceVariant
        static let textTertiary        = outline
        static let textInverse         = Color.white
        static let backgroundCard      = surfaceLowest
        static let backgroundApp       = background
        static let backgroundNavy      = primary

        // Semantic
        static let success             = Color(hex: "#22BF6B")
        static let destructive         = error
        static let warning             = Color(hex: "#FA9818")

        // Priority — Stitch-matched
        static let priorityHigh   = tertiaryContainer   // #852205 — used in Stitch High badges
        static let priorityMedium = secondaryContainer  // #d4e1ee — Medium
        static let priorityLow    = primaryFixed        // #c9e6ff — Low
        static let priorityUrgent = error               // #ba1a1a — Urgent

        static func priorityColor(_ priority: Priority) -> Color {
            switch priority {
            case .low:    return primaryFixed
            case .medium: return secondaryContainer
            case .high:   return tertiaryContainer
            case .urgent: return error
            }
        }

        static func priorityBadgeText(_ priority: Priority) -> Color {
            switch priority {
            case .low:    return onPrimaryFixed
            case .medium: return onSecondaryFixedVariant
            case .high:   return tertiaryFixed
            case .urgent: return onError
            }
        }

        static func workspaceColor(_ workspace: TaskWorkspace) -> Color {
            switch workspace {
            case .inbox:    return primary
            case .work:     return Color(hex: "#6631b0")
            case .personal: return success
            }
        }

        static func fromHex(_ hex: String) -> Color { Color(hex: hex) }
    }

    // MARK: Spacing

    enum Spacing {
        static let xxs:  CGFloat = 2
        static let xs:   CGFloat = 4
        static let sm:   CGFloat = 8
        static let md:   CGFloat = 12
        static let lg:   CGFloat = 16
        static let xl:   CGFloat = 24
        static let xxl:  CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    // MARK: Corner Radius — Stitch values

    enum Radius {
        static let sm:    CGFloat = 8
        static let md:    CGFloat = 12
        static let lg:    CGFloat = 16
        static let xl:    CGFloat = 20
        static let xxl:   CGFloat = 24
        static let xxxl:  CGFloat = 32   // the signature "2rem" Stitch card radius
        static let pill:  CGFloat = 999
    }
}

// MARK: - Color Hex Init

extension Color {
    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        guard sanitized.count == 6,
              let value = UInt64(sanitized, radix: 16) else {
            self = .gray
            return
        }
        self.init(
            red:   Double((value >> 16) & 0xFF) / 255.0,
            green: Double((value >> 8)  & 0xFF) / 255.0,
            blue:  Double(value         & 0xFF) / 255.0
        )
    }
}

// MARK: - Typography helpers

extension Font {
    /// Headline style: Manrope feel — system rounded is the closest native match.
    static func headline(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    /// Body style: Inter feel — system default.
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    static func label(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight)
    }
}

// MARK: - Gradient helpers

extension LinearGradient {
    static var deepSeaPrimary: LinearGradient {
        LinearGradient(
            colors: [DesignTokens.Colors.primary, DesignTokens.Colors.primaryContainer],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - DS App Header

struct DSAppHeader: View {
    let title: String
    var showSearch: Bool = false
    var onSearch: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Circle()
                .fill(DesignTokens.Colors.surfaceHigh)
                .frame(width: 38, height: 38)
                .overlay(
                    Text("A")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(DesignTokens.Colors.primary)
                )
                .accessibilityHidden(true)

            Text(title)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(DesignTokens.Colors.primaryContainer)

            Spacer()

            if showSearch, let onSearch {
                Button(action: onSearch) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .frame(width: 38, height: 38)
                        .background(DesignTokens.Colors.surfaceHighest, in: Circle())
                }
                .accessibilityLabel("Search")
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.sm)
    }
}

// MARK: - DS Card Container

struct DSCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = DesignTokens.Radius.xl

    init(cornerRadius: CGFloat = DesignTokens.Radius.xl, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .background(DesignTokens.Colors.backgroundCard, in: RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: Color(hex: "#00334d").opacity(0.06), radius: 16, x: 0, y: 4)
    }
}

// MARK: - DS Stat Card

struct DSStatCard: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String
    var badge: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(iconColor)
                Spacer()
                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DesignTokens.Colors.success)
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.vertical, 3)
                        .background(DesignTokens.Colors.success.opacity(0.12), in: Capsule())
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.Colors.backgroundCard, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.xl))
        .shadow(color: Color(hex: "#00334d").opacity(0.04), radius: 12, x: 0, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Priority Dot

struct DSPriorityDot: View {
    let priority: Priority
    var size: CGFloat = 10

    var body: some View {
        Circle()
            .fill(DesignTokens.Colors.priorityColor(priority))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

// MARK: - Priority Badge (Stitch pill style)

struct PriorityBadge: View {
    let priority: Priority

    var body: some View {
        Text(priority.label.uppercased())
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(DesignTokens.Colors.priorityBadgeText(priority))
            .kerning(0.8)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(DesignTokens.Colors.priorityColor(priority), in: Capsule())
            .accessibilityLabel("\(priority.label) priority")
    }
}

// MARK: - Tag Chip

struct TagChip: View {
    let tag: Tag

    var body: some View {
        Text(tag.name)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, 3)
            .background(Color(hex: tag.colorHex), in: Capsule())
            .accessibilityLabel("Tag: \(tag.name)")
    }
}

// MARK: - Workspace Badge

struct DSWorkspaceBadge: View {
    let workspace: TaskWorkspace

    var body: some View {
        Text(workspace.rawValue)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(DesignTokens.Colors.workspaceColor(workspace))
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, 3)
            .background(DesignTokens.Colors.workspaceColor(workspace).opacity(0.12), in: Capsule())
    }
}

// MARK: - Progress Ring (Stitch-style SVG arc)

struct DSProgressRing: View {
    let progress: Double  // 0.0 – 1.0
    let size: CGFloat
    var lineWidth: CGFloat = 10
    var color: Color = DesignTokens.Colors.primary

    var body: some View {
        ZStack {
            Circle()
                .stroke(DesignTokens.Colors.surfaceHighest, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient.deepSeaPrimary,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8, dampingFraction: 0.75), value: progress)
            VStack(spacing: 1) {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: size * 0.24, weight: .bold, design: .rounded))
                    .foregroundStyle(DesignTokens.Colors.primary)
                Text("COMPLETE")
                    .font(.system(size: size * 0.085, weight: .medium))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .kerning(-0.3)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("\(Int(progress * 100)) percent complete")
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(DesignTokens.Colors.primaryFixed)
                .padding(.bottom, DesignTokens.Spacing.sm)

            VStack(spacing: DesignTokens.Spacing.sm) {
                Text(title)
                    .font(.headline(22))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                Text(subtitle)
                    .font(.body(15))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignTokens.Spacing.xxl)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Label(actionTitle, systemImage: "plus")
                        .font(.body(15, weight: .semibold))
                        .foregroundStyle(DesignTokens.Colors.onPrimary)
                        .padding(.horizontal, DesignTokens.Spacing.xl)
                        .padding(.vertical, DesignTokens.Spacing.md)
                        .background(LinearGradient.deepSeaPrimary, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.xl))
                }
                .padding(.top, DesignTokens.Spacing.md)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Error Banner

struct ErrorBanner: View {
    let error: AppError
    var retryAction: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DesignTokens.Colors.warning)
            Text(error.localizedDescription)
                .font(.body(14))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
            Spacer()
            if let retryAction {
                Button("Retry", action: retryAction)
                    .font(.body(14, weight: .semibold))
                    .foregroundStyle(DesignTokens.Colors.primary)
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Colors.warning.opacity(0.1), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(error.localizedDescription)")
    }
}

// MARK: - View Modifiers

extension View {
    func sectionLabel() -> some View {
        self
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(DesignTokens.Colors.textSecondary)
            .kerning(1.2)
            .textCase(.uppercase)
            .accessibilityAddTraits(.isHeader)
    }

    func sectionHeader() -> some View {
        self
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(DesignTokens.Colors.textSecondary)
            .accessibilityAddTraits(.isHeader)
    }

    func cardStyle() -> some View {
        self
            .background(DesignTokens.Colors.backgroundCard, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.xl))
            .shadow(color: Color(hex: "#00334d").opacity(0.06), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Shimmer Loading Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -300

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .white.opacity(0.4), .clear]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .offset(x: phase)
                .animation(.linear(duration: 1.4).repeatForever(autoreverses: false), value: phase)
            )
            .clipped()
            .onAppear { phase = 300 }
    }
}

extension View {
    func shimmer() -> some View { modifier(ShimmerModifier()) }
}
