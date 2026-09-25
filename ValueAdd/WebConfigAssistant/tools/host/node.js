// 唯音輸入法配置助手 // node API 之墊片（Phase 246）。
//
// 建置鏈與測試所用到之 node 面（實測清單）僅止於此：
//   fs(readFileSync／writeFileSync／existsSync／readdirSync／statSync／mkdirSync)、
//   path(join／resolve／dirname／basename／relative／extname)、url(fileURLToPath)、
//   vm(runInThisContext／createContext／runInContext)、process(argv／exit／stdout.write)、
//   child_process(execFileSync，僅 `plutil` 一處)、Buffer.byteLength、
//   node:test(test／describe／it)、node:assert(ok／strictEqual／notStrictEqual／
//   deepStrictEqual／equal／throws)。
//
// 二處**非忠實**之代償，皆已於研究文件 §7.10.1 記明：
//   ① `vm` 之 context 隔離：JXA 無「新 context」之能力 ⇒ 於全域求值後回填 `VCA`／`VCA_METADATA`。
//      之所以可行：各工具自成一行程（無跨工具污染），且該處僅窺看這兩個名字。
//   ② `child_process.execFileSync('plutil', …)`：改以 `NSDictionary` 直讀 `.plist`
//      （行為等價、且省一次子行程）。

