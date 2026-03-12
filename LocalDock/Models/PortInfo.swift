import Foundation

struct PortInfo: Identifiable, Hashable {
    let id: String
    let port: Int
    let pid: Int
    let processName: String
    let command: String
    let gitRepo: String?
    let gitBranch: String?
    let startTime: Date
    var customLabel: String?
    var customGroup: String?

    var displayName: String {
        if let label = customLabel, !label.isEmpty {
            return label
        }
        if let repo = gitRepo {
            return repo
        }
        return processName
    }

    var uptimeString: String {
        let interval = Date().timeIntervalSince(startTime)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    var localhostURL: URL? {
        URL(string: "http://localhost:\(port)")
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: PortInfo, rhs: PortInfo) -> Bool {
        lhs.id == rhs.id
    }
}

struct PortGroup: Identifiable {
    let id: String
    let name: String
    let ports: [PortInfo]

    init(name: String, ports: [PortInfo]) {
        self.id = name
        self.name = name
        self.ports = ports.sorted { $0.port < $1.port }
    }
}
