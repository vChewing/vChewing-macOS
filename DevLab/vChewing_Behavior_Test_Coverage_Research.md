# 唯音（vChewing）行為功能與測試覆蓋研究

說明：本研究以軟體倉庫 vChewing-macOS 為準（主頁資料僅作導讀）。以下依「用戶行為 → 觸發功能」重新檢視 `InputHandler.triageInput` 與其委派函式，列出實際支援的行為並標註適合做單元測試的項目，再整理當前測試覆蓋現況與待補清單。

參考路徑（重點模組與測試）：
- Packages/vChewing_Typewriter/Sources/Typewriter/InputHandler/*
- Packages/vChewing_MainAssembly4Darwin/Sources/MainAssembly/SessionController/*
- 測試：
  - TypewriterTests: Packages/vChewing_Typewriter/Tests/TypewriterTests/*
  - MainAssemblyTests: Packages/vChewing_MainAssembly4Darwin/Tests/MainAssemblyTests/*
  - CandidateWindowTests、LangModelAssemblyTests 等輔助測試

---

## 1) 行為功能清單（依 InputHandler.triageInput 分層整理）

帶有 [錄放] 標記的項目需要真實錄製的 NSEvent 序列，否則難以在單元測試中重現條件。

A. 輸入模式與狀態切換
- Caps Lock 與 ASCII 模式的橋接：`handleCapsLockAndAlphanumericalMode` 會在 Caps Lock 亮起或處於 ASCII 模式時，依偏好清空組字區或遞交內容後回到 `.ofEmpty()`，再放行後續輸入。[適合測試][錄放]
- Symbol Menu 實體鍵（Intl/JIS）：`handlePunctuationList` 在無修飾與 Shift 下分別開啟主、副符號表；按住 Option 時呼叫 `revolveTypingMethod()`，在 `.vChewingFactory → .codePoint → .haninKeyboardSymbol` 三種模式間輪換。[適合測試]
- 漢音符號模式快捷鍵：當偏好 `classicHaninKeyboardSymbolModeShortcutEnabled` 為真且輸入 `¥` 或 `\`（無修飾），`revolveTypingMethod(to: .haninKeyboardSymbol)` 立即切換。[適合測試]
- TypingMethod 變換後，`revolveTypingMethod` 會提交既有組字內容並以受保護的 `.ofInputting` 狀態顯示提示，用以維持後續游標與工具提示一致性。

B. 組字流程
- Phonabet 組字：`handlePhonabetComposition` 覆蓋注音/拼音包含「先聲調後注音」覆寫、陰平處理、錯誤提示與逐字選字（SCPC）自動候選呼叫。[適合測試]
- Cassette 模式：`handleCassetteComposition` 支援 `%symboldef` 符號表、`%quick` 快速片語、萬用字元與自動最長鍵合成，並於候選狀態委派給 `handleCandidate`。[適合測試]
- 內碼輸入：`handleCodePointComposition` 維護 `strCodePointBuffer`，在 Option/Backspace 路徑回退、 Enter/Space 提交後回到 `.vChewingFactory`。[適合測試]
- 漢音符號模式：`handleHaninKeyboardSymbolModeInput` 接收模式內符號並依候選數量決定直接提交或顯示符號表。[適合測試]

C. 游標與選取（輸入中）
- 左右方向鍵：`handleBackward` / `handleForward` 逐字移動；按住 Option 改為節點跳躍，Option+Control 進一步映射到 Home/End；按住 Shift（可合併 Option/Command）則建立標記狀態。[適合測試]
- 上下方向鍵：在直排模式與橫排模式互換語意；若方向與排版垂直，`handleClockKey` 僅回報錯誤並保持狀態。[適合測試]
- Home / End：分別將游標移至組字區首尾（`handleHome`、`handleEnd`），同時保留組字內容。[適合測試]
- 候選輪替快捷：Tab、ContextMenu 鍵或在輸入狀態下的方向鍵+Option/Shift（由 triage 判斷）會呼叫 `revolveCandidate(reverseOrder:)` 執行就地輪替。[適合測試]
- Ctrl+Command(+Shift)+[]：於組字狀態下輪替當前節點候選，對應 `triageInput` 內的 bracket 分支。[適合測試]

D. 選字窗、符號表與服務選單
- 手動呼叫：`callCandidateState` 支援 Space（偏好開啟時）、PageUp/Down、Tab（偏好開啟時）與「時鐘方向」箭頭，並處理空組字或候選清單為空時的防呆。[適合測試]
- 候選窗導航：`handleCandidate` 對 Tab/Space/方向鍵/翻頁鍵做合乎偏好的高亮或換行，在橫排與直排情境下選擇上一/下一候選或上一/下一列。[適合測試]
- 游標與標記：候選窗內 Option 方向鍵執行節點跳轉，Option+Shift 逐步推進；Shift+方向鍵離開候選窗並進入標記狀態。[適合測試]
- 候選右鍵捷徑：Option+Command + `-` / `=` 直接呼叫 Nerf / Boost。若要進入 Filter，需以 Option+Command 搭配 Forward Delete（全尺寸鍵盤上的 Delete，或筆電上的 fn+Delete）；單靠 BackSpace 不會觸發這條路徑。這些熱鍵與滑鼠右鍵選單共用 `session.candidatePairRightClicked` 的邏輯。[適合測試]
- 取消邏輯：BackSpace / Esc / ForwardDelete / Shift+方向鍵 依狀態回復至 `.ofInputting` 或 `.ofAbortion`，若符號表仍有前節點則回退一層。[適合測試]
- 服務選單：Shift+`?` 或 Symbol Menu 實體鍵（含 Option/Shift 為逆向捲動）呼叫 `handleServiceMenuInitiation`，開啟 Unicode、Ruby、點字等資訊面板。[適合測試]
- 漢音符號表捷徑：符號表狀態下，Symbol Menu + Option 直接切換 TypingMethod 至 `.haninKeyboardSymbol`。
- 游標避讓：`generateStateOfCandidates` 於必要時呼叫 `dodgeInvalidEdgeCursorForCandidateState`，確保游標落在有效節點範圍內。

E. 逐字選字與關聯詞語
- `revolveCandidate`、`consolidateNode` 與 `retrievePOMSuggestions` 協同處理就地固詞與 POM 觀察，並依偏好推進或復原游標。
- Shift+Enter（非 SCPC）或自動提交後，`handleEnter` / `generateStateOfAssociates` 會根據候選讀音生成 `.ofAssociates` 狀態；SCPC 模式於候選僅剩一筆時直接提交同步觸發關聯詞。[適合測試]

F. Enter / BackSpace / Delete / Esc
- Enter：支援純提交、Option+Shift 加入空格、Ctrl+Command(+Option) 進行讀音/點字/HTML Ruby 輸出，以及在 Cassette 或 CodePoint 模式中退回主模式。[適合測試]
- BackSpace / Delete：`handleBackSpace`、`handleDelete` 支援逐字刪除、Option 節點刪除、Shift 特殊偏好、CodePoint 緩衝區回退與 Cassette wildcard 清空。[適合測試]
- Esc：依 `prefs.escToCleanInputBuffer` 決定清空或提交組字內容，否則僅清除 composer/calligrapher；在其他 TypingMethod 下會先回到 `.vChewingFactory`。[適合測試]

G. 標點、數字與其他按鍵
- `handlePunctuation` 與 `punctuationQueryStrings` 依佈局、修飾鍵映射標點；逐字選字模式下會在單一候選時直接提交。[適合測試]
- Option+數字（主鍵盤）：`handleArabicNumeralInputs` 決定半形/全形輸出；Shift 版本反轉寬度。[適合測試]
- NumPad：`handleNumPadKeyInput` 依偏好值（0~5）決定提交、切換全半形或改走標點表，並清除組字狀態避免殘留。[適合測試]
- Shift+字母：`handleLettersWithShiftHold` 依偏好 1~4 決定直接提交大小寫或保持於組字區，並在 SCPC 下與標點處理互動。[適合測試]

H. 標記狀態
- Shift+方向鍵建構/縮減選區，Option/Command 結合 Shift 以節點為界移動 marker。
- Enter（含 Shift+Command）在 `.ofMarking` 中呼叫 `performUserPhraseOperation` 進行新增、升權、降權或解除過濾；BackSpace / Delete 則標記過濾並透過 tooltip 回饋結果。[適合測試]

I. 其他保護邏輯
- `commitOverflownComposition` 限制黑名單 App 的組字長度。
- 在組字狀態仍有內容時，`triageInput` 結尾會阻擋未知按鍵並回報 `A9BFF20E`，避免 F1~F12 等干擾組字區。

---

## 2) 適合訂做單元測試的功能（標註重點）

原則：

1. 只要可由 `KBEvent` / `NSEvent` 模擬且結果純邏輯可驗證者，皆適合寫成單元測試。上節凡標註「[適合測試]」的項目即為候選；輸入流程核心（InputHandler / SessionCtl）優先。
2. 涉及 Modifier 單擊偵測（如 CapsLock 通知、Shift-Eisu）必須蒐集一套 Raw Events 才能在單元測試重現，因此標記為 [錄放]。

---

## 3) 現有測試覆蓋與待補清單

已覆蓋（摘錄）：
- TypewriterTests IH101~106、IH107~109、IH111：基本組句、逐字選字、Cassette `%quick`、CodePoint、讀音/註記/點字提交以及 POM 觀察。
- CandidateServiceCoordinatorTests：驗證服務選單內容與對應 selector。
- MainAssemblyTests_Test2：
  - 201 覆蓋 Home/End 與 clock keys；202 覆蓋 ESC 偏好兩路徑；203 覆蓋 BackSpace / Delete 各分支與 CodePoint 回退。
  - 205 驗證標點鍵與符號表（含漢音符號模式）；206 覆蓋主鍵盤 Option 數字；207 覆蓋 NumPad 偏好 0~5；208 覆蓋 Shift+字母偏好 1~4。
  - 209 覆蓋候選窗取消、游標移動、Option+Command Nerf/Boost/Filter 快捷；210 驗證服務選單鍵觸發；211 驗證手動呼叫選字窗。
  - 213 驗證候選預覽即時更新；214 驗證 `dodgeInvalidEdgeCursorForCandidateState`；215–216 覆蓋關聯詞語觸發（逐字選字模式 / 非逐字模式）。

尚未覆蓋（建議優先於 MainAssemblyTests 補齊）：
1. Caps Lock 通知與 Shift-Eisu 聯動（SessionCtl.handleKeyDown CapsLock 區段）。[錄放]
   - 需 flagsChanged 原始事件重播，模擬通知開關與 Shift 互動。
2. JIS 英數鍵切換（SessionCtl.handleKeyDown）。[錄放]
   - 應返回 true 並切換英數模式（Photoshop 相容行為）。
3. Emacs 按鍵轉換及動態拉丁佈局轉換（SessionCtl.handleKeyDown）。[錄放]
   - 需錄製對應 Raw NSEvent 來驗證 triage 流程。

---

完。