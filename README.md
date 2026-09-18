# Sub & Cast 🎮 💬

A lightweight, native macOS menu-bar application designed for **real-time game subtitle OCR and on-screen translation overlay**.

Inspired by [OCR-Translator](https://github.com/tomkam1702/OCR-Translator), **Sub & Cast** is engineered specifically for macOS using pure Swift, SwiftUI, and Apple's hardware-accelerated frameworks.

---

## 🌟 Key Highlights

- **Neural On-Device OCR**: Uses Apple's native **Vision Framework** (`VNRecognizeTextRequest`) to extract Japanese, Chinese, Korean, and European languages using the Apple Silicon Neural Engine. Zero latency, 100% offline, zero API costs.
- **Hardware-Accelerated Screen Capture**: Leverages Apple's **ScreenCaptureKit** with automatic fallbacks for optimal frame capture performance.
- **Smart Perceptual Frame Diffing**: Computes downscaled image hashes before performing OCR to avoid wasteful compute cycles and eliminate redundant translation requests when dialogue hasn't changed.
- **Free & Flexible Translation Options**:
  - **Google Translate (Free Web API)**: Works out-of-the-box with zero configuration or API key.
  - **Google Gemini Flash**: Context-aware game dialogue translation with nuanced storytelling tone (using free tier API key).
  - **Apple Native Translation**: On-device offline translation for macOS 15+.
- **Floating Overlays with Click-Through**:
  - **Source Capture Zone**: Resizable & draggable box placed directly over the game's dialogue area.
  - **Subtitle Display Zone**: Floating, customizable subtitle HUD with backdrop opacity, text outline, and auto-fadeout when dialogue ends.
  - **Lock / Click-Through Mode**: One-click or hotkey toggle to make windows completely transparent to mouse events so game controls are never interrupted.
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

1. **Launch the App**: Look for the `captions.bubble` icon in your macOS menu bar.
2. **Position the Zones**:
   - Drag and resize the **cyan dashed box** over your game's subtitle/dialogue area.
   - Drag and resize the **orange dashed box** where you want translated subtitles to appear.
3. **Lock Overlays**:
   - Click the **Lock** button on either box or select **Lock Overlays** from the menu bar (`Cmd + L`).
   - The boxes become invisible/transparent and mouse clicks will pass straight through to your game.
4. **Start Auto-Scan**:
   - Select **Start Auto-Scan** from the menu bar (`Cmd + S`) or click **Start Auto-Scan** in Preferences.
   - Subtitles will appear and auto-fade when the conversation stops!
5. **Preferences**:
   - Click the menu bar icon and choose **Preferences...** (`Cmd + ,`) to switch profiles, adjust font sizes, change languages, or configure Gemini API keys.
