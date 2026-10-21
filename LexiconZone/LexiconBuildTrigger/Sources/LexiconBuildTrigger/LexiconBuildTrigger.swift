// 本型別沒有任何成員：它的唯一用途是給兩支 lexicon buildTool plugin 一個附著點
/// （`VanguardTextMapPlugin` 產出原廠辭典、`TextTemplateAssetInjectorPlugin` 抽出使用者片語範本）。
/// 兩支 plugin 的產物寫進 SwiftPM 的 `plugins/outputs/…`，再由本目錄的 `makefile` 之 `collect` 目標
/// 集中到固定路徑，供 `vChewing_MainAssembly4Darwin` 的 `LexiconAssetRelayPlugin` 複製注入。
public enum LexiconBuildTrigger {}
