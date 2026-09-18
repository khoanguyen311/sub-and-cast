import SwiftUI

public struct CaptureSettingsView: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        Form {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("On-Screen Overlay Zones")
                            .font(.body)
                        Text(appState.isPositioningOverlays ? "Drag and resize boxes on screen, then click Save & Done." : "Adjust the capture area and subtitle display area over your game.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()

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
                            Label("Position Overlays", systemImage: "viewfinder")
                        }
                    }
                }
            } header: {
                Text("Zone Positioning")
            }

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
