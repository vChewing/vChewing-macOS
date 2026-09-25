// 唯音輸入法配置助手之建置器（零 npm 相依；由 tools/host 之 JXA 宿主執行，不需要 node）。
//
// 產物：
//   dist/js/<module>.js   ← `tsc` 之產物（本檔不負責編譯，只負責串接）
//   dist/metadata.js      ← 由 assets/userdef-metadata.json 生成之全域注入
//   dist/core.js          ← 無 DOM 之純邏輯（i18n／schema／問卷／配置包生成）——供測試宿主載入
//   dist/app.js           ← core ＋ DOM 介面（widgets／shell／exits／main）
//   dist/assistant.html   ← 單檔自足之交付物（CSS 與 JS 皆內聯）
//
// 用法：osascript -l JavaScript tools/host/run.js tools/build.js

const fs = require('node:fs');
const path = require('node:path');
const { assertEs5 } = require('./es5guard.js');
const { readTargetVersion } = require('./target-version.js');
const ROOT = path.resolve(path.dirname(__filename), '..');
const SRC_DIR = path.join(ROOT, 'src');
const JS_DIR = path.join(ROOT, 'dist', 'js');
const DIST_DIR = path.join(ROOT, 'dist');
const ASSETS_DIR = path.join(ROOT, 'assets');

// 載入順序即執行順序：tsc 之產物是「全域 script」，沒有模組系統可供解析相依。
// 入口頁之文案（助手之全稱一律取 app l10n 之全稱；此處為靜態檔，故四語系各備一句）。
const UI_TITLE = {
  'zh-Hant': '唯音輸入法配置助手',
  'zh-Hans': '唯音输入法配置助手',
  en: 'vChewing Configuration Assistant',
  ja: '唯音入力アプリ配置助手',
};
const UI_LEAD = {
  'zh-Hant': '正在前往配置助手……',
  'zh-Hans': '正在前往配置助手……',
  en: 'Taking you to the Configuration Assistant…',
  ja: '配置助手へ移動しています……',
};
const LINK_TEXT = {
  'zh-Hant': '若未自動跳轉，請按此處。',
  'zh-Hans': '若未自动跳转，请按此处。',
  en: 'If nothing happens, press here.',
  ja: '自動で移動しない場合はこちらを押してください。',
};

const CORE_ORDER = ['globals', 'model', 'i18n', 'schema', 'questions', 'starter', 'preset'];
const APP_ORDER = ['widgets', 'shell', 'exits', 'main'];

function readText(file) {
  return fs.readFileSync(file, 'utf8');
}

function listSourceStems() {
  return fs.readdirSync(SRC_DIR)
    .filter(function (name) { return name.slice(-3) === '.ts'; })
    .map(function (name) { return name.slice(0, -3); })
    .sort();
}

// 來源清單與實際檔案之一致性：任何新增／改名而未登錄於 CORE_ORDER／APP_ORDER 者，即建置失敗。
function assertOrderCoversSources() {
  const declared = CORE_ORDER.concat(APP_ORDER).slice().sort();
  const actual = listSourceStems();
  const missing = actual.filter(function (s) { return declared.indexOf(s) < 0; });
  const extra = declared.filter(function (s) { return actual.indexOf(s) < 0; });
  if (missing.length > 0 || extra.length > 0) {
    throw new Error(
      'tools/build.js 之載入順序與 src/ 不一致。\n  未登錄：' + (missing.join(', ') || '（無）') +
      '\n  已失效：' + (extra.join(', ') || '（無）')
    );
  }
}

function readEmittedJs(stem) {
  const file = path.join(JS_DIR, stem + '.js');
  if (!fs.existsSync(file)) {
    throw new Error('找不到 tsc 之產物：' + path.relative(ROOT, file) + '（請先跑 `make build`）');
  }
  return readText(file);
}

