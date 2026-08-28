import QuartzCore
import CHaptykAudio
import Cocoa
import Carbon
import Combine
import IOKit.hid

public protocol KeyboardMonitorDelegate: AnyObject {
    func keyboardMonitorDidDetectKeyDown(keyCode: UInt16, keyGroup: HaptykBridgeKeyGroup, timestamp: TimeInterval, estimatedDwellFlightVelocity: Double)
    func keyboardMonitorDidDetectKeyUp(keyCode: UInt16, keyGroup: HaptykBridgeKeyGroup, timestamp: TimeInterval)
}

public final class KeyboardMonitor: ObservableObject, @unchecked Sendable {
    public static let shared = KeyboardMonitor()
    
    public weak var delegate: KeyboardMonitorDelegate?
    
    @Published public private(set) var isMonitoring: Bool = false
    @Published public private(set) var hasAccessibilityPermission: Bool = false
    @Published public private(set) var lastPressedKeyName: String = "—"
    @Published public private(set) var lastPressedKeyCode: UInt16 = 0
    @Published public private(set) var currentWPM: Double = 0.0
    @Published public private(set) var totalKeystrokeCount: Int = 0
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var hidManager: IOHIDManager?
    
    private var permissionTimer: Timer?
    
    // Keystroke timing tracking
    private var lastKeyDownTime: TimeInterval = 0.0
    private var keyDownTimestamps: [UInt16: TimeInterval] = [:]
    private var recentIntervals: [TimeInterval] = []
    private var lastProcessedEventTime: TimeInterval = 0.0
    private let lock = NSLock()
    
    public init() {
        _ = checkPermissions()
        startMonitoring()
        startPermissionWatcher()
    }
    
    public func checkPermissions() -> Bool {
        let trusted = AXIsProcessTrusted()
        DispatchQueue.main.async {
            self.hasAccessibilityPermission = trusted
        }
        return trusted
    }
    
