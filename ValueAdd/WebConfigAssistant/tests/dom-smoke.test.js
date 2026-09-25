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
  // 預設即「只套用起始配置」之快速路線：全程四頁（事主 2026-09-25）。
  assert.strictEqual(segments.length, 4, '分段方塊之數目應等於頁數');
  assert.ok(win.textContent.indexOf('第 1 步，共 4 步') >= 0);

  // 標題帶右側：步數文字與分段方塊為兩個相鄰之 span，且**不得**有關閉鈕
  //（事主 2026-09-24：取消已由底部按鈕承擔，關閉鈕非必需）。
  const titlebar = win.querySelectorAll('.vca-titlebar')[0];
  assert.ok(titlebar, '應有標題帶');
  const segsHosts = titlebar.querySelectorAll('.vca-seg-host');
  assert.strictEqual(segsHosts.length, 1, '分段方塊應置於 .vca-seg-host 之內');
  assert.strictEqual(segsHosts[0].childNodes.length, 4);
  assert.strictEqual(findByTag(titlebar, 'button').length, 0, '標題帶不應有任何按鈕');
  const rightHosts = titlebar.querySelectorAll('.vca-titlebar-right');
  assert.strictEqual(rightHosts.length, 1, '標題帶右側應為單一容器（inline-table）');
  const rightChildren = [];
  for (const child of rightHosts[0].childNodes) {
    if (child.nodeType === 1) rightChildren.push(String(child.className));
  }
  // 兩個格位：步數文字、分段方塊（各自 `display: table-cell` ＋ `vertical-align: middle`）。
  assert.deepStrictEqual(rightChildren, ['vca-titlebar-progress', 'vca-seg-host']);
  assert.strictEqual(rightHosts[0].textContent.indexOf('第 1 步，共 4 步'), 0,
    '步數文字應在方塊之前');
  assert.strictEqual(segsHosts[0].parentNode, rightHosts[0], '分段方塊應為右側容器之直接子節點');
});

test('冒煙：左側水印區之第三行說明當前頁面之職能', function () {
  const { dom, VCA } = bootApp('?lang=zh-Hant');
  const leftNote = function () {
    const nodes = dom.root.querySelectorAll('.vca-left-note');
    return nodes.length === 1 ? nodes[0].textContent : null;
  };
  const leftTitle = function () {
    const nodes = dom.root.querySelectorAll('.vca-left-title');
    return nodes.length === 1 ? nodes[0].textContent : null;
  };
  const appTitle = VCA.UI_STRINGS['zh-Hant']['app.title'];

  assert.strictEqual(leftNote(), '說明本助手的用途與流程', '首頁應說明助手之用途');
  assert.notStrictEqual(leftNote(), appTitle, '第三行不得再是助手全稱（與標題帶重複）');
  assert.strictEqual(leftTitle(), appTitle, '第二行仍是助手全稱');

  clickNext(dom); // background
  assert.strictEqual(leftTitle(), '您的輸入習慣');
  assert.strictEqual(leftNote(), '決定推薦內容與後續頁面');
  clickNext(dom); // starter
  assert.strictEqual(leftTitle(), '起始配置');
  assert.strictEqual(leftNote(), '可先套用，亦可略過');

  // 逐項路線上亦逐頁有別。
  enableDetailSteps(dom);
  assert.ok(gotoStep(dom, '選字窗'));
  assert.strictEqual(leftNote(), '選字窗的外觀與操作');
  assert.ok(gotoStep(dom, '進階選項'));
  assert.strictEqual(leftNote(), '疑難排解與特殊客體');
  for (let i = 0; i < 20 && stepTitle(dom) !== '摘要與產生'; i += 1) clickNext(dom);
  assert.strictEqual(leftNote(), '核對內容並產生配置包');
});

test('冒煙：快速路線——只套用起始配置即四頁走完', function () {
  const { dom, VCA } = bootApp('?lang=zh-Hant');
  assert.strictEqual(VCA.buildSteps({ origin: 'newbie', typing: 'unsure' }, null, true).length, 4);
  const seen = [];
  for (let i = 0; i < 3; i += 1) {
    seen.push(stepTitle(dom));
    clickNext(dom);
  }
  assert.deepStrictEqual(seen, ['歡迎使用唯音輸入法配置助手', '您的輸入習慣', '起始配置']);
  const summary = contentOf(dom).textContent;
  assert.ok(summary.indexOf('摘要與產生') >= 0, '末頁應為摘要頁');
  assert.ok(summary.indexOf('接下來怎麼做？') >= 0);
  // 起始配置**預設即套用**（事主 2026-09-25：「使用者叫出這個配置畫面就是為了想切換配置的」）
  // ⇒ 即使一題未答，配置包亦非空：其內容為「鍵全集皆回歸出廠預設」。
  assert.ok(summary.indexOf('上列每一項都由此配置決定') >= 0, '應為已套用起始配置之摘要');
  assert.strictEqual(summary.indexOf('您尚未表態任何項目'), -1, '預設套用之下不應再是空包');
  assert.ok(dom.root.textContent.indexOf('第 4 步，共 4 步') >= 0, '末頁應為第四頁');
});

