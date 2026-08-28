import CHaptykAudio
import SwiftUI

public struct SensitivityTuningView: View {
    @ObservedObject var engine = HaptykEngine.shared
    @ObservedObject var sensor = MotionSensor.shared
    
    public init() {}
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 18) {
                // Presets Bar
                HStack(spacing: 10) {
                    Text("CALIBRATION PRESETS:")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    PresetButton(title: "Light & Gentle") {
                        engine.softThreshold = 0.12
                        engine.hardThreshold = 0.50
                        engine.slamMultiplier = 1.35
                        engine.dynamicFlightWeight = 0.50
                    }
                    
                    PresetButton(title: "Default MacBook") {
                        engine.softThreshold = 0.20
                        engine.hardThreshold = 0.70
                        engine.slamMultiplier = 1.20
                        engine.dynamicFlightWeight = 0.40
                    }
                    
                    PresetButton(title: "Heavy Typist / Slam") {
                        engine.softThreshold = 0.30
                        engine.hardThreshold = 0.85
                        engine.slamMultiplier = 1.00
                        engine.dynamicFlightWeight = 0.25
                    }
                    
                    Spacer()
                }
                .padding(12)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
                .cornerRadius(10)
                
                // Audio Engine Controls
                VStack(alignment: .leading, spacing: 14) {
                    Label("Acoustic Levels & Upstroke Releases", systemImage: "speaker.wave.2.fill")
                        .font(.system(size: 13, weight: .bold))
                    
                    VStack(spacing: 12) {
                        SliderRow(
                            title: "Master Volume",
                            value: $engine.masterVolume,
                            range: 0.0...1.5,
                            format: "%.0f%%",
                            scale: 100,
                            description: "Overall mechanical switch acoustic gain."
                        )
                        
                        Divider().opacity(0.3)
                        
                        HStack {
                            Toggle("Key Release (Upstroke) Clicks", isOn: $engine.isReleaseEnabled)
                                .font(.system(size: 12, weight: .medium))
                            Spacer()
                        }
                        
                        if engine.isReleaseEnabled {
                            SliderRow(
                                title: "Release Click Volume",
                                value: $engine.releaseVolume,
                                range: 0.0...1.0,
                                format: "%.0f%%",
                                scale: 100,
                                description: "Volume of switch stem returning to top housing upon key release."
                            )
                        }
                    }
                }
                .padding(14)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
                .cornerRadius(12)
                
                // Impact & Velocity Sensitivity Curve
                VStack(alignment: .leading, spacing: 14) {
                    Label("Force Detection & Dynamic Velocity Curve", systemImage: "slider.horizontal.3")
                        .font(.system(size: 13, weight: .bold))
                    
                    VStack(spacing: 12) {
                        SliderRow(
                            title: "Soft Force Threshold",
                            value: $engine.softThreshold,
                            range: 0.05...0.45,
                            format: "%.2f g",
                            scale: 2.0,
                            description: "Minimum impact impulse required to transition out of soft tier."
                        )
                        
                        Divider().opacity(0.3)
                        
                        SliderRow(
                            title: "Hard Force Threshold",
                            value: $engine.hardThreshold,
                            range: 0.40...0.95,
                            format: "%.2f g",
                            scale: 2.0,
                            description: "Impulse level that triggers hard bottom-out clacks."
                        )
                        
                        Divider().opacity(0.3)
                        
                        SliderRow(
                            title: "Slam Multiplier",
                            value: $engine.slamMultiplier,
                            range: 0.8...2.0,
                            format: "%.1fx",
                            scale: 1.0,
                            description: "Amplification factor for maximum impact slams."
                        )
                        
                        Divider().opacity(0.3)
                        
                        SliderRow(
                            title: "Keystroke Timing vs Chassis Accel",
                            value: $engine.dynamicFlightWeight,
                            range: 0.0...1.0,
                            format: "%.0f%% Timing",
                            scale: 100,
                            description: "Balance between physical chassis accelerometer and keystroke flight dynamics."
                        )
                    }
                }
                .padding(14)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
                .cornerRadius(12)
            }
            .padding(.bottom, 16)
        }
    }
}

struct PresetButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.accentColor.opacity(0.15))
                .foregroundColor(.accentColor)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: String
    let scale: Double
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(String(format: format, value * scale))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.accentColor)
            }
            
            Slider(value: $value, in: range)
            
            Text(description)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
}
