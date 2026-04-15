// (c) 2026 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

extension Hotenka {
  public struct StringMap {
    // MARK: Lifecycle

    public init(fileURL: URL) throws {
      try self.init(data: try Data(contentsOf: fileURL, options: [.mappedIfSafe]))
    }

    public init(data: Data) throws {
      let normalizedData = Self.normalizeLineEndings(in: data)
      guard let headerSeparator = normalizedData.range(of: Self.headerSeparator) else {
        throw StringMapError.invalidHeader
      }
      let headerEnd = headerSeparator.lowerBound
      let bodyStart = headerSeparator.upperBound
      guard let header = String(data: normalizedData.prefix(headerEnd), encoding: .utf8) else {
        throw StringMapError.invalidHeader
      }

      let headerLines = header.split(separator: "\n").map(String.init)
      guard headerLines.count >= 2 else {
        throw StringMapError.invalidHeader
      }

      let magicFields = try Self.parseHeaderFields(headerLines[0], expectedCount: 2)
      guard magicFields[0] == Self.magic else {
        throw StringMapError.invalidMagic
      }
      let version = try Self.decodeHexField(magicFields[1])
      guard version == Self.version else {
        throw StringMapError.unsupportedVersion
      }

      let dictFields = try Self.parseHeaderFields(headerLines[1], expectedCount: 2)
      guard dictFields[0] == "DICTS" else {
        throw StringMapError.invalidHeader
      }
      let dictCount = try Self.decodeHexField(dictFields[1])
      guard dictCount == DictType.allCases.count else {
        throw StringMapError.unexpectedDictionaryCount
      }
      guard headerLines.count == dictCount + 2 else {
        throw StringMapError.invalidHeader
      }

      var parsedDescriptors: [String: DictDescriptor] = [:]
      parsedDescriptors.reserveCapacity(dictCount)

      for descriptorLine in headerLines.dropFirst(2) {
        let fields = try Self.parseHeaderFields(descriptorLine, expectedCount: 6)
        let dictKey = fields[0]
        guard DictType.match(rawKeyString: dictKey) != nil else {
          throw StringMapError.invalidDictionaryKey
        }
        parsedDescriptors[dictKey] = DictDescriptor(
          entryCount: try Self.decodeHexField(fields[1]),
          maximumKeyLength: try Self.decodeHexField(fields[2]),
          indexStart: try Self.decodeHexField(fields[3]),
          dataStart: try Self.decodeHexField(fields[4]),
          dataEnd: try Self.decodeHexField(fields[5])
        )
      }

      guard parsedDescriptors.count == dictCount else {
        throw StringMapError.invalidHeader
      }

      let orderedDescriptors = try DictType.allCases.map { dictType in
        guard let descriptor = parsedDescriptors[dictType.rawKeyString] else {
          throw StringMapError.invalidHeader
        }

        let indexLength = descriptor.entryCount * Self.offsetLineWidth
        guard descriptor.indexStart >= bodyStart else {
          throw StringMapError.invalidDescriptor
        }
        guard descriptor.dataStart == descriptor.indexStart + indexLength else {
          throw StringMapError.invalidDescriptor
        }
        guard descriptor.dataStart <= descriptor.dataEnd else {
          throw StringMapError.invalidDescriptor
        }
        guard descriptor.dataEnd <= normalizedData.count else {
          throw StringMapError.invalidDescriptor
        }
        return descriptor
      }

      self.storage = normalizedData
      self.descriptors = orderedDescriptors
    }

    // MARK: Public

    public enum StringMapError: Error {
      case fileTooLarge
      case invalidMagic
      case invalidHeader
      case unsupportedVersion
      case unexpectedDictionaryCount
      case invalidDictionaryKey
      case invalidDescriptor
      case invalidOffsetLine
      case unsupportedControlCharacter
    }

