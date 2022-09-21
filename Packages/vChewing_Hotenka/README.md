# Hotenka Engine 步天歌引擎

- Gitee: [Swift](https://gitee.com/vChewing/Hotenka)
- GitHub: [Swift](https://github.com/vChewing/Hotenka)

步天歌引擎是一套簡繁轉換模組，將 Nick Chen 的 ObjC 模組「[NCChineseConverter](https://github.com/nickcheng/NCChineseConverter)」用 Swift 重寫而得。簡繁轉換資料改用 OpenCC 的轉換資料（Apache License 2.0）且有做了一些修改。

Hotenka Engine is a module made for converting between Simplified Chinese and Traditional Chinese. This module is using the translation data from OpenCC (Apache License 2.0).

## 使用說明

詳見 HotenkaTest.swift。要編譯 plist 詞庫的話，跑一遍單元測試即可自動生成 plist 詞庫檔案。

## 著作權 (Credits)

- Swiftified by (c) 2022 and onwards The vChewing Project (MIT-NTL License).
  - Swift programmer: Shiki Suen
- Rebranded from (c) Nick Chen's Obj-C library "NCChineseConverter" (MIT License).
