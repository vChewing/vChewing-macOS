## vChewing Security Audit Tasks (2025-12-04)

以下為由安全審計 (bookmark/entitlements/typed unarchiving) 得出的任務清單，已標記出優先順序與推薦實作步驟。

> 注意：`as!` 強制轉型類型問題已被使用者修正，因此不在此清單中。

---

## ✅ 已完成

- [x] Audit UpdateSputnik
  - 檢查 `UpdateSputnik` 下載到的 plist 內容並限制可用 scheme（建議強制 `https`），避免打開任意或不安全的 URL。檔案位置：`Packages/vChewing_UpdateSputnik/Sources/UpdateSputnik/UpdateSputnik.swift`
  - 建議：若可能，對更新清單簽章或驗證以避免 MITM 攻擊。

---

## 主要待辦 (High/Medium 優先)

- [x] Fix Shell Usage (Medium → High if untrusted inputs possible)

  - 問題：多處 `NSApp.shell(...)` 或 `ShellHelper.shell(...)` 使用 `-c`（`zsh -c` / `bash -c`），並以字串插入參數，可能導致命令注入。請改成 `Process.executableURL` + `arguments` 的呼叫方式，並避免使用 shell 字串解析。
  - 主要檔案：
    - `Installer/InstallerShared.swift` (函式 `NSApplication.shell`)
    - `Packages/vChewing_OSFrameworkImpl/Sources/OSFrameworkImpl/AppKitImpl/AppKitImpl_Misc.swift`
    - `Source/Data/Sources/LibVanguardChewingData/Utils/ShellHelper.swift`
    - 其他呼叫 `NSApp.shell(...)` 的地方：`Installer/MainViewImpl.swift` 等。
  - 建議步驟：
    1. 新增一個安全 shell wrapper，例如 `exec(_ executable: String, args: [String])`，確保 `executableURL` 與 `arguments` 分離。
    2. 對所有呼叫 `-c` 的地方改用 wrapper，或直接改為 `Process` 調用。
    3. 新增單元測試，模擬注入內容與非注入場景，確保拒絕惡意參數。
  - 額外：檢查開發腳本 `Scripts/vchewing-update.swift` 及 `Source/Data/.../DataBuilder_*` 的參數處理。這些腳本可能接受 CLI 參數或環境變數（例如 `--path`），若這些參數會被放入 `-lc`/`-c` 之命令字串中，請替換為 `Process.executableURL` + `arguments`，或嚴格的參數 escape / 驗證。

- [x] Fix Hotenka SQL & URL Building (High)

  - 問題：`HotenkaChineseConverter` 在建立 SQLite 查詢時使用字串插入（例如：`theKey = '...`），以及使用 `URL(string: dictDir + $0)` 來建立檔案系統路徑。兩者均為風險源（SQL injection 與路徑解析錯誤）。
  - 主要檔案：`Packages/vChewing_Hotenka/Sources/Hotenka/HotenkaChineseConverter.swift`
  - 建議步驟：
    1. 改為使用 `sqlite3_prepare_v2` + `sqlite3_bind_text` / `sqlite3_bind_int`，杜絕 SQL 注入風險。
    2. 將路徑建立換成 `URL(fileURLWithPath: base).appendingPathComponent(filename)`，或在 Swift 中使用 `FileManager` 檢查與處理檔案。
    3. 寫單元測試，對帶有引號、特殊字元的查詢鍵做測試。
    - 已完成實作：
      - 將 `query(dict:key:)` 改寫為 prepared statement，並以 `sqlite3_bind_int` / `sqlite3_bind_text` 綁定參數。
      - 更新 `init(dictDir:)` 的檔案 URL 建構，改用 `URL(fileURLWithPath:)` + `appendingPathComponent`。
      - 在 `Hotenka` 單元測試加入對 SQL 注入的測試（`testSQLInjectionVulnerableQuery`）與將原先的 INSERT 測試改為使用 bind 以模擬不受影響的行為。

