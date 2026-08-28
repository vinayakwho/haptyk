import QuartzCore
import CHaptykAudio
import Foundation
import Combine
import SwiftUI

public enum VelocityTier: String, CaseIterable, Identifiable {
    case soft = "Soft"
    case medium = "Medium"
    case hard = "Hard"
    case slam = "Slam"
    
    public var id: String { rawValue }
    
    public var color: Color {
        switch self {
        case .soft: return Color.blue
        case .medium: return Color.green
        case .hard: return Color.orange
        case .slam: return Color.red
        }
    }
}

public struct KeystrokeEventInfo: Identifiable {
    public let id = UUID()
    public let keyName: String
    public let keyGroup: HaptykBridgeKeyGroup
    public let velocity: Double
    public let rawForce: Double
    public let tier: VelocityTier
    public let timestamp: TimeInterval
}

public final class HaptykEngine: ObservableObject, KeyboardMonitorDelegate, @unchecked Sendable {
    public static let shared = HaptykEngine()
    
    @Published public var masterVolume: Double = 0.95 {
        didSet {
            HaptykAudioBridge.shared().masterVolume = Float(masterVolume)
            UserDefaults.standard.set(masterVolume, forKey: "MasterVolume")
        }
    }
    
    @Published public var releaseVolume: Double = 0.60 {
        didSet {
            HaptykAudioBridge.shared().releaseVolume = Float(releaseVolume)
            UserDefaults.standard.set(releaseVolume, forKey: "ReleaseVolume")
        }
    }
    
    @Published public var isReleaseEnabled: Bool = true {
        didSet {
            HaptykAudioBridge.shared().releaseEnabled = isReleaseEnabled
            UserDefaults.standard.set(isReleaseEnabled, forKey: "IsReleaseEnabled")
        }
    }
    
    @Published public var isMuted: Bool = false {
        didSet {
            HaptykAudioBridge.shared().isMuted = isMuted
        }
    }
    
    // Sensitivity Tuning parameters
    @Published public var softThreshold: Double = 0.15 {
        didSet { UserDefaults.standard.set(softThreshold, forKey: "SoftThreshold") }
    }
    @Published public var hardThreshold: Double = 0.65 {
        didSet { UserDefaults.standard.set(hardThreshold, forKey: "HardThreshold") }
    }
    @Published public var slamMultiplier: Double = 1.15 {
        didSet { UserDefaults.standard.set(slamMultiplier, forKey: "SlamMultiplier") }
    }
    @Published public var dynamicFlightWeight: Double = 0.50 {
        didSet { UserDefaults.standard.set(dynamicFlightWeight, forKey: "DynamicFlightWeight") }
    }
    
    // Live Telemetry
    @Published public private(set) var lastEvent: KeystrokeEventInfo?
    @Published public private(set) var recentEvents: [KeystrokeEventInfo] = []
    @Published public private(set) var currentVelocity: Double = 0.50
    @Published public private(set) var currentTier: VelocityTier = .medium
    @Published public private(set) var velocityHistory: [Double] = Array(repeating: 0.50, count: 50)
    
    public let motionSensor = MotionSensor.shared
    public let keyboardMonitor = KeyboardMonitor.shared
    public let soundPackManager = SoundPackManager.shared
    public let audioBridge = HaptykAudioBridge.shared()
    
    private init() {
        // Load saved preferences
        if let savedVol = UserDefaults.standard.object(forKey: "MasterVolume") as? Double {
            self.masterVolume = savedVol
        }
        if let savedRelVol = UserDefaults.standard.object(forKey: "ReleaseVolume") as? Double {
            self.releaseVolume = savedRelVol
        }
        if let savedRelEn = UserDefaults.standard.object(forKey: "IsReleaseEnabled") as? Bool {
            self.isReleaseEnabled = savedRelEn
        }
        if let savedSoft = UserDefaults.standard.object(forKey: "SoftThreshold") as? Double {
            self.softThreshold = savedSoft
        }
        if let savedHard = UserDefaults.standard.object(forKey: "HardThreshold") as? Double {
            self.hardThreshold = savedHard
        }
        if let savedSlam = UserDefaults.standard.object(forKey: "SlamMultiplier") as? Double {
            self.slamMultiplier = savedSlam
        }
        if let savedFlight = UserDefaults.standard.object(forKey: "DynamicFlightWeight") as? Double {
            self.dynamicFlightWeight = savedFlight
        }
        
        keyboardMonitor.delegate = self
        _ = audioBridge.startEngine()
        audioBridge.masterVolume = Float(self.masterVolume)
        audioBridge.releaseVolume = Float(self.releaseVolume)
        audioBridge.releaseEnabled = self.isReleaseEnabled
        
        keyboardMonitor.startMonitoring()
    }
    
    public func keyboardMonitorDidDetectKeyDown(keyCode: UInt16, keyGroup: HaptykBridgeKeyGroup, timestamp: TimeInterval, estimatedDwellFlightVelocity: Double) {
        // Sample chassis accelerometer impulse
        let rawForce = motionSensor.getImpactVelocity(at: timestamp, fallbackFlightDwell: estimatedDwellFlightVelocity)
        
        // Compute hybrid blended velocity: (1 - weight) * Accel + weight * FlightDynamics
        let blendedForce = (1.0 - dynamicFlightWeight) * rawForce + dynamicFlightWeight * estimatedDwellFlightVelocity
        
        // Map smoothly from [0.1, 0.85] -> [0.20, 1.0]
        let baseVel = max(0.18, min(1.0, blendedForce * slamMultiplier))
        let finalVelocity = baseVel
        
        // Determine Velocity Tier
        let tier: VelocityTier
        if finalVelocity < 0.35 {
            tier = .soft
        } else if finalVelocity < 0.68 {
            tier = .medium
        } else if finalVelocity < 0.88 {
            tier = .hard
        } else {
            tier = .slam
        }
        
        // Zero-latency audio trigger directly in C CoreAudio
        audioBridge.playKey(with: keyGroup, velocity: Float(finalVelocity))
        
        let keyName = keyboardMonitor.readableKeyName(for: keyCode)
        let event = KeystrokeEventInfo(
            keyName: keyName,
            keyGroup: keyGroup,
            velocity: finalVelocity,
            rawForce: rawForce,
            tier: tier,
            timestamp: timestamp
        )
        
        DispatchQueue.main.async {
            self.lastEvent = event
            self.currentVelocity = finalVelocity
            self.currentTier = tier
            
            var events = self.recentEvents
            events.insert(event, at: 0)
            if events.count > 25 { events.removeLast() }
            self.recentEvents = events
            
            var history = self.velocityHistory
            history.removeFirst()
            history.append(finalVelocity)
            self.velocityHistory = history
        }
    }
    
    public func keyboardMonitorDidDetectKeyUp(keyCode: UInt16, keyGroup: HaptykBridgeKeyGroup, timestamp: TimeInterval) {
        if isReleaseEnabled {
            audioBridge.playRelease()
        }
    }
    
    public func testPlayKey(group: HaptykBridgeKeyGroup, velocity: Double) {
        let now = CACurrentMediaTime()
        motionSensor.injectImpulse(intensity: velocity)
        keyboardMonitorDidDetectKeyDown(keyCode: 49, keyGroup: group, timestamp: now, estimatedDwellFlightVelocity: velocity)
    }
}