function __installNodeShim(context) {
  var toolRoot = context.toolRoot;

  // MARK: - 輸出緩衝（JXA 之 console.log 恆帶換行，故整批 flush）

  __outputBuffer = [];

  // 必須在覆蓋全域 `console` **之前**留下宿主原生之 log——否則 flush 會經由墊片之
  // console 把輸出又寫回緩衝，形成自我吞噬（本輪踩到之坑：跑完無輸出、亦無錯誤）。
  var nativeLog = console.log.bind(console);

  __flushOutput = function () {
    var text = __outputBuffer.join("");
    __outputBuffer = [];
    if (text === "") return;
    var lines = text.split("\n");
    if (lines.length > 0 && lines[lines.length - 1] === "") lines.pop();
    for (var i = 0; i < lines.length; i++) nativeLog(lines[i]);
  };

  function write(text) { __outputBuffer.push(String(text)); }

  // MARK: - fs

  var fs = {
    readFileSync: function (path) {
      var text = __readText(path);
      if (text === null) throw new Error("ENOENT: no such file or directory, open '" + path + "'");
      return text;
    },
    writeFileSync: function (path, text) {
      if (!__writeText(path, String(text))) throw new Error("EACCES: cannot write '" + path + "'");
    },
    existsSync: function (path) { return __exists(path); },
    readdirSync: function (path) {
      var names = __listDir(path);
      if (names === null) throw new Error("ENOENT: no such directory, scandir '" + path + "'");
      return names;
    },
    statSync: function (path) {
      return {
        isDirectory: function () { return __isDirectory(path); },
        isFile: function () { return __exists(path) && !__isDirectory(path); },
      };
    },
    mkdirSync: function (path) {
      if (__isDirectory(path)) return;
      __fm().createDirectoryAtPathWithIntermediateDirectoriesAttributesError(path, true, null, null);
    },
  };

  // MARK: - path

  function normalize(joined) {
    var absolute = joined.charAt(0) === "/";
    var segments = joined.split("/");
    var out = [];
    for (var i = 0; i < segments.length; i++) {
      var segment = segments[i];
      if (segment === "" || segment === ".") continue;
      if (segment === "..") { if (out.length > 0) out.pop(); continue; }
      out.push(segment);
    }
    return (absolute ? "/" : "") + out.join("/");
  }

  var path = {
    join: function () {
      var pieces = [];
      for (var i = 0; i < arguments.length; i++) {
        if (String(arguments[i]) !== "") pieces.push(String(arguments[i]));
      }
      return normalize(pieces.join("/"));
    },
    resolve: function () {
      var pieces = [];
      for (var i = 0; i < arguments.length; i++) pieces.push(String(arguments[i]));
      var joined = pieces.join("/");
      return normalize(joined.charAt(0) === "/" ? joined : __cwd() + "/" + joined);
    },
    dirname: function (p) { return __dirnameOf(p); },
    basename: function (p) {
      var index = String(p).lastIndexOf("/");
      return index < 0 ? String(p) : String(p).slice(index + 1);
    },
    // 完整實作（不可只處理「to 在 from 之下」）：`settings-surface.js` 對倉根以外之
    // 掃描目錄求相對路徑，天真版會當場造成假漂移。
    relative: function (from, to) {
      var f = path.resolve(from).split("/").filter(function (s) { return s !== ""; });
      var t = path.resolve(to).split("/").filter(function (s) { return s !== ""; });
      var i = 0;
      while (i < f.length && i < t.length && f[i] === t[i]) i += 1;
      var parts = [];
      for (var j = i; j < f.length; j += 1) parts.push("..");
      for (var k = i; k < t.length; k += 1) parts.push(t[k]);
      return parts.join("/");
    },
    extname: function (p) {
      var base = path.basename(p);
      var index = base.lastIndexOf(".");
      return index <= 0 ? "" : base.slice(index);
    },
    sep: "/",
  };

  // MARK: - url

  var url = {
    fileURLToPath: function (value) { return String(value).replace(/^file:\/\//, ""); },
  };

  // MARK: - vm（見檔首之代償①）

  var lastSandbox = {};

  var vm = {
    runInThisContext: function (code) { return (0, eval)(code); },
    createContext: function (sandbox) { lastSandbox = sandbox; return sandbox; },
    runInContext: function (code) {
      (0, eval)(code);
      if (typeof globalThis.VCA !== "undefined") lastSandbox.VCA = globalThis.VCA;
      if (typeof globalThis.VCA_METADATA !== "undefined") lastSandbox.VCA_METADATA = globalThis.VCA_METADATA;
      return undefined;
    },
  };

  // MARK: - process（`exit(0)` 僅結束本函式；各工具之呼叫點皆位於其 `main()` 之末）

  var process = {
    argv: [],
    stdout: { write: write },
    stderr: { write: write },
    exit: function (code) {
      __flushOutput();
      if (code) throw new Error("__VCA_EXIT_" + code);
    },
    cwd: function () { return __cwd(); },
  };

  // MARK: - child_process（見檔首之代償②）

  var child_process = {
    execFileSync: function (command, args) {
      if (command === "plutil") {
        var json = __plistVersionJSON(args[args.length - 1]);
        if (json === null) throw new Error("plutil：無法讀取 " + args[args.length - 1]);
        return json;
      }
      throw new Error("宿主未實作之子行程：" + command);
    },
  };

  // MARK: - Buffer（node 專屬之全域；此處僅需 byteLength）

  var Buffer = {
    byteLength: function (text) {
      var count = 0;
      for (var i = 0; i < String(text).length; i++) {
        var code = String(text).charCodeAt(i);
        if (code < 0x80) count += 1;
        else if (code < 0x800) count += 2;
        else if (code >= 0xd800 && code <= 0xdbff) { count += 4; i += 1; }
        else count += 3;
      }
      return count;
    },
  };

  // MARK: - node:test 與 node:assert（供既有測試原樣沿用）

  var collectedTests = [];
  function has(object, key) { return Object.prototype.hasOwnProperty.call(object, key); }

  function deepEqual(a, b) {
    if (a === b) return true;
    if (typeof a !== typeof b) return false;
    if (a === null || b === null) return false;
    if (typeof a !== "object") return false;
    var aArray = Object.prototype.toString.call(a) === "[object Array]";
    var bArray = Object.prototype.toString.call(b) === "[object Array]";
    if (aArray !== bArray) return false;
    if (aArray) {
      if (a.length !== b.length) return false;
      for (var i = 0; i < a.length; i++) { if (!deepEqual(a[i], b[i])) return false; }
      return true;
    }
    var keysA = Object.keys(a), keysB = Object.keys(b);
    if (keysA.length !== keysB.length) return false;
    for (var j = 0; j < keysA.length; j++) {
      if (!has(b, keysA[j])) return false;
      if (!deepEqual(a[keysA[j]], b[keysA[j]])) return false;
    }
    return true;
  }

  function assertion(ok, message, operatorName) {
    if (!ok) throw new Error((message || ("assertion failed: " + operatorName)) + " [" + operatorName + "]");
  }

  var assertModule = {
    ok: function (value, message) { assertion(!!value, message, "ok"); },
    strictEqual: function (actual, expected, message) {
      assertion(actual === expected,
        message || ("strictEqual: " + String(actual) + " !== " + String(expected)), "strictEqual");
    },
    notStrictEqual: function (actual, expected, message) {
      assertion(actual !== expected,
        message || ("notStrictEqual: " + String(actual) + " === " + String(expected)), "notStrictEqual");
    },
    deepStrictEqual: function (actual, expected, message) {
      assertion(deepEqual(actual, expected), message || "deepStrictEqual failed", "deepStrictEqual");
    },
    equal: function (actual, expected, message) { assertModule.strictEqual(actual, expected, message); },
    throws: function (fn, message) {
      var threw = false;
      try { fn(); } catch (error) { threw = true; }
      assertion(threw, message || "throws: 未拋出", "throws");
    },
  };

  var testModule = function test(name, fn) { collectedTests.push({ name: name, fn: fn }); };
  testModule.test = testModule;
  testModule.describe = function (name, fn) { fn(); };
  testModule.it = testModule;

  // MARK: - 供 loader 使用之介面

  __nodeBuiltins = {
    "node:fs": fs,
    "node:path": path,
    "node:url": url,
    "node:vm": vm,
    "node:process": process,
    "node:child_process": child_process,
    "node:assert": assertModule,
    "node:test": testModule,
  };
  __nodeGlobals = {
    fs: fs, path: path, url: url, vm: vm, process: process,
    Buffer: Buffer, console: { log: function () { write(Array.prototype.slice.call(arguments).join(" ") + "\n"); } },
  };

  // node 之 `process`／`Buffer`／`console` 皆為**全域**（工具不 require 即用），
  // 故須裝上 globalThis——否則工具會擲 `Can't find variable: process`。
  var globalScope = (typeof globalThis !== "undefined") ? globalThis : this;
  for (var globalName in __nodeGlobals) {
    if (Object.prototype.hasOwnProperty.call(__nodeGlobals, globalName)) {
      globalScope[globalName] = __nodeGlobals[globalName];
    }
  }
  __collectedTests = collectedTests;
  __toolRoot = toolRoot;
}
