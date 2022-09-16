# ShiftKeyUpChecker

```
// (c) 2022 and onwards Qwertyyb (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
```

自[業火五筆輸入法](https://github.com/qwertyyb/Fire)承襲的模組，用來判定「Shift 鍵是否有被單獨摁過」。

該方法並非 Apple 在官方技術文件當中講明的方法，而是業火五筆輸入法的作者首創。

方法的原理就是連續分析前後兩個 NSEvent。由於只需要接收藉由 IMK 傳入的 NSEvent 而不需要監聽系統全局鍵盤事件，所以沒有資安疑慮。
