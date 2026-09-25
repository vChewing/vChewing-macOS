'use strict';
// 題庫之測試：分頁結構、逐題之鍵對位、選項值之合法性、分支與系統版本之過濾、i18n 之齊備。

const test = require('node:test');
const assert = require('node:assert');
const { loadCore } = require('./core-loader');

const ALL_TYPING = ['zhuyin', 'zhuyinmix', 'scpc', 'pinyin', 'cin', 'unsure'];
// 來源清單一律取自執行期（不手抄——新增來源時本清單自動跟上）。
const ALL_ORIGIN = loadCore().VCA.ORIGIN_VALUES.slice();

function stepsFor(VCA, origin, typing, os, expressOnly) {
  return VCA.buildSteps(
    { origin: origin, typing: typing },
    typeof os === 'undefined' ? null : os,
    expressOnly === true
  );
}

function allQuestions(steps) {
  const out = [];
  for (const step of steps) {
    for (const question of step.questions) out.push(question);
  }
  return out;
}

test('題庫：分頁結構固定', function () {
  const { VCA } = loadCore();
  const steps = stepsFor(VCA, 'newbie', 'unsure');
  assert.deepStrictEqual(steps.map(function (s) { return s.id; }), [
    'welcome', 'background', 'starter', 'method', 'rhythm', 'keys', 'candidate',
    'mixed', 'punctuation', 'lexicon', 'notify', 'advanced', 'summary',
  ]);
  for (const step of steps) {
    if (step.id === 'welcome' || step.id === 'summary') continue;
    assert.ok(step.questions.length > 0, step.id + ' 之題數為 0');
  }
  // 進階頁為「可整頁跳過」。
  const advanced = steps.filter(function (s) { return s.id === 'advanced'; })[0];
  assert.strictEqual(advanced.optional, true);
});

test('題庫：只套用起始配置之快速路線恰為四頁', function () {
  const { VCA } = loadCore();
  assert.deepStrictEqual(VCA.EXPRESS_STEP_IDS, ['welcome', 'background', 'starter', 'summary']);
  for (const origin of ALL_ORIGIN) {
    for (const typing of ALL_TYPING) {
      const steps = stepsFor(VCA, origin, typing, null, true);
      assert.deepStrictEqual(steps.map(function (s) { return s.id; }), VCA.EXPRESS_STEP_IDS,
        origin + '/' + typing + ' 之快速路線頁序不正確');
    }
  }
  // 逐項路線＝快速路線 ＋ 九頁逐項問題。
  const detail = stepsFor(VCA, 'newbie', 'unsure', null, false);
  assert.strictEqual(detail.length, 13);
  for (const id of VCA.EXPRESS_STEP_IDS) {
    assert.ok(detail.map(function (s) { return s.id; }).indexOf(id) >= 0, '逐項路線應含 ' + id);
  }
  // 頁序：起始配置在背景之後、逐項問題之前。
  const ids = detail.map(function (s) { return s.id; });
  assert.strictEqual(ids[1], 'background');
  assert.strictEqual(ids[2], 'starter');
  assert.strictEqual(ids[3], 'method');
  assert.strictEqual(ids[ids.length - 1], 'summary');
});

test('題庫：背景頁收「來源」與「打字方式」兩個分支樞紐', function () {
  const { VCA } = loadCore();
  const steps = stepsFor(VCA, 'newbie', 'unsure');
  const background = steps.filter(function (s) { return s.id === 'background'; })[0];
  assert.deepStrictEqual(background.questions.map(function (q) { return q.id; }), ['origin', 'typing']);
  // 兩者皆為自訂題、不輸出任何鍵。
  for (const question of background.questions) {
    assert.strictEqual(question.entry, null);
    assert.strictEqual(VCA.isBranchOnly(question), true);
  }
  const method = steps.filter(function (s) { return s.id === 'method'; })[0];
  assert.strictEqual(method.questions.map(function (q) { return q.id; }).indexOf('typing'), -1,
    '打字方式不應再出現於打字方式一頁');
});

