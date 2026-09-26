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

            // Test subtle in-dialogue text change inside a 600x120 dialogue box
            let w = 600
            let h = 120
            func makeDialogueImage(pattern: Int) -> CGImage {
                var bytes = [UInt8](repeating: 20, count: w * h)
                for y in 45..<65 {
                    for x in 50..<350 {
                        if pattern == 1 {
                            bytes[y * w + x] = (x % 7 == 0 || y % 4 == 0) ? 230 : 20
                        } else {
                            bytes[y * w + x] = (x % 5 == 0 || y % 6 == 0) ? 230 : 20
                        }
                    }
                }
                let ctx = CGContext(data: &bytes, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w, space: colorSpace, bitmapInfo: CGImageAlphaInfo.none.rawValue)!
                return ctx.makeImage()!
            }

            let dialogueDiffer = ImageDiffer()
            let dImg1 = makeDialogueImage(pattern: 1)
            let dImg2 = makeDialogueImage(pattern: 2)

            _ = dialogueDiffer.hasImageChanged(cgImage: dImg1)
            let subtleTextChangeDetected = dialogueDiffer.hasImageChanged(cgImage: dImg2)
            assertTest(subtleTextChangeDetected == true, "ImageDiffer detects subtle text changes within the same dialogue box")
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

                let keyC = AppHotkey(keyCode: 40, modifiers: 256) // Cmd + K
                manager.setHotkey(keyC, for: .oneTimeScan)
                assertTest(manager.oneTimeScanHotkey == keyC, "GlobalHotkeyManager sets oneTimeScan hotkey")

                // Now assign keyA to togglePositioning; toggleScan should be auto-cleared
                manager.setHotkey(keyA, for: .togglePositioning)
                assertTest(manager.togglePositioningHotkey == keyA, "GlobalHotkeyManager updates togglePositioning hotkey")
                assertTest(manager.toggleScanHotkey == nil, "GlobalHotkeyManager auto-clears conflicting toggleScan hotkey")

                // Assign keyA to oneTimeScan; togglePositioning should be auto-cleared
                manager.setHotkey(keyA, for: .oneTimeScan)
                assertTest(manager.oneTimeScanHotkey == keyA, "GlobalHotkeyManager sets oneTimeScan with existing key")
                assertTest(manager.togglePositioningHotkey == nil, "GlobalHotkeyManager auto-clears conflicting togglePositioning hotkey")

                // Reset hotkeys to nil for clean state
                manager.setHotkey(nil, for: .toggleScan)
                manager.setHotkey(nil, for: .togglePositioning)
                manager.setHotkey(nil, for: .oneTimeScan)
                assertTest(
                    manager.toggleScanHotkey == nil && manager.togglePositioningHotkey == nil && manager.oneTimeScanHotkey == nil,
                    "GlobalHotkeyManager clears hotkeys to unassigned"
                )
            }
        } catch {
            print("  ❌ [FAIL] Hotkey Testing Error: \(error)")
            failed += 1
        }

        // Test 7: GameProfile One-Time Scan Fadeout & Backwards Compatibility
        do {
            let profile = GameProfile()
            assertTest(profile.oneTimeFadeTimeoutSeconds == 5.0, "GameProfile default oneTimeFadeTimeoutSeconds is 5.0")

            // Test decoding profile JSON created prior to oneTimeFadeTimeoutSeconds
            let legacyProfileJSON = """
            {
                "id": "\(UUID().uuidString)",
                "name": "Legacy Game",
                "sourceRect": {"x": 100, "y": 150, "width": 600, "height": 120},
                "displayRect": {"x": 100, "y": 300, "width": 600, "height": 140},
                "fadeTimeoutSeconds": 4.0
            }
            """.data(using: .utf8)!
            let decodedLegacy = try JSONDecoder().decode(GameProfile.self, from: legacyProfileJSON)
            assertTest(decodedLegacy.oneTimeFadeTimeoutSeconds == 5.0, "GameProfile decodes legacy profiles with default oneTimeFadeTimeoutSeconds 5.0")
            assertTest(profile.mergeWrappedLines == true, "GameProfile default mergeWrappedLines is true")
            assertTest(decodedLegacy.mergeWrappedLines == true, "GameProfile decodes legacy profiles with default mergeWrappedLines true")
        } catch {
            print("  ❌ [FAIL] GameProfile One-Time Timeout Error: \(error)")
            failed += 1
        }

        // Test 8: DialogueTextReconstructor (Smart Line Merging & Choice Reattachment)
        do {
            // Case A: User's exact in-game dialogue scenario
            let rawLines = [
                "Magister Siwan - A new life awaits! And if you're a particularly good girl, perhaps a cure as well. An end to Source -",
                "for good!",
                "1. *You pull at the thing around your neck, futilely. Demand to know why she collared you.*",
                "2.",
                "*Take your leave.*"
            ]

            let reconstructed = DialogueTextReconstructor.reconstruct(lines: rawLines)
            assertTest(reconstructed.count == 3, "DialogueTextReconstructor produces 3 lines for dialogue and 2 choices")
            assertTest(
                reconstructed[0] == "Magister Siwan - A new life awaits! And if you're a particularly good girl, perhaps a cure as well. An end to Source - for good!",
                "DialogueTextReconstructor merged wrapped sentence preserving sentence dash"
            )
            assertTest(
                reconstructed[1] == "1. *You pull at the thing around your neck, futilely. Demand to know why she collared you.*",
                "DialogueTextReconstructor preserved choice 1"
            )
            assertTest(
                reconstructed[2] == "2. *Take your leave.*",
                "DialogueTextReconstructor reattached isolated choice number '2.' to following choice text"
            )

            // Case B: Word hyphenation break joining
            let hyphenatedLines = [
                "This was an unex-",
                "pected outcome."
            ]
            let dehyphenated = DialogueTextReconstructor.reconstruct(lines: hyphenatedLines)
            assertTest(
                dehyphenated.first == "This was an unexpected outcome.",
                "DialogueTextReconstructor seamlessly rejoined broken word hyphenation ('unex-' + 'pected' -> 'unexpected')"
            )

            // Case C: Choice list preservation
            let choiceLines = [
                "What would you like to do?",
                "1. Attack the guard.",
                "2. Sneak away silently."
            ]
            let choiceResult = DialogueTextReconstructor.reconstruct(lines: choiceLines)
            assertTest(choiceResult.count == 3, "DialogueTextReconstructor preserves distinct choice list items on separate lines")

            // Case D: User's 4-choice dialogue where Choice 1 starts with action asterisk and Choice 3 wraps
            let fourChoiceDialogue = [
                "Magister Siwan - You'll find him on the other side of this deck, in the officers' quarters.",
                "*You pull at the thing around your neck, futilely. Demand to know why she collared you.*",
                "2. [JESTER] *The last thing you remember is hoisting your fifteenth pint. Is this the Ram's Head loo?*",
                "3. [MYSTIC] *Say you had a long black dream about a ship, sailing the river of the dead. But you're not dead, are",
                "you?*",
                "4. *Take your leave.*"
            ]
            let fourResult = DialogueTextReconstructor.reconstruct(lines: fourChoiceDialogue)
            assertTest(fourResult.count == 5, "DialogueTextReconstructor produces exactly 5 lines (speaker + 4 choices)")
            assertTest(
                fourResult[0] == "Magister Siwan - You'll find him on the other side of this deck, in the officers' quarters.",
                "Speaker dialogue line preserved without merging into choices"
            )
            assertTest(
                fourResult[1] == "1. *You pull at the thing around your neck, futilely. Demand to know why she collared you.*",
                "DialogueTextReconstructor recovered missing '1.' on choice 1 before choice 2"
            )
            assertTest(
                fourResult[2].hasPrefix("2. [JESTER]"),
                "Choice 2 preserved with '2. [JESTER]'"
            )
            assertTest(
                fourResult[3].contains("you?*"),
                "Choice 3 wrapped line seamlessly re-merged with choice 3"
            )
            assertTest(
                fourResult[4] == "4. *Take your leave.*",
                "Choice 4 preserved as '4. *Take your leave.*'"
            )
        }

        // Test 5: AssistiveTouch Action Models and Execution
        do {
            // Check enum cases and icon names
            let allCases = AssistiveTouchAction.allCases
            assertTest(allCases.count == 6, "AssistiveTouchAction contains all 6 cases")
            assertTest(AssistiveTouchAction.oneTimeScan.iconName == "viewfinder", "AssistiveTouchAction.oneTimeScan icon is viewfinder")
            assertTest(AssistiveTouchAction.toggleAutoScan.iconName == "arrow.clockwise.circle", "AssistiveTouchAction.toggleAutoScan icon is arrow.clockwise.circle")
            assertTest(AssistiveTouchAction.togglePositioning.iconName == "hand.draw", "AssistiveTouchAction.togglePositioning icon is hand.draw")
            assertTest(AssistiveTouchAction.openQuickMenu.iconName == "square.grid.2x2", "AssistiveTouchAction.openQuickMenu icon is square.grid.2x2")
            assertTest(AssistiveTouchAction.openPreferences.iconName == "gearshape", "AssistiveTouchAction.openPreferences icon is gearshape")
            assertTest(AssistiveTouchAction.none.iconName == "slash.circle", "AssistiveTouchAction.none icon is slash.circle")

            // Test serialization
            let encoded = try JSONEncoder().encode(AssistiveTouchAction.openQuickMenu)
            let decoded = try JSONDecoder().decode(AssistiveTouchAction.self, from: encoded)
            assertTest(decoded == .openQuickMenu, "AssistiveTouchAction encodes and decodes properly")

            // Test AppState default state and action execution on MainActor
            await MainActor.run {
                let state = AppState.shared
                assertTest(state.isAssistiveTouchEnabled == true, "AssistiveTouch enabled by default")
                assertTest(state.assistiveTouchSize == 40.0, "Default AssistiveTouch size is 40 pt")
                assertTest(state.assistiveTouchIdleOpacity == 0.30, "Default AssistiveTouch idle opacity is 30%")
                assertTest(state.assistiveTouchSingleClick == .oneTimeScan, "Default single-click action is one-time scan")
                assertTest(state.assistiveTouchDoubleClick == .toggleAutoScan, "Default double-click action is toggle auto-scan")
                assertTest(state.assistiveTouchLongPress == .openQuickMenu, "Default long-press action is open quick menu")

                // Test toggle quick menu execution
                let initialMenuState = state.isAssistiveQuickMenuOpen
                state.executeAssistiveAction(.openQuickMenu)
                assertTest(state.isAssistiveQuickMenuOpen == !initialMenuState, "executeAssistiveAction toggles quick menu state")
                state.executeAssistiveAction(.openQuickMenu)
                assertTest(state.isAssistiveQuickMenuOpen == initialMenuState, "executeAssistiveAction reverts quick menu state")

                // Test none action execution
                state.executeAssistiveAction(.none)
                assertTest(true, "executeAssistiveAction(.none) executes safely without side effects")
            }
        } catch {
            print("  ❌ [FAIL] AssistiveTouch Error: \(error)")
            failed += 1
        }

        // Test 9: Pipeline Adapters (FrameCaptureProvider & TranslationProvider)
        do {
            // Test StaticImageFrameProvider FIFO and fallback
            let colorSpace = CGColorSpaceCreateDeviceGray()
            var byte0: [UInt8] = [0]
            let ctx0 = CGContext(data: &byte0, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 1, space: colorSpace, bitmapInfo: CGImageAlphaInfo.none.rawValue)!
            let imgA = ctx0.makeImage()!

            var byte1: [UInt8] = [255]
            let ctx1 = CGContext(data: &byte1, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 1, space: colorSpace, bitmapInfo: CGImageAlphaInfo.none.rawValue)!
            let imgB = ctx1.makeImage()!

            let staticProvider = StaticImageFrameProvider(images: [imgA], defaultImage: imgB)
            let rect1 = CGRect(x: 10, y: 20, width: 100, height: 50)
            let captured1 = try await staticProvider.captureRegion(rect: rect1)
            assertTest(captured1 === imgA, "StaticImageFrameProvider dequeues first image")

            let rect2 = CGRect(x: 30, y: 40, width: 200, height: 80)
            let captured2 = try await staticProvider.captureRegion(rect: rect2)
            assertTest(captured2 === imgB, "StaticImageFrameProvider falls back to defaultImage")
            assertTest(staticProvider.capturedRects.count == 2, "StaticImageFrameProvider records capture rects")
            assertTest(staticProvider.capturedRects.first == rect1, "StaticImageFrameProvider records exact rect coordinates")

            // Empty provider throws error
            let emptyProvider = StaticImageFrameProvider()
            var threwError = false
            do {
                _ = try await emptyProvider.captureRegion(rect: rect1)
            } catch {
                threwError = true
            }
            assertTest(threwError, "StaticImageFrameProvider throws error when empty and no fallback")

            // Test MockTranslationProvider
            let mockTranslator = MockTranslationProvider(
                prefix: "VI",
                canned: ["Hello": "Xin chào"]
            )

            // Canned translation
            let t1 = try await mockTranslator.translate(
                text: "Hello",
                sourceLanguage: "en",
                targetLanguage: "vi",
                engineType: "apple"
            )
            assertTest(t1 == "Xin chào", "MockTranslationProvider returns canned translation for known phrase")

            // Prefix translation
            let t2 = try await mockTranslator.translate(
                text: "Goodbye",
                sourceLanguage: "en",
                targetLanguage: "vi",
                engineType: "apple"
            )
            assertTest(t2 == "VI: Goodbye", "MockTranslationProvider uses prefix for uncanned phrase")
            assertTest(mockTranslator.callCount == 2, "MockTranslationProvider tracks call count")
            assertTest(mockTranslator.recordedRequests.count == 2, "MockTranslationProvider records requests")
            assertTest(mockTranslator.recordedRequests.first?.source == "en", "MockTranslationProvider records source language")

            // Custom handler override
            mockTranslator.translationHandler = { text, sl, tl, eng in
                return "HANDLED: \(text)"
            }
            let t3 = try await mockTranslator.translate(
                text: "Test",
                sourceLanguage: "ja",
                targetLanguage: "en",
                engineType: "google_free"
            )
            assertTest(t3 == "HANDLED: Test", "MockTranslationProvider executes custom handler override")

            // Protocol conformance checks
            let _: any FrameCaptureProvider = ScreenCaptureManager()
            let _: any TranslationProvider = TranslationCoordinator.shared
            assertTest(true, "ScreenCaptureManager and TranslationCoordinator conform to adapter protocols")
        } catch {
            print("  ❌ [FAIL] Pipeline Adapters Error: \(error)")
            failed += 1
        }

        print("\n🏁 Results: \(passed) passed, \(failed) failed.")
        if failed > 0 {
            exit(1)
        }
    }
}