    public static func serialize(from dictionaryStore: [String: [String: String]]) throws -> Data {
      let orderedEntries = DictType.allCases.map { dictType in
        let normalizedDictionary = (dictionaryStore[dictType.rawKeyString] ?? [:]).reduce(
          into: [String: String]()
        ) { partialResult, entry in
          partialResult[entry.key.precomposedStringWithCanonicalMapping] = entry.value
        }

        return normalizedDictionary.sorted { lhs, rhs in
          lhs.key.utf8.lexicographicallyPrecedes(rhs.key.utf8)
        }
      }

      let blocks = try orderedEntries.map { entries in
        try makeBlock(entries: entries)
      }

      let placeholderHeader = makeHeader(
        descriptors: zip(DictType.allCases, blocks).map { dictType, block in
          HeaderDescriptor(
            dictKey: dictType.rawKeyString,
            entryCount: block.entryCount,
            maximumKeyLength: block.maximumKeyLength,
            indexStart: 0,
            dataStart: 0,
            dataEnd: 0
          )
        }
      )

      var descriptors: [HeaderDescriptor] = []
      descriptors.reserveCapacity(DictType.allCases.count)
      var cursor = placeholderHeader.count

      for (dictType, block) in zip(DictType.allCases, blocks) {
        let indexStart = cursor
        cursor += block.indexData.count
        let dataStart = cursor
        cursor += block.dataBlock.count
        let dataEnd = cursor

        descriptors.append(
          HeaderDescriptor(
            dictKey: dictType.rawKeyString,
            entryCount: block.entryCount,
            maximumKeyLength: block.maximumKeyLength,
            indexStart: indexStart,
            dataStart: dataStart,
            dataEnd: dataEnd
          )
        )
      }

      var data = makeHeader(descriptors: descriptors)
      for block in blocks {
        data.append(block.indexData)
        data.append(block.dataBlock)
      }
      return data
    }

    public func query(dict dictType: DictType, key searchKey: String) -> String? {
      let descriptor = descriptors[dictType.rawValue]
      guard descriptor.entryCount > 0 else { return nil }
      let searchKeyBytes = Array(searchKey.utf8)

      return storage.withUnsafeBytes { rawBytes in
        guard let baseAddress = rawBytes.bindMemory(to: UInt8.self).baseAddress else {
          return nil
        }

        var lowerBound = 0
        var upperBound = descriptor.entryCount - 1
        while lowerBound <= upperBound {
          let candidateIndex = lowerBound + (upperBound - lowerBound) / 2
          guard let entryStart = entryOffset(
            for: candidateIndex,
            descriptor: descriptor,
            baseAddress: baseAddress
          )
          else {
            return nil
          }

          let entryEnd: Int
          if candidateIndex + 1 < descriptor.entryCount {
            guard let nextStart = entryOffset(
              for: candidateIndex + 1,
              descriptor: descriptor,
              baseAddress: baseAddress
            )
            else {
              return nil
            }
            entryEnd = nextStart
          } else {
            entryEnd = descriptor.dataEnd
          }

          let comparison = Self.compare(
            searchKeyBytes,
            baseAddress: baseAddress,
            entryStart: entryStart,
            entryEnd: entryEnd
          )

          if comparison == 0 {
            return Self.decodeValue(
              baseAddress: baseAddress,
              entryStart: entryStart,
              entryEnd: entryEnd
            )
          }

          if comparison < 0 {
            upperBound = candidateIndex - 1
          } else {
            lowerBound = candidateIndex + 1
          }
        }

        return nil
      }
    }

    public func maximumKeyLength(for dictType: DictType) -> Int {
      descriptors[dictType.rawValue].maximumKeyLength
    }

    // MARK: Internal

    struct ValueSlice {
      let start: Int
      let end: Int
    }

    var storageByteCount: Int {
      storage.count
    }

    func string(for valueSlice: ValueSlice) -> String {
      storage.withUnsafeBytes { rawBytes in
        guard let baseAddress = rawBytes.bindMemory(to: UInt8.self).baseAddress else {
          return ""
        }

        return String(
          decoding: UnsafeBufferPointer(
            start: baseAddress.advanced(by: valueSlice.start),
            count: valueSlice.end - valueSlice.start
          ),
          as: UTF8.self
        )
      }
    }

