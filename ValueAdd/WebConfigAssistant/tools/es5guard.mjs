// 唯音輸入法配置助手之 ES5 語法守衛（零 npm 相依）。
//
// 為何需要：本機之 TypeScript 為 7.x（Go 原生版），其已**移除** `target: es5` 與
// `module: none` 兩個選項（實測：`error TS5108`）。故本專案改以 `target: es2015` 編譯、
// 並以「原始碼一律採 ES5 寫法（`var` ＋ `function` ＋ 字串相加、不用箭頭函式／樣板字串／
// 解構／展開／`class`）」為紀律；本守衛即該紀律之機器檢查——掃描**建置產物**而非原始碼，
// 故能同時抓出 tsc 自行注入之 ES6+ 語法。
//
// 用途：`node tools/es5guard.mjs <file.js> [<file.js> ...]`（獨立執行時，有違規即 exit 1）；
// 亦由 `tools/build.mjs` 以模組方式呼叫。

import fs from 'node:fs';

// ES6+ 語法（Safari 7 不支援者）。
const SYNTAX_RULES = [
  { name: 'arrow-function', pattern: /=>/ },
  { name: 'let-declaration', pattern: /(^|[^\w$.])let\s/ },
  { name: 'const-declaration', pattern: /(^|[^\w$.])const\s/ },
  { name: 'template-literal', pattern: /`/ },
  { name: 'class-declaration', pattern: /(^|[^\w$.])class\s+[\w$]/ },
  { name: 'spread-or-rest', pattern: /\.\.\./ },
  { name: 'for-of', pattern: /(^|[^\w$.])for\s*\([^)]*\bof\b/ },
  { name: 'async-function', pattern: /(^|[^\w$.])async\s/ },
  { name: 'await-expression', pattern: /(^|[^\w$.])await\s/ },
  { name: 'generator-function', pattern: /(^|[^\w$.])function\s*\*/ },
  { name: 'yield-expression', pattern: /(^|[^\w$.])yield\s/ },
  { name: 'default-parameter', pattern: /(^|[^\w$.])function\s*[\w$]*\s*\([^)]*[^=!<>]=[^=]/ },
  { name: 'object-shorthand', pattern: /\{\s*[\w$]+\s*[,}]/ },
];

// ES6+ 標準庫 API（語法合法、但 Safari 7 沒有）。
const API_RULES = [
  { name: 'Array.from', pattern: /(^|[^\w$.])Array\.from\s*\(/ },
  { name: 'Array.prototype.includes', pattern: /\.includes\s*\(/ },
  { name: 'String.prototype.startsWith', pattern: /\.startsWith\s*\(/ },
  { name: 'String.prototype.endsWith', pattern: /\.endsWith\s*\(/ },
  { name: 'String.prototype.padStart', pattern: /\.padStart\s*\(/ },
  { name: 'Object.assign', pattern: /(^|[^\w$.])Object\.assign\s*\(/ },
  { name: 'Object.entries', pattern: /(^|[^\w$.])Object\.entries\s*\(/ },
  { name: 'Object.values', pattern: /(^|[^\w$.])Object\.values\s*\(/ },
  { name: 'Promise', pattern: /(^|[^\w$.])Promise\b/ },
  { name: 'Symbol', pattern: /(^|[^\w$.])Symbol\b/ },
  { name: 'Map', pattern: /(^|[^\w$.])new\s+Map\s*\(/ },
  { name: 'Set', pattern: /(^|[^\w$.])new\s+Set\s*\(/ },
  { name: 'NodeList.forEach', pattern: /querySelectorAll[\s\S]{0,80}?\.forEach\s*\(/ },
];

// 模組系統殘留（本專案之產物必須是「全域 script」，不得有 CJS／ESM 之痕跡）。
const MODULE_RULES = [
  { name: 'commonjs-require', pattern: /(^|[^\w$.])require\s*\(/ },
  { name: 'commonjs-exports', pattern: /(^|[^\w$.])exports\./ },
  { name: 'esm-import', pattern: /(^|[^\w$.])import\s+[\w${*]/ },
  { name: 'esm-export', pattern: /(^|[^\w$.])export\s+(default|const|let|var|function|class|\{)/ },
];

const KEYWORD_BEFORE_REGEX = [
  'return', 'typeof', 'instanceof', 'in', 'of', 'new', 'delete', 'void', 'case', 'do', 'else', 'yield', 'await',
];
const PUNCTUATION_BEFORE_REGEX = '(,=:[!&|?{};+-*%~^<>';

/// 把字串／樣板／註解／正則字面量之內容替換為空白（保留換行，俾使行號不變）。
export function stripLiterals(code) {
  const chars = code.split('');
  const out = new Array(chars.length);
  let i = 0;
  let lastSignificant = '';
  const emit = function (index, ch) {
    out[index] = ch === '\n' ? '\n' : ' ';
  };
  while (i < chars.length) {
    const ch = chars[i];
    const next = chars[i + 1];
    if (ch === '/' && next === '/') {
      while (i < chars.length && chars[i] !== '\n') { emit(i, chars[i]); i += 1; }
      continue;
    }
    if (ch === '/' && next === '*') {
      emit(i, ch); emit(i + 1, next); i += 2;
      while (i < chars.length && !(chars[i] === '*' && chars[i + 1] === '/')) { emit(i, chars[i]); i += 1; }
      if (i < chars.length) { emit(i, chars[i]); emit(i + 1, chars[i + 1]); i += 2; }
      continue;
    }
    if (ch === '"' || ch === "'" || ch === '`') {
      const quote = ch;
      emit(i, ch); i += 1;
      while (i < chars.length && chars[i] !== quote) {
        if (chars[i] === '\\') { emit(i, chars[i]); i += 1; }
        if (i < chars.length) { emit(i, chars[i]); i += 1; }
      }
      if (i < chars.length) { emit(i, chars[i]); i += 1; }
      lastSignificant = quote;
      continue;
    }
    if (ch === '/') {
      const wordBefore = /([\w$]+)\s*$/.exec(code.slice(0, i));
      const isRegex = PUNCTUATION_BEFORE_REGEX.indexOf(lastSignificant) >= 0 ||
        (wordBefore !== null && KEYWORD_BEFORE_REGEX.indexOf(wordBefore[1]) >= 0);
      if (isRegex) {
        emit(i, ch); i += 1;
        let inClass = false;
        while (i < chars.length) {
          const c = chars[i];
          if (c === '\\') { emit(i, c); i += 1; if (i < chars.length) { emit(i, chars[i]); i += 1; } continue; }
          if (c === '[') inClass = true;
          if (c === ']') inClass = false;
          if (c === '/' && !inClass) { emit(i, c); i += 1; break; }
          if (c === '\n') break;
          emit(i, c); i += 1;
        }
        lastSignificant = '/';
        continue;
      }
    }
    out[i] = ch;
    if (!/\s/.test(ch)) lastSignificant = ch;
    i += 1;
  }
  return out.join('');
}

