// (c) 2018 Daniel Galasko
// Ref: https://medium.com/over-engineering/monitoring-a-folder-for-changes-in-ios-dc3f8614f902

import Foundation

public class FolderMonitor {
  // MARK: Properties

  /// A file descriptor for the monitored directory.
  private var monitoredFolderFileDescriptor: CInt = -1
  /// A dispatch queue used for sending file changes in the directory.
  private let folderMonitorQueue = DispatchQueue(label: "FolderMonitorQueue", attributes: .concurrent)
  /// A dispatch source to monitor a file descriptor created from the directory.
  private var folderMonitorSource: DispatchSourceFileSystemObject?
  /// URL for the directory being monitored.
  public let url: URL

  public var folderDidChange: (() -> Void)?

  // MARK: Initializers

  public init(url: URL) {
    self.url = url
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
      self?.folderDidChange?()
    }
    // Define a cancel handler to ensure the directory is closed when the source is cancelled.
    folderMonitorSource?.setCancelHandler { [weak self] in
      guard let strongSelf = self else { return }
      close(strongSelf.monitoredFolderFileDescriptor)
      strongSelf.monitoredFolderFileDescriptor = -1
      strongSelf.folderMonitorSource = nil
    }
    // Start monitoring the directory via the source.
    folderMonitorSource?.resume()
  }

  /// Stop listening for changes to the directory, if the source has been created.
  public func stopMonitoring() {
    folderMonitorSource?.cancel()
  }
}
