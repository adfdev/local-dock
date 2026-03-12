import SwiftUI

struct PortRowView: View {
    let port: PortInfo
    let availableGroups: [String]
    let onKill: () -> Void
    let onSetLabel: (String) -> Void
    let onAssignGroup: (String) -> Void
    let onRemoveFromGroup: () -> Void

    @State private var isHovering = false
    @State private var isEditingLabel = false
    @State private var labelText = ""
    @State private var showGroupPicker = false

    var body: some View {
        HStack(spacing: 10) {
            // Port badge
            Text(verbatim: "\(port.port)")
                .font(.system(.callout, design: .monospaced, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(portColor.gradient)
                )

            // Info column
            VStack(alignment: .leading, spacing: 3) {
                Text(port.displayName)
                    .font(.system(.callout, design: .rounded, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let branch = port.gitBranch {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.system(size: 9))
                            Text(branch)
                        }
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Theme.violet)
                    }

                    Text(port.processName)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Theme.comment)

                    Text(port.uptimeString)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Theme.comment.opacity(0.7))
                }
            }

            Spacer(minLength: 4)

            // Hover actions
            if isHovering {
                HStack(spacing: 2) {
                    ActionButton(icon: "globe", tooltip: "Open in browser", color: Theme.accent) {
                        ProcessManager.openInBrowser(port: port.port)
                    }

                    ActionButton(icon: "doc.on.doc", tooltip: "Copy URL", color: Theme.mint) {
                        ProcessManager.copyURL(port: port.port)
                    }

                    ActionButton(icon: "tag", tooltip: "Set label", color: Theme.violet) {
                        labelText = port.customLabel ?? ""
                        isEditingLabel = true
                    }

                    // Group assign button (styled like ActionButton)
                    ActionButton(
                        icon: port.customGroup != nil ? "folder.fill" : "folder.badge.plus",
                        tooltip: "Assign to group",
                        color: Theme.mint
                    ) {
                        showGroupPicker = true
                    }

                    ActionButton(icon: "xmark.circle.fill", tooltip: "Kill process", color: Theme.coral) {
                        onKill()
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.9, anchor: .trailing)),
                    removal: .opacity
                ))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Theme.surfaceHover : Color.clear)
        )
        .padding(.horizontal, 4)
        .onHover { hovering in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                isHovering = hovering
            }
        }
        .popover(isPresented: $isEditingLabel) {
            LabelEditor(text: $labelText) { newLabel in
                onSetLabel(newLabel)
                isEditingLabel = false
            }
        }
        .popover(isPresented: $showGroupPicker) {
            GroupPicker(
                groups: availableGroups,
                currentGroup: port.customGroup,
                onSelect: { group in
                    onAssignGroup(group)
                    showGroupPicker = false
                },
                onRemove: {
                    onRemoveFromGroup()
                    showGroupPicker = false
                }
            )
        }
        .help(port.command)
    }

    private var portColor: Color {
        Theme.portColor(for: port.port)
    }
}

struct ActionButton: View {
    let icon: String
    let tooltip: String
    var color: Color = .primary
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isHovering ? color : .secondary)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isHovering ? color.opacity(0.12) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(tooltip)
    }
}

struct GroupPicker: View {
    let groups: [String]
    let currentGroup: String?
    let onSelect: (String) -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundStyle(Theme.mint)
                    .font(.system(size: 12))
                Text("Assign to Group")
                    .font(.system(.callout, design: .rounded, weight: .medium))
            }

            if groups.isEmpty {
                Text("No groups yet.\nCreate them in Settings.")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Theme.comment)
            } else {
                VStack(spacing: 2) {
                    ForEach(groups, id: \.self) { group in
                        Button {
                            onSelect(group)
                        } label: {
                            HStack {
                                Text(group)
                                    .font(.system(.callout, design: .rounded))
                                Spacer()
                                if currentGroup == group {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(Theme.mint)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(currentGroup == group ? Theme.mint.opacity(0.1) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                if currentGroup != nil {
                    Rectangle()
                        .fill(Theme.border)
                        .frame(height: 1)

                    Button {
                        onRemove()
                    } label: {
                        HStack {
                            Image(systemName: "folder.badge.minus")
                                .font(.system(size: 10))
                            Text("Remove from group")
                                .font(.system(.caption, design: .rounded))
                        }
                        .foregroundStyle(Theme.coral)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .frame(minWidth: 180)
    }
}

struct LabelEditor: View {
    @Binding var text: String
    let onSave: (String) -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "tag.fill")
                    .foregroundStyle(Theme.violet)
                    .font(.system(size: 12))
                Text("Custom Label")
                    .font(.system(.callout, design: .rounded, weight: .medium))
            }

            TextField("e.g. Frontend, API, DB...", text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.system(.callout, design: .monospaced))
                .frame(width: 200)
                .onSubmit {
                    onSave(text)
                }

            HStack {
                Button {
                    onSave("")
                } label: {
                    Text("Clear")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.comment)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    onSave(text)
                } label: {
                    Text("Save")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(Theme.accent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
    }
}
