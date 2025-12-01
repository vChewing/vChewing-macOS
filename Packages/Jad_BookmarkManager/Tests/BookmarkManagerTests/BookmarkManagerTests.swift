#if os(macOS)

  @testable import BookmarkManager
  import XCTest

  final class BookmarkManagerTests: XCTestCase {
    var bmURL: URL?

    override func setUpWithError() throws {
      // 確保每個測試開始前為乾淨狀態
      BookmarkManager.shared.stopAllSecurityScopedAccesses()

      // 每個測試使用獨立的 bookmarks 路徑，以免在並行測試時互相衝突。
      // 我們使用 BookmarkManager 提供的測試覆寫 API 指向此暫存檔案。
      let tempFile = FileManager.default.temporaryDirectory
        .appendingPathComponent("Bookmarks-\(UUID().uuidString).dict")
      BookmarkManager.shared.setBookmarksURLOverride(tempFile)
      bmURL = tempFile
      if let url = bmURL, FileManager.default.fileExists(atPath: url.path) {
        try? FileManager.default.removeItem(at: url)
      }
    }

    override func tearDownWithError() throws {
      BookmarkManager.shared.stopAllSecurityScopedAccesses()
      if let url = bmURL, FileManager.default.fileExists(atPath: url.path) {
        try? FileManager.default.removeItem(at: url)
      }
      // 清除測試覆寫設定（最佳努力）
      BookmarkManager.shared.setBookmarksURLOverride(nil)
    }

    func testSaveCreatesBookmarksFileAndContainsEntry() throws {
      // 建立暫時資料夾以模擬使用者選擇
      let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

      BookmarkManager.shared.saveBookmark(for: tempDir)

      XCTAssertNotNil(bmURL)
      guard let bmURL = bmURL else { return } // 確保 bmURL 已拆包
      let data = try Data(contentsOf: bmURL)
      let dict = NSKeyedUnarchiver.unarchivedURLDataDictionaryCompat(from: data)

      XCTAssertNotNil(dict)
      XCTAssertTrue(
        dict?.keys.contains(where: { $0.path == tempDir.path }) ?? false,
        "Saved bookmark should include our temp folder URL"
      )

      // 清理暫時資料
      try? FileManager.default.removeItem(at: tempDir)
    }

    func testLoadStartsAccessAndStopClears() throws {
      let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
      BookmarkManager.shared.saveBookmark(for: tempDir)

      // 載入書籤：應嘗試還原並開始存取（若執行環境允許）
      BookmarkManager.shared.loadBookmarks()

      // 我們不能保證在所有 CI/環境下 `startAccessing...` 會回傳 true，但可驗證呼叫是安全的
      // 且 stopAllSecurityScopedAccesses 會清空正在存取的列表。
      let activeBeforeStop = BookmarkManager.shared.activeSecurityScopedAccessURLs
      // 呼叫 stop （停止所有存取）
      BookmarkManager.shared.stopAllSecurityScopedAccesses()
      let activeAfterStop = BookmarkManager.shared.activeSecurityScopedAccessURLs

      XCTAssertEqual(activeAfterStop.count, 0, "All active security scoped accesses must be stopped")

      _ = activeBeforeStop // 保留該變數以便在實際 macOS 環境下除錯

      try? FileManager.default.removeItem(at: tempDir)
    }

    func testSaveMultipleMergesBookmarks() throws {
      let tempDir1 = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      let tempDir2 = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      try FileManager.default.createDirectory(at: tempDir1, withIntermediateDirectories: true)
      try FileManager.default.createDirectory(at: tempDir2, withIntermediateDirectories: true)

      BookmarkManager.shared.saveBookmark(for: tempDir1)
      BookmarkManager.shared.saveBookmark(for: tempDir2)
      guard let bmURL = bmURL else { return } // 確保 bmURL 已拆包
      let data = try Data(contentsOf: bmURL)
      let dict = NSKeyedUnarchiver.unarchivedURLDataDictionaryCompat(from: data)
      XCTAssertNotNil(dict)
      let paths = dict?.keys.map { $0.path } ?? []
      XCTAssertTrue(paths.contains(tempDir1.path), "Bookmarks should contain first path")
      XCTAssertTrue(paths.contains(tempDir2.path), "Bookmarks should contain second path")

      try? FileManager.default.removeItem(at: tempDir1)
      try? FileManager.default.removeItem(at: tempDir2)
    }

    func testDecodeLegacyStringPathKey() throws {
      let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

      let bookmarkData = try tempDir.bookmarkData(
        options: NSURL.BookmarkCreationOptions.withSecurityScope,
        includingResourceValuesForKeys: nil,
        relativeTo: nil
      )

      // 建立舊式格式的字典，其中 key 為字串路徑
      let legacyDict: [String: Data] = [tempDir.path: bookmarkData]
      let archivedData: Data
      if #available(macOS 10.13, *) {
        archivedData = try NSKeyedArchiver.archivedData(
          withRootObject: legacyDict,
          requiringSecureCoding: false
        )
      } else {
        archivedData = NSKeyedArchiver.archivedData(withRootObject: legacyDict)
      }

      let parsed = NSKeyedUnarchiver.unarchivedURLDataDictionaryCompat(from: archivedData)
      XCTAssertNotNil(parsed)
      XCTAssertTrue(parsed?.keys.contains(where: { $0.path == tempDir.path }) ?? false)

      try? FileManager.default.removeItem(at: tempDir)
    }

    func testDecodeLegacyFileURLStringKey() throws {
      let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

      let bookmarkData = try tempDir.bookmarkData(
        options: NSURL.BookmarkCreationOptions.withSecurityScope,
        includingResourceValuesForKeys: nil,
        relativeTo: nil
      )

      // key 為 file:// 格式的 URL 字串
      let fileURLString = URL(fileURLWithPath: tempDir.path).absoluteString
      let legacyDict: [String: Data] = [fileURLString: bookmarkData]
      let archivedData: Data
      if #available(macOS 10.13, *) {
        archivedData = try NSKeyedArchiver.archivedData(
          withRootObject: legacyDict,
          requiringSecureCoding: false
        )
      } else {
        archivedData = NSKeyedArchiver.archivedData(withRootObject: legacyDict)
      }

      let parsed = NSKeyedUnarchiver.unarchivedURLDataDictionaryCompat(from: archivedData)
      XCTAssertNotNil(parsed)
      XCTAssertTrue(parsed?.keys.contains(where: { $0.path == tempDir.path }) ?? false)

      try? FileManager.default.removeItem(at: tempDir)
    }

    func testDecodeNSURLKeyNSDataValue() throws {
      let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

      let bookmarkData = try tempDir.bookmarkData(
        options: NSURL.BookmarkCreationOptions.withSecurityScope,
        includingResourceValuesForKeys: nil,
        relativeTo: nil
      )

      let nsDict: [NSURL: NSData] = [tempDir as NSURL: bookmarkData as NSData]
      let archivedData: Data
      if #available(macOS 10.13, *) {
        archivedData = try NSKeyedArchiver.archivedData(
          withRootObject: nsDict,
          requiringSecureCoding: false
        )
      } else {
        archivedData = NSKeyedArchiver.archivedData(withRootObject: nsDict)
      }

      let parsed = NSKeyedUnarchiver.unarchivedURLDataDictionaryCompat(from: archivedData)
      XCTAssertNotNil(parsed)
      XCTAssertTrue(parsed?.keys.contains(where: { $0.path == tempDir.path }) ?? false)

      try? FileManager.default.removeItem(at: tempDir)
    }

    func testDecodeLegacyFileURLLocalhostStringKey() throws {
      let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

      let bookmarkData = try tempDir.bookmarkData(
        options: NSURL.BookmarkCreationOptions.withSecurityScope,
        includingResourceValuesForKeys: nil,
        relativeTo: nil
      )

      // key 為 file://localhost 格式的 URL 字串
      let fileURLString = "file://localhost" + URL(fileURLWithPath: tempDir.path).path
      let legacyDict: [String: Data] = [fileURLString: bookmarkData]
      let archivedData: Data
      if #available(macOS 10.13, *) {
        archivedData = try NSKeyedArchiver.archivedData(
          withRootObject: legacyDict,
          requiringSecureCoding: false
        )
      } else {
        archivedData = NSKeyedArchiver.archivedData(withRootObject: legacyDict)
      }

      let parsed = NSKeyedUnarchiver.unarchivedURLDataDictionaryCompat(from: archivedData)
      XCTAssertNotNil(parsed)
      XCTAssertTrue(parsed?.keys.contains(where: { $0.path == tempDir.path }) ?? false)

      try? FileManager.default.removeItem(at: tempDir)
    }

    func testDecodeLegacyStringNSDataValue() throws {
      let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

      let bookmarkData = try tempDir.bookmarkData(
        options: NSURL.BookmarkCreationOptions.withSecurityScope,
        includingResourceValuesForKeys: nil,
        relativeTo: nil
      )

      // 舊式字典：String 型別的 key 與 NSData 型別的 value
      let legacyDict: [String: NSData] = [tempDir.path: bookmarkData as NSData]
      let archivedData: Data
      if #available(macOS 10.13, *) {
        archivedData = try NSKeyedArchiver.archivedData(
          withRootObject: legacyDict,
          requiringSecureCoding: false
        )
      } else {
        archivedData = NSKeyedArchiver.archivedData(withRootObject: legacyDict)
      }

      let parsed = NSKeyedUnarchiver.unarchivedURLDataDictionaryCompat(from: archivedData)
      XCTAssertNotNil(parsed)
      XCTAssertTrue(parsed?.keys.contains(where: { $0.path == tempDir.path }) ?? false)

      try? FileManager.default.removeItem(at: tempDir)
    }

    func testRejectNonFileURLStringKey() throws {
      let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

      let bookmarkData = try tempDir.bookmarkData(
        options: NSURL.BookmarkCreationOptions.withSecurityScope,
        includingResourceValuesForKeys: nil,
        relativeTo: nil
      )

      // key 為 http:// 格式的 URL 字串 — 應被拒絕（非本地檔案 URL）
      let httpKey = "http://example.com/this/is/not/a/file"
      let legacyDict: [String: Data] = [httpKey: bookmarkData]
      let archivedData: Data
      if #available(macOS 10.13, *) {
        archivedData = try NSKeyedArchiver.archivedData(
          withRootObject: legacyDict,
          requiringSecureCoding: false
        )
      } else {
        archivedData = NSKeyedArchiver.archivedData(withRootObject: legacyDict)
      }

      let parsed = NSKeyedUnarchiver.unarchivedURLDataDictionaryCompat(from: archivedData)
      XCTAssertNil(parsed)

      try? FileManager.default.removeItem(at: tempDir)
    }
  }

#endif
