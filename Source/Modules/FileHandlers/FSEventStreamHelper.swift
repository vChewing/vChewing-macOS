// Copyright (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service
marks, or product names of Contributor, except as required to fulfill notice
requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import Cocoa

public protocol FSEventStreamHelperDelegate: AnyObject {
  func helper(_ helper: FSEventStreamHelper, didReceive events: [FSEventStreamHelper.Event])
}

public class FSEventStreamHelper {
  public struct Event {
    var path: String
    var flags: FSEventStreamEventFlags
    var id: FSEventStreamEventId
  }

  public var path: String
  public let dispatchQueue: DispatchQueue
  public weak var delegate: FSEventStreamHelperDelegate?

  public init(path: String, queue: DispatchQueue) {
    self.path = path
    dispatchQueue = queue
  }

  private var stream: FSEventStreamRef?

  public func start() -> Bool {
    if stream != nil {
      return false
    }
    var context = FSEventStreamContext()
    context.info = Unmanaged.passUnretained(self).toOpaque()
    guard
      let stream = FSEventStreamCreate(
        nil,
        {
          _, clientCallBackInfo, eventCount, eventPaths, eventFlags, eventIds in
          let helper = Unmanaged<FSEventStreamHelper>.fromOpaque(clientCallBackInfo!)
            .takeUnretainedValue()
          let pathsBase = eventPaths.assumingMemoryBound(to: UnsafePointer<CChar>.self)
          let pathsPtr = UnsafeBufferPointer(start: pathsBase, count: eventCount)
          let flagsPtr = UnsafeBufferPointer(start: eventFlags, count: eventCount)
          let eventIDsPtr = UnsafeBufferPointer(start: eventIds, count: eventCount)
          let events = (0..<eventCount).map {
            FSEventStreamHelper.Event(
              path: String(cString: pathsPtr[$0]),
              flags: flagsPtr[$0],
              id: eventIDsPtr[$0]
            )
          }
          helper.delegate?.helper(helper, didReceive: events)
        },
        &context,
        [path] as CFArray,
        UInt64(kFSEventStreamEventIdSinceNow),
        1.0,
        FSEventStreamCreateFlags(kFSEventStreamCreateFlagNone)
      )
    else {
      return false
    }

    FSEventStreamSetDispatchQueue(stream, dispatchQueue)
    if !FSEventStreamStart(stream) {
      FSEventStreamInvalidate(stream)
      return false
    }
    self.stream = stream
    return true
  }

  func stop() {
    guard let stream = stream else {
      return
    }
    FSEventStreamStop(stream)
    FSEventStreamInvalidate(stream)
    self.stream = nil
  }
}
