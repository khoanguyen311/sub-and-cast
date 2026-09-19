import Foundation
import CoreGraphics
import SubAndCastKit

@main
struct TestRunner {
    static func main() async {
        print("🚀 Running SubAndCast Test Suite...")

        var passed = 0
        var failed = 0

        func assertTest(_ condition: Bool, _ name: String) {
            if condition {
                print("  ✅ [PASS] \(name)")
                passed += 1
            } else {
                print("  ❌ [FAIL] \(name)")
                failed += 1
            }
        }

        // Test 1: GameProfile Serialization
        do {
            let originalProfile = GameProfile(
                name: "Final Fantasy XVI",
                sourceRect: CodableRect(x: 150, y: 800, width: 700, height: 100),
                displayRect: CodableRect(x: 150, y: 920, width: 700, height: 120),
                sourceLanguage: "ja",
                targetLanguage: "en",
                captureIntervalSeconds: 0.5,
                fadeTimeoutSeconds: 5.0,
                fontSize: 22.0,
                backgroundOpacity: 0.9
            )

            let data = try JSONEncoder().encode(originalProfile)
            let decoded = try JSONDecoder().decode(GameProfile.self, from: data)

            assertTest(decoded.id == originalProfile.id, "GameProfile ID preserved")
            assertTest(decoded.name == "Final Fantasy XVI", "GameProfile Name preserved")
            assertTest(decoded.sourceRect.x == 150, "GameProfile Coordinates preserved")
            assertTest(decoded.sourceLanguage == "ja", "GameProfile Source Language preserved")
            assertTest(decoded.targetLanguage == "en", "GameProfile Target Language preserved")

            let defaultProfile = GameProfile()
            assertTest(defaultProfile.sourceLanguage == "en", "GameProfile default source language is English (en)")
            assertTest(defaultProfile.targetLanguage == "vi", "GameProfile default target language is Vietnamese (vi)")
            assertTest(defaultProfile.translationEngineType == "apple", "GameProfile default translation engine is Apple Native")
            assertTest(defaultProfile.ocrEngineType == OCREngine.appleVision.rawValue, "GameProfile default OCR engine is Apple Neural Engine (Vision)")
        } catch {
            print("  ❌ [FAIL] GameProfile Serialization Error: \(error)")
            failed += 1
        }

        // Test 2: ImageDiffer Change Detection
        do {
            let differ = ImageDiffer()
            let colorSpace = CGColorSpaceCreateDeviceGray()

            var blackBytes = [UInt8](repeating: 0, count: 64 * 64)
            let blackContext = CGContext(
                data: &blackBytes,
                width: 64,
                height: 64,
                bitsPerComponent: 8,
                bytesPerRow: 64,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            )!
            let blackImage = blackContext.makeImage()!

            let firstCheck = differ.hasImageChanged(cgImage: blackImage)
            assertTest(firstCheck == true, "ImageDiffer recognizes first frame as changed")

            let secondCheck = differ.hasImageChanged(cgImage: blackImage)
            assertTest(secondCheck == false, "ImageDiffer detects identical consecutive frames as unchanged")

            var whiteBytes = [UInt8](repeating: 255, count: 64 * 64)
            let whiteContext = CGContext(
                data: &whiteBytes,
                width: 64,
                height: 64,
                bitsPerComponent: 8,
                bytesPerRow: 64,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            )!
            let whiteImage = whiteContext.makeImage()!

            let whiteCheck = differ.hasImageChanged(cgImage: whiteImage)
            assertTest(whiteCheck == true, "ImageDiffer recognizes different frame as changed")
        }

        // Test 3: Google Free Translation Empty Handling
        do {
            let engine = GoogleFreeTranslationEngine()
            let emptyResult = try? await engine.translate(text: "   ", sourceLanguage: "ja", targetLanguage: "en")
            assertTest(emptyResult == "", "GoogleFreeTranslationEngine handles empty string safely")
        }

        // Test 4: ProfileManager defaults
        do {
            let profiles = ProfileManager.shared.loadProfiles()
            assertTest(!profiles.isEmpty, "ProfileManager loads at least one default profile")
        }

        // Test 5: CodableRect Clamping & Self-Healing Decoder
        do {
            let clamped = CodableRect(x: -50, y: -20, width: 0, height: 10)
            assertTest(clamped.x == 0, "CodableRect clamps negative x to 0")
            assertTest(clamped.y == 0, "CodableRect clamps negative y to 0")
            assertTest(clamped.width == CodableRect.minWidth, "CodableRect clamps width to minWidth (120)")
            assertTest(clamped.height == CodableRect.minHeight, "CodableRect clamps height to minHeight (40)")

            // Test decoding corrupted profile with W: 0, H: 20
            let corruptedJSON = """
            {"x": 100, "y": 200, "width": 0, "height": 20}
            """.data(using: .utf8)!
            let healed = try JSONDecoder().decode(CodableRect.self, from: corruptedJSON)
            assertTest(healed.width == CodableRect.minWidth, "CodableRect decoder heals width 0 to 120")
            assertTest(healed.height == CodableRect.minHeight, "CodableRect decoder heals height 20 to 40")
        } catch {
            print("  ❌ [FAIL] CodableRect Clamping Error: \(error)")
            failed += 1
        }

        // Test 6: AppHotkey & GlobalHotkeyManager Conflict Resolution
        do {
            let hotkey1 = AppHotkey(keyCode: 1, modifiers: 2048 | 256) // Option + Cmd + S
            assertTest(hotkey1.displayString == "⌥ ⌘ S", "AppHotkey formats modifier and key string accurately")

            let encoded = try JSONEncoder().encode(hotkey1)
            let decoded = try JSONDecoder().decode(AppHotkey.self, from: encoded)
            assertTest(decoded == hotkey1, "AppHotkey preserves keyCode and modifiers across Codable")

            // Test Conflict Resolution on MainActor
            await MainActor.run {
                let manager = GlobalHotkeyManager.shared
                let keyA = AppHotkey(keyCode: 1, modifiers: 256) // Cmd + S
                let keyB = AppHotkey(keyCode: 35, modifiers: 256) // Cmd + P

                manager.setHotkey(keyA, for: .toggleScan)
                assertTest(manager.toggleScanHotkey == keyA, "GlobalHotkeyManager sets toggleScan hotkey")

                manager.setHotkey(keyB, for: .togglePositioning)
                assertTest(manager.togglePositioningHotkey == keyB, "GlobalHotkeyManager sets togglePositioning hotkey")

                // Now assign keyA to togglePositioning; toggleScan should be auto-cleared
                manager.setHotkey(keyA, for: .togglePositioning)
                assertTest(manager.togglePositioningHotkey == keyA, "GlobalHotkeyManager updates togglePositioning hotkey")
                assertTest(manager.toggleScanHotkey == nil, "GlobalHotkeyManager auto-clears conflicting hotkey")

                // Reset hotkeys to nil for clean state
                manager.setHotkey(nil, for: .toggleScan)
                manager.setHotkey(nil, for: .togglePositioning)
                assertTest(manager.toggleScanHotkey == nil && manager.togglePositioningHotkey == nil, "GlobalHotkeyManager clears hotkeys to unassigned")
            }
        } catch {
            print("  ❌ [FAIL] Hotkey Testing Error: \(error)")
            failed += 1
        }

        print("\n🏁 Results: \(passed) passed, \(failed) failed.")
        if failed > 0 {
            exit(1)
        }
    }
}
