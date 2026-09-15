// (c) 2026 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

/// 本型別沒有任何成員：它存在的唯一目的，是讓本套件有一個合法靶可掛那兩個 build tool plug-ins
/// （`VanguardTextMapPlugin` 產出原廠辭典、`TextTemplateAssetInjectorPlugin` 抽出使用者片語範本）。
/// 產物落在 plugin work directory 內，再由 `makefile` 的 `collect` 目標集中到 `Build/`。
public enum LexiconBuildTrigger {}
