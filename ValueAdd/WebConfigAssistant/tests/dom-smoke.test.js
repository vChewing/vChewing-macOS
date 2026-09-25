'use strict';
// 端到端冒煙測試：以 DOM 替身驅動**完整**之 dist/app.js（含外框、控制項、導覽、摘要與出口）。
//
// 驗證：掛載無例外、逐步導覽可走完十二頁、作答會反映到配置包、摘要頁產出合法之 JSON、
// 語言切換不重置答案、取消對話框可清空作答。

const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { createDom, installDom, findByTag, findButtonByText } = require('./dom-shim');

const APP_PATH = path.join(__dirname, '..', 'dist', 'app.js');

function bootApp(query) {
  const dom = createDom();
  installDom(dom);
  dom.window.location.search = query || '';
  // 每次都重新載入產物：助手之狀態存於 namespace IIFE 之閉包內，重載即重新初始化。
  vm.runInThisContext(fs.readFileSync(APP_PATH, 'utf8'), { filename: APP_PATH });
  globalThis.VCA.boot();
  return { dom: dom, VCA: globalThis.VCA };
}

function contentOf(dom) {
  const contents = dom.root.querySelectorAll('vca-content');
  // `querySelectorAll` 只支援 class 選擇器，故改用逐層走訪。
  const results = [];
  const walk = function (node) {
    if (node.nodeType === 1 && String(node.className).indexOf('vca-content') >= 0) results.push(node);
    if (node.nodeType !== 1) return;
    for (const child of node.childNodes) walk(child);
  };
  walk(dom.root);
  return results.length > 0 ? results[0] : null;
}

function clickNext(dom) {
  const buttons = findByTag(dom.root, 'button');
  for (const button of buttons) {
    const text = button.textContent;
    if (text === '下一步 ＞' || text === '完成' || text === 'Next >' || text === 'Finish') {
      button.onclick();
      return text;
    }
  }
  throw new Error('找不到「下一步」按鈕');
}

test('冒煙：掛載後之 DOM 結構（Win2000 外框）', function () {
  const { dom } = bootApp('?lang=zh-Hant');
  const windows = [];
  const walk = function (node) {
    if (node.nodeType === 1 && String(node.className).indexOf('vca-window') >= 0) windows.push(node);
    if (node.nodeType !== 1) return;
    for (const child of node.childNodes) walk(child);
  };
  walk(dom.root);
  assert.strictEqual(windows.length, 1, '應恰有一個 .vca-window');
  const win = windows[0];
  // 產品名一律取 app l10n 之全稱（`i18n:Common.VChewing`）＋「配置助手」。
  assert.ok(win.textContent.indexOf('唯音輸入法配置助手') >= 0, '標題帶應顯示助手之全稱');
  assert.strictEqual(win.textContent.indexOf('唯音配置助手'), -1, '不得再出現舊的簡稱');
  assert.ok(win.textContent.indexOf('歡迎使用唯音輸入法配置助手') >= 0, '首頁應為歡迎頁');

  // 進度字樣與分段方塊：十二頁。
  // 類名一律以**逐詞**比對——`.vca-seg-host`（分段方塊之容器）含 `vca-seg` 之前綴，
  // 以 `indexOf` 比對會把它一併算進去。
  const hasClass = function (node, className) {
    if (!node.className) return false;
    return String(node.className).split(/\s+/).indexOf(className) >= 0;
  };
  const segments = [];
  const walkSeg = function (node) {
    if (node.nodeType === 1 && hasClass(node, 'vca-seg')) segments.push(node);
    if (node.nodeType !== 1) return;
    for (const child of node.childNodes) walkSeg(child);
  };
  walkSeg(win);
  assert.strictEqual(segments.length, 12, '分段方塊之數目應等於頁數');
  assert.ok(win.textContent.indexOf('第 1 步，共 12 步') >= 0);

  // 標題帶右側：步數文字與分段方塊為兩個相鄰之 span，且**不得**有關閉鈕
  //（事主 2026-09-24：取消已由底部按鈕承擔，關閉鈕非必需）。
  const titlebar = win.querySelectorAll('.vca-titlebar')[0];
  assert.ok(titlebar, '應有標題帶');
  const segsHosts = titlebar.querySelectorAll('.vca-seg-host');
  assert.strictEqual(segsHosts.length, 1, '分段方塊應置於 .vca-seg-host 之內');
  assert.strictEqual(segsHosts[0].childNodes.length, 12);
  assert.strictEqual(findByTag(titlebar, 'button').length, 0, '標題帶不應有任何按鈕');
  const rightHosts = titlebar.querySelectorAll('.vca-titlebar-right');
  assert.strictEqual(rightHosts.length, 1, '標題帶右側應為單一容器（inline-table）');
  const rightChildren = [];
  for (const child of rightHosts[0].childNodes) {
    if (child.nodeType === 1) rightChildren.push(String(child.className));
  }
  // 兩個格位：步數文字、分段方塊（各自 `display: table-cell` ＋ `vertical-align: middle`）。
  assert.deepStrictEqual(rightChildren, ['vca-titlebar-progress', 'vca-seg-host']);
  assert.strictEqual(rightHosts[0].textContent.indexOf('第 1 步，共 12 步'), 0,
    '步數文字應在方塊之前');
  assert.strictEqual(segsHosts[0].parentNode, rightHosts[0], '分段方塊應為右側容器之直接子節點');
});