test('題庫：起始配置之鍵與值皆落在題庫與後端之接受範圍內', function () {
  const { VCA } = loadCore();
  const askedKeys = VCA.allQuestionKeys();
  let total = 0;
  for (const origin of ALL_ORIGIN) {
    for (const typing of ALL_TYPING) {
      const profile = { origin: origin, typing: typing };
      const starter = VCA.starterFor(profile, null);
      assert.strictEqual(starter.id, origin + '|' + typing);
      total += starter.keys.length;
      for (const raw of starter.keys) {
        const entry = VCA.entryByRawValue(raw);
        assert.ok(entry, '起始配置之鍵不存在：' + raw);
        // 題庫外之鍵僅限 `PRESET_ONLY_KEYS`（事主 2026-09-25 裁定；如「ㄅ半模式自動啟用
        // 關聯詞語」之 `kAssociatedPhrasesEnabled`）——其餘一律仍須落在題庫內。
        const presetOnly = VCA.PRESET_ONLY_KEYS.indexOf(entry.key) >= 0;
        assert.ok(presetOnly || askedKeys.indexOf(entry.key) >= 0,
          '起始配置觸及題庫外之鍵（使用者無從於逐題頁面看到）：' + raw);
        if (presetOnly) {
          assert.ok(!entry.exchangeBlacklisted, '題庫外之鍵不得為黑名單：' + raw);
        }
        assert.strictEqual(VCA.validateValue(entry, starter.values[raw]), null,
          origin + '/' + typing + ' 之起始配置值未通過驗證：' + raw);
        // 只收**真有依據**之推薦值；出廠預設值不在起始配置之內。
        assert.strictEqual(VCA.isBranchOnly({ entry: null }), true);
      }
      // 鍵序即 `keys` 之序、且值與 `starterFor` 之回報一致。
      assert.strictEqual(Object.keys(starter.values).length, starter.keys.length);
    }
  }
  assert.ok(total > 0, '全部來源皆無起始配置內容——推薦值表應已涵蓋官網既有之處方');
  // 具體一例：微軟新注音＋逐字選字。
  const scpc = VCA.starterFor({ origin: 'msnewphonetic', typing: 'scpc' }, null);
  assert.strictEqual(scpc.values['UseSCPCTypingMode'], true);
  assert.strictEqual(scpc.values['UseRearCursorMode'], true);
  // 系統版本過舊者不得收到「需要較新系統」之鍵（版本一律以整數版本碼比較，見 schema.ts）。
  for (const origin of ALL_ORIGIN) {
    for (const typing of ALL_TYPING) {
      const starter = VCA.starterFor({ origin: origin, typing: typing }, 1009);
      for (const raw of starter.keys) {
        const minimum = VCA.osVersionCodeFromDouble(VCA.entryByRawValue(raw).minimumOS);
        assert.ok(minimum <= 1009,
          origin + '/' + typing + ' 於 macOS 10.9 之起始配置含過新之鍵：' + raw + '（需 ' + minimum + '）');
      }
    }
  }
});

test('題庫：題目 id 不重複、且逐題對位到合法之 UserDef', function () {
  const { VCA } = loadCore();
  const steps = stepsFor(VCA, 'newbie', 'unsure');
  const seen = {};
  for (const question of allQuestions(steps)) {
    assert.ok(!seen[question.id], '重複之題目 id：' + question.id);
    seen[question.id] = true;
    if (!question.entry) {
      assert.strictEqual(question.kind, 'custom');
      continue;
    }
    assert.strictEqual(question.entry.key, question.id);
    assert.ok(VCA.entryByKey(question.id), '題目之鍵不存在於後設資料：' + question.id);
    assert.ok(!question.entry.exchangeBlacklisted, '題庫觸及黑名單鍵：' + question.id);
    assert.notStrictEqual(question.entry.type, 'dictionary');
  }
});

test('題庫：每個選項之值皆通過後端語意之驗證', function () {
  const { VCA } = loadCore();
  const steps = stepsFor(VCA, 'newbie', 'unsure');
  let checked = 0;
  for (const question of allQuestions(steps)) {
    if (!question.entry) continue;
    for (const choice of question.choices) {
      assert.strictEqual(VCA.validateValue(question.entry, choice.value), null,
        question.id + ' 之選項 ' + JSON.stringify(choice.value) + ' 未通過驗證');
      checked += 1;
    }
    if (question.kind === 'number' && question.range) {
      assert.strictEqual(VCA.validateValue(question.entry, question.range[0]), null);
      assert.strictEqual(VCA.validateValue(question.entry, question.range[1]), null);
      assert.ok(VCA.validateValue(question.entry, question.range[0] - 1) !== null);
      assert.ok(VCA.validateValue(question.entry, question.range[1] + 1) !== null);
    }
  }
  assert.ok(checked > 120, '受檢之選項數過少：' + checked);
});

test('題庫：推薦值一律合法，且與 profile 之對位正確', function () {
  const { VCA } = loadCore();
  for (const typing of ALL_TYPING) {
    for (const origin of ALL_ORIGIN) {
      const steps = stepsFor(VCA, origin, typing);
      for (const question of allQuestions(steps)) {
        if (!question.entry) continue;
        const recommended = VCA.effectiveRecommended(question, { origin: origin, typing: typing });
        if (recommended === null) continue;
        assert.strictEqual(VCA.validateValue(question.entry, recommended), null,
          question.id + ' 於 ' + origin + '/' + typing + ' 之推薦值不合法');
      }
    }
  }
  const scpc = stepsFor(VCA, 'msnewphonetic', 'scpc');
  const byId = {};
  for (const question of allQuestions(scpc)) byId[question.id] = question;
  assert.strictEqual(
    VCA.effectiveRecommended(byId['kUseSCPCTypingMode'], { origin: 'msnewphonetic', typing: 'scpc' }), true);
  assert.strictEqual(
    VCA.effectiveRecommended(byId['kUseSCPCTypingMode'], { origin: 'msnewphonetic', typing: 'zhuyin' }), null);
  assert.strictEqual(
    VCA.effectiveRecommended(byId['kUseRearCursorMode'], { origin: 'msnewphonetic', typing: 'zhuyin' }), true);
  assert.strictEqual(
    VCA.effectiveRecommended(byId['kUseRearCursorMode'], { origin: 'newbie', typing: 'zhuyin' }), null);
});

