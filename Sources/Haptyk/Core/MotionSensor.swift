import QuartzCore
import CHaptykAudio
import Foundation
import IOKit
import Combine

public struct MotionSample: Sendable {
    public let timestamp: TimeInterval
    public let x: Double
    public let y: Double
    public let z: Double
    public let magnitude: Double
    public let jerk: Double
}

public final class MotionSensor: ObservableObject, @unchecked Sendable {
    public static let shared = MotionSensor()
    
    @Published public private(set) var isSensorActive: Bool = false
    @Published public private(set) var currentForce: Double = 0.0
    @Published public private(set) var peakForce: Double = 0.0
    @Published public private(set) var recentSamples: [Double] = Array(repeating: 0.0, count: 64)
    
    private var clientRef: UnsafeMutableRawPointer? = nil
    private var lastX: Double = 0.0
    private var lastY: Double = 0.0
    private var lastZ: Double = 1.0
    private var lastTimestamp: TimeInterval = 0.0
    
    // Circular ring buffer for impact correlation (1000 samples = 1 sec buffer)
    private let bufferCapacity = 1024
    private var sampleRing: [MotionSample] = []
    private var ringHead: Int = 0
    private let lock = NSLock()
    
    // Function pointers for private IOHID symbols
    private typealias ClientCreateFunc = @convention(c) (CFAllocator?, Int32, CFDictionary?) -> UnsafeMutableRawPointer?
    private typealias CopyServicesFunc = @convention(c) (UnsafeMutableRawPointer) -> CFArray?
    private typealias CopyPropFunc = @convention(c) (UnsafeMutableRawPointer, CFString) -> CFTypeRef?
    private typealias SetPropFunc = @convention(c) (UnsafeMutableRawPointer, CFString, CFTypeRef) -> Bool
    private typealias RegCallbackFunc = @convention(c) (UnsafeMutableRawPointer, @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void, UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void
    private typealias SchedQueueFunc = @convention(c) (UnsafeMutableRawPointer, DispatchQueue) -> Void
    private typealias UnschedQueueFunc = @convention(c) (UnsafeMutableRawPointer, DispatchQueue) -> Void
    private typealias GetFloatFunc = @convention(c) (UnsafeMutableRawPointer, Int32) -> Double
    private typealias GetTypeFunc = @convention(c) (UnsafeMutableRawPointer) -> Int32
    
    private var copyServices: CopyServicesFunc?
    private var copyProp: CopyPropFunc?
    private var setProp: SetPropFunc?
    private var getFloat: GetFloatFunc?
    private var getType: GetTypeFunc?
    
    private var simulatedTimer: Timer?
    private var lastSimulatedImpactTime: TimeInterval = 0.0
    private var simulatedImpulseDecay: Double = 0.0
    
    public init() {
        sampleRing = Array(repeating: MotionSample(timestamp: 0, x: 0, y: 0, z: 1.0, magnitude: 1.0, jerk: 0), count: bufferCapacity)
        loadIOKitSymbols()
    }
    
    private func loadIOKitSymbols() {
        guard let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW) else {
            return
        }
        
        let createSym = dlsym(handle, "IOHIDEventSystemClientCreateWithType")
        let copySvcsSym = dlsym(handle, "IOHIDEventSystemClientCopyServices")
        let copyPropSym = dlsym(handle, "IOHIDServiceClientCopyProperty")
        let setPropSym = dlsym(handle, "IOHIDServiceClientSetProperty")
        let regSym = dlsym(handle, "IOHIDEventSystemClientRegisterEventCallback")
        let schedSym = dlsym(handle, "IOHIDEventSystemClientScheduleWithDispatchQueue")
        let getFloatSym = dlsym(handle, "IOHIDEventGetFloatValue")
        let getTypeSym = dlsym(handle, "IOHIDEventGetType")
        
        if let copySvcsSym = copySvcsSym { copyServices = unsafeBitCast(copySvcsSym, to: CopyServicesFunc.self) }
        if let copyPropSym = copyPropSym { copyProp = unsafeBitCast(copyPropSym, to: CopyPropFunc.self) }
        if let setPropSym = setPropSym { setProp = unsafeBitCast(setPropSym, to: SetPropFunc.self) }
        if let getFloatSym = getFloatSym { getFloat = unsafeBitCast(getFloatSym, to: GetFloatFunc.self) }
        if let getTypeSym = getTypeSym { getType = unsafeBitCast(getTypeSym, to: GetTypeFunc.self) }
        
        if let createSym = createSym {
            let createFunc = unsafeBitCast(createSym, to: ClientCreateFunc.self)
            // Client type 3 (IOHIDEventSystemClientTypePassive/Admin)
            if let client = createFunc(kCFAllocatorDefault, 3, nil) {
                self.clientRef = client
                
                // Configure sensor report interval to 1000Hz (1ms)
                if let copyServices = copyServices, let copyProp = copyProp, let setProp = setProp {
                    if let services = copyServices(client) as? [UnsafeMutableRawPointer] {
                        for service in services {
                            let page = copyProp(service, "PrimaryUsagePage" as CFString) as? Int ?? 0
                            let usage = copyProp(service, "PrimaryUsage" as CFString) as? Int ?? 0
                            if page == 0x20 || (page == 0x01 && usage == 0x06) {
                                _ = setProp(service, "ReportInterval" as CFString, 1000 as CFNumber)
                            }
                        }
                    }
                }
                
                if let regSym = regSym, let schedSym = schedSym {
                    let regFunc = unsafeBitCast(regSym, to: RegCallbackFunc.self)
                    let schedFunc = unsafeBitCast(schedSym, to: SchedQueueFunc.self)
                    
                    let contextPtr = Unmanaged.passUnretained(self).toOpaque()
                    
                    regFunc(client, { (target, context, service, event) in
                        guard let context = context, let event = event else { return }
                        let sensor = Unmanaged<MotionSensor>.fromOpaque(context).takeUnretainedValue()
                        sensor.handleHIDEvent(event)
                    }, contextPtr, nil)
                    
                    schedFunc(client, DispatchQueue.main)
                    DispatchQueue.main.async {
                        self.isSensorActive = true
                    }
                }
            }
        }
    }
    
