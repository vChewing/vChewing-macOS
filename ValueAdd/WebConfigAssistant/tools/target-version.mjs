// 助手所適配之輸入法版本：讀取、注入與防漂移比對（零 npm 相依）。
//
// 助手側之單一事實來源為本目錄之 `version.txt`；倉庫側之 SSOT 為倉根之
// `Release-Version.plist`（`Plugins/BundleApps/plugin.swift` 明文稱之為
// "the single source of truth"）。兩者須一致——`node tools/target-version.mjs --check`
// 即該比對（`make version-check`，已納入 `make audit`）。
//
// 用法：node tools/target-version.mjs [--check]

import fs from 'node:fs';
import path from 'node:path';
import url from 'node:url';
import { execFileSync } from 'node:child_process';

const ROOT = path.resolve(path.dirname(url.fileURLToPath(import.meta.url)), '..');
const VERSION_TXT = path.join(ROOT, 'version.txt');
const REPO_PLIST = path.join(ROOT, '..', '..', 'Release-Version.plist');

/// 讀取並解析 `version.txt`（`key=value`；`#` 起頭為註解）。
export function readTargetVersion() {
  if (!fs.existsSync(VERSION_TXT)) {
    throw new Error('找不到 version.txt：' + VERSION_TXT);
  }
  const values = {};
  for (const rawLine of fs.readFileSync(VERSION_TXT, 'utf8').split('\n')) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#')) continue;
    const separator = line.indexOf('=');
    if (separator < 0) throw new Error('version.txt 之此行不是 key=value：' + rawLine);
    values[line.slice(0, separator).trim()] = line.slice(separator + 1).trim();
  }
  const version = values.version;
  const build = values.build;
  if (!version || !build) {
    throw new Error('version.txt 缺 version 或 build 之其一。');
  }
  if (!/^[0-9]+(\.[0-9]+)*$/.test(version)) throw new Error('version 之形制不合法：' + version);
  if (!/^[0-9]+$/.test(build)) throw new Error('build 之形制不合法：' + build);
  return { version: version, build: build, display: version + ' (' + build + ')' };
}

/// 讀取倉根 `Release-Version.plist`（以 `plutil` 轉為 JSON，避免自寫 plist 解析器）。
function readRepoVersion() {
  if (!fs.existsSync(REPO_PLIST)) {
    throw new Error('找不到 Release-Version.plist：' + REPO_PLIST);
  }
  const json = execFileSync('plutil', ['-convert', 'json', '-o', '-', REPO_PLIST], { encoding: 'utf8' });
  const parsed = JSON.parse(json);
  return {
    version: String(parsed.CFBundleShortVersionString || ''),
    build: String(parsed.CFBundleVersion || ''),
  };
}

function main() {
  const check = process.argv.indexOf('--check') >= 0;
  const target = readTargetVersion();
  if (!check) {
    process.stdout.write('助手適配之版本：' + target.display + '\n');
    return;
  }
  const repo = readRepoVersion();
  if (repo.version !== target.version || repo.build !== target.build) {
    process.stdout.write(
      'version.txt 與 Release-Version.plist 不一致：\n' +
      '  version.txt            ' + target.version + ' (' + target.build + ')\n' +
      '  Release-Version.plist  ' + repo.version + ' (' + repo.build + ')\n' +
      '請同步 version.txt（本目錄）。\n'
    );
    process.exit(1);
  }
  process.stdout.write('版本一致：' + target.display + '（對照 Release-Version.plist）\n');
}

const invokedPath = process.argv[1] || '';
if (invokedPath.endsWith('target-version.mjs')) main();
