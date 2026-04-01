// DesignSystem.swift
// Principal Engineer: Rajesh Vallepalli — UI/UX Engineering Lead
// Deep Sea Productivity design language: tokens, reusable components, and theming.

import SwiftUI

// MARK: - Design Tokens

enum DesignTokens {

    // MARK: Colors — Deep Sea Palette

    enum Colors {
        // Backgrounds
        static let backgroundApp  = Color(red: 0.933, green: 0.941, blue: 0.953) // #EEF0F3 cool gray
        static let backgroundCard = Color.white
        static let backgroundNavy = Color(red: 0.055, green: 0.118, blue: 0.196) // #0E1E32 deep navy

        // Brand accent — deep blue
        static let accent      = Color(red: 0.157, green: 0.396, blue: 0.878)  // #2865E0
        static let accentLight = Color(red: 0.878, green: 0.918, blue: 1.000)  // #E0EAFF

        // Text
        static let textPrimary   = Color(red: 0.075, green: 0.122, blue: 0.196) // #132032
        static let textSecondary = Color(red: 0.431, green: 0.490, blue: 0.573) // #6E7D92
        static let textTertiary  = Color(red: 0.659, green: 0.706, blue: 0.769) // #A8B4C4
        static let textInverse   = Color.white

        // Semantic
        static let success     = Color(red: 0.133, green: 0.749, blue: 0.420) // #22BF6B
        static let destructive = Color(red: 0.937, green: 0.267, blue: 0.267) // #EF4444
        static let warning     = Color(red: 0.980, green: 0.596, blue: 0.094) // #FA9818

        // Surface layers
        static let surfacePrimary   = Color(.systemBackground)
        static let surfaceSecondary = Color(.secondarySystemBackground)

        // Priority — matching Stitch palette
        static let priorityUrgent = Color(red: 0.937, green: 0.267, blue: 0.267) // red
        static let priorityHigh   = Color(red: 0.980, green: 0.596, blue: 0.094) // orange
        static let priorityMedium = Color(red: 0.251, green: 0.749, blue: 0.424) // green
        static let priorityLow    = Color(red: 0.157, green: 0.396, blue: 0.878) // blue

        static func priorityColor(_ priority: Priority) -> Color {
            switch priority {
            case .low:    return priorityLow
            case .medium: return priorityMedium
            case .high:   return priorityHigh
            case .urgent: return priorityUrgent
            }
        }

        static func workspaceColor(_ workspace: TaskWorkspace) -> Color {
            switch workspace {
            case .inbox:    return accent
            case .work:     return Color(red: 0.412, green: 0.282, blue: 0.937) // indigo
            case .personal: return Color(red: 0.133, green: 0.749, blue: 0.420) // green
            }
        }

        static func fromHex(_ hex: String) -> Color {
            let sanitized = hex.trimmingCharacters(in: .init(charactersIn: "#"))
            guard sanitized.count == 6,
                  let value = UInt64(sanitized, radix: 16) else { return .gray }
            return Color(
                red:   Double((value >> 16) & 0xFF) / 255.0,
                green: Double((value >> 8)  & 0xFF) / 255.0,
                blue:  Double(value         & 0xFF) / 255.0
            )
        }
    }

    // MARK: Spacing

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 12
        static let lg:  CGFloat = 16
        static let xl:  CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    // MARK: Corner Radius

    enum Radius {
        static let sm:   CGFloat = 8
        static let md:   CGFloat = 12
        static let lg:   CGFloat = 16
        static let xl:   CGFloat = 20
        static let pill: CGFloat = 999
    }
}

// MARK: - App Header

struct DSAppHeader: View {
    let title: String
    var showSearch: Bool = false
    var onSearch: (() -> Void)? = nil

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("Deep Sea")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.accent)
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
            }

            Spacer()

            if showSearch, let onSearch {
                Button(action: onSearch) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .frame(width: 34, height: 34)
                        .background(DesignTokens.Colors.backgroundCard, in: Circle())
                        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
                }
                .accessibilityLabel("Search")
                .padding(.trailing, DesignTokens.Spacing.xs)
            }

            Circle()
                .fill(DesignTokens.Colors.backgroundNavy)
                .frame(width: 34, height: 34)
                .overlay(
                    Text("A")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DesignTokens.Colors.textInverse)
                )
                .accessibilityHidden(true)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.sm)
    }
}

// MARK: - DS Card Container

struct DSCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(DesignTokens.Colors.backgroundCard, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
            .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Stat Card

struct DSStatCard: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String
    var badge: String? = nil

    var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(iconColor)
                    Spacer()
                    if let badge {
                        Text(badge)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DesignTokens.Colors.success)
                            .padding(.horizontal, DesignTokens.Spacing.sm)
                            .padding(.vertical, 3)
                            .background(DesignTokens.Colors.success.opacity(0.12), in: Capsule())
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                    Text(label)
                        .font(.footnote)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
            }
            .padding(DesignTokens.Spacing.lg)
        }
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

// MARK: - Priority Badge

struct PriorityBadge: View {
    let priority: Priority

    var body: some View {
        Label(priority.label, systemImage: priority.iconName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(DesignTokens.Colors.priorityColor(priority))
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(DesignTokens.Colors.priorityColor(priority).opacity(0.12), in: Capsule())
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
            .background(DesignTokens.Colors.fromHex(tag.colorHex), in: Capsule())
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

// MARK: - Progress Ring

struct DSProgressRing: View {
    let progress: Double  // 0.0 – 1.0
    let size: CGFloat
    var lineWidth: CGFloat = 10
    var color: Color = DesignTokens.Colors.accent

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8, dampingFraction: 0.75), value: progress)
            Text("\(Int(progress * 100))%")
                .font(.system(size: size * 0.22, weight: .bold, design: .rounded))
                .foregroundStyle(color)
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
                .foregroundStyle(DesignTokens.Colors.accent.opacity(0.5))
                .padding(.bottom, DesignTokens.Spacing.sm)

            VStack(spacing: DesignTokens.Spacing.sm) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignTokens.Spacing.xxl)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Label(actionTitle, systemImage: "plus")
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(DesignTokens.Colors.accent)
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
                .font(.subheadline)
                .foregroundStyle(DesignTokens.Colors.textPrimary)
            Spacer()
            if let retryAction {
                Button("Retry", action: retryAction)
                    .font(.subheadline.weight(.semibold))
                    .tint(DesignTokens.Colors.accent)
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
            .foregroundStyle(DesignTokens.Colors.textTertiary)
            .kerning(0.5)
            .textCase(.uppercase)
            .accessibilityAddTraits(.isHeader)
    }

    func sectionHeader() -> some View {
        self
            .font(.footnote.weight(.semibold))
            .foregroundStyle(DesignTokens.Colors.textSecondary)
            .accessibilityAddTraits(.isHeader)
    }

    func cardStyle() -> some View {
        self
            .background(DesignTokens.Colors.backgroundCard, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
            .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Shimmer

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .white.opacity(0.4), .clear]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .offset(x: phase)
                .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: phase)
            )
            .clipped()
            .onAppear { phase = 300 }
    }
}

extension View {
    func shimmer() -> some View { modifier(ShimmerModifier()) }
}
