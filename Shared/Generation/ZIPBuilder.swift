import Foundation
import Compression

/// Minimal ZIP archive builder that satisfies EPUB packaging requirements.
///
/// EPUB mandates the `mimetype` file be the first entry in the archive, stored
/// uncompressed with no extra field. Most high-level ZIP APIs don't provide this
/// level of control, so we build the ZIP structures by hand.
struct ZIPBuilder {

    // MARK: - Types

    private struct Entry {
        let path: String
        let data: Data
        let method: UInt16          // 0 = stored, 8 = deflated
        let crc32: UInt32
        let compressedSize: UInt32
        let uncompressedSize: UInt32
        let localHeaderOffset: UInt32
    }

    // MARK: - State

    private var buffer = Data()
    private var entries: [Entry] = []

    // MARK: - Public

    /// Add a file stored uncompressed (method 0). Use for `mimetype` and binary
    /// files like JPEG that are already compressed.
    mutating func addStored(path: String, data: Data) {
        let crc = data.crc32()
        let offset = UInt32(buffer.count)

        writeLocalFileHeader(path: path, method: 0, crc: crc,
                             compressedSize: UInt32(data.count),
                             uncompressedSize: UInt32(data.count))
        buffer.append(data)

        entries.append(Entry(path: path, data: data, method: 0, crc32: crc,
                             compressedSize: UInt32(data.count),
                             uncompressedSize: UInt32(data.count),
                             localHeaderOffset: offset))
    }

    /// Add a file with deflate compression (method 8). Use for text content
    /// like XHTML, CSS, and XML.
    mutating func addDeflated(path: String, data: Data) {
        let crc = data.crc32()
        let compressed = deflate(data) ?? data
        let method: UInt16 = compressed.count < data.count ? 8 : 0
        let payload = method == 8 ? compressed : data
        let offset = UInt32(buffer.count)

        writeLocalFileHeader(path: path, method: method, crc: crc,
                             compressedSize: UInt32(payload.count),
                             uncompressedSize: UInt32(data.count))
        buffer.append(payload)

        entries.append(Entry(path: path, data: payload, method: method, crc32: crc,
                             compressedSize: UInt32(payload.count),
                             uncompressedSize: UInt32(data.count),
                             localHeaderOffset: offset))
    }

    /// Finalize the archive by writing the central directory and
    /// end-of-central-directory record. Returns the complete ZIP data.
    mutating func finalize() -> Data {
        let centralDirOffset = UInt32(buffer.count)
        var centralDirSize: UInt32 = 0

        for entry in entries {
            let headerData = centralDirectoryHeader(for: entry)
            buffer.append(headerData)
            centralDirSize += UInt32(headerData.count)
        }

        writeEndOfCentralDirectory(entryCount: UInt16(entries.count),
                                   centralDirSize: centralDirSize,
                                   centralDirOffset: centralDirOffset)
        return buffer
    }

    // MARK: - Local File Header

    private mutating func writeLocalFileHeader(path: String, method: UInt16,
                                                crc: UInt32, compressedSize: UInt32,
                                                uncompressedSize: UInt32) {
        let pathData = Data(path.utf8)
        buffer.appendUInt32(0x04034b50)           // local file header signature
        buffer.appendUInt16(20)                    // version needed (2.0)
        buffer.appendUInt16(0)                     // general purpose bit flag
        buffer.appendUInt16(method)                // compression method
        buffer.appendUInt16(0)                     // last mod file time
        buffer.appendUInt16(0)                     // last mod file date
        buffer.appendUInt32(crc)                   // crc-32
        buffer.appendUInt32(compressedSize)        // compressed size
        buffer.appendUInt32(uncompressedSize)      // uncompressed size
        buffer.appendUInt16(UInt16(pathData.count)) // file name length
        buffer.appendUInt16(0)                     // extra field length (MUST be 0 for mimetype)
        buffer.append(pathData)
    }

    // MARK: - Central Directory

    private func centralDirectoryHeader(for entry: Entry) -> Data {
        let pathData = Data(entry.path.utf8)
        var header = Data()
        header.appendUInt32(0x02014b50)            // central directory signature
        header.appendUInt16(20)                    // version made by
        header.appendUInt16(20)                    // version needed
        header.appendUInt16(0)                     // general purpose bit flag
        header.appendUInt16(entry.method)          // compression method
        header.appendUInt16(0)                     // last mod file time
        header.appendUInt16(0)                     // last mod file date
        header.appendUInt32(entry.crc32)           // crc-32
        header.appendUInt32(entry.compressedSize)  // compressed size
        header.appendUInt32(entry.uncompressedSize) // uncompressed size
        header.appendUInt16(UInt16(pathData.count)) // file name length
        header.appendUInt16(0)                     // extra field length
        header.appendUInt16(0)                     // file comment length
        header.appendUInt16(0)                     // disk number start
        header.appendUInt16(0)                     // internal file attributes
        header.appendUInt32(0)                     // external file attributes
        header.appendUInt32(entry.localHeaderOffset) // relative offset
        header.append(pathData)
        return header
    }

    // MARK: - End of Central Directory

    private mutating func writeEndOfCentralDirectory(entryCount: UInt16,
                                                      centralDirSize: UInt32,
                                                      centralDirOffset: UInt32) {
        buffer.appendUInt32(0x06054b50)            // EOCD signature
        buffer.appendUInt16(0)                     // disk number
        buffer.appendUInt16(0)                     // disk with central directory
        buffer.appendUInt16(entryCount)            // entries on this disk
        buffer.appendUInt16(entryCount)            // total entries
        buffer.appendUInt32(centralDirSize)        // central directory size
        buffer.appendUInt32(centralDirOffset)      // central directory offset
        buffer.appendUInt16(0)                     // comment length
    }

    // MARK: - Deflate

    private func deflate(_ data: Data) -> Data? {
        guard !data.isEmpty else { return Data() }

        let sourceSize = data.count
        // Allocate a destination buffer; deflated data is often smaller but could
        // theoretically expand slightly for incompressible input.
        let destinationSize = sourceSize + 512
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: destinationSize)
        defer { destinationBuffer.deallocate() }

        let result = data.withUnsafeBytes { sourcePtr -> Int in
            guard let baseAddress = sourcePtr.baseAddress else { return 0 }
            return compression_encode_buffer(
                destinationBuffer, destinationSize,
                baseAddress.assumingMemoryBound(to: UInt8.self), sourceSize,
                nil,
                COMPRESSION_ZLIB
            )
        }

        guard result > 0 else { return nil }
        return Data(bytes: destinationBuffer, count: result)
    }
}

// MARK: - Data Helpers

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        var le = value.littleEndian
        Swift.withUnsafeBytes(of: &le) { append(contentsOf: $0) }
    }

    mutating func appendUInt32(_ value: UInt32) {
        var le = value.littleEndian
        Swift.withUnsafeBytes(of: &le) { append(contentsOf: $0) }
    }

    /// Compute CRC-32 using the standard polynomial.
    func crc32() -> UInt32 {
        // Build the lookup table once (static).
        struct Table {
            static let value: [UInt32] = {
                (0..<256).map { i -> UInt32 in
                    var c = UInt32(i)
                    for _ in 0..<8 {
                        c = (c & 1 == 1) ? (0xEDB88320 ^ (c >> 1)) : (c >> 1)
                    }
                    return c
                }
            }()
        }

        var crc: UInt32 = 0xFFFFFFFF
        for byte in self {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = Table.value[index] ^ (crc >> 8)
        }
        return crc ^ 0xFFFFFFFF
    }
}