test('題庫：注音／拼音排列之順序與標籤皆與設定介面同源', function () {
  const { VCA } = loadCore();
  const surface = JSON.parse(
    require('node:fs').readFileSync(require('node:path').join(__dirname, '..', 'assets', 'settings-surface.json'), 'utf8')
  );
  const steps = stepsFor(VCA, 'newbie', 'unsure');
  const byId = {};
  for (const question of allQuestions(steps)) byId[question.id] = question;

  const zhuyin = byId['kKeyboardParser4Zhuyin'];
  assert.ok(zhuyin, '缺注音排列一題');
  // 順序即 `KeyboardParser.allCases` 之宣告序（實查：0,1,4,5,8,6,7,3,2,9,10），非升冪。
  assert.deepStrictEqual(
    zhuyin.choices.map(function (c) { return c.value; }),
    surface.keyboardParsers.zhuyin.map(function (p) { return p.value; })
  );
  assert.deepStrictEqual(
    zhuyin.choices.map(function (c) { return c.value; }),
    [0, 1, 4, 5, 8, 6, 7, 3, 2, 9, 10]
  );
  assert.deepStrictEqual(VCA.entryByKey('kKeyboardParser4Zhuyin').range, [0, 10]);

  const pinyin = byId['kKeyboardParser4Pinyin'];
  assert.ok(pinyin, '缺拼音排列一題');
  assert.deepStrictEqual(
    pinyin.choices.map(function (c) { return c.value; }),
    surface.keyboardParsers.pinyin.map(function (p) { return p.value; })
  );
  assert.deepStrictEqual(
    pinyin.choices.map(function (c) { return c.value; }), [100, 101, 102, 103, 104, 105]
  );
  assert.deepStrictEqual(VCA.entryByKey('kKeyboardParser4Pinyin').range, [100, 105]);

  // 標籤鍵亦須與設定介面同源，且逐選項皆查得四語系之譯文。
  for (const question of [zhuyin, pinyin]) {
    const expectedKeys = question.id === 'kKeyboardParser4Zhuyin'
      ? surface.keyboardParsers.zhuyin : surface.keyboardParsers.pinyin;
    for (let i = 0; i < question.choices.length; i += 1) {
      assert.strictEqual(question.choices[i].i18nKey, expectedKeys[i].i18nKey);
      for (const lang of VCA.LANG_ORDER) {
        const text = VCA.extraLabel(question.choices[i].i18nKey, lang);
        assert.ok(typeof text === 'string' && text.length > 0,
          lang + ' 缺 ' + question.choices[i].i18nKey + ' 之標籤');
      }
    }
  }

  // 分隔線：與設定介面所標者一致，且首項不插（清單之首無從標示分界）。
  const separatorValues = function (question) {
    const out = [];
    for (let i = 0; i < question.choices.length; i += 1) {
      if (question.choices[i].separatorBefore) out.push(question.choices[i].value);
    }
    return out;
  };
  assert.deepStrictEqual(separatorValues(zhuyin), [7]);
  assert.deepStrictEqual(separatorValues(pinyin), []);
  assert.deepStrictEqual(surface.keyboardParsers.dividerBefore, [7, 100]);
});

test('題庫：分支依打字方式過濾', function () {
  const { VCA } = loadCore();
  const idsOf = function (typing) {
    const steps = stepsFor(VCA, 'newbie', typing);
    return allQuestions(steps).map(function (q) { return q.id; });
  };
  const scpc = idsOf('scpc');
  assert.ok(scpc.indexOf('kUseSCPCTypingMode') >= 0);
  assert.ok(scpc.indexOf('kEnforceSingleLineCandidateWindowLayout4SCPC') >= 0);
  assert.strictEqual(scpc.indexOf('kKeyboardParser4Pinyin'), -1);
  assert.strictEqual(scpc.indexOf('kCassetteEnabled'), -1);

  const pinyin = idsOf('pinyin');
  assert.ok(pinyin.indexOf('kKeyboardParser4Pinyin') >= 0);
  assert.strictEqual(pinyin.indexOf('kKeyboardParser4Zhuyin'), -1);
  assert.strictEqual(pinyin.indexOf('kUseSCPCTypingMode'), -1);

  const cin = idsOf('cin');
  assert.ok(cin.indexOf('kCassetteEnabled') >= 0);
  assert.ok(cin.indexOf('kForceCassetteChineseConversion') >= 0);
  assert.strictEqual(cin.indexOf('kKeyboardParser4Zhuyin'), -1);

  // 「還不確定」一律出題（超集）。
  const unsure = idsOf('unsure');
  for (const id of scpc.concat(pinyin).concat(cin)) {
    assert.ok(unsure.indexOf(id) >= 0, 'unsure 應為超集，卻缺：' + id);
  }
});

