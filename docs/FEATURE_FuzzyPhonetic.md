# Feature Spec: 擴充近似音設定 (Extended Fuzzy Phonetic Settings)

> **適用專案**：ThomasHsieh/vChewing-macOS（fork 自 vChewing/vChewing-macOS）  
> **參考來源**：McBopomofo 近似音設定介面（截圖）、vChewing 現有 ㄣ/ㄥ 容錯實作  
> **目標模組**：`vChewing_Shared`（UserDef/PrefMgr）、`vChewing_LangModelAssembly`（查詢層）、`vChewing_MainAssembly4Darwin`（設定 UI）  
> **功能定位**：將現有單一的 ㄣ/ㄥ 容錯開關擴充為多組獨立可設定的近似音規則，預設全部關閉

---

## 1. 功能概述

### 1.1 現有狀態

vChewing 目前在「一般設定」中有一個單一開關：

> **啟用ㄣ/ㄥ容錯輸入（前後鼻音不分）**  
> 啟用後，輸入「ㄣ」時也會找到「ㄥ」的候選字，反之亦然。

本功能將此機制**擴充**為多組獨立的近似音規則，使用者可以按照自己的發音習慣，個別勾選需要的容錯組合。

### 1.2 設計原則

- **現有的 ㄣ/ㄥ 開關保留**，作為其中一個選項遷移進新的設定區塊
- **預設全部關閉**（包含原本預設開啟的 ㄣ/ㄥ）— 遷移時需注意向下相容
- **向下相容**：若使用者原本已啟用 ㄣ/ㄥ，遷移後該選項應維持開啟
- 各規則**完全獨立**，可自由組合勾選

---

## 2. 近似音規則清單

### 2.1 聲母近似音（Fuzzy Initials）

| 規則 ID | 近似音對 | 說明 | McBopomofo 截圖 | 預設 |
|---------|---------|------|----------------|------|
| `fuzzyInitial_BP` | ㄅ ↔ ㄆ | 雙唇音送氣不分 | 未勾選 | 關閉 |
| `fuzzyInitial_FH` | ㄈ ↔ ㄏ | 唇齒音與喉音混淆 | 未勾選 | 關閉 |
| `fuzzyInitial_LN` | ㄌ ↔ ㄋ | 邊音與鼻音混淆 | 未勾選 | 關閉 |
| `fuzzyInitial_ZZh` | ㄗ ↔ ㄓ | 平舌↔捲舌 | ✅ 勾選 | 關閉 |
| `fuzzyInitial_CCh` | ㄘ ↔ ㄔ | 平舌↔捲舌 | ✅ 勾選 | 關閉 |
| `fuzzyInitial_SSh` | ㄙ ↔ ㄕ | 平舌↔捲舌 | ✅ 勾選 | 關閉 |

### 2.2 韻母近似音（Fuzzy Finals）

| 規則 ID | 近似音對 | 說明 | McBopomofo 截圖 | 預設 |
|---------|---------|------|----------------|------|
| `fuzzyFinal_EnEng` | ㄣ ↔ ㄥ | 前後鼻音（現有功能遷移） | ✅ 勾選 | 關閉 |
| `fuzzyFinal_InIng` | ㄧㄣ ↔ ㄧㄥ | 前後鼻音（帶介音ㄧ） | （推測，截圖右下） | 關閉 |

> **備註**：McBopomofo 截圖中韻母欄右側第二個選項因解析度限制不清晰，依近音表規格書中的確認資料（ㄨㄣ↔ㄨㄥ 也是有效近音對），agent 實作時請同時參考近音表規格書（`FEATURE_SimilarPhonetic.md`）的韻母近音對照表，確認完整清單。

**近音表規格書中確認的完整韻母近音對供參考**：

| 規則 ID | 近似音對 | 說明 |
|---------|---------|------|
| `fuzzyFinal_EnEng` | ㄣ ↔ ㄥ | 前後鼻音 |
| `fuzzyFinal_AnAng` | ㄢ ↔ ㄤ | 前後鼻音 |
| `fuzzyFinal_InIng` | ㄧㄣ ↔ ㄧㄥ | 前後鼻音（帶介音ㄧ） |
| `fuzzyFinal_UnUng` | ㄨㄣ ↔ ㄨㄥ | 前後鼻音（帶介音ㄨ） |

