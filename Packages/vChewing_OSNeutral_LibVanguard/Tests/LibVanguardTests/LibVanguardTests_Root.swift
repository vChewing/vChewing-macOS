// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Testing

// MARK: - LibVanguardTestsRoot

/// 本測試目標（`LibVanguardTests`）的**唯一根 suite**。
///
/// - Important: **本測試目標內所有測試一律關在此根之下。** 本根**不再**標 `.serialized`（P316）：
///   各 suite 自持其執行環境（`TestEnvironment`：辭典、宿主、偏好容器皆逐用例一份），
///   故並行執行互不相擾；`SessionHost.shared`、`LXFacade` 的辭典／磁帶／注音文
///   與 `OSUtils.defaultsStore` 皆不再被測試改寫。
///   P315 之前那些「handler 狀態殘留」型偶發失敗之成因已隨之消失。
///
///   新增測試時：**把新 suite 寫成 `extension LibVanguardTestsRoot { … }` 並在其內宣告 `@Suite`**，
///   不要新增游離於本根之外的頂層 suite；並在 `init` 內以 `TestEnvironment()` 取得環境，
///   **不得**改寫任何行程級全域（辭典、宿主、偏好容器一律逐用例自持）。
///
/// - Important: **凡涉及使用者資料載入（userdata）的測試，載入一律須為同步**——即
///   `LXFacade.asyncLoadingUserData == false`。測試要的是**確定性**：資料必須在斷言之前載入完畢，
///   不得留下「等等才會落定」的非同步尾巴。生產碼已把它與測試模式綁定
///   （`resetSharedResources()`／`applyEnvironmentDefaults()` 皆寫 `= !OSUtils.isRunningUnitTests`，
///   故單元測試下恆為 `false`）；該開關現在是類別層之**預設值**，實例未個別指定時即時反映之。
///   **測試若自行改動此開關，必須以 `defer` 還原原值**。
///   **不得**為了「測到非同步路徑」而在單元測試中把它設成 `true`。
@Suite("LibVanguardTestsRoot")
final class LibVanguardTestsRoot {}
