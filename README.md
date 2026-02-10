語言：[简体中文](./README-CHS.md) | *繁體中文*

僅以此 README 紀念祁建華 (CHIEN-HUA CHI, 1921-2001)。

---

有關該倉庫及該輸入法的最新資訊，請洽產品主頁：https://vchewing.github.io/

因不可控原因，該倉庫只能保證在 Gitee 有最新的內容可用：

- 下載：https://gitee.com/vchewing/vChewing-macOS/releases
- 程式碼倉庫：https://gitee.com/vchewing/vChewing-macOS

# vChewing 唯音輸入法

唯音輸入法是一款為 macOS 平台開發的副廠**原生簡體中文、原生繁體中文注音輸入法**：

- 唯音是業界現階段支援注音排列種類數量與輸入用拼音種類數量最多的注音輸入法。
    - 受唯音自家的鐵恨注音並擊引擎加持。
- 唯音的原廠詞庫內不存在任何可以妨礙該輸入法在世界上任何地方傳播的內容。
- 相比中州韻（鼠須管）而言，唯音能夠做到真正的大千聲韻並擊。
- 擁有拼音並擊模式，不懂注音的人群也可以受益於該輸入法所帶來的穩定的平均輸入速度。
    - 相比小鶴雙拼等雙拼方案而言，唯音雙手聲韻分工明確、且重碼率只有雙拼的五分之一。
- 唯音對陸規審音完全相容：不熟悉台澎金馬審音的大陸用戶不會遇到與漢字讀音有關的不便。
    - 反之亦然。
- 唯音輸入法是最安全的 macOS 副廠中文輸入法：
    - 有啟用 Sandbox 特性，（相比其他沒有開 Sandbox 而言）唯音輸入法在原理上不可能拿到系統全局鍵盤權限。
    - 有「強化型組字區安全防護」模式，防止「接收打字的軟體」提前存取您的組字區的內容。

>唯音有很多特色功能。在此僅列舉部分：
>- 支援 macOS 螢幕模擬鍵盤（僅傳統大千與傳統倚天佈局）。
>- 可以將自己打的繁體中文自動轉成日本 JIS 新字體來輸出（包括基礎的字詞轉換）、也可以轉成康熙繁體來輸出。
>- 簡繁體中文語料庫彼此分離，徹底杜絕任何繁簡轉換過程可能造成的失誤。
>- 支援近年的全字庫漢字輸入。
>- 可以自動整理使用者語彙檔案格式、自訂關聯詞語。
>- ……

唯音分支專案及唯音詞庫（先鋒語料庫）由孫志貴（Shiki Suen）維護，其內容屬於可在 Gitee 公開展示的合法內容。但這些內容在被整理收入先鋒語料庫之前的原始資料的合規性不屬於維護者的負責範圍之內。

> 資安宣告：唯音輸入法的 Shift 按鍵監測功能僅藉由對 NSEvent 訊號資料流的上下文關係的觀測來實現，僅接觸藉由 macOS 系統內建的 InputMethodKit 當中的 IMKServer 傳來的 NSEvent 訊號資料流、而無須監聽系統全局鍵盤事件，也無須向使用者申請用以達成這類「可能會引發資安疑慮」的行為所需的輔助權限，更不會將您的電腦內的任何資料傳出去（本來就是這樣，且自唯音 2.3.0 版引入的 Sandbox 特性更杜絕了這種可能性）。請放心使用。Shift 中英模式切換功能要求至少 macOS 10.15 Catalina 才可以用。

## 系統需求

建置用系統需求：

- **Xcode 26.3+ (macOS 15.6+ required)** 或單獨安裝的 **Swift 6.2 open-source toolchain** + **macOS 26 SDK**。
    - 原因：Swift 6.2 成為必需版本（用於改進 concurrency 安全特性、SPM 6.2.4+ API 支援、CommandPlugin 改進等）。
- 請使用正式發行版 Xcode，且最小子版本號越高越好（因為 Bug 相對而言最少）。
    - 如果是某個大版本的 Xcode 的 Release Candidate 版本的話，我們可能會對此做相容性測試。

