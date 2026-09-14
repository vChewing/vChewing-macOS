# vChewing_VanguardSwiftExtension

唯音輸入法用到的各種 Swift 功能擴張。**模組名 `SwiftExtension`**（自 4.7.4 以來未變，故全倉
一律 `import SwiftExtension`）；本套件出貨的**產品名**為 `VanguardSwiftExtension`——兩者刻意不同名。

本模組原為獨立套件 `vChewing_SwiftExtension`，於 2026-09-13 的「聚合體化」中被併入
`vChewing_OSNeutral_LibVanguard`；後因 App-based installer 只用到本模組、卻被迫連帶吃下整條打字
閉包，遂再次析出為獨立套件，並改以動態產品出貨：

- **Darwin**：產品 `VanguardSwiftExtension` 為 `dynamic`，產物 `libVanguardSwiftExtension.dylib`。
  聚合體（`libVanguard.dylib`）對它是**動態相倚**而非靜態內嵌，故每個行程內本模組恰有一份 image。
- **其餘平台**：產品為 `static`，聚合體照舊把它內嵌進唯一那顆 `Vanguard` 動態庫，不產生第二顆
  動態庫。

```
// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.
```

授權全文見同目錄 `LICENSE`（木蘭寬鬆授權條款第 2 版）。
