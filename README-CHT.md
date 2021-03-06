語言：[简体中文](./README.md) | *繁體中文*

僅以此 README 紀念祁建華 (CHIEN-HUA CHI, 1921-2001)。

---

因不可控原因，該倉庫只能保證在 Gitee 有最新的內容可用：

- 下載：https://gitee.com/vchewing/vChewing-macOS/releases
- 程式碼倉庫：https://gitee.com/vchewing/vChewing-macOS

# vChewing 威注音輸入法

威注音輸入法基於小麥注音二次開發，是**原生簡體中文、原生繁體中文注音輸入法**：

- 威注音是業界現階段支援注音排列種類數量與輸入用拼音種類數量最多的注音輸入法。
  - 受威注音自家的鐵恨注音並擊引擎加持。
- 威注音的原廠詞庫內不存在任何可以妨礙該輸入法在世界上任何地方傳播的內容。
- 相比中州韻（鼠須管）而言，威注音能夠做到真正的大千聲韻並擊。
- 擁有拼音並擊模式，不懂注音的人群也可以受益於該輸入法所帶來的穩定的平均輸入速度。
  - 相比小鶴雙拼等雙拼方案而言，威注音雙手聲韻分工明確、且重碼率只有雙拼的五分之一。
- 威注音對陸規審音完全相容：不熟悉台澎金馬審音的大陸用戶不會遇到與漢字讀音有關的不便。
  - 反之亦然。

>威注音有很多特色功能。在此僅列舉部分：
>- 支援 macOS 螢幕模擬鍵盤（僅傳統大千與傳統倚天佈局）。
>- 可以將自己打的繁體中文自動轉成日本 JIS 新字體來輸出（包括基礎的字詞轉換）、也可以轉成康熙繁體來輸出。
>- 簡繁體中文語料庫彼此分離，徹底杜絕任何繁簡轉換過程可能造成的失誤。
>- 支援近年的全字庫漢字輸入。
>- 可以自動整理使用者語彙檔案格式、自訂聯想詞。
>- ……

威注音分支專案及威注音詞庫由孫志貴（Shiki Suen）維護，其內容屬於可在 Gitee 公開展示的合法內容。小麥注音官方原始倉庫內的詞庫的內容均與孫志貴無關。

## 系統需求

建置用系統需求：

