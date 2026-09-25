// 唯音輸入法配置助手 // 測試宿主（Phase 246：取代 `node --test tests/*.test.js`）。
//
// 既有之五支測試檔與 DOM 替身**一字不改**——它們只 `require('node:test')`／
// `require('node:assert')`／`require('./core-loader')`，而三者皆由本宿主提供。
// 測試檔之蒐集方式亦與原 Makefile 之 `tests/*.test.js` 對位（掃描目錄、取 `*.test.js`）。

function __runTestSuite(packageRoot) {
  var testDir = __joinPath(packageRoot, "tests");
  var files = __listDir(testDir).filter(function (name) {
    return /\.test\.js$/.test(name);
  }).sort();
  if (files.length === 0) throw new Error("找不到任何測試檔：" + testDir);

  var loadClock = Date.now();
  for (var i = 0; i < files.length; i++) {
    __loadModule(__joinPath(testDir, files[i]), false);
  }
  var loadMs = Date.now() - loadClock;

  var tests = __collectedTests;
  var passed = 0;
  var failures = [];
  for (var k = 0; k < tests.length; k++) {
    try {
      tests[k].fn();
      passed += 1;
    } catch (error) {
      var message = String((error && error.message) || error).split("\n")[0];
      failures.push(tests[k].name + "：" + message);
    }
  }

  __outputBuffer.push("模組載入：" + loadMs + " ms\n");
  __outputBuffer.push("測試：" + tests.length + " 支，通過 " + passed + "，失敗 " + failures.length + "\n");
  for (var m = 0; m < failures.length && m < 20; m++) {
    __outputBuffer.push("  ✗ " + failures[m] + "\n");
  }
  __flushOutput();

  if (failures.length > 0) throw new Error("測試失敗 " + failures.length + " 支");
}