test('題庫：依系統版本略過過新之選項', function () {
  const { VCA } = loadCore();
  const old = stepsFor(VCA, 'newbie', 'unsure', 1013);
  const notifyOld = old.filter(function (s) { return s.id === 'notify'; })[0];
  assert.ok(notifyOld.skippedByOS >= 3, '舊系統應略過若干選項');
  const oldIds = allQuestions(old).map(function (q) { return q.id; });
  assert.strictEqual(oldIds.indexOf('kShowNotificationsWhenTogglingCapsLock'), -1);
  assert.strictEqual(oldIds.indexOf('kSpecifiedNotifyUIColorScheme'), -1);

  const modern = stepsFor(VCA, 'newbie', 'unsure', 2700);
  const modernIds = allQuestions(modern).map(function (q) { return q.id; });
  assert.ok(modernIds.indexOf('kShowNotificationsWhenTogglingCapsLock') >= 0);
  assert.strictEqual(allQuestions(modern).filter(function (q) { return q.entry; })
    .filter(function (q) { return q.minimumOS > 2700; }).length, 0);
});

test('題庫：所有題目所引用之 i18n 鍵於四語系皆存在', function () {
  const { VCA } = loadCore();
  const steps = stepsFor(VCA, 'newbie', 'unsure');
  const keys = [];
  for (const step of steps) {
    keys.push(step.titleKey, step.noteKey, step.introKey);
    for (const question of step.questions) {
      if (question.titleKey) keys.push(question.titleKey);
      if (question.helpKey) keys.push(question.helpKey);
      for (const choice of question.choices) {
        if (choice.labelKey) keys.push(choice.labelKey);
      }
    }
  }
  for (const lang of VCA.LANG_ORDER) {
    for (const key of keys) {
      const value = VCA.UI_STRINGS[lang][key];
      assert.ok(typeof value === 'string' && value.length > 0, lang + ' 缺介面文案：' + key);
    }
  }
});

/// 以顯示寬度計（CJK 與全形標點算兩格）——左側水印區只有 144px 之文字寬。
function displayWidth(text) {
  let width = 0;
  for (let i = 0; i < text.length; i += 1) {
    width += text.charCodeAt(i) > 0x2000 ? 2 : 1;
  }
  return width;
}

test('題庫：左側水印區之職能說明》（`left.<stepId>`）逐頁具備且不等於助手全稱', function () {
  const { VCA } = loadCore();
  const steps = stepsFor(VCA, 'newbie', 'unsure');
  const seen = {};
  for (const step of steps) {
    assert.strictEqual(step.noteKey, 'left.' + step.id, '職能說明之鍵應為 left.<stepId>');
    for (const lang of VCA.LANG_ORDER) {
      const note = VCA.UI_STRINGS[lang][step.noteKey];
      assert.ok(typeof note === 'string' && note.length > 0,
        lang + ' 缺職能說明：' + step.noteKey);
      assert.notStrictEqual(note, VCA.UI_STRINGS[lang]['app.title'],
        lang + ' 之 ' + step.noteKey + ' 仍是助手全稱（該欄原即為此，事主 2026-09-25 指出）');
      // 左側欄寬度有限（168px，內文約 144px）：說明須短，免得折成多行。
      // 以「顯示寬度」計（CJK 與全形標點算兩格），門檻約當兩行 13 個漢字。
      assert.ok(displayWidth(note) <= 34,
        lang + ' 之 ' + step.noteKey + ' 過長（' + displayWidth(note) + ' 格）：' + note);
    }
    assert.ok(!seen[step.noteKey], '職能說明重複：' + step.noteKey);
    seen[step.noteKey] = true;
  }
  assert.strictEqual(Object.keys(seen).length, steps.length);
});

test('題庫：「ㄅ半」之稱呼', function () {
  const { VCA } = loadCore();
  const expected = {
    'zh-Hant': '注音逐字選字（倚天中文 DOS 系統「ㄅ半」派）',
    'zh-Hans': '注音逐字选字（倚天中文 DOS 系统「ㄅ半」派）',
    en: 'Zhuyin per-character selection (ETen Chinese DOS \"Bo-Ban\")',
    ja: '注音で漢字１つずつ全候補選択（ETen DOS 中国語漢字システムの「ㄅ半」派）',
  };
  for (const lang of VCA.LANG_ORDER) {
    assert.strictEqual(VCA.UI_STRINGS[lang]['typing.opt.scpc'], expected[lang],
      lang + ' 之「ㄅ半」稱呼未依裁定');
  }
});

