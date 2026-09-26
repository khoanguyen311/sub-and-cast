import Foundation
import CoreGraphics
import Combine

// MARK: - Profile Storage Adapter Protocol

/// Storage abstraction for persisting and retrieving GameProfile collections.
public protocol ProfileStorageAdapter: Sendable {
    func loadProfiles() throws -> [GameProfile]
    func saveProfiles(_ profiles: [GameProfile]) throws
}

// MARK: - Production Disk Storage Adapter

public final class DiskProfileStorageAdapter: ProfileStorageAdapter, @unchecked Sendable {
    public let fileURL: URL

    public init(fileURL: URL? = nil) {
        if let customURL = fileURL {
            self.fileURL = customURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let appFolder = appSupport.appendingPathComponent("SubAndCast", isDirectory: true)
            try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
            self.fileURL = appFolder.appendingPathComponent("profiles.json")
        }
    }

    public func loadProfiles() throws -> [GameProfile] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([GameProfile].self, from: data)
    }

    public func saveProfiles(_ profiles: [GameProfile]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(profiles)
        try data.write(to: fileURL, options: .atomic)
    }
}

// MARK: - In-Memory Test Storage Adapter

public final class InMemoryProfileStorageAdapter: ProfileStorageAdapter, @unchecked Sendable {
    private var storedProfiles: [GameProfile]
    private let lock = NSLock()
    private var _saveCount: Int = 0

    public var saveCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _saveCount
    }

    public init(initialProfiles: [GameProfile] = []) {
        self.storedProfiles = initialProfiles
    }

    public func loadProfiles() throws -> [GameProfile] {
        lock.lock()
        defer { lock.unlock() }
        return storedProfiles
    }

    public func saveProfiles(_ profiles: [GameProfile]) throws {
        lock.lock()
        defer { lock.unlock() }
        self.storedProfiles = profiles
        self._saveCount += 1
    }
}

// MARK: - Profile Store Protocol

@MainActor
public protocol ProfileStoreProtocol: AnyObject {
    var profiles: [GameProfile] { get }
    var activeProfile: GameProfile { get }

    func selectProfile(id: UUID)
    func addProfile(name: String) -> GameProfile
    func deleteProfile(id: UUID)
    func updateActiveProfile(_ mutate: (inout GameProfile) -> Void)
    func updateProfile(id: UUID, _ mutate: (inout GameProfile) -> Void)
    func scheduleAutoSave()
    func flush()
}

// MARK: - Deep Profile Store Implementation

@MainActor
public final class ProfileStore: ObservableObject, ProfileStoreProtocol {
    public static let shared = ProfileStore()

    @Published public private(set) var profiles: [GameProfile] = []
    @Published public private(set) var activeProfile: GameProfile = GameProfile()

    private let storage: ProfileStorageAdapter
    private var debouncedSaveTask: Task<Void, Never>?
    private let debounceNanoseconds: UInt64

    public init(
        storage: ProfileStorageAdapter = DiskProfileStorageAdapter(),
        debounceNanoseconds: UInt64 = 300_000_000
    ) {
        self.storage = storage
        self.debounceNanoseconds = debounceNanoseconds
        loadAndHeal()
    }

    private func loadAndHeal() {
        let loaded: [GameProfile]
        do {
            loaded = try storage.loadProfiles()
        } catch {
            print("Failed to load profiles from storage: \(error). Using default.")
            loaded = []
        }

        var validated = loaded.map { healProfile($0) }
        if validated.isEmpty {
            let defaultProfile = GameProfile(name: "Default Game")
            validated = [defaultProfile]
            try? storage.saveProfiles(validated)
        }

        self.profiles = validated
        self.activeProfile = validated.first!
    }

    private func healProfile(_ profile: GameProfile) -> GameProfile {
        var healed = profile
        healed.sourceRect = CodableRect(
            x: profile.sourceRect.x,
            y: profile.sourceRect.y,
            width: max(CodableRect.minWidth, profile.sourceRect.width),
            height: max(CodableRect.minHeight, profile.sourceRect.height)
        )
        healed.displayRect = CodableRect(
            x: profile.displayRect.x,
            y: profile.displayRect.y,
            width: max(CodableRect.minWidth, profile.displayRect.width),
            height: max(CodableRect.minHeight, profile.displayRect.height)
        )
        return healed
    }

    public func selectProfile(id: UUID) {
        guard let target = profiles.first(where: { $0.id == id }) else { return }
        self.activeProfile = target
        scheduleAutoSave()
    }

    @discardableResult
    public func addProfile(name: String) -> GameProfile {
        let newProfile = GameProfile(name: name)
        let healed = healProfile(newProfile)
        profiles.append(healed)
        activeProfile = healed
        scheduleAutoSave()
        return healed
    }

    public func deleteProfile(id: UUID) {
        guard profiles.count > 1 else { return }
        profiles.removeAll(where: { $0.id == id })
        if activeProfile.id == id {
            activeProfile = profiles.first ?? GameProfile()
        }
        scheduleAutoSave()
    }

    public func updateActiveProfile(_ mutate: (inout GameProfile) -> Void) {
        var copy = activeProfile
        mutate(&copy)
        let healed = healProfile(copy)
        self.activeProfile = healed

        if let idx = profiles.firstIndex(where: { $0.id == healed.id }) {
            profiles[idx] = healed
        } else {
            profiles.append(healed)
        }
        scheduleAutoSave()
    }

    public func updateProfile(id: UUID, _ mutate: (inout GameProfile) -> Void) {
        guard let idx = profiles.firstIndex(where: { $0.id == id }) else { return }
        var copy = profiles[idx]
        mutate(&copy)
        let healed = healProfile(copy)
        profiles[idx] = healed

        if activeProfile.id == id {
            activeProfile = healed
        }
        scheduleAutoSave()
    }

    public func scheduleAutoSave() {
        debouncedSaveTask?.cancel()
        debouncedSaveTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            if self.debounceNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: self.debounceNanoseconds)
            }
            guard !Task.isCancelled else { return }
            self.persistSync()
        }
    }

    public func flush() {
        debouncedSaveTask?.cancel()
        debouncedSaveTask = nil
        persistSync()
    }

    private func persistSync() {
        do {
            try storage.saveProfiles(profiles)
        } catch {
            print("ProfileStore: Failed to persist profiles: \(error)")
        }
    }
}
