// SettingsFeature.swift
// Principal Engineer: Rajesh Vallepalli
// App settings: profile, preferences, workspaces, and about.
// Design: Stitch design tokens applied throughout.

import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    @AppStorage("userName")              private var userName:              String = "Alexander"
    @AppStorage("focusModeEnabled")      private var focusModeEnabled:      Bool   = false
    @AppStorage("notificationsEnabled")  private var notificationsEnabled:  Bool   = true
    @State private var showingNameEditor = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                DesignTokens.Colors.backgroundApp.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: DesignTokens.Spacing.lg) {
                        profileCard
                            .padding(.top, DesignTokens.Spacing.sm)

                        settingsSection(title: "PREFERENCES") {
                            SettingsToggleRow(
                                icon: "moon.fill",
                                iconColor: DesignTokens.Colors.primary,
                                label: "Focus Mode",
                                value: $focusModeEnabled
                            )
                            Divider().padding(.leading, 56)
                            SettingsToggleRow(
                                icon: "bell.fill",
                                iconColor: DesignTokens.Colors.warning,
                                label: "Notifications",
                                value: $notificationsEnabled
                            )
                        }

                        settingsSection(title: "WORKSPACES") {
                            ForEach(Array(TaskWorkspace.allCases.enumerated()), id: \.element) { index, workspace in
                                if index > 0 { Divider().padding(.leading, 56) }
                                SettingsLinkRow(
                                    icon: workspace.icon,
                                    iconColor: DesignTokens.Colors.workspaceColor(workspace),
                                    label: workspace.rawValue,
                                    detail: "Configure"
                                )
                            }
                        }

                        settingsSection(title: "ABOUT") {
                            SettingsInfoRow(label: "Version", value: "1.0.0")
                            Divider().padding(.leading, 56)
                            SettingsInfoRow(label: "Build", value: "Deep Sea Productivity")
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.bottom, 100)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    DSAppHeader(title: "Deep Sea Productivity")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .sheet(isPresented: $showingNameEditor) {
            nameEditorSheet
        }
    }

    // MARK: Profile Card

    private var profileCard: some View {
        HStack(spacing: DesignTokens.Spacing.lg) {
            Circle()
                .fill(LinearGradient.deepSeaPrimary)
                .frame(width: 60, height: 60)
                .overlay(
                    Text(String(userName.prefix(1)).uppercased())
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color.white)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(userName)
                    .font(.headline(17))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                Text("Deep Sea Member")
                    .font(.body(13))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }

            Spacer()

            Button { showingNameEditor = true } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DesignTokens.Colors.primary)
                    .frame(width: 34, height: 34)
                    .background(DesignTokens.Colors.primaryFixed, in: Circle())
            }
            .accessibilityLabel("Edit name")
        }
        .padding(DesignTokens.Spacing.lg)
        .background(DesignTokens.Colors.backgroundCard, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl))
        .shadow(color: Color(hex: "#00334d").opacity(0.06), radius: 12, x: 0, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Profile: \(userName)")
    }

    // MARK: Section Builder

    private func settingsSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(title)
                .sectionLabel()
                .padding(.leading, DesignTokens.Spacing.xs)

            VStack(spacing: 0) {
                content()
            }
            .background(DesignTokens.Colors.backgroundCard, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl))
            .shadow(color: Color(hex: "#00334d").opacity(0.04), radius: 8, x: 0, y: 2)
        }
    }

    // MARK: Name Editor Sheet

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
                        .foregroundStyle(DesignTokens.Colors.primary)
                }
            }
        }
    }
}

// MARK: - Settings Row Components

private struct SettingsToggleRow: View {
    let icon:      String
    let iconColor: Color
    let label:     String
    @Binding var value: Bool

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 30, height: 30)
                .background(iconColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            Text(label)
                .font(.body(15))
                .foregroundStyle(DesignTokens.Colors.textPrimary)

            Spacer()

            Toggle("", isOn: $value)
                .labelsHidden()
                .tint(DesignTokens.Colors.primary)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
    }
}

private struct SettingsLinkRow: View {
    let icon:      String
    let iconColor: Color
    let label:     String
    var detail:    String? = nil

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 30, height: 30)
                .background(iconColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            Text(label)
                .font(.body(15))
                .foregroundStyle(DesignTokens.Colors.textPrimary)

            Spacer()

            if let detail {
                Text(detail)
                    .font(.body(13))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DesignTokens.Colors.outlineVariant)
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
        HStack {
            Text(label)
                .font(.body(15))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .padding(.leading, 46)

            Spacer()

            Text(value)
                .font(.body(15))
                .foregroundStyle(DesignTokens.Colors.textSecondary)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
    }
}