test('題庫：「注音組句＋中英混打」為「注音組句」之手足', function () {
  const { VCA } = loadCore();
  const idsOf = function (typing) {
    return allQuestions(stepsFor(VCA, 'newbie', typing)).map(function (q) { return q.id; });
  };
  const plain = idsOf('zhuyin');
  const mixed = idsOf('zhuyinmix');
  assert.deepStrictEqual(mixed, plain, '手足之題目集應與「注音組句」完全相同');
  assert.ok(mixed.indexOf('kKeyboardParser4Zhuyin') >= 0, '注音排列一題應在');
  assert.strictEqual(mixed.indexOf('kUseSCPCTypingMode'), -1, '不應帶出逐字選字之題目');
  assert.strictEqual(mixed.indexOf('kKeyboardParser4Pinyin'), -1, '不應帶出拼音排列之題目');
  assert.strictEqual(mixed.indexOf('kCassetteEnabled'), -1, '不應帶出磁帶之題目');

  // 兩者之唯一差異：混打回退之推薦值。
  const questions = VCA.allQuestionsFor({ origin: 'newbie', typing: 'zhuyinmix' }, null);
  const question = questions.filter(function (q) { return q.id === 'kMixedAlphanumericalEnabled'; })[0];
  assert.ok(question, '題庫應有混打回退一題');
  assert.strictEqual(
    VCA.effectiveRecommended(question, { origin: 'newbie', typing: 'zhuyinmix' }), true,
    '「注音組句＋中英混打」應啟用混打回退');
  assert.strictEqual(
    VCA.effectiveRecommended(question, { origin: 'newbie', typing: 'zhuyin' }), false,
    '純粹的「注音組句」應刻意停用混打回退（非「不表態」）');
  // typing 級優先於 origin 級：華碩之使用者若明示只要純組句，仍以停用為準。
  assert.strictEqual(
    VCA.effectiveRecommended(question, { origin: 'asus', typing: 'zhuyin' }), false);
  assert.strictEqual(
    VCA.effectiveRecommended(question, { origin: 'asus', typing: 'zhuyinmix' }), true);
  assert.strictEqual(
    VCA.effectiveRecommended(question, { origin: 'asus', typing: 'unsure' }), true);
});

test('題庫：中英混打回退只為華碩與「注音組句＋中英混打」而推薦（事主 2026-09-25 裁定）', function () {
  const { VCA } = loadCore();
  const question = VCA.allQuestionsFor({ origin: 'newbie', typing: 'unsure' }, null)
    .filter(function (q) { return q.id === 'kMixedAlphanumericalEnabled'; })[0];
  assert.ok(question, '題庫應有混打回退一題');
  for (const origin of ALL_ORIGIN) {
    for (const typing of ALL_TYPING) {
      const value = VCA.effectiveRecommended(question, { origin: origin, typing: typing });
      // 兩支注音路線雙向表態（＋中英混打 ⇒ true、純組句 ⇒ false），其餘來源只有華碩推薦 true。
      // typing 級優先於 origin 級，故華碩＋純注音組句 ⇒ false。
      let expected = null;
      if (typing === 'zhuyinmix') expected = true;
      else if (typing === 'zhuyin') expected = false;
      else if (origin === 'asus') expected = true;
      assert.strictEqual(value, expected,
        origin + '/' + typing + ' 之混打回退推薦值不符裁定（應為 ' + JSON.stringify(expected) + '）');
    }
  }
});

test('題庫：五個來源刻意啟用左右 Shift 切換英數（事主 2026-09-25 裁定）', function () {
  const { VCA } = loadCore();
  const wanted = { msnewphonetic: true, kimo: true, goingime: true, asus: true, pinyin: true };
  const questions = VCA.allQuestionsFor({ origin: 'newbie', typing: 'unsure' }, null);
  for (const id of ['kTogglingAlphanumericalModeWithLShift', 'kTogglingAlphanumericalModeWithRShift']) {
    const question = questions.filter(function (q) { return q.id === id; })[0];
    assert.ok(question, '題庫應有 ' + id + ' 一題');
    assert.strictEqual(question.entry.type, 'bool');
    for (const origin of ALL_ORIGIN) {
      const value = VCA.effectiveRecommended(question, { origin: origin, typing: 'unsure' });
      assert.strictEqual(value, wanted[origin] === true ? true : null,
        origin + ' 之 ' + id + ' 推薦值不符裁定');
    }
  }
  // 起始配置亦須帶上（現代系統），且狂拼流來源不因 Shift 之故而預設啟用混打回退。
  const starter = VCA.starterFor({ origin: 'pinyin', typing: 'pinyin' }, 2700);
  assert.ok(starter.keys.indexOf('TogglingAlphanumericalModeWithLShift') >= 0);
  assert.ok(starter.keys.indexOf('TogglingAlphanumericalModeWithRShift') >= 0);
  assert.strictEqual(starter.values['MixedAlphanumericalEnabled'], false,
    '狂拼流來源不應啟用混打回退（封閉性下該鍵仍在，惟值為出廠預設之 false）');
  assert.strictEqual(starter.namedKeys.indexOf('MixedAlphanumericalEnabled'), -1,
    '該鍵不應由狂拼流來源指名');
  assert.ok(starter.resetKeys.indexOf('MixedAlphanumericalEnabled') >= 0,
    '該鍵應列於「回歸出廠預設」之一段');
  // 兩鍵之 metadata 為 minimumOS 10.15：舊系統之起始配置不得含之。
  const oldStarter = VCA.starterFor({ origin: 'pinyin', typing: 'pinyin' }, 1009);
  assert.strictEqual(oldStarter.keys.indexOf('TogglingAlphanumericalModeWithLShift'), -1);
  assert.strictEqual(oldStarter.keys.indexOf('TogglingAlphanumericalModeWithRShift'), -1);
});

