// 唯音輸入法配置助手 // 外框（Win2000 安裝程式風：標題帶、左側水印區、內容區、按鈕列）。

namespace VCA {
  /// 外框之事件回呼。
  export interface ShellHandlers {
    onNav: (action: string) => void;
    onLang: (lang: string) => void;
  }

  /// 外框之節點參照。
  export interface ShellRefs {
    root: HTMLElement;
    glyph: HTMLElement;
    leftTitle: HTMLElement;
    leftNote: HTMLElement;
    content: HTMLElement;
    titleText: HTMLElement;
    /// 標題帶右側之「步數文字」格位（`display: table-cell`）。
    titleProgress: HTMLElement;
    /// 標題帶右側之「分段方塊」格位（`display: table-cell`）。
    titleSegments: HTMLElement;
    backBtn: HTMLButtonElement;
    nextBtn: HTMLButtonElement;
    cancelBtn: HTMLButtonElement;
  }

  /// 建立整個外框。
  export function buildShell(host: HTMLElement, handlers: ShellHandlers): ShellRefs {
    clearNode(host);

    var root = el("div", "vca-window", null);

    // 標題帶
    var titlebar = el("div", "vca-titlebar", null);
    var titleText = el("span", "vca-titlebar-text", t("app.title"));
    var titleRight = el("span", "vca-titlebar-right", null);
    // 步數文字與分段方塊各為一個表格格位（`display: table-cell` ＋ `vertical-align: middle`）——
    // 如此兩者之垂直置中與字型基線無關，不會像 inline-block ＋ `vertical-align: middle` 那樣
    // 被半 x-height 推低（事主 2026-09-24：分段方塊「過於貼近標題列的底側」）。
    var titleProgress = el("span", "vca-titlebar-progress", null);
    var titleSegments = el("span", "vca-seg-host", null);
    // 標題帶右側只放步數與分段方塊——**不設關閉鈕**（事主 2026-09-24：取消已由底部按鈕承擔，
    // 該鈕非必需）。
    titleRight.appendChild(titleProgress);
    titleRight.appendChild(titleSegments);
    titlebar.appendChild(titleText);
    titlebar.appendChild(titleRight);

    // 主體
    var body = el("div", "vca-body", null);
    var left = el("div", "vca-left", null);
    var glyph = el("div", "vca-glyph", "");
    var leftTitle = el("div", "vca-left-title", "");
    var leftNote = el("div", "vca-left-note", "");
    left.appendChild(glyph);
    left.appendChild(leftTitle);
    left.appendChild(leftNote);

    var main = el("div", "vca-main", null);
    var content = el("div", "vca-content", null);
    main.appendChild(content);
    body.appendChild(left);
    body.appendChild(main);

    // 按鈕列
    var footer = el("div", "vca-footer", null);
    var cancelBtn = el("button", "vca-btn", t("nav.cancel")) as HTMLButtonElement;
    var backBtn = el("button", "vca-btn", t("nav.back")) as HTMLButtonElement;
    var nextBtn = el("button", "vca-btn", t("nav.next")) as HTMLButtonElement;
    cancelBtn.type = "button";
    backBtn.type = "button";
    nextBtn.type = "button";
    cancelBtn.onclick = function () { handlers.onNav("cancel"); return false; };
    backBtn.onclick = function () { handlers.onNav("back"); return false; };
    nextBtn.onclick = function () { handlers.onNav("next"); return false; };
    footer.appendChild(cancelBtn);
    footer.appendChild(backBtn);
    footer.appendChild(nextBtn);

    root.appendChild(titlebar);
    root.appendChild(body);
    root.appendChild(footer);
    host.appendChild(root);

    return {
      root: root, glyph: glyph, leftTitle: leftTitle, leftNote: leftNote,
      content: content, titleText: titleText, titleProgress: titleProgress,
      titleSegments: titleSegments,
      backBtn: backBtn, nextBtn: nextBtn, cancelBtn: cancelBtn,
    };
  }