    func forEachEntry(dict dictType: DictType, _ body: (String, String) -> ()) {
      let descriptor = descriptors[dictType.rawValue]
      guard descriptor.entryCount > 0 else { return }

      storage.withUnsafeBytes { rawBytes in
        guard let baseAddress = rawBytes.bindMemory(to: UInt8.self).baseAddress else {
          return
        }

        for entryIndex in 0 ..< descriptor.entryCount {
          guard let entryStart = entryOffset(
            for: entryIndex,
            descriptor: descriptor,
            baseAddress: baseAddress
          )
          else {
            return
          }

          let entryEnd: Int
          if entryIndex + 1 < descriptor.entryCount {
            guard let nextEntryStart = entryOffset(
              for: entryIndex + 1,
              descriptor: descriptor,
              baseAddress: baseAddress
            )
            else {
              return
            }
            entryEnd = nextEntryStart
          } else {
            entryEnd = descriptor.dataEnd
          }

          guard let entry = Self.decodeEntry(
            baseAddress: baseAddress,
            entryStart: entryStart,
            entryEnd: entryEnd
          ) else {
            return
          }
          body(entry.key, entry.value)
        }
      }
    }

    func forEachEntrySlice(dict dictType: DictType, _ body: (String, ValueSlice) -> ()) {
      let descriptor = descriptors[dictType.rawValue]
      guard descriptor.entryCount > 0 else { return }

      storage.withUnsafeBytes { rawBytes in
        guard let baseAddress = rawBytes.bindMemory(to: UInt8.self).baseAddress else {
          return
        }

        for entryIndex in 0 ..< descriptor.entryCount {
          guard let entryStart = entryOffset(
            for: entryIndex,
            descriptor: descriptor,
            baseAddress: baseAddress
          )
          else {
            return
          }

          let entryEnd: Int
          if entryIndex + 1 < descriptor.entryCount {
            guard let nextEntryStart = entryOffset(
              for: entryIndex + 1,
              descriptor: descriptor,
              baseAddress: baseAddress
            )
            else {
              return
            }
            entryEnd = nextEntryStart
          } else {
            entryEnd = descriptor.dataEnd
          }

          guard let key = Self.decodeKey(
            baseAddress: baseAddress,
            entryStart: entryStart,
            entryEnd: entryEnd
          ),
            let valueSlice = Self.decodeValueSlice(
              entryStart: entryStart,
              entryEnd: entryEnd,
              baseAddress: baseAddress
            )
          else {
            return
          }

          body(key, valueSlice)
        }
      }
    }

    // MARK: Private

    private struct DictDescriptor {
      let entryCount: Int
      let maximumKeyLength: Int
      let indexStart: Int
      let dataStart: Int
      let dataEnd: Int
    }

    private struct Block {
      let entryCount: Int
      let maximumKeyLength: Int
      let indexData: Data
      let dataBlock: Data
    }

    private struct HeaderDescriptor {
      let dictKey: String
      let entryCount: Int
      let maximumKeyLength: Int
      let indexStart: Int
      let dataStart: Int
      let dataEnd: Int
    }

    private static let headerSeparator = Data("\n\n".utf8)
    private static let magic = "HTSMAPTXT"
    private static let version: Int = 1
    private static let offsetHexWidth = 8
    private static let offsetLineWidth = offsetHexWidth + 1

    private let descriptors: [DictDescriptor]
    private let storage: Data

