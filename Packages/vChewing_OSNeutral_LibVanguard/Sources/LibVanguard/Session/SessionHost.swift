// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import SwiftExtension

// MARK: - SessionHost

/// LibVanguard 對宿主（MainAssembly4Darwin）的動作依賴注入點。
///
/// 本套件不得依賴 MainAssembly4Darwin；所有需要宿主服務的動作
/// （LXMgr、IMEApp、Notifier、AppDelegate、SessionUI 等）皆由宿主於啟動時
/// 以 lambda-expression property assignment 的方式注入到 `SessionHost.shared`。
/// 未注入的屬性會保持無操作預設值，讓本套件可獨立於宿主被執行檔 bundle 除錯，
/// 也能在 Linux / Windows 等非 Darwin 平台上直接編譯。
public final class SessionHost {
  // MARK: Lifecycle

  public init() {}

  // MARK: Public

  public static var shared = SessionHost()

  // MARK: - IMEApp 動作依賴（Darwin 專屬部分）

  /// 當前鍵盤是否為 JIS 佈局。
  public var isKeyboardJIS: () -> Bool = { false }
  /// 蜂鳴或放屁聲。
  public var buzz: () -> () = {}

  // MARK: - LXMgr 動作依賴

  /// 核心辭典是否已連線。
  public var isCoreDBConnected: () -> Bool = { false }
  /// 同步語言模型偏好設定。
  public var syncLMPrefs: () -> () = {}
  /// 清除 Trie 查詢快取。
  public var flushTrieCaches: () -> () = {}
  /// 判斷給定 IMEStateData 是否可被加入過濾清單。
  public var isStateDataFilterableForMarked: (_ state: IMEStateData) -> Bool = { _ in false }
  /// 儲存感知模型資料。
  public var savePerceptionOverrideModelData: () -> () = {}
  /// 直接寫入使用者語彙。
  public var writeUserPhrasesAtOnce: (_ phrase: UserPhraseInsertable, _ areWeFiltering: Bool) -> Bool =
    { _, _ in false }
  /// 針對漸退模組清詞。
  public var bleachSpecifiedSuggestions: (_ targets: [String], _ headReadings: [String]?, _ mode: Shared.InputMode)
    -> () =
    { _, _, _ in }
  /// 檢查詞音配對是否在庫。
  public var checkIfPhrasePairExists: (_ userPhrase: String, _ mode: Shared.InputMode, _ keyArray: [String]) -> Bool =
    { _, _, _ in false }
  /// 檢查詞音配對是否已被過濾。
  public var checkIfPhrasePairIsFiltered: (_ userPhrase: String, _ mode: Shared.InputMode, _ keyArray: [String])
    -> Bool =
    { _, _, _ in false }
  /// 取得使用者辭典資料路徑。
  public var userDictDataURL: (_ mode: Shared.InputMode, _ type: LXAssembly.ReplacableUserDataType) -> URL =
    { _, _ in URL(fileURLWithPath: "") }

  // MARK: - Notifier 動作依賴

  /// 通知。
  public var notify: (String) -> () = { _ in }

  // MARK: - SpeechSputnik 動作依賴

  /// 朗讀。
  public var narrate: (String) -> () = { _ in }
  /// 語音朗讀器（SpeechNarratorProtocol 實例）。
  public var narrator: () -> (any SpeechNarratorProtocol)? = { nil }

  // MARK: - AppDelegate 動作依賴

  /// 檢查更新。
  public var checkUpdate: (_ forced: Bool, _ bypass: @escaping () -> Bool) -> () = { _, _ in }
  /// 檢查記憶體用量。
  public var checkMemoryUsage: () -> () = {}

  // MARK: - NSRunningApplication / NSApp / NSWorkspace / NSSound / NSPasteboard 動作依賴

  /// 判斷客體應用是否採用 Web 技術構築。
  public var isElectronBasedApp: (_ identifier: String) -> Bool = { _ in false }
  /// 取得客體應用的強調色。
  public var findAccentColor: (_ identifier: String) -> HSBA? = { _ in nil }
  /// 判斷系統是否已自訂強調色。
  public var isAccentColorCustomized: () -> Bool = { false }
  /// 開啟 URL。
  public var openURL: (URL) -> () = { _ in }
  /// 判斷 VoiceOver 是否開啟。
  public var isVoiceOverEnabled: () -> Bool = { false }
  /// 系統蜂鳴聲。
  public var soundBuzz: () -> () = {}
  /// 設定剪貼簿內容。
  public var setPasteboardString: (String) -> () = { _ in }

  // MARK: - IMKHelper / Broadcaster 動作依賴

  /// 是否啟用動態鍵盤佈局。
  public var isDynamicBasicKeyboardLayoutEnabled: () -> Bool = { false }
  /// 關閉所有浮動視窗。
  public var postEventForClosingAllPanels: () -> () = {}

  // MARK: - Controller 生命週期

