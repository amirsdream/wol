import Darwin
import Foundation

enum WakePacket {
    static func normalizeMAC(_ raw: String) -> String? {
        let hex = raw.uppercased().filter(\.isHexDigit)
        guard hex.count == 12 else { return nil }
        var parts: [String] = []
        var index = hex.startIndex
        for _ in 0..<6 {
            let next = hex.index(index, offsetBy: 2)
            parts.append(String(hex[index..<next]))
            index = next
        }
        return parts.joined(separator: ":")
    }

    static func isIPv4(_ host: String) -> Bool {
        var addr = in_addr()
        return inet_pton(AF_INET, host, &addr) == 1
    }

    struct Sent {
        var interface: String
        var host: String
        var port: Int
    }

    /// One magic packet, bound to the Wi-Fi or Ethernet port so it actually leaves the Mac.
    static func send(mac: String, host: String, port: Int) throws -> Sent {
        guard let mac = normalizeMAC(mac) else { throw WakeError.mac }
        guard isIPv4(host), port > 0, port < 65536 else { throw WakeError.address }
        let bytes = mac.split(separator: ":").compactMap { UInt8($0, radix: 16) }
        guard bytes.count == 6 else { throw WakeError.mac }
        guard let link = lanInterface() else { throw WakeError.send }

        var packet = [UInt8](repeating: 0xFF, count: 6)
        for _ in 0..<16 { packet.append(contentsOf: bytes) }

        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { throw WakeError.socket }
        defer { close(fd) }

        var yes: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &yes, socklen_t(MemoryLayout.size(ofValue: yes)))
        var index = if_nametoindex(link.name)
        if index != 0 {
            setsockopt(fd, IPPROTO_IP, IP_BOUND_IF, &index, socklen_t(MemoryLayout.size(ofValue: index)))
        }

        var local = sockaddr_in()
        local.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        local.sin_family = sa_family_t(AF_INET)
        local.sin_addr = link.local
        let bound = withUnsafePointer(to: &local) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0 else { throw WakeError.send }

        // 255.255.255.255 can leave on more than one port. A second copy
        // while the power supply is switching on latches it off.
        let destination = host == "255.255.255.255" ? link.broadcast : host
        var remote = sockaddr_in()
        remote.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        remote.sin_family = sa_family_t(AF_INET)
        remote.sin_port = in_port_t(UInt16(port).bigEndian)
        guard inet_pton(AF_INET, destination, &remote.sin_addr) == 1 else { throw WakeError.address }

        let sent = packet.withUnsafeBytes { buffer in
            withUnsafePointer(to: &remote) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    sendto(fd, buffer.baseAddress, packet.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sent == packet.count else { throw WakeError.send }
        return Sent(interface: link.name, host: destination, port: port)
    }

    private struct Link {
        var name: String
        var local: in_addr
        var broadcast: String
    }

    /// The active LAN port, preferring en0.
    private static func lanInterface() -> Link? {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let head else { return nil }
        defer { freeifaddrs(head) }
        var match: Link?
        var cursor: UnsafeMutablePointer<ifaddrs>? = head
        while let item = cursor {
            defer { cursor = item.pointee.ifa_next }
            let flags = Int32(item.pointee.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0, flags & IFF_BROADCAST != 0 else { continue }
            guard let addr = item.pointee.ifa_addr, addr.pointee.sa_family == sa_family_t(AF_INET) else { continue }
            guard let bcast = item.pointee.ifa_dstaddr else { continue }
            let name = String(cString: item.pointee.ifa_name)
            guard name.hasPrefix("en") else { continue }
            let local = addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr }
            var raw = bcast.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr }
            var text = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            guard inet_ntop(AF_INET, &raw, &text, socklen_t(INET_ADDRSTRLEN)) != nil else { continue }
            let link = Link(name: name, local: local, broadcast: String(cString: text))
            if name == "en0" { return link }
            if match == nil { match = link }
        }
        return match
    }
}

enum WakeError: Error {
    case mac, address, socket, send

    var message: String {
        switch self {
        case .mac: "That MAC address needs 12 hex digits."
        case .address: "Broadcast address or port is not valid."
        case .socket, .send: "The packet did not leave this Mac."
        }
    }
}
