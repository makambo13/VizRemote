import Foundation
import Network

protocol TVDiscovery {
    /// Emits each TV found within the search window; may emit the same TV more than once.
    func search(timeout: TimeInterval) -> AsyncStream<DiscoveredTV>
}

/// Confirmed 2026-09-26: a raw SSDP M-SEARCH (ST: ssdp:all) against the real network only
/// drew replies from the router's MiniUPnPd — the VIZIO TV never answered. VIZIO SmartCast
/// doesn't reliably advertise itself over SSDP, so discovery instead probes every host on
/// the Mac's own /24 for the open SmartCast control port (7345). This needs no special
/// entitlement (plain outbound TCP), but does trigger the same macOS "Local Network"
/// permission prompt as the old multicast approach.
final class SubnetScanDiscovery: TVDiscovery {
    private let port: NWEndpoint.Port = 7345
    private let probeTimeout: TimeInterval = 1.5

    func search(timeout: TimeInterval) -> AsyncStream<DiscoveredTV> {
        AsyncStream { continuation in
            guard let subnet = LocalNetwork.currentIPv4Subnet() else {
                continuation.finish()
                return
            }
            let hosts = LocalNetwork.hostAddresses(base: subnet.address, prefixLength: subnet.prefixLength)
                .filter { $0 != subnet.address }
            let port = port
            let probeTimeout = probeTimeout

            let task = Task.detached {
                await withTaskGroup(of: DiscoveredTV?.self) { group in
                    for host in hosts {
                        group.addTask {
                            await Self.probe(host: host, port: port, timeout: probeTimeout)
                        }
                    }
                    for await result in group {
                        if let tv = result {
                            continuation.yield(tv)
                        }
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func probe(host: String, port: NWEndpoint.Port, timeout: TimeInterval) async -> DiscoveredTV? {
        await withCheckedContinuation { (continuation: CheckedContinuation<DiscoveredTV?, Never>) in
            let connection = NWConnection(host: NWEndpoint.Host(host), port: port, using: .tcp)
            var didResume = false
            let resumeOnce: (DiscoveredTV?) -> Void = { result in
                guard !didResume else { return }
                didResume = true
                connection.cancel()
                continuation.resume(returning: result)
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    resumeOnce(DiscoveredTV(id: "tcp-\(host)", name: "VIZIO TV", model: "VIZIO SmartCast", host: host))
                case .failed, .cancelled:
                    resumeOnce(nil)
                default:
                    break
                }
            }
            connection.start(queue: .global(qos: .utility))
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
                resumeOnce(nil)
            }
        }
    }
}

enum LocalNetwork {
    static func currentIPv4Subnet() -> (address: String, prefixLength: Int)? {
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let firstAddr = ifaddrPtr else { return nil }
        defer { freeifaddrs(ifaddrPtr) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            guard (flags & IFF_UP) == IFF_UP, (flags & IFF_LOOPBACK) == 0,
                  let addr = ptr.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            let name = String(cString: ptr.pointee.ifa_name)
            guard name.hasPrefix("en") else { continue }

            var addrStorage = sockaddr_in()
            memcpy(&addrStorage, addr, MemoryLayout<sockaddr_in>.size)
            var ipBuffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            inet_ntop(AF_INET, &addrStorage.sin_addr, &ipBuffer, socklen_t(INET_ADDRSTRLEN))
            let ip = String(cString: ipBuffer)

            guard let mask = ptr.pointee.ifa_netmask else { continue }
            var maskStorage = sockaddr_in()
            memcpy(&maskStorage, mask, MemoryLayout<sockaddr_in>.size)
            let prefixLength = maskStorage.sin_addr.s_addr.nonzeroBitCount

            return (ip, prefixLength)
        }
        return nil
    }

    private static func ipv4ToUInt32(_ ip: String) -> UInt32? {
        var addr = in_addr()
        guard inet_pton(AF_INET, ip, &addr) == 1 else { return nil }
        return UInt32(bigEndian: addr.s_addr)
    }

    private static func uint32ToIPv4(_ value: UInt32) -> String {
        var addr = in_addr(s_addr: value.bigEndian)
        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        inet_ntop(AF_INET, &addr, &buffer, socklen_t(INET_ADDRSTRLEN))
        return String(cString: buffer)
    }

    static func hostAddresses(base: String, prefixLength: Int, limit: Int = 512) -> [String] {
        guard let baseValue = ipv4ToUInt32(base), prefixLength > 0, prefixLength <= 32 else { return [] }
        let hostBits = 32 - prefixLength
        guard hostBits > 0, hostBits <= 16 else { return [] }
        let networkValue = baseValue & (~UInt32(0) << hostBits)
        let hostCount = 1 << hostBits
        var addresses: [String] = []
        for i in 1..<(hostCount - 1) where addresses.count < limit {
            addresses.append(uint32ToIPv4(networkValue + UInt32(i)))
        }
        return addresses
    }
}
