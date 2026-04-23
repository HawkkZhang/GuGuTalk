import Foundation

enum PermissionState: String {
    case authorized
    case denied
    case notDetermined
    case unsupported

    var title: String {
        switch self {
        case .authorized:
            "已授权"
        case .denied:
            "未授权"
        case .notDetermined:
            "待请求"
        case .unsupported:
            "不可用"
        }
    }

    var isUsable: Bool {
        self == .authorized
    }
}