test('冒煙：逐項微調路線——取消勾選後十三頁皆可走完，且末頁為摘要', function () {
  const { dom, VCA } = bootApp('?lang=zh-Hant');
  clickNext(dom); // 背景
  clickNext(dom); // 起始配置
  assert.strictEqual(stepTitle(dom), '起始配置');
  assert.strictEqual(enableDetailSteps(dom), false, '取消勾選後即展開逐項頁面');
  const seen = [];
  for (let i = 0; i < 20; i += 1) {
    seen.push(stepTitle(dom));
    if (stepTitle(dom) === '摘要與產生') break;
    clickNext(dom);
  }
  // 十三頁：四頁之快速路線 ＋ 九頁之逐項問題。
  assert.strictEqual(VCA.buildSteps({ origin: 'newbie', typing: 'unsure' }, null, false).length, 13);
  assert.deepStrictEqual(seen, [
    '起始配置', '打字方式', '打字節奏與聲調', '按鍵行為', '選字窗', '中英混打',
    '標點、數字與符號', '辭典與智慧功能', '通知與系統整合', '進階選項', '摘要與產生',
  ]);
  assert.ok(contentOf(dom).textContent.indexOf('接下來怎麼做？') >= 0);
});

/// 當前頁之標題（`.vca-h1`）；無者回空字串。
function stepTitle(dom) {
  const nodes = contentOf(dom).querySelectorAll('.vca-h1');
  return nodes.length > 0 ? nodes[0].textContent : '';
}

/// 一路按「下一步」直到該頁之標題為 `title`；抵達摘要仍未遇者回 false。
function gotoStep(dom, title) {
  for (let i = 0; i < 20; i += 1) {
    if (stepTitle(dom) === title) return true;
    if (stepTitle(dom) === '摘要與產生') return false;
    clickNext(dom);
  }
  return false;
}

/// 走到某個逐項頁面（途中於起始配置頁取消「只套用起始配置」）。
///
/// 不拘當前在第幾頁——先走到起始配置頁（快速路線下必經），再展開逐項頁面。
function gotoDetailStep(dom, title) {
  if (!gotoStep(dom, '起始配置')) throw new Error('應可抵達起始配置頁');
  enableDetailSteps(dom);
  if (!gotoStep(dom, title)) throw new Error('走不到該頁：' + title);
  return true;
}

/// 於指定題目內點選某一**選項**（不含「維持不變」列）。
///
/// 以**行首**比對：選項列之文字為「選項標籤 ＋ 註記」，而「維持不變」列之註記會引用
/// 該題之出廠預設值——若用 `indexOf` 任憑片段出現，就會誤中「維持不變」列。
function pickChoice(dom, questionId, fragment) {
  const radios = findByTag(contentOf(dom), 'input').filter(function (input) {
    return input.type === 'radio' && String(input.name) === 'vca-group-' + questionId;
  });
  for (const radio of radios) {
    if (radio.parentNode.textContent.indexOf(fragment) === 0) {
      radio.click();
      return true;
    }
  }
  return false;
}

/// 摘要頁之配置包物件（自動展開 JSON 文字區）。
function presetObject(dom) {
  const links = findByTag(contentOf(dom), 'a');
  for (const link of links) {
    if (link.textContent.indexOf('顯示配置包內容') >= 0) { link.onclick(); break; }
  }
  const areas = findByTag(contentOf(dom), 'textarea');
  if (areas.length !== 1) throw new Error('摘要頁應顯示 JSON 文字區');
  return JSON.parse(areas[0].value);
}

/// 於起始配置頁取消勾選「只套用起始配置」，令後面的逐項頁面展開。
function enableDetailSteps(dom) {
  const boxes = findByTag(contentOf(dom), 'input').filter(function (input) {
    return input.type === 'checkbox' &&
      input.parentNode.textContent.indexOf('只套用起始配置') >= 0;
  });
  if (boxes.length !== 1) throw new Error('起始配置頁應恰有一個「只套用起始配置」核取項');
  boxes[0].click();
  return boxes[0].checked;
}

/// 起始配置頁之兩個取捨項（「不套用」／「套用這組起始配置」）。
function starterRadios(dom) {
  return findByTag(contentOf(dom), 'input').filter(function (input) {
    return input.type === 'radio' && String(input.name) === 'vca-group-starter';
  });
}