    private func handleHIDEvent(_ event: UnsafeMutableRawPointer) {
        guard let getType = getType, let getFloat = getFloat else { return }
        let type = getType(event)
        
        let x = getFloat(event, (type << 16) | 0)
        let y = getFloat(event, (type << 16) | 1)
        let z = getFloat(event, (type << 16) | 2)
        
        let now = CACurrentMediaTime()
        recordRawReading(x: x, y: y, z: z, timestamp: now)
    }
    
    public func recordRawReading(x: Double, y: Double, z: Double, timestamp: TimeInterval) {
        let dx = x - lastX
        let dy = y - lastY
        let dz = z - lastZ
        let dt = max(0.0005, timestamp - lastTimestamp)
        
        lastX = x
        lastY = y
        lastZ = z
        lastTimestamp = timestamp
        
        let jerk = sqrt(dx*dx + dy*dy + dz*dz) / dt
        let mag = sqrt(x*x + y*y + z*z)
        
        let sample = MotionSample(timestamp: timestamp, x: x, y: y, z: z, magnitude: mag, jerk: jerk)
        
        lock.lock()
        sampleRing[ringHead % bufferCapacity] = sample
        ringHead += 1
        lock.unlock()
        
        // Normalize force for UI visualizer
        let normForce = min(1.0, jerk / 15.0)
        DispatchQueue.main.async {
            self.currentForce = normForce
            if normForce > self.peakForce {
                self.peakForce = normForce
            } else {
                self.peakForce = max(0, self.peakForce * 0.95)
            }
            
            var arr = self.recentSamples
            arr.removeFirst()
            arr.append(normForce)
            self.recentSamples = arr
        }
    }
    
    /// Correlates keystroke time with accelerometer jerk spike within ±15ms window
    public func getImpactVelocity(at timestamp: TimeInterval, fallbackFlightDwell: Double = 0.5) -> Double {
        lock.lock()
        defer { lock.unlock() }
        
        var maxJerk: Double = 0.0
        let windowStart = timestamp - 0.018
        let windowEnd = timestamp + 0.018
        
        let head = ringHead
        let count = min(head, bufferCapacity)
        
        for i in 0..<count {
            let idx = (head - 1 - i + bufferCapacity) % bufferCapacity
            let s = sampleRing[idx]
            if s.timestamp >= windowStart && s.timestamp <= windowEnd {
                if s.jerk > maxJerk {
                    maxJerk = s.jerk
                }
            } else if s.timestamp < windowStart && i > 20 {
                break
            }
        }
        
        if maxJerk > 0.1 {
            // Accelerometer registered actual chassis shockwave
            // Map jerk from [0.5, 20.0] -> [0.1, 1.0]
            let norm = (maxJerk - 0.2) / 18.0
            return max(0.1, min(1.0, norm))
        }
        
        // If accelerometer jerk below noise threshold (e.g. ultra-light touch or external keyboard),
        // blend with keystroke dynamics
        return fallbackFlightDwell
    }
    
    /// Inject simulated impact impulse for testing or desktop Macs
    public func injectImpulse(intensity: Double) {
        let now = CACurrentMediaTime()
        let jerk = intensity * 18.0
        let sample = MotionSample(timestamp: now, x: 0, y: 0, z: 1.0 + intensity, magnitude: 1.0 + intensity, jerk: jerk)
        
        lock.lock()
        sampleRing[ringHead % bufferCapacity] = sample
        ringHead += 1
        lock.unlock()
        
        DispatchQueue.main.async {
            self.currentForce = intensity
            self.peakForce = max(self.peakForce, intensity)
            var arr = self.recentSamples
            arr.removeFirst()
            arr.append(intensity)
            self.recentSamples = arr
        }
    }
}
