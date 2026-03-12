import SwiftUI

struct SettingsView: View {
    @Bindable private var settings = AppSettings.shared
    @State private var newGroupName = ""
    @State private var editingGroup: String?
    @State private var editedGroupName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "gearshape.fill")
                    .foregroundStyle(Theme.accent)
                    .font(.system(size: 13))
                Text("Settings")
                    .font(.system(.headline, design: .rounded))
            }

            // Toggles
            VStack(alignment: .leading, spacing: 8) {
                SettingsToggle(
                    label: "Notifications",
                    icon: "bell.fill",
                    color: Theme.amber,
                    isOn: $settings.showNotifications
                )
                SettingsToggle(
                    label: "Group by project",
                    icon: "folder.fill",
                    color: Theme.violet,
                    isOn: $settings.groupByProject
                )
                SettingsToggle(
                    label: "Launch at login",
                    icon: "power",
                    color: Theme.emerald,
                    isOn: $settings.launchAtLogin
                )
                SettingsToggle(
                    label: "Show all ports",
                    icon: "eye.fill",
                    color: Theme.coral,
                    isOn: $settings.showAllPorts
                )
            }

            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)

            // Custom Groups
            VStack(alignment: .leading, spacing: 8) {
                Text("CUSTOM GROUPS")
                    .font(.system(.caption2, design: .monospaced, weight: .semibold))
                    .foregroundStyle(Theme.comment)

                // Existing groups
                if !settings.groupOrder.isEmpty {
                    VStack(spacing: 4) {
                        ForEach(settings.groupOrder, id: \.self) { group in
                            HStack(spacing: 8) {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Theme.mint)

                                if editingGroup == group {
                                    TextField("Group name", text: $editedGroupName)
                                        .textFieldStyle(.plain)
                                        .font(.system(.callout, design: .monospaced))
                                        .onSubmit {
                                            if !editedGroupName.isEmpty {
                                                settings.renameGroup(group, to: editedGroupName)
                                            }
                                            editingGroup = nil
                                        }
                                } else {
                                    Text(group)
                                        .font(.system(.callout, design: .rounded))
                                        .onTapGesture(count: 2) {
                                            editingGroup = group
                                            editedGroupName = group
                                        }
                                }

                                let count = settings.customGroups[group]?.count ?? 0
                                if count > 0 {
                                    Text(verbatim: "\(count)")
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(Theme.comment)
                                }

                                Spacer()

                                Button {
                                    settings.removeGroup(group)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(Theme.comment)
                                }
                                .buttonStyle(.plain)
                                .help("Delete group")
                            }
                            .padding(.vertical, 3)
                            .padding(.horizontal, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Theme.surfaceHover)
                            )
                        }
                    }
                }

                // Add new group
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.mint)

                    TextField("New group name...", text: $newGroupName)
                        .textFieldStyle(.plain)
                        .font(.system(.callout, design: .monospaced))
                        .onSubmit {
                            addGroup()
                        }

                    if !newGroupName.isEmpty {
                        Button {
                            addGroup()
                        } label: {
                            Text("Add")
                                .font(.system(.caption, design: .rounded, weight: .medium))
                                .foregroundStyle(Theme.mint)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }

            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)

            VStack(spacing: 6) {
                HStack {
                    Text("Local Dock")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(Theme.comment)
                    Spacer()
                    Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Theme.comment.opacity(0.6))
                }

                HStack(spacing: 4) {
                    Text("Made by")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(Theme.comment.opacity(0.5))

                    Button {
                        NSWorkspace.shared.open(URL(string: "https://adf.dev")!)
                    } label: {
                        Text("@adfdev")
                            .font(.system(.caption2, design: .monospaced, weight: .medium))
                            .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            }
        }
        .padding(16)
        .frame(width: 280)
    }

    private func addGroup() {
        let name = newGroupName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        settings.addGroup(name)
        newGroupName = ""
    }
}

struct SettingsToggle: View {
    let label: String
    let icon: String
    let color: Color
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(color)
                    .frame(width: 16, alignment: .leading)
                Text(label)
                    .font(.system(.callout, design: .rounded))
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }
}
