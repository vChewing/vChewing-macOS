# LexiconAssembly

唯音輸入法的語言模組總成套裝，以 LXAssembly 命名空間承載下述唯二對外物件：

- LXConsolidator：自動格式整理模組。
- LXFacade：語言模組副本化模組，亦集成一些自身功能擴展。

LXAssembly 總命名空間也承載一些在套裝內共用的工具函式。

以下是子模組：

- LXAssociates：關聯詞語模組。
- lxCassette：專門用來處理 CIN 磁帶檔案的模組，命名為「遠野」引擎。
- LXCoreEX：可以直接讀取 TXT 格式的帶有權重資料的語彙檔案的模組。
- lxPlainBopomofo：專門用來讀取使用者自訂ㄅ半候選字順序覆蓋定義檔案（plist）的模組。
- lxReplacements：專門用來讀取使用者片語置換模式的辭典資料的模組。
- LXPerceptor：漸退記憶模組。

```
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.
```
