import Darwin
import XCTest

@testable import AerospaceTabs

final class AerospaceClientTests: XCTestCase {
    func testSocketConfigurationSuppressesSIGPIPE() throws {
        let sockets = try makeSocketPair()
        defer {
            Darwin.close(sockets.reader)
            Darwin.close(sockets.writer)
        }

        try AerospaceClient.configureSocket(sockets.writer)

        var noSIGPIPE: Int32 = 0
        var noSIGPIPELength = socklen_t(MemoryLayout.size(ofValue: noSIGPIPE))
        XCTAssertEqual(
            getsockopt(sockets.writer, SOL_SOCKET, SO_NOSIGPIPE, &noSIGPIPE, &noSIGPIPELength),
            0
        )
        XCTAssertEqual(noSIGPIPE, 1)
    }

    func testSocketConfigurationSetsIOTimeouts() throws {
        let sockets = try makeSocketPair()
        defer {
            Darwin.close(sockets.reader)
            Darwin.close(sockets.writer)
        }

        try AerospaceClient.configureSocket(sockets.writer)

        var receiveTimeout = timeval()
        var receiveTimeoutLength = socklen_t(MemoryLayout.size(ofValue: receiveTimeout))
        XCTAssertEqual(
            getsockopt(sockets.writer, SOL_SOCKET, SO_RCVTIMEO, &receiveTimeout, &receiveTimeoutLength),
            0
        )
        XCTAssertTrue(receiveTimeout.tv_sec > 0 || receiveTimeout.tv_usec > 0)

        var sendTimeout = timeval()
        var sendTimeoutLength = socklen_t(MemoryLayout.size(ofValue: sendTimeout))
        XCTAssertEqual(
            getsockopt(sockets.writer, SOL_SOCKET, SO_SNDTIMEO, &sendTimeout, &sendTimeoutLength),
            0
        )
        XCTAssertTrue(sendTimeout.tv_sec > 0 || sendTimeout.tv_usec > 0)
    }

    func testValidatedFrameLengthRejectsOversizedPayloadBeforeAllocation() throws {
        let accepted = UInt32(AerospaceClient.maximumFrameSize).littleEndian
        XCTAssertEqual(
            try AerospaceClient.validatedFrameLength(accepted),
            AerospaceClient.maximumFrameSize
        )

        let oversized = UInt32(AerospaceClient.maximumFrameSize + 1).littleEndian
        XCTAssertThrowsError(try AerospaceClient.validatedFrameLength(oversized)) { error in
            XCTAssertEqual(
                error as? AerospaceProtocolError,
                .frameTooLarge(
                    length: AerospaceClient.maximumFrameSize + 1,
                    maximum: AerospaceClient.maximumFrameSize
                )
            )
        }
    }

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

    func testWriteAllReturnsBrokenPipeInsteadOfRaisingSIGPIPE() throws {
        let sockets = try makeSocketPair()
        defer { Darwin.close(sockets.writer) }

        try AerospaceClient.configureSocket(sockets.writer)
        XCTAssertEqual(Darwin.close(sockets.reader), 0)

        var byte: UInt8 = 0x01
        XCTAssertThrowsError(try withUnsafeBytes(of: &byte) { try writeAll(sockets.writer, $0) }) { error in
            let error = error as NSError
            XCTAssertEqual(error.domain, NSPOSIXErrorDomain)
            XCTAssertEqual(error.code, Int(EPIPE))
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
