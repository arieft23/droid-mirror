import SwiftUI

public struct ContentView: View {
    @ObservedObject var adbService = ADBService.shared
    @ObservedObject var scrcpyService = ScrcpyService.shared
    @State private var isLogExpanded: Bool = false
    @State private var isRestartingADB: Bool = false

    public init() {}

    public var body: some View {
        NavigationSplitView {
            sidebarContent
                .navigationSplitViewColumnWidth(min: 240, ideal: 260, max: 320)
        } detail: {
            VStack(spacing: 0) {
                if let selected = adbService.selectedDevice {
                    DeviceDetailView(device: selected)
                } else {
                    EmptyStateGuideView()
                }

                Spacer(minLength: 0)

                LogDrawerView(isExpanded: $isLogExpanded)
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    adbService.refreshDevices()
                }) {
                    Label(adbService.isScanning ? "Memindai..." : "Pindai Ulang", systemImage: "arrow.clockwise")
                }
                .disabled(adbService.isScanning)
                .help("Cari ulang perangkat Android yang terhubung")
            }

            ToolbarItem(placement: .automatic) {
                Button(action: {
                    restartADB()
                }) {
                    Label("Reset Sambungan", systemImage: "arrow.triangle.2.circlepath")
                }
                .help("Mulai ulang koneksi jika perangkat tidak terdeteksi")
            }
        }
    }

    private var sidebarContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App Branding
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(colors: [.green, .teal], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 38, height: 38)
                    Image(systemName: "display.and.arrow.down")
                        .foregroundColor(.white)
                        .font(.system(size: 20, weight: .bold))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("DroidMirror")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("Mirror Layar Android")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            // Devices List
            List(selection: $adbService.selectedDeviceId) {
                Section(header: Text("Perangkat Android (\(adbService.devices.count))")) {
                    if adbService.devices.isEmpty {
                        Text("Tidak ada HP terhubung")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(adbService.devices) { device in
                            DeviceRowView(
                                device: device,
                                isMirroring: scrcpyService.isMirroring && scrcpyService.activeDeviceId == device.id
                            )
                            .tag(device.id)
                        }
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            // Bottom Status Info
            HStack(spacing: 8) {
                if let resolved = BinaryResolver.shared.resolve() {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                    Text(resolved.isBundled ? "Mode Portabel (Bundled)" : "Homebrew Terdeteksi")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 7, height: 7)
                    Text("Binary Belum Siap")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
        }
    }

    private func restartADB() {
        isRestartingADB = true
        Task {
            await adbService.restartServer()
            isRestartingADB = false
        }
    }
}

private struct DeviceRowView: View {
    let device: Device
    let isMirroring: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: device.connectionType == .wifi ? "wifi" : "iphone")
                .foregroundColor(device.state == .ready ? .accentColor : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(device.connectionType.rawValue)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if let battery = device.batteryLevel {
                        Text("• \(battery)%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            if isMirroring {
                Image(systemName: "record.circle")
                    .foregroundColor(.red)
                    .font(.caption)
            } else {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch device.state {
        case .ready: return .green
        case .unauthorized: return .orange
        case .offline: return .red
        case .unknown: return .gray
        }
    }
}
