import SwiftUI

public struct CaptureSettingsView: View {
    @ObservedObject var appState: AppState
    @State private var showingResetAlert = false

    public init(appState: AppState) {
        self.appState = appState
    }

    private var previewImage: NSImage? {
        if let image = NSImage(named: "GamePreviewMockup") {
            return image
        }
        if let image = NSImage(named: "game_preview") {
            return image
        }
        #if SWIFT_PACKAGE
        if let url = Bundle.module.url(forResource: "game_preview", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        #endif
        if let url = Bundle.main.url(forResource: "game_preview", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        let fallbackPath = "/Users/khoa/personal/sub-and-cast/Sources/SubAndCastKit/Resources/game_preview.png"
        if FileManager.default.fileExists(atPath: fallbackPath),
           let image = NSImage(contentsOfFile: fallbackPath) {
            return image
        }
        return nil
    }

    public var body: some View {
        Form {
            // MARK: - Zone Positioning & Manual Coordinates
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    // 1. OCR Capture Area
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "viewfinder")
                                .foregroundColor(.cyan)
                                .font(.caption.bold())
                            Text("OCR Capture Area")
                                .font(.subheadline.bold())
                        }

                        HStack(alignment: .center, spacing: 10) {
                            CoordinateField(label: "X:", value: $appState.currentProfile.sourceRect.x, range: 0...4000)
                            CoordinateField(label: "Y:", value: $appState.currentProfile.sourceRect.y, range: 0...4000)

                            Capsule()
                                .fill(Color.secondary.opacity(0.25))
                                .frame(width: 1, height: 14)

                            CoordinateField(label: "W:", value: $appState.currentProfile.sourceRect.width, range: Int(CodableRect.minWidth)...3000)
                            CoordinateField(label: "H:", value: $appState.currentProfile.sourceRect.height, range: Int(CodableRect.minHeight)...1500)

                            Spacer()
                        }
                    }

                    // 2. Clean Hairline Divider
                    Divider()
                        .padding(.vertical, 2)

                    // 3. Subtitle Display Area
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "captions.bubble")
                                .foregroundColor(.orange)
                                .font(.caption.bold())
                            Text("Subtitle Display Area")
                                .font(.subheadline.bold())
                        }

                        HStack(alignment: .center, spacing: 10) {
                            CoordinateField(label: "X:", value: $appState.currentProfile.displayRect.x, range: 0...4000)
                            CoordinateField(label: "Y:", value: $appState.currentProfile.displayRect.y, range: 0...4000)

                            Capsule()
                                .fill(Color.secondary.opacity(0.25))
                                .frame(width: 1, height: 14)

                            CoordinateField(label: "W:", value: $appState.currentProfile.displayRect.width, range: Int(CodableRect.minWidth)...3000)
                            CoordinateField(label: "H:", value: $appState.currentProfile.displayRect.height, range: Int(CodableRect.minHeight)...1500)

                            Spacer()
                        }
                    }

                    // 4. Action Row Aligned to Bottom-Right
                    HStack(spacing: 8) {
                        Spacer()

                        // Secondary Utility Action: Reset
                        Button {
                            showingResetAlert = true
                        } label: {
                            Label("Reset", systemImage: "arrow.counterclockwise")
                        }
                        .buttonStyle(.bordered)
                        .foregroundStyle(.secondary)
                        .controlSize(.regular)
                        .help("Reset both overlay zones to centered defaults")

                        // Position / Save & Done
                        if appState.isPositioningOverlays {
                            Button {
                                appState.finishPositioningOverlays()
                            } label: {
                                Label("Save & Done", systemImage: "checkmark.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .controlSize(.regular)
                            .help("Save positions and lock overlays")
                        } else {
                            Button {
                                appState.startPositioningOverlays()
                            } label: {
                                Label("Position", systemImage: "viewfinder")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .help("Show draggable overlay boxes on screen")
                        }
                    }
                    .padding(.top, 10)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Zone Positioning")
            }

            // MARK: - Timings
            Section {
                LabeledContent("Capture Interval") {
                    HStack(spacing: 12) {
                        Slider(value: $appState.currentProfile.captureIntervalSeconds, in: 0.3...3.0, step: 0.1)
                        Text(String(format: "%.1fs", appState.currentProfile.captureIntervalSeconds))
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                            .frame(width: 45, alignment: .trailing)
                    }
                }

                LabeledContent("Auto-Scan Fadeout") {
                    HStack(spacing: 12) {
                        Slider(value: $appState.currentProfile.fadeTimeoutSeconds, in: 1.0...10.0, step: 0.5)
                        Text(String(format: "%.1fs", appState.currentProfile.fadeTimeoutSeconds))
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                            .frame(width: 45, alignment: .trailing)
                    }
                }

                LabeledContent("One-Time Scan Fadeout") {
                    HStack(spacing: 12) {
                        Slider(value: $appState.currentProfile.oneTimeFadeTimeoutSeconds, in: 1.0...15.0, step: 0.5)
                        Text(String(format: "%.1fs", appState.currentProfile.oneTimeFadeTimeoutSeconds))
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                            .frame(width: 45, alignment: .trailing)
                    }
                }
            } header: {
                Text("Timings")
            }

            // MARK: - Text Processing
            Section {
                Toggle("Merge Wrapped Dialogue Lines", isOn: $appState.currentProfile.mergeWrappedLines)
            } header: {
                Text("Text Formatting")
            }

            // MARK: - HUD Appearance
            Section {
                // Live Subtitle Preview Canvas
                VStack(spacing: 0) {
                    ZStack {
                        if let image = previewImage {
                            Image(nsImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 85)
                                .clipped()
                        } else {
                            // Fallback gradient scene if image is not yet added
                            LinearGradient(
                                colors: [Color(hex: "1f2937"), Color(hex: "111827"), Color(hex: "374151")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        }

                        // Live Subtitle Box preview
                        Text("Xin chào thế giới / Hello World")
                            .font(.system(size: min(28, appState.currentProfile.fontSize), weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.9), radius: 2, x: 0, y: 1)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.black.opacity(appState.currentProfile.backgroundOpacity))
                                    .shadow(color: .black.opacity(0.5 * appState.currentProfile.backgroundOpacity), radius: 4, x: 0, y: 2)
                            )
                            .padding(10)
                    }
                    .frame(height: 85)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    )
                }
                .padding(.vertical, 2)

                LabeledContent("Font Size") {
                    HStack(spacing: 12) {
                        Slider(value: $appState.currentProfile.fontSize, in: 8...36, step: 1)
                        Text("\(Int(appState.currentProfile.fontSize)) pt")
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                            .frame(width: 45, alignment: .trailing)
                    }
                }

                LabeledContent("Backdrop Opacity") {
                    HStack(spacing: 12) {
                        Slider(value: $appState.currentProfile.backgroundOpacity, in: 0.0...1.0, step: 0.05)
                        Text("\(Int(appState.currentProfile.backgroundOpacity * 100))%")
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                            .frame(width: 45, alignment: .trailing)
                    }
                }
            } header: {
                Text("HUD Appearance")
            }
        }
        .formStyle(.grouped)
        .alert("Reset Overlay Zones?", isPresented: $showingResetAlert) {
            Button("Reset", role: .destructive) {
                appState.resetOverlayZonesToDefault()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will reset both the OCR capture zone and subtitle display zone to centered defaults.")
        }
    }
}

// MARK: - Coordinate Input Field
struct CoordinateField: View {
    let label: String
    @Binding var value: CGFloat
    let range: ClosedRange<Int>

    private var intBinding: Binding<Int> {
        Binding(
            get: { Int(value.rounded()) },
            set: { value = CGFloat(max(range.lowerBound, min(range.upperBound, $0))) }
        )
    }

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 16, alignment: .leading)

            TextField("", value: intBinding, format: .number.grouping(.never))
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(width: 48, height: 19)

            Stepper("", value: intBinding, in: range, step: 1)
                .labelsHidden()
                .fixedSize()
        }
        .controlSize(.small)
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: 92, alignment: .leading)
    }
}

// MARK: - Color Hex Initializer
private extension Color {
    init(hex: String) {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&int)
        let r, g, b, a: Double
        switch cleanHex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
            a = 1.0
        case 8:
            r = Double((int >> 24) & 0xFF) / 255
            g = Double((int >> 16) & 0xFF) / 255
            b = Double((int >> 8) & 0xFF) / 255
            a = Double(int & 0xFF) / 255
        default:
            r = 0.12; g = 0.16; b = 0.22; a = 1.0
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
