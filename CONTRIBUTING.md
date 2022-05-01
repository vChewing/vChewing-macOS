# 威注音輸入法研發參與相關說明

威注音輸入法歡迎有熱心的志願者們參與。

威注音目前的 codebase 更能代表一個先進的 macOS 輸入法雛形專案的形態。目前的 dev 分支除了 Mandarin 模組（以及其與 KeyHandler 的對接的部分）以外被威注音使用的部分全都是清一色的 Swift codebase，一目了然，方便他人參與，比某些其它開源品牌旗下的專案更具程式方面的生命力。為什麼這樣講呢？那些傳統開源品牌的專案主要使用 C++ 這門不太友好的語言（Mandarin 模組現在對我而言仍舊是天書，一大堆針對記憶體指針的操作完全看不懂。搞不清楚在這一層之上的功能邏輯的話，就無法制定 Swift 版的 coding 策略），這也是我這次用 Swift 重寫了語言模型引擎的原因（也是為後來者行方便）。

為了不讓參與者們浪費各自的熱情，特設此文以說明該專案目前最需要協助的地方。

1. 有人能用 Swift 將該專案內的這個源自 LibFormosa 的組件套件重寫：
	- Mandarin 組件，用以分析普通話音韻數據、創建且控制 Syllable Composer 注音拼識組件。
		- 一堆記憶體指針操作，實在看不懂這個組件的處理邏輯是什麼，無能為力。
2. 讓 Alt+波浪鍵選單能夠在諸如 MS Word 以及終端機內正常工作（可以用方向鍵控制高亮候選內容，等）。
		- 原理上而言恐怕得欺騙當前正在接受輸入的應用、使其誤以為當前有組字區。這只是推測。
3. SQLite 實現。


除了上述各項以外的貢獻，除非特邀、或者有足夠的說服理由與吸引力（比如語法錯誤或更好的重構方法等），否則敝專案可能會無視或者拒絕。

請注意不要浪費自己的時間精力與感情，一定要在自己動工之前打個招呼。

如果您對威注音的產品功能發展另有所期的話，威注音雖不接受相關的爭論，但您可以自行建立分流專案。只需要遵守 MIT-NTL 協議、不沿用威注音的品牌名稱即可。

## 格式規範：

該專案對源碼格式有規範，且 Swift 與其他 (Obj)C(++) 系語言持不同規範：

- Swift: 採 [Apple 官方 Swift-Format](https://github.com/apple/swift-format)，且施加如下例外修改項目：
	- Indentation 僅使用 `"indentation" : {     "tabs" : 1   },`，不以空格來縮進。
	- `"indentSwitchCaseLabels" : true,`
	- `"lineLength" : 120,`
	- `"NoBlockComments" : false,`
	- `"tabWidth" : 4,`
    - `"OnlyOneTrailingClosureArgument" : false,` // SwiftUI 相容
    - `"UseTripleSlashForDocumentationComments" : false,`
    - `"DontRepeatTypeInStaticProperties" : false,`
- (Obj)C(++) 系語言：使用 clang-format 命令、且採 Microsoft 行文規範。
	- 該規範以四個西文半形空格為行縮進單位。
	- 由於今後不會再用這類語言給該倉庫新增內容，所以相關規範就不改動了。

至於對 Swift 檔案改採 1-Tab 縮進，則是為了在尊重所有用戶的需求的同時、最大程度上節約檔案體積。使用者可自行修改 Xcode 的預設 Tab 縮進尺寸。

$ EOF.
