import CHaptykAudio
import SwiftUI

public struct DashboardView: View {
    @ObservedObject var engine = HaptykEngine.shared
    @ObservedObject var packManager = SoundPackManager.shared
    @ObservedObject var kb = KeyboardMonitor.shared
    @State private var selectedTab: DashboardTab = .switches
    
    public enum DashboardTab: String, CaseIterable, Identifiable {
        case switches = "Switches"
        case visualizer = "Live Telemetry"
        case tuning = "Sensitivity"
        case playground = "Playground"
        case permissions = "Permissions"
        
        public var id: String { rawValue }
        
        public var icon: String {
            switch self {
            case .switches: return "square.grid.2x2.fill"
            case .visualizer: return "waveform.path.ecg"
            case .tuning: return "slider.horizontal.3"
            case .playground: return "keyboard.fill"
            case .permissions: return "shield.lefthalf.filled"
            }
        }
    }
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Permission Alert Banner if Accessibility not yet enabled
            if !kb.hasAccessibilityPermission {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 14))
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Accessibility Permission Required for System-Wide Typing")
                            .font(.system(size: 12, weight: .bold))
                        Text("Enable Haptyk in System Settings so mechanical keyboard sounds play in Safari, Notes, VS Code, and every app.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        kb.requestPermissions()
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        Text("Enable in System Settings")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.orange.opacity(0.12))
                
                Divider()
            }
            
            // Top Bar
            HStack(spacing: 16) {
                // App Brand
                HStack(spacing: 10) {
                    Image(systemName: "keyboard.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.accentColor)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Haptyk")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                        Text("Velocity-Sensitive Mechanical Keyboard for MacBook")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Active Switch Pill
                if let pack = packManager.selectedPack {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(hex: pack.color) ?? .accentColor)
                            .frame(width: 10, height: 10)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(pack.name)
                                .font(.system(size: 12, weight: .bold))
                            Text(pack.category)
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(8)
                }
                
                // Master Mute Button
                Button(action: { engine.isMuted.toggle() }) {
                    Image(systemName: engine.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .foregroundColor(engine.isMuted ? .red : .primary)
                        .font(.system(size: 13))
                        .padding(8)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                // Import Pack Button
                Button(action: openPackImportDialog) {
                    Label("Import Pack", systemImage: "plus")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            // Tab Selector
            HStack(spacing: 6) {
                ForEach(DashboardTab.allCases) { tab in
                    Button(action: { selectedTab = tab }) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 12))
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: selectedTab == tab ? .bold : .medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(selectedTab == tab ? Color.accentColor : Color.clear)
                        .foregroundColor(selectedTab == tab ? .white : .secondary)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            // Tab Content
            Group {
                switch selectedTab {
                case .switches:
                    SwitchCatalogView()
                case .visualizer:
                    LiveVisualizerView()
                case .tuning:
                    SensitivityTuningView()
                case .playground:
                    TypingPlaygroundView()
                case .permissions:
                    PermissionsView()
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(minWidth: 780, minHeight: 560)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private func openPackImportDialog() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = []
        if panel.runModal() == .OK, let url = panel.url {
            _ = packManager.importPack(from: url)
        }
    }
}
