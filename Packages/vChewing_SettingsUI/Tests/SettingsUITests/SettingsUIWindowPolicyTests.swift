// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import Testing

@testable import SettingsUI

// MARK: - SettingsUIWindowPolicyTests

/// `SettingsUIWindowPolicy` 之供應範圍表列。
///
/// 本套件只驗「給定主版本 → 是否供應」這層純函式，不開任何視窗，故不與 UI 測試爭用執行緒。
@Suite
final class SettingsUIWindowPolicyTests {
  @Test
  func testExcludedSystemVersions() {
    // macOS 26 全代排除。
    #expect(!SettingsUIWindowPolicy.isSwiftUIWindowAvailable(systemMajorVersion: 26))
  }

  @Test
  func testUnsupportedSystemVersions() {
    #expect(!SettingsUIWindowPolicy.isSwiftUIWindowAvailable(systemMajorVersion: 10))
    #expect(!SettingsUIWindowPolicy.isSwiftUIWindowAvailable(systemMajorVersion: 12))
    #expect(!SettingsUIWindowPolicy.isSwiftUIWindowAvailable(systemMajorVersion: 13))
  }

  @Test
  func testSupportedSystemVersions() {
    #expect(SettingsUIWindowPolicy.isSwiftUIWindowAvailable(systemMajorVersion: 14))
    #expect(SettingsUIWindowPolicy.isSwiftUIWindowAvailable(systemMajorVersion: 15))
    #expect(SettingsUIWindowPolicy.isSwiftUIWindowAvailable(systemMajorVersion: 27))
    #expect(SettingsUIWindowPolicy.isSwiftUIWindowAvailable(systemMajorVersion: 28))
  }

  @Test
  func testCurrentSystemFollowsTheSameRule() {
    let majorVersion = SettingsUIWindowPolicy.systemMajorVersion
    #expect(majorVersion >= 10)
    let expected = majorVersion >= SettingsUIWindowPolicy.minimumSystemMajorVersion
      && !SettingsUIWindowPolicy.excludedSystemMajorVersions.contains(majorVersion)
    #expect(SettingsUIWindowPolicy.isSwiftUIWindowAvailable == expected)
  }
}
