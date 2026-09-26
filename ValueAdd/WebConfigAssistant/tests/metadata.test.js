'use strict';
// 後設資料之契約測試：助手所依賴的一切欄位，皆須與 Swift 側之導出一致。

const test = require('node:test');
const assert = require('node:assert');
const { loadCore, loadAsset } = require('./core-loader');

// 2026-09-24（Phase 241 補記）：三條鍵之 `metaData.options` 曾超出 `validNumeralValueRange`
// （`kSpecifiedNotifyUIColorScheme` 之 -1、`kForceCassetteChineseConversion` 之 3、
// `kNumPadCharInputBehavior` 之 3／4／5），令 app 自己匯出的偏好包會被拒。該缺陷已於 app 側
// 修好（值域放寬為與選項一致），故助手不再需要「選項 ∩ 值域」之特別處理——但仍保留該機制
// 作為防禦，並以下列不變式守住「選項 ⊆ 值域」。

const PARSER_LABEL_KEYS = [
  'i18n:KeyboardLayout.DachenMicrosoftStandard', 'i18n:KeyboardLayout.EtenTraditional',
  'i18n:KeyboardLayout.Hsu', 'i18n:KeyboardLayout.Eten26', 'i18n:KeyboardLayout.IBM',
  'i18n:KeyboardLayout.MiTAC', 'i18n:KeyboardLayout.FakeSeigyou', 'i18n:KeyboardLayout.Dachen26',
  'i18n:KeyboardLayout.Seigyou', 'i18n:KeyboardLayout.Starlight',
  'i18n:KeyboardLayout.AlvinLiuImitative',
  'i18n:TypingMethod.HanyuPinyinNumeral', 'i18n:TypingMethod.SecondaryPinyinNumeral',
  'i18n:TypingMethod.YalePinyinNumeral', 'i18n:TypingMethod.HualuoPinyinNumeral',
  'i18n:TypingMethod.UniversalPinyinNumeral', 'i18n:TypingMethod.WadeGilesPinyinNumeral',
];

test('後設資料：基本不變式', function () {
  const { metadata } = loadCore();
  assert.strictEqual(metadata.schemaVersion, 1);
  assert.strictEqual(metadata.count, 119);
  assert.strictEqual(metadata.count, metadata.entries.length);
  assert.deepStrictEqual(metadata.locales, ['zh-Hant', 'zh-Hans', 'en', 'ja']);
  assert.deepStrictEqual(metadata.missingI18nKeys, []);
  assert.deepStrictEqual(metadata.pendingMetadataKeys, []);
  // 條目順序即 `UserDef.allCases` 之宣告序。
  assert.strictEqual(metadata.entries[0].key, 'kIsDebugModeEnabled');
  assert.strictEqual(metadata.entries[0].rawValue, '_DebugMode');
});

test('後設資料：鍵名與 rawValue 皆不重複', function () {
  const { metadata } = loadCore();
  const keys = {};
  const raws = {};
  for (const entry of metadata.entries) {
    assert.ok(!keys[entry.key], '重複之 key：' + entry.key);
    assert.ok(!raws[entry.rawValue], '重複之 rawValue：' + entry.rawValue);
    keys[entry.key] = true;
    raws[entry.rawValue] = true;
    assert.ok(!entry.rawValue.startsWith('__'), 'rawValue 不得以 __ 開頭：' + entry.rawValue);
  }
});

test('後設資料：預設值之型別與值域皆合法', function () {
  const { VCA, metadata } = loadCore();
  for (const entry of metadata.entries) {
    assert.notStrictEqual(entry['default'], null, entry.key + ' 缺 default');
    if (entry.range) {
      const [low, high] = entry.range;
      assert.ok(low <= high, entry.key + ' 之值域顛倒');
      if (typeof entry['default'] === 'number') {
        assert.ok(entry['default'] >= low && entry['default'] <= high,
          entry.key + ' 之預設值不在值域內');
      }
    }
    // 預設值必須能通過助手之驗證（＝後端亦應接受之最低保證）；
    // 黑名單鍵與助手不支援之型別本即不參與交換，故略過。
    if (!VCA.isTouchable(entry)) continue;
    assert.strictEqual(VCA.validateValue(entry, entry['default']), null,
      entry.key + ' 之預設值未通過 validateValue');
  }
});

