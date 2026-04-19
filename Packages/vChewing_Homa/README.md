# Homa Engine 護摩引擎

> 該引擎已經實裝於基於純 Swift 語言完成的 **唯音輸入法** 內，歡迎好奇者嘗試：[GitHub](https://github.com/vChewing/vChewing-macOS ) | [Gitee](https://gitee.com/vchewing/vChewing-macOS ) 。

護摩引擎是用來處理輸入法語彙庫的一個模組。

Homa Engine is a module made for processing lingual data of an input method.

## 專案特色

- 原生 Swift 實作，擁有完備的 Swift 5.10 支援、也可以用作任何 Swift 6 專案的相依套件。
- 以陣列的形式處理輸入的 key。
- 在獲取候選字詞內容的時候，不會出現橫跨游標的詞。
- 使用 DAG-DP 算法，擁有比 DAG-Relax Topology 算法更優的效能。
- 允許使用 Bigrams 以及 partial matching，但 partial matching 得需要搭配專門的資料提供 API。

## 使用說明

`HomaTests.swift` 展示了詳細的使用方法。

## 著作權 (Credits)

- (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
- The unit tests utilizes certain contents extracted from libvchewing-data by (c) 2022 and onwards The vChewing Project (BSD-3-Clause).

敝專案採雙授權發佈措施。除了 LGPLv3 以外，對商業使用者也提供不同的授權條款（比如允許閉源使用等）。詳情請[電郵聯絡作者](shikisuen@yeah.net)。