    private static func makeBlock(entries: [(key: String, value: String)]) throws -> Block {
      var offsets: [Int] = []
      offsets.reserveCapacity(entries.count)

      var dataBlock = Data()
      for (key, value) in entries {
        guard !containsUnsupportedControlCharacter(key) else {
          throw StringMapError.unsupportedControlCharacter
        }
        guard !containsUnsupportedControlCharacter(value) else {
          throw StringMapError.unsupportedControlCharacter
        }

        offsets.append(dataBlock.count)
        dataBlock.append(contentsOf: key.utf8)
        dataBlock.append(0x09)
        dataBlock.append(contentsOf: value.utf8)
        dataBlock.append(0x0A)
      }

      var indexData = Data()
      indexData.reserveCapacity(offsets.count * offsetLineWidth)
      for offset in offsets {
        indexData.append(contentsOf: try encodeHexField(offset).utf8)
        indexData.append(0x0A)
      }

      return Block(
        entryCount: entries.count,
        maximumKeyLength: entries.map { $0.key.count }.max() ?? 0,
        indexData: indexData,
        dataBlock: dataBlock
      )
    }

    private static func makeHeader(descriptors: [HeaderDescriptor]) -> Data {
      var lines: [String] = []
      lines.reserveCapacity(descriptors.count + 3)
      lines.append("\(magic)\t\(unsafeHexField(version))")
      lines.append("DICTS\t\(unsafeHexField(descriptors.count))")
      for descriptor in descriptors {
        lines.append(
          [
            descriptor.dictKey,
            unsafeHexField(descriptor.entryCount),
            unsafeHexField(descriptor.maximumKeyLength),
            unsafeHexField(descriptor.indexStart),
            unsafeHexField(descriptor.dataStart),
            unsafeHexField(descriptor.dataEnd),
          ].joined(separator: "\t")
        )
      }

      var output = Data(lines.joined(separator: "\n").utf8)
      output.append(Self.headerSeparator)
      return output
    }

    private static func parseHeaderFields(
      _ line: String,
      expectedCount: Int
    ) throws
      -> [String] {
      let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
      guard fields.count == expectedCount else {
        throw StringMapError.invalidHeader
      }
      return fields
    }

    private static func containsUnsupportedControlCharacter(_ value: String) -> Bool {
      value.contains("\t") || value.contains("\n") || value.contains("\r")
    }

    private static func normalizeLineEndings(in data: Data) -> Data {
      guard data.contains(0x0D) else { return data }

      var output = Data()
      output.reserveCapacity(data.count)
      var index = data.startIndex

      while index < data.endIndex {
        let byte = data[index]
        if byte == 0x0D {
          let nextIndex = data.index(after: index)
          if nextIndex < data.endIndex, data[nextIndex] == 0x0A {
            index = nextIndex
            continue
          }
        }

        output.append(byte)
        index = data.index(after: index)
      }

      return output
    }

    private static func encodeHexField(_ value: Int) throws -> String {
      guard let exactValue = UInt32(exactly: value) else {
        throw StringMapError.fileTooLarge
      }
      return String(format: "%08X", exactValue)
    }

    private static func unsafeHexField(_ value: Int) -> String {
      String(format: "%08X", UInt32(truncatingIfNeeded: value))
    }

    private static func decodeHexField(_ value: String) throws -> Int {
      guard value.count == offsetHexWidth else {
        throw StringMapError.invalidHeader
      }
      guard let decoded = Int(value, radix: 16) else {
        throw StringMapError.invalidHeader
      }
      return decoded
    }

    private static func decodeHexField(
      at offset: Int,
      baseAddress: UnsafePointer<UInt8>
    )
      -> Int? {
      var value = 0
      for index in 0 ..< offsetHexWidth {
        guard let nibble = hexNibble(baseAddress[offset + index]) else {
          return nil
        }
        value = (value << 4) | nibble
      }
      return value
    }

    private static func hexNibble(_ byte: UInt8) -> Int? {
      switch byte {
      case 48 ... 57:
        return Int(byte - 48)
      case 65 ... 70:
        return Int(byte - 55)
      default:
        return nil
      }
    }

