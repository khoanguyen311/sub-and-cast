import Foundation

public final class ProfileManager: @unchecked Sendable {
    public static let shared = ProfileManager()

    private let fileURL: URL

    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("SubAndCast", isDirectory: true)
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        self.fileURL = appFolder.appendingPathComponent("profiles.json")
    }

    public func loadProfiles() -> [GameProfile] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            let defaultProfile = GameProfile()
            saveProfiles([defaultProfile])
            return [defaultProfile]
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let profiles = try JSONDecoder().decode([GameProfile].self, from: data)
            return profiles.isEmpty ? [GameProfile()] : profiles
        } catch {
            print("Failed to load profiles: \(error). Falling back to default.")
            return [GameProfile()]
        }
    }

    public func saveProfiles(_ profiles: [GameProfile]) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(profiles)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save profiles: \(error)")
        }
    }
}
