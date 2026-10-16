import SwiftUI

public struct EmptyStateGuideView: View {
    @ObservedObject var adbService = ADBService.shared
    @State private var showBrandTips: Bool = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "iphone.and.arrow.forward")
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor)
                        .padding(.top, 16)

                    Text("Belum Ada HP Android Terhubung")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Ikuti 4 langkah mudah di bawah ini untuk menghubungkan HP ke Mac")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Steps Cards
                VStack(spacing: 12) {
                    StepCard(
                        number: "1",
                        icon: "gearshape.fill",
                        iconColor: .blue,
                        title: "Buka Pengaturan HP",
                        description: "Buka aplikasi Pengaturan (Settings) di HP Android kamu."
                    )

                    StepCard(
                        number: "2",
                        icon: "hand.tap.fill",
                        iconColor: .purple,
                        title: "Aktifkan Mode Pengembang",
                        description: "Cari menu Tentang Ponsel (About Phone) → Ketuk Nomor Versi (Build Number) sebanyak 7 kali berturut-turut sampai muncul 'You are now a developer'."
                    )

                    StepCard(
                        number: "3",
                        icon: "wrench.and.screwdriver.fill",
                        iconColor: .orange,
                        title: "Nyalakan USB Debugging",
                        description: "Buka menu Opsi Pengembang (Developer Options) → Aktifkan sakelar USB Debugging."
                    )

                    StepCard(
                        number: "4",
                        icon: "cable.connector",
                        iconColor: .green,
                        title: "Colok Kabel & Beri Izin",
                        description: "Hubungkan kabel data dari HP ke Mac. Saat muncul jendela konfirmasi di layar HP, centang 'Selalu izinkan dari komputer ini' lalu ketuk OK."
                    )
                }
                .padding(.horizontal)

                // Refresh Button
                Button(action: {
                    adbService.refreshDevices()
                }) {
                    HStack(spacing: 8) {
                        if adbService.isScanning {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(adbService.isScanning ? "Mencari HP..." : "Pindai Ulang Perangkat")
                            .fontWeight(.medium)
                    }
                    .frame(minWidth: 200)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                // Brand specific tips
                DisclosureGroup("Tips Tambahan untuk Xiaomi, Realme, OPPO, & Vivo", isExpanded: $showBrandTips) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• **Xiaomi / Redmi / POCO**: Di Opsi Pengembang, selain 'USB Debugging', pastikan juga mengaktifkan **'USB Debugging (Security settings)'** agar layar bisa diklik/dikontrol dari Mac.")
                        Text("• **Realme / OPPO / OnePlus**: Matikan opsi 'Disable Permission Monitoring' jika sentuhan mouse tidak merespons.")
                        Text("• **Samsung Galaxy**: Pastikan menggunakan kabel data yang mendukung transfer data (bukan hanya kabel pengisi daya biasa).")
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                .cornerRadius(10)
                .padding(.horizontal)
            }
            .padding(.bottom, 24)
        }
    }
}

private struct StepCard: View {
    let number: String
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.system(size: 18, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Langkah \(number)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(iconColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(iconColor.opacity(0.12))
                        .cornerRadius(4)

                    Text(title)
                        .font(.headline)
                }

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
