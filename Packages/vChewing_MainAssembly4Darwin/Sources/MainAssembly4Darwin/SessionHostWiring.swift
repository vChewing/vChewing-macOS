// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Shared
import Shared_DarwinImpl
import Typewriter

// MARK: - SessionHost 動作依賴注入

extension SessionHost {
  /// 由宿主（MainAssembly4Darwin）於啟動時呼叫，將 Typewriter 套件
  /// 所需的宿主服務（LMMgr、IMEApp、Notifier、AppDelegate、SessionUI 等）注入。
  public static func wireUp() {
    let host = SessionHost.shared
    // IMEApp 動作依賴。
    host.isKeyboardJIS = { IMEApp.isKeyboardJIS }
    host.buzz = { IMEApp.buzz() }
    // LMMgr 動作依賴。
    host.isCoreDBConnected = { LMMgr.isCoreDBConnected }
    host.syncLMPrefs = { LMMgr.syncLMPrefs() }
    host.flushTrieCaches = { LMMgr.flushTrieCaches() }
    host.isStateDataFilterableForMarked = { LMMgr.isStateDataFilterableForMarked($0) }
    host.savePerceptionOverrideModelData = { LMMgr.savePerceptionOverrideModelData(false) }
    host.writeUserPhrasesAtOnce = { LMMgr.writeUserPhrasesAtOnce($0, areWeFiltering: $1) }
    host.bleachSpecifiedSuggestions = { targets, headReadings, mode in
      if let headReadings, !headReadings.isEmpty {
        LMMgr.bleachSpecifiedSuggestions(headReadings: headReadings, mode: mode)
      } else {
        LMMgr.bleachSpecifiedSuggestions(targets: targets, mode: mode)
      }
    }
    host.checkIfPhrasePairExists = { LMMgr.checkIfPhrasePairExists(userPhrase: $0, mode: $1, keyArray: $2) }
    host.checkIfPhrasePairIsFiltered = { LMMgr.checkIfPhrasePairIsFiltered(userPhrase: $0, mode: $1, keyArray: $2) }
    host.userDictDataURL = { LMMgr.userDictDataURL(mode: $0, type: $1) }
    // Notifier 動作依賴。
    host.notify = { Notifier.notify(message: $0) }
    // SpeechSputnik 動作依賴。
    host.narrate = { SpeechSputnik.shared.narrate($0) }
    host.narrator = { SpeechSputnik.shared }
    // AppDelegate 動作依賴。
    host.checkUpdate = { AppDelegate.shared.checkUpdate(forced: $0, shouldBypass: $1) }
    host.checkMemoryUsage = { AppDelegate.shared.checkMemoryUsage() }
    // NSRunningApplication / NSApp / NSWorkspace / NSSound / NSPasteboard 動作依賴。
    host.isElectronBasedApp = { NSRunningApplication.isElectronBasedApp(identifier: $0) }
    host.findAccentColor = { NSRunningApplication.findAccentColor(with: $0) }
    host.isAccentColorCustomized = { NSApp.isAccentColorCustomized }
    host.openURL = { NSWorkspace.shared.open($0) }
    host.isVoiceOverEnabled = {
      if #available(macOS 10.13, *) {
        return NSWorkspace.shared.isVoiceOverEnabled
      } else {
        return !NSRunningApplication.runningApplications(
          withBundleIdentifier: "com.apple.VoiceOver"
        ).isEmpty
      }
    }
    host.soundBuzz = { NSSound.buzz() }
    host.setPasteboardString = { str in
      NSPasteboard.general.declareTypes([.string], owner: nil)
      NSPasteboard.general.setString(str, forType: .string)
    }
    // IMKHelper / Broadcaster 動作依賴。
    host.isDynamicBasicKeyboardLayoutEnabled = { IMKHelper.isDynamicBasicKeyboardLayoutEnabled }
    host.postEventForClosingAllPanels = { Broadcaster.shared.postEventForClosingAllPanels() }
    // Controller 生命週期。
    host.isControllerAddressAlive = { IMKControllerLifetimeTracker.shared().isAddressAlive($0) }
    host.resolveClientProxy = { addr in
      guard let opaque = UnsafeRawPointer(bitPattern: addr) else { return nil }
      if !UserDefaults.pendingUnitTests {
        guard SessionHost.shared.isControllerAddressAlive(addr) else { return nil }
      }
      let obj = Unmanaged<AnyObject>.fromOpaque(opaque).takeUnretainedValue()
      return obj as? any SessionClientProxy
    }
    // UI / Prefs 動作依賴。
    host.ui = { SessionUI.shared }
    host.prefs = { PrefMgr.shared }
    // LangModel 動作依賴。
    host.pomDataURL = { LMMgr.perceptionOverrideModelDataURL($0) }
    host.validateCandidateKeys = { prefs, keys in
      prefs.validate(candidateKeys: keys)
    }
    // ChineseConverter 動作依賴（繁簡轉換）。
    host.crossConvert = { ChineseConverter.crossConvert($0) }
    host.kanjiConversionIfRequired = { ChineseConverter.kanjiConversionIfRequired($0) }
    // UserPhrase / CandidateTextService 動作依賴。
    host.updateUserPhraseWeight = { phrase, action in
      var phrase = phrase
      phrase.updateWeight(basedOn: action)
      return phrase
    }
    host.responseFromSelector = { $0.responseFromSelector }
  }
}
