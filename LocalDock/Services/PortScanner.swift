import Foundation

protocol PortScanning: Sendable {
    func scanPorts() async throws -> [PortInfo]
}

actor PortScanner: PortScanning {
    private var gitRootCache: [Int: (root: String?, timestamp: Date)] = [:]
    private var gitBranchCache: [String: (branch: String?, timestamp: Date)] = [:]
    private let cacheTTL: TimeInterval = 30

    // Processi di sviluppo riconosciuti (dev servers, databases, runtimes)
    private static let devProcesses: Set<String> = [
        // Runtimes & servers
        "node", "deno", "bun", "python", "python3", "ruby", "java", "go",
        "php", "dotnet", "uvicorn", "gunicorn", "flask", "django",
        "next-server", "vite", "webpack", "esbuild", "turbopack",
        "ng", "nuxt", "remix", "astro",
        // Databases
        "postgres", "mysqld", "mariadbd", "mongod", "mongos",
        "redis-ser", "redis-server", "memcached",
        "clickhouse", "cockroach",
        // Containers & infra
        "docker", "docker-proxy", "containerd", "kubectl", "kubelet",
        "nginx", "httpd", "apache2", "caddy", "traefik", "envoy",
        // Mobile dev
        "dart", "flutter", "Runner",
        // Tools
        "adb", "emulator", "Simulator",
        "hugo", "jekyll", "gatsby",
        // Elixir/Erlang
        "beam.smp", "elixir", "mix",
        // Rust
        "cargo", "rustc",
    ]

    // Processi di sistema da nascondere sempre
    private static let systemProcesses: Set<String> = [
        "ControlCe", "ControlCenter",
        "rapportd", "sharingd",
        "WiFiAgent", "bluetoothd", "airportd",
        "IPNExtens", "NETExtens",
        "mDNSRespo", "netbiosd",
        "launchd", "kernel_task",
        "UserEvent", "SystemUIServer",
    ]

    // Pattern di processi helper/browser da nascondere
    private static let hiddenPatterns: [String] = [
        "Code Helper", "Code\\x20H",
        "Electron Helper", "Electron\\x20H",
        "chrome-he", "chrome_crashpad",
        "Google Chrome H", "Google\\x20Chrome",
        "firefox", "Safari",
        "Discord", "Slack Helper", "Slack\\x20H",
        "Spotify", "Spotify Helper",
        "Teams", "Zoom",
        "figma", "Figma",
    ]

    func isDevProcess(_ processName: String, command: String) -> Bool {
        // Check if it's explicitly a system process
        if Self.systemProcesses.contains(processName) {
            return false
        }

        // Check hidden patterns
        for pattern in Self.hiddenPatterns {
            if processName.contains(pattern) || command.contains(pattern) {
                return false
            }
        }

        // Check if it's a known dev process
        if Self.devProcesses.contains(processName) {
            return true
        }

        // Check if the command line contains known dev tools
        let devKeywords = [
            "node ", "npm ", "npx ", "yarn ", "pnpm ",
            "python ", "python3 ", "pip ",
            "ruby ", "rails ", "bundle ",
            "java ", "gradle ", "maven ", "mvn ",
            "go ", "cargo ", "rustc ",
            "php ", "composer ", "artisan",
            "docker", "kubectl",
            "postgres", "mysql", "redis", "mongo",
            "next", "vite", "webpack", "flask", "django",
            "uvicorn", "gunicorn", "nest",
            "dart ", "flutter",
        ]
        let cmdLower = command.lowercased()
        for keyword in devKeywords {
            if cmdLower.contains(keyword) {
                return true
            }
        }

        return false
    }

    func scanPorts() async throws -> [PortInfo] {
        let output = try await runCommand("/usr/sbin/lsof", arguments: ["-iTCP", "-sTCP:LISTEN", "-n", "-P"])
        let lines = output.components(separatedBy: "\n").dropFirst() // skip header
        var portMap: [String: PortInfo] = [:]

        for line in lines {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard parts.count >= 9 else { continue }

            let processName = parts[0]
            guard let pid = Int(parts[1]) else { continue }

            // NAME field is second-to-last (last is "(LISTEN)")
            // Find the field that contains a colon and port number
            var nameField = ""
            for part in parts.reversed() {
                if part.contains(":") && !part.hasPrefix("(") {
                    nameField = part
                    break
                }
            }
            guard !nameField.isEmpty else { continue }
            guard let port = parsePort(from: nameField) else { continue }

            let key = "\(pid):\(port)"
            guard portMap[key] == nil else { continue }

            let command = await getCommand(for: pid)

            // Filter: skip non-dev processes unless showAllPorts is enabled
            let showAll = await MainActor.run { AppSettings.shared.showAllPorts }
            if !showAll && !isDevProcess(processName, command: command) {
                continue
            }

            let gitRoot = await getGitRoot(for: pid)
            let gitBranch: String? = if let root = gitRoot {
                await getGitBranch(at: root)
            } else {
                nil
            }
            let repoName = gitRoot.map { URL(fileURLWithPath: $0).lastPathComponent }
            let startTime = await getProcessStartTime(for: pid) ?? Date()

            let customLabel = await MainActor.run { AppSettings.shared.customLabels[port] }
            let info = PortInfo(
                id: key,
                port: port,
                pid: pid,
                processName: processName,
                command: command,
                gitRepo: repoName,
                gitBranch: gitBranch,
                startTime: startTime,
                customLabel: customLabel
            )
            portMap[key] = info
        }

        return Array(portMap.values)
    }

    private func parsePort(from nameField: String) -> Int? {
        // Format: *:PORT or 127.0.0.1:PORT or [::1]:PORT
        guard let colonRange = nameField.range(of: ":", options: .backwards) else { return nil }
        let portString = String(nameField[colonRange.upperBound...])
        return Int(portString)
    }

    private func getCommand(for pid: Int) async -> String {
        let output = (try? await runCommand("/bin/ps", arguments: ["-p", "\(pid)", "-o", "command="])) ?? ""
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func getProcessStartTime(for pid: Int) async -> Date? {
        guard let output = try? await runCommand("/bin/ps", arguments: ["-p", "\(pid)", "-o", "lstart="]) else {
            return nil
        }
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE MMM dd HH:mm:ss yyyy"
        return formatter.date(from: trimmed)
    }

    private func getGitRoot(for pid: Int) async -> String? {
        if let cached = gitRootCache[pid],
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            return cached.root
        }

        // Get the working directory of the process via lsof
        guard let cwd = try? await runCommand("/usr/sbin/lsof", arguments: ["-p", "\(pid)", "-Fn", "-a", "-d", "cwd"]) else {
            gitRootCache[pid] = (nil, Date())
            return nil
        }

        let lines = cwd.components(separatedBy: "\n")
        var directory: String?
        for line in lines {
            if line.hasPrefix("n") && line.count > 1 {
                directory = String(line.dropFirst())
                break
            }
        }

        guard let dir = directory else {
            gitRootCache[pid] = (nil, Date())
            return nil
        }

        // Use git subprocess instead of FileManager to avoid TCC prompts
        let root = try? await runCommandInDirectory(
            "/usr/bin/git", arguments: ["rev-parse", "--show-toplevel"], directory: dir
        )
        let trimmedRoot = root?.trimmingCharacters(in: .whitespacesAndNewlines)
        let result = (trimmedRoot?.isEmpty == false) ? trimmedRoot : nil
        gitRootCache[pid] = (result, Date())
        return result
    }

    private func getGitBranch(at repoPath: String) async -> String? {
        if let cached = gitBranchCache[repoPath],
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            return cached.branch
        }

        // Use git subprocess instead of reading .git/HEAD directly
        let output = try? await runCommandInDirectory(
            "/usr/bin/git", arguments: ["rev-parse", "--abbrev-ref", "HEAD"], directory: repoPath
        )
        let branch = output?.trimmingCharacters(in: .whitespacesAndNewlines)
        let result = (branch?.isEmpty == false) ? branch : nil
        gitBranchCache[repoPath] = (result, Date())
        return result
    }

    func pruneCache(activePIDs: Set<Int>) {
        for pid in gitRootCache.keys where !activePIDs.contains(pid) {
            gitRootCache.removeValue(forKey: pid)
        }
    }

    private func runCommandInDirectory(_ path: String, arguments: [String], directory: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = arguments
            process.currentDirectoryURL = URL(fileURLWithPath: directory)
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
                return
            }

            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            if process.terminationStatus == 0 {
                continuation.resume(returning: output)
            } else {
                continuation.resume(throwing: NSError(domain: "PortScanner", code: Int(process.terminationStatus)))
            }
        }
    }

    private func runCommand(_ path: String, arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = arguments
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
                return
            }

            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            continuation.resume(returning: output)
        }
    }
}