    private static func compare(
      _ lhs: [UInt8],
      baseAddress: UnsafePointer<UInt8>,
      entryStart: Int,
      entryEnd: Int
    )
      -> Int {
      var rhsIndex = entryStart
      var lhsIndex = 0

      while lhsIndex < lhs.count, rhsIndex < entryEnd {
        let rhsByte = baseAddress[rhsIndex]
        if rhsByte == 0x09 || rhsByte == 0x0A || rhsByte == 0x0D {
          return 1
        }
        if lhs[lhsIndex] < rhsByte { return -1 }
        if lhs[lhsIndex] > rhsByte { return 1 }
        lhsIndex += 1
        rhsIndex += 1
      }

      if lhsIndex < lhs.count { return 1 }
      if rhsIndex < entryEnd {
        let rhsByte = baseAddress[rhsIndex]
        if rhsByte != 0x09, rhsByte != 0x0A, rhsByte != 0x0D { return -1 }
      }
      return 0
    }

    private static func decodeValue(
      baseAddress: UnsafePointer<UInt8>,
      entryStart: Int,
      entryEnd: Int
    )
      -> String? {
      guard let valueSlice = decodeValueSlice(
        entryStart: entryStart,
        entryEnd: entryEnd,
        baseAddress: baseAddress
      ) else {
        return nil
      }

      return String(
        decoding: UnsafeBufferPointer(
          start: baseAddress.advanced(by: valueSlice.start),
          count: valueSlice.end - valueSlice.start
        ),
        as: UTF8.self
      )
    }

    private static func decodeKey(
      baseAddress: UnsafePointer<UInt8>,
      entryStart: Int,
      entryEnd: Int
    )
      -> String? {
      var tabIndex = entryStart
      while tabIndex < entryEnd, baseAddress[tabIndex] != 0x09 {
        tabIndex += 1
      }
      guard tabIndex < entryEnd else { return nil }

      return String(
        decoding: UnsafeBufferPointer(
          start: baseAddress.advanced(by: entryStart),
          count: tabIndex - entryStart
        ),
        as: UTF8.self
      )
    }

    private static func decodeValueSlice(
      entryStart: Int,
      entryEnd: Int,
      baseAddress: UnsafePointer<UInt8>
    )
      -> ValueSlice? {
      var tabIndex = entryStart
      while tabIndex < entryEnd, baseAddress[tabIndex] != 0x09 {
        tabIndex += 1
      }
      guard tabIndex < entryEnd else { return nil }

      let valueStart = tabIndex + 1
      var valueEnd = entryEnd
      if valueEnd > valueStart, baseAddress[valueEnd - 1] == 0x0A {
        valueEnd -= 1
      }
      if valueEnd > valueStart, baseAddress[valueEnd - 1] == 0x0D {
        valueEnd -= 1
      }
      guard valueStart <= valueEnd else { return nil }

      return ValueSlice(start: valueStart, end: valueEnd)
    }

    private static func decodeEntry(
      baseAddress: UnsafePointer<UInt8>,
      entryStart: Int,
      entryEnd: Int
    )
      -> (key: String, value: String)? {
      guard let key = decodeKey(
        baseAddress: baseAddress,
        entryStart: entryStart,
        entryEnd: entryEnd
      ) else {
        return nil
      }

      guard let value = decodeValue(
        baseAddress: baseAddress,
        entryStart: entryStart,
        entryEnd: entryEnd
      ) else {
        return nil
      }

      return (key, value)
    }

    private func entryOffset(
      for index: Int,
      descriptor: DictDescriptor,
      baseAddress: UnsafePointer<UInt8>
    )
      -> Int? {
      let lineStart = descriptor.indexStart + index * Self.offsetLineWidth
      guard lineStart + Self.offsetLineWidth <= descriptor.dataStart else {
        return nil
      }
      guard baseAddress[lineStart + Self.offsetHexWidth] == 0x0A else {
        return nil
      }
      return Self.decodeHexField(at: lineStart, baseAddress: baseAddress).map {
        descriptor.dataStart + $0
      }
    }
  }
}
