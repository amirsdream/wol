import Combine
import Foundation

struct Device: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var mac: String
    var host: String
    var port: Int
}

@MainActor
final class Library: ObservableObject {
    @Published var devices: [Device] = []
    private let file: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("local.wol.wake", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        file = base.appendingPathComponent("devices.json")
        load()
    }

    func upsert(_ device: Device) {
        var next = devices
        if let index = next.firstIndex(where: { $0.id == device.id }) {
            next[index] = device
        } else {
            next.append(device)
        }
        next.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        devices = next
        save()
    }

    func remove(_ id: UUID) {
        devices = devices.filter { $0.id != id }
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: file),
              let decoded = try? JSONDecoder().decode([Device].self, from: data) else { return }
        devices = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(devices) else { return }
        try? data.write(to: file, options: .atomic)
    }
}
