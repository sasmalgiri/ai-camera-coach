# AI Camera Coach — v2.0

> Take professional-looking photos without learning photography.

AI Camera Coach is an iOS camera app that combines an **AI Coach** (which tells you what to do) with an **AI Photographer** (which decides when to capture for you). Everything runs on-device by default, with no accounts, no ads, and no tracking.

**Price:** $4.99 — one-time purchase.

---

## What's new in v2.0

- **Mixture-of-Experts hybrid AI** — 7 parallel Apple-trained Vision experts (face, OCR, classification, horizon, saliency, animal, aesthetics) + NaturalLanguage feed into multiple parallel Apple Intelligence sessions (map-reduce synthesis)
- **Cloud LLM vision coaching** — when you opt in with your own OpenAI or Anthropic key, the model sees the actual frame
- **Composition overlays** — rule-of-thirds grid + live horizon level indicator via CoreMotion
- **Tap-to-focus + tap-to-expose** with animated reticle
- **Pinch-to-zoom** with smooth ramp-up to device max
- **Self-timer** (3 s / 10 s) with countdown
- **Proactive coach** — surfaces the top tip automatically when your score drops below 45
- **Mode auto-detect** — banner suggests switching to Family / Travel when the scene calls for it
- **Save to Photos library** (opt-in)
- **Before/After slider** in the gallery — drag to compare original vs enhanced
- **Multi-select + share + batch delete** in the gallery
- **Voice tips** (off by default) — speaks the top tip aloud for tripod/selfie shooting
- **App Intents / Shortcuts** — *"Hey Siri, open AI Camera Coach in Pet mode"*
- **Thermal throttling** — analysis frequency adapts to device temperature
- **Haptics** on capture, mode change, AI photographer fires, selection
- **Privacy promise page** — explicit "what we do / what we don't do"

## Modes

| Mode | What it optimizes for |
|---|---|
| **Original** | Raw camera — no enhancement |
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
