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

public enum DisplayOrientation: String, Codable, CaseIterable, Identifiable {
    case landscape = "Landscape"
    case portrait = "Portrait"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .landscape: return "🖥️ Landscape (Mendatar)"
        case .portrait: return "📱 Portrait (Tegak)"
        }
    }
}

public enum VirtualDisplayPreset: String, CaseIterable, Identifiable {
    // Landscape (diurutkan dari resolusi tertinggi)
    case landQhd = "2560x1440/200"
    case landQhdFourThree = "1920x1440/200"
    case landFhd = "1920x1080/160"
    case landFhdLargeText = "1920x1080/180"
    case landFhdCompact = "1920x1080/140"
    case landFhdFourThree = "1440x1080/160"
    case landHd = "1280x720/120"

    // Portrait (diurutkan dari resolusi tertinggi)
    case portFlagship = "1080x2400/360"
    case portFoldCover = "960x2200/320"
    case portFhd = "1080x1920/320"
    case portTabletReading = "1080x1440/220"
    case portHdPlus = "720x1600/260"
    case portHd = "720x1280/220"

    public var id: String { rawValue }

    public var orientation: DisplayOrientation {
        switch self {
        case .landQhd, .landQhdFourThree, .landFhd, .landFhdLargeText, .landFhdCompact, .landFhdFourThree, .landHd:
            return .landscape
        case .portFlagship, .portFoldCover, .portFhd, .portTabletReading, .portHdPlus, .portHd:
            return .portrait
        }
    }

    public var title: String {
        switch self {
        // Landscape
        case .landQhd: return "2560 × 1440 (16:9) • 200 DPI"
        case .landQhdFourThree: return "1920 × 1440 (4:3) • 200 DPI"
        case .landFhd: return "1920 × 1080 (16:9) • 160 DPI (Standar)"
        case .landFhdLargeText: return "1920 × 1080 (16:9) • 180 DPI (Teks Besar)"
        case .landFhdCompact: return "1920 × 1080 (16:9) • 140 DPI (Kompak)"
        case .landFhdFourThree: return "1440 × 1080 (4:3) • 160 DPI"
        case .landHd: return "1280 × 720 (16:9) • 120 DPI (Ringan)"

        // Portrait
        case .portFlagship: return "1080 × 2400 (20:9) • 360 DPI (Standar HP)"
        case .portFoldCover: return "960 × 2200 (21:9) • 320 DPI (Ramping / Fold)"
        case .portFhd: return "1080 × 1920 (16:9) • 320 DPI"
        case .portTabletReading: return "1080 × 1440 (3:4) • 220 DPI (Baca Dokumen)"
        case .portHdPlus: return "720 × 1600 (20:9) • 260 DPI"
        case .portHd: return "720 × 1280 (16:9) • 220 DPI (Ringan)"
        }
    }

    public static func presets(for orientation: DisplayOrientation) -> [VirtualDisplayPreset] {
        return allCases.filter { $0.orientation == orientation }
    }

    public static func defaultPreset(for orientation: DisplayOrientation) -> VirtualDisplayPreset {
        switch orientation {
        case .landscape: return .landFhd
        case .portrait: return .portFlagship
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
    public var displayOrientation: DisplayOrientation = .landscape
    public var newDisplayResolution: String = VirtualDisplayPreset.landFhd.rawValue

    public init() {}
}