/// 於指定題目（`vca-group-<questionId>`）內點選含某片段之選項。
///
/// 非用 `pickRadio` 不可者：背景頁同時有「來源」與「打字方式」兩題，同一片段
/// （如「漢語拼音」）可能同時命中兩題之選項。
function pickRadioIn(dom, questionId, fragment) {
  const radios = findByTag(contentOf(dom), 'input').filter(function (input) {
    return input.type === 'radio' && String(input.name) === 'vca-group-' + questionId;
  });
  for (const radio of radios) {
    if (radio.parentNode.textContent.indexOf(fragment) >= 0) {
      radio.click();
      return true;
    }
  }
  return false;
}

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
  const { dom } = bootApp('?lang=zh-Hant');
  // 第二頁（背景）：兩個分支樞紐同頁——「原本用哪一款輸入法」與「主要用哪一種打字方式」。
  clickNext(dom);
  const background = contentOf(dom).textContent;
  assert.ok(background.indexOf('您原本用哪一款輸入法') >= 0);
  assert.ok(background.indexOf('您主要用哪一種打字方式') >= 0, '打字方式一題應與來源同頁');
  assert.ok(pickRadioIn(dom, 'origin', '我是全新使用者'), '應可點選「全新使用者」');
  assert.ok(pickRadioIn(dom, 'typing', '逐字選字'), '應可點選「逐字選字」');
  // 第三頁（起始配置）：**不套用**，逕行逐項微調。
  clickNext(dom);
  assert.strictEqual(stepTitle(dom), '起始配置');
  assert.strictEqual(starterRadios(dom).length, 2, '起始配置頁應有兩個取捨項');
  assert.strictEqual(enableDetailSteps(dom), false);
  clickNext(dom); // method
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
  // 分支題目（拼音排列、磁帶）之**作答**不得出現；惟兩鍵屬起始配置之鍵全集，故以
  // 「回歸出廠預設」之身分入包（此即封閉性：換人套用時不留前一位使用者之痕跡）。
  assert.strictEqual(parsed['KeyboardParser4Pinyin'], 100, '回歸段應為出廠預設');
  assert.strictEqual(parsed['CassetteEnabled'], false, '回歸段應為出廠預設');
  // 全集之外者仍一概不碰（進階頁未勾「以推薦值補齊」者亦然）。
  assert.strictEqual(typeof parsed['_DebugMode'], 'undefined');

  const steps = VCA.buildSteps({ origin: 'newbie', typing: 'scpc' }, null, false);
  assert.strictEqual(steps.length, 13);
});

/// 回歸段之逐項核取項（以 `data-focus-key` 之 `starter-reset-<rawValue>` 對位）。
function resetBoxes(dom) {
  const out = {};
  for (const input of findByTag(contentOf(dom), 'input')) {
    if (input.type !== 'checkbox') continue;
    const key = String(input.getAttribute('data-focus-key') || '');
    if (key.indexOf('starter-reset-') === 0) out[key.slice('starter-reset-'.length)] = input;
  }
  return out;
}

/// 某段之「全部取消勾選／全部勾選」連結（緊貼該段標題，故以標題文字辨識）。
function blockAllLink(dom, headingFragment) {
  const links = findByTag(contentOf(dom), 'a').filter(function (link) {
    const parentText = link.parentNode ? link.parentNode.textContent : '';
    const isToggle = link.textContent === '全部取消勾選' || link.textContent === '全部勾選';
    return isToggle && parentText.indexOf(headingFragment) === 0;
  });
  return links.length === 1 ? links[0] : null;
}

function resetAllLink(dom) {
  return blockAllLink(dom, '一併回歸唯音出廠預設的項目');
}

function namedAllLink(dom) {
  return blockAllLink(dom, '本組指名的項目');
}

/// 指名段之逐項核取項（`data-focus-key` 之 `starter-named-<rawValue>`）。
function namedBoxes(dom) {
  const out = {};
  for (const input of findByTag(contentOf(dom), 'input')) {
    if (input.type !== 'checkbox') continue;
    const key = String(input.getAttribute('data-focus-key') || '');
    if (key.indexOf('starter-named-') === 0) out[key.slice('starter-named-'.length)] = input;
  }
  return out;
}

