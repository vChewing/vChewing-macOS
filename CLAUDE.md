# CLAUDE.md

Guidance for Claude-family coding agents working on the vChewing (唯音) macOS repository. Treat `AGENTS.md` as canonical for architecture and workflow; align with `.github/copilot-instructions.md` for shared guardrails. Use only English or zh-Hant-TW in documentation/comments/reviews; zh-Hans is allowed only in filename stems ending with -CHS.

## Quick Checklist

- **Language**：Documentation、comments、reviews 僅能使用 English 或 zh-Hant-TW（檔名結尾 `-CHS` 可用 zh-Hans）。尤其注意中文資訊電子術語必須得是 zh-Hant-TW。
- **Commits**：遵循 `ModuleName // SubModuleName: Change.` 的 Conventional Commit 風格。
- **Scope**：主要工作區位於 `Packages/`。Linux 環境僅構建 `vChewing_Typewriter` 與其依賴。macOS 構建使用 `Package.swift` + `Makefile` + `BundleApps` CommandPlugin。
- **UI 規範**：所有視窗使用 `vChewing_OSFrameworkImpl` 的 AppKit Result Builder DSL，不得引入 Interface Builder 資產。
- **FSM 流程**：維持 `SessionCtl → InputSession → InputHandler (→ Megrez) → IMEState` 流程；新增 API 時先更新協定。
- **Lexicon**：詞庫資源由遠端 Swift Package plugin `VanguardSQLLegacyPlugin`（來自 `vChewing-VanguardLexicon` 倉庫）提供，構建時動態注入至 `vChewing_MainAssembly4Darwin`；編譯後的成品為暫時構建產物，不應簽入版控。
- **ObjC(++)/C(++) 風格**：Objective-C(++) 與 C(++) 原始碼請遵守 Google Style Guide 的格式規範。
- **使用者資料路徑**：除非是 Swift Package 的測試目標所需，請勿在程式中寫死使用者資料路徑。

## Entry Points

- `Packages/vChewing_MainAssembly4Darwin/.../SessionController/SessionCtl.swift`：IMK 入口；處理事件、更新 UI。
- `Packages/vChewing_MainAssembly4Darwin/.../LangModelManager/BundleAccessor.swift`：自訂 `Bundle.currentSPM` 查詢器，用於定位 factory 詞庫資源。
- `Packages/vChewing_Typewriter/Sources/Typewriter/InputHandler/`：FSM 實作、Tekkon/Megrez 橋接。
- `Packages/vChewing_Tekkon/Sources/Tekkon/`：注音/拼音解析、組筆處理。
- `Packages/vChewing_Megrez/Sources/Megrez/`：DAG-DP 組句器，兼任 POM 觀測資料生成器。
- `Packages/vChewing_LangModelAssembly/Sources/LangModelAssembly/`：語言模型匯流、使用者詞語、關聯詞、POM 記憶管理。

## Testing & Tooling

- 針對變更的 package 執行 `swift test`；對 Tekkon/Megrez 相關改動請補齊邊界案例。
- 偏好 (PrefMgr) 相關測試需在測試前後還原設定，避免滲漏。
- 若新增可視化或除錯輸出，透過偏好旗標控制，避免影響 Release 組建。

## Docs to Read First

- `AGENTS.md`：完整開發守則。
- `algorithm.md`：Tekkon、Megrez、語言模型、詞庫製程的詳細說明（zh-Hant）。
- `.github/copilot-instructions.md`：Copilot/Claude 共用的即時守則。

遵守以上規範能確保與維護者協作順暢。如遇到與守則衝突的新需求，請在 PR 說明內註記並提出調整建議。