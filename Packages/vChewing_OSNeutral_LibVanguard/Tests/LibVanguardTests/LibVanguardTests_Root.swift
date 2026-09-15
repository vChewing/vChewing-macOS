// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Testing

// MARK: - LibVanguardTestsRoot

/// 本測試靶（`LibVanguardTests`）的**唯一根 suite**。
///
/// - Important: **本靶內所有測試一律關在此根之下，且根標 `.serialized`。**
///   理由（2026-09-15 實測）：本靶各 suite 共用大量**行程內全域狀態**——`LXFacade` 的
///   `factoryTrie`／`lxCassette`、`PrefMgr.shared`、`SessionHost.shared`（`InputHandlerTests`
///   與 `SessionTests` 各自的 `init` 都會重新指派它）。**只要有任何兩個 suite 並行，就會互相踩踏**，
///   症狀是偶發的「handler 狀態殘留」型失敗（例：`mixedAlphanumericalBuffer` 該有值卻是空字串、
///   `narrateCallCount` 該 ≥1 卻是 0），且**同一測試時過時不過**。
///
///   兩道防線的層級不同，須分清：
///   1. **`swift test --no-parallel`**：CLI 層，擋「同時間多個測試函式」。**必要，但不充分**
///      ——它不保證非同步測試在 `await` 暫停點不交錯，也不改變 suite 之間的關係。
///   2. **單一根 suite ＋ `.serialized`**：型別層，`Swift Testing` 保證**該子樹內絕不並行**。
///      這才是本靶真正需要的保證，故所有 suite 一律嵌於本根之下。
///
///   新增測試時：**把新 suite 寫成 `extension LibVanguardTestsRoot { … }` 並在其內宣告 `@Suite`**，
///   不要新增游離於本根之外的頂層 suite。
///
/// - Important: **凡涉及使用者資料載入（userdata）的測試，載入一律須為同步**——即
///   `LXFacade.asyncLoadingUserData == false`。測試要的是**確定性**：資料必須在斷言之前載入完畢，
///   不得留下「等等才會落定」的非同步尾巴。生產碼已把它與測試模式綁定
///   （`resetSharedResources()`／`applyEnvironmentDefaults()` 皆寫 `= !UserDefaults.pendingUnitTests`，
///   故單元測試下恆為 `false`）；**測試若自行改動此開關，必須以 `defer` 還原原值**
///   （見 `InputHandlerTests_Cases1` 之九處、`LXFacadeTests`、`LXFacade_TextMapTests`、`SessionTests_Basics`）。
///   **不得**為了「測到非同步路徑」而在單元測試中把它設成 `true`。
@Suite("LibVanguardTestsRoot", .serialized)
final class LibVanguardTestsRoot {}