  /// 更新標題帶之進度（「第 %1 步，共 %2 步」＋一排分段方塊）。
  export function updateProgress(refs: ShellRefs, index: number, total: number): void {
    refs.titleProgress.textContent = tf("app.stepCounter", [index + 1, total]);
    clearNode(refs.titleSegments);
    for (var i = 0; i < total; i += 1) {
      refs.titleSegments.appendChild(el("span", i <= index ? "vca-seg vca-seg-done" : "vca-seg", null));
    }
  }

  /// 更新左側水印區。
  export function updateLeftPane(refs: ShellRefs, glyph: string, title: string, note: string): void {
    refs.glyph.firstChild ? (refs.glyph.firstChild.nodeValue = glyph) : refs.glyph.appendChild(document.createTextNode(glyph));
    refs.leftTitle.firstChild
      ? (refs.leftTitle.firstChild.nodeValue = title)
      : refs.leftTitle.appendChild(document.createTextNode(title));
    clearNode(refs.leftNote);
    if (note) refs.leftNote.appendChild(document.createTextNode(note));
  }

  /// 記錄當前焦點之 `data-focus-key`（重繪前呼叫）。
  export function captureFocusKey(): string | null {
    var active = document.activeElement as HTMLElement | null;
    if (!active || typeof active.getAttribute !== "function") return null;
    return active.getAttribute("data-focus-key");
  }

  /// 還原焦點與內容區之捲動位置（重繪後呼叫）。
  export function restoreFocusKey(refs: ShellRefs, focusKey: string | null, scrollTop: number): void {
    refs.content.scrollTop = scrollTop;
    if (!focusKey) return;
    var found = refs.content.querySelector('[data-focus-key="' + focusKey + '"]') as HTMLElement | null;
    if (found && typeof found.focus === "function") found.focus();
  }

  /// 模態對話框是否開著（開著時，全域鍵盤處理一律讓位）。
  export var modalOpen: boolean = false;

  /// 建立模態對話框之共同外框，回傳「內容區」與 `close()`。
  function makeDialog(title: string, onClose?: () => void): { body: HTMLElement; footer: HTMLElement; close: () => void } {
    var layer = el("div", "vca-modal-layer", null);
    var dialog = el("div", "vca-dialog", null);
    var titlebar = el("div", "vca-titlebar", null);
    titlebar.appendChild(el("span", "vca-titlebar-text", title));
    var body = el("div", "vca-dialog-body", null);
    var footer = el("div", "vca-dialog-footer", null);
    var close = function () {
      modalOpen = false;
      if (layer.parentNode) layer.parentNode.removeChild(layer);
      if (dialog.parentNode) dialog.parentNode.removeChild(dialog);
      if (onClose) onClose();
    };
    dialog.appendChild(titlebar);
    dialog.appendChild(body);
    dialog.appendChild(footer);
    document.body.appendChild(layer);
    document.body.appendChild(dialog);
    modalOpen = true;
    return { body: body, footer: footer, close: close };
  }

  /// Win2000 風之單鍵訊息框。
  export function showInfo(title: string, message: string, okLabel: string): void {
    var dialog = makeDialog(title);
    var lines = message.split("\n");
    for (var i = 0; i < lines.length; i += 1) {
      dialog.body.appendChild(el("div", "vca-p", lines[i]));
    }
    var ok = el("button", "vca-btn", okLabel) as HTMLButtonElement;
    ok.type = "button";
    ok.onclick = function () { dialog.close(); return false; };
    dialog.footer.appendChild(ok);
    ok.focus();
  }

  /// Win2000 風之模態確認對話框。
  export function showConfirm(
    title: string, message: string, yesLabel: string, noLabel: string,
    onYes: () => void, onNo: () => void
  )
    : void {
    var dialog = makeDialog(title);
    dialog.body.appendChild(el("div", "vca-p", message));
    var yes = el("button", "vca-btn", yesLabel) as HTMLButtonElement;
    var no = el("button", "vca-btn", noLabel) as HTMLButtonElement;
    yes.type = "button";
    no.type = "button";
    yes.onclick = function () { dialog.close(); onYes(); return false; };
    no.onclick = function () { dialog.close(); onNo(); return false; };
    dialog.footer.appendChild(yes);
    dialog.footer.appendChild(no);
    no.focus();
  }
}
