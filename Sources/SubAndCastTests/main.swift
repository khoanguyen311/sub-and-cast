import Foundation
import CoreGraphics
import CoreText
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

        // Test 10: SubtitlePipeline End-to-End Headless Tests
        do {
            // Helper to render readable text into a CGImage bitmap for Vision OCR
            func makeRenderedTextImage(text: String, width: Int = 500, height: Int = 100) -> CGImage {
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                let ctx = CGContext(
                    data: nil,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width * 4,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                )!
                // Black background
                ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1.0))
                ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

                if !text.isEmpty {
                    let font = CTFontCreateWithName("Helvetica" as CFString, 26, nil)
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: font,
                        .foregroundColor: CGColor(red: 1, green: 1, blue: 1, alpha: 1)
                    ]
                    let attrString = CFAttributedStringCreate(nil, text as CFString, attributes as CFDictionary)!
                    let line = CTLineCreateWithAttributedString(attrString)
                    ctx.textPosition = CGPoint(x: 20, y: 35)
                    CTLineDraw(line, ctx)
                }
                return ctx.makeImage()!
            }

            let mockCapture = StaticImageFrameProvider()
            let mockTranslator = MockTranslationProvider(prefix: "TRANSLATED")
            let pipeline = SubtitlePipeline(
                captureProvider: mockCapture,
                translationProvider: mockTranslator
            )

            let testConfig = SubtitlePipelineConfig(
                sourceLanguage: "en",
                targetLanguage: "vi",
                translationEngineType: "apple",
                mergeWrappedLines: true
            )
            let testRect = CGRect(x: 100, y: 200, width: 500, height: 100)

            // Step 1: Empty/blank image should emit .empty
            let blankImage = makeRenderedTextImage(text: "")
            mockCapture.setImages([blankImage])
            let emptyOutput = try await pipeline.process(rect: testRect, config: testConfig, force: false)
            assertTest(emptyOutput == .empty, "SubtitlePipeline emits .empty for image with no text")
            assertTest(pipeline.lastRecognizedText == "", "SubtitlePipeline clears lastRecognizedText on empty frame")

            // Step 2: New frame with text should emit .dialogue(...)
            let textImage1 = makeRenderedTextImage(text: "Hello World")
            mockCapture.setImages([textImage1])
            let dialogueOutput1 = try await pipeline.process(rect: testRect, config: testConfig, force: false)
            if case let .dialogue(src, trans, _) = dialogueOutput1 {
                assertTest(src.contains("Hello World"), "SubtitlePipeline recognized text contains 'Hello World'")
                assertTest(trans == "TRANSLATED: \(src)", "SubtitlePipeline translated dialogue with mock translation")
            } else {
                assertTest(false, "SubtitlePipeline should emit .dialogue for recognized text")
            }
            assertTest(mockTranslator.callCount == 1, "SubtitlePipeline invoked translation provider once")

            // Step 3: Consecutive identical frame should emit .unchanged without calling translation again
            mockCapture.setImages([textImage1])
            let unchangedOutput = try await pipeline.process(rect: testRect, config: testConfig, force: false)
            assertTest(unchangedOutput == .unchanged, "SubtitlePipeline emits .unchanged for identical frame")
            assertTest(mockTranslator.callCount == 1, "SubtitlePipeline bypassed translation provider on unchanged frame")

            // Step 4: Forced scan on unchanged frame should return .dialogue reusing previous translation without hitting provider
            mockCapture.setImages([textImage1])
            let forcedOutput = try await pipeline.process(rect: testRect, config: testConfig, force: true)
            if case let .dialogue(src, trans, _) = forcedOutput {
                assertTest(src.contains("Hello World"), "SubtitlePipeline forced scan re-evaluates frame")
                assertTest(trans.contains("TRANSLATED"), "SubtitlePipeline forced scan reuses previous translated text")
            } else {
                assertTest(false, "SubtitlePipeline forced scan should emit .dialogue")
            }
            assertTest(mockTranslator.callCount == 1, "SubtitlePipeline reuses previous translation when scan matches (callCount remains 1)")

            // Step 5: Process next dialogue frame
            let textImage2 = makeRenderedTextImage(text: "Farewell friend")
            mockCapture.setImages([textImage2])
            let dialogueOutput2 = try await pipeline.process(rect: testRect, config: testConfig, force: false)
            if case let .dialogue(src, _, _) = dialogueOutput2 {
                assertTest(src.contains("Farewell friend"), "SubtitlePipeline detects updated dialogue")
            } else {
                assertTest(false, "SubtitlePipeline should emit .dialogue for new text")
            }
            assertTest(mockTranslator.callCount == 2, "SubtitlePipeline invoked translation for new text")

            // Step 6: Invalid small rect returns .empty immediately
            let invalidRect = CGRect(x: 0, y: 0, width: 20, height: 10)
            let invalidOutput = try await pipeline.process(rect: invalidRect, config: testConfig, force: false)
            assertTest(invalidOutput == .empty, "SubtitlePipeline returns .empty for rect smaller than minimum size")

            // Step 7: Reset clears caches
            pipeline.reset()
            assertTest(pipeline.lastRecognizedText == "" && pipeline.lastTranslatedText == "", "SubtitlePipeline reset() clears text caches")
        } catch {
            print("  ❌ [FAIL] SubtitlePipeline Test Error: \(error)")
            failed += 1
        }

        // Test 11: AppState One-Time Scan Integration with SubtitlePipeline
        do {
            final class MockPipeline: SubtitlePipelineProtocol, @unchecked Sendable {
                var simulatedOutput: SubtitlePipelineOutput = .dialogue(sourceText: "Hello", translatedText: "Xin chào", confidence: 0.95)
                var shouldThrow = false
                var receivedForce: Bool?

                func process(rect: CGRect, config: SubtitlePipelineConfig, force: Bool) async throws -> SubtitlePipelineOutput {
                    receivedForce = force
                    if shouldThrow {
                        throw NSError(domain: "MockPipeline", code: -1, userInfo: [NSLocalizedDescriptionKey: "Simulated failure"])
                    }
                    return simulatedOutput
                }

                func process(image: CGImage, config: SubtitlePipelineConfig, force: Bool) async throws -> SubtitlePipelineOutput {
                    return simulatedOutput
                }

                func reset() {}
            }

            let mockPipe = MockPipeline()
            let testState = await MainActor.run { () -> AppState in
                let state = AppState(subtitlePipeline: mockPipe)
                state.currentProfile.sourceRect = CodableRect(x: 100, y: 100, width: 200, height: 100)
                state.triggerOneTimeScan()
                return state
            }

            // Allow Task on MainActor to complete
            try await Task.sleep(nanoseconds: 100_000_000)

            await MainActor.run {
                assertTest(mockPipe.receivedForce == true, "AppState delegates one-time scan with force: true")
                assertTest(testState.lastRecognizedText == "Hello", "AppState one-time scan updates lastRecognizedText")
                assertTest(testState.lastTranslatedText == "Xin chào", "AppState one-time scan updates lastTranslatedText")
                assertTest(testState.isOneTimeSubtitleVisible == true, "AppState one-time scan sets isOneTimeSubtitleVisible true")
                assertTest(testState.oneTimeScanTriggerCount >= 1, "AppState one-time scan increments trigger count")
                assertTest(testState.statusMessage.contains("Translated"), "AppState one-time scan updates status message on success")

                // Test empty output handling
                mockPipe.simulatedOutput = .empty
                testState.triggerOneTimeScan()
            }

            try await Task.sleep(nanoseconds: 100_000_000)

            await MainActor.run {
                assertTest(testState.statusMessage == "No text detected", "AppState one-time scan sets status on empty output")

                // Test error handling
                mockPipe.shouldThrow = true
                testState.triggerOneTimeScan()
            }

            try await Task.sleep(nanoseconds: 100_000_000)

            await MainActor.run {
                assertTest(testState.statusMessage.contains("Error:"), "AppState one-time scan surfaces errors in statusMessage")
            }
        } catch {
            print("  ❌ [FAIL] AppState One-Time Scan Error: \(error)")
            failed += 1
        }

        // Test 12: AppState Auto-Scan Cycle & SubtitlePipeline Integration
        do {
            final class AutoScanMockPipeline: SubtitlePipelineProtocol, @unchecked Sendable {
                var outputToReturn: SubtitlePipelineOutput = .dialogue(sourceText: "Dialogue line 1", translatedText: "Dòng thoại 1", confidence: 0.99)
                var resetCalled = false
                var processCallCount = 0

                func process(rect: CGRect, config: SubtitlePipelineConfig, force: Bool) async throws -> SubtitlePipelineOutput {
                    processCallCount += 1
                    return outputToReturn
                }

                func process(image: CGImage, config: SubtitlePipelineConfig, force: Bool) async throws -> SubtitlePipelineOutput {
                    return outputToReturn
                }

                func reset() {
                    resetCalled = true
                }
            }

            let mockPipe = AutoScanMockPipeline()
            let state = await MainActor.run { () -> AppState in
                let s = AppState(subtitlePipeline: mockPipe)
                s.currentProfile.sourceRect = CodableRect(x: 100, y: 100, width: 300, height: 100)
                s.currentProfile.captureIntervalSeconds = 0.3
                return s
            }

            // Start scanning calls reset() on pipeline
            await MainActor.run {
                state.startScanning()
                assertTest(mockPipe.resetCalled == true, "startScanning() calls subtitlePipeline.reset()")
                assertTest(state.isScanning == true, "startScanning() sets isScanning true")
            }

            // Wait for at least one scan cycle to run
            try await Task.sleep(nanoseconds: 150_000_000)

            await MainActor.run {
                assertTest(state.isDialoguePresent == true, "Auto-scan cycle sets isDialoguePresent true on dialogue")
                assertTest(state.lastRecognizedText == "Dialogue line 1", "Auto-scan cycle updates lastRecognizedText")
                assertTest(state.lastTranslatedText == "Dòng thoại 1", "Auto-scan cycle updates lastTranslatedText")

                // Next cycle returns .unchanged: dialogue should remain present
                mockPipe.outputToReturn = .unchanged
            }

            try await Task.sleep(nanoseconds: 350_000_000)

            await MainActor.run {
                assertTest(state.isDialoguePresent == true, "Auto-scan cycle preserves isDialoguePresent on .unchanged")

                // Next cycle returns .empty: dialogue should become false and recognized text cleared
                mockPipe.outputToReturn = .empty
            }

            try await Task.sleep(nanoseconds: 350_000_000)

            await MainActor.run {
                assertTest(state.isDialoguePresent == false, "Auto-scan cycle sets isDialoguePresent false on .empty")
                assertTest(state.lastRecognizedText == "", "Auto-scan cycle clears lastRecognizedText on .empty")

                state.stopScanning()
                assertTest(state.isScanning == false, "stopScanning() stops scanning task")

                // Language mapping verification
                assertTest(state.ocrLanguages(for: "ja") == ["ja-JP", "en-US"], "AppState.ocrLanguages maps ja correctly")
                assertTest(state.ocrLanguages(for: "vi") == ["vi-VN", "en-US"], "AppState.ocrLanguages maps vi correctly")
            }
        } catch {
            print("  ❌ [FAIL] AppState Auto-Scan Cycle Error: \(error)")
            failed += 1
        }

        // Test 13: ProfileStore Headless Tests (In-Memory Adapter)
        do {
            let inMemoryAdapter = InMemoryProfileStorageAdapter(initialProfiles: [])
            let store = await MainActor.run {
                ProfileStore(storage: inMemoryAdapter, debounceNanoseconds: 50_000_000)
            }

            await MainActor.run {
                assertTest(store.profiles.count == 1, "ProfileStore creates default profile when storage is empty")
                assertTest(store.activeProfile.name == "Default Game", "ProfileStore default profile named 'Default Game'")

                // Add profile with sub-minimum dimensions to verify automatic healing
                let p2 = store.addProfile(name: "Baldur's Gate 3")
                assertTest(store.profiles.count == 2, "ProfileStore addProfile increments count")
                assertTest(store.activeProfile.id == p2.id, "ProfileStore addProfile makes new profile active")

                store.updateActiveProfile { profile in
                    profile.sourceRect = CodableRect(x: -10, y: -20, width: 50, height: 10)
                }
                assertTest(store.activeProfile.sourceRect.width >= CodableRect.minWidth, "ProfileStore heals sub-minimum width to minWidth")
                assertTest(store.activeProfile.sourceRect.height >= CodableRect.minHeight, "ProfileStore heals sub-minimum height to minHeight")

                // Add third profile and test selection
                let p3 = store.addProfile(name: "Elden Ring")
                assertTest(store.activeProfile.id == p3.id, "ProfileStore activeProfile matches Elden Ring")
                store.selectProfile(id: p2.id)
                assertTest(store.activeProfile.id == p2.id, "ProfileStore selectProfile selects Baldur's Gate 3")

                // Test deletion of active profile shifts selection to first remaining
                store.deleteProfile(id: p2.id)
                assertTest(store.profiles.count == 2, "ProfileStore deleteProfile removes target")
                assertTest(store.activeProfile.id == store.profiles.first?.id, "ProfileStore deleting active shifts to first remaining profile")

                // Delete until only 1 remains
                store.deleteProfile(id: p3.id)
                assertTest(store.profiles.count == 1, "ProfileStore retains exactly 1 profile")

                // Attempt deleting the only remaining profile
                store.deleteProfile(id: store.profiles[0].id)
                assertTest(store.profiles.count == 1, "ProfileStore ignores deleting the last remaining profile")

                // Flush persists to adapter
                store.flush()
                assertTest(inMemoryAdapter.saveCount >= 1, "ProfileStore flush persists to storage adapter")

                // AppState integration with injected ProfileStore
                let appStateWithStore = AppState(profileStore: store)
                assertTest(appStateWithStore.profiles.count == 1, "AppState adopts injected ProfileStore profiles")
                assertTest(appStateWithStore.currentProfile.id == store.activeProfile.id, "AppState adopts injected ProfileStore active profile")

                // Test last active profile persistence across store instances
                let testSuite = "test_profile_persistence_\(UUID().uuidString)"
                let testDefaults = UserDefaults(suiteName: testSuite)!
                defer { UserDefaults.standard.removePersistentDomain(forName: testSuite) }

                let pA = GameProfile(name: "Game A")
                let pB = GameProfile(name: "Game B")
                let adapterWithProfiles = InMemoryProfileStorageAdapter(initialProfiles: [pA, pB])
                let storeInstance1 = ProfileStore(storage: adapterWithProfiles, debounceNanoseconds: 10_000_000, userDefaults: testDefaults)
                storeInstance1.selectProfile(id: pB.id)
                assertTest(storeInstance1.activeProfile.id == pB.id, "ProfileStore sets Game B active")

                // Re-open store with the same defaults and storage
                let storeInstance2 = ProfileStore(storage: adapterWithProfiles, debounceNanoseconds: 10_000_000, userDefaults: testDefaults)
                assertTest(storeInstance2.activeProfile.id == pB.id, "ProfileStore defaults to last used profile on reopening")
            }
        } catch {
            print("  ❌ [FAIL] ProfileStore Tests Error: \(error)")
            failed += 1
        }

        // Test 14: SubtitlePipeline Autonomous Scan Engine & AsyncStream Events
        do {
            func makeTestImage(text: String, width: Int = 400, height: Int = 80) -> CGImage {
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                let ctx = CGContext(
                    data: nil,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width * 4,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                )!
                ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1.0))
                ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
                if !text.isEmpty {
                    let font = CTFontCreateWithName("Helvetica" as CFString, 24, nil)
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: font,
                        .foregroundColor: CGColor(red: 1, green: 1, blue: 1, alpha: 1)
                    ]
                    let attrString = CFAttributedStringCreate(nil, text as CFString, attributes as CFDictionary)!
                    let line = CTLineCreateWithAttributedString(attrString)
                    ctx.textPosition = CGPoint(x: 10, y: 25)
                    CTLineDraw(line, ctx)
                }
                return ctx.makeImage()!
            }

            let capture = StaticImageFrameProvider()
            let translator = MockTranslationProvider(prefix: "TRANSLATED")
            let pipeline = SubtitlePipeline(captureProvider: capture, translationProvider: translator)

            let config = SubtitlePipelineConfig(sourceLanguage: "en", targetLanguage: "vi")
            let rect = CGRect(x: 50, y: 50, width: 400, height: 80)

            // Test scanOnce single-shot execution
            let img1 = makeTestImage(text: "Autonomous Engine")
            capture.setImages([img1])
            let singleEvent = await pipeline.scanOnce(rect: rect, config: config)
            if case let .dialogue(src, trans, _) = singleEvent {
                assertTest(src.contains("Autonomous Engine"), "pipeline.scanOnce recognizes dialogue text")
                assertTest(trans.contains("TRANSLATED"), "pipeline.scanOnce translates dialogue text")
            } else {
                assertTest(false, "pipeline.scanOnce did not emit .dialogue")
            }

            // Test startScan event stream
            let img2 = makeTestImage(text: "Continuous Dialogue")
            let imgBlank = makeTestImage(text: "")
            capture.setImages([img2, img2, imgBlank])

            let stream = pipeline.startScan(rect: rect, config: config, intervalSeconds: 0.2)
            var collectedEvents: [SubtitleEvent] = []

            for await event in stream {
                collectedEvents.append(event)
                if collectedEvents.count >= 3 {
                    pipeline.stopScan()
                    break
                }
            }

            assertTest(collectedEvents.count >= 3, "pipeline.startScan stream yields multiple events")
            if collectedEvents.count >= 3 {
                if case let .dialogue(src, _, _) = collectedEvents[0] {
                    assertTest(src.contains("Continuous Dialogue"), "startScan stream first event is dialogue")
                } else {
                    assertTest(false, "startScan stream first event is not dialogue")
                }
                assertTest(collectedEvents[1] == .unchanged, "startScan stream second identical event is .unchanged")
                assertTest(collectedEvents[2] == .empty, "startScan stream blank event is .empty")
            }
        } catch {
            print("  ❌ [FAIL] SubtitlePipeline Stream Tests Error: \(error)")
            failed += 1
        }

        // Test 15: ShortcutRegistry with MockHotkeyEventSource and ActionStream
        do {
            await MainActor.run {
                let mockSource = MockHotkeyEventSource()
                let testDefaultsSuite = "test_shortcut_registry_\(UUID().uuidString)"
                let testDefaults = UserDefaults(suiteName: testDefaultsSuite)!
                defer { UserDefaults.standard.removePersistentDomain(forName: testDefaultsSuite) }

                let registry = ShortcutRegistry(eventSource: mockSource, userDefaults: testDefaults)

                let key1 = AppHotkey(keyCode: 1, modifiers: 256)
                let key2 = AppHotkey(keyCode: 2, modifiers: 256)

                // Assignment
                registry.setHotkey(key1, for: .toggleScan)
                assertTest(registry.toggleScanHotkey == key1, "ShortcutRegistry sets toggleScan hotkey")
                assertTest(mockSource.registeredHotkey(for: .toggleScan) == key1, "MockHotkeyEventSource receives registration for toggleScan")

                registry.setHotkey(key2, for: .togglePositioning)
                assertTest(registry.togglePositioningHotkey == key2, "ShortcutRegistry sets togglePositioning hotkey")
                assertTest(mockSource.registeredHotkey(for: .togglePositioning) == key2, "MockHotkeyEventSource receives registration for togglePositioning")

                // Conflict Resolution: assigning key1 to togglePositioning should clear toggleScan
                registry.setHotkey(key1, for: .togglePositioning)
                assertTest(registry.togglePositioningHotkey == key1, "ShortcutRegistry reassigns key to togglePositioning")
                assertTest(registry.toggleScanHotkey == nil, "ShortcutRegistry auto-unbinds conflicting hotkey from toggleScan")
                assertTest(mockSource.registeredHotkey(for: .toggleScan) == nil, "MockHotkeyEventSource unregisters conflicting toggleScan")

                // Persistence reload
                let reloadedRegistry = ShortcutRegistry(eventSource: mockSource, userDefaults: testDefaults)
                assertTest(reloadedRegistry.togglePositioningHotkey == key1, "ShortcutRegistry reloads persisted hotkey")
                assertTest(reloadedRegistry.toggleScanHotkey == nil, "ShortcutRegistry reloads nil for cleared hotkey")
            }

            // Stream action emission
            let mockSource = MockHotkeyEventSource()
            let testDefaultsSuite = "test_shortcut_stream_\(UUID().uuidString)"
            let testDefaults = UserDefaults(suiteName: testDefaultsSuite)!
            defer { UserDefaults.standard.removePersistentDomain(forName: testDefaultsSuite) }

            let (registry, stream) = await MainActor.run { () -> (ShortcutRegistry, AsyncStream<HotkeyAction>) in
                let reg = ShortcutRegistry(eventSource: mockSource, userDefaults: testDefaults)
                return (reg, reg.actionStream)
            }
            _ = registry

            var emittedActions: [HotkeyAction] = []
            let streamTask = Task {
                for await action in stream {
                    emittedActions.append(action)
                    if emittedActions.count >= 2 {
                        break
                    }
                }
            }

            // Simulate key presses via MockHotkeyEventSource
            mockSource.simulateKeyPress(for: .toggleScan)
            mockSource.simulateKeyPress(for: .oneTimeScan)

            _ = await streamTask.result

            assertTest(emittedActions.count == 2, "ShortcutRegistry actionStream received 2 simulated actions")
            if emittedActions.count == 2 {
                assertTest(emittedActions[0] == .toggleScan, "actionStream received .toggleScan first")
                assertTest(emittedActions[1] == .oneTimeScan, "actionStream received .oneTimeScan second")
            }
        }

        // Test 16: OverlayCoordinator Coordinate Inversion Math, Clamping & Undo Sessions
        do {
            await MainActor.run {
                let screenHeight: CGFloat = 1080

                // 1. Inversion Math: CoreGraphics -> AppKit
                // Box at CG (100, 200, width: 400, height: 100)
                let cgBox = CGRect(x: 100, y: 200, width: 400, height: 100)
                let appKitWithHeader = OverlayCoordinator.appKitFrame(
                    from: cgBox,
                    screenHeight: screenHeight,
                    includeHeader: true
                )
                // AppKit Y = 1080 - 200 - 100 = 780. Height = 100 + 36 = 136.
                assertTest(appKitWithHeader.origin.x == 100, "OverlayCoordinator preserves X coordinate in AppKit conversion")
                assertTest(appKitWithHeader.origin.y == 780, "OverlayCoordinator calculates bottom-left Y coordinate correctly")
                assertTest(appKitWithHeader.width == 400, "OverlayCoordinator preserves box width")
                assertTest(appKitWithHeader.height == 136, "OverlayCoordinator adds 36pt header offset when includeHeader is true")

                let appKitNoHeader = OverlayCoordinator.appKitFrame(
                    from: cgBox,
                    screenHeight: screenHeight,
                    includeHeader: false
                )
                assertTest(appKitNoHeader.height == 100, "OverlayCoordinator omits header offset when includeHeader is false")

                // 2. Inversion Math: AppKit -> CoreGraphics
                let cgRecovered = OverlayCoordinator.coreGraphicsRect(
                    from: appKitWithHeader,
                    screenHeight: screenHeight,
                    headerIsPresent: true
                )
                assertTest(cgRecovered.origin.x == 100, "OverlayCoordinator recovers original CoreGraphics X")
                assertTest(cgRecovered.origin.y == 200, "OverlayCoordinator recovers original CoreGraphics Y")
                assertTest(cgRecovered.width == 400, "OverlayCoordinator recovers original box width")
                assertTest(cgRecovered.height == 100, "OverlayCoordinator subtracts 36pt header to recover box height")

                // 3. Minimum Boundary Clamping
                let tinyRect = CGRect(x: -50, y: -20, width: 10, height: 5)
                let clamped = OverlayCoordinator.clampRect(tinyRect)
                assertTest(clamped.origin.x == 0, "OverlayCoordinator clamps negative X to 0")
                assertTest(clamped.origin.y == 0, "OverlayCoordinator clamps negative Y to 0")
                assertTest(clamped.width == CodableRect.minWidth, "OverlayCoordinator clamps width to minWidth (120)")
                assertTest(clamped.height == CodableRect.minHeight, "OverlayCoordinator clamps height to minHeight (40)")

                // 4. Positioning Session State Machine & Undo Rollback
                let coordinator = OverlayCoordinator()
                let initialSource = CodableRect(x: 100, y: 150, width: 350, height: 80)
                let initialDisplay = CodableRect(x: 100, y: 300, width: 450, height: 90)

                assertTest(coordinator.isPositioning == false, "OverlayCoordinator initially locked")

                // Begin positioning
                coordinator.beginPositioning(sourceRect: initialSource, displayRect: initialDisplay)
                assertTest(coordinator.isPositioning == true, "OverlayCoordinator transitions to positioning state")

                // Cancel positioning should return exact snapshots
                let rollback = coordinator.cancelPositioning()
                assertTest(rollback?.source == initialSource, "OverlayCoordinator cancel returns initial source rect snapshot")
                assertTest(rollback?.display == initialDisplay, "OverlayCoordinator cancel returns initial display rect snapshot")
                assertTest(coordinator.isPositioning == false, "OverlayCoordinator returns to locked state on cancel")

                // Commit positioning
                coordinator.beginPositioning(sourceRect: initialSource, displayRect: initialDisplay)
                let committed = coordinator.commitPositioning()
                assertTest(committed == true, "OverlayCoordinator commit succeeds when positioning")
                assertTest(coordinator.isPositioning == false, "OverlayCoordinator returns to locked state on commit")

                // 5. MockOverlayWindowAdapter
                let mockPanel = MockOverlayWindowAdapter()
                mockPanel.orderFrontRegardless()
                assertTest(mockPanel.isVisible == true, "MockOverlayWindowAdapter tracks orderFrontRegardless")
                mockPanel.makeKey()
                assertTest(mockPanel.isKeyWindow == true, "MockOverlayWindowAdapter tracks makeKey")
                mockPanel.setLocked(true)
                assertTest(mockPanel.isLocked == true, "MockOverlayWindowAdapter tracks setLocked")
                mockPanel.orderOut(nil)
                assertTest(mockPanel.isVisible == false, "MockOverlayWindowAdapter tracks orderOut")
            }
        }

        // Test 16: Cloudflare Workers AI Translation Engine & Profile Serialization
        do {
            // 1. GameProfile Serialization & Legacy Backwards Compatibility
            let cfProfile = GameProfile(
                name: "Elden Ring CF",
                translationEngineType: "cloudflare",
                cloudflareAccountId: "acc_12345",
                cloudflareApiToken: "tok_secret_999",
                cloudflareModel: "@cf/meta/llama-3.2-3b-instruct"
            )
            let cfData = try JSONEncoder().encode(cfProfile)
            let decodedCF = try JSONDecoder().decode(GameProfile.self, from: cfData)

            assertTest(decodedCF.translationEngineType == "cloudflare", "GameProfile encodes and decodes cloudflare engine type")
            assertTest(decodedCF.cloudflareAccountId == "acc_12345", "GameProfile preserves cloudflareAccountId")
            assertTest(decodedCF.cloudflareApiToken == "tok_secret_999", "GameProfile preserves cloudflareApiToken")
            assertTest(decodedCF.cloudflareModel == "@cf/meta/llama-3.2-3b-instruct", "GameProfile preserves cloudflareModel")

            let legacyJSONWithoutCF = """
            {
                "id": "\(UUID().uuidString)",
                "name": "Legacy Game Without CF",
                "sourceRect": {"x": 100, "y": 150, "width": 600, "height": 120},
                "displayRect": {"x": 100, "y": 300, "width": 600, "height": 140}
            }
            """.data(using: .utf8)!
            let legacyDecoded = try JSONDecoder().decode(GameProfile.self, from: legacyJSONWithoutCF)
            assertTest(legacyDecoded.cloudflareAccountId == "", "Legacy GameProfile decodes with empty cloudflareAccountId default")
            assertTest(legacyDecoded.cloudflareApiToken == "", "Legacy GameProfile decodes with empty cloudflareApiToken default")
            assertTest(legacyDecoded.cloudflareModel == "@cf/meta/llama-3.2-3b-instruct", "Legacy GameProfile decodes with default model")

            // 2. Output Sanitizer
            let rawWithQuotes = "\"Hello world\""
            assertTest(CloudflareWorkersAITranslationEngine.sanitizeOutput(rawWithQuotes) == "Hello world", "Sanitizer strips surrounding double quotes")

            let rawWithSingleQuotes = "'Greetings warrior'"
            assertTest(CloudflareWorkersAITranslationEngine.sanitizeOutput(rawWithSingleQuotes) == "Greetings warrior", "Sanitizer strips surrounding single quotes")

            let rawWithCJKQuotes = "「こんにちは」"
            assertTest(CloudflareWorkersAITranslationEngine.sanitizeOutput(rawWithCJKQuotes) == "こんにちは", "Sanitizer strips surrounding Japanese corner brackets")

            let rawWithPreamble = "Here is the translation: \"The castle gate is locked.\""
            assertTest(CloudflareWorkersAITranslationEngine.sanitizeOutput(rawWithPreamble) == "The castle gate is locked.", "Sanitizer strips 'Here is the translation:' preamble and quotes")

            // 3. MockURLProtocol for HTTP Request/Response Testing
            final class TestURLProtocol: URLProtocol, @unchecked Sendable {
                nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

                override class func canInit(with request: URLRequest) -> Bool { true }
                override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

                override func startLoading() {
                    guard let h = TestURLProtocol.handler else {
                        client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                        return
                    }
                    do {
                        let (response, data) = try h(request)
                        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                        client?.urlProtocol(self, didLoad: data)
                        client?.urlProtocolDidFinishLoading(self)
                    } catch {
                        client?.urlProtocol(self, didFailWithError: error)
                    }
                }

                override func stopLoading() {}
            }

            let sessionConfig = URLSessionConfiguration.ephemeral
            sessionConfig.protocolClasses = [TestURLProtocol.self]
            let testSession = URLSession(configuration: sessionConfig)
            let cfEngine = CloudflareWorkersAITranslationEngine(session: testSession)

            // Missing credentials throws error
            var threwMissing = false
            do {
                _ = try await cfEngine.translate(text: "Hello", sourceLanguage: "en", targetLanguage: "vi", config: CloudflareConfig())
            } catch CloudflareAIError.missingCredentials {
                threwMissing = true
            } catch {}
            assertTest(threwMissing, "Cloudflare engine throws missingCredentials when credentials are empty")

            // Test successful translation call
            var interceptedURL: URL?
            var interceptedAuth: String?
            var interceptedContentType: String?
            var interceptedBody: String?

            TestURLProtocol.handler = { req in
                interceptedURL = req.url
                interceptedAuth = req.value(forHTTPHeaderField: "Authorization")
                interceptedContentType = req.value(forHTTPHeaderField: "Content-Type")
                if let bodyData = req.httpBody {
                    interceptedBody = String(data: bodyData, encoding: .utf8)
                } else if let stream = req.httpBodyStream {
                    stream.open()
                    var data = Data()
                    let bufferSize = 1024
                    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
                    defer { buffer.deallocate() }
                    while stream.hasBytesAvailable {
                        let read = stream.read(buffer, maxLength: bufferSize)
                        if read > 0 {
                            data.append(buffer, count: read)
                        } else {
                            break
                        }
                    }
                    stream.close()
                    interceptedBody = String(data: data, encoding: .utf8)
                }

                let responseJSON = """
                {
                    "success": true,
                    "result": {
                        "response": "\\"Xin chào thế giới\\""
                    },
                    "errors": [],
                    "messages": []
                }
                """
                let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                return (resp, responseJSON.data(using: .utf8)!)
            }

            let testConfig = CloudflareConfig(
                accountId: "test_account_888",
                apiToken: "cf_token_xyz",
                model: "@cf/meta/llama-3.2-3b-instruct"
            )

            let translated = try await cfEngine.translate(text: "Hello world", sourceLanguage: "en", targetLanguage: "vi", config: testConfig)
            assertTest(interceptedURL?.absoluteString == "https://api.cloudflare.com/client/v4/accounts/test_account_888/ai/run/@cf/meta/llama-3.2-3b-instruct", "Cloudflare engine constructs expected account and model URL")
            assertTest(interceptedAuth == "Bearer cf_token_xyz", "Cloudflare engine attaches Bearer Authorization header")
            assertTest(interceptedContentType == "application/json", "Cloudflare engine specifies application/json Content-Type")
            assertTest(interceptedBody?.contains("Hello world") == true, "Cloudflare request body contains source text")
            assertTest(translated == "Xin chào thế giới", "Cloudflare engine successfully parsed and sanitized response")

            // Test connection verification
            let connectionOk = try await cfEngine.testConnection(accountId: "test_account_888", apiToken: "cf_token_xyz")
            assertTest(connectionOk == true, "testConnection returns true on HTTP 200")

            // Test error handling on HTTP 401
            TestURLProtocol.handler = { req in
                let errJSON = """
                {
                    "success": false,
                    "result": null,
                    "errors": [{"code": 10000, "message": "Invalid API Token"}],
                    "messages": []
                }
                """
                let resp = HTTPURLResponse(url: req.url!, statusCode: 401, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                return (resp, errJSON.data(using: .utf8)!)
            }

            var caughtApiError = false
            do {
                _ = try await cfEngine.translate(text: "Test", sourceLanguage: "en", targetLanguage: "vi", config: testConfig)
            } catch let CloudflareAIError.apiError(code, msg) {
                caughtApiError = (code == 401 && msg.contains("Invalid API Token"))
            } catch {}
            assertTest(caughtApiError, "Cloudflare engine parses HTTP 401 error message accurately")

            var testConnError = false
            do {
                _ = try await cfEngine.testConnection(accountId: "test_account_888", apiToken: "cf_token_xyz")
            } catch let CloudflareAIError.apiError(code, _) {
                testConnError = (code == 401)
            } catch {}
            assertTest(testConnError, "testConnection throws CloudflareAIError on HTTP 401")

            // 4. Prompt Presets & Custom Prompt (Ticket #14)
            assertTest(PromptPreset.allCases.count == 4, "PromptPreset contains all 4 cases")
            assertTest(PromptPreset.natural.displayName == "Natural Game Localization", "PromptPreset natural displayName correct")
            assertTest(PromptPreset.literal.displayName == "Literal & Faithful", "PromptPreset literal displayName correct")
            assertTest(PromptPreset.fantasy.displayName == "Fantasy & Historic RPG", "PromptPreset fantasy displayName correct")
            assertTest(PromptPreset.custom.displayName == "Custom", "PromptPreset custom displayName correct")
            assertTest(!PromptPreset.fantasy.defaultPrompt.isEmpty, "Fantasy preset has rich default prompt")

            var capturedPromptBody: String?
            TestURLProtocol.handler = { req in
                if let bodyData = req.httpBody {
                    capturedPromptBody = String(data: bodyData, encoding: .utf8)
                } else if let stream = req.httpBodyStream {
                    stream.open()
                    var data = Data()
                    let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: 512)
                    defer { buf.deallocate() }
                    while stream.hasBytesAvailable {
                        let n = stream.read(buf, maxLength: 512)
                        if n > 0 { data.append(buf, count: n) } else { break }
                    }
                    stream.close()
                    capturedPromptBody = String(data: data, encoding: .utf8)
                }
                let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                return (resp, "{\"success\":true,\"result\":{\"response\":\"Translated text\"}}".data(using: .utf8)!)
            }

            let fantasyConfig = CloudflareConfig(
                accountId: "test_acc",
                apiToken: "test_tok",
                model: "@cf/meta/llama-3.2-3b-instruct",
                customPrompt: "Act as a medieval bard."
            )
            _ = try await cfEngine.translate(text: "Halt traveler", sourceLanguage: "en", targetLanguage: "vi", config: fantasyConfig)
            assertTest(capturedPromptBody?.contains("Act as a medieval bard.") == true, "System prompt correctly injected into Cloudflare request payload")
            assertTest(capturedPromptBody?.contains("Vietnamese (tiếng Việt)") == true, "Target language mapped to descriptive name in prompt payload")

            // Additional Sanitizer Tests
            let trailingNote = "Translated line\n(Note: This was an archaic greeting)"
            assertTest(CloudflareWorkersAITranslationEngine.sanitizeOutput(trailingNote) == "Translated line", "Sanitizer strips trailing (Note: ...) commentary")

            // 5. Curated & Custom Model Selection (Ticket #15)
            var targetedModelURL: URL?
            TestURLProtocol.handler = { req in
                targetedModelURL = req.url
                let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                return (resp, "{\"success\":true,\"result\":{\"response\":\"OK\"}}".data(using: .utf8)!)
            }

            let customModelConfig = CloudflareConfig(
                accountId: "test_acc",
                apiToken: "test_tok",
                model: "@cf/custom/fine-tuned-rpg-v2"
            )
            _ = try await cfEngine.translate(text: "Hello", sourceLanguage: "en", targetLanguage: "vi", config: customModelConfig)
            assertTest(targetedModelURL?.absoluteString.contains("@cf/custom/fine-tuned-rpg-v2") == true, "Cloudflare engine dynamically routes to custom model identifier")

            // 6. Automated Failover Policy & HUD Warning (Ticket #16)
            final class Box<T>: @unchecked Sendable {
                var value: T
                init(_ value: T) { self.value = value }
            }

            let testCoordinator = TranslationCoordinator()
            testCoordinator.cloudflareEngine.session = testSession
            testCoordinator.googleFreeEngine.session = testSession

            // Handler: Return 429 for Cloudflare, Return valid JSON for Google Translate
            TestURLProtocol.handler = { req in
                if req.url?.absoluteString.contains("googleapis.com") == true {
                    let googleJSON = "[[[\"Dịch dự phòng\",\"Testing failover\",null,null,10]]]"
                    let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    return (resp, googleJSON.data(using: .utf8)!)
                } else {
                    let resp = HTTPURLResponse(url: req.url!, statusCode: 429, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    return (resp, "{\"success\":false,\"errors\":[{\"message\":\"Rate limit exceeded\"}]}".data(using: .utf8)!)
                }
            }

            let fallbackNotified = Box<String?>(nil)
            testCoordinator.onFallbackTriggered = { eng, _ in
                fallbackNotified.value = eng
            }

            let failoverConfigDisabled = CloudflareConfig(
                accountId: "test_acc",
                apiToken: "test_tok",
                fallbackEnabled: false,
                fallbackEngine: "google_free"
            )

            var caughtDisabledError = false
            do {
                _ = try await testCoordinator.translate(
                    text: "Testing failover",
                    sourceLanguage: "en",
                    targetLanguage: "vi",
                    engineType: "cloudflare",
                    cloudflareConfig: failoverConfigDisabled
                )
            } catch {
                caughtDisabledError = true
            }
            assertTest(caughtDisabledError, "When fallback is disabled, coordinator propagates Cloudflare error")

            // Fallback enabled on error
            let failoverConfigEnabled = CloudflareConfig(
                accountId: "test_acc",
                apiToken: "test_tok",
                fallbackEnabled: true,
                fallbackEngine: "google_free"
            )

            let fallbackResult = try await testCoordinator.translate(
                text: "Testing failover",
                sourceLanguage: "en",
                targetLanguage: "vi",
                engineType: "cloudflare",
                cloudflareConfig: failoverConfigEnabled
            )
            assertTest(fallbackResult == "Dịch dự phòng", "When Cloudflare fails and fallback is enabled, coordinator falls back to secondary engine")
            assertTest(fallbackNotified.value == "google_free", "Fallback notification fires with secondary engine name")

            // Fallback enabled with missing credentials (clear cache to test fresh failover)
            testCoordinator.clearCache()
            let failoverMissingCreds = CloudflareConfig(
                accountId: "",
                apiToken: "",
                fallbackEnabled: true,
                fallbackEngine: "google_free"
            )
            let missingFallbackTriggered = Box<Bool>(false)
            testCoordinator.onFallbackTriggered = { eng, reason in
                if eng == "google_free" && reason.contains("Missing credentials") {
                    missingFallbackTriggered.value = true
                }
            }
            let missingResult = try await testCoordinator.translate(
                text: "Testing failover",
                sourceLanguage: "en",
                targetLanguage: "vi",
                engineType: "cloudflare",
                cloudflareConfig: failoverMissingCreds
            )
            assertTest(missingResult == "Dịch dự phòng", "Fallback triggered when credentials missing")
            assertTest(missingFallbackTriggered.value == true, "Missing credentials triggered onFallbackTriggered callback")

            // Test AppState showHUDWarning on MainActor
            await MainActor.run {
                let state = AppState.shared
                state.showHUDWarning("⚠️ Fallback: Google Translate", duration: 1.0)
                assertTest(state.hudWarning == "⚠️ Fallback: Google Translate", "AppState showHUDWarning sets hudWarning property")
            }
        } catch {
            print("  ❌ [FAIL] Cloudflare Workers AI Test Error: \(error)")
            failed += 1
        }

        // Test 18: Translation LRU Cache and Multi-Engine Deduplication
        do {
            // 1. TranslationLRUCache Unit Tests
            let lru = TranslationLRUCache(capacity: 3)
            let k1 = TranslationCacheKey(text: "Hello", sourceLanguage: "en", targetLanguage: "vi", engineType: "apple")
            let k2 = TranslationCacheKey(text: "World", sourceLanguage: "en", targetLanguage: "vi", engineType: "apple")
            let k3 = TranslationCacheKey(text: "Goodbye", sourceLanguage: "en", targetLanguage: "vi", engineType: "apple")
            let k4 = TranslationCacheKey(text: "Welcome", sourceLanguage: "en", targetLanguage: "vi", engineType: "apple")

            lru.set(k1, value: "Xin chào")
            lru.set(k2, value: "Thế giới")
            lru.set(k3, value: "Tạm biệt")

            assertTest(lru.count == 3, "TranslationLRUCache holds 3 items")
            assertTest(lru.get(k1) == "Xin chào", "TranslationLRUCache retrieves k1")

            // Accessing k1 makes k2 the oldest. Inserting k4 should evict k2.
            lru.set(k4, value: "Chào mừng")
            assertTest(lru.count == 3, "TranslationLRUCache maintains maximum capacity")
            assertTest(lru.get(k2) == nil, "TranslationLRUCache evicts least recently used item k2")
            assertTest(lru.get(k1) == "Xin chào", "TranslationLRUCache preserves recently accessed k1")
            assertTest(lru.get(k3) == "Tạm biệt", "TranslationLRUCache preserves k3")
            assertTest(lru.get(k4) == "Chào mừng", "TranslationLRUCache contains newly added k4")

            lru.clear()
            assertTest(lru.count == 0, "TranslationLRUCache clear() removes all entries")
            assertTest(lru.get(k1) == nil, "TranslationLRUCache get() returns nil after clear")

            // 2. TranslationCoordinator caching across engines
            final class MockHTTPProtocol: URLProtocol, @unchecked Sendable {
                nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
                override class func canInit(with request: URLRequest) -> Bool { true }
                override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
                override func startLoading() {
                    guard let h = MockHTTPProtocol.handler else {
                        client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                        return
                    }
                    do {
                        let (response, data) = try h(request)
                        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                        client?.urlProtocol(self, didLoad: data)
                        client?.urlProtocolDidFinishLoading(self)
                    } catch {
                        client?.urlProtocol(self, didFailWithError: error)
                    }
                }
                override func stopLoading() {}
            }

            let sessionConfig = URLSessionConfiguration.ephemeral
            sessionConfig.protocolClasses = [MockHTTPProtocol.self]
            let testSession = URLSession(configuration: sessionConfig)

            let coordinator = TranslationCoordinator(cacheCapacity: 10)
            coordinator.googleFreeEngine.session = testSession

            var googleHitCount = 0
            MockHTTPProtocol.handler = { req in
                googleHitCount += 1
                let googleJSON = "[[[\"Dịch mẫu\",\"Sample text\",null,null,10]]]"
                let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                return (resp, googleJSON.data(using: .utf8)!)
            }

            let firstTrans = try await coordinator.translate(text: "Sample text", sourceLanguage: "en", targetLanguage: "vi", engineType: "google_free")
            assertTest(firstTrans == "Dịch mẫu", "Coordinator translates via Google engine on cache miss")
            assertTest(googleHitCount == 1, "Coordinator hits network on first request")
            assertTest(coordinator.cachedTranslationsCount == 1, "Coordinator records translation in cache")

            let secondTrans = try await coordinator.translate(text: "  Sample text  \n", sourceLanguage: "en", targetLanguage: "vi", engineType: "google_free")
            assertTest(secondTrans == "Dịch mẫu", "Coordinator returns cached translation for identical normalized text")
            assertTest(googleHitCount == 1, "Coordinator does not hit network on cache hit")

            // Changing targetLanguage misses cache and invokes engine
            MockHTTPProtocol.handler = { req in
                googleHitCount += 1
                let googleJSON = "[[[\"Texte échantillon\",\"Sample text\",null,null,10]]]"
                let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                return (resp, googleJSON.data(using: .utf8)!)
            }
            let frTrans = try await coordinator.translate(text: "Sample text", sourceLanguage: "en", targetLanguage: "fr", engineType: "google_free")
            assertTest(frTrans == "Texte échantillon", "Coordinator translates new language combination")
            assertTest(googleHitCount == 2, "Coordinator hits network when target language differs")
            assertTest(coordinator.cachedTranslationsCount == 2, "Coordinator caches new language entry separately")

            // Test clearCache
            coordinator.clearCache()
            assertTest(coordinator.cachedTranslationsCount == 0, "Coordinator clearCache() resets cache count to 0")

            // 3. SubtitlePipeline single-shot scan deduplication
            func makePipelineTestImage(text: String, width: Int = 400, height: Int = 80) -> CGImage {
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                let ctx = CGContext(
                    data: nil,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width * 4,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                )!
                ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1.0))
                ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
                if !text.isEmpty {
                    let font = CTFontCreateWithName("Helvetica" as CFString, 24, nil)
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: font,
                        .foregroundColor: CGColor(red: 1, green: 1, blue: 1, alpha: 1)
                    ]
                    let attrString = CFAttributedStringCreate(nil, text as CFString, attributes as CFDictionary)!
                    let line = CTLineCreateWithAttributedString(attrString)
                    ctx.textPosition = CGPoint(x: 10, y: 25)
                    CTLineDraw(line, ctx)
                }
                return ctx.makeImage()!
            }

            let mockCapture = StaticImageFrameProvider()
            let mockTranslator = MockTranslationProvider(prefix: "PIPELINE_TRANS")
            let pipeline = SubtitlePipeline(captureProvider: mockCapture, translationProvider: mockTranslator)

            let pConfig = SubtitlePipelineConfig(sourceLanguage: "en", targetLanguage: "vi")
            let pRect = CGRect(x: 10, y: 10, width: 400, height: 80)

            let testImg = makePipelineTestImage(text: "Optimized Dialogue")
            mockCapture.setImages([testImg])

            // First scanOnce
            let scan1 = await pipeline.scanOnce(rect: pRect, config: pConfig)
            if case let .dialogue(src, trans, _) = scan1 {
                assertTest(src.contains("Optimized Dialogue"), "scanOnce first scan recognizes dialogue")
                assertTest(trans.contains("PIPELINE_TRANS"), "scanOnce first scan translates dialogue")
            } else {
                assertTest(false, "scanOnce first scan should emit .dialogue")
            }
            assertTest(mockTranslator.callCount == 1, "mockTranslator called once on first scanOnce")

            // Second scanOnce on matching scan
            mockCapture.setImages([testImg])
            let scan2 = await pipeline.scanOnce(rect: pRect, config: pConfig)
            if case let .dialogue(src, trans, _) = scan2 {
                assertTest(src.contains("Optimized Dialogue"), "scanOnce second scan retains recognized text")
                assertTest(trans.contains("PIPELINE_TRANS"), "scanOnce second scan retains translated text without hitting provider")
            } else {
                assertTest(false, "scanOnce second scan on identical text should emit .dialogue")
            }
            assertTest(mockTranslator.callCount == 1, "mockTranslator not called again when scan matches previous one")

            // Third scan with altered config (targetLanguage: "ja")
            let pConfigJa = SubtitlePipelineConfig(sourceLanguage: "en", targetLanguage: "ja")
            mockCapture.setImages([testImg])
            let scan3 = await pipeline.scanOnce(rect: pRect, config: pConfigJa)
            if case let .dialogue(_, trans, _) = scan3 {
                assertTest(trans.contains("PIPELINE_TRANS"), "scanOnce translates when config changes")
            } else {
                assertTest(false, "scanOnce with changed config should emit .dialogue")
            }
            assertTest(mockTranslator.callCount == 2, "mockTranslator invoked when config changes even if text is identical")

            // Fourth scan: continuous process on identical dialogue emits .unchanged
            mockCapture.setImages([testImg])
            let streamOutput = try await pipeline.process(rect: pRect, config: pConfigJa, force: false)
            assertTest(streamOutput == .unchanged, "continuous scan on identical dialogue emits .unchanged")
            assertTest(mockTranslator.callCount == 2, "continuous scan on identical dialogue does not hit translation provider")
        } catch {
            print("  ❌ [FAIL] Test 18 Error: \(error)")
            failed += 1
        }

        // Test 19: Dialogue Formatting & Structural Alignment for LLM Translations
        do {
            // 1. parseStructure tests
            let struct1 = DialogueTextReconstructor.parseStructure(line: "1. [PERSUASION] *Draw your weapon.*")
            assertTest(struct1.choicePrefix == "1. ", "parseStructure identifies choice prefix '1. '")
            assertTest(struct1.tagPrefix == "[PERSUASION] ", "parseStructure identifies tag prefix '[PERSUASION] '")
            assertTest(struct1.speakerPrefix == nil, "parseStructure has nil speaker prefix when absent")
            assertTest(struct1.isActionWrapped == true, "parseStructure detects action wrapped in asterisks")
            assertTest(struct1.content == "*Draw your weapon.*", "parseStructure preserves content")

            let struct2 = DialogueTextReconstructor.parseStructure(line: "Shadowheart: I need a moment.")
            assertTest(struct2.speakerPrefix == "Shadowheart: ", "parseStructure identifies speaker prefix 'Shadowheart: '")
            assertTest(struct2.choicePrefix == nil, "parseStructure has nil choice prefix for speaker turn")
            assertTest(struct2.tagPrefix == nil, "parseStructure has nil tag prefix for speaker turn")
            assertTest(struct2.isActionWrapped == false, "parseStructure detects plain dialogue not action wrapped")

            // 2. alignTranslation with missing choice numbers
            let srcChoices = """
            1. Stand your ground and fight.
            2. Run for the shadows.
            """
            let rawLLMChoicesNoPrefix = """
            Đứng vững và chiến đấu.
            Chạy vào bóng tối.
            """
            let alignedChoices = DialogueTextReconstructor.alignTranslation(sourceText: srcChoices, translatedText: rawLLMChoicesNoPrefix)
            let expectedChoices = """
            1. Đứng vững và chiến đấu.
            2. Chạy vào bóng tối.
            """
            assertTest(alignedChoices == expectedChoices, "alignTranslation restores missing choice numbers on matching lines")

            // 3. alignTranslation with collapsed multi-line choices
            let collapsedLLMChoices = "1. Đứng vững và chiến đấu. 2. Chạy vào bóng tối."
            let uncollapsedAligned = DialogueTextReconstructor.alignTranslation(sourceText: srcChoices, translatedText: collapsedLLMChoices)
            assertTest(uncollapsedAligned == expectedChoices, "alignTranslation splits collapsed single-line choices into separate lines")

            // 4. alignTranslation with translated speaker name
            let srcSpeaker = "Shadowheart: I need a moment."
            let rawTranslatedSpeaker = "Trái Tim Bóng Tối: Tôi cần một chút thời gian."
            let alignedSpeaker = DialogueTextReconstructor.alignTranslation(sourceText: srcSpeaker, translatedText: rawTranslatedSpeaker)
            assertTest(alignedSpeaker == "Shadowheart: Tôi cần một chút thời gian.", "alignTranslation anchors original speaker name verbatim")

            // 5. alignTranslation with translated tag
            let srcTag = "[INTIMIDATION] Back off before things get ugly."
            let rawTranslatedTag = "[ĐE DỌA] Lùi lại trước khi mọi chuyện trở nên tồi tệ."
            let alignedTag = DialogueTextReconstructor.alignTranslation(sourceText: srcTag, translatedText: rawTranslatedTag)
            assertTest(alignedTag == "[INTIMIDATION] Lùi lại trước khi mọi chuyện trở nên tồi tệ.", "alignTranslation restores original bracketed gameplay tag verbatim")

            // 6. alignTranslation with action formatting restoration
            let srcAction = "1. [ROGUE] *Pick the lock while the guard is distracted.*"
            let rawTranslatedAction = "Phá khóa khi tên lính gác mất tập trung."
            let alignedAction = DialogueTextReconstructor.alignTranslation(sourceText: srcAction, translatedText: rawTranslatedAction)
            assertTest(alignedAction == "1. [ROGUE] *Phá khóa khi tên lính gác mất tập trung.*", "alignTranslation restores choice, tag, and enclosing action asterisks")

            // 7. End-to-end CloudflareWorkersAITranslationEngine with alignment
            final class CFAlignMockProtocol: URLProtocol, @unchecked Sendable {
                nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
                override class func canInit(with request: URLRequest) -> Bool { true }
                override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
                override func startLoading() {
                    guard let h = CFAlignMockProtocol.handler else {
                        client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                        return
                    }
                    do {
                        let (response, data) = try h(request)
                        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                        client?.urlProtocol(self, didLoad: data)
                        client?.urlProtocolDidFinishLoading(self)
                    } catch {
                        client?.urlProtocol(self, didFailWithError: error)
                    }
                }
                override func stopLoading() {}
            }

            let cfAlignSessionConfig = URLSessionConfiguration.ephemeral
            cfAlignSessionConfig.protocolClasses = [CFAlignMockProtocol.self]
            let cfAlignSession = URLSession(configuration: cfAlignSessionConfig)
            let cfAlignEngine = CloudflareWorkersAITranslationEngine(session: cfAlignSession)

            var interceptedPrompt: String?
            CFAlignMockProtocol.handler = { req in
                if let bodyData = req.httpBody {
                    interceptedPrompt = String(data: bodyData, encoding: .utf8)
                } else if let stream = req.httpBodyStream {
                    stream.open()
                    var data = Data()
                    let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: 512)
                    defer { buf.deallocate() }
                    while stream.hasBytesAvailable {
                        let n = stream.read(buf, maxLength: 512)
                        if n > 0 { data.append(buf, count: n) } else { break }
                    }
                    stream.close()
                    interceptedPrompt = String(data: data, encoding: .utf8)
                }
                let llmResponse = "{\"success\":true,\"result\":{\"response\":\"Người kể chuyện: Đêm nay gió lạnh buốt.\"}}"
                let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                return (resp, llmResponse.data(using: .utf8)!)
            }

            let cfConfig = CloudflareConfig(
                accountId: "acc_123",
                apiToken: "tok_123"
            )
            let result = try await cfAlignEngine.translate(
                text: "Narrator: The wind is cold tonight.",
                sourceLanguage: "en",
                targetLanguage: "vi",
                config: cfConfig
            )

            assertTest(interceptedPrompt?.contains("Preserve character speaker names") == true, "Cloudflare prompt includes verbatim speaker name preservation rule")
            assertTest(interceptedPrompt?.contains("Preserve the EXACT line breaks") == true, "Cloudflare prompt includes line break preservation rule")
            assertTest(result == "Narrator: Đêm nay gió lạnh buốt.", "Cloudflare translation engine restores original speaker label on output")
        } catch {
            print("  ❌ [FAIL] Test 19 Error: \(error)")
            failed += 1
        }

        print("\n🏁 Results: \(passed) passed, \(failed) failed.")
        if failed > 0 {
            exit(1)
        }
    }
}