> **UI 呈現取捨**：可依 McBopomofo 截圖只顯示 ㄣ↔ㄥ 和 ㄌ↔ㄇ 兩個，或顯示全部四個韻母組。建議**顯示全部四個**，讓使用者有更細緻的控制。

---

## 3. 設定 UI 規格

### 3.1 UI 位置

**方案 A（建議）**：在「一般設定」頁面，將現有的「啟用ㄣ/ㄥ容錯輸入」開關替換為一個可展開的「近似音設定」區塊。

**方案 B**：新增一個獨立的「近似音」子頁面（類似 McBopomofo 的進階設定）。

### 3.2 UI 佈局（參考 McBopomofo 截圖）

```
┌─────────────────────────────────────────────────────┐
│ ☑ 使用近似音                                         │
│                                                     │
│  聲母                    韻母                        │
│  □ ㄅ ↔ ㄆ              ☑ ㄣ ↔ ㄥ                   │
│  □ ㄈ ↔ ㄏ              □ ㄢ ↔ ㄤ                   │
│  □ ㄌ ↔ ㄋ              □ ㄧㄣ ↔ ㄧㄥ               │
│  ☑ ㄗ ↔ ㄓ              □ ㄨㄣ ↔ ㄨㄥ               │
│  ☑ ㄘ ↔ ㄔ                                          │
│  ☑ ㄙ ↔ ㄕ                                          │
└─────────────────────────────────────────────────────┘
```

**UI 行為**：
- 「使用近似音」總開關關閉時，下方所有子選項灰化（disabled），但記憶各子項的勾選狀態
- 總開關開啟時，子選項依各自狀態生效
- 子選項排列：聲母在左欄（6 項），韻母在右欄（4 項）

### 3.3 現有 ㄣ/ㄥ 開關的遷移

現有的獨立開關「啟用ㄣ/ㄥ容錯輸入（前後鼻音不分）」應在此次更新中**移除**，功能合併至新的近似音設定區塊中的 `fuzzyFinal_EnEng` 選項。

**向下相容邏輯**：

```swift
// 首次啟動新版本時的遷移
if UserDefaults.standard.object(forKey: "fuzzyFinalEnEng") == nil {
    // 若舊開關曾被使用者開啟，遷移到新設定
    let legacyValue = PrefMgr.shared.legacyFuzzyEnEng  // 舊的 UserDef key
    PrefMgr.shared.fuzzyFinalEnEng = legacyValue
    // 若舊開關開啟，總開關也應自動開啟
    if legacyValue { PrefMgr.shared.fuzzyPhoneticEnabled = true }
}
```

---

## 4. 偏好設定鍵值

在 `UserDef` 新增以下項目，並對應更新 `PrefMgrProtocol` 與 `PrefMgr`：

### 4.1 總開關

| UserDef Key | 型別 | 預設值 | 說明 |
|-------------|------|--------|------|
| `fuzzyPhoneticEnabled` | `Bool` | `false` | 是否啟用近似音功能（總開關） |

### 4.2 聲母近似音

| UserDef Key | 型別 | 預設值 | 對應規則 |
|-------------|------|--------|---------|
| `fuzzyInitialBP` | `Bool` | `false` | ㄅ ↔ ㄆ |
| `fuzzyInitialFH` | `Bool` | `false` | ㄈ ↔ ㄏ |
| `fuzzyInitialLN` | `Bool` | `false` | ㄌ ↔ ㄋ |
| `fuzzyInitialZZh` | `Bool` | `false` | ㄗ ↔ ㄓ |
| `fuzzyInitialCCh` | `Bool` | `false` | ㄘ ↔ ㄔ |
| `fuzzyInitialSSh` | `Bool` | `false` | ㄙ ↔ ㄕ |

### 4.3 韻母近似音

| UserDef Key | 型別 | 預設值 | 對應規則 |
|-------------|------|--------|---------|
| `fuzzyFinalEnEng` | `Bool` | `false` | ㄣ ↔ ㄥ（原有功能遷移） |
| `fuzzyFinalAnAng` | `Bool` | `false` | ㄢ ↔ ㄤ |
| `fuzzyFinalInIng` | `Bool` | `false` | ㄧㄣ ↔ ㄧㄥ |
| `fuzzyFinalUnUng` | `Bool` | `false` | ㄨㄣ ↔ ㄨㄥ |

