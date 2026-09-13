# ShiftKeyUpChecker

```
// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.
```

用來判定「Shift 鍵是否有被單獨摁過」的模組。

該方法並非 Apple 在官方技術文件當中講明的方法，而是連續分析前後兩個 NSEvent。

由於只需要接收藉由 IMK 傳入的 NSEvent 而不需要監聽系統全局鍵盤事件，所以沒有資安疑慮。
