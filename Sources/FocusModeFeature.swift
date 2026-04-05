// FocusModeFeature.swift
// Principal Engineer: Rajesh Vallepalli
// Focus Mode: circular timer, session depth selector, ocean ambience selector.
// Design: matches Stitch focus_mode/code.html exactly.

import SwiftUI

// MARK: - Focus Session Duration

enum FocusDepth: Int, CaseIterable, Identifiable {
    case reef     = 15
    case lagoon   = 25
    case abyss    = 45
    case trenches = 60

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .reef:     return "Reef"
        case .lagoon:   return "Lagoon"
        case .abyss:    return "Abyss"
        case .trenches: return "Trenches"
        }
    }
}

// MARK: - Ocean Ambience

struct OceanAmbience: Identifiable, Equatable {
    let id: Int
    let name: String
    let subtitle: String
    let icon: String

    static let all: [OceanAmbience] = [
        OceanAmbience(id: 0, name: "Gentle Currents",  subtitle: "Soft rhythmic flows",        icon: "drop"),
        OceanAmbience(id: 1, name: "Whale Songs",       subtitle: "Distant haunting melodies",  icon: "waveform"),
        OceanAmbience(id: 2, name: "Ocean Thunder",     subtitle: "Deep rolling waves",          icon: "cloud.bolt"),
        OceanAmbience(id: 3, name: "Coral Silence",    subtitle: "Still, undisturbed depths",   icon: "waveform.path"),
    ]
}

// MARK: - Focus Mode ViewModel

@MainActor
final class FocusModeViewModel: ObservableObject {
    @Published private(set) var isRunning:      Bool          = false
    @Published private(set) var timeRemaining:  Int           = 25 * 60   // seconds
    @Published var selectedDepth:  FocusDepth  = .lagoon
    @Published var selectedAmbience: OceanAmbience = OceanAmbience.all[0]
    @Published private(set) var currentStreak:  Int           = 4

    private var timer: Task<Void, Never>?

    var totalSeconds: Int { selectedDepth.rawValue * 60 }

    var progressFraction: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1.0 - (Double(timeRemaining) / Double(totalSeconds))
    }

    var timerDisplay: String {
        let m = timeRemaining / 60
        let s = timeRemaining % 60
        return String(format: "%02d:%02d", m, s)
    }

    deinit {
        timer?.cancel()
        #if DEBUG
        print("FocusModeViewModel deinitialized")
        #endif
    }

    func selectDepth(_ depth: FocusDepth) {
        guard !isRunning else { return }
        selectedDepth = depth
        timeRemaining = depth.rawValue * 60
    }

    func startOrPause() {
        if isRunning {
            timer?.cancel()
            timer = nil
            isRunning = false
        } else {
            isRunning = true
            timer = Task { [weak self] in
                while true {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        guard let self else { return }
                        if self.timeRemaining > 0 {
                            self.timeRemaining -= 1
                        } else {
                            self.timer?.cancel()
                            self.timer = nil
                            self.isRunning = false
                        }
                    }
                }
            }
        }
    }

    func reset() {
        timer?.cancel()
        timer = nil
        isRunning = false
        timeRemaining = selectedDepth.rawValue * 60
    }
}

// MARK: - Focus Mode View (Stitch design)

