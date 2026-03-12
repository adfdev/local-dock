import Foundation
import SwiftUI

@Observable
final class AppSettings {
    static let shared = AppSettings()

    var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            LaunchAtLoginManager.setEnabled(launchAtLogin)
        }
    }

    var showNotifications: Bool {
        didSet {
            UserDefaults.standard.set(showNotifications, forKey: "showNotifications")
        }
    }

    var groupByProject: Bool {
        didSet {
            UserDefaults.standard.set(groupByProject, forKey: "groupByProject")
        }
    }

    var showAllPorts: Bool {
        didSet {
            UserDefaults.standard.set(showAllPorts, forKey: "showAllPorts")
        }
    }

    var customLabels: [Int: String] {
        didSet {
            if let data = try? JSONEncoder().encode(customLabels) {
                UserDefaults.standard.set(data, forKey: "customLabels")
            }
        }
    }

    /// Custom groups: group name -> set of port numbers
    var customGroups: [String: Set<Int>] {
        didSet {
            let encodable = customGroups.mapValues { Array($0) }
            if let data = try? JSONEncoder().encode(encodable) {
                UserDefaults.standard.set(data, forKey: "customGroups")
            }
        }
    }

    /// Ordered list of group names
    var groupOrder: [String] {
        didSet {
            UserDefaults.standard.set(groupOrder, forKey: "groupOrder")
        }
    }

    /// Port -> group name mapping (derived for quick lookup)
    var portToGroup: [Int: String] {
        var map: [Int: String] = [:]
        for (groupName, ports) in customGroups {
            for port in ports {
                map[port] = groupName
            }
        }
        return map
    }

    func addGroup(_ name: String) {
        guard !name.isEmpty, customGroups[name] == nil else { return }
        customGroups[name] = []
        groupOrder.append(name)
    }

    func removeGroup(_ name: String) {
        customGroups.removeValue(forKey: name)
        groupOrder.removeAll { $0 == name }
    }

    func renameGroup(_ oldName: String, to newName: String) {
        guard let ports = customGroups[oldName], !newName.isEmpty else { return }
        customGroups.removeValue(forKey: oldName)
        customGroups[newName] = ports
        if let idx = groupOrder.firstIndex(of: oldName) {
            groupOrder[idx] = newName
        }
    }

    func assignPort(_ port: Int, toGroup group: String) {
        // Remove from any existing group first
        for (name, var ports) in customGroups {
            if ports.remove(port) != nil {
                customGroups[name] = ports
            }
        }
        // Add to new group
        if var ports = customGroups[group] {
            ports.insert(port)
            customGroups[group] = ports
        }
    }

    func removePortFromGroup(_ port: Int) {
        for (name, var ports) in customGroups {
            if ports.remove(port) != nil {
                customGroups[name] = ports
                return
            }
        }
    }

    private init() {
        self.launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
        self.showNotifications = UserDefaults.standard.object(forKey: "showNotifications") as? Bool ?? true
        self.groupByProject = UserDefaults.standard.object(forKey: "groupByProject") as? Bool ?? true
        self.showAllPorts = UserDefaults.standard.bool(forKey: "showAllPorts")

        if let data = UserDefaults.standard.data(forKey: "customLabels"),
           let labels = try? JSONDecoder().decode([Int: String].self, from: data) {
            self.customLabels = labels
        } else {
            self.customLabels = [:]
        }

        if let data = UserDefaults.standard.data(forKey: "customGroups"),
           let groups = try? JSONDecoder().decode([String: [Int]].self, from: data) {
            self.customGroups = groups.mapValues { Set($0) }
        } else {
            self.customGroups = [:]
        }

        self.groupOrder = UserDefaults.standard.stringArray(forKey: "groupOrder") ?? []
    }
}

enum LaunchAtLoginManager {
    static func setEnabled(_ enabled: Bool) {
        if enabled {
            try? SMAppService.register()
        } else {
            try? SMAppService.unregister()
        }
    }
}

import ServiceManagement

private extension SMAppService {
    static func register() throws {
        try SMAppService.mainApp.register()
    }

    static func unregister() throws {
        try SMAppService.mainApp.unregister()
    }
}
