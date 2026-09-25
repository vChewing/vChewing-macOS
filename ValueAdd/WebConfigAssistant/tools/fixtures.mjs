// 契約測試用之 fixture 產生器（零 npm 相依）。
//
// 為何要「產生」而非「手抄」：fixture 是助手與唯音之間的契約樣本——手抄必然漂移。
// 本檔以助手自己的核心邏輯（dist/core.js）實際生成配置包，故 fixture 恆等於助手之真實產物；
// 其後由 Swift 側之契約測試斷言「唯音收得下這些包」。
//
// 用法：node tools/fixtures.mjs [--check]
//   --check：只重新生成到 dist/ 並與入庫版比對，有差即失敗（供 `make fixtures-check` 用）。

import fs from 'node:fs';
import path from 'node:path';
import url from 'node:url';
import vm from 'node:vm';

const ROOT = path.resolve(path.dirname(url.fileURLToPath(import.meta.url)), '..');
const CORE = path.join(ROOT, 'dist', 'core.js');
const OUT_DIR = path.join(ROOT, 'tests', 'fixtures');
const CHECK_DIR = path.join(ROOT, 'dist', 'fixtures');

/// 情境：一組 profile ＋ 是否逐頁「以推薦值補齊」＋ 額外之手動答案。
const SCENARIOS = [
  {
    name: 'msnewphonetic-scpc',
    title: '微軟新注音轉唯音（逐字選字派）',
    description: '由唯音輸入法配置助手生成：微軟新注音之用戶，改用注音逐字選字（ㄅ半）風格。',
    profile: { origin: 'msnewphonetic', typing: 'scpc' },
    fillAllPages: true,
    manualAnswers: { CandidateListTextSize: 48 },
  },
  {
    name: 'kimo-zhuyin',
    title: '奇摩輸入法轉唯音（注音組句）',
    description: '由唯音輸入法配置助手生成：雅虎奇摩輸入法之用戶，改用注音組句。',
    profile: { origin: 'kimo', typing: 'zhuyin' },
    fillAllPages: true,
    manualAnswers: {},
  },
  {
    name: 'pinyin-newbie',
    title: '全新使用者（漢語拼音）',
    description: '由唯音輸入法配置助手生成：全新使用者，以漢語拼音打字。',
    profile: { origin: 'newbie', typing: 'pinyin' },
    fillAllPages: true,
    manualAnswers: { UseExternalFactoryDict: true },
  },
  {
    name: 'minimal-sparse',
    title: '極簡包（只表態一項）',
    description: '由唯音輸入法配置助手生成：只調整了選字窗字號一項，其餘一概不動。',
    profile: { origin: 'newbie', typing: 'unsure' },
    fillAllPages: false,
    manualAnswers: { CandidateListTextSize: 32 },
  },
];

function loadCore() {
  if (!fs.existsSync(CORE)) {
    throw new Error('找不到 dist/core.js：請先跑 `make bundle`。');
  }
  const sandbox = { console: console };
  vm.createContext(sandbox);
  vm.runInContext(fs.readFileSync(CORE, 'utf8'), sandbox, { filename: CORE });
  if (!sandbox.VCA) throw new Error('dist/core.js 未匯出 VCA。');
  return sandbox.VCA;
}

function buildScenario(VCA, scenario) {
  const steps = VCA.buildSteps(scenario.profile, null);
  const state = {
    lang: 'zh-Hant',
    stepIndex: 0,
    profile: scenario.profile,
    answers: {},
    manual: {},
    fillAdded: {},
    metaTitle: scenario.title,
    metaDescription: scenario.description,
    fillRecommended: {},
    jsonVisible: false,
  };
  const askedKeys = VCA.allQuestionKeys();
  for (const key of Object.keys(scenario.manualAnswers)) {
    const entry = VCA.entryByRawValue(key);
    if (!entry) throw new Error('情境 ' + scenario.name + ' 之手動答案不存在：' + key);
    // 手動答案亦須落在題庫內——否則該 fixture 即非助手做得出之產物。
    if (askedKeys.indexOf(entry.key) < 0) {
      throw new Error('情境 ' + scenario.name + ' 之手動答案不在題庫內：' + key);
    }
    state.answers[key] = scenario.manualAnswers[key];
    state.manual[key] = true;
  }
  if (scenario.fillAllPages) {
    for (const step of steps) {
      if (step.id === 'welcome' || step.id === 'summary') continue;
      const additions = VCA.fillSuggestions(step, state);
      for (const raw of Object.keys(additions)) state.answers[raw] = additions[raw];
    }
  }
  const preset = VCA.buildPreset({
    answers: state.answers,
    title: scenario.title,
    description: scenario.description,
  });
  if (preset.rejected.length > 0) {
    throw new Error('情境 ' + scenario.name + ' 產生了被拒之鍵：' + JSON.stringify(preset.rejected));
  }
  return preset.json + '\n';
}

function main() {
  const check = process.argv.indexOf('--check') >= 0;
  const VCA = loadCore();
  const targetDir = check ? CHECK_DIR : OUT_DIR;
  fs.mkdirSync(targetDir, { recursive: true });
  let drift = 0;
  const summary = [];
  for (const scenario of SCENARIOS) {
    const text = buildScenario(VCA, scenario);
    const target = path.join(targetDir, scenario.name + '.json');
    if (check) {
      const committed = fs.existsSync(path.join(OUT_DIR, scenario.name + '.json'))
        ? fs.readFileSync(path.join(OUT_DIR, scenario.name + '.json'), 'utf8') : '';
      if (committed !== text) {
        drift += 1;
        summary.push('  DIFF ' + scenario.name + '.json');
        continue;
      }
      summary.push('  same ' + scenario.name + '.json');
      continue;
    }
    fs.writeFileSync(target, text, 'utf8');
    const parsed = JSON.parse(text);
    const count = Object.keys(parsed).length - 1;
    summary.push('  ' + scenario.name + '.json（' + count + ' 項）');
  }
  process.stdout.write((check ? 'fixture 比對：\n' : 'fixture 已生成：\n') + summary.join('\n') + '\n');
  if (check && drift > 0) {
    process.stdout.write('fixture 已漂移。請跑 `make fixtures` 後提交。\n');
    process.exit(1);
  }
}

main();
