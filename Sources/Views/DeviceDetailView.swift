import SwiftUI
import AppKit

public struct DeviceDetailView: View {
    let device: Device
    @ObservedObject var scrcpyService = ScrcpyService.shared
    @ObservedObject var adbService = ADBService.shared

    @State private var config = ScrcpyConfig()
    @State private var isShowingWirelessModal = false
    @State private var isInstallingAPK = false
    @State private var apkMessage: String?
    @State private var screenshotURL: URL?
    @State private var isTakingScreenshot = false

    public init(device: Device) {
        self.device = device
    }

    private var isThisDeviceMirroring: Bool {
        return scrcpyService.isMirroring && scrcpyService.activeDeviceId == device.id
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Card
                headerCard

                // Unauthorized warning if applicable
                if device.state == .unauthorized {
                    unauthorizedWarningCard
                }

                // Main Mirror Control Card
                if device.state == .ready {
                    mirrorControlCard
                    quickSettingsCard
                    remoteToolsCard
                }
            }
            .padding(24)
        }
        .sheet(isPresented: $isShowingWirelessModal) {
            WirelessConnectSheet(device: device)
        }
    }

    // MARK: - Subviews

    private var headerCard: some View {
        HStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 68, height: 68)

                Image(systemName: device.connectionType == .wifi ? "wifi" : "cable.connector")
                    .font(.system(size: 30))
                    .foregroundColor(.accentColor)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 10) {
                    Text(device.displayName)
                        .font(.title2)
                        .fontWeight(.bold)

                    StatusBadge(state: device.state)
                }

                HStack(spacing: 12) {
                    Label(device.connectionType.rawValue, systemImage: device.connectionType == .wifi ? "antenna.radiowaves.left.and.right" : "link")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("ID: \(device.id)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)

                    if let battery = device.batteryLevel {
                        HStack(spacing: 4) {
                            Image(systemName: battery > 20 ? "battery.75" : "battery.25")
                                .foregroundColor(battery > 20 ? .green : .red)
                            Text("\(battery)%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Spacer()

            if device.connectionType == .usb && device.state == .ready {
                Button(action: {
                    isShowingWirelessModal = true
                }) {
                    Label("Ganti ke Nirkabel (Wi-Fi)", systemImage: "wifi")
                        .font(.callout)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(18)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(14)
    }

    private var unauthorizedWarningCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.title)

            VStack(alignment: .leading, spacing: 6) {
                Text("Izin Diperlukan di Layar HP")
                    .font(.headline)
                    .foregroundColor(.orange)

                Text("Silakan cek layar ponsel kamu sekarang. Centang kotak **'Selalu izinkan dari komputer ini'** (*Always allow from this computer*), lalu tekan tombol **OK**.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Cek Lagi") {
                adbService.refreshDevices()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }

    private var mirrorControlCard: some View {
        VStack(spacing: 14) {
            Button(action: {
                if isThisDeviceMirroring {
                    scrcpyService.stopMirroring()
                } else {
                    scrcpyService.startMirroring(device: device, config: config)
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: isThisDeviceMirroring ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title2)
                    Text(isThisDeviceMirroring ? "Hentikan Mirroring" : "Mulai Mirroring Layar")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(isThisDeviceMirroring ? .red : .accentColor)
            .controlSize(.large)

            if let err = scrcpyService.errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    private var quickSettingsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pengaturan Tampilan & Performa")
                .font(.headline)

            // Display Mode Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Mode Tampilan:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("", selection: $config.useNewDisplay) {
                    Text("📱 Layar Ponsel").tag(false)
                    Text("🖥️ Layar Kedua (Virtual)").tag(true)
                }
                .pickerStyle(.segmented)

                if config.useNewDisplay {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Pilihan Resolusi:", selection: $config.newDisplayResolution) {
                            ForEach(VirtualDisplayPreset.allCases) { item in
                                Text(item.title).tag(item.rawValue)
                            }
                        }
                        .pickerStyle(.menu)

                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "sparkles")
                                .foregroundColor(.accentColor)
                                .font(.caption)
                            Text("Layar kedua bekerja secara mandiri di jendela Mac tanpa mengganggu layar utama HP.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(10)
                    .background(Color.accentColor.opacity(0.08))
                    .cornerRadius(8)
                } else {
                    Picker("Kualitas Video:", selection: $config.preset) {
                        ForEach(PresetQuality.allCases) { preset in
                            Text(preset.rawValue).tag(preset.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: config.preset) { newValue in
                        if let matched = PresetQuality.allCases.first(where: { $0.rawValue == newValue }) {
                            config.maxSize = matched.maxSize
                            config.bitRateMbps = matched.bitRate
                        }
                    }
                }
            }

            Divider()

            // Toggles Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                Toggle("Matikan Layar HP", isOn: $config.turnScreenOff)
                    .help("Menghemat baterai HP dan menjaga ponsel tetap dingin saat mirroring")

                Toggle("Jaga HP Tetap Menyala", isOn: $config.stayAwake)
                    .help("Mencegah HP mengunci layar saat terhubung")

                Toggle("Teruskan Suara ke Mac", isOn: $config.audioEnabled)
                    .help("Memutar suara dari HP melalui speaker Mac")

                Toggle("Jendela Selalu di Depan", isOn: $config.alwaysOnTop)
                    .help("Menjaga jendela tampilan selalu terlihat di atas aplikasi lain")

                Toggle("Tampilkan Titik Sentuhan", isOn: $config.showTouches)
                    .help("Menampilkan indikator sentuhan saat layar diklik")

                Toggle("Buka Layar Penuh", isOn: $config.fullscreen)
                    .help("Langsung membuka dalam mode satu layar penuh")
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private var remoteToolsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Alat Cepat & Tombol Navigasi")
                .font(.headline)

            HStack(spacing: 12) {
                // Screenshot
                Button(action: {
                    takeScreenshot()
                }) {
                    Label(isTakingScreenshot ? "Menyimpan..." : "Ambil Screenshot", systemImage: "camera")
                }
                .buttonStyle(.bordered)
                .disabled(isTakingScreenshot)

                // Install APK
                Button(action: {
                    selectAndInstallAPK()
                }) {
                    Label(isInstallingAPK ? "Memasang..." : "Pasang File APK", systemImage: "arrow.down.app")
                }
                .buttonStyle(.bordered)
                .disabled(isInstallingAPK)

                Spacer()
            }

            if let msg = apkMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Hardware Button Emulation
            HStack(spacing: 8) {
                Text("Navigasi:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button(action: { adbService.sendKeyEvent(device: device, keyCode: 4) }) {
                    Label("Kembali", systemImage: "chevron.left")
                }

                Button(action: { adbService.sendKeyEvent(device: device, keyCode: 3) }) {
                    Label("Home", systemImage: "house")
                }

                Button(action: { adbService.sendKeyEvent(device: device, keyCode: 187) }) {
                    Label("Apps", systemImage: "square.stack.3d.up")
                }

                Spacer()

                Button(action: { adbService.sendKeyEvent(device: device, keyCode: 25) }) {
                    Image(systemName: "speaker.wave.1")
                }
                .help("Kecilkan Volume")

                Button(action: { adbService.sendKeyEvent(device: device, keyCode: 24) }) {
                    Image(systemName: "speaker.wave.3")
                }
                .help("Besarkan Volume")

                Button(action: { adbService.sendKeyEvent(device: device, keyCode: 26) }) {
                    Image(systemName: "power")
                }
                .help("Tombol Daya (Kunci/Buka)")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .foregroundColor(.accentColor)
                    .font(.caption2)
                Text("Pintasan: Tekan **Option + O** di jendela layar untuk mematikan layar HP tanpa memutus koneksi.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 2)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    // MARK: - Actions

    private func takeScreenshot() {
        isTakingScreenshot = true
        Task {
            if let url = await adbService.takeScreenshot(device: device) {
                screenshotURL = url
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
            isTakingScreenshot = false
        }
    }

    private func selectAndInstallAPK() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "apk")!]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Pilih file APK yang ingin dipasang ke HP"

        if panel.runModal() == .OK, let url = panel.url {
            isInstallingAPK = true
            apkMessage = "Sedang memasang APK ke HP..."
            Task {
                let res = await adbService.installAPK(device: device, fileURL: url)
                switch res {
                case .success(let msg):
                    apkMessage = "✅ \(msg)"
                case .failure(let err):
                    apkMessage = "❌ Gagal: \(err.localizedDescription)"
                }
                isInstallingAPK = false
            }
        }
    }
}

private struct StatusBadge: View {
    let state: DeviceState

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(state.title)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .cornerRadius(6)
    }

    private var color: Color {
        switch state {
        case .ready: return .green
        case .unauthorized: return .orange
        case .offline: return .red
        case .unknown: return .gray
        }
    }
}
