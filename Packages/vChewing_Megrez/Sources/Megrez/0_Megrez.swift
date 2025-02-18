// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

/// The namespace for this package.
public enum Megrez {}

// 著作權聲明：
// 除了 Megrez 專有的修改與實作以外，該套件所有程式邏輯來自於 Gramambular。
// 天權星引擎（Megrez Compositor）僅僅是將 Gramambular 用 Swift 重寫之後繼續開發的結果而已。主要區別：
//
// - 原生 Swift 實作，擁有完備的 Swift 5.3 ~ 5.9 支援、也可以用作任何 Swift 6 專案的相依套件（需使用者自行處理對跨執行緒安全性的需求）。
// - API 經過重新設計，以陣列的形式處理輸入的 key。而且，在獲取候選字詞內容的時候，也可以徹底篩除橫跨游標的詞。
// - 爬軌算法（Walking Algorithm）改為 Dijkstra 的算法，且經過效能最佳化處理、擁有比 DAG-Relax 算法更優的效能。

// 術語：

// Grid: 節軌
// Walk: 爬軌
// Node: 節點
// SpanLength: 節幅
// Span: 幅位
