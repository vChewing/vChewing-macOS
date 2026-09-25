'use strict';
// 題庫之測試：分頁結構、逐題之鍵對位、選項值之合法性、分支與系統版本之過濾、i18n 之齊備。

const test = require('node:test');
const assert = require('node:assert');
const { loadCore } = require('./core-loader');

const ALL_TYPING = ['zhuyin', 'scpc', 'pinyin', 'cin', 'unsure'];
// 來源清單一律取自執行期（不手抄——新增來源時本清單自動跟上）。
const ALL_ORIGIN = loadCore().VCA.ORIGIN_VALUES.slice();

function stepsFor(VCA, origin, typing, os) {
  return VCA.buildSteps({ origin: origin, typing: typing }, typeof os === 'undefined' ? null : os);
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
    'welcome', 'background', 'method', 'rhythm', 'keys', 'candidate',
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
    keys.push(step.titleKey, step.introKey);
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
