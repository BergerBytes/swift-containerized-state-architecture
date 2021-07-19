import Foundation

public enum RenderPolicy {
    case possible
    case notPossible(RenderError)

    public enum RenderError {
        case viewNotReady
        case viewDeallocated
    }

    var canBeRendered: Bool {
        switch self {
        case .possible:
            return true
        case .notPossible:
            return false
        }
    }
}
