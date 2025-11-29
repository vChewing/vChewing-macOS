# Megrez Engine 天權星引擎

- Gitee: [Swift](https://gitee.com/vChewing/Megrez) | [C#](https://gitee.com/vChewing/MegrezNT)
- GitHub: [Swift](https://github.com/vChewing/Megrez) | [C#](https://github.com/vChewing/MegrezNT)

> 該引擎已經實裝於基於純 Swift 語言完成的 **唯音輸入法** 內，歡迎好奇者嘗試：[GitHub](https://github.com/vChewing/vChewing-macOS ) | [Gitee](https://gitee.com/vchewing/vChewing-macOS ) 。

天權星引擎是用來處理輸入法語彙庫的一個模組。

Megrez Engine is a module made for processing lingual data of an input method.

## 專案特色

- 原生 Swift 實作，擁有完備的 Swift 5.3 ~ 5.9 支援、也可以用作任何 Swift 6 專案的相依套件。
  - 注意：`Megrez.Compositor.theSeparator` **沒有多執行緒安全性**。對該 API 的保留乃是出於相容性之考量。新專案請避免使用該 static API。
- 以陣列的形式處理輸入的 key。
- 在獲取候選字詞內容的時候，不會出現橫跨游標的詞。
- 使用 DAG-DP 算法，擁有比 DAG-Relax Topology 算法更優的效能。

## 使用說明

`MegrezTests.swift` 展示了詳細的使用方法。

## 著作權 (Credits)

- (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
- The unit tests utilizes certain contents extracted from libvchewing-data by (c) 2022 and onwards The vChewing Project (BSD-3-Clause).

敝專案採雙授權發佈措施。除了 LGPLv3 以外，對商業使用者也提供不同的授權條款（比如允許閉源使用等）。詳情請[電郵聯絡作者](shikisuen@yeah.net)。