test('冒煙：回歸段為逐項核取清單（預設全選）', function () {
  const { dom, VCA } = bootApp('?lang=zh-Hant');
  clickNext(dom); // background
  assert.ok(pickRadioIn(dom, 'origin', '微軟新注音'));
  assert.ok(pickRadioIn(dom, 'typing', '逐字選字'));
  clickNext(dom); // starter
  const starter = VCA.starterFor({ origin: 'msnewphonetic', typing: 'scpc' }, null);
  starterRadios(dom)[1].click(); // 套用

  // ① 預設：回歸段逐項皆勾選，且鍵集恰為回歸段。
  const boxes = resetBoxes(dom);
  assert.deepStrictEqual(Object.keys(boxes).sort(), starter.resetKeys.slice().sort(),
    '核取清單應恰對位回歸段');
  for (const raw of starter.resetKeys) {
    assert.strictEqual(boxes[raw].checked, true, '預設應全選：' + raw);
  }
  assert.strictEqual(allTableRows(dom).length, starter.keys.length, '全選時應列出全集');
  assert.ok(contentOf(dom).textContent.indexOf('一併回歸唯音出廠預設的項目') >= 0);
  // 題庫外之鍵（關聯詞語模式）應以 app 既有之顯示名呈現，而非 rawValue。
  const previewText = contentOf(dom).textContent;
  assert.ok(previewText.indexOf('關聯詞語模式') >= 0, '關聯詞語應以顯示名呈現');
  assert.strictEqual(previewText.indexOf('AssociatedPhrasesEnabled'), -1,
    '不得對使用者印出 rawValue');

  // ② 逐項取消：該鍵不得寫入，其餘仍在。
  boxes['CassetteEnabled'].click();
  assert.strictEqual(resetBoxes(dom)['CassetteEnabled'].checked, false);
  assert.ok(contentOf(dom).textContent.indexOf('您取消了 1 項的回歸') >= 0, '說明應隨之改口');
  clickNext(dom); // 摘要
  const partial = presetObject(dom);
  assert.strictEqual(typeof partial['CassetteEnabled'], 'undefined', '取消者不得寫入');
  assert.strictEqual(partial['UseSCPCTypingMode'], true, '指名者仍須寫入');
  assert.strictEqual(partial['AssociatedPhrasesEnabled'], true, '未取消之回歸項仍須寫入');
  assert.ok(contentOf(dom).textContent.indexOf('您取消了 1 項的回歸出廠預設') >= 0,
    '摘要頁之說明亦應改口');

  // ③ 全部取消 ⇒ 只寫指名段（回到稀疏）；摘要頁之說明亦隨之。
  findButtonByText(dom.root, '＜ 上一步').onclick();
  resetAllLink(dom).onclick();
  // 清單本身仍在（否則使用者無從再勾回），惟各項皆已取消勾選。
  const afterUncheckAll = resetBoxes(dom);
  assert.strictEqual(Object.keys(afterUncheckAll).length, starter.resetKeys.length);
  for (const raw of starter.resetKeys) {
    assert.strictEqual(afterUncheckAll[raw].checked, false, '應已全部取消：' + raw);
  }
  assert.strictEqual(resetAllLink(dom).textContent, '全部勾選');
  clickNext(dom); // 摘要
  const lean = presetObject(dom);
  assert.strictEqual(Object.keys(lean).length - 1, starter.namedKeys.length);
  assert.strictEqual(lean['AssociatedPhrasesEnabled'], true,
    '關聯詞語由ㄅ半指名，故全部取消回歸時仍須寫入');
  assert.ok(contentOf(dom).textContent.indexOf('本配置只寫入您表態的項目') >= 0);

  // ④ 全部勾選 ⇒ 恢復封閉全集。
  findButtonByText(dom.root, '＜ 上一步').onclick();
  resetAllLink(dom).onclick();
  assert.strictEqual(resetAllLink(dom).textContent, '全部取消勾選');
  clickNext(dom); // 摘要
  const closed = presetObject(dom);
  assert.strictEqual(Object.keys(closed).length - 1, starter.keys.length, '全選時應寫入全集');
  assert.strictEqual(closed['CassetteEnabled'], false, '回歸段應回歸出廠預設');
});

test('冒煙：指名段亦為逐項核取清單（預設全選、可逐項取消）', function () {
  const { dom, VCA } = bootApp('?lang=zh-Hant');
  clickNext(dom); // background
  assert.ok(pickRadioIn(dom, 'origin', '微軟新注音'));
  assert.ok(pickRadioIn(dom, 'typing', '逐字選字'));
  clickNext(dom); // starter（預設已套用）
  const starter = VCA.starterFor({ origin: 'msnewphonetic', typing: 'scpc' }, null);

  // ① 預設：指名段逐項皆勾選，且鍵集恰對位指名段。
  const boxes = namedBoxes(dom);
  assert.deepStrictEqual(Object.keys(boxes).sort(), starter.namedKeys.slice().sort(),
    '核取清單應恰對位指名段');
  for (const raw of starter.namedKeys) {
    assert.strictEqual(boxes[raw].checked, true, '預設應全選：' + raw);
  }
  // 兩段各有一條同名連結，且各自緊貼其段之標題（作用範圍一眼可辨）。
  assert.ok(namedAllLink(dom), '指名段應有「全部取消勾選」連結');
  assert.ok(resetAllLink(dom), '回歸段應有「全部取消勾選」連結');
  assert.notStrictEqual(namedAllLink(dom), resetAllLink(dom), '兩段之連結不得為同一條');

  // ② 逐項取消指名項：該鍵不得寫入，其餘（含回歸段）仍在；兩處文案皆改口。
  boxes['UseSCPCTypingMode'].click();
  assert.strictEqual(namedBoxes(dom)['UseSCPCTypingMode'].checked, false);
  assert.ok(contentOf(dom).textContent.indexOf('您取消了 1 項指名項目') >= 0);
  clickNext(dom); // 摘要
  const partial = presetObject(dom);
  assert.strictEqual(typeof partial['UseSCPCTypingMode'], 'undefined', '取消之指名項不得寫入');
  assert.strictEqual(partial['CandidateKeys'], '123456789', '其餘指名項仍須寫入');
  assert.strictEqual(partial['CassetteEnabled'], false, '回歸段未動，仍應寫入');
  assert.ok(contentOf(dom).textContent.indexOf('您取消了 1 項指名項目') >= 0,
    '摘要頁亦應載明取消之指名項');

  // ③ 指名段全部取消 ⇒ 只寫回歸段；再全部勾選 ⇒ 恢復全集。
  findButtonByText(dom.root, '＜ 上一步').onclick();
  namedAllLink(dom).onclick();
  for (const raw of starter.namedKeys) {
    assert.strictEqual(namedBoxes(dom)[raw].checked, false, '應已全部取消：' + raw);
  }
  assert.strictEqual(namedAllLink(dom).textContent, '全部勾選');
  clickNext(dom); // 摘要
  const resetOnly = presetObject(dom);
  assert.strictEqual(Object.keys(resetOnly).length - 1, starter.resetKeys.length,
    '指名段全取消時只應寫回歸段');
  assert.strictEqual(typeof resetOnly['UseSCPCTypingMode'], 'undefined');

  findButtonByText(dom.root, '＜ 上一步').onclick();
  namedAllLink(dom).onclick();
  clickNext(dom); // 摘要
  const closed = presetObject(dom);
  assert.strictEqual(Object.keys(closed).length - 1, starter.keys.length, '全選時應寫入全集');
});