test('冒煙：十二頁皆可走完，且末頁為摘要', function () {
  const { dom } = bootApp('?lang=zh-Hant');
  const seen = [];
  for (let i = 0; i < 11; i += 1) {
    seen.push(contentOf(dom).textContent.slice(0, 40));
    clickNext(dom);
  }
  const summary = contentOf(dom).textContent;
  assert.ok(summary.indexOf('摘要與產生') >= 0, '末頁應為摘要頁');
  assert.ok(summary.indexOf('接下來怎麼做？') >= 0);
  assert.ok(summary.indexOf('您尚未表態任何項目') >= 0, '未作答時應提示尚無內容');
  assert.strictEqual(seen.length, 11);
});

function pickRadio(dom, fragment) {
  const radios = findByTag(contentOf(dom), 'input');
  for (const radio of radios) {
    if (radio.type !== 'radio') continue;
    if (radio.parentNode.textContent.indexOf(fragment) >= 0) {
      radio.click();
      return true;
    }
  }
  return false;
}

function tickFill(dom) {
  const checkboxes = findByTag(contentOf(dom), 'input').filter(function (i) {
    return i.type === 'checkbox' && i.parentNode.textContent.indexOf('補齊本頁未答') >= 0;
  });
  if (checkboxes.length !== 1) return false;
  checkboxes[0].click();
  return true;
}