test('題庫：選字鍵之逐來源預設值（事主 2026-09-25 裁定）', function () {
  const { VCA } = loadCore();
  // 事主之清單：微軟新注音／ㄅ半／小麥注音／奇摩／OpenVanilla／自然／華碩 ⇒ 123456789；
  // CIN（所有字根類）⇒ 1234567890；macOS 內建注音／漢音／狂拼流 ⇒ 123456；其餘 ⇒ 123456。
  const nine = ['msnewphonetic', 'mcbpmf', 'kimo', 'ov', 'goingime', 'asus'];
  const ten = '1234567890';
  const six = '123456';
  for (const origin of ALL_ORIGIN) {
    for (const typing of ALL_TYPING) {
      const values = VCA.starterFor({ origin: origin, typing: typing }, 2700).values;
      const actual = values['CandidateKeys'];
      // 期望值之優先序與 `effectiveRecommended()` 一致：typing 級 ＞ origin 級 ＞ 回退值。
      let expected = six;
      if (typing === 'scpc') expected = '123456789';
      else if (typing === 'cin') expected = ten;
      else if (origin === 'cin') expected = ten;
      else if (nine.indexOf(origin) >= 0) expected = '123456789';
      assert.strictEqual(actual, expected,
        origin + '/' + typing + ' 之選字鍵不符裁定：' + actual + '（應為 ' + expected + '）');
      // 一律屬「指名」段（含回退值）：該鍵對每一 profile 皆有立場。
      const starter = VCA.starterFor({ origin: origin, typing: typing }, 2700);
      assert.ok(starter.namedKeys.indexOf('CandidateKeys') >= 0,
        origin + '/' + typing + ' 之選字鍵應屬指名段');
      // 值域：唯音之選字鍵校驗為長度 6…10 之可列印 ASCII。
      assert.ok(actual.length >= 6 && actual.length <= 10, '長度須在 6…10：' + actual);
      assert.strictEqual(VCA.validateValue(VCA.entryByRawKey ? null : VCA.entryByRawValue('CandidateKeys'), actual), null);
    }
  }
});

test('題庫：preset 不再指定「僅以單行/單列來陳列候選字」（事主 2026-09-25 裁定）', function () {
  const { VCA } = loadCore();
  // 該鍵為全域排版偏好（其說明載明係為老花眼者而設）；逐字選字之單行佈局已由
  // `kEnforceSingleLineCandidateWindowLayout4SCPC` 保證 ⇒ 各組 preset 一概不提。
  const universe = VCA.starterUniverse(2700).map(function (q) { return q.entry.rawValue; });
  assert.strictEqual(universe.indexOf('CandidateWindowShowOnlyOneLine'), -1,
    '全集不應再含該鍵');
  for (const origin of ALL_ORIGIN) {
    for (const typing of ALL_TYPING) {
      const starter = VCA.starterFor({ origin: origin, typing: typing }, 2700);
      assert.strictEqual(starter.keys.indexOf('CandidateWindowShowOnlyOneLine'), -1,
        origin + '/' + typing + ' 之起始配置仍指定了該鍵');
      if (typing === 'scpc') {
        assert.strictEqual(starter.values['EnforceSingleLineCandidateWindowLayout4SCPC'], true,
          'ㄅ半之單行佈局應由該鍵保證');
      }
    }
  }
});

