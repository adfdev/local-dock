import Foundation

struct GitHubRelease: Decodable {
    let tagName: String
    let htmlUrl: String

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlUrl = "html_url"
    }
}

@MainActor
@Observable
final class UpdateChecker {
    static let shared = UpdateChecker()

    var updateAvailable = false
    var latestVersion = ""
    var downloadURL = ""

    private let repo = "adfdev/local-dock"

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    func checkForUpdates() async {
        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else { return }

        do {
            var request = URLRequest(url: url)
            request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 10

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let remote = release.tagName.replacingOccurrences(of: "v", with: "")

            if isNewer(remote: remote, current: currentVersion) {
                updateAvailable = true
                latestVersion = remote
                downloadURL = release.htmlUrl
            }
        } catch {
            // Silently fail — non-critical
        }
    }

    private func isNewer(remote: String, current: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let c = current.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(r.count, c.count) {
            let rv = i < r.count ? r[i] : 0
            let cv = i < c.count ? c[i] : 0
            if rv > cv { return true }
            if rv < cv { return false }
        }
        return false
    }
}
