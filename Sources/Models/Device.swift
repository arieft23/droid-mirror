import Foundation

public enum DeviceState: String, Codable, CaseIterable {
    case ready = "device"
    case unauthorized = "unauthorized"
    case offline = "offline"
    case unknown = "unknown"

    public var title: String {
        switch self {
        case .ready: return "Siap Digunakan"
        case .unauthorized: return "Butuh Otorisasi HP"
        case .offline: return "Offline"
        case .unknown: return "Tidak Diketahui"
        }
    }

    public var colorName: String {
        switch self {
        case .ready: return "green"
        case .unauthorized: return "orange"
        case .offline: return "red"
        case .unknown: return "gray"
        }
    }
}

public enum ConnectionType: String, Codable {
    case usb = "USB"
    case wifi = "Wi-Fi"
}

public struct Device: Identifiable, Hashable, Equatable {
    public let id: String // Serial number or IP:port
    public var model: String
    public var product: String
    public var deviceName: String
    public var transportId: String
    public var state: DeviceState
    public var connectionType: ConnectionType
    public var batteryLevel: Int?

    public init(
        id: String,
        model: String = "",
        product: String = "",
        deviceName: String = "",
        transportId: String = "",
        state: DeviceState = .unknown,
        connectionType: ConnectionType = .usb,
        batteryLevel: Int? = nil
    ) {
        self.id = id
        self.model = model
        self.product = product
        self.deviceName = deviceName
        self.transportId = transportId
        self.state = state
        self.connectionType = connectionType
        self.batteryLevel = batteryLevel
    }

    public var displayName: String {
        if !model.isEmpty {
            return model.replacingOccurrences(of: "_", with: " ")
        } else if !deviceName.isEmpty {
            return deviceName
        } else {
            return id
        }
    }
}

public enum PresetQuality: String, CaseIterable, Identifiable {
    case high = "Kualitas Tinggi (1080p, 60fps)"
    case balanced = "Seimbang (720p, 60fps)"
    case lowLatency = "Cepat / Low Latency (540p, 60fps)"
    case maxOriginal = "Asli / Resolusi Penuh"

    public var id: String { rawValue }

    public var maxSize: Int {
        switch self {
        case .high: return 1080
        case .balanced: return 720
        case .lowLatency: return 540
        case .maxOriginal: return 0
        }
    }

    public var bitRate: Int {
        switch self {
        case .high: return 12
        case .balanced: return 8
        case .lowLatency: return 4
        case .maxOriginal: return 16
        }
    }
}

public enum VirtualDisplayPreset: String, CaseIterable, Identifiable {
    case fhdDesktop = "1920x1080/160"
    case mangaFhd = "1920x1440/200"
    case mangaHd = "1440x1080/160"
    case fhdCompact = "1920x1080/140"
    case fhdLargeText = "1920x1080/180"
    case qhdDesktop = "2560x1440/200"
    case hdDesktop = "1280x720/120"
    case nativeDpi = "1920x1080"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .fhdDesktop: return "1080p Desktop 16:9 (160 DPI - Rekomendasi)"
        case .mangaFhd: return "📖 1920×1440 / 200 DPI (4:3 Manga Dual-Page - Super Tajam)"
        case .mangaHd: return "📖 1440×1080 / 160 DPI (4:3 Manga Dual-Page - Standar)"
        case .fhdCompact: return "1080p Kompak & Luas (140 DPI)"
        case .fhdLargeText: return "1080p Teks Lebih Besar (180 DPI)"
        case .qhdDesktop: return "2K QHD Desktop (200 DPI)"
        case .hdDesktop: return "720p HD Desktop (120 DPI)"
        case .nativeDpi: return "1080p Standar (Bawaan HP / Tanpa DPI)"
        }
    }
}

public struct ScrcpyConfig: Codable, Equatable {
    public var preset: String = PresetQuality.high.rawValue
    public var maxSize: Int = 1080
    public var bitRateMbps: Int = 8
    public var maxFps: Int = 60
    public var turnScreenOff: Bool = true // -S
    public var stayAwake: Bool = true
    public var audioEnabled: Bool = true
    public var alwaysOnTop: Bool = false
    public var fullscreen: Bool = false
    public var showTouches: Bool = false
    public var recordScreen: Bool = false
    public var customTitle: String = ""

    // Virtual New Display (--new-display)
    public var useNewDisplay: Bool = false
    public var newDisplayResolution: String = VirtualDisplayPreset.fhdDesktop.rawValue

    public init() {}
}
