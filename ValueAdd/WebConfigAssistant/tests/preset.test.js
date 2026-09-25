'use strict';
// 配置包生成之測試（核心可測件）：稀疏性、型別、值域、黑名單、鍵序、「以推薦值補齊」。

const test = require('node:test');
const assert = require('node:assert');
const { loadCore, emptyState } = require('./core-loader');

function build(VCA, answers, title, description) {
  return VCA.buildPreset({
    answers: answers || {},
    title: typeof title === 'undefined' ? '自訂配置' : title,
    description: typeof description === 'undefined' ? '由唯音輸入法配置助手產生。' : description,
  });
}

test('配置包：未表態者不輸出任何鍵（稀疏）', function () {
  const { VCA } = loadCore();
  const result = build(VCA, {});
  assert.deepStrictEqual(Object.keys(result.object), [VCA.META_KEY]);
  assert.strictEqual(result.accepted.length, 0);
  assert.strictEqual(result.rejected.length, 0);
  const parsed = JSON.parse(result.json);
  assert.strictEqual(parsed[VCA.META_KEY].title, '自訂配置');
  assert.ok(typeof parsed[VCA.META_KEY].description === 'string');
});

test('配置包：中介辭典置於最前，其後依宣告序', function () {
  const { VCA, metadata } = loadCore();
  // 刻意以「逆序」給答案；輸出仍須依後設資料之宣告序。
  const answers = {};
  answers['UseRearCursorMode'] = true;
  answers['HalfWidthPunctuationEnabled'] = true;
  answers['IsDebugModeEnabled'] = true; // hmm：此鍵之 rawValue 為 `_DebugMode`
  delete answers['IsDebugModeEnabled'];
  answers['_DebugMode'] = true;
  const result = build(VCA, answers);
  const keys = Object.keys(result.object);
  assert.strictEqual(keys[0], VCA.META_KEY);
  const emitted = keys.slice(1);
  const declared = metadata.entries
    .map(function (e) { return e.rawValue; })
    .filter(function (raw) { return emitted.indexOf(raw) >= 0; });
  assert.deepStrictEqual(emitted, declared);
});

test('配置包：型別依後設資料（布林／整數／字串）', function () {
  const { VCA } = loadCore();
  const result = build(VCA, {
    UseRearCursorMode: true,
    CandidateListTextSize: 40,
    CandidateKeys: 'asdfghjkl',
  });
  assert.strictEqual(result.object['UseRearCursorMode'], true);
  assert.strictEqual(result.object['CandidateListTextSize'], 40);
  assert.strictEqual(result.object['CandidateKeys'], 'asdfghjkl');
  assert.strictEqual(result.rejected.length, 0);
});

test('配置包：跨表示法之輸入會被正規化（1 ⇒ true）', function () {
  const { VCA } = loadCore();
  const result = build(VCA, { UseRearCursorMode: 1 });
  assert.strictEqual(result.object['UseRearCursorMode'], true);
});

test('配置包：黑名單鍵一律不輸出、且入列 rejected', function () {
  const { VCA } = loadCore();
  const result = build(VCA, {
    AppleLanguages: 'zh-Hant',
    CassettePath: '/tmp/x.cin',
    UserDataFolderSpecified: '/tmp',
    MostRecentInputMode: 'zhuyin',
    _FailureFlag_POMObservation: false,
    CandidateServiceMenuContents: 'x',
  });
  const keys = Object.keys(result.object);
  assert.deepStrictEqual(keys, [VCA.META_KEY]);
  assert.strictEqual(result.rejected.length, 6);
  for (const item of result.rejected) {
    assert.strictEqual(item.reason, 'Blacklisted key');
  }
});

test('配置包：值域外之整數一律不輸出', function () {
  const { VCA } = loadCore();
  const tooBig = build(VCA, { CandidateListTextSize: 9999 });
  assert.deepStrictEqual(Object.keys(tooBig.object), [VCA.META_KEY]);
  assert.strictEqual(tooBig.rejected.length, 1);
  assert.ok(tooBig.rejected[0].reason.indexOf('closed range') >= 0);

  const tooSmall = build(VCA, { CandidateListTextSize: 11 });
  assert.strictEqual(tooSmall.rejected.length, 1);

  const ok = build(VCA, { CandidateListTextSize: 12 });
  assert.strictEqual(ok.object['CandidateListTextSize'], 12);
});

test('配置包：空字串之選字鍵不被接受', function () {
  const { VCA } = loadCore();
  const result = build(VCA, { CandidateKeys: '' });
  assert.deepStrictEqual(Object.keys(result.object), [VCA.META_KEY]);
  assert.strictEqual(result.rejected.length, 1);
});

