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

public struct ScrcpyConfig: Codable, Equatable {
    public var preset: String = PresetQuality.high.rawValue
    public var maxSize: Int = 1080
    public var bitRateMbps: Int = 8
    public var maxFps: Int = 60
    public var turnScreenOff: Bool = true
    public var stayAwake: Bool = true
    public var audioEnabled: Bool = true
    public var alwaysOnTop: Bool = false
    public var fullscreen: Bool = false
    public var showTouches: Bool = false
    public var recordScreen: Bool = false
    public var customTitle: String = ""

    public init() {}
}