- [x] Harden LMInstantiator and other SQL hotspots (Medium)

  - 問題：`LMInstantiator_SQLExtension.swift`（和其他 SQL 片段）對某些查詢仍使用 string interpolation 並靠 `replace("'", "''")` 等防呆措施來避免 SQL injection；這不如使用 prepared/bound statements 安全可靠。
  - 建議步驟：
    1. 漸進式改動：把常用/關鍵 SQL 查询改寫成 bind 形式，再把其他次要查询一起改良。
    2. 編寫測試覆蓋邊界情形（包含單引號、分號、特殊字元）。
    3. 已完成實作：
    - `LMInstantiator_SQLExtension` 中多處以 `sqlite3_prepare_v2` + `sqlite3_bind_text` 改寫 `SELECT *` 類型查詢（並新增針對 SQL 注入的單元測試 `LMInstantiator_SQLInjectionTests`）。
    - 備註：`runAsSQLExec` 仍保留作為執行 PRAGMA/DDL/測試用途，任意 user-supplied SQL 應改為 prepared statements 並使用 `%` placeholders。

- [x] Harden Candidate Text Services (High)
  - 問題：`CandidateTextService` 允許以 `@URL:` 含 user-editable 的 URL 字串與 `@SEL:` 含 selector 的字串，並在 UI 中把這些輸入當作可執行動作（`NSWorkspace.shared.open(url)` 或 `performSelector`）執行。若使用者/偏好設定可由外部操控，攻擊者可將惡意 URL（javascript: 等）或任意 selector 放入偏好中以誘導執行。
  - 主要檔案：`Packages/vChewing_Shared/Sources/Shared/CandidateTextService.swift`、`Packages/vChewing_MainAssembly/Sources/MainAssembly/CandidateTextService_SelectorImpl.swift`、`Packages/vChewing_MainAssembly/Sources/MainAssembly/SessionController/InputSession_Delegates.swift`
  - 建議步驟：
    1. URL 白名單：`CandidateTextService` 構造時已限制 `@URL:` 只接受 `http`/`https` 這兩個 scheme。
    2. Selector 白名單：`finalSanityCheck` 已修改為 deny-by-default，並新增白名單（`copyUnicodeMetadata:`、`copyRuby*`、`copyInline*`、`copyBraille*`），且在 `Coordinator.runTask` 執行前再次檢查。已加入單元測試來驗證不允許的 `@SEL:` 或不安全 URL 被拒絕。
    3. 在 UI/Pref 編輯器中提示且限制使用者所使用的 service URL 與 selector，並在儲存時再做最後檢驗。
    4. 新增單元測試：嘗試輸入惡意 `@URL:` 與 `@SEL:`，驗證存取被拒絕或安全處理。

- [x] Harden CandidateTextService Selector Handling (High)
  - 問題：`Coordinator.runTask` 使用 `performSelector(onMainThread: Selector(selectorName), with: param, waitUntilDone: true)`，且 `finalSanityCheck` 目前預設放行（只在部分情況做特殊檢查），若偏好設定可被修改，攻擊者可能嘗試觸發未經授權的 selector（雖然 响應者僅在 `Coordinator` 類別內）。
  - 建議步驟：
    1. 改用明確 mapping（selectorName -> method closure）或 enum 方法，以在編譯時即確定可執行方法。 (已新增 runtime 白名單並在 `Coordinator.runTask` 再次檢查)
    2. 將 `finalSanityCheck` 改為 deny-by-default 模式，僅允許 `copyUnicodeMetadata:`、`copyRuby...`、`copyBraille...`、`copyInline...` 等必要的 selector。
    3. 若保留 `performSelector`，在執行前再檢查是否為白名單中的 method 名稱，拒絕一切不明 selector。
    4. 新增整合測試，確保只有被允許的 selector 可以被偏好設定呼叫，並在測試中模擬惡意 selector 字串。

---

## 目前不處理或無法處理的內容