test('題庫：ㄅ半模式自動啟用關聯詞語（事主 2026-09-25 裁定；題庫外之鍵）', function () {
  const { VCA } = loadCore();
  // 該鍵不在題庫內（其可復原路徑為輸入法選單之「關聯詞語模式」⌃⌘O），但仍屬起始配置
  // 之範圍——故題庫 ⊆ 曝露面之不變式不受影響。
  assert.deepStrictEqual(VCA.PRESET_ONLY_KEYS, ['kAssociatedPhrasesEnabled']);
  assert.strictEqual(VCA.allQuestionKeys().indexOf('kAssociatedPhrasesEnabled'), -1,
    '題庫外之鍵不得混入題庫');
  const entry = VCA.entryByKey('kAssociatedPhrasesEnabled');
  assert.ok(entry && entry.type === 'bool' && !entry.exchangeBlacklisted);
  // 其顯示名由 `kUsingHotKeyAssociates`（「關聯詞語模式」）承載。
  assert.strictEqual(VCA.LABEL_ENTRY_ALIAS['kAssociatedPhrasesEnabled'], 'kUsingHotKeyAssociates');
  assert.ok(VCA.shortTitleOf(VCA.entryByKey('kUsingHotKeyAssociates'), 'zh-Hant').length > 0);
  assert.strictEqual(VCA.shortTitleOf(entry, 'zh-Hant'), entry.rawValue,
    '該鍵自身無標籤（故顯示時須取別名）');

  // 逐字選字（ㄅ半）之各分支 ⇒ 啟用；其餘一律回歸出廠預設（false）。
  for (const origin of ALL_ORIGIN) {
    for (const typing of ALL_TYPING) {
      const starter = VCA.starterFor({ origin: origin, typing: typing }, 2700);
      assert.ok(starter.keys.indexOf('AssociatedPhrasesEnabled') >= 0,
        '全集應涵蓋該鍵：' + origin + '/' + typing);
      const expected = typing === 'scpc';
      assert.strictEqual(starter.values['AssociatedPhrasesEnabled'], expected,
        origin + '/' + typing + ' 之關聯詞語值不符裁定');
      assert.strictEqual(starter.namedKeys.indexOf('AssociatedPhrasesEnabled') >= 0, expected,
        origin + '/' + typing + ' 之關聯詞語應' + (expected ? '' : '不') + '屬指名段');
    }
  }
});

test('題庫：起始配置之封閉性——任兩組配置所寫入之鍵集完全相同（多人共用一台電腦時不互相殘留）', function () {
  const { VCA } = loadCore();
  // 同一台電腦之人們可能有完全不同的打字習慣；此處以「磁帶派」與「注音組句派」為極端例。
  const profiles = [];
  for (const origin of ALL_ORIGIN) {
    for (const typing of ALL_TYPING) profiles.push({ origin: origin, typing: typing });
  }
  const reference = VCA.starterFor(profiles[0], 2700);
  assert.ok(reference.keys.length >= 10, '全集之鍵數過少：' + reference.keys.length);
  for (const profile of profiles) {
    const starter = VCA.starterFor(profile, 2700);
    assert.deepStrictEqual(starter.keys, reference.keys,
      profile.origin + '/' + profile.typing + ' 之鍵集與他組不同（封閉性被破壞）');
    assert.strictEqual(starter.namedKeys.length + starter.resetKeys.length, starter.keys.length);
    // 指名與回歸兩段互斥且聯集為全集。
    for (const raw of starter.namedKeys) {
      assert.strictEqual(starter.resetKeys.indexOf(raw), -1, '同鍵不得既指名又回歸：' + raw);
    }
    // 「回歸」段之值必為該鍵之出廠預設值。
    for (const raw of starter.resetKeys) {
      const entry = VCA.entryByRawValue(raw);
      assert.ok(entry, '全集之鍵須存在於後設資料：' + raw);
      assert.deepStrictEqual(starter.values[raw], entry['default'],
        profile.origin + '/' + profile.typing + ' 之回歸值非出廠預設：' + raw);
    }
  }
  // 極端例：磁帶派之先行套用，不應在注音派套用後殘留 CassetteEnabled。
  const cin = VCA.starterFor({ origin: 'cin', typing: 'cin' }, 2700);
  const zhuyin = VCA.starterFor({ origin: 'macoszhuyin', typing: 'zhuyin' }, 2700);
  assert.strictEqual(cin.values['CassetteEnabled'], true);
  assert.ok(zhuyin.keys.indexOf('CassetteEnabled') >= 0,
    '注音派之配置亦須涵蓋磁帶鍵（否則前一位使用者之 true 會殘留而停用注音）');
  assert.strictEqual(zhuyin.values['CassetteEnabled'], false);
  assert.strictEqual(zhuyin.values['CandidateKeys'], VCA.entryByRawValue('CandidateKeys')['default']);
  // 全集外之偏好一概不碰。
  for (const banned of ['CandidateListTextSize', 'UsingHotKeySCPC', '_DebugMode']) {
    assert.strictEqual(reference.keys.indexOf(banned), -1, '全集不得觸及：' + banned);
  }
});