---

## 5. 技術實作：查詢展開邏輯

### 5.1 現有 ㄣ/ㄥ 的實作位置

Agent 實作前請先搜尋現有的 ㄣ/ㄥ 容錯實作位置：

```
搜尋關鍵字：fuzzyEn、ㄣ、ㄥ、EnEng、legacyFuzzyEnEng
搜尋範圍：
  - Packages/vChewing_LangModelAssembly/
  - Packages/vChewing_Typewriter/
  - Packages/vChewing_Shared/
```

找到現有實作後，**在相同位置擴充**其他近似音規則，保持架構一致。

### 5.2 查詢展開邏輯（概念）

近似音的核心是：輸入某個讀音時，同時查詢其近似音的候選字，並以**較低權重**合併到候選清單中。

```swift
/// 根據目前啟用的近似音設定，展開一個讀音為多個讀音
func expandFuzzyReadings(_ reading: String) -> [String] {
    guard PrefMgr.shared.fuzzyPhoneticEnabled else { return [reading] }
    
    var expanded: [String] = [reading]
    
    // 聲母近似音展開
    let fuzzyInitialRules: [(String, String, Bool)] = [
        ("ㄅ", "ㄆ", PrefMgr.shared.fuzzyInitialBP),
        ("ㄈ", "ㄏ", PrefMgr.shared.fuzzyInitialFH),
        ("ㄌ", "ㄋ", PrefMgr.shared.fuzzyInitialLN),
        ("ㄗ", "ㄓ", PrefMgr.shared.fuzzyInitialZZh),
        ("ㄘ", "ㄔ", PrefMgr.shared.fuzzyInitialCCh),
        ("ㄙ", "ㄕ", PrefMgr.shared.fuzzyInitialSSh),
    ]
    
    for (a, b, enabled) in fuzzyInitialRules where enabled {
        if reading.hasPrefix(a) {
            expanded.append(b + reading.dropFirst(a.count))
        } else if reading.hasPrefix(b) {
            expanded.append(a + reading.dropFirst(b.count))
        }
    }
    
    // 韻母近似音展開
    let fuzzyFinalRules: [(String, String, Bool)] = [
        ("ㄣ", "ㄥ", PrefMgr.shared.fuzzyFinalEnEng),
        ("ㄢ", "ㄤ", PrefMgr.shared.fuzzyFinalAnAng),
        ("ㄧㄣ", "ㄧㄥ", PrefMgr.shared.fuzzyFinalInIng),
        ("ㄨㄣ", "ㄨㄥ", PrefMgr.shared.fuzzyFinalUnUng),
    ]
    
    for (a, b, enabled) in fuzzyFinalRules where enabled {
        if reading.hasSuffix(a) {
            expanded.append(reading.dropLast(a.count) + b)
        } else if reading.hasSuffix(b) {
            expanded.append(reading.dropLast(b.count) + a)
        }
    }
    
    return Array(Set(expanded))  // 去重
}
```

### 5.3 非法音節過濾

展開後的讀音必須過濾掉在注音系統中**不合法**的組合。例如：
- ㄅ 沒有對應的聲調輕聲形式某些特定組合
- ㄍㄩ、ㄎㄩ 等在注音中不存在

Agent 實作時需在展開後查詢詞庫前，先驗證展開後的讀音是否為合法注音音節（可參考 Tekkon 的合法音節表）。

---

## 6. 架構與實作位置

### 6.1 修改檔案清單

| 檔案路徑 | 變更類型 | 說明 |
|----------|---------|------|
| `Packages/vChewing_Shared/Sources/Shared/UserDef/UserDef.swift` | 修改 | 新增 10 個 UserDef case（1 總開關 + 6 聲母 + 4 韻母） |
| `Packages/vChewing_Shared/Sources/Shared/Protocols/PrefMgrProtocol.swift` | 修改 | 新增對應的 protocol 屬性 |
| `Packages/vChewing_Shared/Sources/Shared/PrefMgr/PrefMgr.swift` | 修改 | 新增 UserDefaults 讀寫實作 |
| `Packages/vChewing_LangModelAssembly/.../（現有 ㄣ/ㄥ 容錯位置）` | 修改 | 擴充為支援全部近似音規則，複用現有展開邏輯 |
| `Packages/vChewing_MainAssembly4Darwin/.../SettingsUI（一般設定頁）` | 修改 | 移除舊 ㄣ/ㄥ 開關，新增近似音設定區塊（總開關 + 二欄子選項） |

