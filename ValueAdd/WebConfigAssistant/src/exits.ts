// 唯音輸入法配置助手 // 出口：剪貼簿與檔案下載。
//
// 相容性策略（目標含 macOS 10.9 之 Safari 7）：
//   ① 剪貼簿：`navigator.clipboard`（現代）＞ `document.execCommand("copy")`（Safari 10 起）
//      ＞ 交由呼叫端顯示內文區、請使用者自行全選複製（Safari 7 僅此途）。
//   ② 下載：`Blob` ＋ `<a download>`（Safari 10.1 起）＞ `data:` URL 另開視窗。

namespace VCA {
  /// 複製文字至剪貼簿。`done(true)` 表成功。
  export function copyText(text: string, done: (ok: boolean) => void): void {
    var nav = navigator as unknown as { clipboard?: { writeText?: (s: string) => { then: Function } } };
    if (nav.clipboard && typeof nav.clipboard.writeText === "function") {
      var op = nav.clipboard.writeText(text);
      op.then(
        function () { done(true); },
        function () { done(legacyCopy(text)); }
      );
      return;
    }
    done(legacyCopy(text));
  }

  /// 舊路線：暫時性 textarea ＋ `execCommand("copy")`。
  function legacyCopy(text: string): boolean {
    var area = document.createElement("textarea") as HTMLTextAreaElement;
    area.value = text;
    area.setAttribute("readonly", "readonly");
    area.style.position = "fixed";
    area.style.left = "-4000px";
    area.style.top = "0";
    document.body.appendChild(area);
    var ok = false;
    try {
      area.select();
      if (typeof document.execCommand === "function") ok = document.execCommand("copy") === true;
    } catch (error) {
      ok = false;
    }
    document.body.removeChild(area);
    return ok;
  }

  /// 該環境是否支援 `<a download>`（Safari 10.1 起）。不支援時不得走 Blob 路線，
  /// 否則 Safari 7 會直接**導航**至該 blob、離開助手。
  export function supportsDownloadAttribute(): boolean {
    var probe = document.createElement("a");
    return typeof probe.setAttribute === "function" && "download" in probe;
  }

  /// 下載文字為檔案。回 `true` 表已交予瀏覽器。
  export function downloadText(filename: string, text: string): boolean {
    var windowAny = window as unknown as {
      Blob?: new (parts: string[], options: { type: string }) => unknown;
      URL?: { createObjectURL?: (b: unknown) => string; revokeObjectURL?: (u: string) => void };
      webkitURL?: { createObjectURL?: (b: unknown) => string; revokeObjectURL?: (u: string) => void };
    };
    var urlApi = windowAny.URL || windowAny.webkitURL;

    if (windowAny.Blob && urlApi && typeof urlApi.createObjectURL === "function" &&
      supportsDownloadAttribute()) {
      try {
        var blob = new windowAny.Blob([text], { type: "application/json" });
        var href = (urlApi.createObjectURL as (b: unknown) => string)(blob);
        var link = document.createElement("a") as HTMLAnchorElement;
        link.href = href;
        link.setAttribute("download", filename);
        link.style.display = "none";
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        if (typeof urlApi.revokeObjectURL === "function") {
          var revoke = urlApi.revokeObjectURL as (u: string) => void;
          window.setTimeout(function () { revoke(href); }, 4000);
        }
        return true;
      } catch (error) {
        // 落至 data: 路線。
      }
    }

    try {
      var dataHref = "data:application/json;charset=utf-8," + encodeURIComponent(text);
      var opened = window.open(dataHref, "_blank");
      return opened !== null && typeof opened !== "undefined";
    } catch (error2) {
      return false;
    }
  }
}