test('後設資料：每個選項皆落在值域內（＝選項 ⊆ 值域 之不變式）', function () {
  const { VCA, metadata } = loadCore();
  let checked = 0;
  for (const entry of metadata.entries) {
    const excluded = VCA.optionsOutOfRange(entry);
    assert.deepStrictEqual(excluded, [],
      entry.key + ' 之選項超出值域：' + JSON.stringify(excluded));
    for (const option of VCA.usableOptions(entry)) {
      // 布林鍵之 `options` 值為 0／1（僅為「假／真」之標籤），助手實際輸出者為
      // 真正的 boolean；故先正規化再驗證——此即助手產出配置包時所走之路徑。
      const coerced = VCA.coerceValue(entry, option.value);
      assert.notStrictEqual(coerced, null,
        entry.key + ' 之選項 ' + option.value + ' 無法正規化為合法值');
      assert.strictEqual(VCA.validateValue(entry, coerced), null,
        entry.key + ' 之選項 ' + option.value + ' 未通過驗證');
      checked += 1;
    }
  }
  assert.ok(checked >= 40, '受檢之選項數過少：' + checked);
  // 三條曾與值域不一致之鍵，其值域之現行定版（絆線）。
  assert.deepStrictEqual(VCA.entryByKey('kSpecifiedNotifyUIColorScheme').range, [-1, 1]);
  assert.deepStrictEqual(VCA.entryByKey('kForceCassetteChineseConversion').range, [0, 3]);
  assert.deepStrictEqual(VCA.entryByKey('kNumPadCharInputBehavior').range, [0, 5]);
});

test('後設資料：黑名單恰為六條鍵，且助手之題庫不觸及之', function () {
  const { VCA, metadata } = loadCore();
  const blacklisted = metadata.entries.filter(function (e) { return e.exchangeBlacklisted; })
    .map(function (e) { return e.key; }).sort();
  assert.deepStrictEqual(blacklisted, [
    'kAppleLanguages', 'kCandidateServiceMenuContents', 'kCassettePath',
    'kFailureFlagForPOMObservation', 'kMostRecentInputMode', 'kUserDataFolderSpecified',
  ]);
  const asked = VCA.allQuestionKeys();
  for (const key of blacklisted) {
    assert.ok(asked.indexOf(key) < 0, '題庫不得觸及黑名單鍵：' + key);
  }
});

test('後設資料：四語系之標籤與注音／拼音排列名稱皆齊備', function () {
  const { VCA, metadata } = loadCore();
  for (const lang of metadata.locales) {
    for (const key of PARSER_LABEL_KEYS) {
      const text = VCA.extraLabel(key, lang);
      assert.ok(typeof text === 'string' && text.length > 0,
        lang + ' 缺注音／拼音排列標籤：' + key);
    }
  }
  // 可讀標題：至少九成之鍵於四語系皆有 shortTitle（其餘為刻意無標籤者）。
  let withTitle = 0;
  for (const entry of metadata.entries) {
    if (entry.labels['zh-Hant'] && entry.labels['zh-Hant'].shortTitle) withTitle += 1;
  }
  assert.ok(withTitle >= 100, '帶 shortTitle 之鍵數過少：' + withTitle);
});

test('後設資料：字典型別之鍵一律不出題', function () {
  const { VCA, metadata } = loadCore();
  const dictionaries = metadata.entries.filter(function (e) { return e.type === 'dictionary'; });
  assert.ok(dictionaries.length >= 1);
  const asked = VCA.allQuestionKeys();
  for (const entry of dictionaries) {
    assert.ok(asked.indexOf(entry.key) < 0, '字典型別之鍵不得出題：' + entry.key);
  }
});

