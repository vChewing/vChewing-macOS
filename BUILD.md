# vChewing-macOS 編譯流程指南

## 環境需求

- macOS 14.7+ (建議 Sonoma)
- Xcode 15.3+ (包含 Swift 5.10 或更新版本)
- Swift Package Manager 6.2.4+

## 首次設定

### 1. Xcode 設定（重要）

建置前必須先配置 Xcode，允許其直接構建在專案所在資料夾下的 build 資料夾內：

**步驟一：設定 Derived Data 位置**
1. 開啟 Xcode
2. 選單列：「Xcode」→「Settings...」（或 Preferences）
3. 切換到「Locations」分頁
4. 確認「Derived Data」設定為「Relative to Workspace」

**步驟二：設定專案建置路徑**
1. 開啟 vChewing 專案（開啟 Package.swift 所在資料夾）
2. 選單列：「File」→「Project Settings...」
3. 點擊「Advanced」按鈕
4. 選擇「Custom」→「Relative to Workspace」
5. 按「Done」儲存

> **注意**：如果不進行上述設定，`make` 指令可能會出錯。

## 編譯指令

在終端機內定位到專案目錄後，執行下列指令：

### 取得詞庫資源（首次或更新詞庫時執行）
```bash
make update
```
這會使用遠端 Swift Package plugin 取得最新詞庫資源。

### 建置發行版本（推薦）
```bash
make release
```
- 建置通用二進制版本（同時支援 arm64 和 x86_64）
- 輸出位置：`Build/Products/Release/`
- 包含完整的應用程式 Bundle

### 建置存檔版本
```bash
make archive
```
- 建置通用版本並產生 `.xcarchive` 存檔
- 包含除錯符號（dSYM）
- 自動存入 Xcode Archives 目錄（`~/Library/Developer/Xcode/Archives/`）

### 快速偵錯組建
```bash
make debug
```
- 單一架構組建（較快）
- 適合開發測試使用
- 輸出位置：`Build/Products/Debug/`

## 安裝輸入法

### 安裝發行版本
```bash
make install-release
```
這會自動開啟安裝程式（`vChewingInstaller.app`）。

### 安裝偵錯版本
```bash
make install-debug
```

## 完整首次建置流程

```bash
# 1. 進入專案目錄
cd vChewing-macOS

# 2. 更新詞庫
make update

# 3. 建置發行版本
make release

# 4. 安裝輸入法
make install-release
```

## 其他實用指令

### 清理建置檔案
```bash
make clean          # 清理主要建置檔案
make clean-spm      # 清理 Swift Package Manager 快取
make xcode-clean    # 清理 Xcode 建置快取（如果使用 Xcode 建置）
make gitclean       # 清理所有未被追蹤的檔案（小心使用）
```

### 執行測試
```bash
make test           # 執行所有測試
```

### 程式碼格式化與檢查
```bash
make format         # 使用 swiftformat 格式化程式碼
make lint           # 使用 swiftlint 檢查程式碼
```

## 使用 Xcode 開發

如果您偏好使用 Xcode IDE：

1. 開啟專案資料夾（包含 `Package.swift` 的資料夾）
2. 等待 Xcode 載入 Swift Package 依賴
3. 選擇 Scheme：「vChewingInstaller」
4. 按 Cmd+B 編譯，或 Cmd+R 執行

## 注意事項

- 修改原廠辭典或程式碼後，只需重複上述建置流程即可重新安裝
- 建置過程會自動處理程式碼簽署（codesign）
- 如果遇到權限問題，請確認 Xcode 命令列工具已正確安裝：
  ```bash
  xcode-select --install
  ```
