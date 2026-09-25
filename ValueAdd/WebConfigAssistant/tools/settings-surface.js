// 設定介面曝露面之掃描器（零 npm 相依；由 tools/host 之 JXA 宿主執行，不需要 node）。
//
// 事主 2026-09-24 立規：**只要不是 `SettingsUI`／`SettingsCocoa` 曝露給使用者的選項，
// 就不要在配置助手裡面出現**。助手無法在執行期得知該集合（它不讀取任何本機檔案），
// 故於建置期掃描那兩個目錄之源碼、生成 `assets/settings-surface.json`；
// `tests/questions.test.js` 再以「題庫 ⊆ 曝露面」之不變式守住。
//
// 用法：osascript -l JavaScript tools/host/run.js tools/settings-surface.js [--check]

const fs = require('node:fs');
const path = require('node:path');
const ROOT = path.resolve(path.dirname(__filename), '..');
const ASSET_PATH = path.join(ROOT, 'assets', 'settings-surface.json');
// 助手目錄位於 vChewing-macOS/ValueAdd/WebConfigAssistant ⇒ 往上三層即倉根。
const SETTINGS_ROOT = path.join(ROOT, '..', '..', 'Packages', 'vChewing_SettingsUI', 'Sources', 'SettingsUI');
// 注音／拼音排列之清單：順序與標籤皆取自 app 自身（`KeyboardParser` 之宣告序 ＋ 其選單名稱），
// 分隔線則取自設定介面之繪製碼——故助手不必手抄這 17 條，亦不會與介面分歧。
const SHARED_SWIFT = path.join(
  ROOT, '..', '..', 'Packages', 'vChewing_OSNeutral_LibVanguard', 'Sources', 'Shared', 'Shared.swift'
);
const SWIFTUI_RENDERER = path.join(SETTINGS_ROOT, 'SettingsUI', 'UserDefRenderableImpl.swift');
const SCAN_DIRS = [
  path.join(SETTINGS_ROOT, 'SettingsUI'), // SwiftUI（macOS 14+）
  path.join(SETTINGS_ROOT, 'SettingsCocoa'), // AppKit（10.9+ 之對位介面）
];

function collectSwiftFiles(dir, out) {
  if (!fs.existsSync(dir)) return out;
  for (const name of fs.readdirSync(dir)) {
    const full = path.join(dir, name);
    const stat = fs.statSync(full);
    if (stat.isDirectory()) {
      collectSwiftFiles(full, out);
    } else if (name.endsWith('.swift')) {
      out.push(full);
    }
  }
  return out;
}

/// 解析 `KeyboardParser`：宣告序 ＋ 各 case 之 i18n 選單名稱 ＋ 設定介面之分隔線位置。
function extractKeyboardParsers() {
  if (!fs.existsSync(SHARED_SWIFT)) {
    throw new Error('找不到 KeyboardParser 之源碼：' + SHARED_SWIFT);
  }
  const lines = fs.readFileSync(SHARED_SWIFT, 'utf8').split('\n');
  const cases = [];
  const i18nKeys = {};
  // 逐行掃描：先收 enum 之 case（宣告序），再收 `localizedMenuName` 之 switch。
  // 結束 case 收集之判準是「遇到非 case 之實質內容」——**不可**用第一個 `}`，因為
  // `localizedMenuName` 之 switch 也在同一 enum 內、其標籤行會先被誤吞。
  let inCases = false;
  for (const line of lines) {
    if (line.indexOf('public enum KeyboardParser: Int, CaseIterable {') >= 0) { inCases = true; continue; }
    if (inCases) {
      const matched = /^\s*case\s+(\w+)\s*=\s*([0-9]+)\s*$/.exec(line);
      if (matched) {
        cases.push({ name: matched[1], value: parseInt(matched[2], 10) });
        continue;
      }
      const trimmed = line.trim();
      if (trimmed === '' || trimmed.indexOf('//') === 0) continue;
      inCases = false;
    }
    const label = /^\s*case\s+\.(\w+):\s*return\s+"(i18n:[^"]+)"/.exec(line);
    if (label) i18nKeys[label[1]] = label[2];
  }
  if (cases.length === 0) throw new Error('KeyboardParser 之 case 一個都沒解析到（源碼形制已變？）');
  const missing = cases.filter(function (item) { return !i18nKeys[item.name]; });
  if (missing.length > 0) {
    throw new Error('下列 KeyboardParser case 查無選單名稱：' + missing.map(function (i) { return i.name; }).join('、'));
  }
  const enriched = cases.map(function (item) {
    return { name: item.name, value: item.value, i18nKey: i18nKeys[item.name] };
  });

  // 分隔線：設定介面於此二者之前插入分隔（SwiftUI 之 `Divider()`；Cocoa 側同款）。
  let dividerBefore = [];
  const renderer = fs.readFileSync(SWIFTUI_RENDERER, 'utf8');
  const dividerMatch = /if\s*\[([0-9,\s]+)\]\.contains\(item\.rawValue\)/.exec(renderer);
  if (dividerMatch) {
    dividerBefore = dividerMatch[1].split(',').map(function (text) { return parseInt(text.trim(), 10); })
      .filter(function (value) { return !isNaN(value); });
  }
  return {
    dividerBefore: dividerBefore,
    zhuyin: enriched.filter(function (item) { return item.value < 100; }).map(function (item) { return item; }),
    pinyin: enriched.filter(function (item) { return item.value >= 100; }).map(function (item) { return item; }),
  };
}

function main() {
  const check = process.argv.indexOf('--check') >= 0;
  const files = [];
  for (const dir of SCAN_DIRS) collectSwiftFiles(dir, files);
  if (files.length === 0) {
    throw new Error('找不到設定介面之源碼：' + SCAN_DIRS.join('、'));
  }
  const pattern = /UserDef\.(k[A-Za-z0-9_]+)/g;
  const keys = new Set();
  for (const file of files) {
    const text = fs.readFileSync(file, 'utf8');
    let match = pattern.exec(text);
    while (match !== null) {
      keys.add(match[1]);
      match = pattern.exec(text);
    }
    pattern.lastIndex = 0;
  }
  const sorted = Array.from(keys).sort();
  const keyboardParsers = extractKeyboardParsers();
  const payload = {
    generator: 'tools/settings-surface.js',
    sourceDirectories: SCAN_DIRS.map(function (dir) { return path.relative(ROOT, dir); }),
    scannedFileCount: files.length,
    count: sorted.length,
    keys: sorted,
    keyboardParsers: keyboardParsers,
  };
  const text = JSON.stringify(payload, null, 2) + '\n';
  if (check) {
    const committed = fs.existsSync(ASSET_PATH) ? fs.readFileSync(ASSET_PATH, 'utf8') : '';
    if (committed !== text) {
      process.stdout.write('設定介面曝露面已漂移。請跑 `make surface` 後提交。\n');
      process.exit(1);
    }
    process.stdout.write('設定介面曝露面：' + sorted.length + ' 鍵（無漂移）\n');
    return;
  }
  fs.writeFileSync(ASSET_PATH, text, 'utf8');
  process.stdout.write(
    '設定介面曝露面已更新：' + sorted.length + ' 鍵（掃描 ' + files.length + ' 檔）；' +
    '注音排列 ' + keyboardParsers.zhuyin.length + ' 項、拼音排列 ' + keyboardParsers.pinyin.length + ' 項，' +
    '分隔線 ' + JSON.stringify(keyboardParsers.dividerBefore) + '\n'
  );
}

if (require.main === module) main();
