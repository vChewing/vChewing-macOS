// 唯音輸入法配置助手 // 建置鏈之宿主入口（Phase 246）。
//
// 以 macOS 內建之 **JXA**（`osascript -l JavaScript`）為 JS 宿主，令整條建置鏈
// 只要求 devenv 事先安裝 `tsc`。
//
// 用法：
//   osascript -l JavaScript tools/host/run.js <工具.js> [該工具之引數…]
//   osascript -l JavaScript tools/host/run.js --tests
//
// 何以此處不用 `jsc`（同為系統內建、且更快）：`jsc` 缺三樣本鏈需要之物——
// ① 無目錄列舉（`readFile` 對目錄直接拋錯，全域亦無 `readDir`／`stat` 一類）；
// ② 無子行程能力（`target-version.js` 需讀 `.plist`）；
// ③ 無 argv（傳入之引數會被當成**待載入之檔案**）。
// JXA 三者皆備，且啟動僅約 0.02–0.03 s。詳見
// `vChewing-DevLogs/Research/Phase245-PostResearch.md` §7.10.1。

ObjC.import("Foundation");

// MARK: - 原生層（唯一與 JXA 打交道之處；其餘皆為 JS）

function __fm() { return $.NSFileManager.defaultManager; }

function __readText(path) {
  var text = $.NSString.stringWithContentsOfFileEncodingError(path, $.NSUTF8StringEncoding, null);
  return text.isNil() ? null : ObjC.unwrap(text);
}

function __writeText(path, text) {
  return $.NSString.alloc.initWithUTF8String(text)
    .writeToFileAtomicallyEncodingError(path, true, $.NSUTF8StringEncoding, null);
}

function __listDir(path) {
  var items = __fm().contentsOfDirectoryAtPathError(path, null);
  if (items.isNil()) return null;
  var out = [];
  for (var i = 0; i < items.count; i++) out.push(ObjC.unwrap(items.objectAtIndex(i)));
  return out;
}

function __isDirectory(path) {
  var flag = Ref();
  return __fm().fileExistsAtPathIsDirectory(path, flag) && flag[0];
}

function __exists(path) { return __fm().fileExistsAtPath(path); }

/// 讀取 `.plist` 之兩個版本鍵並回傳 JSON——即 `plutil -convert json -o -` 之等價物。
/// `target-version.js` 原本以 `execFileSync('plutil', …)` 取得；此處不經子行程。
function __plistVersionJSON(path) {
  var dict = $.NSDictionary.dictionaryWithContentsOfFile(path);
  if (dict.isNil()) return null;
  return JSON.stringify({
    CFBundleShortVersionString: ObjC.unwrap(dict.objectForKey("CFBundleShortVersionString")) || "",
    CFBundleVersion: ObjC.unwrap(dict.objectForKey("CFBundleVersion")) || "",
  });
}

function __cwd() { return ObjC.unwrap(__fm().currentDirectoryPath); }

// MARK: - 啟動期之最小路徑工具（正式之 `path` 模組在 host/node.js）

function __dirnameOf(path) {
  var index = String(path).lastIndexOf("/");
  return index <= 0 ? "/" : String(path).slice(0, index);
}

function __joinPath(left, right) {
  var joined = String(left) + "/" + String(right);
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

function __isAbsolute(path) { return String(path).charAt(0) === "/"; }

// MARK: - 進入點

function run(argv) {
  var programArguments = $.NSProcessInfo.processInfo.arguments;
  // programArguments ＝ ["/usr/bin/osascript", "-l", "JavaScript", <本檔>, …]
  var selfPath = ObjC.unwrap(programArguments.objectAtIndex(3));
  var selfDir = __dirnameOf(selfPath);
  var hostDir = __isAbsolute(selfDir) ? selfDir : __joinPath(__cwd(), selfDir);
  var toolRoot = __joinPath(hostDir, "..");
  var packageRoot = __joinPath(toolRoot, "..");

  (0, eval)(__readText(__joinPath(hostDir, "node.js")));
  (0, eval)(__readText(__joinPath(hostDir, "loader.js")));

  __installNodeShim({ toolRoot: toolRoot, packageRoot: packageRoot });

  if (argv.length === 0) {
    throw new Error("用法：osascript -l JavaScript tools/host/run.js <工具.js> [引數…] | --tests");
  }

  if (argv[0] === "--tests") {
    (0, eval)(__readText(__joinPath(hostDir, "tests.js")));
    __runTestSuite(packageRoot);
    __flushOutput();
    return;
  }

  var entryPath = __isAbsolute(argv[0]) ? argv[0] : __joinPath(__cwd(), argv[0]);
  process.argv = ["osascript", entryPath].concat(argv.slice(1));
  try {
    __loadModule(entryPath, true);
  } catch (error) {
    __flushOutput();
    if (error && error.isToolExit) {
      // 擲字串、不擲 Error：osascript 會自加一層「Error: 」，故字串之訊息較乾淨。
      throw "工具以狀態 " + error.exitCode + " 收場；診斷見上方輸出";
    }
    throw error;
  }
  __flushOutput();
}
