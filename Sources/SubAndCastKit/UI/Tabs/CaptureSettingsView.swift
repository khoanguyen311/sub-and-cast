import SwiftUI

public struct CaptureSettingsView: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        Form {
            // MARK: - Zone Positioning & Manual Coordinates
            Section {
                // Header row with Action buttons
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Zone Coordinates")
                            .font(.body)
                        Text(appState.isPositioningOverlays ? "Drag/resize on screen or edit values below." : "Fine-tune pixel coordinates or position on-screen.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()

                    HStack(spacing: 8) {
                        Button {
                            appState.resetOverlayZonesToDefault()
                        } label: {
                            Label("Reset", systemImage: "arrow.counterclockwise")
                        }
                        .help("Reset both overlay zones to centered defaults")

                        if appState.isPositioningOverlays {
                            Button(action: {
                                appState.finishPositioningOverlays()
                            }) {
                                Label("Save & Done", systemImage: "checkmark.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                        } else {
                            Button(action: {
                                appState.startPositioningOverlays()
                            }) {
                                Label("Position", systemImage: "viewfinder")
                            }
                        }
                    }
                }
                .padding(.bottom, 2)

                // Section A: OCR Capture Zone
                ZoneCoordinateRow(
                    title: "OCR Capture Area (Source)",
                    iconName: "viewfinder",
                    iconColor: .cyan,
                    rect: $appState.currentProfile.sourceRect
                )

                // Section B: Subtitle Display Zone
                ZoneCoordinateRow(
                    title: "Subtitle Display Area (Target)",
                    iconName: "captions.bubble",
                    iconColor: .orange,
                    rect: $appState.currentProfile.displayRect
                )
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
                LabeledContent("Font Size") {
                    HStack(spacing: 12) {
                        Slider(value: $appState.currentProfile.fontSize, in: 14...36, step: 1)
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
    }
}

// MARK: - Coordinate Row & Inputs
struct ZoneCoordinateRow: View {
    let title: String
    let iconName: String
    let iconColor: Color
    @Binding var rect: CodableRect

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .foregroundColor(iconColor)
                    .font(.caption.bold())
                Text(title)
                    .font(.subheadline.bold())
            }

            HStack(spacing: 10) {
                CoordinateField(label: "X", value: $rect.x, range: 0...4000)
                CoordinateField(label: "Y", value: $rect.y, range: 0...4000)
                CoordinateField(label: "W", value: $rect.width, range: 80...3000)
                CoordinateField(label: "H", value: $rect.height, range: 40...1500)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CoordinateField: View {
    let label: String
    @Binding var value: CGFloat
    let range: ClosedRange<Int>

    private var intBinding: Binding<Int> {
        Binding(
            get: { Int(value.rounded()) },
            set: { value = CGFloat($0) }
        )
    }

    var body: some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.caption2.bold())
                .foregroundColor(.secondary)
                .frame(width: 12, alignment: .leading)

            TextField("", value: intBinding, format: .number)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(width: 52)

            Stepper("", value: intBinding, in: range, step: 10)
                .labelsHidden()
        }
    }
}
