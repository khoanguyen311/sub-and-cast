import SwiftUI

public struct CaptureSettingsView: View {
    @ObservedObject var appState: AppState
    @State private var showingResetAlert = false

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        Form {
            // MARK: - Zone Positioning & Manual Coordinates
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    // 1. OCR Capture Area
                    ZoneCoordinateRow(
                        title: "OCR Capture Area",
                        iconName: "viewfinder",
                        iconColor: .cyan,
                        rect: $appState.currentProfile.sourceRect
                    )

                    // 2. Clean Hairline Divider
                    Divider()
                        .padding(.vertical, 2)

                    // 3. Subtitle Display Area
                    ZoneCoordinateRow(
                        title: "Subtitle Display Area",
                        iconName: "captions.bubble",
                        iconColor: .orange,
                        rect: $appState.currentProfile.displayRect
                    )

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
                    .padding(.top, 4)
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

                LabeledContent("Subtitle Fadeout") {
                    HStack(spacing: 12) {
                        Slider(value: $appState.currentProfile.fadeTimeoutSeconds, in: 1.0...10.0, step: 0.5)
                        Text(String(format: "%.1fs", appState.currentProfile.fadeTimeoutSeconds))
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                            .frame(width: 45, alignment: .trailing)
                    }
                }
            } header: {
                Text("Timings")
            }

            // MARK: - HUD Appearance
            Section {
                // Live Subtitle Preview Canvas
                VStack(spacing: 0) {
                    ZStack {
                        // In-game dark cinematic gradient background
                        LinearGradient(
                            colors: [Color(white: 0.14), Color(white: 0.08)],
                            startPoint: .top,
                            endPoint: .bottom
                        )

                        // Live Subtitle Box preview
                        Text("Xin chào thế giới / Hello World")
                            .font(.system(size: appState.currentProfile.fontSize, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.black.opacity(appState.currentProfile.backgroundOpacity))
                                    .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
                            )
                            .padding(8)
                    }
                    .frame(height: 74)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
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
                        Slider(value: $appState.currentProfile.backgroundOpacity, in: 0.2...1.0, step: 0.05)
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

// MARK: - Coordinate Row & Inputs
struct ZoneCoordinateRow: View {
    let title: String
    let iconName: String
    let iconColor: Color
    @Binding var rect: CodableRect

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .foregroundColor(iconColor)
                    .font(.caption.bold())
                Text(title)
                    .font(.subheadline.bold())
            }

            Grid(alignment: .center, horizontalSpacing: 10, verticalSpacing: 0) {
                GridRow {
                    CoordinateField(label: "X", value: $rect.x, range: 0...4000)
                    CoordinateField(label: "Y", value: $rect.y, range: 0...4000)
                    CoordinateField(label: "W", value: $rect.width, range: Int(CodableRect.minWidth)...3000)
                    CoordinateField(label: "H", value: $rect.height, range: Int(CodableRect.minHeight)...1500)
                }
            }
        }
    }
}

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
        HStack(spacing: 3) {
            Text(label)
                .font(.caption2.bold())
                .foregroundColor(.secondary)
                .frame(width: 14, alignment: .leading)

            TextField("", value: intBinding, format: .number)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(width: 50)

            Stepper("", value: intBinding, in: range, step: 10)
                .labelsHidden()
                .controlSize(.small)
        }
    }
}
