// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import SwiftExtension

// MARK: - FolderMonitor

public final class FolderMonitor: NSObject, NSFilePresenter {
  // MARK: Lifecycle

  public init(url: URL, debounceInterval: TimeInterval = 1) {
    self.url = url
    self.debounceInterval = debounceInterval
    super.init()
    updateDebouncer()
  }

  deinit {
    mainSync {
      stopMonitoring()
    }
  }

  // MARK: Public

  /// 正在監控的目錄 URL。
  public let url: URL

  public var folderDidChange: (() -> ())?

  /// 控制事件觸發的去抖動間隔。
  public var debounceInterval: TimeInterval {
    didSet { updateDebouncer() }
  }

  /// NSFilePresenter 協議要求的 OperationQueue。
  public nonisolated var presentedItemOperationQueue: OperationQueue {
    folderMonitorOperationQueue
  }

  /// NSFilePresenter 協議要求的監控對象。
  public nonisolated var presentedItemURL: URL? {
    url
  }

  /// 在指定時間內忽略檔案事件的通知回撥。
  public func suppressEvents(for interval: TimeInterval) {
    guard interval > 0 else { return }
    let deadline = Date().addingTimeInterval(interval)
    ignoreEventsLock.withLock {
      if deadline > ignoreEventsUntil { ignoreEventsUntil = deadline }
    }
  }

  // MARK: Monitoring

  /// 開始監控。在 Sandbox 中，這會將物件註冊為 File Presenter。
  public func startMonitoring() {
    guard !isMonitoring else { return }
    // 在 Sandbox 且涉及 iCloud 時，NSFileCoordinator 是感知變動的關鍵。
    NSFileCoordinator.addFilePresenter(self)
    isMonitoring = true
  }

  /// 停止監控。
  public func stopMonitoring() {
    guard isMonitoring else { return }
    NSFileCoordinator.removeFilePresenter(self)
    eventDebouncer?.invalidate()
    isMonitoring = false
  }

  // MARK: NSFilePresenter Events

  /// 當目錄下的子項目發生變動（寫入、移動、刪除）時由系統調用。
  public nonisolated func presentedSubitemDidChange(at url: URL) {
    // 過濾掉因為雲端正在下載導致的頻繁更新
    mainSync {
      handleFolderDidChange()
    }
  }

  /// 當目錄本身發生屬性變動時調用。
  public nonisolated func presentedItemDidChange() {
    mainSync {
      handleFolderDidChange()
    }
  }

  // MARK: Private

  private var isMonitoring = false

  /// 使用 OperationQueue 配合 NSFilePresenter。
  private let folderMonitorOperationQueue: OperationQueue = {
    let queue = OperationQueue()
    queue.name = "org.vchewing.FolderMonitorQueue"
    queue.maxConcurrentOperationCount = 1
    return queue
  }()

  private var eventDebouncer: Debouncer?
  private let ignoreEventsLock = NSLock()
  private var ignoreEventsUntil = Date.distantPast

  private let resourceKeys: Set<URLResourceKey> = [
    .isDirectoryKey,
    .isUbiquitousItemKey,
    .ubiquitousItemDownloadingStatusKey,
    .ubiquitousItemIsDownloadingKey,
  ]

  private func updateDebouncer() {
    eventDebouncer?.invalidate()
    eventDebouncer = debounceInterval > 0
      ? Debouncer(delay: debounceInterval, queue: .main) // 使用 Main 或是指定的 Queue
      : nil
  }

  private func handleFolderDidChange() {
    if let eventDebouncer {
      eventDebouncer.schedule { [weak self] in
        guard let this = self else { return }
        this.notifyIfReady()
      }
      return
    }
    notifyIfReady()
  }

  private func notifyIfReady() {
    guard !shouldIgnoreDueToSelfWrites() else { return }
    // 檢查是否為雲端同步引起的暫態變化
    guard !shouldDeferDueToCloudDownload() else { return }

    // 返回主執行緒執行回調，確保 UI 安全性
    asyncOnMain { [weak self] in
      self?.folderDidChange?()
    }
  }

  private func shouldDeferDueToCloudDownload() -> Bool {
    let fileManager = FileManager.default
    let options: FileManager.DirectoryEnumerationOptions = [.skipsSubdirectoryDescendants]

    // 注意：在 Sandbox 中，存取 iCloud 目錄可能需要 Security-Scoped Access
    let shouldAccess = url.startAccessingSecurityScopedResource()
    defer { if shouldAccess { url.stopAccessingSecurityScopedResource() } }

    guard let contents = try? fileManager.contentsOfDirectory(
      at: url,
      includingPropertiesForKeys: Array(resourceKeys),
      options: options
    ) else { return false }

    for fileURL in contents {
      guard let values = try? fileURL.resourceValues(forKeys: resourceKeys) else { continue }
      if values.isDirectory == true { continue }
      guard values.isUbiquitousItem == true else { continue }
      // 如果文件正在從雲端下載，暫時不觸發變動通知
      if values.ubiquitousItemDownloadingStatus != .current || values.ubiquitousItemIsDownloading == true {
        return true
      }
    }
    return false
  }

  private func shouldIgnoreDueToSelfWrites() -> Bool {
    ignoreEventsLock.withLock {
      Date() < ignoreEventsUntil
    }
  }
}
