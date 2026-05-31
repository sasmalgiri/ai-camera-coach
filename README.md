# AI Camera Coach

> Take professional-looking photos without learning photography.

AI Camera Coach is an iOS camera app that combines an **AI Coach** (which tells you what to do) with an **AI Photographer** (which decides when to capture for you). Everything runs on-device, with no accounts, no ads, and no tracking.

**Price:** $4.99 — one-time purchase.

---

## Modes

| Mode | What it optimizes for |
|---|---|
| **Smart** | General-purpose AI capture |
| **Family** | Group shots — waits for everyone's eyes open |
| **Child** | Moving kids and unpredictable expressions |
| **Pet** | Animal faces, fast subjects |
| **Travel** | Landmarks, scenery, horizon-level framing |

## Features

- **Live photo scoring** — a 0–100 quality score updated in real time
- **Plain-language coaching** — "move closer," "turn toward light," not ISO or EV
- **AI auto-capture** — the app fires the shutter when confidence is high enough
- **Automatic correction** — exposure, white balance, color, tone
- **Before/After gallery** — long-press a saved photo to compare with the original
- **100% on-device** — Vision + Core Image, no cloud calls

## Requirements

- iOS 18+ (built and tested against iOS 26.5)
- Xcode 26+
- A device with a rear camera (the camera doesn't work in the simulator)

## Build & Run

1. Open `original photo and ai assistant.xcodeproj` in Xcode.
2. Select a real iOS device as the run destination.
3. Add the following keys to the target's **Info** tab (Build Settings > Info.plist values) if not already present:
   - `NSCameraUsageDescription` — *"AI Camera Coach uses the camera to capture photos and guide you toward great shots."*
   - `NSPhotoLibraryAddUsageDescription` — *"AI Camera Coach saves your photos to your library so you can keep them."*
4. Build and run.

## Architecture

```
original photo and ai assistant/
├── Models/          # CaptureMode, PhotoEntry, PhotoScore, SceneAnalysis, CoachSuggestion
├── Camera/          # AVFoundation session and preview view
├── AI/              # SceneAnalyzer (Vision), PhotoScorer, CoachAdvisor, AutoCorrector, AIPhotographer
├── Storage/         # PhotoLibraryStore (local JPEG + JSON index)
├── ViewModels/      # CameraViewModel (Observable, MainActor)
└── Views/           # SwiftUI screens
```

- SwiftUI + the `@Observable` macro (no Combine)
- Strict concurrency / `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
- AVFoundation runs on a dedicated `nonisolated` service; delegate callbacks hop to MainActor

## Privacy

- No accounts. No login. No analytics.
- All scene analysis is on-device.
- Photos are saved to your app's local Documents directory; you control them.

## License

Copyright © 2026. All rights reserved.