test('冒煙：作答會反映到配置包（並遵守稀疏與分支）', function () {
  const { dom, VCA } = bootApp('?lang=zh-Hant');
  // 第二頁（分支樞紐）：選「我是全新使用者」。
  clickNext(dom);
  assert.ok(contentOf(dom).textContent.indexOf('您原本用哪一款輸入法') >= 0);
  assert.ok(pickRadio(dom, '我是全新使用者'), '應可點選「全新使用者」');
  // 第三頁（打字方式）：選「注音逐字選字（ㄅ半派）」。
  clickNext(dom);
  assert.ok(contentOf(dom).textContent.indexOf('您主要用哪一種打字方式') >= 0);
  assert.ok(pickRadio(dom, '逐字選字'), '應可點選「逐字選字」');
  const methodText = contentOf(dom).textContent;
  assert.ok(methodText.indexOf('模擬 90 年代前期注音逐字選字輸入風格') >= 0, 'SCPC 分支題目應出現');
  assert.ok(methodText.indexOf('注音排列') >= 0, '注音排列一題應出現');
  assert.strictEqual(methodText.indexOf('拼音輸入種類'), -1, '拼音排列一題應被分支濾除');
  assert.strictEqual(methodText.indexOf('磁帶'), -1, '磁帶一題應被分支濾除');

  // 逐頁勾「以推薦值補齊」：配置包即應含各頁之處方。
  assert.ok(tickFill(dom), '打字方式一頁應有「以推薦值補齊」之核取項');
  clickNext(dom); // rhythm
  assert.ok(tickFill(dom));
  clickNext(dom); // keys
  assert.ok(tickFill(dom));
  clickNext(dom); // candidate
  assert.ok(contentOf(dom).textContent.indexOf('選字窗') >= 0);
  assert.ok(tickFill(dom));
  clickNext(dom); // mixed
  assert.ok(tickFill(dom));
  clickNext(dom); // punctuation
  assert.ok(tickFill(dom));
  clickNext(dom); // lexicon
  assert.ok(tickFill(dom));
  clickNext(dom); // notify
  assert.ok(tickFill(dom));
  clickNext(dom); // advanced（**刻意不勾**：驗證「未勾之頁面完全不輸出」）
  assert.ok(contentOf(dom).textContent.indexOf('進階選項') >= 0);
  // 走到摘要頁檢視配置包。
  clickNext(dom);
  assert.ok(contentOf(dom).textContent.indexOf('摘要與產生') >= 0);
  const links = findByTag(contentOf(dom), 'a');
  for (const link of links) {
    if (link.textContent.indexOf('顯示配置包內容') >= 0) { link.onclick(); break; }
  }
  const area = findByTag(contentOf(dom), 'textarea')[0];
  const parsed = JSON.parse(area.value);
  assert.strictEqual(parsed['UseSCPCTypingMode'], true, '推薦值應已寫入配置包');
  assert.strictEqual(parsed['CandidateKeys'], '123456789');
  assert.strictEqual(parsed['UseHorizontalCandidateList'], false);
  // 「以推薦值補齊」之語意：該頁未答者以推薦值補之；無推薦值者以**出廠預設值**補之
  //（此為明示且逐頁之行為，故逐頁之未答項皆會被寫入）。
  assert.strictEqual(parsed['InlineDumpPinyinInLieuOfZhuyin'], false);
  assert.ok(typeof parsed['CandidateListTextSize'] === 'number');
  // 未勾「以推薦值補齊」之頁面（進階）：一個鍵都不得輸出。
  assert.strictEqual(typeof parsed['_DebugMode'], 'undefined');
  assert.strictEqual(typeof parsed['UsingHotKeySCPC'], 'undefined');
  // 分支題目（拼音排列、磁帶）不得出現。
  assert.strictEqual(typeof parsed['KeyboardParser4Pinyin'], 'undefined');
  assert.strictEqual(typeof parsed['CassetteEnabled'], 'undefined');

  const steps = VCA.buildSteps({ origin: 'newbie', typing: 'scpc' }, null);
  assert.strictEqual(steps.length, 12);
});

test('冒煙：摘要頁之 JSON 與按鈕', function () {
  const { dom } = bootApp('?lang=zh-Hant');
  for (let i = 0; i < 11; i += 1) clickNext(dom);
  // 直接注入答案（模擬已作答），再重繪。
  const textareas = findByTag(contentOf(dom), 'textarea');
  assert.strictEqual(textareas.length, 0, '預設不顯示 JSON');
  const links = findByTag(contentOf(dom), 'a');
  let toggled = false;
  for (const link of links) {
    if (link.textContent.indexOf('顯示配置包內容') >= 0) {
      link.onclick();
      toggled = true;
      break;
    }
  }
  assert.ok(toggled, '應有「顯示配置包內容」之連結');
  const shown = findByTag(contentOf(dom), 'textarea');
  assert.strictEqual(shown.length, 1, '點選後應顯示 JSON 文字區');
  const parsed = JSON.parse(shown[0].value);
  assert.ok(parsed.__UserDefMeta, '配置包應含中介辭典');
  assert.strictEqual(parsed.__UserDefMeta.title, '自訂配置');
  const copyButtons = findByTag(contentOf(dom), 'button');
  const labels = copyButtons.map(function (b) { return b.textContent; });
  assert.ok(labels.indexOf('拷貝配置資料') >= 0, '應有拷貝按鈕：' + labels.join('|'));
  assert.ok(labels.indexOf('下載配置檔案') >= 0, '應有下載按鈕');
});

