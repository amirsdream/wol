import SwiftUI

@MainActor
final class PanelModel: ObservableObject {
    @Published var composer: Composer?
    @Published var sent: Set<UUID> = []
    @Published var note: String?
    @Published var sentTo: String?
    var lastWake = Date.distantPast
    let library: Library

    init(library: Library) {
        self.library = library
    }
}

struct Panel: View {
    @ObservedObject var model: PanelModel
    var onHeight: (CGFloat) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if model.library.devices.isEmpty, model.composer == nil {
                empty
            } else if !model.library.devices.isEmpty {
                list
            }
            if let composer = model.composer {
                editor(composer)
            }
            if let sentTo = model.sentTo {
                Text(sentTo)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let note = model.note {
                Text(note)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            footer
        }
        .padding(14)
        .frame(width: 292, alignment: .leading)
        .fixedSize(horizontal: true, vertical: true)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { height in
            onHeight(height)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Wake")
                    .font(.system(size: 15, weight: .semibold))
                Text("On this network")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button {
                withAnimation(.snappy(duration: 0.18)) {
                    model.composer = model.composer == nil ? Composer() : nil
                    model.note = nil
                }
            } label: {
                Image(systemName: model.composer == nil ? "plus" : "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 26, height: 22)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .help(model.composer == nil ? "Add a device" : "Close")
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No devices")
                .font(.system(size: 13, weight: .medium))
            Text("Add a Mac or PC by its MAC address. Wake sends a magic packet on your local network.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }

    private var list: some View {
        VStack(spacing: 0) {
            ForEach(Array(model.library.devices.enumerated()), id: \.element.id) { index, device in
                row(device)
                if index < model.library.devices.count - 1 {
                    Divider().padding(.leading, 12)
                }
            }
        }
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func row(_ device: Device) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(subtitle(device))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Button {
                edit(device)
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 22, height: 22)
                    .foregroundStyle(model.composer?.id == device.id ? Color.primary : Color.secondary)
            }
            .buttonStyle(.plain)
            .help("Edit \(device.name)")
            Button {
                Task { await wake(device) }
            } label: {
                Image(systemName: model.sent.contains(device.id) ? "checkmark" : "power")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 22)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .help("Wake \(device.name)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .contextMenu {
            Button("Edit") { edit(device) }
            Button("Remove", role: .destructive) {
                withAnimation(.snappy(duration: 0.18)) {
                    model.library.remove(device.id)
                    if model.composer?.id == device.id { model.composer = nil }
                }
            }
        }
    }

    private func editor(_ draft: Composer) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            field("Name", text: binding(\.name), prompt: "Studio display")
            field("MAC", text: binding(\.mac), prompt: "A4:83:E7:12:34:56")
                .font(.system(size: 13, design: .monospaced))
            DisclosureGroup("Broadcast") {
                VStack(alignment: .leading, spacing: 8) {
                    field("Address", text: binding(\.host), prompt: "255.255.255.255")
                    field("Port", text: binding(\.port), prompt: "9")
                }
                .padding(.top, 6)
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            HStack {
                Button("Cancel") {
                    withAnimation(.snappy(duration: 0.18)) { model.composer = nil }
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                Spacer()
                Button(draft.isNew ? "Add" : "Save") { save(draft) }
                    .buttonStyle(.glassProminent)
                    .controlSize(.small)
                    .disabled(!draft.canSave)
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func field(_ title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            TextField(prompt, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private func binding(_ keyPath: WritableKeyPath<Composer, String>) -> Binding<String> {
        Binding(
            get: { model.composer?[keyPath: keyPath] ?? "" },
            set: { newValue in
                guard var draft = model.composer else { return }
                draft[keyPath: keyPath] = newValue
                model.composer = draft
            }
        )
    }

    private func edit(_ device: Device) {
        withAnimation(.snappy(duration: 0.18)) {
            model.composer = model.composer?.id == device.id ? nil : Composer(device)
            model.note = nil
        }
    }

    private func subtitle(_ device: Device) -> String {
        if device.host == "255.255.255.255", device.port == 9 { return device.mac }
        return "\(device.mac)  \(device.host):\(device.port)"
    }

    private func save(_ draft: Composer) {
        guard let device = draft.device else {
            model.note = WakeError.mac.message
            return
        }
        withAnimation(.snappy(duration: 0.18)) {
            model.library.upsert(device)
            model.composer = nil
            model.note = nil
        }
    }

    private func wake(_ device: Device) async {
        let now = Date()
        if now.timeIntervalSince(model.lastWake) < 60 {
            model.note = "Wait a minute. Another packet can shut the PC off."
            return
        }
        model.lastWake = now
        model.note = nil
        model.sentTo = nil
        do {
            let sent = try WakePacket.send(mac: device.mac, host: device.host, port: device.port)
            model.sentTo = "Sent once to \(sent.host). Leave it for a minute."
            model.sent = model.sent.union([device.id])
            try? await Task.sleep(for: .milliseconds(1200))
            model.sent = model.sent.subtracting([device.id])
        } catch let error as WakeError {
            model.note = error.message
        } catch {
            model.note = WakeError.send.message
        }
    }
}

struct Composer: Equatable {
    var id: UUID?
    var name = ""
    var mac = ""
    var host = "255.255.255.255"
    var port = "9"

    init() {}

    init(_ device: Device) {
        id = device.id
        name = device.name
        mac = device.mac
        host = device.host
        port = String(device.port)
    }

    var isNew: Bool { id == nil }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && device != nil
    }

    var device: Device? {
        guard let mac = WakePacket.normalizeMAC(mac),
              WakePacket.isIPv4(host),
              let port = Int(port), (1...65535).contains(port) else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return Device(id: id ?? UUID(), name: trimmed, mac: mac, host: host, port: port)
    }
}
