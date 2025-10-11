// (c) 2019 and onwards Robert Muckle-Jones (Apache 2.0 License).

import Foundation
import SwiftExtension

// MARK: - LineReader

public class LineReader {
  // MARK: Lifecycle

  public init(
    file: FileHandle, encoding: String.Encoding = .utf8,
    chunkSize: Int = 4_096
  ) throws {
    let fileHandle = file
    self.encoding = encoding
    self.chunkSize = chunkSize
    self.fileHandle = fileHandle
    self.delimData = "\n".data(using: encoding)!
    self.buffer = Data(capacity: chunkSize)
    self.atEof = false
  }

  // MARK: Public

  /// Return next line, or nil on EOF.
  public func nextLine() -> String? {
    // Read data chunks from file until a line delimiter is found:
    while !atEof {
      // get a data from the buffer up to the next delimiter
      if let range = buffer.range(of: delimData) {
        // convert data to a string
        let line = String(data: buffer.subdata(in: 0 ..< range.lowerBound), encoding: encoding)!
        // remove that data from the buffer
        buffer.removeSubrange(0 ..< range.upperBound)
        return line.trimmingCharacters(in: .newlines)
      }

      fileRead: do {
        let nextData = try fileHandle.readData(upToCount: chunkSize)
        if let nextData = nextData, !nextData.isEmpty {
          buffer.append(nextData)
          continue
        }
      } catch {
        break fileRead
      }

      // End of file or read error
      atEof = true
      if !buffer.isEmpty {
        // Buffer contains last line in file (not terminated by delimiter).
        let line = String(data: buffer as Data, encoding: encoding)!
        return line.trimmingCharacters(in: .newlines)
      }
    }
    return nil
  }

  /// Start reading from the beginning of file.
  public func rewind() {
    fileHandle.seek(toFileOffset: 0)
    buffer.count = 0
    atEof = false
  }

  // MARK: Internal

  let encoding: String.Encoding
  let chunkSize: Int
  var fileHandle: FileHandle
  let delimData: Data
  var buffer: Data
  var atEof: Bool
}

// MARK: Sequence

extension LineReader: Sequence {
  public func makeIterator() -> AnyIterator<String> {
    AnyIterator {
      self.nextLine()
    }
  }
}
