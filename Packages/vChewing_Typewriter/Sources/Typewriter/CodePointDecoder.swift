// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

// MARK: - CodePointDecoder

/// Fallback code-point decoding utilities leveraging iconv on every platform.
enum CodePointDecoder {
  // MARK: Internal

  static func decode(
    hexString: String,
    encodingID: UInt32?,
    encodingHint: String?
  )
    -> String? {
    guard let bytes = hexString.hexByteArray else { return nil }

    for candidate in iconvEncodingCandidates(for: encodingID, hint: encodingHint) {
      if let converted = decode(bytes: bytes, using: candidate) {
        return converted
      }
    }

    return decodeAsUTF16BE(bytes: bytes)
  }

  // MARK: Private

  // MARK: Private helpers

  private static func decode(bytes: [UInt8], using encoding: String) -> String? {
    guard !bytes.isEmpty else { return nil }

    let descriptor: iconv_t = encoding.withCString { fromPtr in
      "UTF-8".withCString { toPtr in
        iconv_open(toPtr, fromPtr)
      }
    }
    guard descriptor != iconv_t(bitPattern: -1) else { return nil }
    defer { iconv_close(descriptor) }

    var input = bytes.map { Int8(bitPattern: $0) }
    var inBytesLeft = input.count
    var output = [Int8](repeating: 0, count: max(4, input.count * 4))
    var outBytesLeft = output.count
    var producedCount = 0

    let conversionSucceeded = input.withUnsafeMutableBufferPointer { inBuffer -> Bool in
      guard let inBase = inBuffer.baseAddress else { return false }
      return output.withUnsafeMutableBufferPointer { outBuffer -> Bool in
        guard let outBase = outBuffer.baseAddress else { return false }
        var inOptional: UnsafeMutablePointer<Int8>? = inBase
        var outOptional: UnsafeMutablePointer<Int8>? = outBase
        let result = iconv(
          descriptor,
          &inOptional,
          &inBytesLeft,
          &outOptional,
          &outBytesLeft
        )
        guard result != -1 else { return false }
        producedCount = outBuffer.count - outBytesLeft
        return true
      }
    }

    guard conversionSucceeded, producedCount > 0 else { return nil }
    let utf8Bytes = output.prefix(producedCount).map { UInt8(bitPattern: $0) }
    return String(bytes: utf8Bytes, encoding: .utf8)
  }

  private static func decodeAsUTF16BE(bytes: [UInt8]) -> String? {
    guard !bytes.isEmpty, bytes.count % 2 == 0 else { return nil }
    var scalars: [UnicodeScalar] = []
    scalars.reserveCapacity(bytes.count / 2)
    var index = 0
    while index < bytes.count {
      let high = UInt16(bytes[index]) << 8
      let low = UInt16(bytes[index + 1])
      index += 2
      let value = high | low
      if value >= 0xD800, value <= 0xDBFF {
        guard index + 1 < bytes.count else { return nil }
        let nextHigh = UInt16(bytes[index]) << 8
        let nextLow = UInt16(bytes[index + 1])
        index += 2
        let trail = nextHigh | nextLow
        guard trail >= 0xDC00, trail <= 0xDFFF else { return nil }
        let scalarValue = 0x10000 + ((UInt32(value) - 0xD800) << 10) + (UInt32(trail) - 0xDC00)
        guard let scalar = UnicodeScalar(scalarValue) else { return nil }
        scalars.append(scalar)
        continue
      }
      guard let scalar = UnicodeScalar(value) else { return nil }
      scalars.append(scalar)
    }
    return String(String.UnicodeScalarView(scalars))
  }

  private static func iconvEncodingCandidates(for id: UInt32?, hint: String?) -> [String] {
    var candidates: [String] = []
    if let id {
      switch id {
      case 0x0630, // GB encodings
           0x0631, 0x0632: // GB encodings
        candidates.append(contentsOf: ["GB18030", "GBK", "GB2312"])
      case 0x0301, 0x0303, 0x0A03: // Big5 variants
        candidates.append(contentsOf: ["BIG5-HKSCS", "BIG5", "CP950"])
      default: break
      }
    }
    if let hint = hint?.lowercased() {
      if hint.contains("gb") {
        candidates.append(contentsOf: ["GB18030", "GBK", "GB2312"])
      }
      if hint.contains("b5") || hint.contains("big5") {
        candidates.append(contentsOf: ["BIG5-HKSCS", "BIG5", "CP950"])
      }
    }
    candidates.append("UTF-16BE")
    return candidates.deduplicated()
  }
}

extension Array where Element == String {
  fileprivate func deduplicated() -> [String] {
    var seen = Set<String>()
    var result: [String] = []
    for item in self where seen.insert(item.uppercased()).inserted {
      result.append(item)
    }
    return result
  }
}

extension String {
  fileprivate var hexByteArray: [UInt8]? {
    let sanitized = filter { !$0.isWhitespace }
    guard !sanitized.isEmpty, sanitized.count % 2 == 0 else { return nil }
    var result: [UInt8] = []
    result.reserveCapacity(sanitized.count / 2)
    var index = sanitized.startIndex
    while index < sanitized.endIndex {
      let nextIndex = sanitized.index(index, offsetBy: 2)
      let slice = sanitized[index ..< nextIndex]
      guard let value = UInt8(slice, radix: 16) else { return nil }
      result.append(value)
      index = nextIndex
    }
    return result
  }
}
