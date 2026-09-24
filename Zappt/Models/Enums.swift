import Foundation
import CoreGraphics

/// The kind of content the user wants to capture.
enum CaptureSourceType: String, CaseIterable, Identifiable, Codable {
    case fullScreen
    case window
    case area
    case cameraOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fullScreen: return "Full Screen"
        case .window: return "Window"
        case .area: return "Area"
        case .cameraOnly: return "Camera Only"
        }
    }

    var symbol: String {
        switch self {
        case .fullScreen: return "display"
        case .window: return "macwindow"
        case .area: return "rectangle.dashed"
        case .cameraOnly: return "web.camera"
        }
    }
}

enum VideoQuality: String, CaseIterable, Identifiable, Codable {
    case p720, p1080, native
    var id: String { rawValue }
    var title: String {
        switch self {
        case .p720: return "720p"
        case .p1080: return "1080p"
        case .native: return "Native"
        }
    }
    /// Target height in points. `nil` means use the source's native size.
    var targetHeight: Int? {
        switch self {
        case .p720: return 720
        case .p1080: return 1080
        case .native: return nil
        }
    }
}

enum FrameRate: Int, CaseIterable, Identifiable, Codable {
    case fps30 = 30
    case fps60 = 60
    var id: Int { rawValue }
    var title: String { "\(rawValue) fps" }
}

enum BubbleSize: String, CaseIterable, Identifiable, Codable {
    case small, medium, large
    var id: String { rawValue }
    var title: String {
        switch self {
        case .small: return "S"
        case .medium: return "M"
        case .large: return "L"
        }
    }
    var diameter: CGFloat {
        switch self {
        case .small: return 140
        case .medium: return 200
        case .large: return 280
        }
    }
}

enum BubbleShape: String, CaseIterable, Identifiable, Codable {
    case circle, roundedRect
    var id: String { rawValue }
    var title: String {
        switch self {
        case .circle: return "Circle"
        case .roundedRect: return "Rounded"
        }
    }
    var symbol: String {
        switch self {
        case .circle: return "circle"
        case .roundedRect: return "rectangle"
        }
    }
}

/// High-level recorder lifecycle state.
enum RecorderState: Equatable {
    case idle
    case countdown(Int)
    case recording
    case paused
    case stopping
    case error(String)
}
