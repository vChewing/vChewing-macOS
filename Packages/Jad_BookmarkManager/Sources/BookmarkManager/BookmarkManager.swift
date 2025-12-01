/// Ref: https://stackoverflow.com/a/61695824
/// License: https://creativecommons.org/licenses/by-sa/4.0/
/// Further developments are done by (c) 2025 and onwards The vChewing Project (MIT-NTL License).

#if os(macOS)
  import AppKit

  #if canImport(OSLog)
    import OSLog
  #endif

  // MARK: - BookmarkManager

  public final class BookmarkManager {
    // MARK: Lifecycle

    deinit {
      stopAllSecurityScopedAccesses()
    }

    // MARK: Public

    public static let shared = BookmarkManager()

    // MARK: - 檢視/狀態查詢

    /// 回傳目前正在使用的 security-scoped 存取 URL 陣列。僅供測試／除錯使用。
    public var activeSecurityScopedAccessURLs: [URL] { Array(startedAccessingURLs) }

    /// 儲存 URL 的書籤。在 NSOpenPanel 的 `begin` closure 內使用。
    public func saveBookmark(for url: URL) {
      guard let bookmarkDataEntry = getBookmarkData(url: url),
            let bookmarkURL = getBookmarkURL()
      else {
        Self.consoleLog("Error getting data or bookmarkURL")
        return
      }
      // 載入現有書籤，合併後再寫回。
      do {
        var existingBookmarks: [URL: Data] = [:]
        if fileExists(bookmarkURL) {
          let existingData = try Data(contentsOf: bookmarkURL)
          if let fileBookmarks = decodeBookmarksData(existingData) {
            existingBookmarks = fileBookmarks
          }
        }
        // 停止將被取代的舊 URL 所開啟的 security-scope 存取（若存在）。
        let newUrl = bookmarkDataEntry.keys.first!
        for existingKey in existingBookmarks.keys
          where existingKey.path == newUrl.path && existingKey != newUrl {
          if startedAccessingURLs.contains(existingKey) {
            existingKey.stopAccessingSecurityScopedResource()
            startedAccessingURLs.remove(existingKey)
          }
          existingBookmarks.removeValue(forKey: existingKey)
        }
        // 合併 / 替換書籤項目
        existingBookmarks.merge(bookmarkDataEntry) { _, new in new }

        var outData: Data?
        if #unavailable(macOS 10.13) {
          outData = NSKeyedArchiver.archivedData(withRootObject: existingBookmarks)
        } else {
          // 在可行時優先使用 requiringSecureCoding，以在讀取時強制安全解碼。
          do {
            outData = try NSKeyedArchiver.archivedData(withRootObject: existingBookmarks, requiringSecureCoding: true)
          } catch {
            // 針對舊版解析機制採用非 secure 的序列化備援。
            outData = try NSKeyedArchiver.archivedData(withRootObject: existingBookmarks, requiringSecureCoding: false)
          }
        }
        if let outData = outData {
          // 確保 parent 目錄存在
          let dir = bookmarkURL.deletingLastPathComponent()
          try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
          // 使用原子寫入，並設定嚴格檔案權限（rw-------）。
          try outData.write(to: bookmarkURL, options: [.atomic])
          try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: bookmarkURL.path)
        }
        Self.consoleLog("Did save data to url")
      } catch {
        Self.consoleLog("Couldn't save bookmarks")
      }
    }

    /// Load bookmarks when your app launch for example
    public func loadBookmarks() {
      guard let url = getBookmarkURL() else {
        return
      }

      // 為避免重複的 startAccessing 呼叫，先停止已存在的所有 security-scoped access。
      stopAllSecurityScopedAccesses()

      if fileExists(url) {
        do {
          let fileData = try Data(contentsOf: url)
          if let fileBookmarks = decodeBookmarksData(fileData) {
            for bookmark in fileBookmarks {
              restoreBookmark(key: bookmark.key, value: bookmark.value)
            }
          }
        } catch {
          Self.consoleLog("Couldn't load bookmarks")
        }
      }
    }

    /// 停止所有已啟動的 security-scoped 資源，並清空內部紀錄。
    public func stopAllSecurityScopedAccesses() {
      startedAccessingURLs.forEach { url in
        url.stopAccessingSecurityScopedResource()
      }
      startedAccessingURLs.removeAll()
    }

    /// 如果指定 URL 的 security-scoped 資源已啟動，則停止存取它。
    public func stopAccessingSecurityScopedResource(for url: URL) {
      if startedAccessingURLs.contains(url) {
        url.stopAccessingSecurityScopedResource()
        startedAccessingURLs.remove(url)
      }
    }

    /// 設定一個書籤檔案路徑的覆寫（僅供測試用），傳入 `nil` 可清除覆寫。
    /// 這比起使用環境變數更明確，也可讓測試穩定地使用每個測試個別的暫存檔案。
    public func setBookmarksURLOverride(_ url: URL?) {
      Self.bookmarksURLOverride = url
    }

    // MARK: Internal

    static func consoleLog<S: StringProtocol>(_ msg: S) {
      let msgStr = msg.description
      if #available(macOS 26.0, *) {
        #if canImport(OSLog)
          let logger = Logger(subsystem: "vChewing", category: "BookmarkManager")
          logger.log(level: .default, "\(msgStr, privacy: .public)")
          return
        #else
          break
        #endif
      }

      // 兼容舊系統
      NSLog(msgStr)
    }

    // MARK: Private

    // MARK: - 測試 hook：允許覆寫 Bookmark 所使用的路徑

    private static var bookmarksURLOverride: URL?

    /// 追蹤曾呼叫 startAccessingSecurityScopedResource() 的 URL，以便日後停止呼叫（釋放權限）。
    private var startedAccessingURLs: Set<URL> = []

    private func restoreBookmark(key: URL, value: Data) {
      let restoredUrl: URL?
      var isStale = false

      Self.consoleLog("Restoring \(key)")
      do {
        restoredUrl = try URL(
          resolvingBookmarkData: value,
          options: NSURL.BookmarkResolutionOptions.withSecurityScope,
          relativeTo: nil,
          bookmarkDataIsStale: &isStale
        )
      } catch {
        Self.consoleLog("Error restoring bookmarks")
        restoredUrl = nil
      }

      if let url = restoredUrl {
        if isStale {
          Self.consoleLog("URL is stale")
          // 嘗試以新的書籤資料更新該筆書籤條目
          if let newBookmarkData = try? url.bookmarkData(
            options: NSURL.BookmarkCreationOptions.withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
          ), let bmURL = getBookmarkURL() {
            var existing = [URL: Data]()
            if fileExists(bmURL), let fileData = try? Data(contentsOf: bmURL) {
              if let fileBookmarks = decodeBookmarksData(fileData) {
                existing = fileBookmarks
              }
            }
            existing[key] = newBookmarkData
            if #unavailable(macOS 10.13) {
              let newData = NSKeyedArchiver.archivedData(withRootObject: existing)
              try? newData.write(to: bmURL)
            } else {
              if let newData = try? NSKeyedArchiver.archivedData(
                withRootObject: existing,
                requiringSecureCoding: false
              ) {
                try? newData.write(to: bmURL)
              }
            }
          }
        } else {
          // 每個 URL 僅在尚未啟動時呼叫 startAccessingSecurityScopedResource() 一次以避免重複
          if !startedAccessingURLs.contains(url) {
            if !url.startAccessingSecurityScopedResource() {
              Self.consoleLog("Couldn't access: \(url.path)")
            } else {
              startedAccessingURLs.insert(url)
            }
          }
        }
      }
    }

    private func getBookmarkData(url: URL) -> [URL: Data]? {
      let data = try? url.bookmarkData(
        options: NSURL.BookmarkCreationOptions.withSecurityScope,
        includingResourceValuesForKeys: nil,
        relativeTo: nil
      )
      if let data = data {
        return [url: data]
      }
      return nil
    }

    private func getBookmarkURL() -> URL? {
      // 如果存在測試覆寫，則優先使用
      if let override = Self.bookmarksURLOverride {
        return override
      }

      return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).last?
        .appendingPathComponent("Bookmarks.dict")
    }

    private func fileExists(_ url: URL) -> Bool {
      var isDir = ObjCBool(false)
      let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)

      return exists
    }

    // MARK: - 解序列化輔助函式

    /// 將給定資料解序列化為 typed 的 [URL: Data] 字典。
    /// macOS 11+ 優先使用 typed API（`unarchivedDictionary`）；舊版 macOS 則回退到 `unarchiveTopLevelObjectWithData` 或 `unarchiveObject`，並進行執行時類型驗證。
    private func decodeBookmarksData(_ data: Data) -> [URL: Data]? {
      // 委派給相容性 shim 來處理（解序列化的相容/驗證邏輯）
      NSKeyedUnarchiver.unarchivedURLDataDictionaryCompat(from: data)
    }
  }

  // MARK: - Typed 解序列化相容性輔助

  extension NSKeyedUnarchiver {
    /// 相容性 wrapper：在 macOS 11+ 優先使用 typed API 取得 [URL: Data]，舊平台則使用備援解序列化流程並做類型轉換。
    static func unarchivedURLDataDictionaryCompat(from data: Data) -> [URL: Data]? {
      // 優先採用 macOS 11 的 typed API
      if #available(macOS 11.0, *) {
        if let typed = try? NSKeyedUnarchiver.unarchivedDictionary(
          ofKeyClass: NSURL.self, objectClass: NSData.self, from: data
        ) {
          return extractURLDataMap(from: typed)
        }
      }

      // 在 macOS 10.11+ 的情況下，使用 TopLevel 解序列化再轉換
      if #available(macOS 10.11, *) {
        if let obj = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) {
          return extractURLDataMap(from: obj)
        }
      } else {
        // 舊版 fallback
        if let obj = NSKeyedUnarchiver.unarchiveObject(with: data) {
          return extractURLDataMap(from: obj)
        }
      }
      return nil
    }

    /// 輔助函式：驗證並將解序列化後的物件強制轉換為 [URL: Data]
    /// 將任意解序列化物件轉換為 [URL: Data]。
    /// 這是 `extractURLDataMap` 的通用實作，已從 BookmarkManager 中抽出。
    static func extractURLDataMap(from d: Any) -> [URL: Data]? {
      switch d {
      case let d as [URL: Data]: return d
      case let d as [NSURL: NSData]:
        var out = [URL: Data]()
        d.forEach { k, v in out[k as URL] = v as Data }
        return out
      case let d as [AnyHashable: Any]:
        var out = [URL: Data]()
        for (k, v) in d {
          if let url = parseAnyHashMapKeyToURL(k) {
            out[url] = parseAnyHashMapValueToData(v)
          }
        }
        return out.isEmpty ? nil : out
      default:
        return nil
      }
    }

    fileprivate static func parseAnyHashMapKeyToURL(_ k: AnyHashable) -> URL? {
      switch k {
      case let k as URL: return k
      case let k as NSURL: return k as URL
      case let k as String:
        let s = k
        if s.contains("://"), let url = URL(string: s) {
          // 僅允許本地 file schema；拒絕其他網路（非本地） schema。
          guard url.scheme?.lowercased() == "file" else { return nil }

          // 如果 URL 帶有 host（例如 "localhost"），忽略 host 並僅使用回傳的路徑部分；
          // 本管理器只支援本地檔案 URL。
          // 使用 url.path 同時會將 percent-encoding 的內容解碼（例如 %20 -> 空白）。
          let p = url.path
          return URL(fileURLWithPath: p)
        }

        // No scheme: treat as a local filesystem path.
        return URL(fileURLWithPath: s)
      default: return nil
      }
    }

    fileprivate static func parseAnyHashMapValueToData(_ dd: Any) -> Data? {
      switch dd {
      case let dd as Data: return dd
      case let dd as NSData: return dd as Data
      default: return nil
      }
    }
  }

#endif
