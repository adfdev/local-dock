import Foundation
import AppKit

enum ProcessManager {
    enum KillError: LocalizedError {
        case failed(Int32)

        var errorDescription: String? {
            switch self {
            case .failed(let code):
                return "Failed to kill process (error \(code))"
            }
        }
    }

    static func kill(pid: Int) throws {
        let result = Darwin.kill(Int32(pid), SIGTERM)
        if result != 0 {
            // Try SIGKILL as fallback
            let killResult = Darwin.kill(Int32(pid), SIGKILL)
            if killResult != 0 {
                throw KillError.failed(killResult)
            }
        }
    }

    static func openInBrowser(port: Int) {
        guard let url = URL(string: "http://localhost:\(port)") else { return }
        NSWorkspace.shared.open(url)
    }

    static func copyURL(port: Int) {
        let url = "http://localhost:\(port)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
    }
}