// 內嵌版之後設資料：只留助手用得到的欄位，以免單檔產物被 prompt／toolTip 一類欄位撐大。
function projectMetadata(raw) {
  const entries = raw.entries.map(function (entry) {
    const labels = {};
    Object.keys(entry.labels || {}).forEach(function (lang) {
      const source = entry.labels[lang] || {};
      const kept = {};
      if (typeof source.shortTitle === 'string') kept.shortTitle = source.shortTitle;
      if (typeof source.description === 'string') kept.description = source.description;
      labels[lang] = kept;
    });
    return {
      key: entry.key,
      rawValue: entry.rawValue,
      type: entry.type,
      defaultsType: entry.defaultsType,
      default: entry['default'],
      range: entry.range,
      minimumOS: entry.minimumOS,
      exchangeBlacklisted: entry.exchangeBlacklisted,
      metadataPending: entry.metadataPending,
      metadataPendingReason: entry.metadataPendingReason,
      options: entry.options,
      optionsKind: entry.optionsKind,
      labels: labels,
    };
  });
  return {
    schemaVersion: raw.schemaVersion,
    generator: raw.generator,
    locales: raw.locales,
    count: raw.count,
    missingI18nKeys: raw.missingI18nKeys,
    pendingMetadataKeys: raw.pendingMetadataKeys,
    extraLabelPrefixes: raw.extraLabelPrefixes,
    extraLabels: raw.extraLabels,
    entries: entries,
  };
}

function buildMetadataJs(docBase) {
  const assetPath = path.join(ASSETS_DIR, 'userdef-metadata.json');
  if (!fs.existsSync(assetPath)) {
    throw new Error('找不到 assets/userdef-metadata.json（請先跑 `make metadata-update`）');
  }
  const raw = JSON.parse(readText(assetPath));
  const projected = projectMetadata(raw);
  const stamp = new Date().toISOString();
  const surfacePath = path.join(ASSETS_DIR, 'settings-surface.json');
  if (!fs.existsSync(surfacePath)) {
    throw new Error('找不到 assets/settings-surface.json（請先跑 `make surface`）');
  }
  const surface = JSON.parse(readText(surfacePath));
  const targetVersion = readTargetVersion();
  let code = '// 本檔為建置產物（由 assets/userdef-metadata.json 與 assets/settings-surface.json 投影而成），請勿手改。\n';
  code += 'var VCA_METADATA = ' + JSON.stringify(projected) + ';\n';
  // 只注入執行期需要之段落（鍵盤排列之順序／標籤）；鍵集本身屬建置期與測試之用。
  code += 'var VCA_SURFACE = ' + JSON.stringify({ keyboardParsers: surface.keyboardParsers }) + ';\n';
  // 助手所適配之輸入法版本（來自本目錄之 version.txt；`make version-check` 與倉根
  // `Release-Version.plist` 比對）。
  code += 'var VCA_TARGET_VERSION = ' + JSON.stringify(targetVersion) + ';\n';
  code += 'var VCA_DOC_BASE = ' + JSON.stringify(docBase) + ';\n';
  code += 'var VCA_BUILD_STAMP = ' + JSON.stringify(stamp) + ';\n';
  const serialized = JSON.stringify(projected);
  return {
    code: code,
    stamp: stamp,
    metadataBytes: Buffer.byteLength(serialized, 'utf8'),
    targetVersion: targetVersion,
  };
}

// 產物之入口頁：`dist/` 整個目錄丟上網即可用（`/assistant/` 之目錄索引）。
//
// 何以用 `<meta http-equiv="refresh">`：它自 HTML 4.01 起即有、Safari 7（目標環境）亦支援，
// 不勞 JavaScript；並附一個普通連結作後備（不支援 meta refresh 者仍可手動進入）。
// 標題與說明取助手之全稱與首頁第一句，使分享出去之網址預覽不至空白。
function buildRedirectHtml(stamp, lang) {
  const title = UI_TITLE[lang] || UI_TITLE['zh-Hant'];
  const lead = UI_LEAD[lang] || UI_LEAD['zh-Hant'];
  return [
    '<!DOCTYPE html>',
    '<html lang="' + lang + '">',
    '<head>',
    '<meta charset="utf-8">',
    '<meta http-equiv="refresh" content="0; url=assistant.html">',
    '<title>' + title + '</title>',
    '<style>',
    'body { background: #3B6EA5; color: #000; font-family: Tahoma, "Helvetica Neue", sans-serif;',
    '  font-size: 12px; margin: 0; padding: 40px 0; }',
    '.win { background: #C0C0C0; border: 2px outset #FFF; width: 420px; margin: 0 auto; padding: 18px; }',
    '.bar { background: #0A246A; color: #FFF; font-weight: bold; padding: 3px 6px; margin: -18px -18px 14px -18px; }',
    'a { color: #0000EE; }',
    '</style>',
    '</head>',
    '<body>',
    '<div class="win">',
    '<div class="bar">' + title + '</div>',
    '<p>' + lead + '</p>',
    '<p><a href="assistant.html">' + LINK_TEXT[lang] + '</a></p>',
    '<p>' + stamp + '</p>',
    '</div>',
    '</body>',
    '</html>',
    '',
  ].join('\n');
}