    public func requestPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options)
        DispatchQueue.main.async {
            self.hasAccessibilityPermission = trusted
            if trusted {
                self.setupCGEventTap()
                self.setupGlobalNSEventMonitor()
            }
        }
    }
    
    private func startPermissionWatcher() {
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let trusted = AXIsProcessTrusted()
            if trusted != self.hasAccessibilityPermission {
                DispatchQueue.main.async {
                    self.hasAccessibilityPermission = trusted
                }
                if trusted {
                    self.setupCGEventTap()
                    self.setupGlobalNSEventMonitor()
                }
            }
        }
    }
    
    public func startMonitoring() {
        setupCGEventTap()
        setupGlobalNSEventMonitor()
        setupLocalNSEventMonitor()
        setupIOHIDKeyboardManager()
        
        DispatchQueue.main.async {
            self.isMonitoring = (self.eventTap != nil || self.globalMonitor != nil || self.hidManager != nil)
        }
    }
    
    private func setupCGEventTap() {
        if eventTap != nil { return }
        
        let eventMask = (1 << CGEventType.keyDown.rawValue) |
                        (1 << CGEventType.keyUp.rawValue) |
                        (1 << CGEventType.flagsChanged.rawValue)
        
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        
        // Try session tap first, then fallback to HID tap
        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(refcon).takeUnretainedValue()
                
                // Re-enable tap if disabled by system timeout or user input
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let t = monitor.eventTap {
                        CGEvent.tapEnable(tap: t, enable: true)
                    }
                    return Unmanaged.passUnretained(event)
                }
                
                monitor.handleCGEvent(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: selfPtr
        )
        
        if let tap = tap {
            self.eventTap = tap
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            self.runLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            print("[KeyboardMonitor] ✓ CGEventTap successfully activated globally!")
        }
    }
    
    private func setupGlobalNSEventMonitor() {
        if globalMonitor != nil { return }
        
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            self?.handleNSEvent(event)
        }
        if globalMonitor != nil {
            print("[KeyboardMonitor] ✓ NSEvent Global Monitor registered!")
        }
    }
    
    private func setupLocalNSEventMonitor() {
        if localMonitor != nil { return }
        
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            self?.handleNSEvent(event)
            return event
        }
    }
    
    private func setupIOHIDKeyboardManager() {
        if hidManager != nil { return }
        
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        
        let matchingDict: [String: Any] = [
            kIOHIDDeviceUsagePageKey as String: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey as String: kHIDUsage_GD_Keyboard
        ]
        
        IOHIDManagerSetDeviceMatching(manager, matchingDict as CFDictionary)
        
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        
        IOHIDManagerRegisterInputValueCallback(manager, { (context, result, sender, value) in
            guard let context = context else { return }
            let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(context).takeUnretainedValue()
            let elem = IOHIDValueGetElement(value)
            let usagePage = IOHIDElementGetUsagePage(elem)
            let usage = IOHIDElementGetUsage(elem)
            let intVal = IOHIDValueGetIntegerValue(value)
            
            if usagePage == kHIDPage_KeyboardOrKeypad && usage >= 4 && usage <= 231 {
                let now = CACurrentMediaTime()
                // Only use IOHID if event tap hasn't triggered recently
                if now - monitor.lastProcessedEventTime > 0.008 {
                    let keyCode = monitor.hidUsageToKeyCode(UInt16(usage))
                    let group = monitor.keyGroup(for: keyCode)
                    if intVal == 1 {
                        monitor.processKeyDown(keyCode: keyCode, keyGroup: group, timestamp: now)
                    } else if intVal == 0 {
                        monitor.processKeyUp(keyCode: keyCode, keyGroup: group, timestamp: now)
                    }
                }
            }
        }, selfPtr)
        
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        let status = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if status == kIOReturnSuccess {
            self.hidManager = manager
            print("[KeyboardMonitor] ✓ IOHIDManager keyboard driver initialized!")
        }
    }
    
    public func stopMonitoring() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let src = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
            }
            self.eventTap = nil
            self.runLoopSource = nil
        }
        if let gm = globalMonitor {
            NSEvent.removeMonitor(gm)
            self.globalMonitor = nil
        }
        if let lm = localMonitor {
            NSEvent.removeMonitor(lm)
            self.localMonitor = nil
        }
        if let hm = hidManager {
            IOHIDManagerClose(hm, IOOptionBits(kIOHIDOptionsTypeNone))
            self.hidManager = nil
        }
        permissionTimer?.invalidate()
        permissionTimer = nil
        
        DispatchQueue.main.async {
            self.isMonitoring = false
        }
    }
    
    private func handleCGEvent(type: CGEventType, event: CGEvent) {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let now = CACurrentMediaTime()
        let group = keyGroup(for: keyCode)
        
        if type == .keyDown {
            processKeyDown(keyCode: keyCode, keyGroup: group, timestamp: now)
        } else if type == .keyUp {
            processKeyUp(keyCode: keyCode, keyGroup: group, timestamp: now)
        } else if type == .flagsChanged {
            let flags = event.flags
            let isDown = flags.contains(.maskShift) || flags.contains(.maskControl) || flags.contains(.maskAlternate) || flags.contains(.maskCommand)
            if isDown {
                processKeyDown(keyCode: keyCode, keyGroup: .modifier, timestamp: now)
            } else {
                processKeyUp(keyCode: keyCode, keyGroup: .modifier, timestamp: now)
            }
        }
    }
    
    private func handleNSEvent(_ event: NSEvent) {
        let keyCode = event.keyCode
        let now = CACurrentMediaTime()
        let group = keyGroup(for: keyCode)
        
        // Debounce if CGEvent already handled this timestamp
        if now - lastProcessedEventTime < 0.003 { return }
        
        if event.type == .keyDown {
            processKeyDown(keyCode: keyCode, keyGroup: group, timestamp: now)
        } else if event.type == .keyUp {
            processKeyUp(keyCode: keyCode, keyGroup: group, timestamp: now)
        } else if event.type == .flagsChanged {
            let flags = event.modifierFlags
            let isDown = flags.contains(.shift) || flags.contains(.control) || flags.contains(.option) || flags.contains(.command)
            if isDown {
                processKeyDown(keyCode: keyCode, keyGroup: .modifier, timestamp: now)
            } else {
                processKeyUp(keyCode: keyCode, keyGroup: .modifier, timestamp: now)
            }
        }
    }
    
    private func processKeyDown(keyCode: UInt16, keyGroup: HaptykBridgeKeyGroup, timestamp: TimeInterval) {
        lock.lock()
        if timestamp - lastProcessedEventTime < 0.003 && keyCode == lastPressedKeyCode {
            lock.unlock()
            return
        }
        lastProcessedEventTime = timestamp
        
        let dt = (lastKeyDownTime > 0) ? (timestamp - lastKeyDownTime) : 0.2
        lastKeyDownTime = timestamp
        keyDownTimestamps[keyCode] = timestamp
        
        var dynamicFlightVel = 0.55
        if dt > 0 && dt < 0.6 {
            recentIntervals.append(dt)
            if recentIntervals.count > 10 {
                recentIntervals.removeFirst()
            }
            let avgDt = recentIntervals.reduce(0, +) / Double(recentIntervals.count)
            dynamicFlightVel = max(0.25, min(0.98, 1.0 - (avgDt - 0.04) / 0.30))
        }
        lock.unlock()
        
        let keyName = readableKeyName(for: keyCode)
        
        DispatchQueue.main.async {
            self.lastPressedKeyName = keyName
            self.lastPressedKeyCode = keyCode
            self.totalKeystrokeCount += 1
            self.updateWPM(timestamp: timestamp)
        }
        
        delegate?.keyboardMonitorDidDetectKeyDown(
            keyCode: keyCode,
            keyGroup: keyGroup,
            timestamp: timestamp,
            estimatedDwellFlightVelocity: dynamicFlightVel
        )
    }
    
    private func processKeyUp(keyCode: UInt16, keyGroup: HaptykBridgeKeyGroup, timestamp: TimeInterval) {
        lock.lock()
        keyDownTimestamps.removeValue(forKey: keyCode)
        lock.unlock()
        
        delegate?.keyboardMonitorDidDetectKeyUp(keyCode: keyCode, keyGroup: keyGroup, timestamp: timestamp)
    }
    
    private func updateWPM(timestamp: TimeInterval) {
        if recentIntervals.count > 3 {
            let avgDt = recentIntervals.reduce(0, +) / Double(recentIntervals.count)
            if avgDt > 0.03 {
                let cps = 1.0 / avgDt
                let wpm = (cps * 60.0) / 5.0
                self.currentWPM = min(220.0, wpm)
            }
        }
    }
    
    public func keyGroup(for keyCode: UInt16) -> HaptykBridgeKeyGroup {
        switch keyCode {
        case 49: return .spacebar
        case 36, 76: return .enter
        case 51, 117: return .backspace
        case 54, 55, 56, 57, 58, 59, 60, 61, 62, 63: return .modifier
        default: return .standard
        }
    }
    
    public func hidUsageToKeyCode(_ usage: UInt16) -> UInt16 {
        switch usage {
        case 0x04: return 0   // A
        case 0x05: return 11  // B
        case 0x06: return 8   // C
        case 0x07: return 2   // D
        case 0x08: return 14  // E
        case 0x09: return 3   // F
        case 0x0A: return 5   // G
        case 0x0B: return 4   // H
        case 0x0C: return 34  // I
        case 0x0D: return 38  // J
        case 0x0E: return 40  // K
        case 0x0F: return 37  // L
        case 0x10: return 46  // M
        case 0x11: return 45  // N
        case 0x12: return 31  // O
        case 0x13: return 35  // P
        case 0x14: return 12  // Q
        case 0x15: return 15  // R
        case 0x16: return 1   // S
        case 0x17: return 17  // T
        case 0x18: return 32  // U
        case 0x19: return 9   // V
        case 0x1A: return 13  // W
        case 0x1B: return 7   // X
        case 0x1C: return 16  // Y
        case 0x1D: return 6   // Z
        case 0x1E: return 18  // 1
        case 0x1F: return 19  // 2
        case 0x20: return 20  // 3
        case 0x21: return 21  // 4
        case 0x22: return 23  // 5
        case 0x23: return 22  // 6
        case 0x24: return 26  // 7
        case 0x25: return 28  // 8
        case 0x26: return 25  // 9
        case 0x27: return 29  // 0
        case 0x28: return 36  // Return
        case 0x29: return 53  // Escape
        case 0x2A: return 51  // Delete
        case 0x2B: return 48  // Tab
        case 0x2C: return 49  // Spacebar
        default: return 0
        }
    }
    
    public func readableKeyName(for keyCode: UInt16) -> String {
        switch keyCode {
        case 49: return "Space"
        case 36: return "Return"
        case 76: return "Enter"
        case 51: return "Delete"
        case 53: return "Esc"
        case 48: return "Tab"
        case 56, 60: return "Shift"
        case 55, 54: return "Command"
        case 58, 61: return "Option"
        case 59, 62: return "Control"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 45: return "N"
        case 46: return "M"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 17: return "T"
        case 16: return "Y"
        case 32: return "U"
        case 34: return "I"
        case 31: return "O"
        case 35: return "P"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 23: return "5"
        case 22: return "6"
        case 26: return "7"
        case 28: return "8"
        case 25: return "9"
        case 29: return "0"
        default: return "Key \(keyCode)"
        }
    }
}
