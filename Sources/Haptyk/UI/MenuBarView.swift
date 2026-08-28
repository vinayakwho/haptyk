import CHaptykAudio
import SwiftUI

public struct MenuBarView: View {
    @ObservedObject var engine = HaptykEngine.shared
    @ObservedObject var packManager = SoundPackManager.shared
    @ObservedObject var sensor = MotionSensor.shared
    
    var onOpenDashboard: () -> Void
    
    public init(onOpenDashboard: @escaping () -> Void) {
        self.onOpenDashboard = onOpenDashboard
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "keyboard.fill")
                        .foregroundColor(.accentColor)
                    Text("Haptyk")
                        .font(.system(size: 14, weight: .bold))
                }
                
                Spacer()
                
                Button(action: { engine.isMuted.toggle() }) {
                    Image(systemName: engine.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .foregroundColor(engine.isMuted ? .red : .primary)
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            // Switch Selector
            VStack(alignment: .leading, spacing: 6) {
                Text("SWITCH SOUND PACK")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                
                Menu {
                    ForEach(packManager.availablePacks) { pack in
                        Button(action: { packManager.selectPack(pack) }) {
                            HStack {
                                Text(pack.name)
                                if packManager.selectedPack?.id == pack.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        if let selected = packManager.selectedPack {
                            Circle()
                                .fill(Color(hex: selected.color) ?? .accentColor)
                                .frame(width: 8, height: 8)
                            Text(selected.name)
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                            Text(selected.category)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        } else {
                            Text("Select Sound Pack...")
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(6)
                }
            }
            
            // Real-Time Force Indicator
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("FORCE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(engine.currentTier.rawValue)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(engine.currentTier.color)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.08))
                        Capsule()
                            .fill(engine.currentTier.color)
                            .frame(width: max(4, geo.size.width * CGFloat(engine.currentVelocity)))
                    }
                }
                .frame(height: 6)
            }
            
            // Master Volume
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("VOLUME")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.0f%%", engine.masterVolume * 100))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                }
                
                Slider(value: $engine.masterVolume, in: 0.0...1.2)
            }
            
            Divider()
            
            // Action Buttons
            HStack(spacing: 8) {
                Button(action: onOpenDashboard) {
                    Label("Dashboard", systemImage: "slider.horizontal.below.rectangle")
                        .font(.system(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Text("Quit")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
            }
        }
        .padding(14)
        .frame(width: 260)
    }
}
