import CHaptykAudio
import Foundation
import Combine

public struct SoundPackInfo: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let category: String
    public let actuation_force: String
    public let travel: String
    public let description: String
    public let color: String
    public let has_release: Bool
    public let tiers: [String]
    public let key_groups: [String]
    
    public var directoryURL: URL? = nil
    
    enum CodingKeys: String, CodingKey {
        case id, name, category, actuation_force, travel, description, color, has_release, tiers, key_groups
    }
}

public final class SoundPackManager: ObservableObject, @unchecked Sendable {
    public static let shared = SoundPackManager()
    
    @Published public private(set) var availablePacks: [SoundPackInfo] = []
    @Published public private(set) var selectedPack: SoundPackInfo?
    @Published public private(set) var isLoadingPack: Bool = false
    
    private let appSupportURL: URL
    
    public init() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Haptyk", isDirectory: true)
            .appendingPathComponent("Packs", isDirectory: true)
        
        self.appSupportURL = appSupport
        try? fileManager.createDirectory(at: appSupport, withIntermediateDirectories: true)
        
        loadAllPacks()
    }
    
    public func loadAllPacks() {
        var packs: [SoundPackInfo] = []
        
        // 1. Check Bundle Resources or Relative Dev Resources
        var resourceURLs: [URL] = []
        if let bundleResources = Bundle.main.resourceURL?.appendingPathComponent("SoundPacks", isDirectory: true) {
            resourceURLs.append(bundleResources)
        }
        
        // Direct App resources if packaged in .app
        if let execURL = Bundle.main.executableURL {
            let appBundleRes = execURL.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/SoundPacks", isDirectory: true)
            resourceURLs.append(appBundleRes)
        }
        
        // Dev path fallback
        let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let devResource = currentDir.appendingPathComponent("Sources/Haptyk/Resources/SoundPacks", isDirectory: true)
        resourceURLs.append(devResource)
        let rootResource = currentDir.appendingPathComponent("Haptyk.app/Contents/Resources/SoundPacks", isDirectory: true)
        resourceURLs.append(rootResource)
        
        for rootURL in resourceURLs {
            let manifestURL = rootURL.appendingPathComponent("manifest.json")
            if let data = try? Data(contentsOf: manifestURL),
               let loaded = try? JSONDecoder().decode([SoundPackInfo].self, from: data) {
                for var p in loaded {
                    p.directoryURL = rootURL.appendingPathComponent(p.id, isDirectory: true)
                    if !packs.contains(where: { $0.id == p.id }) {
                        packs.append(p)
                    }
                }
                if !packs.isEmpty {
                    print("[SoundPackManager] Loaded \(packs.count) packs from \(rootURL.path)")
                    break
                }
            }
        }
        
        // 2. Check Application Support user packs
        if let userPacks = try? FileManager.default.contentsOfDirectory(at: appSupportURL, includingPropertiesForKeys: nil) {
            for dir in userPacks where dir.hasDirectoryPath {
                let infoURL = dir.appendingPathComponent("info.json")
                if let data = try? Data(contentsOf: infoURL),
                   var p = try? JSONDecoder().decode(SoundPackInfo.self, from: data) {
                    p.directoryURL = dir
                    if !packs.contains(where: { $0.id == p.id }) {
                        packs.append(p)
                    }
                }
            }
        }
        
        self.availablePacks = packs
        
        // Restore last selected or first
        let savedId = UserDefaults.standard.string(forKey: "SelectedSoundPackId") ?? "holy_panda"
        let packToSelect = packs.first(where: { $0.id == savedId }) ?? packs.first
        if let target = packToSelect {
            self.selectPack(target)
        }
    }
    
    public func selectPack(byId id: String) {
        if let pack = availablePacks.first(where: { $0.id == id }) {
            selectPack(pack)
        }
    }
    
    public func selectPack(_ pack: SoundPackInfo) {
        guard let dir = pack.directoryURL else { return }
        self.isLoadingPack = true
        
        print("[SoundPackManager] Activating pack: \(pack.name) from \(dir.path)")
        let success = HaptykAudioBridge.shared().loadSoundPack(
            fromDirectory: dir.path,
            packId: pack.id,
            name: pack.name
        )
        
        DispatchQueue.main.async {
            self.isLoadingPack = false
            if success {
                self.selectedPack = pack
                UserDefaults.standard.set(pack.id, forKey: "SelectedSoundPackId")
                print("[SoundPackManager] Successfully loaded sound pack: \(pack.name)")
            } else {
                print("[SoundPackManager] Failed to load sound pack: \(pack.name)")
            }
        }
    }
    
    public func importPack(from fileURL: URL) -> Bool {
        let isDir = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
        let packName = fileURL.deletingPathExtension().lastPathComponent
        let targetDir = appSupportURL.appendingPathComponent(packName, isDirectory: true)
        
        do {
            try? FileManager.default.removeItem(at: targetDir)
            if isDir {
                try FileManager.default.copyItem(at: fileURL, to: targetDir)
            } else {
                return false
            }
            loadAllPacks()
            selectPack(byId: packName)
            return true
        } catch {
            print("Failed to import pack: \(error)")
            return false
        }
    }
}
