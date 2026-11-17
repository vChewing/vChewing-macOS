// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import Foundation

// MARK: - SettingsUIWindowPolicy

/// SwiftUI 版偏好設定視窗（`CtlSettingsUI`）之供應範圍。
///
/// 本政策係**執行期**之單一真源：`CtlSettingsUI` 自身仍以 `@available(macOS 14, *)` 標記其
/// 編譯期下限；呼叫端則一律以本政策決定要開 SwiftUI 版、抑或退守 AppKit 版
/// （`CtlSettingsCocoa`）——輸入法之偏好選單（`showPreferences`）、選單列之設定項、
/// 診斷宿主三處皆然。
public enum SettingsUIWindowPolicy {
  /// 已排除之 macOS 主版本。
  ///
  /// `26` 全代排除：該代之終末版本於 SwiftUI（AppKit-based target）出現 `Form` 寬度失控之故障
  /// ——內容仍以兩欄之實需寬排版，視窗卻不再隨之撐開，遂見左右裁切。本工作區之機器已於
  /// macOS 27，無從複驗 26 之實機行為，故對該代一律退守 AppKit 版。日後若經實機複驗無虞，
  /// 刪去此列即恢復供應（`SettingsUIWindowPolicyTests` 之表列會同步要求改正）。
  public static let excludedSystemMajorVersions: Set<Int> = [26]

  /// 本政策所認可之最低 macOS 主版本（與 `CtlSettingsUI` 之 `@available(macOS 14, *)` 對位）。
  public static let minimumSystemMajorVersion: Int = 14

  /// 現行系統之 macOS 主版本。
  ///
  /// 走 `OS.currentOSVersionString` 而非 `ProcessInfo.operatingSystemVersion`：後者起自
  /// macOS 10.10，而本套件於 Swift 5.10 之路徑上仍以 10.9 為部署地板。
  public static var systemMajorVersion: Int {
    guard let majorComponent = OS.currentOSVersionString.split(separator: ".").first else { return 0 }
    return Int(majorComponent) ?? 0
  }

  /// 現行系統是否應供應 SwiftUI 版設定視窗。
  public static var isSwiftUIWindowAvailable: Bool {
    isSwiftUIWindowAvailable(systemMajorVersion: systemMajorVersion)
  }

  /// 給定 macOS 主版本是否應供應 SwiftUI 版設定視窗。
  public static func isSwiftUIWindowAvailable(systemMajorVersion majorVersion: Int) -> Bool {
    guard majorVersion >= minimumSystemMajorVersion else { return false }
    return !excludedSystemMajorVersions.contains(majorVersion)
  }
}
