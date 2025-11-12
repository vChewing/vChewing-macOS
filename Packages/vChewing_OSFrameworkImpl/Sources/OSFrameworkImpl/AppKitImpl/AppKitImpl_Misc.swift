// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

#if canImport(AppKit)

  import AppKit
  import CoreText

  // MARK: - Get Bundle Signature Timestamp

  extension Bundle {
    public func getCodeSignedDate() -> Date? {
      var code: SecStaticCode?
      var information: CFDictionary?
      let status4Code = SecStaticCodeCreateWithPath(
        bundleURL as CFURL,
        SecCSFlags(rawValue: 0),
        &code
      )
      guard status4Code == 0, let code = code else {
        Process.consoleLog("Error from getCodeSignedDate(): Failed from retrieving status4Code.")
        return nil
      }
      let status = SecCodeCopySigningInformation(
        code,
        SecCSFlags(rawValue: kSecCSSigningInformation),
        &information
      )
      guard status == noErr else {
        Process
          .consoleLog(
            "Error from getCodeSignedDate(): Failed from retrieving code signing intelligence."
          )
        return nil
      }
      guard let dictionary = information as? [String: NSObject] else { return nil }
      guard dictionary[kSecCodeInfoIdentifier as String] != nil else {
        Process.consoleLog("Error from getCodeSignedDate(): Target not signed.")
        return nil
      }
      guard let infoDate = dictionary[kSecCodeInfoTimestamp as String] as? Date else {
        Process.consoleLog("Error from getCodeSignedDate(): Target signing timestamp is missing.")
        return nil
      }
      return infoDate as Date
    }
  }

  // MARK: - Detect whether a running application is Electron-based.

  extension NSRunningApplication {
    public static func isElectronBasedApp(identifier: String) -> Bool {
      let ids = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
      guard !ids.isEmpty else { return false }
      for id in ids {
        guard let bURL = id.bundleURL, let bundle = Bundle(url: bURL) else { continue }
        if bundle.isElectronBasedApp { return true }
      }
      return false
    }
  }

  // MARK: - Detect whether a bundle is Electron-based.

  extension Bundle {
    public var isElectronBasedApp: Bool {
      // Check the info.plist.
      guard let dict = infoDictionary else { return false }
      if dict.keys.contains(where: { $0.lowercased().contains("electron") }) { return true }
      let selectedValues: [String] = dict.values.compactMap {
        ($0 as? CustomStringConvertible)?.description.lowercased()
      }
      if selectedValues.contains(where: { $0.contains("electron") }) { return true }
      // Check the existence of the Electron framework bundle.
      guard let urlFrameworks = privateFrameworksURL else { return false }
      guard let paths = try? FileManager.default.contentsOfDirectory(
        at: urlFrameworks,
        includingPropertiesForKeys: nil,
        options: []
      )
      else { return false }
      for path in paths {
        let pathLC = path.absoluteString.lowercased()
        if pathLC.contains("electron") { return true }
        if pathLC.contains("mswebview") { return true }
        if pathLC.contains("slimcorewebview") { return true }
      }
      return false
    }
  }

  // MARK: - NSAttributedString extension

  extension NSAttributedString {
    // MARK: Public API

    /// 回傳該 NSAttributedString 的邊界尺寸。單行、無附件文本會走 CoreText 快路徑。
    @objc
    public func getBoundingDimension(forceFallback: Bool = false) -> CGSize {
      guard length > 0 else { return .zero }
      let shouldFallback = forceFallback || containsLineBreaks || containsAttachments
      let path: MeasurementPath = shouldFallback ? .textKitFallback : .fastSingleLine
      return Self.measure(self, using: path)
    }

    // MARK: Private Helpers

    private enum MeasurementPath: Hashable { case fastSingleLine, textKitFallback }

    private struct CacheKey: Hashable {
      let stringHash: Int
      let attributesHash: Int
      let path: MeasurementPath
    }

    private static let newlineSet = CharacterSet.newlines
    private static let cacheQueue = DispatchQueue(
      label: "org.vChewing.candidateWindow.measure.cache",
      attributes: .concurrent
    )
    private static var cachedSizes: [CacheKey: CGSize] = [:]

    private static let textKitQueue =
      DispatchQueue(label: "org.vChewing.candidateWindow.measure.textkit")
    private static let textKitContext: TextKitContext = .init()

    private var containsLineBreaks: Bool { string.rangeOfCharacter(from: Self.newlineSet) != nil }

    private var containsAttachments: Bool {
      guard length > 0 else { return false }
      var result = false
      enumerateAttribute(
        .attachment,
        in: NSRange(location: 0, length: length),
        options: []
      ) { value, _, stop in
        guard value != nil else { return }
        result = true
        stop.pointee = true
      }
      return result
    }

    private static func measure(
      _ attributedString: NSAttributedString,
      using path: MeasurementPath
    )
      -> CGSize {
      let key = cacheKey(for: attributedString, path: path)
      if let cached = cachedSize(for: key) { return cached }

      let measured: CGSize
      switch path {
      case .fastSingleLine: measured = coreTextSize(for: attributedString)
      case .textKitFallback: measured = textKitSize(for: attributedString)
      }

      store(size: measured, for: key)
      return measured
    }

    private static func cachedSize(for key: CacheKey) -> CGSize? {
      cacheQueue.sync { cachedSizes[key] }
    }

    private static func store(size: CGSize, for key: CacheKey) {
      cacheQueue.async(flags: .barrier) { cachedSizes[key] = size }
    }

    private static func cacheKey(
      for attributedString: NSAttributedString,
      path: MeasurementPath
    )
      -> CacheKey {
      let stringHash = attributedString.string.hashValue
      let attributesHash = attributeHash(for: attributedString)
      return CacheKey(stringHash: stringHash, attributesHash: attributesHash, path: path)
    }

    private static func attributeHash(for attributedString: NSAttributedString) -> Int {
      guard attributedString.length > 0 else { return 0 }
      var hasher = Hasher()
      let fullRange = NSRange(location: 0, length: attributedString.length)
      attributedString.enumerateAttributes(in: fullRange, options: []) { attributes, range, _ in
        hasher.combine(range.length)
        let sortedPairs = attributes.sorted { lhs, rhs in lhs.key.rawValue < rhs.key.rawValue }
        for (key, value) in sortedPairs {
          hasher.combine(key.rawValue)
          switch value {
          case let font as NSFont:
            hasher.combine(font.fontName)
            hasher.combine(font.pointSize)
            hasher.combine(font.fontDescriptor.symbolicTraits.rawValue)
          case let number as NSNumber:
            hasher.combine(number.doubleValue)
          case let paragraph as NSParagraphStyle:
            hasher.combine(paragraph.alignment.rawValue)
            hasher.combine(paragraph.lineBreakMode.rawValue)
            hasher.combine(paragraph.minimumLineHeight)
            hasher.combine(paragraph.maximumLineHeight)
            hasher.combine(paragraph.lineSpacing)
          case let color as NSColor:
            if let rgbColor = color.usingColorSpace(.sRGB) {
              hasher.combine(rgbColor.redComponent)
              hasher.combine(rgbColor.greenComponent)
              hasher.combine(rgbColor.blueComponent)
              hasher.combine(rgbColor.alphaComponent)
            } else {
              hasher.combine(color.description)
            }
          case let attachment as NSTextAttachment:
            hasher.combine(ObjectIdentifier(attachment))
            if #available(macOS 10.11, *) {
              hasher.combine(NSStringFromRect(attachment.bounds))
            }
            if let cell = attachment.attachmentCell {
              hasher.combine(String(describing: type(of: cell)))
              let cellSize = cell.cellSize()
              hasher.combine(cellSize.width)
              hasher.combine(cellSize.height)
            }
          default:
            hasher.combine(String(describing: value))
          }
        }
      }
      return hasher.finalize()
    }

    private static func coreTextSize(
      for attributedString: NSAttributedString
    )
      -> CGSize {
      let line = CTLineCreateWithAttributedString(attributedString as CFAttributedString)
      var ascent: CGFloat = 0
      var descent: CGFloat = 0
      var leading: CGFloat = 0
      let typographicWidth = CGFloat(
        CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
      )
      let glyphBounds = CTLineGetBoundsWithOptions(line, [.useGlyphPathBounds])
      let widthFromGlyphs = max(0, glyphBounds.width)
      let computedWidth = max(typographicWidth, widthFromGlyphs)

      let fontMetrics = maximumFontMetrics(in: attributedString)
      let typographicHeight = ascent + descent + leading
      let fallbackHeight = fontMetrics.ascent + fontMetrics.descent
      let height = ceil(max(typographicHeight, fallbackHeight))

      return CGSize(width: ceil(max(computedWidth, 0)), height: height)
    }

    private static func textKitSize(for attributedString: NSAttributedString) -> CGSize {
      textKitQueue.sync {
        let context = textKitContext
        context.textContainer.containerSize = CGSize(
          width: CGFloat.greatestFiniteMagnitude,
          height: CGFloat.greatestFiniteMagnitude
        )
        context.textStorage.setAttributedString(attributedString)
        _ = context.layoutManager.glyphRange(for: context.textContainer)
        context.layoutManager.ensureLayout(for: context.textContainer)
        var usedRect = context.layoutManager.usedRect(for: context.textContainer)
        if usedRect.isNull { usedRect = .zero }
        return CGSize(
          width: ceil(max(usedRect.width, 0)),
          height: ceil(max(usedRect.height, 0))
        )
      }
    }

    private static func maximumFontMetrics(in attributedString: NSAttributedString)
      -> (ascent: CGFloat, descent: CGFloat) {
      guard attributedString.length > 0 else { return (0, 0) }
      var maxAscent: CGFloat = 0
      var maxDescent: CGFloat = 0
      let fullRange = NSRange(location: 0, length: attributedString.length)
      attributedString.enumerateAttribute(.font, in: fullRange, options: []) { value, _, _ in
        guard let font = value as? NSFont else { return }
        maxAscent = max(maxAscent, font.ascender)
        maxDescent = max(maxDescent, abs(font.descender))
      }
      return (maxAscent, maxDescent)
    }

    private final class TextKitContext {
      // MARK: Lifecycle

      init() {
        self.textStorage = NSTextStorage()
        self.layoutManager = NSLayoutManager()
        self.textContainer = NSTextContainer()
        textContainer.containerSize = CGSize(
          width: CGFloat.greatestFiniteMagnitude,
          height: CGFloat.greatestFiniteMagnitude
        )
        textContainer.lineFragmentPadding = 0
        textContainer.widthTracksTextView = false
        textContainer.heightTracksTextView = false
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
      }

      // MARK: Internal

      let textStorage: NSTextStorage
      let layoutManager: NSLayoutManager
      let textContainer: NSTextContainer
    }
  }

  // MARK: - Shell Extension

  extension NSApplication {
    public static func shell(_ command: String) throws -> String {
      let task = Process()
      let pipe = Pipe()

      task.standardOutput = pipe
      task.standardError = pipe
      task.arguments = ["-c", command]
      if #available(macOS 10.13, *) {
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
      } else {
        task.launchPath = "/bin/zsh"
      }
      task.standardInput = nil

      if #available(macOS 10.13, *) {
        try task.run()
      } else {
        task.launch()
      }

      var output = ""
      do {
        let data = try pipe.fileHandleForReading.readDataToEnd()
        if let data = data, let str = String(data: data, encoding: .utf8) {
          output.append(str)
        }
      } catch {
        return ""
      }
      return output
    }
  }

  extension NSApplication {
    // MARK: - System Dark Mode Status Detector.

    public static var isDarkMode: Bool {
      // "NSApp" can be nil during SPM unit tests.
      // Therefore, the method dedicated for macOS 10.15 and later is not considered stable anymore.
      // Fortunately, the method for macOS 10.14 works well on later macOS releases.
      if #available(macOS 10.14, *),
         let strAIS = UserDefaults.current.string(forKey: "AppleInterfaceStyle") {
        return strAIS.lowercased().contains("dark")
      } else {
        return false
      }
    }

    // MARK: - Tell whether this IME is running with Root privileges.

    public static var isSudoMode: Bool {
      NSUserName() == "root"
    }
  }

  // MARK: - Memory Footprint Calculator

  // Ref: https://developer.apple.com/forums/thread/105088?answerId=357415022#357415022
  extension NSApplication {
    /// The memory footprint of the current application in bytes.
    public static var memoryFootprint: UInt64? {
      // The `TASK_VM_INFO_COUNT` and `TASK_VM_INFO_REV1_COUNT` macros are too
      // complex for the Swift C importer, so we have to define them ourselves.
      let tskVMInfoCount = mach_msg_type_number_t(
        MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size
      )
      let tskVMInfoRev1Count = mach_msg_type_number_t(
        MemoryLayout.offset(of: \task_vm_info_data_t.min_address)! / MemoryLayout<integer_t>.size
      )
      var info = task_vm_info_data_t()
      var count = tskVMInfoCount
      let kr = withUnsafeMutablePointer(to: &info) { infoPtr in
        infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
          task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), intPtr, &count)
        }
      }
      guard kr == KERN_SUCCESS, count >= tskVMInfoRev1Count else { return nil }
      return info.phys_footprint as UInt64
    }
  }

  // MARK: - Apple Silicon Detector

  // Ref: https://developer.apple.com/forums/thread/678914

  extension NSApplication {
    public static var isAppleSilicon: Bool {
      Process.isAppleSilicon
    }
  }

  // MARK: - NSApp Activation Helper

  // This is to deal with changes brought by macOS 14.

  extension NSApplication {
    public func popup() {
      #if compiler(>=5.9) && canImport(AppKit, _version: 14.0)
        if #available(macOS 14.0, *) {
          NSApp.activate()
        } else {
          NSApp.activate(ignoringOtherApps: true)
        }
      #else
        NSApp.activate(ignoringOtherApps: true)
      #endif
    }
  }

  // MARK: - Reading bundle's accent color.

  extension NSColor {
    public static var accentColor: NSColor {
      guard #unavailable(macOS 10.14) else { return .controlAccentColor }
      return .alternateSelectedControlColor
    }
  }

  extension Bundle {
    fileprivate func getAccentColor() -> NSColor {
      let defaultResult: NSColor = .accentColor
      let queryPhrase =
        localizedInfoDictionary?["NSAccentColorName"] as? String ?? infoDictionary?[
          "NSAccentColorName"
        ] as? String
      guard let queryPhrase = queryPhrase, !queryPhrase.isEmpty else { return defaultResult }
      guard #available(macOS 10.13, *) else { return defaultResult }
      return NSColor(named: queryPhrase, bundle: self) ?? defaultResult
    }
  }

  extension NSRunningApplication {
    private static var temporatyBundlePtr: Bundle?

    public static func findAccentColor(with bundleIdentifier: String?) -> NSColor? {
      guard let bundleIdentifier else { return nil }
      let matchedRunningApps = Self.runningApplications(withBundleIdentifier: bundleIdentifier)
      guard let matchedAppURL = matchedRunningApps.first?.bundleURL else { return nil }
      Self.temporatyBundlePtr = Bundle(url: matchedAppURL)
      defer { temporatyBundlePtr = nil }
      return Self.temporatyBundlePtr?.getAccentColor().usingColorSpace(.deviceRGB)
    }
  }

  // MARK: - Check whether system's accent color is fixed with non-default value.

  extension NSApplication {
    public var isAccentColorCustomized: Bool {
      UserDefaults.standard.object(forKey: "AppleAccentColor") != nil
    }
  }

  // MARK: - Pasteboard Type Extension.

  extension NSPasteboard.PasteboardType {
    public static let kUTTypeFileURL =
      Self(rawValue: "public.file-url") // import UniformTypeIdentifiers
    public static let kUTTypeData = Self(rawValue: "public.data") // import UniformTypeIdentifiers
    public static let kUTTypeAppBundle =
      Self(rawValue: "com.apple.application-bundle") // import UniformTypeIdentifiers
    public static let kUTTypeUTF8PlainText = Self(rawValue: "public.utf8-plain-text")
    public static let kNSFilenamesPboardType = Self(rawValue: "NSFilenamesPboardType")
  }

  // MARK: - UXLevel

  extension NSApplication {
    public enum UXLevel: Int {
      case liquidGlass = 2
      case material = 1
      case none = 0
    }

    public static var uxLevel: UXLevel {
      switch (Process.isAppleSilicon, Process.totalMemoryGiB) {
      case (true, 16...):
        if #available(macOS 27, *) {
          return .liquidGlass
        } else {
          return .material
        }
      case (true, ..<16): return .material
      case (false, 8...): return .material
      case (false, ..<8): return .none
      case (_, _): return .none
      }
    }
  }

  extension NSColor {
    public var asHSBA: HSBA {
      .init(
        hue: hueComponent,
        saturation: saturationComponent,
        brightness: brightnessComponent,
        alpha: alphaComponent
      )
    }
  }

  extension HSBA {
    /// 轉換為 NSColor（僅 macOS）。確保數值合法。
    public var nsColor: NSColor {
      let h = hue.isFinite ? max(0, min(1, hue)) : 0
      let s = saturation.isFinite ? max(0, min(1, saturation)) : 0
      let b = brightness.isFinite ? max(0, min(1, brightness)) : 0
      let a = alpha.isFinite ? max(0, min(1, alpha)) : 1
      return NSColor(hue: h, saturation: s, brightness: b, alpha: a)
    }

    /// 從 NSColor 初始化（僅 macOS）。
    public init(_ nsColor: NSColor) {
      self.init(
        hue: nsColor.hueComponent,
        saturation: nsColor.saturationComponent,
        brightness: nsColor.brightnessComponent,
        alpha: nsColor.alphaComponent
      )
    }
  }

#endif
