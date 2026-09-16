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
>- 可以自動整理使用者片語檔案格式、自訂關聯詞語。
>- ……

唯音分支專案及唯音詞庫（先鋒語料庫）由孫志貴（Shiki Suen）維護，其內容屬於可在 Gitee 公開展示的合法內容。但這些內容在被整理收入先鋒語料庫之前的原始資料的合規性不屬於維護者的負責範圍之內。

> 資安宣告：唯音輸入法的 Shift 按鍵監測功能僅藉由對 NSEvent 訊號資料流的上下文關係的觀測來實現，僅接觸藉由 macOS 系統內建的 InputMethodKit 當中的 IMKServer 傳來的 NSEvent 訊號資料流、而無須監聽系統全局鍵盤事件，也無須向使用者申請用以達成這類「可能會引發資安疑慮」的行為所需的輔助權限，更不會將您的電腦內的任何資料傳出去（本來就是這樣，且自唯音 2.3.0 版引入的 Sandbox 特性更杜絕了這種可能性）。請放心使用。Shift 中英模式切換功能要求至少 macOS 10.15 Catalina 才可以用。

## 系統需求

建置用系統需求：

- **Swift 6.4 以上是硬性下限**。取得方式二選一：
    - **Xcode 27+**（需 macOS 26.6 以上）；或
    - **Xcode 26.x**（Intel Mac 能用的最後一代）＋ 另裝 **Swift 6.4+ open-source toolchain**。
    - 注意：**Xcode 無法用另裝的 open-source toolchain 來解讀 Swift Package**——它的套件解析固定用自己內建的 toolchain。故在 Intel Mac（Xcode 上限 26.x、內建 Swift < 6.4）上，**本倉已無法再用 Xcode 建置**，只能以 SwiftPM 命令列（`make spmDebug`／`make release` 一類，配 6.4+ toolchain）建置；Apple silicon 不受影響。
    - 原因：Swift 6.x **僅支援 6.4 以上**。6.2／6.3 已由倉庫內的封堵 manifest（`Package@swift-6.2.swift`／`Package@swift-6.3.swift`）**明文拒絕建置**：該兩版會對 default-isolated 的下游遵循上游協定一事強制索求明文 `@MainActor`（`#ConformanceIsolation`），本倉的依賴閉包在該兩版下不存在可用的產物形態。
    - 另裝 toolchain 時，SDK 的世代搭配要對：Xcode 27 自帶的 macOS 27 SDK 內含只用得了 6.4 以上編譯器的 `.swiftinterface`，故不可拿 6.2／6.3 系 toolchain 去配它。
- 請使用正式發行版 Xcode，且最小子版本號越高越好（因為 Bug 相對而言最少）。
    - 如果是某個大版本的 Xcode 的 Release Candidate 版本的話，我們可能會對此做相容性測試。
- **（選用）建置 legacy 產物**：若需自行產生 macOS 10.9～10.10 的安裝包，另需 **Xcode 15** ＋ **`MacOSX13.3.sdk`** ＋ **Swift 5.10.1 open-source toolchain**，並以 `make debugLegacy`／`make releaseLegacy` 驅動。此路徑僅供本機使用、**不納入 CI**。
    - 該 SDK **不是 Xcode 15 內建的**（Xcode 15 自帶的是 macOS 14 系），取得方式是安裝 **macOS 13.3 的 Command Line Tools**（`/Library/Developer/CommandLineTools/SDKs/MacOSX13.3.sdk`），再置入 Xcode 15 的平臺目錄。
- **想在 macOS 27 之前的系統上以 Swift 6.4+ 編譯**（例如末代 Intel MacBook Pro 13-inch）：請注意，**「讓當前 shell 自動用上 Swift 6.4+ open-source toolchain」是您自己的責任**。官方推出的 **Swiftly** 是一條可行路徑，但它的 shell 環境配置相當繁瑣，且會把原本裝在系統根目錄的 FOSS toolchain 全部改成裝進您的 user-space——至少在 macOS 26 上這是能用的選擇。若您的電腦最高只能跑到 macOS 15，Swiftly 可能無法把 toolchain 裝進 user-space，此時只能以系統管理員權限、手動將官方發行的 toolchain `.dmg`／`.pkg` 安裝到系統根目錄；如此一來，您可能得按自身需求改動本倉的 `makefile`。這些瑣碎事務在當今是可以交給 LLM 打點的，但便利與風險並存，請自行斟酌。
- **本倉庫不提供 `build640` 這類「鎖定 Swift 版本號」的建置入口**：Swift 每發一版就得回頭把所有 `makefile` 修一遍，得不償失。建置入口一律以「當前 shell 的 `swift`」為準。

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

唯音輸入法 macOS 版以木蘭寬鬆授權條款第 2 版（MulanPSL-2.0）授權釋出：© 2021-2022 vChewing 專案。全文見 `./LICENSE.txt`。

- 唯音輸入法 macOS 版程式維護：Shiki Suen。特別感謝 Isaac Xen 與 Hiraku Wong 等人對唯音輸入法 1.x 早期版本的技術協力。
- 鐵恨注音並擊處理引擎：Shiki Suen (LGPL v3.0 or later, with Swift App Development exception)。
- 護摩組句引擎（Homa）：Shiki Suen (LGPL v3.0 or later, with Swift App Development exception)。
- 唯音詞庫（先鋒語料庫）由 Shiki Suen 維護，以木蘭寬鬆授權條款第 2 版（MulanPSL-2.0）授權釋出。其中的詞頻資料[由 NAER 授權用於非商業用途](https://twitter.com/ShikiSuen/status/1479329302713831424)。

> 自 2026 年 04 月下旬，本倉庫的組句引擎已由天權星（Megrez）遷移為敝專案自研先鋒引擎套件 LibVanguard 當中的護摩（Homa）。Homa 元件本身以 LGPL v3.0 or later 授權釋出，且附帶與 Swift App Development 情境的額外許可；詳見 `./Packages/vChewing_OSNeutral_LibVanguard/LICENSES/Homa-CUSTOM_LGPLv3_EXCEPTION.md` 與 `./Packages/vChewing_OSNeutral_LibVanguard/LICENSES/Homa-LICENSE.txt`。

使用者可自由使用、散播本軟體，惟散播時必須完整保留版權聲明及軟體授權、且「一旦經過修改便不可以再繼續使用唯音的產品名稱」。木蘭寬鬆授權條款第 2 版特示：一是第 3 條的商標不許可規定（你 Fork 可以，但 Fork 成單獨發行的產品名稱時就必須修改產品名稱）；二是專利授權與專利訴訟反制條款。詳見全文。

$ EOF.
