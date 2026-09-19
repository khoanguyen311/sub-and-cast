import SwiftUI
import AppKit

public struct ShortcutRecorderView: View {
    @Binding var hotkey: AppHotkey?
    var onSet: ((AppHotkey) -> Void)?
    var onClear: (() -> Void)?

    @State private var isRecording = false
    @State private var keyMonitor: Any?

    public init(
        hotkey: Binding<AppHotkey?>,
        onSet: ((AppHotkey) -> Void)? = nil,
        onClear: (() -> Void)? = nil
    ) {
        self._hotkey = hotkey
        self.onSet = onSet
        self.onClear = onClear
    }

    public var body: some View {
        HStack(spacing: 6) {
            Button {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            } label: {
                HStack(spacing: 6) {
                    if isRecording {
                        Image(systemName: "record.circle.fill")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 10))
                        Text("Type Shortcut...")
                            .foregroundColor(.accentColor)
                    } else if let hotkey = hotkey {
                        Text(hotkey.displayString)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    } else {
                        Text("Record Shortcut")
                            .foregroundColor(.secondary)
                    }
                }
                .font(.system(size: 12))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .frame(minWidth: 120)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isRecording ? Color.accentColor.opacity(0.12) : Color(NSColor.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(isRecording ? Color.accentColor : Color(NSColor.separatorColor), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)

            if hotkey != nil && !isRecording {
                Button {
                    hotkey = nil
                    onClear?()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .help("Clear shortcut")
            }
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        stopRecording()
        isRecording = true

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Escape cancels recording without changing existing shortcut
            if event.keyCode == 53 {
                stopRecording()
                return nil
            }

            // Strict rule: Require at least one modifier key
            let modifierFlags = event.modifierFlags.intersection([.command, .option, .control, .shift])
            if modifierFlags.isEmpty {
                NSSound.beep()
                return nil
            }

            if let newHotkey = AppHotkey(from: event) {
                self.hotkey = newHotkey
                self.onSet?(newHotkey)
                self.stopRecording()
                return nil
            }

            return event
        }
    }

    private func stopRecording() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        isRecording = false
    }
}