test('冒煙：語言切換不重置答案', function () {
  const { dom } = bootApp('?lang=zh-Hant');
  clickNext(dom);
  assert.ok(pickRadio(dom, '微軟新注音'), '應可點選「微軟新注音」');
  // 回首頁切語言。
  const buttons = findByTag(dom.root, 'button');
  for (const button of buttons) {
    if (button.textContent === '＜ 上一步') { button.onclick(); break; }
  }
  const selects = findByTag(contentOf(dom), 'select');
  assert.strictEqual(selects.length, 1, '首頁應有語言選單');
  selects[0].value = 'en';
  selects[0].onchange();
  // 再前進：微軟新注音之選取應仍在（以英文介面顯示）。
  clickNext(dom);
  const english = contentOf(dom).textContent;
  assert.ok(english.indexOf('Which input method') >= 0, '介面應已切為英文：' + english.slice(0, 80));
  const englishRadios = findByTag(contentOf(dom), 'input');
  let checkedCount = 0;
  for (const radio of englishRadios) {
    if (radio.type === 'radio' && radio.checked) checkedCount += 1;
  }
  assert.strictEqual(checkedCount, 1, '先前的作答應仍為選中狀態');
});

test('冒煙：取消對話框會清空作答', function () {
  const { dom } = bootApp('?lang=zh-Hant');
  clickNext(dom);
  assert.ok(pickRadio(dom, '微軟新注音'), '應可點選「微軟新注音」');
  // 按取消 → 對話框出現 → 按「確定」。
  const cancel = findButtonByText(dom.root, '取消');
  assert.ok(cancel, '應有取消按鈕');
  cancel.onclick();
  const dialogYes = findButtonByText(dom.document.body, '確定');
  assert.ok(dialogYes, '應出現確認對話框');
  dialogYes.onclick();
  // 回到首頁；再前進時，先前之選取應已清空。
  assert.ok(contentOf(dom).textContent.indexOf('歡迎使用唯音輸入法配置助手') >= 0);
  clickNext(dom);
  const after = findByTag(contentOf(dom), 'input');
  let checked = 0;
  for (const radio of after) {
    if (radio.type === 'radio' && radio.checked) checked += 1;
  }
  assert.strictEqual(checked, 0, '取消後不應殘留任何選取');
});

test('冒煙：鍵盤導覽（Alt+← 上一步）', function () {
  const { dom } = bootApp('?lang=zh-Hant');
  clickNext(dom);
  assert.ok(contentOf(dom).textContent.indexOf('您原本用哪一款輸入法') >= 0);
  dom.window.onkeydown({ keyCode: 37, altKey: true, target: dom.document.body });
  assert.ok(contentOf(dom).textContent.indexOf('歡迎使用唯音輸入法配置助手') >= 0, 'Alt+← 應回到上一頁');
});

