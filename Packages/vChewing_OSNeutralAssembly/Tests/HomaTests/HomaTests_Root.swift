// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Testing

/// 全部 Homa 單元測試的總 suite：以 extension 將各子 suite 收進同一序列化作用域。
/// （heap 哨兵量測全進程 malloc zone，跨 suite 並行的分配會污染量測窗口造成假陽性。）
@Suite(.serialized)
enum HomaTestsRoot {}
