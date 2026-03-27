// DesignSystem.swift
// Principal Engineer: Rajesh Vallepalli — UI/UX Engineering Lead
// Design tokens, reusable components, and theming.
// Every color, spacing, and typography value flows from here.

import SwiftUI

// MARK: - Design Tokens

enum DesignTokens {

    // MARK: Colors

    enum Colors {
        static let accent = Color("AccentBlue", bundle: nil)
            // Fallback for when asset catalog isn't set up:
            ?? Color(red: 0.35, green: 0.34, blue: 0.84)

        static let destructive = Color.red
        static let success = Color.green
        static let warning = Color.orange

        static let surfacePrimary = Color(.systemBackground)
        static let surfaceSecondary = Color(.secondarySystemBackground)
        static let surfaceTertiary = Color(.tertiarySystemBackground)

        static let textPrimary = Color(.label)
        static let textSecondary = Color(.secondaryLabel)
        static let textTertiary = Color(.tertiaryLabel)

        static func priorityColor(_ priority: Priority) -> Color {
            switch priority {
            case .low:    return .gray
            case .medium: return .blue
            case .high:   return .orange
            case .urgent: return .red
            }
        }

        static func fromHex(_ hex: String) -> Color {
            let sanitized = hex.trimmingCharacters(in: .init(charactersIn: "#"))
            guard sanitized.count == 6,
                  let value = UInt64(sanitized, radix: 16) else {
                return .gray
            }
            return Color(
                red: Double((value >> 16) & 0xFF) / 255.0,
                green: Double((value >> 8) & 0xFF) / 255.0,
                blue: Double(value & 0xFF) / 255.0
            )
        }
    }

    // MARK: Spacing

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    // MARK: Corner Radius

    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 16
        static let pill: CGFloat = 999
    }
}

// MARK: - Reusable Components

struct PriorityBadge: View {
    let priority: Priority

    var body: some View {
        Label(priority.label, systemImage: priority.iconName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(DesignTokens.Colors.priorityColor(priority))
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(
                DesignTokens.Colors.priorityColor(priority).opacity(0.12),
                in: Capsule()
            )
            .accessibilityLabel("\(priority.label) priority")
    }
}

struct TagChip: View {
    let tag: Tag

    var body: some View {
        Text(tag.name)
            .font(.caption)
            .foregroundStyle(.white)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(
                DesignTokens.Colors.fromHex(tag.colorHex),
                in: Capsule()
            )
            .accessibilityLabel("Tag: \(tag.name)")
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        #if compiler(>=5.9)
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            Text(subtitle)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
            }
        }
        #else
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(DesignTokens.Colors.textTertiary)
                .padding(.bottom, DesignTokens.Spacing.sm)
            
            Text(title)
                .font(.headline)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.xl)
            
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .padding(.top, DesignTokens.Spacing.md)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
    }
}

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
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(
            DesignTokens.Colors.warning.opacity(0.1),
            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
        )
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(error.localizedDescription)")
    }
}

// MARK: - View Modifiers

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(DesignTokens.Spacing.lg)
            .background(
                DesignTokens.Colors.surfaceSecondary,
                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
            )
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }

    func sectionHeader() -> some View {
        self
            .font(.headline.weight(.bold))
            .foregroundStyle(DesignTokens.Colors.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Shimmer Loading Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        .clear,
                        .white.opacity(0.4),
                        .clear
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .offset(x: phase)
                .animation(
                    .linear(duration: 1.5).repeatForever(autoreverses: false),
                    value: phase
                )
            )
            .clipped()
            .onAppear { phase = 300 }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}