test('冒煙：逐項取消回歸時，非ㄅ半之配置亦不寫入題庫外之鍵', function () {
  const { dom, VCA } = bootApp('?lang=zh-Hant');
  clickNext(dom); // background
  assert.ok(pickRadioIn(dom, 'origin', 'macOS 內建注音'));
  assert.ok(pickRadioIn(dom, 'typing', '注音組句（'));
  clickNext(dom); // starter
  const starter = VCA.starterFor({ origin: 'macoszhuyin', typing: 'zhuyin' }, null);
  assert.strictEqual(starter.resetKeys.indexOf('AssociatedPhrasesEnabled') >= 0, true,
    '非ㄅ半者，該鍵應屬回歸段');
  starterRadios(dom)[1].click(); // 套用
  resetBoxes(dom)['AssociatedPhrasesEnabled'].click(); // 逐項取消
  clickNext(dom); // 摘要
  const lean = presetObject(dom);
  assert.strictEqual(Object.keys(lean).length - 1, starter.keys.length - 1,
    '恰少一鍵（取消者）');
  assert.strictEqual(typeof lean['AssociatedPhrasesEnabled'], 'undefined',
    '非ㄅ半且已取消回歸時，該鍵不得寫入');
  assert.strictEqual(lean['UseRearCursorMode'], false, '指名者仍須寫入');
});

test('冒煙：「注音組句＋中英混打」帶出混打回退；狂拼流來源之配置名用短名', function () {
  const { dom } = bootApp('?lang=zh-Hant');
  clickNext(dom); // background
  assert.ok(pickRadioIn(dom, 'origin', '我是全新使用者'));
  assert.ok(pickRadioIn(dom, 'typing', '中英混打'),
    '打字方式一題應有「注音組句＋中英混打」之手足');
  clickNext(dom); // starter
  starterRadios(dom)[1].click(); // 套用
  const rows = summaryRows(dom);
  const row = rows.filter(function (cells) { return cells[0] === '啟用中英混合輸入回退'; })[0];
  assert.ok(row, '起始配置應含混打回退：' + JSON.stringify(rows));
  assert.strictEqual(row[1], '啟用');
  clickNext(dom); // 摘要
  assert.strictEqual(presetObject(dom)['MixedAlphanumericalEnabled'], true);

  // 狂拼流來源：選項顯示全名，內文與配置名用短名。
  const { dom: dom2 } = bootApp('?lang=zh-Hant');
  clickNext(dom2); // background
  const background = contentOf(dom2).textContent;
  assert.ok(background.indexOf('狂拼流漢語拼音輸入法（微軟拼音／微信輸入法／搜狗拼音／昇陽拼音／智能狂拼／紫光拼音／Rime）') >= 0,
    '來源一項應並列產品名：' + background.slice(0, 400));
  assert.ok(pickRadioIn(dom2, 'origin', '狂拼流'));
  assert.ok(pickRadioIn(dom2, 'typing', '漢語拼音'));
  clickNext(dom2); // starter
  const lead = contentOf(dom2).textContent;
  assert.ok(lead.indexOf('您原本使用的是「狂拼流漢語拼音輸入法」') >= 0,
    '起始配置頁之內文應用短名：' + lead.slice(0, 300));
  starterRadios(dom2)[1].click();
  clickNext(dom2); // 摘要
  const parsed = presetObject(dom2);
  assert.strictEqual(parsed.__UserDefMeta.title, '狂拼流漢語拼音輸入法的起始配置',
    '配置名應用短名');
  // 兩條 Shift 鍵亦應寫入（現代系統；測試環境之 UA 為 10.15.7）。
  assert.strictEqual(parsed['TogglingAlphanumericalModeWithLShift'], true);
  assert.strictEqual(parsed['TogglingAlphanumericalModeWithRShift'], true);
});

