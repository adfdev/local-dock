import SwiftUI

struct ContentView: View {
    @Bindable var store: PortStore
    @State private var showSettings = false
    @State private var showKillAllConfirmation = false

    var body: some View {
        ZStack {
            // Main content
            VStack(spacing: 0) {
                headerView

                Rectangle()
                    .fill(Theme.border)
                    .frame(height: 1)

                if UpdateChecker.shared.updateAvailable {
                    updateBanner
                }

                if store.activePortCount > 3 {
                    searchBar
                    Rectangle()
                        .fill(Theme.border)
                        .frame(height: 1)
                }

                ScrollView {
                    if let error = store.error {
                        errorView(error)
                    } else if store.filteredPorts.isEmpty {
                        emptyView
                    } else {
                        portListView
                    }
                }
                .frame(maxHeight: 420)
                .scrollIndicators(.never)
            }
            .blur(radius: (store.showKillConfirmation || showKillAllConfirmation || showKillGroupConfirmation) ? 2 : 0)
            .allowsHitTesting(!(store.showKillConfirmation || showKillAllConfirmation || showKillGroupConfirmation))

            // Kill single confirmation overlay
            if store.showKillConfirmation, let port = store.portToKill {
                confirmationOverlay(
                    title: "Kill Process",
                    message: "Terminate \(port.displayName) on port \(port.port)?\nPID: \(port.pid)",
                    confirmLabel: "Kill",
                    onConfirm: { store.confirmKill() },
                    onCancel: { store.cancelKill() }
                )
            }

            // Kill group confirmation overlay
            if showKillGroupConfirmation, let group = groupToKill {
                confirmationOverlay(
                    title: "Kill Group",
                    message: "Terminate all \(group.ports.count) processes in \"\(group.name)\"?",
                    confirmLabel: "Kill Group",
                    onConfirm: {
                        killGroup(group)
                        showKillGroupConfirmation = false
                        groupToKill = nil
                    },
                    onCancel: {
                        showKillGroupConfirmation = false
                        groupToKill = nil
                    }
                )
            }

            // Kill All confirmation overlay
            if showKillAllConfirmation {
                confirmationOverlay(
                    title: "Kill All Ports",
                    message: "Terminate all \(store.filteredPorts.count) active processes?",
                    confirmLabel: "Kill All",
                    onConfirm: {
                        killAllPorts()
                        showKillAllConfirmation = false
                    },
                    onCancel: { showKillAllConfirmation = false }
                )
            }
        }
        .frame(width: 420)
        .background(.ultraThinMaterial)
        .onAppear {
            store.startMonitoring()
            Task { await UpdateChecker.shared.checkForUpdates() }
        }
        .onDisappear {
            store.stopMonitoring()
        }
    }

    // MARK: - Confirmation Overlay

    private func confirmationOverlay(
        title: String,
        message: String,
        confirmLabel: String,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundStyle(Theme.coral)

            VStack(spacing: 6) {
                Text(title)
                    .font(.system(.headline, design: .rounded))

                Text(message)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 10) {
                Button {
                    onCancel()
                } label: {
                    Text("Cancel")
                        .font(.system(.callout, design: .rounded, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.primary.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)

                Button {
                    onConfirm()
                } label: {
                    Text(confirmLabel)
                        .font(.system(.callout, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Theme.coral)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .frame(width: 300)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThickMaterial)
                .shadow(color: .black.opacity(0.2), radius: 20)
        )
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 8) {
            Image("Logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)

            Text("Local Dock")
                .font(.system(.headline, design: .rounded))

            Spacer()

            if store.activePortCount > 0 {
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        showKillAllConfirmation = true
                    }
                } label: {
                    Text("Kill All")
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.coral)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Theme.coral.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
            }

            Text(verbatim: "\(store.activePortCount)")
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(store.activePortCount > 0 ? Theme.accent : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Theme.accent.opacity(store.activePortCount > 0 ? 0.12 : 0.05))
                )

            FooterButton(icon: "gear", tooltip: "Settings") {
                showSettings.toggle()
            }
            .popover(isPresented: $showSettings) {
                SettingsView()
            }

            FooterButton(icon: "power", tooltip: "Quit Local Dock", muted: true) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(Theme.comment)

            TextField("Search ports, projects, groups...", text: $store.searchText)
                .textFieldStyle(.plain)
                .font(.system(.callout, design: .monospaced))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Port List

    private var portListView: some View {
        let availableGroups = AppSettings.shared.groupOrder

        return LazyVStack(alignment: .leading, spacing: 1) {
            ForEach(store.groupedPorts) { group in
                if store.groupedPorts.count > 1 {
                    groupHeader(group)
                }

                ForEach(group.ports) { port in
                    PortRowView(
                        port: port,
                        availableGroups: availableGroups,
                        onKill: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                store.requestKill(port)
                            }
                        },
                        onSetLabel: { label in store.setLabel(label, for: port) },
                        onAssignGroup: { group in store.assignToGroup(port, group: group) },
                        onRemoveFromGroup: { store.removeFromGroup(port) }
                    )
                }
            }
        }
        .padding(.vertical, 6)
    }

    @State private var groupToKill: PortGroup?
    @State private var showKillGroupConfirmation = false

    private func groupHeader(_ group: PortGroup) -> some View {
        HStack(spacing: 6) {
            if AppSettings.shared.customGroups[group.name] != nil {
                Image(systemName: "folder.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(Theme.mint)
            }
            Text(group.name)
                .font(.system(.caption2, design: .monospaced, weight: .semibold))
                .foregroundStyle(Theme.comment)
                .textCase(.uppercase)

            Spacer()

            if group.ports.count > 1 {
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        groupToKill = group
                        showKillGroupConfirmation = true
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 9))
                        Text("Kill")
                            .font(.system(.caption2, design: .rounded, weight: .medium))
                    }
                    .foregroundStyle(Theme.coral.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    // MARK: - Empty State

    private var emptyView: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.comment.opacity(0.1))
                    .frame(width: 64, height: 64)

                Image(systemName: "network.slash")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(Theme.comment)
            }

            VStack(spacing: 4) {
                Text("No active ports")
                    .font(.system(.callout, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)

                Text("Start a dev server to see it here")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Theme.comment)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title3)
                .foregroundStyle(Theme.coral)

            Text(message)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task { await store.scan() }
            } label: {
                Text("Retry")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Theme.accent.opacity(0.15))
                    .foregroundStyle(Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    // MARK: - Update Banner

    private var updateBanner: some View {
        Button {
            if let url = URL(string: UpdateChecker.shared.downloadURL) {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.emerald)

                Text("v\(UpdateChecker.shared.latestVersion) disponibile")
                    .font(.system(.caption, design: .rounded, weight: .medium))

                Spacer()

                Text("Download")
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Theme.emerald))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Theme.emerald.opacity(0.08))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func killGroup(_ group: PortGroup) {
        for port in group.ports {
            try? ProcessManager.kill(pid: port.pid)
        }
        Task {
            try? await Task.sleep(for: .seconds(1))
            await store.scan()
        }
    }

    private func killAllPorts() {
        for port in store.filteredPorts {
            try? ProcessManager.kill(pid: port.pid)
        }
        Task {
            try? await Task.sleep(for: .seconds(1))
            await store.scan()
        }
    }
}

struct FooterButton: View {
    let icon: String
    let tooltip: String
    var muted: Bool = false
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(muted ? Theme.comment : .secondary)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovering ? Theme.surfaceHover : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(tooltip)
    }
}
