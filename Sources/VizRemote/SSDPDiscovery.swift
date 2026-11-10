import Foundation

/// Sends a plain SSDP M-SEARCH multicast and parses replies from real VIZIO SmartCast
/// devices. Plain BSD sockets, no multicast *join* required — sending to the multicast
/// group and listening on our own ephemeral port for unicast replies is enough, and
/// doesn't require Apple's `com.apple.developer.networking.multicast` entitlement (that's
/// only enforced under the App Sandbox; this build has no entitlements file at all).
final class SSDPDiscovery: TVDiscovery {
    private let multicastAddress = "239.255.255.250"
    private let multicastPort: UInt16 = 1900

    func search(timeout: TimeInterval) -> AsyncStream<DiscoveredTV> {
        AsyncStream { continuation in
            let socketFD = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
            guard socketFD >= 0 else { continuation.finish(); return }

            var enable: Int32 = 1
            setsockopt(socketFD, SOL_SOCKET, SO_REUSEADDR, &enable, socklen_t(MemoryLayout<Int32>.size))

            var timeoutVal = timeval(tv_sec: Int(timeout), tv_usec: 0)
            setsockopt(socketFD, SOL_SOCKET, SO_RCVTIMEO, &timeoutVal, socklen_t(MemoryLayout<timeval>.size))

            var addr = sockaddr_in()
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = multicastPort.bigEndian
            inet_pton(AF_INET, multicastAddress, &addr.sin_addr)

            let message = "M-SEARCH * HTTP/1.1\r\nHOST: \(multicastAddress):\(multicastPort)\r\nMAN: \"ssdp:discover\"\r\nMX: 3\r\nST: ssdp:all\r\n\r\n"
            let messageData = [UInt8](message.utf8)

            withUnsafePointer(to: &addr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    _ = sendto(socketFD, messageData, messageData.count, 0, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }

            let deadline = Date().addingTimeInterval(timeout)
            Task.detached {
                var buffer = [UInt8](repeating: 0, count: 4096)
                while Date() < deadline {
                    let received = recv(socketFD, &buffer, buffer.count, 0)
                    guard received > 0 else { continue }
                    let text = String(decoding: buffer[0..<received], as: UTF8.self)
                    if let tv = Self.parseTV(from: text) {
                        continuation.yield(tv)
                    }
                }
                close(socketFD)
                continuation.finish()
            }
        }
    }

    private static func parseTV(from response: String) -> DiscoveredTV? {
        var location: String?
        var usn: String?
        var isVizio = false

        for line in response.split(separator: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { continue }
            switch parts[0].uppercased() {
            case "LOCATION": location = parts[1]
            case "USN": usn = parts[1]
            case "SERVER", "X-USER-AGENT": if parts[1].uppercased().contains("MDX") { isVizio = true }
            default: break
            }
        }
        guard isVizio, let location, let usn,
              let url = URL(string: location), let host = url.host else { return nil }
        return DiscoveredTV(id: usn, name: host, model: "VIZIO SmartCast", host: host)
    }
}