test('配置包：未知鍵入列 rejected', function () {
  const { VCA } = loadCore();
  const result = build(VCA, { NoSuchPreferenceKey: true });
  assert.deepStrictEqual(Object.keys(result.object), [VCA.META_KEY]);
  assert.strictEqual(result.rejected.length, 1);
  assert.strictEqual(result.rejected[0].reason, 'Unknown key');
});

test('配置包：JSON 為合法之 pretty-print，且可回解為同一物件', function () {
  const { VCA } = loadCore();
  const result = build(VCA, { CandidateListTextSize: 24, UseHorizontalCandidateList: false });
  assert.ok(result.json.indexOf('\n  ') >= 0, '應為縮排之 pretty-print');
  assert.deepStrictEqual(JSON.parse(result.json), result.object);
  assert.strictEqual(result.accepted.length, 2);
});

test('配置包：整份題庫之推薦值皆可生成合法之配置包', function () {
  const { VCA } = loadCore();
  const steps = VCA.buildSteps({ origin: 'msnewphonetic', typing: 'scpc' }, null);
  const state = emptyState({ origin: 'msnewphonetic', typing: 'scpc' });
  for (const step of steps) {
    const additions = VCA.fillSuggestions(step, state);
    for (const raw of Object.keys(additions)) {
      state.answers[raw] = additions[raw];
    }
  }
  const result = build(VCA, state.answers);
  assert.strictEqual(result.rejected.length, 0, JSON.stringify(result.rejected));
  assert.ok(result.accepted.length > 0);
  // 逐鍵再走一次後端語意之驗證。
  for (const accepted of result.accepted) {
    assert.strictEqual(VCA.validateValue(accepted.entry, accepted.value), null);
  }
});

test('配置包：fillSuggestions 只補「未表態且有推薦值」者', function () {
  const { VCA } = loadCore();
  const steps = VCA.buildSteps({ origin: 'msnewphonetic', typing: 'scpc' }, null);
  const state = emptyState({ origin: 'msnewphonetic', typing: 'scpc' });
  // 使用者已親自表態者，不得被推薦值覆寫。
  state.answers['CandidateKeys'] = 'asdfghjkl';
  state.manual['CandidateKeys'] = true;
  const methodStep = steps.filter(function (s) { return s.id === 'method'; })[0];
  const candidateStep = steps.filter(function (s) { return s.id === 'candidate'; })[0];
  const methodAdditions = VCA.fillSuggestions(methodStep, state);
  assert.strictEqual(methodAdditions['UseSCPCTypingMode'], true);
  const candidateAdditions = VCA.fillSuggestions(candidateStep, state);
  assert.strictEqual(typeof candidateAdditions['CandidateKeys'], 'undefined');
  assert.strictEqual(candidateAdditions['UseHorizontalCandidateList'], false);
  // 「僅以單行/單列來陳列候選字」已無推薦值（事主 2026-09-25：ㄅ半之單行佈局由
  // `kEnforceSingleLineCandidateWindowLayout4SCPC` 保證即可）⇒ 由出廠預設值（false）補之。
  assert.strictEqual(candidateAdditions['CandidateWindowShowOnlyOneLine'], false);
  // 無推薦值、亦未表態者：以出廠預設值補之（此為明示之「逐組」行為）。
  assert.strictEqual(typeof candidateAdditions['EnableCandidateWindowAnimation'], 'boolean');
});

test('配置包：題目之選項與後端值域一致（曾因三條鍵不一致而修）', function () {
  const { VCA } = loadCore();
  // kNumPadCharInputBehavior 之 options 為 0…5；值域已於 2026-09-24 由 0…2 放寬為 0…5，
  // 故六個選項皆可出題、且皆為後端所接受。
  const entry = VCA.entryByKey('kNumPadCharInputBehavior');
  const usable = VCA.usableOptions(entry).map(function (o) { return o.value; });
  assert.deepStrictEqual(usable, [0, 1, 2, 3, 4, 5]);
  const steps = VCA.buildSteps({ origin: 'newbie', typing: 'unsure' }, null);
  let found = null;
  for (const step of steps) {
    for (const question of step.questions) {
      if (question.id === 'kNumPadCharInputBehavior') found = question;
    }
  }
  assert.ok(found, '缺數字小鍵盤一題');
  assert.deepStrictEqual(found.choices.map(function (c) { return c.value; }), [0, 1, 2, 3, 4, 5]);
  // 通知配色之 -1（淺色模式）亦應回到題目內。
  const color = VCA.entryByKey('kSpecifiedNotifyUIColorScheme');
  assert.deepStrictEqual(VCA.usableOptions(color).map(function (o) { return o.value; }), [-1, 0, 1]);
});