### 6.2 實作步驟建議

1. **先找到現有 ㄣ/ㄥ 實作**：搜尋現有容錯邏輯的完整位置
2. **新增 UserDef 鍵值**：10 個新的偏好設定項目
3. **擴充查詢展開邏輯**：在現有 ㄣ/ㄥ 的基礎上加入其他規則
4. **更新 UI**：移除舊開關，新增二欄佈局的近似音設定區塊
5. **向下相容遷移**：確保舊設定正確遷移到新格式
6. **單元測試**：驗證各規則展開正確，非法音節被過濾

---

## 7. 測試案例

### 7.1 聲母近似音

| 輸入讀音 | 啟用規則 | 展開後查詢 |
|---------|---------|-----------|
| ㄗㄨㄛˋ | ㄗ↔ㄓ | ㄗㄨㄛˋ + ㄓㄨㄛˋ |
| ㄓㄨㄛˋ | ㄗ↔ㄓ | ㄓㄨㄛˋ + ㄗㄨㄛˋ |
| ㄙ | ㄙ↔ㄕ | ㄙ + ㄕ（但需驗證單聲母合法性） |
| ㄌㄧˋ | ㄌ↔ㄋ | ㄌㄧˋ + ㄋㄧˋ |

### 7.2 韻母近似音

| 輸入讀音 | 啟用規則 | 展開後查詢 |
|---------|---------|-----------|
| ㄓㄣ | ㄣ↔ㄥ | ㄓㄣ + ㄓㄥ |
| ㄙㄨㄣ | ㄨㄣ↔ㄨㄥ | ㄙㄨㄣ + ㄙㄨㄥ |
| ㄧㄣ | ㄧㄣ↔ㄧㄥ | ㄧㄣ + ㄧㄥ |
| ㄇㄢ | ㄢ↔ㄤ | ㄇㄢ + ㄇㄤ |

### 7.3 非法音節過濾

| 展開結果 | 是否合法 | 處理 |
|---------|---------|------|
| ㄅㄆ組合某些形式 | 視情況 | 查詢 Tekkon 合法表過濾 |
| ㄍㄩ | 不合法 | 過濾，不查詢 |

### 7.4 總開關

| 狀態 | 預期行為 |
|------|---------|
| 總開關關閉 | 所有近似音規則無效，僅查詢精確讀音 |
| 總開關開啟，但所有子選項未勾選 | 等同關閉，無近似音展開 |
| 總開關開啟，ㄗ↔ㄓ 勾選 | 僅展開平捲舌，其他不展開 |

### 7.5 向下相容

| 舊設定狀態 | 遷移後結果 |
|-----------|-----------|
| 舊 ㄣ/ㄥ 開關：開啟 | `fuzzyPhoneticEnabled = true`、`fuzzyFinalEnEng = true` |
| 舊 ㄣ/ㄥ 開關：關閉 | `fuzzyPhoneticEnabled = false`、`fuzzyFinalEnEng = false` |

---

## 8. 不在本次範圍內（Out of Scope）

- 聲調近似音（如陰平↔陽平）
- 自訂近似音規則（使用者自行新增音對）
- 近似音候選字的權重細調（目前統一用較低優先度顯示）
- 與近音表選字（↑鍵）功能的整合（兩者獨立運作）

---

## 9. Commit 訊息格式參考

```
Shared // UserDef: Add fuzzyPhonetic preference keys (1 master + 6 initial + 4 final).
Shared // PrefMgr: Implement fuzzyPhonetic preference properties with legacy migration.
LangModelAssembly // FuzzyPhonetic: Extend fuzzy reading expansion to support all rules.
MainAssembly // SettingsUI: Replace legacy EnEng toggle with fuzzy phonetic settings panel.
Typewriter // Tests: Add unit tests for fuzzy reading expansion and illegal syllable filter.
```