function buildHtml(style, script, stamp, lang) {
  const template = readText(path.join(ROOT, 'index.html'));
  return template
    .replace('{{LANG}}', lang)
    .replace('{{STYLE}}', style)
    .replace('{{SCRIPT}}', script)
    .replace('{{BUILD_STAMP}}', stamp);
}

function main() {
  assertOrderCoversSources();
  fs.mkdirSync(DIST_DIR, { recursive: true });

  const docBaseArg = process.argv.filter(function (arg) { return arg.indexOf('--doc-base=') === 0; })[0];
  // 預設指向官網之絕對位址：助手的產物可雙擊開啟（file://）、亦可能被他處嵌入，
  // 相對路徑在 file:// 之下必為死鏈。若助手與官網同網域，可改用 `--doc-base=../`。
  const docBase = docBaseArg ? docBaseArg.slice('--doc-base='.length) : 'https://vchewing.github.io/';

  const metadata = buildMetadataJs(docBase);
  fs.writeFileSync(path.join(DIST_DIR, 'metadata.js'), metadata.code, 'utf8');

  const core = [metadata.code]
    .concat(CORE_ORDER.map(readEmittedJs))
    .join('\n');
  const app = [core]
    .concat(APP_ORDER.map(readEmittedJs))
    .join('\n');

  // 守衛：產物必須是 ES5 語法 ＋ 不得有模組系統殘留（本專案以 tsc 7 編譯，無 ES5 target）。
  assertEs5(core, 'dist/core.js');
  assertEs5(app, 'dist/app.js');

  fs.writeFileSync(path.join(DIST_DIR, 'core.js'), core, 'utf8');
  fs.writeFileSync(path.join(DIST_DIR, 'app.js'), app, 'utf8');

  const style = readText(path.join(ASSETS_DIR, 'assistant.css'));
  const html = buildHtml(style, app, metadata.stamp, 'zh-Hant');
  fs.writeFileSync(path.join(DIST_DIR, 'assistant.html'), html, 'utf8');
  // 入口頁：整個 dist/ 目錄即可直接上網（`<站根>/assistant/` 之目錄索引）。
  const redirect = buildRedirectHtml(metadata.stamp, 'zh-Hant');
  fs.writeFileSync(path.join(DIST_DIR, 'index.html'), redirect, 'utf8');

  // 一律以**位元組**計（產物含大量 CJK，字元數與位元組數相去甚遠）。
  const kb = function (n) { return (n / 1024).toFixed(1) + ' KiB'; };
  const bytesOf = function (text) { return Buffer.byteLength(text, 'utf8'); };
  process.stdout.write('建置完成（位元組）：\n');
  process.stdout.write('  dist/core.js        ' + kb(bytesOf(core)) + '\n');
  process.stdout.write('  dist/app.js         ' + kb(bytesOf(app)) + '\n');
  process.stdout.write('  dist/assistant.html ' + kb(bytesOf(html)) +
    '（內嵌之後設資料 ' + kb(metadata.metadataBytes) + '）\n');
  process.stdout.write('  dist/index.html     ' + kb(bytesOf(redirect)) +
    '（自動跳轉至 assistant.html）\n');
  process.stdout.write('  適配版本 ' + metadata.targetVersion.display + '\n');
  process.stdout.write('  產出時間 ' + metadata.stamp + '\n');
}

if (require.main === module) main();