/// 掃描一份 JS 原始碼，回傳違規清單（每項含 rule 與 line）。
export function scan(code, rules) {
  const stripped = stripLiterals(code);
  const lines = stripped.split('\n');
  const violations = [];
  const activeRules = rules || SYNTAX_RULES.concat(API_RULES).concat(MODULE_RULES);
  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    for (let r = 0; r < activeRules.length; r += 1) {
      if (activeRules[r].pattern.test(line)) {
        violations.push({ rule: activeRules[r].name, line: index + 1, text: code.split('\n')[index].trim() });
      }
    }
  }
  return violations;
}

/// 供建置器使用：檢查一段產物，違規則擲出例外。
export function assertEs5(code, label) {
  const violations = scan(code);
  if (violations.length === 0) return;
  let message = 'ES5 守衛失敗（' + label + '）：\n';
  for (let i = 0; i < violations.length && i < 20; i += 1) {
    message += '  - L' + violations[i].line + ' [' + violations[i].rule + '] ' + violations[i].text + '\n';
  }
  if (violations.length > 20) message += '  …（共 ' + violations.length + ' 筆）\n';
  throw new Error(message);
}

const invokedPath = process.argv[1] || '';
if (invokedPath.endsWith('es5guard.mjs')) {
  const files = process.argv.slice(2);
  if (files.length === 0) {
    process.stdout.write('用法：node tools/es5guard.mjs <file.js> [...]\n');
    process.exit(2);
  }
  let failed = 0;
  for (const file of files) {
    const code = fs.readFileSync(file, 'utf8');
    const violations = scan(code);
    if (violations.length === 0) {
      process.stdout.write('OK   ' + file + '\n');
    } else {
      failed += 1;
      process.stdout.write('FAIL ' + file + '（' + violations.length + ' 筆）\n');
      for (const v of violations.slice(0, 20)) {
        process.stdout.write('   - L' + v.line + ' [' + v.rule + '] ' + v.text + '\n');
      }
    }
  }
  process.exit(failed === 0 ? 0 : 1);
}
