import Foundation

public final class ProfileManager: @unchecked Sendable {
    public static let shared = ProfileManager()

    private let adapter: DiskProfileStorageAdapter

    public init(adapter: DiskProfileStorageAdapter = DiskProfileStorageAdapter()) {
        self.adapter = adapter
    }

    public func loadProfiles() -> [GameProfile] {
        do {
            let loaded = try adapter.loadProfiles()
            return loaded.isEmpty ? [GameProfile()] : loaded
        } catch {
            return [GameProfile()]
        }
    }

    public func saveProfiles(_ profiles: [GameProfile]) {
        try? adapter.saveProfiles(profiles)
    }
}
