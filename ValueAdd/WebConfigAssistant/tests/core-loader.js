'use strict';
// 測試用之載入器：把 dist/core.js（無 DOM 之純邏輯）載入當前全域。
//
// 說明：本專案之產物是「全域 script」（`var VCA;  (function (VCA) {…})(VCA || (VCA = {}))`），
// 沒有模組系統，故以 `vm.runInThisContext` 執行之——它與測試檔共用同一個全域物件，
// 故 `globalThis.VCA`／`globalThis.VCA_METADATA` 直接可用。

const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const CORE_PATH = path.join(__dirname, '..', 'dist', 'core.js');
const ASSET_PATH = path.join(__dirname, '..', 'assets', 'userdef-metadata.json');

function loadCore() {
  if (!fs.existsSync(CORE_PATH)) {
    throw new Error('找不到 dist/core.js：請先於 ValueAdd/WebConfigAssistant 跑 `make bundle`。');
  }
  if (!globalThis.VCA) {
    vm.runInThisContext(fs.readFileSync(CORE_PATH, 'utf8'), { filename: CORE_PATH });
  }
  return { VCA: globalThis.VCA, metadata: globalThis.VCA_METADATA };
}

function loadAsset() {
  return JSON.parse(fs.readFileSync(ASSET_PATH, 'utf8'));
}

function emptyState(profile, lang) {
  return {
    lang: lang || 'zh-Hant',
    stepIndex: 0,
    profile: profile || { origin: 'newbie', typing: 'unsure' },
    answers: {},
    manual: {},
    fillAdded: {},
    starterOn: true,
    starterAdded: {},
    starterNamedOff: {},
    starterResetOff: {},
    expressOnly: true,
    skipFromIndex: -1,
    metaTitle: '',
    metaDescription: '',
    fillRecommended: {},
    jsonVisible: false,
  };
}

module.exports = { loadCore, loadAsset, emptyState };
