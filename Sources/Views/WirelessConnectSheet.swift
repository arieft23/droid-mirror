import SwiftUI

public struct WirelessConnectSheet: View {
    let device: Device
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var adbService = ADBService.shared

    @State private var isConnecting = false
    @State private var detectedIP: String = ""
    @State private var manualIP: String = ""
    @State private var errorMessage: String?
    @State private var successMessage: String?

    public init(device: Device) {
        self.device = device
    }

    public var body: some View {
        VStack(spacing: 20) {
            // Sheet Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hubungkan Nirkabel (Wi-Fi)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Mirror layar tanpa memerlukan kabel USB")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Tutup") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }

            Divider()

            // Info Card
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "wifi.circle.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 32))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Pastikan HP dan Mac Terhubung ke Wi-Fi yang Sama")
                        .font(.headline)

                    Text("Setelah tombol di bawah ditekan, mode nirkabel akan diaktifkan secara otomatis. Jika berhasil, kabel USB bisa langsung dicabut.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.blue.opacity(0.08))
            .cornerRadius(10)

            if !detectedIP.isEmpty {
                HStack {
                    Text("IP Terdeteksi:")
                        .foregroundColor(.secondary)
                    Text(detectedIP)
                        .fontWeight(.semibold)
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                }
                .padding(.horizontal)
            }

            if let err = errorMessage {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text(err)
                        .font(.subheadline)
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }

            if let success = successMessage {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(success)
                        .font(.subheadline)
                        .foregroundColor(.green)
                    Spacer()
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }

            Spacer()

            // Action Buttons
            HStack(spacing: 12) {
                Button("Batal") {
                    dismiss()
                }

                Button(action: {
                    connectWireless()
                }) {
                    HStack {
                        if isConnecting {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(isConnecting ? "Menghubungkan..." : "Aktifkan Nirkabel Sekarang")
                            .fontWeight(.medium)
                    }
                    .frame(minWidth: 180)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isConnecting)
            }
        }
        .padding(24)
        .frame(width: 480, height: 380)
        .onAppear {
            detectIP()
        }
    }

    private func detectIP() {
        Task {
            if let ip = await adbService.getDeviceIP(device: device) {
                detectedIP = ip
            }
        }
    }

    private func connectWireless() {
        isConnecting = true
        errorMessage = nil
        successMessage = nil

        Task {
            let res = await adbService.enableWirelessMode(device: device)
            switch res {
            case .success(let ip):
                successMessage = "Berhasil tersambung ke \(ip):5555! Kamu sekarang bisa mencabut kabel USB."
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                dismiss()
            case .failure(let err):
                errorMessage = err.localizedDescription
            }
            isConnecting = false
        }
    }
}
