// 唯音輸入法配置助手 // 由 tools/build.js 注入之全域值（此處僅作型別宣告，不產生執行期碼）。
//
// 為何不用 `import`：本專案以 TypeScript 7（Go 原生版）編譯，而該版已移除 `module: none`
// 與 `target: es5`（實測 `error TS5108`／`TS6046`）。故改以「全域 script ＋ namespace 合併」
// 組織程式碼：原始碼一律 ES5 寫法，產物由 tools/build.js 依序串接為單一 script，
// 並由 tools/es5guard.js 守住 ES5 語法（見 README）。

declare var VCA_METADATA: VCA.MetadataFile;
declare var VCA_SURFACE: VCA.SettingsSurface;
declare var VCA_TARGET_VERSION: VCA.TargetVersion;
declare var VCA_DOC_BASE: string;
declare var VCA_BUILD_STAMP: string;
