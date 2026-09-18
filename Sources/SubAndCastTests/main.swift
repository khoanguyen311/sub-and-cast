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
                backgroundOpacity: 0.9,
                translationEngineType: "google_free"
            )

            let data = try JSONEncoder().encode(originalProfile)
            let decoded = try JSONDecoder().decode(GameProfile.self, from: data)

            assertTest(decoded.id == originalProfile.id, "GameProfile ID preserved")
            assertTest(decoded.name == "Final Fantasy XVI", "GameProfile Name preserved")
            assertTest(decoded.sourceRect.x == 150, "GameProfile Coordinates preserved")
            assertTest(decoded.sourceLanguage == "ja", "GameProfile Source Language preserved")
            assertTest(decoded.targetLanguage == "en", "GameProfile Target Language preserved")
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

        print("\n🏁 Results: \(passed) passed, \(failed) failed.")
        if failed > 0 {
            exit(1)
        }
    }
}