test('後設資料：入庫版與內嵌版一致（同一份導出）', function () {
  const { metadata } = loadCore();
  const asset = loadAsset();
  assert.strictEqual(asset.count, metadata.count);
  assert.strictEqual(asset.entries.length, metadata.entries.length);
  for (let i = 0; i < asset.entries.length; i += 1) {
    assert.strictEqual(asset.entries[i].key, metadata.entries[i].key);
    assert.strictEqual(asset.entries[i].rawValue, metadata.entries[i].rawValue);
    assert.strictEqual(asset.entries[i].type, metadata.entries[i].type);
  }
});

test('後設資料：文案之術語統一——已停用之舊稱謂不得再出現（事主 2026-09-26 裁定）', function () {
  const { metadata } = loadCore();
  // 舊稱謂：狂拼（→拼音狂打）／狂注（→注音狂打）及其 ja／en 對位。**本清單即該裁定之固化物。**
  const RETIRED = ['狂拼', '狂注', '狂拼モード', '狂注モード', 'Furious Typing', 'Furious Zhuyin Typing'];
  const text = JSON.stringify(metadata);
  for (const term of RETIRED) {
    assert.strictEqual(text.indexOf(term), -1, '後設資料之文案仍含已停用之稱謂：' + term);
  }
  // 新稱謂須確實在位（兩鍵之四語系標題）。
  const EXPECTED = [
    ['kFuriousTypingEnabled4Pinyin', { 'zh-Hant': '拼音狂打', 'zh-Hans': '拼音狂打', ja: '弁音狂打ち', en: 'Furious Pinyin' }],
    ['kFuriousTypingEnabled4Zhuyin', { 'zh-Hant': '注音狂打', 'zh-Hans': '注音狂打', ja: '注音狂打ち', en: 'Furious Zhuyin' }],
  ];
  for (const pair of EXPECTED) {
    const key = pair[0];
    const expected = pair[1];
    const entry = metadata.entries.filter(function (e) { return e.key === key; })[0];
    assert.ok(entry, '找不到條目：' + key);
    for (const loc of Object.keys(expected)) {
      const title = entry.labels[loc].shortTitle;
      assert.ok(title.indexOf(expected[loc]) >= 0,
        key + '/' + loc + ' 之標題未含新稱謂（' + expected[loc] + '）：' + title);
    }
  }
});

test('後設資料：注音狂打之警示須置於 description 之首（事主 2026-09-26 裁定）', function () {
  const { metadata } = loadCore();
  // 事主原文：「kFuriousTypingEnabled4Zhuyin 的 description 得在最開頭就顯示
  // 「⚠︎ 該模式無法在中英文輸入回退模式啟用時起作用。\n」，因為插在其他位置的話不醒目。」
  // 本靶即「醒目性」之固化物：只驗「在不在」不足以守住該裁定——**位置**才是重點。
  const MARK = '\u26a0\ufe0e';
  const entry = metadata.entries.filter(function (e) {
    return e.key === 'kFuriousTypingEnabled4Zhuyin';
  })[0];
  assert.ok(entry, '找不到條目：kFuriousTypingEnabled4Zhuyin');
  for (const loc of ['zh-Hant', 'zh-Hans', 'ja', 'en']) {
    const desc = entry.labels[loc].description;
    assert.ok(desc, loc + ' 之 description 為空');
    assert.ok(desc.indexOf(MARK) === 0,
      loc + ' 之 description 未以警示符開頭（首 20 字：' + desc.slice(0, 20) + '）');
    assert.ok(desc.indexOf('\n') > 0,
      loc + ' 之警示行未與內文分行（缺少換行）');
  }
});