test('冒煙：起始配置——套用、預覽、撤回與預設配置名', function () {
  const { dom, VCA } = bootApp('?lang=zh-Hant');
  const profile = { origin: 'msnewphonetic', typing: 'scpc' };
  const starter = VCA.starterFor(profile, null);
  assert.ok(starter.keys.length > 0, '微軟新注音＋逐字選字應有起始配置');
  const askedKeys = VCA.allQuestionKeys();
  for (const raw of starter.keys) {
    const entry = VCA.entryByRawValue(raw);
    assert.ok(entry, '起始配置之鍵須存在於後設資料：' + raw);
    const presetOnly = VCA.PRESET_ONLY_KEYS.indexOf(entry.key) >= 0;
    assert.ok(presetOnly || askedKeys.indexOf(entry.key) >= 0,
      '起始配置之鍵須落在題庫內（題庫外者僅限 PRESET_ONLY_KEYS）：' + raw);
    assert.strictEqual(VCA.validateValue(entry, starter.values[raw]), null,
      '起始配置之值須通過後端驗證：' + raw);
  }

  clickNext(dom); // background
  assert.ok(pickRadioIn(dom, 'origin', '微軟新注音'));
  assert.ok(pickRadioIn(dom, 'typing', '逐字選字'));
  clickNext(dom); // starter
  assert.strictEqual(stepTitle(dom), '起始配置');
  const radios = starterRadios(dom);
  assert.strictEqual(radios.length, 2, '應恰有「不套用」與「套用」兩項');
  // 預設即「套用」——使用者叫出這個配置畫面就是為了想切換配置（事主 2026-09-25）。
  assert.strictEqual(radios[1].checked, true, '預設應為「套用這組起始配置」');
  assert.strictEqual(radios[0].checked, false);
  assert.ok(contentOf(dom).textContent.indexOf('本組指名的項目') >= 0,
    '預設即套用 ⇒ 一進該頁就應列出兩段內容');

  radios[1].click(); // 再點一次仍為套用（冪等）
  const preview = contentOf(dom).textContent;
  assert.ok(preview.indexOf('本組指名的項目') >= 0, '套用後應列出本組指名之項目');
  assert.ok(preview.indexOf('一併回歸唯音出廠預設的項目') >= 0, '並應列出回歸出廠預設之項目');
  assert.strictEqual(summaryRows(dom).length, starter.namedKeys.length,
    '第一段（指名）之列數應等於指名之鍵數');
  assert.strictEqual(allTableRows(dom).length, starter.keys.length,
    '兩段預覽之列數合計應等於全集之鍵數');

  clickNext(dom); // 快速路線：下一步即摘要
  assert.ok(dom.root.textContent.indexOf('第 4 步，共 4 步') >= 0);
  const parsed = presetObject(dom);
  assert.strictEqual(parsed['UseSCPCTypingMode'], true, '起始配置應寫入「ㄅ半」一鍵');
  assert.strictEqual(Object.keys(parsed).length - 1, starter.keys.length,
    '配置包之鍵數應等於起始配置之鍵數');
  assert.strictEqual(parsed.__UserDefMeta.title, '微軟新注音（Windows）的起始配置',
    '已套用起始配置時，預設配置名應說明來歷');

  // 回上一步取消套用 → 配置包應回到「未表態任何項目」。
  findButtonByText(dom.root, '＜ 上一步').onclick();
  assert.strictEqual(stepTitle(dom), '起始配置');
  starterRadios(dom)[0].click();
  clickNext(dom);
  assert.ok(contentOf(dom).textContent.indexOf('您尚未表態任何項目') >= 0,
    '取消套用後配置包應為空');
  const emptied = presetObject(dom);
  assert.strictEqual(Object.keys(emptied).length, 1, '只餘中介辭典');
  assert.strictEqual(emptied.__UserDefMeta.title, '自訂配置');
});

test('冒煙：起始配置頁之提醒，與「跳到摘要」之往返', function () {
  const { dom } = bootApp('?lang=zh-Hant');
  clickNext(dom); // background
  clickNext(dom); // starter
  const text = contentOf(dom).textContent;
  assert.ok(text.indexOf('多數使用者到這裡就夠了') >= 0,
    '應提醒可提前結束助手：' + text.slice(0, 240));
  assert.strictEqual(contentOf(dom).querySelectorAll('.vca-note-box').length, 1,
    '提醒應以唯讀欄位（白底內凹框）呈現');

  const skip = findButtonByText(dom.root, '跳到摘要 ＞');
  assert.ok(skip, '底列應有「跳到摘要」鈕');
  assert.strictEqual(skip.style.display, 'none', '快速路線下（只差一頁）不露面');

  // 展開逐項頁面之後該鈕露面；按之即到摘要，按「上一步」應回到跳轉前所在之頁。
  enableDetailSteps(dom);
  assert.strictEqual(skip.style.display, '', '逐項路線下應露面');
  assert.ok(gotoStep(dom, '按鍵行為'));
  skip.onclick();
  assert.ok(contentOf(dom).textContent.indexOf('摘要與產生') >= 0);
  findButtonByText(dom.root, '＜ 上一步').onclick();
  assert.strictEqual(stepTitle(dom), '按鍵行為', '「上一步」應回到跳轉前之頁，而非最後一頁');
});

