// 唯音輸入法配置助手 // CommonJS 載入器（Phase 246）。
//
// 何以需要自建：JXA 無模組系統，而本鏈之五支工具與五支測試檔皆彼此 `require`／被 `require`。
// 本載入器提供 node 之 CommonJS 語意（`require`／`module`／`exports`／`__filename`／
// `__dirname`／`require.main === module`），故工具與測試之原始碼得以維持慣用之形制。
//
// 一項方法學教訓（Phase 245 研究 §7.10.1 所載）：**不可把各檔攤平到同一全域**——
// `build.js` 與 `es5guard.js` 各以 `require.main === module` 判斷是否為入口，
// 而兩者另有同名之頂層繫結；攤平即撞名。模組範疇必須保留。

var __moduleCache = {};
var __mainModule = null;

function __loadModule(absPath, isMain) {
  if (Object.prototype.hasOwnProperty.call(__moduleCache, absPath)) {
    return __moduleCache[absPath].exports;
  }
  var source = __readText(absPath);
  if (source === null) throw new Error("Cannot find module '" + absPath + "'");

  var module = { exports: {}, id: absPath, filename: absPath, loaded: false };
  __moduleCache[absPath] = module;
  if (isMain) __mainModule = module;

  var dir = __dirnameOf(absPath);
  var require = __makeRequire(dir);
  var wrapper = (0, eval)(
    "(function (exports, require, module, __filename, __dirname) {\n" + source + "\n})"
  );
  wrapper.call(module.exports, module.exports, require, module, absPath, dir);
  module.loaded = true;
  return module.exports;
}

function __makeRequire(dir) {
  function require(id) {
    if (Object.prototype.hasOwnProperty.call(__nodeBuiltins, id)) return __nodeBuiltins[id];
    if (id.charAt(0) !== "." && id.charAt(0) !== "/") {
      throw new Error("Cannot find module '" + id + "'（宿主僅提供 node:* 之墊片）");
    }
    var resolved = id.charAt(0) === "/" ? id : __joinPath(dir, id);
    if (!/\.js$/.test(resolved) && __exists(resolved + ".js")) resolved = resolved + ".js";
    return __loadModule(resolved, false);
  }
  require.main = __mainModule;
  require.cache = __moduleCache;
  return require;
}