test('冒煙：「維持不變」右側標明保留之對象與該項之出廠預設值', function () {
  const { dom } = bootApp('?lang=zh-Hant');
  // 走到「打字節奏與聲調」一頁（該頁之題目皆為一般設定項，皆帶「維持不變」）。
  for (let i = 0; i < 3; i += 1) clickNext(dom);
  const content = contentOf(dom);
  const options = content.querySelectorAll('.vca-opt');
  let keepRow = null;
  for (const option of options) {
    if (option.textContent.indexOf('維持不變') === 0) { keepRow = option; break; }
  }
  assert.ok(keepRow, '應有「維持不變」之選項列');
  assert.ok(keepRow.textContent.indexOf('保留您目前在唯音內的設定值') >= 0,
    '應說明保留之對象：' + keepRow.textContent);
  assert.ok(keepRow.textContent.indexOf('出廠預設為：') >= 0,
    '應附出廠預設值：' + keepRow.textContent);
  const notes = content.querySelectorAll('.vca-opt-note');
  assert.ok(notes.length > 0, '註記應以 .vca-opt-note 呈現');
});

test('冒煙：短說明直接內聯、長說明仍收於折疊區；值域提示只給數值題', function () {
  const { dom, VCA } = bootApp('?lang=zh-Hant');
  // 走到「標點、數字與符號」一頁（其「數字小鍵盤」一題之說明僅一句）。
  // 頁序：0 歡迎、1 來源、2 打字方式、3 節奏、4 按鍵、5 選字窗、6 中英混打、7 標點。
  for (let i = 0; i < 7; i += 1) clickNext(dom);
  const punctuation = contentOf(dom);
  assert.ok(punctuation.textContent.indexOf('指定數字小鍵盤的輸入行為。') >= 0,
    '短說明應直接內聯');
  const numpad = VCA.entryByKey('kNumPadCharInputBehavior');
  assert.ok(numpad && numpad.options.length > 0);
  assert.strictEqual(punctuation.textContent.indexOf('可輸入 0 ～ 5'), -1,
    '單選題不應出現「可輸入」之值域提示');

  // 選字窗一頁（頁序 5）：字級為數值題，應有值域提示。
  const { dom: dom2 } = bootApp('?lang=zh-Hant');
  for (let i = 0; i < 5; i += 1) clickNext(dom2);
  const candidate = contentOf(dom2);
  assert.ok(candidate.textContent.indexOf('可輸入 12 ～ 196') >= 0,
    '數值題應顯示值域提示');
  assert.ok(candidate.querySelectorAll('.vca-hint').length > 0);
});

test('冒煙：「深入說明」連結指向官網之絕對位址與真實 permalink', function () {
  const { dom } = bootApp('?lang=zh-Hant');
  const PREFIX = 'https://vchewing.github.io/';
  // 方法頁：通用文章。
  clickNext(dom); // background
  let links = findByTag(contentOf(dom), 'a');
  let docLinks = links.filter(function (a) { return a.href.indexOf(PREFIX) === 0; });
  assert.strictEqual(docLinks.length, 1, '背景頁應有一個官網連結');
  assert.strictEqual(docLinks[0].href, PREFIX + 'onboarding/');
  // 選了來源輸入法之後，該頁之連結應改指對應文章。
  assert.ok(pickRadio(dom, '微軟新注音'));
  links = findByTag(contentOf(dom), 'a');
  docLinks = links.filter(function (a) { return a.href.indexOf(PREFIX) === 0; });
  assert.strictEqual(docLinks.length, 1);
  assert.strictEqual(docLinks[0].href, PREFIX + 'manual/onboarding_msnewphonetic.html');
  // 其餘各頁：偏好設定一文。
  clickNext(dom); // method
  links = findByTag(contentOf(dom), 'a');
  docLinks = links.filter(function (a) { return a.href.indexOf(PREFIX) === 0; });
  assert.ok(docLinks.length >= 1);
  assert.strictEqual(docLinks[0].href, PREFIX + 'manual/preferences.html');
});

function summaryRows(dom) {
  const tables = findByTag(contentOf(dom), 'table');
  if (tables.length === 0) return [];
  return findByTag(tables[0], 'tr').map(function (row) {
    return findByTag(row, 'td').map(function (cell) { return cell.textContent; });
  }).filter(function (cells) { return cells.length === 2; });
}