test('冒煙：起始配置不覆蓋使用者親自之表態', function () {
  const { dom, VCA } = bootApp('?lang=zh-Hant');
  clickNext(dom); // background
  assert.ok(pickRadioIn(dom, 'origin', '微軟新注音'));
  assert.ok(pickRadioIn(dom, 'typing', '逐字選字'));
  clickNext(dom); // starter
  starterRadios(dom)[1].click(); // 套用
  enableDetailSteps(dom);

  // 親自把「選字游標」改為詞語前方（與起始配置之推薦值相反）。
  assert.ok(gotoStep(dom, '選字窗'));
  assert.ok(pickChoice(dom, 'kUseRearCursorMode', '將游標置於詞語前方'),
    '應可改選「將游標置於詞語前方」');
  for (let i = 0; i < 20 && stepTitle(dom) !== '摘要與產生'; i += 1) clickNext(dom);
  const applied = presetObject(dom);
  assert.strictEqual(applied['UseRearCursorMode'], false, '使用者之表態應優先');

  // 回起始配置頁取消套用：使用者親自改過者必須留下，其餘撤回。
  for (let i = 0; i < 20 && stepTitle(dom) !== '起始配置'; i += 1) {
    findButtonByText(dom.root, '＜ 上一步').onclick();
  }
  assert.strictEqual(stepTitle(dom), '起始配置');
  starterRadios(dom)[0].click();
  for (let i = 0; i < 20 && stepTitle(dom) !== '摘要與產生'; i += 1) clickNext(dom);
  const after = presetObject(dom);
  assert.strictEqual(after['UseRearCursorMode'], false, '親自改過者不因取消套用而消失');
  assert.strictEqual(typeof after['UseSCPCTypingMode'], 'undefined',
    '未經使用者表態之起始配置項應已撤回');
  assert.strictEqual(VCA.starterFor({ origin: 'msnewphonetic', typing: 'scpc' }, null).keys.length > 1, true);
});

