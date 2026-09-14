// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import Foundation
import LibVanguard
import Shared
import Shared_DarwinImpl

// MARK: - SessionHost 動作依賴注入

extension SessionHost {
  /// 由宿主（MainAssembly4Darwin）於啟動時呼叫，將 LibVanguard 套件
  /// 所需的宿主服務（LXMgr、IMEApp、Notifier、AppDelegate、SessionUI 等）注入。
  public static func wireUp() {
    let host = SessionHost.shared
    // IMEApp 動作依賴。
    host.isKeyboardJIS = { IMEApp.isKeyboardJIS }
    host.buzz = { IMEApp.buzz() }
    // LXMgr 動作依賴。
    host.isCoreDBConnected = { LXMgr.isCoreDBConnected }
    host.syncLMPrefs = { LXMgr.syncLMPrefs() }
    host.flushTrieCaches = { LXMgr.flushTrieCaches() }
    host.isStateDataFilterableForMarked = { LXMgr.isStateDataFilterableForMarked($0) }
    host.savePerceptionOverrideModelData = { LXMgr.savePerceptionOverrideModelData(false) }
    host.writeUserPhrasesAtOnce = { LXMgr.writeUserPhrasesAtOnce($0, areWeFiltering: $1) }
    host.bleachSpecifiedSuggestions = { targets, headReadings, mode in
      if let headReadings, !headReadings.isEmpty {
        LXMgr.bleachSpecifiedSuggestions(headReadings: headReadings, mode: mode)
      } else {
        LXMgr.bleachSpecifiedSuggestions(targets: targets, mode: mode)
      }
    }
    host.checkIfPhrasePairExists = { LXMgr.checkIfPhrasePairExists(userPhrase: $0, mode: $1, keyArray: $2) }
    host.checkIfPhrasePairIsFiltered = { LXMgr.checkIfPhrasePairIsFiltered(userPhrase: $0, mode: $1, keyArray: $2) }
    host.userDictDataURL = { LXMgr.userDictDataURL(mode: $0, type: $1) }
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
    // Lexicon 動作依賴。
    host.pomDataURL = { LXMgr.perceptionOverrideModelDataURL($0) }
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
