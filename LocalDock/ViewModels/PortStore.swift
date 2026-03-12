import Foundation
import SwiftUI

@Observable
@MainActor
final class PortStore {
    var ports: [PortInfo] = []
    var error: String?
    var searchText = ""
    var selectedPort: PortInfo?

    // Kill confirmation
    var portToKill: PortInfo?
    var showKillConfirmation = false

    private let scanner: PortScanning
    private var timerTask: Task<Void, Never>?
    private var recentlyKilled: [Int: Date] = [:]
    private let recentlyKilledTTL: TimeInterval = 8

    var filteredPorts: [PortInfo] {
        var result = ports.filter { port in
            !isRecentlyKilled(pid: port.pid)
        }

        if !searchText.isEmpty {
            result = result.filter { port in
                port.displayName.localizedCaseInsensitiveContains(searchText) ||
                String(port.port).contains(searchText) ||
                port.processName.localizedCaseInsensitiveContains(searchText) ||
                (port.gitBranch?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (port.customGroup?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return result
    }

    var groupedPorts: [PortGroup] {
        let settings = AppSettings.shared
        let portToGroup = settings.portToGroup

        // 1. Custom groups (ordered)
        let portsInCustomGroups = filteredPorts.filter { portToGroup[$0.port] != nil }

        // 2. Remaining (ungrouped)
        let ungrouped = filteredPorts.filter { portToGroup[$0.port] == nil }

        var groups: [PortGroup] = []

        // Custom groups in user-defined order
        for groupName in settings.groupOrder {
            let groupPorts = portsInCustomGroups.filter { portToGroup[$0.port] == groupName }
            if !groupPorts.isEmpty {
                groups.append(PortGroup(name: groupName, ports: groupPorts))
            }
        }

        // Ungrouped ports
        if !ungrouped.isEmpty {
            if settings.groupByProject {
                let grouped = Dictionary(grouping: ungrouped) { $0.gitRepo ?? "Other" }
                let sorted = grouped.sorted { $0.key < $1.key }
                for (name, ports) in sorted {
                    groups.append(PortGroup(name: name, ports: ports))
                }
            } else {
                groups.append(PortGroup(name: "Ungrouped", ports: ungrouped))
            }
        }

        return groups
    }

    var activePortCount: Int {
        ports.count
    }

    init(scanner: PortScanning = PortScanner()) {
        self.scanner = scanner
    }

    func startMonitoring() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.scan()
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    func stopMonitoring() {
        timerTask?.cancel()
        timerTask = nil
    }

    func scan() async {
        error = nil

        do {
            let scanned = try await scanner.scanPorts()
            applyUpdate(scanned)
            NotificationManager.shared.checkForChanges(currentPorts: ports)

            if let scanner = scanner as? PortScanner {
                let activePIDs = Set(scanned.map(\.pid))
                await scanner.pruneCache(activePIDs: activePIDs)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // Ask for confirmation before killing
    func requestKill(_ port: PortInfo) {
        portToKill = port
        showKillConfirmation = true
    }

    // Actually kill after confirmation
    func confirmKill() {
        guard let port = portToKill else { return }
        do {
            try ProcessManager.kill(pid: port.pid)
            recentlyKilled[port.pid] = Date()
        } catch {
            self.error = error.localizedDescription
        }
        portToKill = nil
        showKillConfirmation = false
    }

    func cancelKill() {
        portToKill = nil
        showKillConfirmation = false
    }

    func setLabel(_ label: String, for port: PortInfo) {
        var labels = AppSettings.shared.customLabels
        if label.isEmpty {
            labels.removeValue(forKey: port.port)
        } else {
            labels[port.port] = label
        }
        AppSettings.shared.customLabels = labels

        if let index = ports.firstIndex(where: { $0.id == port.id }) {
            var updated = ports[index]
            updated.customLabel = label.isEmpty ? nil : label
            ports[index] = updated
        }
    }

    func assignToGroup(_ port: PortInfo, group: String) {
        AppSettings.shared.assignPort(port.port, toGroup: group)
    }

    func removeFromGroup(_ port: PortInfo) {
        AppSettings.shared.removePortFromGroup(port.port)
    }

    private func applyUpdate(_ newPorts: [PortInfo]) {
        let oldSet = Set(ports.map(\.id))
        let newSet = Set(newPorts.map(\.id))

        // Enrich with custom group info
        let portToGroup = AppSettings.shared.portToGroup
        let enriched = newPorts.map { port in
            var p = port
            p.customGroup = portToGroup[port.port]
            return p
        }

        if oldSet != newSet {
            withAnimation(.easeInOut(duration: 0.2)) {
                self.ports = enriched
            }
        } else {
            self.ports = enriched
        }
    }

    private func isRecentlyKilled(pid: Int) -> Bool {
        guard let killedAt = recentlyKilled[pid] else { return false }
        if Date().timeIntervalSince(killedAt) > recentlyKilledTTL {
            recentlyKilled.removeValue(forKey: pid)
            return false
        }
        return true
    }
}