- 1. Harden Kimo NSConnection handling (Medium)
  - 問題：`KimoCommunicator` 使用 `NSConnection rootProxyForConnectionWithRegisteredName` (舊 IPC 機制) 來與 Yahoo! Kimo 進行資料交換。雖然這是舊 API，會帶來來源驗證的風險，但 Yahoo! Kimo 自 2012 年底即停止維護（該專案被徹底取消），且原始設計針對 macOS 10.4+，不能支援 `NSXPCConnection`。vChewing 的目的僅是幫助遷移 Kimo 使用者資料；若要保持相容性，應避免移除該對接，而是以防禦性方式降低風險。
  - 主要檔案：`Packages/vChewing_KimoDataReader/Sources/ObjcKimoCommunicator/KimoCommunicator.m`
  - 建議步驟（不可改用 XPC 或不易轉移時）：
    1. 最小暴露面：將 Kimo 的 IPC 行為限定在 user-initiated 路徑（例如：匯入/匯出按鍵），並避免在背景自動啟動該連線。
    2. 輸入格式驗證：對 `userPhraseDBDictionaryAtRow:`, `exportUserPhraseDBToFile:` 等回傳內容進行結構 & schema 驗證（例如只接受 [String: String] / 具體 keys），拒絕任意不合格式或超大 payload。
    3. 路徑安全：`exportUserPhraseDBToFile:` 應在寫入前檢查目標路徑，防止任意路徑寫入，並在 UI 中要求使用者確認及限定到可接受目錄（如 `NSTemporaryDirectory()` 或 user-selected folder）。
    4. 身份盡力驗證：若可取得呼叫端的可辨識資訊（例如 processName/bundleID 或 code signature），在可能之處盡量核對以避免誤接到惡意程式；若無此資源，則至少拒絕未由使用者明確啟動的自動匯入。
    5. 日誌與偵測：加入短期連線偵測與警示（如發現異常結果、格式錯誤或過大資料時通知），以便偵測潛在冒充情況。
    6. 新增單元/整合測試：模擬格式錯亂或惡意回傳、測試 `exportUserPhraseDBToFile:` 的 path 限制與 user-interaction flow。
  - 備註（不可行時）：如果未來 Yahoo! Kimo 或其他遺留輸入法支援 NSXPC，則可再評估移轉，但目前不建議強制轉換以免切斷支援或破壞遷移流程。

- 2. Avoid logging sensitive user content (Medium)
  - 問題：在 debug 日誌中會列印完整 plist/查詢內容，例如 `Process.consoleLog("update check plist: \(plist)")`，或其他情況會把使用者資料寫進日誌中。這會增加敏感資訊外露風險（尤其在收集日誌或 debug 模式時）。
  - 不處理的原因：一旦處理了的話，使用者便無法參與到與開發者協同的偵錯過程。而且，該列印功能在預設情況下是不啟用的。
  - 如果處理的話，建議步驟：
    1. 在 `Process.consoleLog` 與 logger 內部提供可選擇的 redact 機制，例如 `vCLog` 或 `Process.consoleLog` 應避免在 release build 中把完整 plist 或用戶資料列印出來。
    2. 對所有 `consoleLog` 呼叫進行-review，避免日誌包含使用者私密資訊（例如 bookmarked paths、plist payload 內容）或限制到 debug 等級。
    3. 新增測試與日誌策略文檔（包括 log redaction 與 debug/production 的啟用規則）。

---

## Add Tests & CI (High)