test('冒煙：值一律以選項標籤呈現（排列類不得顯示裸數字）', function () {
  const { dom } = bootApp('?lang=zh-Hant');
  clickNext(dom); // background
  assert.ok(pickRadio(dom, '微軟新注音'));
  clickNext(dom); // method
  assert.ok(pickRadio(dom, '漢語拼音'));

  // ① 「推薦值」一列：應為標籤。
  const method = contentOf(dom).textContent;
  assert.ok(method.indexOf('推薦值：漢語拼音+數字標調') >= 0,
    '推薦值應以標籤呈現：' + method.slice(0, 400));
  assert.strictEqual(method.indexOf('推薦值：100'), -1, '不得顯示裸數字');
  // ② 「維持不變」之註記：該題之出廠預設值亦應為標籤。
  assert.ok(method.indexOf('出廠預設為：漢語拼音+數字標調') >= 0,
    '出廠預設值應以標籤呈現');

  // ③ 摘要表：該列之值亦應為標籤。
  assert.ok(tickFill(dom));
  for (let i = 0; i < 9; i += 1) { clickNext(dom); tickFill(dom); }
  const rows = summaryRows(dom);
  assert.ok(rows.length > 10, '摘要表列數過少：' + rows.length);
  const pinyinRow = rows.filter(function (cells) { return cells[0] === '拼音輸入種類'; })[0];
  assert.ok(pinyinRow, '摘要表應有「拼音輸入種類」一列');
  assert.strictEqual(pinyinRow[1], '漢語拼音+數字標調');
  const bareNumbers = rows.filter(function (cells) {
    return cells[1] === '100' || cells[1] === '102';
  });
  assert.deepStrictEqual(bareNumbers, [], '摘要表不應出現裸數字：' + JSON.stringify(bareNumbers));
});

test('冒煙：注音排列之「維持不變」註記以排列名稱呈現', function () {
  const { dom } = bootApp('?lang=zh-Hant');
  clickNext(dom); // background
  assert.ok(pickRadio(dom, '微軟新注音'));
  clickNext(dom); // method
  assert.ok(pickRadio(dom, '注音組句'));
  const text = contentOf(dom).textContent;
  assert.ok(text.indexOf('出廠預設為：大千排列') >= 0,
    '注音排列之出廠預設值應以排列名稱呈現：' + text.slice(0, 400));
});

test('冒煙：注音排列之順序與分隔線與設定介面一致', function () {
  const { dom } = bootApp('?lang=zh-Hant');
  clickNext(dom); // background
  assert.ok(pickRadio(dom, '微軟新注音'));
  clickNext(dom); // method
  assert.ok(pickRadio(dom, '注音組句'));
  const content = contentOf(dom);
  let question = null;
  for (const candidate of content.querySelectorAll('.vca-q')) {
    const title = candidate.querySelectorAll('.vca-q-title')[0];
    if (title && title.textContent === '注音排列') { question = candidate; break; }
  }
  assert.ok(question, '應有「注音排列」一題');
  const labels = [];
  let separators = 0;
  for (const child of question.childNodes) {
    if (child.nodeType !== 1) continue;
    const className = String(child.className);
    if (className.indexOf('vca-opt-sep') >= 0) { separators += 1; continue; }
    if (className.indexOf('vca-opt') >= 0) labels.push(child.textContent);
  }
  // 首列為「維持不變」，其後 11 項依 `KeyboardParser.allCases` 之宣告序（非升冪）。
  assert.strictEqual(labels.length, 12, '選項列數應為 12：' + labels.length);
  assert.ok(labels[0].indexOf('維持不變') === 0);
  assert.ok(labels[1].indexOf('大千排列') === 0, labels[1]);
  assert.ok(labels[2].indexOf('倚天傳統排列') === 0, labels[2]);
  assert.ok(labels[3].indexOf('IBM 排列') === 0, labels[3]);
  assert.ok(labels[4].indexOf('神通排列') === 0, labels[4]);
  assert.ok(labels[5].indexOf('精業排列') === 0, labels[5]);
  assert.ok(labels[6].indexOf('偽精業排列') === 0, labels[6]);
  assert.ok(labels[7].indexOf('酷音大千二十六鍵排列') === 0, labels[7]);
  assert.ok(labels[8].indexOf('倚天忘形排列') === 0, labels[8]);
  assert.ok(labels[9].indexOf('許氏國音自然排列') === 0, labels[9]);
  assert.ok(labels[10].indexOf('星光排列') === 0, labels[10]);
  assert.ok(labels[11].indexOf('劉又銘擬音注音排列') === 0, labels[11]);
  assert.strictEqual(separators, 1, '應恰有一條分隔線（在「酷音大千二十六鍵排列」之前）');
});

