// SettingsFeature.swift
// Principal Engineer: Rajesh Vallepalli
// App settings: preferences, about, and workspace configuration.

import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    @AppStorage("userName") private var userName: String = "Alexander"
    @AppStorage("focusModeEnabled") private var focusModeEnabled: Bool = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @State private var showingNameEditor = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                DesignTokens.Colors.backgroundApp.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: DesignTokens.Spacing.lg) {

                        // Profile Card
                        profileCard
                            .padding(.top, DesignTokens.Spacing.sm)

                        // Preferences
                        settingsSection(title: "Preferences") {
                            SettingsToggleRow(
                                icon: "moon.fill",
                                iconColor: DesignTokens.Colors.accent,
                                label: "Focus Mode",
                                value: $focusModeEnabled
                            )
                            Divider().padding(.leading, 48)
                            SettingsToggleRow(
                                icon: "bell.fill",
                                iconColor: DesignTokens.Colors.warning,
                                label: "Notifications",
                                value: $notificationsEnabled
                            )
                        }

                        // Workspaces
                        settingsSection(title: "Workspaces") {
                            ForEach(Array(TaskWorkspace.allCases.enumerated()), id: \.element) { index, workspace in
                                if index > 0 { Divider().padding(.leading, 48) }
                                SettingsLinkRow(
                                    icon: workspace.icon,
                                    iconColor: DesignTokens.Colors.workspaceColor(workspace),
                                    label: workspace.rawValue,
                                    detail: "Configure"
                                )
                            }
                        }

                        // About
                        settingsSection(title: "About") {
                            SettingsInfoRow(label: "Version", value: "1.0.0")
                            Divider().padding(.leading, 48)
                            SettingsInfoRow(label: "Build", value: "Deep Sea Productivity")
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.bottom, DesignTokens.Spacing.xxxl)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    DSAppHeader(title: "Productivity")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .sheet(isPresented: $showingNameEditor) {
            nameEditorSheet
        }
    }

    // MARK: - Profile Card

    private var profileCard: some View {
        DSCard {
            HStack(spacing: DesignTokens.Spacing.lg) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [DesignTokens.Colors.accent, DesignTokens.Colors.backgroundNavy],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .overlay(
                        Text(String(userName.prefix(1)).uppercased())
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(userName)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                    Text("Deep Sea Member")
                        .font(.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }

                Spacer()

                Button {
                    showingNameEditor = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DesignTokens.Colors.accent)
                        .frame(width: 32, height: 32)
                        .background(DesignTokens.Colors.accentLight, in: Circle())
                }
                .accessibilityLabel("Edit name")
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Profile: \(userName)")
    }

    // MARK: - Section Builder

    private func settingsSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(title)
                .sectionLabel()
                .padding(.leading, DesignTokens.Spacing.xs)

            DSCard {
                VStack(spacing: 0) {
                    content()
                }
                .padding(.vertical, DesignTokens.Spacing.xs)
            }
        }
    }

    // MARK: - Name Editor Sheet

    private var nameEditorSheet: some View {
        NavigationStack {
            Form {
                Section("Your Name") {
                    TextField("Name", text: $userName)
                }
            }
            .navigationTitle("Edit Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingNameEditor = false }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Settings Row Components

private struct SettingsToggleRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    @Binding var value: Bool

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)
                .background(iconColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))

            Text(label)
                .font(.subheadline)
                .foregroundStyle(DesignTokens.Colors.textPrimary)

            Spacer()

            Toggle("", isOn: $value)
                .labelsHidden()
                .tint(DesignTokens.Colors.accent)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
    }
}

private struct SettingsLinkRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    var detail: String? = nil

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)
                .background(iconColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))

            Text(label)
                .font(.subheadline)
                .foregroundStyle(DesignTokens.Colors.textPrimary)

            Spacer()

            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DesignTokens.Colors.textTertiary)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
        .contentShape(Rectangle())
    }
}

private struct SettingsInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .padding(.leading, 48)

            Spacer()

            Text(value)
                .font(.subheadline)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
    }
}
