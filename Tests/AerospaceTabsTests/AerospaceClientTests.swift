import Darwin
import XCTest

@testable import AerospaceTabs

final class AerospaceClientTests: XCTestCase {
    func testReadExactReportsEOFWithPartialByteCount() throws {
        let sockets = try makeSocketPair()
        defer { Darwin.close(sockets.reader) }

        let prefix: [UInt8] = [0xAA, 0xBB]
        let written = prefix.withUnsafeBytes {
            Darwin.write(sockets.writer, $0.baseAddress, $0.count)
        }
        XCTAssertEqual(written, prefix.count)
        XCTAssertEqual(Darwin.close(sockets.writer), 0)

        var destination = [UInt8](repeating: 0, count: 4)
        XCTAssertThrowsError(try destination.withUnsafeMutableBytes { try readExact(sockets.reader, $0) }) { error in
            XCTAssertEqual(
                error as? AerospaceSocketIOError,
                .unexpectedEOF(expected: destination.count, received: prefix.count)
            )
        }
    }

    private func makeSocketPair() throws -> (reader: Int32, writer: Int32) {
        var descriptors = [Int32](repeating: -1, count: 2)
        guard socketpair(AF_UNIX, SOCK_STREAM, 0, &descriptors) == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        return (reader: descriptors[0], writer: descriptors[1])
    }
}