test('靜態樣式：內容區為固定高度（窗體不隨頁面內容變動）', function () {
  const fs = require('node:fs');
  const path = require('node:path');
  const css = fs.readFileSync(path.join(__dirname, '..', 'assets', 'assistant.css'), 'utf8');
  // 先剃除註解——本檔之註解會提及「max-height」一詞以說明取捨，不剃會誤判。
  const stripped = css.replace(/\/\*[\s\S]*?\*\//g, '');
  const block = /\.vca-content\s*\{([^}]*)\}/.exec(stripped);
  assert.ok(block, '應有 .vca-content 之規則');
  assert.ok(/height:\s*490px/.test(block[1]),
    '內容區應為固定高度（490px）：' + block[1].replace(/\s+/g, ' '));
  assert.strictEqual(/max-height/.test(block[1]), false,
    '不得用 max-height——那會令窗體高度隨頁面內容變動、底部按鈕位移');
  // 小字說明之不透明度。
  // 小字（#114514）：`.vca-rec`／`.vca-opt-note`／`.vca-version` 共用一條選擇器；
  // **不得**以 opacity 代之——半透明會把指定色沖淡，且對黑字幾乎無可見差異。
  const small = /\.vca-rec,\s*\.vca-opt-note,\s*\.vca-version\s*\{([^}]*)\}/.exec(stripped);
  assert.ok(small, '應有 .vca-rec／.vca-opt-note／.vca-version 之共用小字規則');
  assert.ok(/color:\s*#114514/i.test(small[1]),
    '小字應為 #114514：' + small[1].replace(/\s+/g, ' '));
  assert.ok(/font-size:\s*11px/.test(small[1]), '小字應為 11px');
  assert.strictEqual(/opacity/.test(small[1]), false, '不得以 opacity 代替指定色');
  const rec = /\.vca-rec\s*\{([^}]*)\}/.exec(stripped);
  const note = /\.vca-opt-note\s*\{([^}]*)\}/.exec(stripped);
  assert.ok(note && /margin-left:\s*8px/.test(note[1]),
    '小字與「維持不變」之間應有 8px 間距：' + (note ? note[1] : ''));
  assert.ok(rec && /margin:/.test(rec[1]), '推薦值一列應自定其上邊距');
  assert.strictEqual(/color/.test(rec[1]), false, '色應由共用規則給定，勿於此重複');
});

