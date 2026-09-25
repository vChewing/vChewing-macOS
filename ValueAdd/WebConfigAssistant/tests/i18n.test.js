'use strict';
// 介面文案之測試：四語系之完整性、佔位符一致性、以及 zh-Hans 之語體紀律。

const test = require('node:test');
const assert = require('node:assert');
const { loadCore } = require('./core-loader');

// zh-Hans 一律為 **zh-Hans-TW**（臺灣華語、簡體字形）：只簡化字形，不得改用大陸用語。
// 以下為本倉既有慣例所禁之詞（對照表見 vChewing-DevLogs/KnowledgeMemo4LLM.md §12.6）。
const FORBIDDEN_MAINLAND_TERMS = [
  '剪贴板', '导入', '设置', '数据', '窗口', '菜单', '软件', '标识', '复制', '内存',
  '硬盘', '支持', '鼠标', '屏幕', '链接', '优化', '兼容', '通过', '默认', '用户',
  '视频', '打印机', '进程', '服务器', '互联网', '简体中文台湾',
];

// 同一批詞之臺灣用法（簡體字形），至少須出現一次。
const REQUIRED_TAIWAN_TERMS = ['剪贴簿', '汇入', '套用', '设定', '资料', '视窗', '软体', '预设', '使用者'];

function placeholders(text) {
  const found = [];
  for (let i = 0; i < text.length - 1; i += 1) {
    if (text.charAt(i) !== '%') continue;
    const digit = text.charAt(i + 1);
    if ('123456789'.indexOf(digit) >= 0 && found.indexOf(digit) < 0) found.push(digit);
  }
  return found.sort();
}

test('i18n：四個語系皆存在，且鍵集與 zh-Hant 完全相同', function () {
  const { VCA } = loadCore();
  assert.deepStrictEqual(VCA.LANG_ORDER, ['zh-Hant', 'zh-Hans', 'en', 'ja']);
  const base = Object.keys(VCA.UI_STRINGS['zh-Hant']).sort();
  assert.ok(base.length >= 80, 'zh-Hant 之鍵數過少：' + base.length);
  for (const lang of VCA.LANG_ORDER) {
    const table = VCA.UI_STRINGS[lang];
    assert.ok(table, '缺語系：' + lang);
    assert.deepStrictEqual(Object.keys(table).sort(), base, lang + ' 之鍵集與 zh-Hant 不一致');
  }
});

test('i18n：無空字串、無未翻譯（值等於鍵）者', function () {
  const { VCA } = loadCore();
  for (const lang of VCA.LANG_ORDER) {
    const table = VCA.UI_STRINGS[lang];
    for (const key of Object.keys(table)) {
      const value = table[key];
      assert.ok(typeof value === 'string' && value.length > 0, lang + ' 之 ' + key + ' 為空');
      assert.notStrictEqual(value, key, lang + ' 之 ' + key + ' 未翻譯');
    }
  }
});

test('i18n：佔位符之集合逐鍵一致', function () {
  const { VCA } = loadCore();
  const base = VCA.UI_STRINGS['zh-Hant'];
  for (const key of Object.keys(base)) {
    const expected = placeholders(base[key]);
    for (const lang of VCA.LANG_ORDER) {
      const actual = placeholders(VCA.UI_STRINGS[lang][key]);
      assert.deepStrictEqual(actual, expected,
        lang + ' 之 ' + key + ' 佔位符不一致（' + actual.join(',') + ' vs ' + expected.join(',') + '）');
    }
  }
});

test('i18n：zh-Hans 為 zh-Hans-TW（臺灣用語、簡體字形）', function () {
  const { VCA } = loadCore();
  const table = VCA.UI_STRINGS['zh-Hans'];
  const joined = Object.keys(table).map(function (k) { return table[k]; }).join('\n');
  for (const term of FORBIDDEN_MAINLAND_TERMS) {
    assert.strictEqual(joined.indexOf(term), -1, 'zh-Hans 出現大陸用語：' + term);
  }
  for (const term of REQUIRED_TAIWAN_TERMS) {
    assert.ok(joined.indexOf(term) >= 0, 'zh-Hans 缺臺灣用語：' + term);
  }
  // 反例：zh-Hant 不得出現簡體字形。
  const hant = Object.keys(VCA.UI_STRINGS['zh-Hant'])
    .map(function (k) { return VCA.UI_STRINGS['zh-Hant'][k]; }).join('\n');
  for (const term of ['剪贴', '汇入', '设定', '资料', '视窗', '软体', '预设']) {
    assert.strictEqual(hant.indexOf(term), -1, 'zh-Hant 出現簡體字形：' + term);
  }
});

test('i18n：語言偵測與檢索', function () {
  const { VCA } = loadCore();
  assert.strictEqual(VCA.normalizeLang('zh-CN'), 'zh-Hans');
  assert.strictEqual(VCA.normalizeLang('zh-TW'), 'zh-Hant');
  assert.strictEqual(VCA.normalizeLang('ja-JP'), 'ja');
  assert.strictEqual(VCA.normalizeLang('en-US'), 'en');
  assert.strictEqual(VCA.normalizeLang('fr'), null);
  assert.strictEqual(VCA.detectLang(null, 'ja-JP'), 'ja');
  assert.strictEqual(VCA.detectLang('en', 'ja-JP'), 'en');
  assert.strictEqual(VCA.detectLang(null, null), 'zh-Hant');
  assert.strictEqual(VCA.detectLang('fr', 'fr-FR'), 'zh-Hant');
});

test('i18n：t() 與 tf() 之替代行為', function () {
  const { VCA } = loadCore();
  VCA.setLang('zh-Hant');
  assert.strictEqual(VCA.t('app.title'), VCA.UI_STRINGS['zh-Hant']['app.title']);
  assert.strictEqual(VCA.t('no.such.key'), 'no.such.key');
  const rendered = VCA.tf('q.range', [12, 196]);
  assert.ok(rendered.indexOf('12') >= 0 && rendered.indexOf('196') >= 0, rendered);
  VCA.setLang('en');
  const english = VCA.tf('app.stepCounter', [3, 12]);
  assert.ok(english.indexOf('3') >= 0 && english.indexOf('12') >= 0, english);
  VCA.setLang('zh-Hant');
});
