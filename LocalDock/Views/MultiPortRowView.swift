import SwiftUI

struct MergedEntry: Identifiable {
    let ports: [PortInfo]

    var id: String {
        ports.map { $0.id }.joined(separator: "-")
    }

    var displayName: String {
        ports.first?.displayName ?? ""
    }

    var processName: String {
        ports.first?.processName ?? ""
    }

    var gitBranch: String? {
        ports.first?.gitBranch
    }

    var oldestUptime: String {
        guard let oldest = ports.min(by: { $0.startTime < $1.startTime }) else { return "" }
        return oldest.uptimeString
    }
}

struct MultiPortRowView: View {
    let entry: MergedEntry
    let availableGroups: [String]
    let onKill: (PortInfo) -> Void
    let onSetLabel: (String, PortInfo) -> Void
    let onAssignGroup: (String, PortInfo) -> Void
    let onRemoveFromGroup: (PortInfo) -> Void

    @State private var isHovering = false
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main collapsed row
            HStack(spacing: 10) {
                // Multi-port badges
                FlowLayout(spacing: 4) {
                    ForEach(entry.ports, id: \.port) { port in
                        PortBadge(port: port)
                    }
                }

                // Info column
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.displayName)
                        .font(.system(.callout, design: .rounded, weight: .medium))
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        if let branch = entry.gitBranch {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.triangle.branch")
                                    .font(.system(size: 9))
                                Text(branch)
                            }
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(Theme.violet)
                        }

                        Text(entry.processName)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(Theme.comment)

                        Text("\(entry.ports.count) ports")
                            .font(.system(.caption2, design: .monospaced, weight: .medium))
                            .foregroundStyle(Theme.accent)
                    }
                }

                Spacer(minLength: 4)

                // Expand/collapse
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.comment)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
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

            // Expanded individual ports
            if isExpanded {
                VStack(spacing: 1) {
                    ForEach(entry.ports) { port in
                        PortRowView(
                            port: port,
                            availableGroups: availableGroups,
                            onKill: { onKill(port) },
                            onSetLabel: { label in onSetLabel(label, port) },
                            onAssignGroup: { group in onAssignGroup(group, port) },
                            onRemoveFromGroup: { onRemoveFromGroup(port) }
                        )
                    }
                }
                .padding(.leading, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

private struct PortBadge: View {
    let port: PortInfo

    @State private var isHovering = false

    var body: some View {
        Text(verbatim: "\(port.port)")
            .font(.system(.caption2, design: .monospaced, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Theme.portColor(for: port.port).gradient)
            )
            .scaleEffect(isHovering ? 1.08 : 1.0)
            .onHover { isHovering = $0 }
            .onTapGesture {
                ProcessManager.openInBrowser(port: port.port)
            }
            .help("Open localhost:\(port.port)")
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}
