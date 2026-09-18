import SwiftUI

public enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case translation = "Translation"
    case capture = "Capture & Overlays"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .general: return "gearshape"
        case .translation: return "bubble.left.and.bubble.right"
        case .capture: return "viewfinder"
        }
    }
}

public struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var selectedTab: SettingsTab = .general
    @Namespace private var tabAnimation

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - In-Window Horizontal Tab Strip
            HStack {
                Spacer()
                tabStrip
                Spacer()
            }
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // MARK: - Modular Content Area
            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsView(appState: appState)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                case .translation:
                    TranslationSettingsView(appState: appState)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                case .capture:
                    CaptureSettingsView(appState: appState)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // MARK: - Bottom Action & Status Footer
            footerBar
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 540, height: 540)
        .navigationTitle("Preferences")
        .animation(.easeInOut(duration: 0.2), value: selectedTab)
        .onChange(of: appState.currentProfile) { _, _ in
            appState.saveCurrentProfile()
        }
    }

    // MARK: - Horizontal Segmented Pill Strip
    private var tabStrip: some View {
        HStack(spacing: 4) {
            ForEach(SettingsTab.allCases) { tab in
                let isSelected = selectedTab == tab
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    }
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color(NSColor.controlAccentColor).opacity(0.14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .stroke(Color(NSColor.controlAccentColor).opacity(0.3), lineWidth: 1)
                                )
                                .matchedGeometryEffect(id: "activePill", in: tabAnimation)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
        )
    }

    // MARK: - Footer Status & Actions
    private var footerBar: some View {
        HStack(spacing: 10) {
            // Apple-style status indicator badge
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: statusColor.opacity(0.6), radius: appState.isScanning ? 3 : 0)

                Text(appState.statusMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Compact runtime trigger buttons with SF symbols
            HStack(spacing: 8) {
                Button {
                    appState.triggerSnapshot()
                } label: {
                    Label("Snapshot", systemImage: "camera")
                }
                .controlSize(.regular)
                .help("Capture and translate a single frame")

                Button {
                    appState.toggleScanning()
                } label: {
                    Label(
                        appState.isScanning ? "Pause" : "Scan",
                        systemImage: appState.isScanning ? "pause.fill" : "play.fill"
                    )
                }
                .controlSize(.regular)
                .help(appState.isScanning ? "Pause auto-scan" : "Start continuous auto-scan")
            }
        }
    }

    private var statusColor: Color {
        if appState.isOCRActive {
            return .orange
        } else if appState.isScanning {
            return .green
        } else {
            return .gray
        }
    }
}
