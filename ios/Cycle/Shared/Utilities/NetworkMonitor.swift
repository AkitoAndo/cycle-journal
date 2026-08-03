//
//  NetworkMonitor.swift
//  CycleJournal
//

import Combine
import Network
import Foundation

@MainActor
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published private(set) var isConnected: Bool = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.cycle.journal.networkmonitor")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let connected = path.status == .satisfied
            Task { @MainActor in
                self.isConnected = connected
            }
        }
        monitor.start(queue: queue)
    }
}
