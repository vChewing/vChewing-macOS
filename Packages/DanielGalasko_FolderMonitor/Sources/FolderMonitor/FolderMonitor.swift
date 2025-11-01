// (c) 2018 Daniel Galasko
// Ref: https://medium.com/over-engineering/monitoring-a-folder-for-changes-in-ios-dc3f8614f902
// Further developments are done by (c) 2025 and onwards The vChewing Project (MIT-NTL License).

import Foundation

// MARK: - Debouncer

private final class Debouncer {
  // MARK: Lifecycle

  init(delay: TimeInterval, queue: DispatchQueue) {
    self.delay = delay
    self.queue = queue
  }

  deinit {
    invalidate()
  }

  // MARK: Internal

  func schedule(_ block: @escaping () -> ()) {
    lock.lock()
    let previousTimer = timer
    let newTimer = DispatchSource.makeTimerSource(queue: queue)
    newTimer.schedule(deadline: .now() + delay)
    newTimer.setEventHandler { [weak self, weak newTimer] in
      block()
      self?.completeActiveTimer(expected: newTimer)
    }
    timer = newTimer
    lock.unlock()

    previousTimer?.cancel()
    newTimer.resume()
  }

  func invalidate() {
    lock.lock()
    timer?.cancel()
    timer = nil
    lock.unlock()
  }

  // MARK: Private

  private let delay: TimeInterval
  private let queue: DispatchQueue
  private var timer: DispatchSourceTimer?
  private let lock = NSLock()

  private func completeActiveTimer(expected: DispatchSourceTimer?) {
    lock.lock()
    defer { lock.unlock() }
    guard let expected = expected, let currentTimer = timer else { return }
    if currentTimer === expected { timer = nil }
  }
}

// MARK: - FolderMonitor

public class FolderMonitor {
  // MARK: Lifecycle

  // MARK: Initializers

  public init(url: URL, debounceInterval: TimeInterval = 2) {
    // 此處 Debounce 時間故意設為兩秒。
    self.url = url
    self.debounceInterval = debounceInterval
    updateDebouncer()
  }

  // MARK: Public

  /// URL for the directory being monitored.
  public let url: URL

  public var folderDidChange: (() -> ())?

  /// 控制事件觸發的去抖動間隔。預設值 0.3 秒。
  public var debounceInterval: TimeInterval {
    didSet { updateDebouncer() }
  }

  /// 在指定時間內忽略檔案事件的通知回撥。
  public func suppressEvents(for interval: TimeInterval) {
    guard interval > 0 else { return }
    let deadline = Date().addingTimeInterval(interval)
    ignoreEventsLock.lock()
    if deadline > ignoreEventsUntil { ignoreEventsUntil = deadline }
    ignoreEventsLock.unlock()
  }

  // MARK: Monitoring

  /// Listen for changes to the directory (if we are not already).
  public func startMonitoring() {
    guard folderMonitorSource == nil, monitoredFolderFileDescriptor == -1 else {
      return
    }
    // Open the directory referenced by URL for monitoring only.
    monitoredFolderFileDescriptor = open(url.path, O_EVTONLY)
    // Define a dispatch source monitoring the directory for additions, deletions, and renamings.
    folderMonitorSource = DispatchSource.makeFileSystemObjectSource(
      fileDescriptor: monitoredFolderFileDescriptor, eventMask: .write, queue: folderMonitorQueue
    )
    // Define the block to call when a file change is detected.
    folderMonitorSource?.setEventHandler { [weak self] in
      guard let self = self else { return }
      self.handleFolderDidChange()
    }
    // Define a cancel handler to ensure the directory is closed when the source is cancelled.
    folderMonitorSource?.setCancelHandler { [weak self] in
      guard let self = self else { return }
      close(self.monitoredFolderFileDescriptor)
      self.monitoredFolderFileDescriptor = -1
      self.folderMonitorSource = nil
    }
    // Start monitoring the directory via the source.
    folderMonitorSource?.resume()
  }

  /// Stop listening for changes to the directory, if the source has been created.
  public func stopMonitoring() {
    folderMonitorSource?.cancel()
    eventDebouncer?.invalidate()
  }

  // MARK: Private

  private enum CloudStatus {
    case unknown
    case ubiquitous
    case notUbiquitous
  }

  /// A file descriptor for the monitored directory.
  private var monitoredFolderFileDescriptor: CInt = -1
  /// A dispatch queue used for sending file changes in the directory.
  private let folderMonitorQueue = DispatchQueue(
    label: "FolderMonitorQueue",
    attributes: .concurrent
  )
  /// A dispatch source to monitor a file descriptor created from the directory.
  private var folderMonitorSource: DispatchSourceFileSystemObject?
  private var eventDebouncer: Debouncer?
  private let resourceKeys: Set<URLResourceKey> = [
    .isDirectoryKey,
    .isUbiquitousItemKey,
    .ubiquitousItemDownloadingStatusKey,
    .ubiquitousItemIsDownloadingKey,
  ]
  private let ignoreEventsLock = NSLock()
  private var ignoreEventsUntil = Date.distantPast

  private var directoryCloudStatus: CloudStatus = .unknown

  private func updateDebouncer() {
    eventDebouncer?.invalidate()
    eventDebouncer = debounceInterval > 0
      ? Debouncer(delay: debounceInterval, queue: folderMonitorQueue)
      : nil
  }

  private func handleFolderDidChange() {
    if let eventDebouncer {
      eventDebouncer.schedule { [weak self] in
        guard let self = self else { return }
        self.notifyIfReady()
      }
      return
    }
    notifyIfReady()
  }

  private func notifyIfReady() {
    guard !shouldIgnoreDueToSelfWrites() else { return }
    guard !shouldDeferDueToCloudDownload() else { return }
    folderDidChange?()
  }

  private func shouldDeferDueToCloudDownload() -> Bool {
    guard isDirectoryBackedByICloud() else { return false }
    let fileManager = FileManager.default
    let options: FileManager.DirectoryEnumerationOptions = [.skipsSubdirectoryDescendants]
    let directoryURL = url
    let contents: [URL]
    do {
      contents = try fileManager.contentsOfDirectory(
        at: directoryURL,
        includingPropertiesForKeys: Array(resourceKeys),
        options: options
      )
    } catch {
      return false
    }
    for fileURL in contents {
      guard let values = try? fileURL.resourceValues(forKeys: resourceKeys) else { continue }
      if values.isDirectory == true { continue }
      guard values.isUbiquitousItem == true else { continue }
      if values.ubiquitousItemDownloadingStatus == .current { return true }
      if values.ubiquitousItemIsDownloading == true { return true }
    }
    return false
  }

  private func shouldIgnoreDueToSelfWrites() -> Bool {
    ignoreEventsLock.lock()
    let deadline = ignoreEventsUntil
    ignoreEventsLock.unlock()
    return Date() < deadline
  }

  private func isDirectoryBackedByICloud() -> Bool {
    if directoryCloudStatus == .unknown {
      if let values = try? url.resourceValues(forKeys: [.isUbiquitousItemKey]),
         values.isUbiquitousItem == true {
        directoryCloudStatus = .ubiquitous
      } else {
        directoryCloudStatus = .notUbiquitous
      }
    }
    return directoryCloudStatus == .ubiquitous
  }
}
