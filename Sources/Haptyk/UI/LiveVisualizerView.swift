import CHaptykAudio
import SwiftUI

public struct LiveVisualizerView: View {
    @ObservedObject var engine = HaptykEngine.shared
    @ObservedObject var sensor = MotionSensor.shared
    @ObservedObject var kb = KeyboardMonitor.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 18) {
            // Header Stats Row
            HStack(spacing: 16) {
                StatCard(
                    title: "CURRENT FORCE",
                    value: String(format: "%.0f%%", engine.currentVelocity * 100),
                    subtitle: engine.currentTier.rawValue.uppercased(),
                    color: engine.currentTier.color,
                    icon: "bolt.fill"
                )
                
                StatCard(
                    title: "PEAK IMPULSE",
                    value: String(format: "%.2f g", sensor.peakForce * 2.5),
                    subtitle: sensor.isSensorActive ? "M1+ ACCELEROMETER (~1000Hz)" : "DYNAMICS FALLBACK",
                    color: .cyan,
                    icon: "waveform.path.ecg"
                )
                
                StatCard(
                    title: "TYPING SPEED",
                    value: String(format: "%.0f WPM", kb.currentWPM),
                    subtitle: "\(kb.totalKeystrokeCount) KEYSTROKES",
                    color: .purple,
                    icon: "keyboard"
                )
                
                StatCard(
                    title: "AUDIO ENGINE",
                    value: "< 1 ms",
                    subtitle: "COREAUDIO C THREAD",
                    color: .green,
                    icon: "speaker.wave.3.fill"
                )
            }
            
            // Real-Time Waveform & Impact Meter
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Real-Time Chassis Accelerometer Waveform (~1,000 reads/sec)", systemImage: "waveform.path.badge.plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(sensor.isSensorActive ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(sensor.isSensorActive ? "M1+ Chassis Sensor Active" : "Hybrid Mode")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                    
                    // Grid lines
                    VStack {
                        Divider().opacity(0.3)
                        Spacer()
                        Divider().opacity(0.3)
                        Spacer()
                        Divider().opacity(0.3)
                    }
                    .padding(.vertical, 8)
                    
                    // Waveform graph
                    GeometryReader { geo in
                        Path { path in
                            let width = geo.size.width
                            let height = geo.size.height
                            let step = width / CGFloat(max(1, sensor.recentSamples.count - 1))
                            
                            for (index, val) in sensor.recentSamples.enumerated() {
                                let x = CGFloat(index) * step
                                let y = height - (CGFloat(val) * (height - 12) + 6)
                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(
                            LinearGradient(
                                colors: [.blue, .cyan, .green, .orange, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                        )
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
                .frame(height: 100)
            }
            .padding(14)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
            .cornerRadius(12)
            
            // Velocity Tier Meters & Live Key Activity
            HStack(spacing: 16) {
                // Tier distribution gauge
                VStack(alignment: .leading, spacing: 10) {
                    Text("VELOCITY TIERS & CROSSFADE")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 8) {
                        TierBar(name: "Slam", range: "> 88%", color: .red, active: engine.currentTier == .slam, value: engine.currentTier == .slam ? engine.currentVelocity : 0.0)
                        TierBar(name: "Hard", range: "66% - 88%", color: .orange, active: engine.currentTier == .hard, value: engine.currentTier == .hard ? engine.currentVelocity : 0.0)
                        TierBar(name: "Medium", range: "33% - 66%", color: .green, active: engine.currentTier == .medium, value: engine.currentTier == .medium ? engine.currentVelocity : 0.0)
                        TierBar(name: "Soft", range: "< 33%", color: .blue, active: engine.currentTier == .soft, value: engine.currentTier == .soft ? engine.currentVelocity : 0.0)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
                .cornerRadius(12)
                
                // Recent Keystrokes Log
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("LIVE KEYSTROKE IMPACTS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("LAST 25 EVENTS")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 6) {
                            if engine.recentEvents.isEmpty {
                                Text("Press keys on your keyboard to test...")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.top, 20)
                            } else {
                                ForEach(engine.recentEvents) { ev in
                                    HStack {
                                        Text(ev.keyName)
                                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.primary.opacity(0.08))
                                            .cornerRadius(4)
                                        
                                        Text(keyGroupLabel(ev.keyGroup))
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                        
                                        Spacer()
                                        
                                        Text(String(format: "%.0f%% force", ev.velocity * 100))
                                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                                        
                                        Text(ev.tier.rawValue)
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(ev.tier.color)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(ev.tier.color.opacity(0.15))
                                            .cornerRadius(4)
                                    }
                                }
                            }
                        }
                    }
                    .frame(height: 110)
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
                .cornerRadius(12)
            }
        }
    }
    
    private func keyGroupLabel(_ g: HaptykBridgeKeyGroup) -> String {
        switch g {
        case .spacebar: return "Spacebar"
        case .enter: return "Enter"
        case .backspace: return "Backspace"
        case .modifier: return "Modifier"
        default: return "Standard"
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
            }
            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundColor(.primary)
            Text(subtitle)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(color)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.6))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

struct TierBar: View {
    let name: String
    let range: String
    let color: Color
    let active: Bool
    let value: Double
    
    var body: some View {
        HStack(spacing: 8) {
            Text(name)
                .font(.system(size: 11, weight: active ? .bold : .medium))
                .foregroundColor(active ? color : .primary)
                .frame(width: 55, alignment: .leading)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                    
                    if active {
                        Capsule()
                            .fill(color)
                            .frame(width: max(8, geo.size.width * CGFloat(value)))
                    }
                }
            }
            .frame(height: 8)
            
            Text(range)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .trailing)
        }
    }
}
