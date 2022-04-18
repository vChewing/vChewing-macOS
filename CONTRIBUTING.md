# 威注音輸入法研發參與相關說明

威注音輸入法歡迎有人參與。但為了不讓參與者們浪費各自的熱情，特設此文以說明該專案目前最需要協助的地方。

1. 有人能用 Swift 將該專案內這兩個源自 LibFormosa 的組件套件重寫：
	- Mandarin 組件，用以分析普通話音韻數據、創建且控制 Syllable Composer 注音拼識組件。
	- Gramambular 套裝，這包括了 Source 資料夾下的其餘全部的 (Obj)C(++) 檔案（LMConsolidator 除外）。
		- LMConsolidator 有 Swift 版本，已經用於威注音語彙編輯器內。給主程式用 C++ 版本僅為了與 Gramambular 協作方便。
		- 這也包括了所有與 Language Model 有關的實現，因為都是 Gramambular 內的某個語言模組 Protocol 衍生出來的東西。
		- LMInstantiator 是用來將語言模組副本化的組件，原本不屬於 Gramambular，但與其衍生的各類語言模組高度耦合。
		- KeyValueBlobReader 不屬於 Gramambular，但與其衍生的各類語言模組高度耦合、也與 KeyHandler 高度耦合。
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