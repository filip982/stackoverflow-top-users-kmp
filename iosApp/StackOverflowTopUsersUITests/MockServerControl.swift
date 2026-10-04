import Foundation
import Network

/// Talks to the standalone :mockserver control endpoints from the UI-test runner.
///
/// Uses a raw TCP connection (Network.framework) instead of URLSession: App Transport Security does
/// not apply to it, so plain-HTTP localhost works no matter what the generated test-runner
/// Info.plist allows. The iOS Simulator shares the Mac's network stack, so localhost is the host.
enum MockServerControl {
    /// From the runner environment (`TEST_RUNNER_MOCK_BASE_URL=... xcodebuild test`), default localhost:8080.
    static var baseUrl: String {
        let value = ProcessInfo.processInfo.environment["MOCK_BASE_URL"]?.trimmingCharacters(in: .whitespaces) ?? ""
        return value.isEmpty ? "http://localhost:8080" : value
    }

    struct ControlError: Error, CustomStringConvertible {
        let description: String
    }

    static func setScenario(_ name: String) throws {
        let (status, body) = try send(method: "POST", path: "/__scenario?name=\(name)")
        guard status == 200 else {
            throw ControlError(description: "POST /__scenario?name=\(name) → HTTP \(status): \(body)")
        }
    }

    static func assertReady() throws {
        let (status, body) = try send(method: "GET", path: "/__ready")
        guard status == 200 else {
            throw ControlError(description: "mockserver not ready at \(baseUrl): HTTP \(status) \(body)")
        }
    }

    // MARK: Minimal HTTP/1.1 over NWConnection

    private final class Exchange: @unchecked Sendable {
        var response = Data()
        var failure: Error?
    }

    private static func send(method: String, path: String, timeout: TimeInterval = 10) throws -> (Int, String) {
        guard let url = URL(string: baseUrl), let rawHost = url.host else {
            throw ControlError(description: "invalid MOCK_BASE_URL '\(baseUrl)'")
        }
        // The mockserver binds IPv4; avoid a ::1 attempt for "localhost".
        let host = rawHost == "localhost" ? "127.0.0.1" : rawHost
        guard let port = NWEndpoint.Port(rawValue: UInt16(url.port ?? 80)) else {
            throw ControlError(description: "invalid port in '\(baseUrl)'")
        }

        let request = "\(method) \(path) HTTP/1.1\r\nHost: \(rawHost):\(port.rawValue)\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
        let connection = NWConnection(host: NWEndpoint.Host(host), port: port, using: .tcp)
        let queue = DispatchQueue(label: "mockserver-control")
        let done = DispatchSemaphore(value: 0)
        let exchange = Exchange()

        func receiveAll() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, isComplete, error in
                if let data { exchange.response.append(data) }
                if let error { exchange.failure = error }
                if isComplete || error != nil {
                    done.signal()
                } else {
                    receiveAll()
                }
            }
        }

        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                connection.send(content: Data(request.utf8), completion: .contentProcessed { error in
                    if let error {
                        exchange.failure = error
                        done.signal()
                    } else {
                        receiveAll()
                    }
                })
            case let .failed(error), let .waiting(error):
                exchange.failure = error
                done.signal()
            default:
                break
            }
        }
        connection.start(queue: queue)
        let waited = done.wait(timeout: .now() + timeout)
        connection.cancel()

        if waited == .timedOut {
            throw ControlError(description: "\(method) \(path) timed out against \(baseUrl)")
        }
        let text = String(decoding: exchange.response, as: UTF8.self)
        if let failure = exchange.failure, text.isEmpty {
            throw ControlError(description: "\(method) \(path) failed against \(baseUrl): \(failure)")
        }
        // Status line: "HTTP/1.1 200 OK"
        let statusLine = text.split(separator: "\r\n", maxSplits: 1).first.map(String.init) ?? ""
        let parts = statusLine.split(separator: " ")
        guard parts.count >= 2, let status = Int(parts[1]) else {
            throw ControlError(description: "unparseable response from \(baseUrl): '\(statusLine)'")
        }
        let body = text.components(separatedBy: "\r\n\r\n").dropFirst().joined(separator: "\r\n\r\n")
        return (status, body)
    }
}
