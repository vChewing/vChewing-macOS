# 威注音輸入法研發參與相關說明

威注音輸入法歡迎有熱心的志願者們參與。

威注音目前的 codebase 更能代表一個先進的 macOS 輸入法雛形專案的形態。目前的 dev 分支全都是清一色的 Swift codebase，一目了然，方便他人參與，比某些其它開源品牌旗下的專案更具程式方面的生命力。為什麼這樣講呢？那些傳統開源品牌的專案主要使用 C++ 這門不太友好的語言（Mandarin 模組現在對我而言仍舊是天書，一大堆針對記憶體指針的操作完全看不懂。搞不清楚在這一層之上的功能邏輯的話，就無法制定 Swift 版的 coding 策略），這也是我這次用 Swift 重寫了語言模型引擎與注音拼音並擊處理引擎、來換掉 Gramambular 與 OVMandarin 的原因（也是為後來者行方便）。

## 問題提報：

因技術原因，請默認本人無法接收來自任何「需要本人使用虛擬專用網路方可使用」的途徑的輸入法問題提報。

下述問題途徑可以用來提報與輸入法有關的問題：

- 大陸用戶請洽 Gitee 倉庫的工單區：https://gitee.com/vChewing/vChewing-macOS/issues
- 台澎金馬及海外用戶請洽 GitLab China 倉庫的工單區（可發起非公開工單）：https://jihulab.com/vChewing/vChewing-macOS/-/issues/
- 如果台澎金馬用戶無法註冊 Gitee 的話，請使用 GitLab China 的工單區。
  - 還可以使用電郵（理論上最快）：shikisuen◎yeah●net

### 我想在小麥注音的基礎上開發新功能，該怎麼開始？

首先，您得有 Swift 基礎、對設計模式（策略模式與狀態模式）與演算法都有一定的了解。無論是比較上層的使用體驗，還是比較底層的演算法，威注音都僅使用 Swift。

威注音倉庫內可能會在未來不久新增與程式架構有關的百科說明文章，但對鐵恨注拼引擎與天權星語彙引擎的架構說明則會擇日放入對應的倉庫的百科內。然而，書寫這些百科，需要花費時間精力。威注音相信專案內已有的針對函式的中文註解應該已經足夠了。

## 參與說明：

為了不讓參與者們浪費各自的熱情，特設此文以說明該專案目前最需要協助的地方。

1. 將選字窗換成 IMK 內建的矩陣選字窗。

除了上述各項以外的貢獻，除非特邀、或者有足夠的說服理由與吸引力（比如語法錯誤或更好的重構方法等），否則敝專案可能會無視或者拒絕。

請注意不要浪費自己的時間精力與感情，一定要在自己動工之前打個招呼。

如果您對威注音的產品功能發展另有所期的話，威注音雖不接受相關的爭論，但您可以自行建立分流專案。只需要遵守 MIT-NTL 協議、不沿用威注音的品牌名稱即可。

## 格式規範：

該專案對源碼格式有規範：

- Swift: 採 [Apple 官方 Swift-Format](https://github.com/apple/swift-format)，且施加如下例外修改項目：
	- `"indentSwitchCaseLabels" : true,`
	- `"lineLength" : 120,`
	- `"NoBlockComments" : false,`
    - `"OnlyOneTrailingClosureArgument" : false,` // SwiftUI 相容
    - `"UseTripleSlashForDocumentationComments" : false,`
    - `"DontRepeatTypeInStaticProperties" : false,`

之前，為了節省檔案體積，曾經對 Swift 檔案改採 1-Tab 縮進。然而，這會導致 Gitee 等線上 git 專案管理網站內的顯示變成 8-Space 縮進。於是，該專案對 Swift 檔案又改回了 2-Spaces 縮進。

$ EOF.
