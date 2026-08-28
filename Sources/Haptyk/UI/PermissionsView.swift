import CHaptykAudio
import SwiftUI

public struct PermissionsView: View {
    @ObservedObject var kb = KeyboardMonitor.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: kb.hasAccessibilityPermission ? "checkmark.shield.fill" : "lock.shield.fill")
                .font(.system(size: 48))
                .foregroundColor(kb.hasAccessibilityPermission ? .green : .orange)
            
            VStack(spacing: 6) {
                Text(kb.hasAccessibilityPermission ? "Permissions Granted" : "Accessibility Permission Required")
                    .font(.system(size: 16, weight: .bold))
                
                Text(kb.hasAccessibilityPermission
                     ? "Haptyk is ready to detect keystrokes and force across your entire system."
                     : "macOS requires Accessibility permission so Haptyk can detect keystrokes in any application.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            if !kb.hasAccessibilityPermission {
                VStack(spacing: 10) {
                    Button(action: {
                        kb.requestPermissions()
                    }) {
                        Label("Grant Accessibility Access", systemImage: "hand.tap.fill")
                            .font(.system(size: 13, weight: .bold))
                            .frame(maxWidth: 240)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button(action: {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        Text("Open System Settings > Privacy > Accessibility")
                            .font(.system(size: 11))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                HStack(spacing: 6) {
                    Circle().fill(Color.green).frame(width: 8, height: 8)
                    Text("Global Event Tap Active")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.green)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
        .cornerRadius(12)
    }
}