  /// 檢查 controller 記憶體位址是否仍然存活。
  public var isControllerAddressAlive: (_ addr: UInt) -> Bool = { _ in false }
  /// 由 controller 記憶體位址解析出客戶端 proxy。
  public var resolveClientProxy: (_ addr: UInt) -> (any SessionClientProxy)? = { _ in nil }

  // MARK: - UI / Prefs 動作依賴

  /// 目前使用的 SessionUI（或 nil）。
  public var ui: () -> (any SessionUIProtocol)? = { nil }
  /// 目前使用的偏好設定實例。
  public var prefs: () -> any PrefMgrProtocol = { PrefMgr.sharedSansDidSetOps }

  // MARK: - Lexicon 動作依賴

  /// 取得指定模式下的感知模型（POM）資料路徑。
  public var pomDataURL: (Shared.InputMode) -> URL? = { _ in nil }
  /// 候選字鍵驗證。
  public var validateCandidateKeys: (_ prefs: any PrefMgrProtocol, _ keys: String) -> String? =
    { _, _ in nil }

  // MARK: - ChineseConverter 動作依賴（繁簡轉換）

  /// 繁簡轉換。
  public var crossConvert: (String) -> String = { $0 }
  /// 依偏好設定執行的繁簡轉換（含磁帶模式與康熙/JIS 模式）。
  public var kanjiConversionIfRequired: (String) -> String = { $0 }

  // MARK: - UserPhrase / CandidateTextService 動作依賴

  /// 依動作更新使用者語彙權重（Darwin 端實作含漸退模型權重建議）。
  public var updateUserPhraseWeight: (
    _ phrase: UserPhraseInsertable, _ action: CandidateContextMenuAction
  )
    -> UserPhraseInsertable = { phrase, _ in phrase }
  /// 候選文字服務的 selector 回應。
  public var responseFromSelector: (CandidateTextService) -> String? = { _ in nil }

  // MARK: Fileprivate

  /// 辭典物件之儲存格（`nil` 表示尚未建置）。
  fileprivate var lexiconFactoryStorage: LexiconAssembly.FactoryDictionary?
  /// 辭典副本之儲存格。
  fileprivate var lexiconStore: LexiconStore?
}

// MARK: - 辭典資源（P316）

extension SessionHost {
  /// 本宿主所持之原廠辭典物件：`lexicon(for:)` 之兩份副本共享同一份 TextMap 與磁帶，
  /// 故「連上測試辭典」只影響本宿主，不再波及行程內其他宿主與其他測試套房。
  public var factoryDictionary: LexiconAssembly.FactoryDictionary {
    get {
      lexiconFactoryStorage ?? LexiconAssembly.FactoryDictionary.shared
    }
    set {
      lexiconFactoryStorage = newValue
      resetLexiconCache()
    }
  }

  /// 取得指定模式下之辭典副本（首次索取時建置並快取）。
  public func lexicon(for mode: Shared.InputMode) -> LXAssembly.LXFacade {
    // 空模式亦落在此：回傳副本而非另建無辭典之實例，
    // 否則會話層取到的辭典與宿主所持者不是同一個（P316）。
    LXAssembly.applyEnvironmentDefaults()
    if lexiconStore == nil {
      lexiconStore = LexiconStore(pomDataURL: { self.pomDataURL($0) }, factory: factoryDictionary)
    }
    switch mode {
    case .imeModeCHS: return lexiconStore!.chs
    case .imeModeCHT, .imeModeNULL: return lexiconStore!.cht
    }
  }

  /// 丟棄已建置之辭典副本（下次索取時重建）。
  public func resetLexiconCache() {
    lexiconStore = nil
  }

  /// 兩份辭典副本之持有者。
  fileprivate final class LexiconStore {
    // MARK: Lifecycle

    init(pomDataURL: (Shared.InputMode) -> URL?, factory: LexiconAssembly.FactoryDictionary) {
      self.cht = LXAssembly.LXFacade(
        isCHS: false,
        pomDataURL: pomDataURL(.imeModeCHT),
        factory: factory
      )
      self.chs = LXAssembly.LXFacade(
        isCHS: true,
        pomDataURL: pomDataURL(.imeModeCHS),
        factory: factory
      )
    }

    // MARK: Internal

    let cht: LXAssembly.LXFacade
    let chs: LXAssembly.LXFacade
  }
}

// MARK: - Shared.InputMode.lexicon（跨平台）

extension Shared.InputMode {
  public static func resetLexiconCache(forUnitTests: Bool? = nil) {
    _ = forUnitTests
    SessionHost.shared.resetLexiconCache()
  }

  /// 當前模式所對應之辭典副本：一律經由 `SessionHost.shared` 取得。
  /// 需要與行程共用者隔離時（例如測試），請改走 `host.lexicon(for:)`。
  public var lexicon: LXAssembly.LXFacade {
    SessionHost.shared.lexicon(for: self)
  }
}