test('冒煙：快速路線上之值仍以選項標籤呈現（標籤索引不隨流程模式增減）', function () {
  const { dom } = bootApp('?lang=zh-Hant');
  clickNext(dom); // background
  assert.ok(pickRadioIn(dom, 'origin', '微軟新注音'));
  assert.ok(pickRadioIn(dom, 'typing', '漢語拼音'));
  clickNext(dom); // starter（快速路線：逐項頁面不在流程內）
  assert.strictEqual(stepTitle(dom), '起始配置');
  assert.strictEqual(enableDetailSteps(dom), false, '取消勾選即展開逐項頁面');
  starterRadios(dom)[1].click(); // 套用
  // 預覽表：拼音排列之值應為標籤，而非裸數字 100。
  const preview = summaryRows(dom);
  assert.ok(preview.length > 0, '套用後應有預覽表');
  const previewPinyin = preview.filter(function (cells) { return cells[0] === '拼音輸入種類'; })[0];
  assert.ok(previewPinyin, '預覽表應有「拼音輸入種類」一列：' + JSON.stringify(preview));
  assert.strictEqual(previewPinyin[1], '漢語拼音+數字標調');
  const barePreview = preview.filter(function (cells) { return cells[1] === '100'; });
  assert.deepStrictEqual(barePreview, [], '預覽表不應出現裸數字');

  // 回到快速路線並走到摘要：摘要表亦同。
  assert.strictEqual(enableDetailSteps(dom), true, '再勾選即回到快速路線');
  clickNext(dom);
  assert.ok(dom.root.textContent.indexOf('第 4 步，共 4 步') >= 0);
  const rows = summaryRows(dom);
  const pinyinRow = rows.filter(function (cells) { return cells[0] === '拼音輸入種類'; })[0];
  assert.ok(pinyinRow, '摘要表應有「拼音輸入種類」一列：' + JSON.stringify(rows));
  assert.strictEqual(pinyinRow[1], '漢語拼音+數字標調');
  const bare = rows.filter(function (cells) { return cells[1] === '100'; });
  assert.deepStrictEqual(bare, [], '摘要表不應出現裸數字');
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
  assert.ok(pickRadioIn(dom, 'origin', '微軟新注音'), '應可點選「微軟新注音」');
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
  assert.ok(pickRadioIn(dom, 'origin', '微軟新注音'), '應可點選「微軟新注音」');
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
  clickNext(dom); // background
  clickNext(dom); // starter
  enableDetailSteps(dom);
  assert.ok(gotoStep(dom, '打字節奏與聲調'), '應可抵達「打字節奏與聲調」一頁');
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
  gotoDetailStep(dom, '標點、數字與符號');
  const punctuation = contentOf(dom);
  assert.ok(punctuation.textContent.indexOf('指定數字小鍵盤的輸入行為。') >= 0,
    '短說明應直接內聯');
  const numpad = VCA.entryByKey('kNumPadCharInputBehavior');
  assert.ok(numpad && numpad.options.length > 0);
  assert.strictEqual(punctuation.textContent.indexOf('可輸入 0 ～ 5'), -1,
    '單選題不應出現「可輸入」之值域提示');

  // 選字窗一頁：字級為數值題，應有值域提示。
  const { dom: dom2 } = bootApp('?lang=zh-Hant');
  gotoDetailStep(dom2, '選字窗');
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
  // 背景頁有兩題（來源、打字方式），各帶一個「深入說明 →」；未選來源時同指新手上路。
  assert.strictEqual(docLinks.length, 2, '背景頁應有兩個官網連結');
  assert.strictEqual(docLinks[0].href, PREFIX + 'onboarding/');
  assert.strictEqual(docLinks[1].href, PREFIX + 'onboarding/');
  // 選了來源輸入法之後，該頁之連結應改指對應文章。
  assert.ok(pickRadioIn(dom, 'origin', '微軟新注音'));
  links = findByTag(contentOf(dom), 'a');
  docLinks = links.filter(function (a) { return a.href.indexOf(PREFIX) === 0; });
  assert.strictEqual(docLinks.length, 2);
  assert.strictEqual(docLinks[0].href, PREFIX + 'manual/onboarding_msnewphonetic.html');
  // 起始配置一頁：同指該來源之文章（該組配置之依據）。
  clickNext(dom); // starter
  assert.strictEqual(stepTitle(dom), '起始配置');
  links = findByTag(contentOf(dom), 'a');
  docLinks = links.filter(function (a) { return a.href.indexOf(PREFIX) === 0; });
  assert.strictEqual(docLinks.length, 1, '起始配置頁應有一個官網連結');
  assert.strictEqual(docLinks[0].href, PREFIX + 'manual/onboarding_msnewphonetic.html');
  enableDetailSteps(dom);
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

/// 內容區內**所有**表格之資料列（起始配置之預覽分「指名」與「回歸」兩段）。
function allTableRows(dom) {
  const rows = [];
  for (const table of findByTag(contentOf(dom), 'table')) {
    for (const row of findByTag(table, 'tr')) {
      const cells = findByTag(row, 'td').map(function (cell) { return cell.textContent; });
      if (cells.length === 2) rows.push(cells);
    }
  }
  return rows;
}

test('冒煙：值一律以選項標籤呈現（排列類不得顯示裸數字）', function () {
  const { dom } = bootApp('?lang=zh-Hant');
  clickNext(dom); // background
  assert.ok(pickRadioIn(dom, 'origin', '微軟新注音'));
  assert.ok(pickRadioIn(dom, 'typing', '漢語拼音'));
  gotoDetailStep(dom, '打字方式');

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
  for (let i = 0; i < 20; i += 1) {
    if (stepTitle(dom) === '摘要與產生') break;
    clickNext(dom);
    tickFill(dom);
  }
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
  assert.ok(pickRadioIn(dom, 'origin', '微軟新注音'));
  assert.ok(pickRadioIn(dom, 'typing', '注音組句'));
  gotoDetailStep(dom, '打字方式');
  const text = contentOf(dom).textContent;
  assert.ok(text.indexOf('出廠預設為：大千排列') >= 0,
    '注音排列之出廠預設值應以排列名稱呈現：' + text.slice(0, 400));
});

test('冒煙：注音排列之順序與分隔線與設定介面一致', function () {
  const { dom } = bootApp('?lang=zh-Hant');
  clickNext(dom); // background
  assert.ok(pickRadioIn(dom, 'origin', '微軟新注音'));
  assert.ok(pickRadioIn(dom, 'typing', '注音組句'));
  gotoDetailStep(dom, '打字方式');
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

test('靜態產物：dist/index.html 自動跳轉至 assistant.html', function () {
  const fs = require('node:fs');
  const path = require('node:path');
  const file = path.join(__dirname, '..', 'dist', 'index.html');
  assert.ok(fs.existsSync(file), 'make bundle 應另生 dist/index.html（目錄入口頁）');
  const html = fs.readFileSync(file, 'utf8');
  assert.ok(html.indexOf('http-equiv="refresh"') >= 0 && html.indexOf('url=assistant.html') >= 0,
    '應以 meta refresh 自動跳轉至 assistant.html');
  assert.ok(html.indexOf('href="assistant.html"') >= 0, '應附手動連結之後備');
  assert.ok(html.indexOf('唯音輸入法配置助手') >= 0, '入口頁之標題應為助手之全稱');
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
  assert.ok(pickRadioIn(dom, 'origin', 'macOS 內建注音'), '來源清單應有 macOS 內建注音一項');
  const text = contentOf(dom).textContent;
  // 接待說明：明示「唯音預設即照內建注音的習慣」。
  assert.ok(text.indexOf('唯音的預設值就是照 macOS 10.9 開始的內建注音的習慣來的') >= 0,
    '應顯示該來源之接待說明：' + text.slice(0, 240));
  assert.strictEqual(contentOf(dom).querySelectorAll('.vca-note-box').length, 1);
  // 文章連結：指向新增之 onboarding 文章（用戶端 permalink）。
  const links = findByTag(contentOf(dom), 'a').filter(function (a) {
    return a.href.indexOf('https://vchewing.github.io/') === 0;
  });
  // 兩題各一連結（來源題與打字方式題），皆指該來源之文章。
  assert.strictEqual(links.length, 2, '應有兩個官網連結');
  assert.strictEqual(links[0].href,
    'https://vchewing.github.io/manual/onboarding_macOSZhuyinSinceSnowLeopard.html');
  assert.strictEqual(links[1].href,
    'https://vchewing.github.io/manual/onboarding_macOSZhuyinSinceSnowLeopard.html');
  // 起始配置一頁亦指該文章，且該來源之起始配置為「有內容、但不改動唯音預設」之一組。
  clickNext(dom);
  assert.strictEqual(stepTitle(dom), '起始配置');
  assert.ok(contentOf(dom).textContent.indexOf('您原本使用的是「macOS 內建注音') >= 0,
    '應點明該組配置所對應之來源');

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
