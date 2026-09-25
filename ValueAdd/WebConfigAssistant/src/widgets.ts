// 唯音輸入法配置助手 // 表單控制項（Win2000 風格）。
//
// 兩條原則：
//   ① 一律用**原生**之 `<input type="radio|checkbox">`（語意、鍵盤、輔助技術皆免費），
//      僅以 CSS 之 `opacity: 0` ＋ 緊鄰之 `.vca-box` 重繪外觀。故不支援該 CSS 的瀏覽器
//      只會看到原生控制項，功能不受影響。
//   ② 每個輸入項皆帶 `data-focus-key`：重繪後由 shell 還原焦點，俾使點選選項不奪焦。

namespace VCA {
  /// 題目之互動回呼（狀態由 main 持有）。
  export interface QuestionHandlers {
    setAnswer: (question: Question, value: PrefValue) => void;
    clearAnswer: (question: Question) => void;
    changed: () => void;
  }

  /// 建立元素。
  export function el(tag: string, className: string | null, text: string | null): HTMLElement {
    var node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== null) node.appendChild(document.createTextNode(text));
    return node;
  }

  /// 清空元素之所有子節點。
  export function clearNode(node: HTMLElement): void {
    while (node.firstChild) node.removeChild(node.firstChild);
  }

  /// 對外連結（官網文章）之絕對位址。
  export function docHref(docPath: string): string {
    return VCA_DOC_BASE + docPath;
  }

  /// 取選項於該語系之標籤（依序：助手 i18n ＞ app 既有 i18n ＞ 後設資料選項標籤）。
  export function choiceLabel(question: Question, choice: QuestionChoice, lang: string): string {
    if (choice.labelKey) return t(choice.labelKey);
    if (choice.i18nKey) {
      var extra = extraLabel(choice.i18nKey, lang);
      if (extra) return extra;
    }
    if (question.entry && choice.optionValue !== null) {
      return optionLabel(question.entry, choice.optionValue, lang);
    }
    return String(choice.value);
  }

  /// 取某值之顯示文字。
  ///
  /// **一律優先走題目自身之選項標籤**——`UserDef.metaData.options` 未收錄者（注音／拼音排列
  /// 之選單名稱即為一例：那 17 條由 `KeyboardParser.localizedMenuName` 供出），若逕以
  /// `formatValue` 印出即為裸數字（如 `100`），使用者無從理解。次之才回退至後設資料之標籤／數字。
  export function labelForValue(question: Question, value: PrefValue, lang: string): string {
    for (var i = 0; i < question.choices.length; i += 1) {
      if (sameValue(question.choices[i].value, value)) {
        return choiceLabel(question, question.choices[i], lang);
      }
    }
    if (question.entry) return formatValue(question.entry, value, lang);
    return String(value);
  }

  /// 題目之標題。
  export function questionTitle(question: Question, lang: string): string {
    if (question.titleKey) return t(question.titleKey);
    if (question.entry) return shortTitleOf(question.entry, lang);
    return question.id;
  }

  /// 題目之說明（可為 `null`）。
  export function questionHelp(question: Question, lang: string): string | null {
    if (question.helpKey) return t(question.helpKey);
    if (question.entry) return descriptionOf(question.entry, lang);
    return null;
  }

  /// 現行之答案（未表態者回 `null`）。
  ///
  /// 分支樞紐與起始配置之取捨皆為自訂題、不輸出任何鍵，其答案分別寄存於
  /// `state.profile` 與 `state.starterOn`——重繪時亦須還原，
  /// 否則切換語言或往返頁面即丟失選取狀態（此缺陷由 DOM 冒煙測試抓到）。
  function currentAnswer(question: Question, state: AssistantState): PrefValue | null {
    if (!question.entry) {
      if (question.id === "origin") return state.profile.origin === "" ? null : state.profile.origin;
      if (question.id === "typing") return state.profile.typing === "" ? null : state.profile.typing;
      // 「不套用」即此題之「維持不變」：未套用時該項恆為選中態（事主 2026-09-25）。
      if (question.id === "starter") return state.starterOn ? "on" : "off";
      return null;
    }
    var value = state.answers[question.entry.rawValue];
    return typeof value === "undefined" ? null : value;
  }

  /// 單一選項列。`noteText` 為可選之尾端註記（小字級，如「維持不變」所列之出廠預設值）。
  function optionRow(
    inputType: string,
    name: string,
    focusKey: string,
    checked: boolean,
    labelText: string,
    onPick: () => void,
    noteText?: string
  )
    : HTMLElement {
    var label = el("label", "vca-opt", null);
    var input = document.createElement("input") as HTMLInputElement;
    input.type = inputType;
    input.name = name;
    input.setAttribute("data-focus-key", focusKey);
    if (checked) input.checked = true;
    input.onclick = function () { onPick(); };
    label.appendChild(input);
    label.appendChild(el("span", "vca-box", null));
    label.appendChild(el("span", "vca-opt-label", labelText));
    if (noteText) label.appendChild(el("span", "vca-opt-note", noteText));
    return label;
  }

  /// 說明文字「直接內聯」之上限（字元數）。
  ///
  /// 事主 2026-09-24 指示：若「為什麼問這個」之內容不長，就直接沿用到題目下方的註解欄位；
  /// 過長者仍收進折疊區，以免版面被長篇說明淹沒。
  var INLINE_HELP_MAX_LENGTH: number = 60;

  /// 題目之外框（標題、說明、推薦值）。
  ///
  /// - Returns: 外框，暨「說明是否已內聯顯示」（已內聯者即不再提供折疊式說明）。
  function questionFrame(
    question: Question, state: AssistantState
  )
    : { frame: HTMLElement; helpShownInline: boolean } {
    var lang = state.lang;
    var frame = el("div", "vca-q", null);
    frame.setAttribute("data-question-id", question.id);

    frame.appendChild(el("div", "vca-q-title", questionTitle(question, lang)));

    var recommended = question.entry ? effectiveRecommended(question, state.profile) : null;
    if (recommended !== null && question.entry) {
      frame.appendChild(
        el("div", "vca-rec", tf("q.recommended", [labelForValue(question, recommended, lang)]))
      );
    }

    // 短說明直接內聯（即事主所稱之「註解欄位」）。
    var help = questionHelp(question, lang);
    var helpShownInline = false;
    if (help && help.length <= INLINE_HELP_MAX_LENGTH) {
      frame.appendChild(el("div", "vca-hint", help));
      helpShownInline = true;
    }

    // 值域提示只對「數值輸入」有意義——單選題之值域即其選項，寫「可輸入 x ～ y」只會令人困惑。
    if (question.kind === "number" && question.range) {
      frame.appendChild(el("div", "vca-hint", tf("q.range", [question.range[0], question.range[1]])));
    }
    return { frame: frame, helpShownInline: helpShownInline };
  }

  /// 折疊式說明（「為什麼問這個？」＋「深入說明 →」）。說明已內聯者只留後者。
  function helpBlock(
    question: Question, state: AssistantState, docPath: string, helpShownInline: boolean
  )
    : HTMLElement | null {
    var help = helpShownInline ? null : questionHelp(question, state.lang);
    var host = el("div", "vca-why", null);
    if (!help) {
      var linkOnly = el("a", "vca-link", t("q.moreInfo"));
      (linkOnly as HTMLAnchorElement).href = docHref(docPath);
      (linkOnly as HTMLAnchorElement).target = "_blank";
      host.appendChild(linkOnly);
      return host;
    }

    var bodyText = el("div", "vca-hint", help);
    bodyText.style.display = "none";

    var toggle = el("a", "vca-link", t("q.why"));
    (toggle as HTMLAnchorElement).href = "#";
    toggle.onclick = function () {
      bodyText.style.display = bodyText.style.display === "none" ? "block" : "none";
      return false;
    };
    host.appendChild(toggle);
    host.appendChild(bodyText);

    var link = el("a", "vca-link", t("q.moreInfo"));
    (link as HTMLAnchorElement).href = docHref(docPath);
    (link as HTMLAnchorElement).target = "_blank";
    link.style.marginLeft = "8px";
    host.appendChild(link);
    return host;
  }

  /// 繪製一題。
  export function renderQuestion(
    question: Question,
    state: AssistantState,
    docPath: string,
    handlers: QuestionHandlers
  )
    : HTMLElement {
    var framed = questionFrame(question, state);
    var frame = framed.frame;
    var current = currentAnswer(question, state);
    var name = "vca-group-" + question.id;

    if (question.kind === "custom" || question.kind === "bool" || question.kind === "enum") {
      if (question.kind !== "custom") {
        frame.appendChild(optionRow(
          "radio", name, question.id + "-keep", current === null,
          t("q.keepUnchanged"),
          function () { handlers.clearAnswer(question); handlers.changed(); },
          keepUnchangedNote(question, state)
        ));
      }
      for (var i = 0; i < question.choices.length; i += 1) {
        (function (choice: QuestionChoice, index: number) {
          var selected = current !== null && sameValue(current, choice.value);
          // 與設定介面同款之分組：特定選項之前插一條分隔線（如注音排列之「酷音大千二十六鍵」前）。
          if (choice.separatorBefore) frame.appendChild(el("hr", "vca-opt-sep", null));
          frame.appendChild(optionRow(
            "radio", name, question.id + "-" + index, selected,
            choiceLabel(question, choice, state.lang),
            function () { handlers.setAnswer(question, choice.value); handlers.changed(); }
          ));
        })(question.choices[i], i);
      }
    } else if (question.kind === "number") {
      frame.appendChild(numberField(question, current, handlers));
    } else {
      frame.appendChild(textField(question, current, handlers));
    }

    var help = helpBlock(question, state, docPath, framed.helpShownInline);
    if (help) frame.appendChild(help);
    return frame;
  }

  /// 「維持不變」右側之註記：明示「保留的是您在唯音內的現值」，並附上該項之出廠預設值
  /// 供對照（事主 2026-09-24 選定「兩者並列」）。
  function keepUnchangedNote(question: Question, state: AssistantState): string | undefined {
    if (!question.entry) return undefined;
    var preset = defaultValueOf(question.entry);
    if (preset === null) return undefined;
    return tf("q.keepUnchangedNote", [labelForValue(question, preset, state.lang)]);
  }

  /// 數值欄（含 Win2000 風之上下箭頭）。
  function numberField(
    question: Question,
    current: PrefValue | null,
    handlers: QuestionHandlers
  )
    : HTMLElement {
    var host = el("div", null, null);
    var input = document.createElement("input") as HTMLInputElement;
    input.type = "text";
    input.className = "vca-num";
    input.setAttribute("data-focus-key", question.id + "-input");
    input.value = typeof current === "number" ? String(current) : "";
    var errorHost = el("div", "vca-warn", null);
    errorHost.style.display = "none";

    var commit = function () {
      var raw = input.value;
      if (trimAll(raw) === "") {
        errorHost.style.display = "none";
        handlers.clearAnswer(question);
        handlers.changed();
        return;
      }
      var entry = question.entry as UserDefEntry;
      var coerced = coerceValue(entry, raw);
      var failure = coerced === null ? "Must be an Integer." : validateValue(entry, coerced);
      if (failure !== null) {
        errorHost.firstChild ? (errorHost.firstChild.nodeValue = failure) : errorHost.appendChild(document.createTextNode(failure));
        errorHost.style.display = "block";
        return;
      }
      errorHost.style.display = "none";
      handlers.setAnswer(question, coerced as PrefValue);
      handlers.changed();
    };
    input.onchange = commit;
    input.onblur = commit;

    var step = function (delta: number) {
      var entry = question.entry as UserDefEntry;
      var base = typeof current === "number" ? current : parseInt(input.value, 10);
      if (!isFinite(base)) base = entry.range ? entry.range[0] : 0;
      var next = base + delta;
      if (entry.range) {
        if (next < entry.range[0]) next = entry.range[0];
        if (next > entry.range[1]) next = entry.range[1];
      }
      input.value = String(next);
      commit();
    };

    var spin = el("span", "vca-spin", null);
    var up = el("button", "vca-spin-btn", "▲") as HTMLButtonElement;
    var down = el("button", "vca-spin-btn", "▼") as HTMLButtonElement;
    up.type = "button";
    down.type = "button";
    up.onclick = function () { step(1); return false; };
    down.onclick = function () { step(-1); return false; };
    spin.appendChild(up);
    spin.appendChild(down);

    host.appendChild(input);
    host.appendChild(spin);
    host.appendChild(errorHost);
    host.appendChild(el("div", "vca-hint", t("q.textHint")));
    return host;
  }

  /// 文字欄（含逗號分隔之字串陣列）。
  function textField(
    question: Question,
    current: PrefValue | null,
    handlers: QuestionHandlers
  )
    : HTMLElement {
    var host = el("div", null, null);
    var input = document.createElement("input") as HTMLInputElement;
    input.type = "text";
    input.className = "vca-input";
    input.setAttribute("data-focus-key", question.id + "-input");
    if (typeof current === "string") {
      input.value = current;
    } else if (question.kind === "strings" && isStringList(current)) {
      input.value = (current as string[]).join(", ");
    }
    var errorHost = el("div", "vca-warn", null);
    errorHost.style.display = "none";

    var commit = function () {
      var entry = question.entry as UserDefEntry;
      if (trimAll(input.value) === "") {
        errorHost.style.display = "none";
        handlers.clearAnswer(question);
        handlers.changed();
        return;
      }
      var coerced = coerceValue(entry, input.value);
      var failure = coerced === null ? "Unsupported value" : validateValue(entry, coerced);
      if (failure !== null) {
        errorHost.firstChild ? (errorHost.firstChild.nodeValue = failure) : errorHost.appendChild(document.createTextNode(failure));
        errorHost.style.display = "block";
        return;
      }
      errorHost.style.display = "none";
      handlers.setAnswer(question, coerced as PrefValue);
      handlers.changed();
    };
    input.onchange = commit;
    input.onblur = commit;

    host.appendChild(input);
    host.appendChild(errorHost);
    host.appendChild(el("div", "vca-hint", t("q.textHint")));
    return host;
  }

  // MARK: - 小工具

  /// 單一核取項（如「以推薦值補齊本頁未答之項目」）。
  ///
  /// `payload` 為可選之附加引數：回呼時原樣奉還——供「同一處理函式服務一整個核取清單」之用
  /// （起始配置之回歸段即如此，見 main.ts 之 `preferenceCheckTable`）。
  export function renderCheckbox(
    focusKey: string, labelText: string, checked: boolean,
    onToggle: (checked: boolean, payload?: string) => void, payload?: string
  )
    : HTMLElement {
    var label = el("label", "vca-opt", null);
    var input = document.createElement("input") as HTMLInputElement;
    input.type = "checkbox";
    input.checked = checked;
    input.setAttribute("data-focus-key", focusKey);
    input.onclick = function () { onToggle(input.checked, payload); };
    label.appendChild(input);
    label.appendChild(el("span", "vca-box", null));
    label.appendChild(el("span", "vca-opt-label", labelText));
    return label;
  }

  /// 值之相等判定（含布林／數值／字串／字串陣列）。
  export function sameValue(lhs: PrefValue, rhs: PrefValue): boolean {
    if (typeof lhs === "boolean" || typeof rhs === "boolean") return lhs === rhs;
    if (typeof lhs === "number" && typeof rhs === "number") return lhs === rhs;
    if (typeof lhs === "string" && typeof rhs === "string") return lhs === rhs;
    if (isStringList(lhs) && isStringList(rhs)) {
      var left = lhs as string[];
      var right = rhs as string[];
      if (left.length !== right.length) return false;
      for (var i = 0; i < left.length; i += 1) {
        if (left[i] !== right[i]) return false;
      }
      return true;
    }
    return false;
  }

  function isStringList(value: PrefValue | null): boolean {
    if (value === null) return false;
    if (Object.prototype.toString.call(value) !== "[object Array]") return false;
    var list = value as string[];
    for (var i = 0; i < list.length; i += 1) {
      if (typeof list[i] !== "string") return false;
    }
    return true;
  }

  function trimAll(text: string): string {
    return String(text).replace(/^[\s\u3000]+/, "").replace(/[\s\u3000]+$/, "");
  }
}
