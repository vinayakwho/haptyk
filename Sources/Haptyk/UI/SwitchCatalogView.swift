import CHaptykAudio
import SwiftUI

public struct SwitchCatalogView: View {
    @ObservedObject var packManager = SoundPackManager.shared
    @ObservedObject var engine = HaptykEngine.shared
    @State private var selectedFilter: String = "All"
    @State private var searchText: String = ""
    
    private let categories = ["All", "Linear", "Clicky", "Tactile", "IBM Model M", "Electrostatic", "Thick Click"]
    
    public init() {}
    
    var filteredPacks: [SoundPackInfo] {
        packManager.availablePacks.filter { pack in
            let matchesCat = (selectedFilter == "All") || (pack.category.lowercased().contains(selectedFilter.lowercased()))
            let matchesSearch = searchText.isEmpty || pack.name.localizedCaseInsensitiveContains(searchText) || pack.description.localizedCaseInsensitiveContains(searchText)
            return matchesCat && matchesSearch
        }
    }
    
    public var body: some View {
        VStack(spacing: 14) {
            // Filter Bar & Search
            HStack(spacing: 12) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categories, id: \.self) { cat in
                            Button(action: { selectedFilter = cat }) {
                                Text(cat)
                                    .font(.system(size: 12, weight: selectedFilter == cat ? .bold : .medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedFilter == cat ? Color.accentColor : Color.primary.opacity(0.06))
                                    .foregroundColor(selectedFilter == cat ? .white : .primary)
                                    .cornerRadius(16)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Spacer()
                
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                    TextField("Search switches...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.06))
                .cornerRadius(8)
                .frame(width: 180)
            }
            
            // Switch Cards Grid
            ScrollView(.vertical, showsIndicators: true) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 14)], spacing: 14) {
                    ForEach(filteredPacks) { pack in
                        SwitchCard(
                            pack: pack,
                            isSelected: packManager.selectedPack?.id == pack.id,
                            onSelect: {
                                packManager.selectPack(pack)
                            },
                            onPreview: { keyGroup, velocity in
                                if packManager.selectedPack?.id != pack.id {
                                    packManager.selectPack(pack)
                                }
                                engine.testPlayKey(group: keyGroup, velocity: velocity)
                            }
                        )
                    }
                }
                .padding(.bottom, 16)
            }
        }
    }
}

struct SwitchCard: View {
    let pack: SoundPackInfo
    let isSelected: Bool
    let onSelect: () -> Void
    let onPreview: (HaptykBridgeKeyGroup, Double) -> Void
    
    var packColor: Color {
        Color(hex: pack.color) ?? .blue
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(packColor)
                        .frame(width: 14, height: 14)
                    
                    Text(pack.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Text(pack.category)
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(packColor.opacity(0.18))
                    .foregroundColor(packColor)
                    .cornerRadius(6)
            }
            
            // Specs
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "scalemass.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(pack.actuation_force)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.to.line.compact")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(pack.travel)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            Text(pack.description)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            
            Divider().opacity(0.4)
            
            // Force Previews & Activation
            HStack {
                Text("TEST:")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 6) {
                    PreviewButton(title: "Soft", color: .blue) {
                        onPreview(.standard, 0.20)
                    }
                    PreviewButton(title: "Med", color: .green) {
                        onPreview(.standard, 0.50)
                    }
                    PreviewButton(title: "Hard", color: .orange) {
                        onPreview(.standard, 0.78)
                    }
                    PreviewButton(title: "Slam", color: .red) {
                        onPreview(.standard, 0.98)
                    }
                    PreviewButton(title: "Space", color: packColor) {
                        onPreview(.spacebar, 0.85)
                    }
                }
                
                Spacer()
                
                Button(action: onSelect) {
                    HStack(spacing: 4) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Active")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.green)
                        } else {
                            Text("Select")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(isSelected ? Color.green.opacity(0.12) : Color.primary.opacity(0.08))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color(nsColor: .windowBackgroundColor).opacity(isSelected ? 0.9 : 0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? packColor : Color.primary.opacity(0.08), lineWidth: isSelected ? 2 : 1)
        )
    }
}

struct PreviewButton: View {
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(color.opacity(0.15))
                .foregroundColor(color)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let length = hexSanitized.count
        if length == 6 {
            let r = Double((rgb & 0xFF0000) >> 16) / 255.0
            let g = Double((rgb & 0x00FF00) >> 8) / 255.0
            let b = Double(rgb & 0x0000FF) / 255.0
            self.init(red: r, green: g, blue: b)
        } else {
            return nil
        }
    }
}