- 至少 macOS 12 Monterey & Xcode 13.4.1。
    - 原因：Swift 封包管理支援與 Swift 5.5 所需，且倉庫內包含了需要 Xcode 13.4.1 才能正常編譯的內容（App 型安裝程式）。
    - 我們已經沒有條件測試比 Xcode 13.4.1 更老的環境了。硬要在這個環境下編譯的話，可能需要額外安裝[新版 Swift](https://www.swift.org/download/) 才可以。
- 請使用正式發行版 Xcode，且最小子版本號越高越好（因為 Bug 相對而言最少）。
    - 如果是某個大版本的 Xcode 的 Release Candidate 版本的話，我們可能會對此做相容性測試。

編譯出的成品對應系統需求：

- 至少 macOS El Capitan 10.11.5，否則無法處理 Unicode 8.0 的漢字。即便如此，仍需手動升級蘋方至至少 macOS 10.12 開始隨贈的版本、以支援 Unicode 8.0 的通用規範漢字表用字（全字庫沒有「𫫇」字）。
  - 保留該系統支援的原因：非 Unibody 機種的 MacBook Pro 支援的最後一版 macOS 就是 El Capitan。

- **推薦最低系統版本**：macOS 10.12 Sierra，對 Unicode 8.0 開始的《通用規範漢字表》漢字有原生的蘋方支援。

  - 同時建議**系統記憶體應至少 4GB**。威注音輸入法佔用記憶體約 115MB 左右（簡繁雙模式）、75MB左右（單模式），供參考。
    - 請務必使用 SSD 硬碟，否則可能會影響每次開機之後輸入法首次載入的速度。從 10.10 Yosemite 開始，macOS 就已經是針對機械硬碟負優化的作業系統了。
    - 注：能裝 macOS 10.13 High Sierra 就不要去碰 macOS 10.12 Sierra 這個半成品。

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
在終端機內定位到威注音的克隆本地專案的本地倉庫的目錄之後，執行 `make update` 以獲取最新詞庫。

接下來就是直接開 Xcode 專案，Product -> Scheme 選「vChewingInstaller」，編譯即可。

> 之前說「在成功之後執行 `make` 即可組建、再執行 `make install` 可以觸發威注音的安裝程式」，這對新版威注音而言**當且僅當**使用純 Swift 編譯腳本工序時方可使用。目前的 libvchewing-data 模組已經針對 macOS 版威注音實裝了純 Swift 詞庫編譯腳本。

第一次安裝完，日後程式碼或詞庫有任何修改，只要重覆上述流程，再次安裝威注音即可。

要注意的是 macOS 可能會限制同一次 login session 能終結同一個輸入法的執行進程的次數（安裝程式透過 kill input method process 來讓新版的輸入法生效）。如果安裝若干次後，發現程式修改的結果並沒有出現、或甚至輸入法已無法再選用，只需要登出目前的 macOS 系統帳號、再重新登入即可。

補記: 該輸入法是在 2021 年 11 月初「28ae7deb4092f067539cff600397292e66a5dd56」這一版小麥注音建置的基礎上完成的。因為在清洗詞庫的時候清洗了全部的 git commit 歷史，所以無法自動從小麥注音官方倉庫上游繼承任何改動，只能手動同步任何在此之後的程式修正。最近一次同步參照是上游主倉庫的 2.2.2 版、以及 zonble 的分支「5cb6819e132a02bbcba77dbf083ada418750dab7」。

## 應用授權

威注音專案僅用到小麥注音的下述程式組件（MIT License）：

- 狀態管理引擎 & NSStringUtils & FSEventStreamHelper (by Zonble Yang)，基於狀態設計模式：
  - ctlInputMethod 輸入法主控制器內則採用策略設計模式來處理各種狀態。
- 半衰記憶模組的 C++ 原版作者是 Mengjuei Hsieh，且由 Shiki Suen 用 Swift 與 C# 分別重寫、繼續開發。
- 僅供研發人員調試方便而使用的 App 版安裝程式 (by Zonble Yang)，不對公眾使用。
- Voltaire MK2 選字窗、飄雲通知視窗、工具提示 (by Zonble Yang)，有大幅度修改。

威注音輸入法 macOS 版以 MIT-NTL License 授權釋出 (與 MIT 相容)：© 2021-2022 vChewing 專案。

- 威注音輸入法 macOS 版程式維護：Shiki Suen。特別感謝 Isaac Xen 與 Hiraku Wong 等人的技術協力。
- 鐵恨注音並擊處理引擎：Shiki Suen (MIT-NTL License)。
- 天權星語彙處理引擎：Shiki Suen (MIT-NTL License)。
- 威注音詞庫由 Shiki Suen 維護，以 3-Clause BSD License 授權釋出。其中的詞頻數據[由 NAER 授權用於非商業用途](https://twitter.com/ShikiSuen/status/1479329302713831424)。

使用者可自由使用、散播本軟體，惟散播時必須完整保留版權聲明及軟體授權、且一旦經過修改便不可以再繼續使用威注音的產品名稱。

## 資料來源

原廠詞庫主要詞語資料來源：

- 《重編國語辭典修訂本 2015》的六字以內的詞語資料 (CC BY-ND 3.0)。
- 《CNS11643中文標準交換碼全字庫(簡稱全字庫)》 (OGDv1 License)。
- LibTaBE (by Pai-Hsiang Hsiao under 3-Clause BSD License)。
- [《新加坡華語資料庫》](https://www.languagecouncils.sg/mandarin/ch/learning-resources/singaporean-mandarin-database)。
- 原始詞頻資料取自 NAER，有經過換算處理與按需調整。
    - 威注音並未使用由 LibTaBE 內建的來自 Sinica 語料庫的詞頻資料。
- 威注音語彙庫作者自行維護新增的詞語資料，包括：
    - 盡可能所有字詞的陸規審音與齊鐵恨廣播讀音。
    - 中國大陸常用資訊電子術語等常用語，以確保簡體中文母語者在使用輸入法時不會受到審音差異的困擾。
- 其他使用者建議收錄的資料。

## 參與研發時的注意事項

歡迎參與威注音的研發。論及相關細則，請洽該倉庫內的「[CONTRIBUTING.md](./CONTRIBUTING.md)」檔案、以及《[常見問題解答](./FAQ.md)》。

敝專案採用了《[貢獻者品行準則承約書 v2.1](./code-of-conduct.md)》。考慮到上游鏈接給出的中文版翻譯與英文原文嚴重不符合的情況（會出現因執法與被執法雙方的認知偏差導致的矛盾，非常容易變成敵我矛盾），敝專案使用了自行翻譯的版本、且新增了一些能促進雙方共識的註解。

$ EOF.