test('題庫：狂拼流來源之並列產品名（四語系）', function () {
  const { VCA } = loadCore();
  const required = {
    'zh-Hant': ['狂拼流漢語拼音輸入法', '微軟拼音', '微信輸入法', '搜狗拼音', '昇陽拼音', '智能狂拼', '紫光拼音', 'Rime'],
    'zh-Hans': ['狂拼流汉语拼音输入法', '微软拼音', '微信输入法', '搜狗拼音', '升阳拼音', '智能狂拼', '紫光拼音', 'Rime'],
    en: ['Furious-typing Hanyu Pinyin IMEs', 'Microsoft Pinyin', 'WeType', 'Sogou Pinyin', 'SunPinyin', 'ChineseStar', 'Ziguang Pinyin', 'Rime'],
    ja: ['狂拼流の漢語弁音入力', 'Microsoft Pinyin', 'WeType', 'Sogou Pinyin', 'SunPinyin', 'ChineseStar', '紫光拼音', 'Rime'],
  };
  for (const lang of VCA.LANG_ORDER) {
    const label = VCA.UI_STRINGS[lang]['origin.opt.pinyin'];
    for (const term of required[lang]) {
      assert.ok(label.indexOf(term) >= 0, lang + ' 之來源標籤缺「' + term + '」：' + label);
    }
  }
  // 短名（內文與配置名用）不含並列清單，且僅長標籤者方有。
  assert.deepStrictEqual(Object.keys(VCA.ORIGIN_SHORT_NAME_KEY), ['pinyin']);
  for (const lang of VCA.LANG_ORDER) {
    const short = VCA.UI_STRINGS[lang]['origin.short.pinyin'];
    assert.ok(typeof short === 'string' && short.length > 0, lang + ' 缺狂拼流之短名');
    assert.strictEqual(short.indexOf('／') >= 0 || short.indexOf('/') >= 0, false,
      lang + ' 之短名不應含並列清單：' + short);
    assert.ok(VCA.UI_STRINGS[lang]['origin.opt.pinyin'].indexOf(short) >= 0,
      lang + ' 之短名應為全名之子字串：' + short);
  }
  // 配置名用之（`summary.starterTitle` 之 %1）。
  const starter = VCA.starterFor({ origin: 'pinyin', typing: 'pinyin' }, 2700);
  assert.strictEqual(starter.origin, 'pinyin');
});

test('題庫：只用 SettingsUI／SettingsCocoa 曝露給使用者之選項', function () {
  const { VCA } = loadCore();
  const surface = JSON.parse(
    require('node:fs').readFileSync(require('node:path').join(__dirname, '..', 'assets', 'settings-surface.json'), 'utf8')
  );
  assert.ok(surface.count >= 100, '曝露面鍵數過少：' + surface.count);
  const asked = VCA.allQuestionKeys();
  const notExposed = asked.filter(function (key) { return surface.keys.indexOf(key) < 0; });
  assert.deepStrictEqual(notExposed, [],
    '題庫觸及設定介面未曝露之選項（使用者無從自行復原，故不得問）：' + notExposed.join('、'));
  // 事主明示移除者，須確實不在題庫內。
  for (const banned of [
    'kCandidateTextFontName', 'kAssociatedPhrasesEnabled', 'kCurrencyNumeralsEnabled',
    'kHalfWidthPunctuationEnabled', 'kPinyinTypingEnabled',
  ]) {
    assert.strictEqual(asked.indexOf(banned), -1, '事主明示移除之選項仍在題庫內：' + banned);
  }
});

test('題庫：allQuestionKeys() 之覆蓋率', function () {
  const { VCA } = loadCore();
  const keys = VCA.allQuestionKeys();
  assert.ok(keys.length >= 90, '題庫覆蓋之鍵數過少：' + keys.length);
  assert.ok(keys.length <= 118);
  const seen = {};
  for (const key of keys) {
    assert.ok(!seen[key], '重複：' + key);
    seen[key] = true;
    assert.ok(VCA.entryByKey(key), '不存在之鍵：' + key);
  }
});

test('schema：系統版本碼之解析（整數編碼，避免 10.9 ＞ 10.15 之浮點陷阱）', function () {
  const { VCA } = loadCore();
  // 版本碼：major * 100 + minor。
  assert.strictEqual(VCA.osVersionFromUA('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15'), 1015);
  assert.strictEqual(VCA.osVersionFromUA('Mozilla/5.0 (Macintosh; Intel Mac OS X 12_6) AppleWebKit/605.1.15'), 1206);
  assert.strictEqual(VCA.osVersionFromUA('Mozilla/5.0 (Macintosh; Intel Mac OS X 10.9; rv:1.0)'), 1009);
  assert.strictEqual(VCA.osVersionFromUA('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_6)'), 1013);
  assert.strictEqual(VCA.osVersionFromUA('Mozilla/5.0 (Windows NT 10.0; Win64; x64)'), null);
  assert.strictEqual(VCA.osVersionFromUA(null), null);
  // 後設資料之浮點字面值 ⇒ 版本碼。
  assert.strictEqual(VCA.osVersionCodeFromDouble(10.9), 1009);
  assert.strictEqual(VCA.osVersionCodeFromDouble(10.15), 1015);
  assert.strictEqual(VCA.osVersionCodeFromDouble(10.14), 1014);
  assert.strictEqual(VCA.osVersionCodeFromDouble(12), 1200);
  // 顯示字串。
  assert.strictEqual(VCA.formatOSCode(1015), '10.15');
  assert.strictEqual(VCA.formatOSCode(1009), '10.9');
  assert.strictEqual(VCA.formatOSCode(1200), '12');
  // 關鍵不變式：Catalina 不該被當成比 Mavericks 還舊。
  assert.ok(VCA.osVersionCodeFromDouble(10.15) > VCA.osVersionCodeFromDouble(10.9));
});
