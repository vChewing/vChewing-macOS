//  Ref: https://stackoverflow.com/a/61695824
//  License: https://creativecommons.org/licenses/by-sa/4.0/

import Cocoa

public class BookmarkManager {
  public static let shared = BookmarkManager()
  // Save bookmark for URL. Use this inside the NSOpenPanel `begin` closure
  public func saveBookmark(for url: URL) {
    guard let bookmarkDic = getBookmarkData(url: url),
      let bookmarkURL = getBookmarkURL()
    else {
      NSLog("Error getting data or bookmarkURL")
      return
    }

    if #available(macOS 10.13, *) {
      do {
        let data = try NSKeyedArchiver.archivedData(withRootObject: bookmarkDic, requiringSecureCoding: false)
        try data.write(to: bookmarkURL)
        NSLog("Did save data to url")
      } catch {
        NSLog("Couldn't save bookmarks")
      }
    }
  }

  // Load bookmarks when your app launch for example
  public func loadBookmarks() {
    guard let url = getBookmarkURL() else {
      return
    }

    if fileExists(url) {
      do {
        let fileData = try Data(contentsOf: url)
        if let fileBookmarks = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(fileData) as! [URL: Data]? {
          for bookmark in fileBookmarks {
            restoreBookmark(key: bookmark.key, value: bookmark.value)
          }
        }
      } catch {
        NSLog("Couldn't load bookmarks")
      }
    }
  }

  private func restoreBookmark(key: URL, value: Data) {
    let restoredUrl: URL?
    var isStale = false

    NSLog("Restoring \(key)")
    do {
      restoredUrl = try URL(
        resolvingBookmarkData: value, options: NSURL.BookmarkResolutionOptions.withSecurityScope, relativeTo: nil,
        bookmarkDataIsStale: &isStale
      )
    } catch {
      NSLog("Error restoring bookmarks")
      restoredUrl = nil
    }

    if let url = restoredUrl {
      if isStale {
        NSLog("URL is stale")
      } else {
        if !url.startAccessingSecurityScopedResource() {
          NSLog("Couldn't access: \(url.path)")
        }
      }
    }
  }

  private func getBookmarkData(url: URL) -> [URL: Data]? {
    let data = try? url.bookmarkData(
      options: NSURL.BookmarkCreationOptions.withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil
    )
    if let data = data {
      return [url: data]
    }
    return nil
  }

  private func getBookmarkURL() -> URL? {
    let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
    if let appSupportURL = urls.last {
      let url = appSupportURL.appendingPathComponent("Bookmarks.dict")
      return url
    }
    return nil
  }

  private func fileExists(_ url: URL) -> Bool {
    var isDir = ObjCBool(false)
    let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)

    return exists
  }
}