test('冒煙：macOS 內建注音之接待流程（說明、文章連結、推薦值）', function () {
  const { dom, VCA } = bootApp('?lang=zh-Hant');
  clickNext(dom); // background
  assert.ok(pickRadio(dom, 'macOS 內建注音'), '來源清單應有 macOS 內建注音一項');
  const text = contentOf(dom).textContent;
  // 接待說明：明示「唯音預設即照內建注音的習慣」。
  assert.ok(text.indexOf('唯音的預設值就是照 macOS 10.9 開始的內建注音的習慣來的') >= 0,
    '應顯示該來源之接待說明：' + text.slice(0, 240));
  assert.strictEqual(contentOf(dom).querySelectorAll('.vca-note-box').length, 1);
  // 文章連結：指向新增之 onboarding 文章（用戶端 permalink）。
  const links = findByTag(contentOf(dom), 'a').filter(function (a) {
    return a.href.indexOf('https://vchewing.github.io/') === 0;
  });
  assert.strictEqual(links.length, 1, '應恰有一個官網連結');
  assert.strictEqual(links[0].href,
    'https://vchewing.github.io/manual/onboarding_macOSZhuyinSinceSnowLeopard.html');

  // 推薦值：該文章明載之兩項行為，且皆為唯音之出廠預設。
  const steps = VCA.buildSteps({ origin: 'macoszhuyin', typing: 'zhuyin' }, null);
  const byId = {};
  for (const step of steps) {
    for (const question of step.questions) byId[question.id] = question;
  }
  const profile = { origin: 'macoszhuyin', typing: 'zhuyin' };
  assert.strictEqual(VCA.effectiveRecommended(byId['kUseRearCursorMode'], profile), false,
    '選字游標應推薦置於詞語前方（＝內建注音之習慣）');
  assert.strictEqual(VCA.effectiveRecommended(byId['kSpecifyIntonationKeyBehavior'], profile), 0,
    '聲調鍵應推薦覆寫字音');
  // 換成別的來源時，同一題不應沿用該推薦值。
  assert.strictEqual(
    VCA.effectiveRecommended(byId['kSpecifyIntonationKeyBehavior'], { origin: 'kimo', typing: 'zhuyin' }),
    null
  );
});

test('冒煙：首頁之隱私說明（不得再稱「不會連網」）', function () {
  const { dom, VCA } = bootApp('?lang=zh-Hant');
  const welcome = contentOf(dom).textContent;
  assert.ok(welcome.indexOf('不會擅自將您填入的偏好帶離這台電腦') >= 0,
    '應明示「不擅自把偏好帶離本機」：' + welcome.slice(0, 300));
  assert.strictEqual(welcome.indexOf('不會連網'), -1, '不得再出現「不會連網」之說法');
  // 四語系皆不得再有「連網／goes online／ネットワークにも接続」之舊說法。
  for (const lang of VCA.LANG_ORDER) {
    const text = VCA.UI_STRINGS[lang]['welcome.p3'];
    assert.ok(text.indexOf('連網') < 0 && text.indexOf('连网') < 0 &&
      text.indexOf('goes online') < 0 && text.indexOf('ネットワークにも接続') < 0,
      lang + ' 之隱私說明仍為舊說法：' + text);
  }
});

test('冒煙：首頁以 #114514 之小字顯示適配之輸入法版本', function () {
  const fs = require('node:fs');
  const path = require('node:path');
  const { dom, VCA } = bootApp('?lang=zh-Hant');
  const welcome = contentOf(dom);
  const versionNodes = welcome.querySelectorAll('.vca-version');
  assert.strictEqual(versionNodes.length, 1, '首頁應恰有一處版本標示');
  // 值取自 version.txt（助手側之單一事實來源）。
  const raw = fs.readFileSync(path.join(__dirname, '..', 'version.txt'), 'utf8');
  const values = {};
  for (const line of raw.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const separator = trimmed.indexOf('=');
    if (separator > 0) values[trimmed.slice(0, separator).trim()] = trimmed.slice(separator + 1).trim();
  }
  assert.ok(values.version && values.build, 'version.txt 應有 version 與 build');
  const expected = '適配唯音輸入法 ' + values.version + ' (' + values.build + ')';
  assert.strictEqual(versionNodes[0].textContent, expected,
    '版本標示應與 version.txt 一致');
  assert.ok(welcome.textContent.indexOf(expected) >= 0);
});
