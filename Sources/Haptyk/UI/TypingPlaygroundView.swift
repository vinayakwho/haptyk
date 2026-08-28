import CHaptykAudio
import SwiftUI

public struct TypingPlaygroundView: View {
    @ObservedObject var engine = HaptykEngine.shared
    @ObservedObject var packManager = SoundPackManager.shared
    @ObservedObject var kb = KeyboardMonitor.shared
    
    @State private var typedText: String = ""
    @State private var softCount: Int = 0
    @State private var mediumCount: Int = 0
    @State private var hardCount: Int = 0
    @State private var slamCount: Int = 0
    
    private let sampleQuotes = [
        "The quick brown fox jumps over the lazy dog.",
        "Sphinx of black quartz, judge my vow.",
        "Haptyk detects how hard you type on your MacBook and plays the matching mechanical keyboard sound in real time.",
        "Pack my box with five dozen liquor jugs."
    ]
    @State private var currentQuoteIndex = 0
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 16) {
            // Target quote prompt
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("SAMPLE SENTENCE (TYPE BELOW):")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Next Sentence") {
                        currentQuoteIndex = (currentQuoteIndex + 1) % sampleQuotes.count
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                }
                
                Text(sampleQuotes[currentQuoteIndex])
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .foregroundColor(.primary.opacity(0.85))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(8)
            }
            .padding(12)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
            .cornerRadius(10)
            
            // Text Editor Playground
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Live Typing Area", systemImage: "keyboard")
                        .font(.system(size: 12, weight: .bold))
                    Spacer()
                    if !typedText.isEmpty {
                        Button("Clear") {
                            typedText = ""
                            softCount = 0
                            mediumCount = 0
                            hardCount = 0
                            slamCount = 0
                        }
                        .font(.system(size: 11))
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                    }
                }
                
                TextEditor(text: $typedText)
                    .font(.system(size: 14, design: .monospaced))
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.7))
                    .cornerRadius(8)
                    .frame(height: 120)
                    .onChange(of: engine.lastEvent?.id) { _ in
                        guard let ev = engine.lastEvent else { return }
                        switch ev.tier {
                        case .soft: softCount += 1
                        case .medium: mediumCount += 1
                        case .hard: hardCount += 1
                        case .slam: slamCount += 1
                        }
                    }
            }
            .padding(12)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
            .cornerRadius(10)
            
            // Live Stats & Breakdown
            HStack(spacing: 12) {
                // Tier distribution
                HStack(spacing: 8) {
                    PlaygroundTierStat(name: "Soft", count: softCount, color: .blue)
                    PlaygroundTierStat(name: "Medium", count: mediumCount, color: .green)
                    PlaygroundTierStat(name: "Hard", count: hardCount, color: .orange)
                    PlaygroundTierStat(name: "Slam", count: slamCount, color: .red)
                }
                .frame(maxWidth: .infinity)
                .padding(10)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
                .cornerRadius(10)
                
                // Speed & Count
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SPEED")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                        Text(String(format: "%.0f WPM", kb.currentWPM))
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundColor(.purple)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CHARS")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                        Text("\(typedText.count)")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)
                    }
                }
                .padding(10)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
                .cornerRadius(10)
            }
        }
    }
}

struct PlaygroundTierStat: View {
    let name: String
    let count: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(name)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(color)
            Text("\(count)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(color.opacity(0.08))
        .cornerRadius(6)
    }
}