- [x] Add macOS GitHub Actions runner + tests
  - 目標：讓 macOS-only 測試 (例如 `Jad_BookmarkManager`) 在 CI 上經常執行，以便提早捕捉平台差異或 API 開始棄用造成的問題。
  - 建議包含測試：
    - `UpdateSputnik`: mocking remote plist 檔案，測試不同 `UpdateInfoSite` 字段，確認 scheme 檢查（https）會拒絕不合法的 scheme。
    - `Hotenka`: 確認 bind 查詢對含引號鍵行為正常，並不會產生 SQL injection。
    - `NSApp.shell`/`ShellHelper`: 改寫後以單元測試確保安全和可預期輸出。
  - 建議步驟：
    1. 建立 `macos-latest` workflow，包含 `swift test` 執行的 packages。
    2. 啟用 `swift test` 過濾對應 macOS-only 包（`Jad_BookmarkManager`, `vChewing_Hotenka`, `UpdateSputnik` 等）。
    3. 新增 `CandidateTextService` 的單元測試：
      - 註：目前已新增與強化 `build_darwin_MainAssembly.yml`，使 macOS CI:
        - 使用 `actions/checkout@v4` 並檢出 submodule。
        - 快取 SwiftPM 與 `.build` 產物以加速重複工作。
        - 在 macOS Runner 上為關鍵 macOS-only package（`vChewing_Shared`, `vChewing_MainAssembly`, `vChewing_LangModelAssembly`, `vChewing_Hotenka`, `vChewing_OSFrameworkImpl`, `vChewing_UpdateSputnik`, `Jad_BookmarkManager`）逐一執行 `swift test`。
        - 適當處理 `swift test` 回傳的 `no tests found` (exit code 1) 情況，不會使 CI 失敗。

    - 確認 `@URL:` 只接受 `http`/`https`（`file:`、`data:`、`javascript:`、`mailto:` 等均被拒絕）。
    - 注意：若需要載入 macOS 系統字典（`dict://` scheme），請清楚指定是否將 `dict:` 納入白名單或改為使用 selector 以避開直接處理 URL 的風險。
    - 確認 `@SEL:` 只允許白名單內的方法（且 `performSelector`/Coordinator 只會在白名單的 selector 上執行）。
    4. 新增 `KimoCommunicator` 模擬 XPC/NSConnection 偽裝測試，檢查 parse/response 的邊界情況以及非預期來源的回傳導致的錯誤行為是否被拒絕。

---

## Memos

- `Update-Info.plist` 是 PLIST，解碼時應已具備對 MITM 的抵抗能力。如果內容有偽造的話，會直接 HTTPS 傳輸失敗。
- 使用者所提供之資料理論上應該不可能被送給 `Process` 來執行。

---

## Acceptance Criteria

- 所有改動點皆有單元測試（可在 macOS runner 上跑通）。
- 不會再直接使用 `-c` shell 命令字串插入（僅 developer-only scripts 保留且受控）。
- 所有在執行時直接 `open(...)` 外部 URL 的場景，預先驗證 `scheme` 與白名單域名（或強制 `https`）。
- `Hotenka` 與 `LMInstantiator` SQL 查詢全部改寫成 prepared/bound statements。

---

## 參考檔案

- `Packages/Jad_BookmarkManager/Sources/BookmarkManager/BookmarkManager.swift`
- `Packages/vChewing_UpdateSputnik/Sources/UpdateSputnik/UpdateSputnik.swift`
- `Installer/InstallerShared.swift`
- `Installer/MainViewImpl.swift`
- `Packages/vChewing_OSFrameworkImpl/Sources/OSFrameworkImpl/AppKitImpl/AppKitImpl_Misc.swift`
- `Source/Data/Sources/LibVanguardChewingData/Utils/ShellHelper.swift`
- `Packages/vChewing_Hotenka/Sources/Hotenka/HotenkaChineseConverter.swift`
- `Packages/vChewing_LangModelAssembly/Sources/LangModelAssembly/LMInstantiator_SQLExtension.swift`

---

## Source/Data Submodule: 專門 TODO（由 submodule 專案另一個 copilot session 解決）

> 說明：以下項目屬於 `Source/Data` 的子模組 (libvchewing-data) 中的資產與工具，請在對應的子模組專案中處理。不要在主倉庫直接變更這些檔案（除非你也更新子模組引用與 commit）。
>
> 該子模組專案在開發者的電腦上的位置： `/Users/shikisuen/Repos/!vChewing/vChewing-VanguardLexicon`

