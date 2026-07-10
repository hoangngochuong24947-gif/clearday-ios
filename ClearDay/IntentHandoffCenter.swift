import Foundation
import Observation

@MainActor
@Observable
final class IntentHandoffCenter {
    enum Destination: Equatable {
        case composer(prefilledTitle: String)
        case today
    }

    struct Request: Identifiable, Equatable {
        let id = UUID()
        let destination: Destination
    }

    static let shared = IntentHandoffCenter()

    private(set) var pendingRequest: Request?

    private init() {}

    func send(_ destination: Destination) {
        pendingRequest = Request(destination: destination)
    }

    func take() -> Request? {
        defer { pendingRequest = nil }
        return pendingRequest
    }
}