編譯出的成品對應系統需求：

- 至少 macOS 12 Monterey。
  - 如需要在更舊版的系統下運行的話，請前往[唯音輸入法主頁](https://vchewing.github.io/README.html)下載 Aqua 紀念版唯音輸入法，可支援自 macOS 10.9 開始至 macOS 12 Monterey 為止的系統版本。

- **推薦最低系統版本**：macOS 14 Sonoma。

  - 同時建議**系統記憶體應至少 4GB**。唯音輸入法佔用記憶體約 115MB 左右（簡繁雙模式）、75MB左右（單模式），供參考。
    - 請務必使用 SSD 硬碟，否則可能會影響每次開機之後輸入法首次載入的速度。從 10.10 Yosemite 開始，macOS 就已經是針對機械硬碟負優化的作業系統了。

- 關於全字庫支援，因下述事實而在理論上很難做到最完美：

  - 很可惜 GB18030-2005 並沒有官方提供的逐字讀音對照表，所以目前才用了全字庫。然而全字庫並不等於完美。
  - 有條件者可以安裝全字庫字型與花園明朝，否則全字庫等高萬國碼碼位漢字恐無法在輸入法的選字窗內完整顯示。
    - 全字庫漢字顯示支援會受到具體系統版本對萬國碼版本的支援的限制。
    - 有些全字庫漢字一開始會依賴萬國碼的私人造字區，且在之後被新版本萬國碼所支援。

## 建置流程

安裝 Xcode 之後，請先配置 Xcode 允許其直接構建在專案所在的資料夾下的 build 資料夾內。步驟：
```
「Xcode」->「Preferences...」->「Locations」；
「File」->「Project/WorkspaceSettings...」->「Advanced」；
選「Custom」->「Relative to Workspace」即可。不選的話，make 的過程會出錯。
```

在終端機內定位到唯音的克隆本地專案的本地倉庫的目錄之後，執行下列指令：

- `make update`：取得最新詞庫資源（使用遠端 Swift Package plugin）。
- `make release`：建置通用二進制版本（arm64 + x86_64），輸出至 `Build/Products/Release/`。
- `make archive`：建置通用版本並產生 `.xcarchive` 存檔（含 dSYM），存入 Xcode Archives 目錄。
- `make debug`：快速偵錯組建（單一架構）。

或者直接開啟 Xcode 專案，Product -> Scheme 選「vChewingInstaller」，編譯即可。

第一次安裝完之後，如有修改原廠辭典與程式碼的話，只要重覆上述流程重新安裝輸入法即可。

如果安裝若干次後，發現程式修改的結果並沒有出現、或甚至輸入法已無法再選用的話，請重新登入系統。

## 關於該倉庫的歷史記錄

該輸入法早於 4.1.3 版的記錄全部放在[vChewing-macOS-AncientArchive](https://github.com/vChewing/vChewing-macOS-AncientArchive)倉庫內。

## 應用授權

唯音輸入法 macOS 版以 MIT-NTL License 授權釋出 (與 MIT 相容)：© 2021-2022 vChewing 專案。

- 唯音輸入法 macOS 版程式維護：Shiki Suen。特別感謝 Isaac Xen 與 Hiraku Wong 等人的技術協力。
- 鐵恨注音並擊處理引擎：Shiki Suen (AGPL-3.0-or-later License)。
- 天權星語彙處理引擎：Shiki Suen (AGPL-3.0-or-later License)。
- 唯音詞庫（先鋒語料庫）由 Shiki Suen 維護，以 3-Clause BSD License 授權釋出。其中的詞頻資料[由 NAER 授權用於非商業用途](https://twitter.com/ShikiSuen/status/1479329302713831424)。

使用者可自由使用、散播本軟體，惟散播時必須完整保留版權聲明及軟體授權、且「一旦經過修改便不可以再繼續使用唯音的產品名稱」。換言之，這條相對上游 MIT 而言新增的規定就是：你 Fork 可以，但 Fork 成單獨發行的產品名稱時就必須修改產品名稱。

$ EOF.