- [x] DataBuilder Shell Usage → 改以 exec+args（重要）

  - 檔案/範例：`Source/Data/Sources/LibVanguardChewingData/SubCodes/Builders/DataBuilder_ChewingCBased.swift`、`DataBuilder_ChewingRust.swift`、`DataBuilder_Protocol.swift`。
  - 工作說明：
    1. 把 `ShellHelper.shell(...)`、`shellWithPath(...)`、或直接 `Process` 的 `-c` 風格呼叫，替換為 `exec(_executable, args:, path:)`（或相等的低階 `Process` 呼叫，避免 shell string parsing）。
    2. 將 `firstCommand` / `secondCommand` 之類字串分離成 `executable` 與 `args`，不要把 CLI arguments 串成 `"chewing-cli init-database -t trie \(src) \(dst)"` 的單一字串傳入 `-c`。
    3. 在 Windows (PowerShell) 分支，盡可能以 `Process` 的 `executableURL` 跟 `arguments` 形式呼叫，或在 `PowerShell` 測試代碼中將參數單獨放到變數以避免被 shell 擴展。
    4. 新增單元測試：模擬惡意輸入（例如 `"; rm -rf /"` 之類）以證明無法注入。
    5. Acceptance：`swift test` 在 `Source/Data` 子模組測試套件能過，且示例 `DataBuilder` 流程能以 exec 呼叫正確產生檔案。

- [x] ShellHelper API 安全性加強（重要）

  - 檔案：`Source/Data/Sources/LibVanguardChewingData/Utils/ShellHelper.swift`（子模組）
  - 工作說明：
    1. 確認 `exec` 方法已在子模組中提供（以非 shell 方式執行可執行檔並傳給 args）。
    2. 移除或降權 `shell` / `shellWithPath` 的用法；若保留，務必強制為 developer-only 或明確地進行輸入逃逸。
    3. 在 `exec` 中實作 timeout、錯誤回傳與檢查 exit code，並封裝 log redaction 選項以避免出現在 release 日誌中。
    4. Acceptance：`exec` 在 `DataBuilder` / `Build` 流程中被使用且測試正常。

- [x] DataBuilders & Rust/C Build Flow（可移植性與安全）

  - 檔案/區域：`DataBuilder_ChewingRust.swift`、`DataBuilder_ChewingCBased.swift`、`DataBuilder_Protocol.swift`、`DataBuilder_...`。
  - 工作說明：
    1. 驗證 `PATH` 與 `PATH` 更新機制（例如使用 `Process` 的 `environment`），避免在 `-c` 下的 `which`/`env` 查找造成注入或路徑覆寫。
    2. 在 Windows branch 與 non-windows 上皆使用 `exec` 形式啟動可執行檔，並以 path/args 的方式處理。
    3. Acceptance：在 Linux/macOS/Windows 上都能成功執行，且無 `-c` 字串拼接或被 shell 解釋的情況。

- [x] sqlite / prepared statements in DataBuilder components（高）

  - 檔案：若子模組有使用 SQLite（例如 `DataBuilder_Protocol`, `Other DB`），請確認皆改為 `sqlite3_prepare_v2` + `sqlite3_bind_...`。
  - 工作說明：
    1. 一致性地將所有含有 user content 的查詢改為 prepared statements + bind variables。
    2. 如果生成 SQL 的工具本身 (例如 lexicon generator) 輸入資料載自 user-provided source，請在 parse pipeline 前驗證/逃逸/限制內容。
    3. Acceptance：對於子模組中 DB 存取行為加入 unit tests 確保注入無效並保持預期資料輸出。

- [x] Path & URL handling used in submodule (Low → Medium)

  - 檔案：若子模組內出現 `URL(string:)` 用於 file path 或 `URL(fileURLWithPath:)` 誤用，請進行檢查。
  - 工作說明：
    1. 將所有 file path 的 `URL(string:)` 換成 `URL(fileURLWithPath:)` 或 `baseURL.appendingPathComponent(...)`。
    2. 如果程式接收 user-supplied path，請檢查 canonicalization 並限制 write 目標為特定目錄（NSTemporaryDirectory 或 user chosen folder），以避免 arbitrary write。

- [x] Tests & CI in submodule (High)
  - 工作說明：
    1. 在子模組 repo 新增測試用 CI workflow (macOS runner / Linux if supported)，確保 `swift test` 能跑通。
    2. 確保 `DataBuilder` 腳本/程式在 CI 中也能被 exercise，或者在 dev machine 上以模擬用例執行。
