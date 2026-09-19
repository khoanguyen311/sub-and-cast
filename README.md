# Sub & Cast 🎮 💬

A lightweight, native macOS menu-bar application designed for **real-time game subtitle OCR and on-screen translation overlay**.

**Sub & Cast** is engineered specifically for macOS using pure Swift, SwiftUI, and Apple's hardware-accelerated frameworks.

---

## 🌟 Key Highlights

- **Neural On-Device OCR**: Uses Apple's native **Vision Framework** (`VNRecognizeTextRequest`) to extract Japanese, Chinese, Korean, Vietnamese, and European languages using the Apple Silicon Neural Engine. Zero latency, 100% offline, zero API costs.
- **Hardware-Accelerated Screen Capture**: Leverages Apple's **ScreenCaptureKit** with automatic fallbacks for optimal frame capture performance.
- **Smart Perceptual Frame Diffing**: Computes downscaled image hashes before performing OCR to avoid wasteful compute cycles and eliminate redundant translation requests when dialogue hasn't changed.
- **Smart Dialogue Persistence**: Subtitles stay locked on screen at 100% opacity while dialogue remains present, and only trigger the fadeout grace period once the in-game dialogue box closes.
- **Configurable Global Hotkeys**: Carbon Events-based shortcut engine allowing custom key combinations for *Toggle Auto Scan* and *Toggle Positioning Mode* that work seamlessly inside full-screen games without requiring macOS Accessibility permissions.
- **Free & Flexible Translation Options**:
  - **Google Translate (Free Web API)**: Works out-of-the-box with zero configuration or API key.
  - **Apple Native Translation**: On-device offline translation for macOS 15+.
- **Floating Overlays with Click-Through**:
  - **Source Capture Zone**: Resizable & draggable box placed directly over the game's dialogue area.
  - **Subtitle Display Zone**: Floating, customizable subtitle HUD with backdrop opacity, text outline, and safe inset padding.
  - **Lock / Click-Through Mode**: Overlay windows become completely transparent to mouse events during playback so game controls are never interrupted.
- **Game Profiles**: Automatically saves window positions, sizes, languages, and timings per game in `~/Library/Application Support/SubAndCast/profiles.json`.

---

## 🚀 Getting Started

### 1. Build & Run from Terminal

To run directly during development:
```bash
swift run SubAndCast
```

To run the automated verification test suite:
```bash
swift run SubAndCastTests
```

### 2. Build as a macOS `.app` Application

To package a standalone `SubAndCast.app`:
```bash
./scripts/build_app.sh
open SubAndCast.app
```

> **Note on Permissions**: The first time you capture the screen, macOS will prompt for **Screen Recording** permission in *System Settings → Privacy & Security → Screen Recording*. Enable `SubAndCast` (or your terminal application if running via `swift run`) and restart the app.

---

## 🎮 How to Use While Playing

1. **Launch the App**:
   - On launch, the **Preferences** window opens. Overlays remain hidden until activated.
2. **Configure Global Hotkeys**:
   - In the **General** tab under **Global Shortcuts**, assign your preferred shortcuts for:
     * **Toggle Auto Scan**
     * **Toggle Positioning Mode**
3. **Position the Zones**:
   - Click **Position** in the **Capture & Overlays** tab (or trigger your positioning hotkey).
   - Drag and resize the **cyan dashed box** over your game's dialogue area.
   - Drag and resize the **orange dashed box** where you want translated subtitles to appear.
   - Click **Save & Done** (in the overlay header or Preferences) to lock the positions.
4. **Start Auto-Scan & Play**:
   - Trigger your configured **Toggle Auto Scan** hotkey (or click **Scan** in Preferences / menu bar).
   - Subtitles float seamlessly over your game, remain visible while you read dialogue, and gracefully fade out after the dialogue box closes.
5. **Preferences**:
   - Use the in-window tab strip (**General**, **Translation**, **Capture & Overlays**) to customize languages, timings, font size, backdrop opacity, and game profiles.
