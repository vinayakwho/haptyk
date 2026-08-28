# Haptyk ⚡️
### The Velocity‑Sensitive Mechanical Keyboard Your MacBook Was Missing.

![macOS 13+](https://img.shields.io/badge/platform-macOS%2013%2B-blue.svg)
![Apple Silicon](https://img.shields.io/badge/architecture-Apple%20Silicon%20(M1%2FM2%2FM3%2FM4)-teal.svg)
![Audio Latency](https://img.shields.io/badge/latency-%3C%201ms%20(Pure%20C)-emerald.svg)
![Switch Packs](https://img.shields.io/badge/switches-16%20Packs-orange.svg)
![License](https://img.shields.io/badge/license-MIT-purple.svg)

Haptyk detects how hard you type on your MacBook using the internal chassis accelerometer (~1,000 reads/sec) and plays matching mechanical keyboard switch sounds in real time.

**Type softly, hear a soft click. Slam a key, hear the slam.**

---

## 🚀 Key Features

- **Chassis Accelerometer Impact Detection**: Reads real physical typing impact ~1,000 times per second directly from Apple Silicon internal sensors (`IOHIDEventSystemClient`).
- **Sub-Millisecond Zero-Latency Audio Engine**: Pure C CoreAudio real-time thread (`kAudioUnitSubType_DefaultOutput`) with zero garbage collection overhead.
- **32-Voice Polyphony**: Fast burst typing, rolls, and key releases without dropped clicks.
- **Continuous Velocity Crossfade**: Smoothly scales between **Soft**, **Medium**, **Hard**, and **Slam** velocity tiers with organic micro-pitch variations.
- **16 Curated Switch Sound Packs**:
  1. **Alpaca** (Smooth linear)
  2. **Blue Alps** (Vintage clicky)
  3. **Buckling Spring** (IBM Model M metallic ping & clack)
  4. **Cherry MX Black PBT** (Heavy linear)
  5. **Cherry MX Blue PBT** (Crisp clicky)
  6. **Cherry MX Brown PBT** (Tactile bump)
  7. **Cherry MX Red PBT** (Light linear)
  8. **EG Crystal Purple** (Snappy tactile)
  9. **Gateron Black Ink** (Ultra-deep bass thock)
  10. **Gateron Red Ink V2** (Velvety linear)
  11. **Holy Panda** (Snappy tactile pop)
  12. **Kailh Box Navy** (Thick clickbar)
  13. **NK Cream** (POM-on-POM clack)
  14. **Topre PBT** (Electrostatic capacitive dome thock)
  15. **Turquoise Tealios** (Silky linear clack)
  16. **Biscuit** (Warm, round tactile)
- **Key Groups Support**: Distinct acoustic profiles for **Spacebar** (deep stabilizer clack), **Enter**, **Backspace**, **Modifiers**, and **Standard Keys**.
- **Key-Up Release Clicks**: Realistic stem return sounds upon releasing keys.
- **Modern macOS SwiftUI Dashboard & Menu Bar App**: Live 60fps accelerometer visualizer, switch catalog, sensitivity tuner, and typing playground.

---

## 🛠️ Architecture

```
Haptyk/
├── Haptyk.app/                     # Packaged macOS App Bundle
├── Sources/
│   ├── CHaptykAudio/               # Pure C CoreAudio Real-Time Sound Engine
│   │   ├── include/
│   │   │   ├── HaptykAudioCore.h
│   │   │   └── HaptykAudioBridge.h
│   │   ├── HaptykAudioCore.c
│   │   └── HaptykAudioBridge.m
│   └── Haptyk/
│       ├── App/                    # AppDelegate & App Entry
│       ├── Core/                   # MotionSensor, KeyboardMonitor, HaptykEngine
│       ├── UI/                     # SwiftUI Views (Visualizer, Catalog, Tuning, MenuBar)
│       └── Resources/
│           ├── AppIcon.icns        # High-res macOS App Icon
│           └── SoundPacks/         # 16 Switch Audio Packs (48kHz Stereo PCM)
├── Tools/
│   └── generate_soundpacks.py      # High-fidelity switch acoustic synthesis tool
└── web/                            # Interactive Web Showcase (Vercel Ready)
    ├── public/
    │   ├── index.html              # Live Web Audio mechanical switch playground
    │   └── audio/                  # Audio samples
    └── vercel.json                 # Vercel deployment configuration
```

---

## 📦 Building and Running

### Prerequisites
- macOS 13.0+ (Ventura, Sonoma, Sequoia, Tahoe)
- Xcode Command Line Tools (`clang`, `swiftc`)

### Build macOS App Bundle
```bash
./bundle_app.sh
```

### Launch Haptyk
```bash
open Haptyk.app
```

> **Accessibility Note**: To play mechanical switch sounds across all applications (Safari, Notes, VS Code, Terminal), enable **Haptyk** under **System Settings > Privacy & Security > Accessibility**.

---

## 🌐 Deploy to Vercel

The `web/` directory contains an interactive Web Audio mechanical switch emulator and landing page ready for zero-config Vercel deployment:

```bash
cd web
npx vercel
```

Or connect the repository to [Vercel](https://vercel.com) with the root directory set to `web`.

---

## 📄 License
MIT License. Copyright © 2026 Haptyk.
