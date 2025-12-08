// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

/// KeyKeyUserDBKit - Yahoo! 奇摩輸入法使用者資料庫工具
///
/// 此套件提供解密和讀取 Yahoo! 奇摩輸入法 (KeyKey) 使用者資料庫的功能。
///
/// ## 主要元件
///
/// - ``KeyKeyUserDBKit/SEEDecryptor``: SQLite SEE AES-128 解密器
/// - ``KeyKeyUserDBKit/PhonaSet``: 注音符號處理類別
/// - ``KeyKeyUserDBKit/UserDatabase``: 使用者資料庫讀取器
/// - ``KeyKeyUserDBKit/Gram``: 通用語料結構體
///
/// ## 使用範例
///
/// ```swift
/// import KeyKeyUserDBKit
///
/// // 解密資料庫
/// let decryptor = KeyKeyUserDBKit.SEEDecryptor()
/// try decryptor.decryptFile(
///     at: URL(fileURLWithPath: "SmartMandarinUserData.db"),
///     to: URL(fileURLWithPath: "decrypted.db")
/// )
///
/// // 讀取資料
/// let db = try KeyKeyUserDBKit.UserDatabase(path: "decrypted.db")
///
/// // 取得所有語料資料
/// let allGrams = try db.fetchAllGrams()
///
/// for gram in allGrams {
///     print("\(gram.current) → \(gram.keyArray.joined(separator: ","))")
/// }
///
/// // 或分別讀取各類型資料
/// let unigrams = try db.fetchUnigrams()
/// let bigrams = try db.fetchBigrams()
/// let overrides = try db.fetchCandidateOverrides()
/// ```
public enum KeyKeyUserDBKit {}
