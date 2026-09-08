import Darwin
import Foundation

final class AerospaceClient {
    private static let socketTimeout: TimeInterval = 2

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
        var shouldRetry = true
        while true {
            do {
                try ensureConnected()
                return try send(args)
            } catch {
                // Drop timed-out or otherwise broken sockets before retrying.
                close()
                guard shouldRetry else { throw error }
                shouldRetry = false
            }
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
        var ownsSocket = true
        defer {
            if ownsSocket {
                Darwin.close(sock)
            }
        }

        try Self.configureSocket(sock)

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let path = "/tmp/bobko.aerospace-\(NSUserName()).sock"
        withUnsafeMutablePointer(to: &addr.sun_path.0) { ptr in
            let buf = UnsafeMutableBufferPointer(start: ptr, count: 104)
            for i in buf.indices { buf[i] = 0 }
            strncpy(ptr, path, 103)
        }

        let size = socklen_t(MemoryLayout<sockaddr_un>.size)
        try withUnsafePointer(to: &addr) {
            try $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                try connectWithDeadline(sock, address: $0, length: size)
            }
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
        ownsSocket = false
    }

    static func configureSocket(_ sock: Int32) throws {
        var enabled: Int32 = 1
        try setSocketOption(
            sock,
            name: SO_NOSIGPIPE,
            value: &enabled,
            operation: "setsockopt(SO_NOSIGPIPE)"
        )

        let wholeSeconds = Int(Self.socketTimeout)
        let microseconds = Int32((Self.socketTimeout - Double(wholeSeconds)) * 1_000_000)
        var timeout = timeval(tv_sec: wholeSeconds, tv_usec: microseconds)
        try setSocketOption(
            sock,
            name: SO_RCVTIMEO,
            value: &timeout,
            operation: "setsockopt(SO_RCVTIMEO)"
        )
        try setSocketOption(
            sock,
            name: SO_SNDTIMEO,
            value: &timeout,
            operation: "setsockopt(SO_SNDTIMEO)"
        )
    }

    private static func setSocketOption<T>(
        _ sock: Int32,
        name: Int32,
        value: inout T,
        operation: String
    ) throws {
        let result = withUnsafePointer(to: &value) { pointer in
            setsockopt(sock, SOL_SOCKET, name, pointer, socklen_t(MemoryLayout<T>.size))
        }
        if result != 0 {
            throw makePOSIXError(operation, code: errno)
        }
    }

    private func connectWithDeadline(
        _ sock: Int32,
        address: UnsafePointer<sockaddr>,
        length: socklen_t
    ) throws {
        let originalFlags = fcntl(sock, F_GETFL)
        if originalFlags < 0 {
            throw posix("fcntl(F_GETFL)")
        }
        if fcntl(sock, F_SETFL, originalFlags | O_NONBLOCK) != 0 {
            throw posix("fcntl(F_SETFL)")
        }

        do {
            let result = Darwin.connect(sock, address, length)
            if result != 0 {
                let code = errno
                guard code == EINPROGRESS else {
                    throw posix("connect", code: code)
                }
                try waitForConnection(sock, timeout: Self.socketTimeout)
            }
        } catch {
            _ = fcntl(sock, F_SETFL, originalFlags)
            throw error
        }

        if fcntl(sock, F_SETFL, originalFlags) != 0 {
            throw posix("fcntl(F_SETFL)")
        }
    }

    private func waitForConnection(_ sock: Int32, timeout: TimeInterval) throws {
        let timeoutNanoseconds = UInt64(timeout * 1_000_000_000)
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        var descriptor = pollfd(fd: sock, events: Int16(POLLOUT), revents: 0)

        while true {
            let now = DispatchTime.now().uptimeNanoseconds
            guard now < deadline else {
                throw posix("connect", code: ETIMEDOUT)
            }
            let remainingNanoseconds = deadline - now
            let remainingMilliseconds = max(1, (remainingNanoseconds + 999_999) / 1_000_000)
            let result = Darwin.poll(&descriptor, 1, Int32(min(remainingMilliseconds, UInt64(Int32.max))))
            if result > 0 { break }
            if result == 0 {
                throw posix("connect", code: ETIMEDOUT)
            }
            if errno == EINTR { continue }
            throw posix("poll")
        }

        var socketError: Int32 = 0
        var errorLength = socklen_t(MemoryLayout<Int32>.size)
        if getsockopt(sock, SOL_SOCKET, SO_ERROR, &socketError, &errorLength) != 0 {
            throw posix("getsockopt(SO_ERROR)")
        }
        if socketError != 0 {
            throw posix("connect", code: socketError)
        }
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

    private func posix(_ op: String, code: Int32 = errno) -> NSError {
        makePOSIXError(op, code: code)
    }
}

enum AerospaceSocketIOError: Error, Equatable {
    case unexpectedEOF(expected: Int, received: Int)
}

func writeAll(_ fd: Int32, _ buffer: UnsafeRawBufferPointer) throws {
    var written = 0
    while written < buffer.count {
        let n = Darwin.write(fd, buffer.baseAddress!.advanced(by: written), buffer.count - written)
        if n > 0 {
            written += n
            continue
        }
        if n == 0 {
            throw makePOSIXError("write", code: EPIPE)
        }
        if errno == EINTR { continue }
        throw makePOSIXError("write", code: errno)
    }
}

func readExact(_ fd: Int32, _ buffer: UnsafeMutableRawBufferPointer) throws {
    var readCount = 0
    while readCount < buffer.count {
        let n = Darwin.read(fd, buffer.baseAddress!.advanced(by: readCount), buffer.count - readCount)
        if n > 0 {
            readCount += n
            continue
        }
        if n == 0 {
            throw AerospaceSocketIOError.unexpectedEOF(expected: buffer.count, received: readCount)
        }
        if errno == EINTR { continue }
        throw makePOSIXError("read", code: errno)
    }
}

private func makePOSIXError(_ operation: String, code: Int32) -> NSError {
    NSError(domain: NSPOSIXErrorDomain, code: Int(code), userInfo: [
        NSLocalizedDescriptionKey: "\(operation) failed: \(String(cString: strerror(code)))",
    ])
}