struct FocusModeView: View {
    @ObservedObject var viewModel: FocusModeViewModel

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                DesignTokens.Colors.backgroundApp.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: DesignTokens.Spacing.xl) {

                        // Immersive timer section
                        timerSection
                            .padding(.top, DesignTokens.Spacing.sm)

                        // Session depth selector
                        depthSelectorCard

                        // Ocean ambience
                        ambienceCard

                        // Stats row
                        statsRow
                    }
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.bottom, 100)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    DSAppHeader(title: "Deep Sea Productivity", showSearch: false)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Timer Section

    private var timerSection: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            // Circular timer
            ZStack {
                // Wave decoration
                ZStack {
                    Circle()
                        .fill(DesignTokens.Colors.primaryContainer.opacity(0.04))
                        .frame(width: 320, height: 320)
                    Circle()
                        .fill(DesignTokens.Colors.primaryContainer.opacity(0.06))
                        .frame(width: 260, height: 260)
                }

                // Progress ring
                ZStack {
                    Circle()
                        .stroke(DesignTokens.Colors.surfaceHighest, lineWidth: 10)
                        .frame(width: 220, height: 220)

                    Circle()
                        .trim(from: 0, to: viewModel.progressFraction)
                        .stroke(
                            LinearGradient.deepSeaPrimary,
                            style: StrokeStyle(lineWidth: 14, lineCap: .round)
                        )
                        .frame(width: 220, height: 220)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: viewModel.progressFraction)

                    VStack(spacing: DesignTokens.Spacing.xs) {
                        Text(viewModel.timerDisplay)
                            .font(.system(size: 60, weight: .bold, design: .rounded))
                            .foregroundStyle(DesignTokens.Colors.primary)
                            .monospacedDigit()
                        Text("Deep Focus")
                            .font(.label(12, weight: .semibold))
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .kerning(1.5)
                            .textCase(.uppercase)
                    }
                }
            }
            .frame(height: 240)
            .accessibilityLabel("Timer: \(viewModel.timerDisplay) remaining")

            // Controls
            HStack(spacing: DesignTokens.Spacing.md) {
                // Primary: Deep Dive / Resurface
                Button(action: { viewModel.startOrPause() }) {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text(viewModel.isRunning ? "Resurface" : "Deep Dive")
                            .font(.headline(17))
                    }
                    .foregroundStyle(DesignTokens.Colors.onPrimary)
                    .padding(.horizontal, DesignTokens.Spacing.xxl)
                    .padding(.vertical, DesignTokens.Spacing.lg)
                    .background(LinearGradient.deepSeaPrimary, in: Capsule())
                    .shadow(color: DesignTokens.Colors.primary.opacity(0.25), radius: 16, x: 0, y: 8)
                }
                .accessibilityLabel(viewModel.isRunning ? "Pause focus session" : "Start focus session")

                // Secondary: Reset
                Button(action: { viewModel.reset() }) {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Reset")
                            .font(.headline(17))
                    }
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .padding(.horizontal, DesignTokens.Spacing.xl)
                    .padding(.vertical, DesignTokens.Spacing.lg)
                    .background(DesignTokens.Colors.surfaceHighest, in: Capsule())
                }
                .accessibilityLabel("Reset timer")
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(DesignTokens.Colors.surfaceLow, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.xxxl))
        .overlay(
            // Subtle wave SVG-like gradient at bottom
            LinearGradient(
                colors: [DesignTokens.Colors.primaryContainer.opacity(0.06), .clear],
                startPoint: .bottom,
                endPoint: .top
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.xxxl))
        )
    }

    // MARK: - Depth Selector Card

    private var depthSelectorCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            HStack {
                Text("Session Depth")
                    .font(.headline(18))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                Spacer()
                Text("MINUTES")
                    .font(.label(10, weight: .bold))
                    .foregroundStyle(DesignTokens.Colors.primary)
                    .kerning(0.8)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(DesignTokens.Colors.primaryFixed, in: Capsule())
            }

            HStack(spacing: DesignTokens.Spacing.md) {
                ForEach(FocusDepth.allCases) { depth in
                    DepthButton(
                        depth: depth,
                        isSelected: viewModel.selectedDepth == depth,
                        onSelect: { viewModel.selectDepth(depth) }
                    )
                }
            }
        }
        .padding(DesignTokens.Spacing.xl)
        .background(DesignTokens.Colors.surfaceLow, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.xxxl))
    }

    // MARK: - Ambience Card

    private var ambienceCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            Text("Ocean Ambience")
                .font(.headline(18))
                .foregroundStyle(DesignTokens.Colors.textPrimary)

            VStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(OceanAmbience.all) { ambience in
                    AmbienceRow(
                        ambience: ambience,
                        isSelected: viewModel.selectedAmbience == ambience,
                        onSelect: { viewModel.selectedAmbience = ambience }
                    )
                }
            }
        }
        .padding(DesignTokens.Spacing.xl)
        .background(DesignTokens.Colors.surfaceLow, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.xxxl))
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // Streak tile
            HStack(spacing: DesignTokens.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(DesignTokens.Colors.tertiaryContainer.opacity(0.1))
                        .frame(width: 52, height: 52)
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(DesignTokens.Colors.tertiary)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Current Streak")
                        .font(.headline(14))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                    Text("You've reached focus depth \(viewModel.currentStreak) days in a row.")
                        .font(.body(12))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(DesignTokens.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignTokens.Colors.backgroundCard, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl))
            .shadow(color: Color(hex: "#00334d").opacity(0.04), radius: 8, x: 0, y: 2)

            // Pro tip tile
            HStack(spacing: DesignTokens.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(DesignTokens.Colors.primaryFixed)
                        .frame(width: 52, height: 52)
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(DesignTokens.Colors.onPrimaryFixedVariant)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Pro Tip")
                        .font(.headline(14))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                    Text("Mute notifications to avoid surfacing too early.")
                        .font(.body(12))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(DesignTokens.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignTokens.Colors.backgroundCard, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl))
            .shadow(color: Color(hex: "#00334d").opacity(0.04), radius: 8, x: 0, y: 2)
        }
    }
}

// MARK: - Depth Button

private struct DepthButton: View {
    let depth: FocusDepth
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: DesignTokens.Spacing.xs) {
                Text("\(depth.rawValue)")
                    .font(.headline(22))
                    .foregroundStyle(isSelected ? DesignTokens.Colors.onPrimary : DesignTokens.Colors.primary)
                Text(depth.label)
                    .font(.label(11, weight: .medium))
                    .foregroundStyle(isSelected ? DesignTokens.Colors.onPrimary.opacity(0.8) : DesignTokens.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.Spacing.lg)
            .background(
                isSelected
                    ? AnyShapeStyle(LinearGradient.deepSeaPrimary)
                    : AnyShapeStyle(DesignTokens.Colors.backgroundCard),
                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.xl)
            )
            .shadow(
                color: isSelected ? DesignTokens.Colors.primary.opacity(0.3) : Color(hex: "#00334d").opacity(0.04),
                radius: isSelected ? 12 : 4,
                x: 0, y: isSelected ? 6 : 2
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(depth.rawValue) minute \(depth.label) session")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Ambience Row

private struct AmbienceRow: View {
    let ambience: OceanAmbience
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DesignTokens.Spacing.md) {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                    .fill(isSelected ? DesignTokens.Colors.secondaryContainer : DesignTokens.Colors.surfaceHighest)
                    .frame(width: 46, height: 46)
                    .overlay(
                        Image(systemName: ambience.icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(
                                isSelected ? DesignTokens.Colors.onSecondaryContainer : DesignTokens.Colors.textSecondary
                            )
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(ambience.name)
                        .font(.headline(15))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                    Text(ambience.subtitle)
                        .font(.body(12))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "play.circle")
                    .font(.system(size: 22))
                    .foregroundStyle(
                        isSelected ? DesignTokens.Colors.primary : DesignTokens.Colors.outlineVariant
                    )
            }
            .padding(DesignTokens.Spacing.md)
            .background(
                isSelected ? DesignTokens.Colors.primaryFixed.opacity(0.15) : Color.clear,
                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.xl)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(ambience.name)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
