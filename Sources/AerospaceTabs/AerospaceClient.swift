import Darwin
import Foundation

final class AerospaceClient {
    static var binaryURL: URL {
        let candidates = [
            "/opt/homebrew/bin/aerospace",
            "/usr/local/bin/aerospace",
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return URL(fileURLWithPath: "/opt/homebrew/bin/aerospace")
    }

    private let queue = DispatchQueue(label: "aerospace.socket")
    private var fd: Int32 = -1
    private let decoder = JSONDecoder()

    private static let format =
        "%{window-id}%{window-title}%{app-name}%{app-bundle-id}%{app-bundle-path}%{workspace}%{monitor-appkit-nsscreen-screens-id}%{window-parent-container-layout}"

    func listVisibleWindows(completion: @escaping (Result<Snapshot, Error>) -> Void) {
        queue.async { [weak self] in
            guard let self else { return }
            do {
                let raw = try self.command([
                    "list-windows",
                    "--workspace", "visible",
                    "--json",
                    "--format", Self.format,
                ])
                let rows = try self.decoder.decode([WindowRow].self, from: Data(raw.utf8))
                let windows = rows.compactMap(\.asWin).filter { $0.bundleID != "com.pedrotmr.AerospaceTabs" }
                var focused: Int?
                if let focusedRaw = try? self.command([
                    "list-windows",
                    "--focused",
                    "--json",
                    "--format", "%{window-id}",
                ]), let focusedRows = try? self.decoder.decode([WindowRow].self, from: Data(focusedRaw.utf8)) {
                    focused = focusedRows.first?.windowId
                }
                DispatchQueue.main.async {
                    completion(.success(Snapshot(windows: windows, focused: focused)))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    func focus(windowID: Int, completion: @escaping () -> Void) {
        queue.async { [weak self] in
            _ = try? self?.command(["focus", "--window-id", String(windowID)])
            DispatchQueue.main.async(execute: completion)
        }
    }

    private func command(_ args: [String]) throws -> String {
        try ensureConnected()
        do {
            return try send(args)
        } catch {
            close()
            try ensureConnected()
            return try send(args)
        }
    }

    private func send(_ args: [String]) throws -> String {
        let payload: [String: Any] = [
            "args": args,
            "stdin": "",
            "windowId": NSNull(),
            "workspace": NSNull(),
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        try writeFrame(data)
        let reply = try readFrame()
        let object = try JSONSerialization.jsonObject(with: reply) as? [String: Any]
        let code = object?["exitCode"] as? Int ?? 1
        let stdout = object?["stdout"] as? String ?? ""
        if code != 0 {
            let stderr = object?["stderr"] as? String ?? "aerospace error"
            throw NSError(domain: "aerospace", code: code, userInfo: [NSLocalizedDescriptionKey: stderr])
        }
        return stdout
    }

    private func ensureConnected() throws {
        if fd >= 0 { return }
        let sock = socket(AF_UNIX, SOCK_STREAM, 0)
        if sock < 0 { throw posix("socket") }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let path = "/tmp/bobko.aerospace-\(NSUserName()).sock"
        withUnsafeMutablePointer(to: &addr.sun_path.0) { ptr in
            let buf = UnsafeMutableBufferPointer(start: ptr, count: 104)
            for i in buf.indices { buf[i] = 0 }
            strncpy(ptr, path, 103)
        }

        let size = socklen_t(MemoryLayout<sockaddr_un>.size)
        let ok = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(sock, $0, size)
            }
        }
        if ok != 0 {
            Darwin.close(sock)
            throw posix("connect")
        }

        var version: UInt32 = 1
        try withUnsafeBytes(of: &version) { raw in
            try writeAll(sock, raw)
        }
        var serverVersion: UInt32 = 0
        try withUnsafeMutableBytes(of: &serverVersion) { raw in
            try readExact(sock, raw)
        }
        fd = sock
    }

    private func writeFrame(_ payload: Data) throws {
        var length = UInt32(payload.count).littleEndian
        try withUnsafeBytes(of: &length) { try writeAll(fd, $0) }
        try payload.withUnsafeBytes { try writeAll(fd, $0) }
    }

    private func readFrame() throws -> Data {
        var length: UInt32 = 0
        try withUnsafeMutableBytes(of: &length) { try readExact(fd, $0) }
        length = UInt32(littleEndian: length)
        var payload = Data(count: Int(length))
        try payload.withUnsafeMutableBytes { try readExact(fd, $0) }
        return payload
    }

    private func close() {
        if fd >= 0 {
            Darwin.close(fd)
            fd = -1
        }
    }

    private func posix(_ op: String) -> NSError {
        NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [
            NSLocalizedDescriptionKey: "\(op) failed",
        ])
    }
}

private func writeAll(_ fd: Int32, _ buffer: UnsafeRawBufferPointer) throws {
    var written = 0
    while written < buffer.count {
        let n = Darwin.write(fd, buffer.baseAddress!.advanced(by: written), buffer.count - written)
        if n <= 0 { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        written += n
    }
}

private func readExact(_ fd: Int32, _ buffer: UnsafeMutableRawBufferPointer) throws {
    var readCount = 0
    while readCount < buffer.count {
        let n = Darwin.read(fd, buffer.baseAddress!.advanced(by: readCount), buffer.count - readCount)
        if n <= 0 { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        readCount += n
    }
}
