# DroidMirror 📱🖥️

> **Aplikasi macOS native (SwiftUI) pembungkus `scrcpy` dan `adb` yang dirancang khusus untuk orang awam.**  
> *Plug-and-play*: Tanpa perlu buka Terminal, tanpa perlu install Homebrew, dan tanpa perlu konfigurasi rumit.

---

## 🌟 Fitur Utama

- 🚀 **Zero-Dependency (Benar-Benar Portabel)**
  - Binary `adb`, `scrcpy`, dan `scrcpy-server` sudah dibundel langsung ke dalam aplikasi.
  - Seluruh *dynamic libraries* (FFmpeg, SDL3, libusb, Opus, x264, x265, dll.) sudah direlokasi ke dalam `@rpath` aplikasi. User tidak perlu install Homebrew sama sekali.
- 📋 **Panduan Visual Ramah Pemula**
  - Jika belum ada HP terhubung, aplikasi menampilkan panduan 4 langkah bergambar untuk mengaktifkan *Developer Options* dan *USB Debugging*.
  - Dilengkapi tips khusus untuk HP Xiaomi (MIUI/HyperOS), Realme, OPPO, Vivo, dan Samsung.
- ⚡ **1-Klik Mode Nirkabel (Wi-Fi)**
  - Cukup colok kabel USB satu kali, tekan **"Ganti ke Nirkabel"**, aplikasi akan otomatis membaca IP HP dan menyambungkan via port 5555. Setelah itu kabel USB bisa langsung dicabut!
- 🎛️ **Preset Kualitas & Kontrol Praktis**
  - Pilihan preset instan: *Kualitas Tinggi (1080p, 60fps)*, *Seimbang (720p)*, *Low Latency (540p)*, atau *Resolusi Asli*.
  - **Matikan Layar HP saat Mirror**: Mencegah HP panas dan menghemat baterai saat sedang ditampilkan di Mac.
  - **Forward Audio**: Memutar suara HP langsung lewat speaker Mac.
  - **Jendela Selalu di Atas (Always on Top)** & **Mode Fullscreen**.
- 🛠️ **Alat Bantu Tambahan**
  - **Ambil Screenshot**: Sekali klik, screenshot HP langsung tersimpan di folder *Downloads* Mac.
  - **Pasang File APK**: Pilih file APK dari Mac, langsung terpasang di HP.
  - **Kontrol Navigasi Virtual**: Tombol Back, Home, App Switcher, Volume Up/Down, dan Power.
- 📝 **Terminal Log Collapsible**
  - Drawer log bawaan yang bisa dibuka jika ingin melihat status atau mendiagnosis kendala koneksi.

---

## ⚡ Cara Pasang Paling Mudah (One-Line Installer)

Cukup buka aplikasi **Terminal** di Mac kamu, lalu salin dan tempel perintah di bawah ini:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/arieft23/droid-mirror/main/install.sh)"
```

**Apa yang dilakukan script ini secara otomatis?**
1. Mendeteksi arsitektur Mac kamu (Apple Silicon M-Series).
2. Mengunduh file `.app` versi terbaru dari GitHub.
3. Memasangnya ke folder `/Applications`.
4. **Membersihkan proteksi Gatekeeper (`xattr -cr`)** sehingga tidak muncul error *"App is damaged"*.
5. Langsung membuka aplikasi **DroidMirror** di layar!

---

```
droid-mirror/
├── Sources/
│   ├── App.swift                 # Entry point SwiftUI (@main)
│   ├── Models/
│   │   └── Device.swift          # Model Perangkat & Konfigurasi Scrcpy
│   ├── Services/
│   │   ├── BinaryResolver.swift  # Pendeteksi binary bawaan (bundled) vs system
│   │   ├── ProcessRunner.swift   # Eksekutor child process async (Process & Pipe)
│   │   ├── ADBService.swift      # Manajemen perangkat, baterai, wifi, screenshot, APK
│   │   └── ScrcpyService.swift   # Lifecycle runner scrcpy & streaming log
│   └── Views/
│       ├── ContentView.swift           # Layout utama (Sidebar + Detail)
│       ├── DeviceDetailView.swift      # Panel kontrol, preset, dan tombol aksi
│       ├── EmptyStateGuideView.swift   # Panduan pemula langkah-demi-langkah
│       ├── WirelessConnectSheet.swift  # Modal setup koneksi Wi-Fi
│       └── LogDrawerView.swift         # Drawer log scrcpy & adb
├── Resources/
│   └── Info.plist                # Metadata macOS App Bundle
├── scripts/
│   └── bundle_app.py             # Script otomatis: compile Swift + relink 21 dylibs + ad-hoc sign
├── .gitignore
├── LICENSE
└── README.md
```

---

## 🛠️ Cara Build dari Source

### Kebutuhan Sistem
- macOS 13.0+ (Ventura, Sonoma, Sequoia, Tahoe)
- Apple Silicon (M1/M2/M3/M4) atau Intel Mac
- Command Line Tools (`xcode-select --install`)
- Python 3

### Langkah Build

1. **Jalankan script bundler**:
   ```bash
   ./scripts/bundle_app.py
   ```
2. Script ini akan secara otomatis:
   - Meng-compile seluruh source code Swift dengan optimasi `-O`.
   - Menyiapkan struktur `.app` bundle di `build/DroidMirror.app`.
   - Menyalin binary `adb`, `scrcpy`, dan `scrcpy-server`.
   - Mengumpulkan seluruh 21 dependensi `.dylib` ke `Contents/Frameworks/`.
   - Memperbaiki path library dengan `install_name_tool` ke `@rpath`.
   - Melakukan ad-hoc codesigning pada seluruh file dan app bundle.
   - Menguji langsung scrcpy hasil bundle.

3. **Hasil Build**:
   Aplikasi siap jalan ada di:
   ```
   build/DroidMirror.app
   ```
   Kamu bisa langsung memindahkannya ke `/Applications` atau membungkusnya menjadi zip:
   ```bash
   zip -r -q DroidMirror-macOS.zip build/DroidMirror.app
   ```

---

## 📱 Panduan Penggunaan untuk Pengguna

1. Download dan buka **DroidMirror.app**.
2. Di HP Android:
   - Masuk ke **Pengaturan** -> **Tentang Ponsel**.
   - Ketuk **Nomor Versi (Build Number)** 7 kali hingga muncul pemberitahuan *"You are now a developer"*.
   - Masuk ke **Opsi Pengembang (Developer Options)** -> Aktifkan **USB Debugging**.
3. Hubungkan HP ke Mac menggunakan kabel data USB.
4. Pada layar HP, centang *"Selalu izinkan dari komputer ini"* lalu tekan **OK**.
5. Nama HP kamu akan langsung muncul di **DroidMirror**.
6. Tekan tombol besar **"Mulai Mirroring Layar"**!

---

## 📄 Lisensi
Didistribusikan di bawah lisensi [MIT](LICENSE).
Sistem ini menggunakan binary upstream dari [Genymobile/scrcpy](https://github.com/Genymobile/scrcpy) dan Android Platform Tools (ADB).
