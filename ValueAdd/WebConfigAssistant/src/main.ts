// 唯音輸入法配置助手 // 進入點：狀態持有、流程控制、鍵盤導覽、摘要與出口。

namespace VCA {
  var state: AssistantState;
  var refs: ShellRefs | null = null;
  var osVersion: number | null = null;

  /// 交付物之檔名（與唯音既有之 `fileExporter` 一致）。
  var PRESET_FILENAME: string = "vChewing_Preferences.json";

  // MARK: - 進入點

  /// 掛載助手。由單檔產物之末尾呼叫（見 index.html）。
  export function boot(): void {
    var host = document.getElementById("vca-root");
    if (!host) return;
    var query = parseQuery(window.location.search);
    setLang(detectLang(
      typeof query["lang"] === "string" ? query["lang"] : null,
      typeof navigator !== "undefined" ? navigator.language : null
    ));
    osVersion = osVersionFromUA(typeof navigator !== "undefined" ? navigator.userAgent : null);
    state = createInitialState(currentLang);

    refs = buildShell(host, { onNav: handleNav, onLang: handleLang });
    var requested = parseInt(String(query["step"] || ""), 10);
    if (isFinite(requested) && requested >= 1) state.stepIndex = requested - 1;
    document.documentElement.setAttribute("lang", state.lang);
    render();

    window.onkeydown = function (event: KeyboardEvent) { handleKey(event); };
  }

  function createInitialState(lang: string): AssistantState {
    return {
      lang: lang,
      stepIndex: 0,
      profile: { origin: "", typing: "" },
      answers: {},
      manual: {},
      fillAdded: {},
      metaTitle: "",
      metaDescription: "",
      fillRecommended: {},
      jsonVisible: false,
    };
  }

  function currentSteps(): Step[] {
    return buildSteps(state.profile, osVersion);
  }

  // MARK: - 繪製

  function render(): void {
    if (!refs) return;
    var shell = refs;
    var steps = currentSteps();
    if (state.stepIndex < 0) state.stepIndex = 0;
    if (state.stepIndex > steps.length - 1) state.stepIndex = steps.length - 1;
    var step = steps[state.stepIndex];

    var focusKey = captureFocusKey();
    var scrollTop = shell.content.scrollTop;

    shell.titleText.textContent = t("app.title");
    updateProgress(shell, state.stepIndex, steps.length);
    updateLeftPane(shell, step.glyph, t(step.titleKey), t("app.title"));

    clearNode(shell.content);
    if (step.id === "welcome") {
      renderWelcome(shell.content);
    } else if (step.id === "summary") {
      renderSummary(shell.content);
    } else {
      renderQuestionPage(step, shell.content);
    }

    shell.backBtn.disabled = state.stepIndex === 0;
    shell.nextBtn.textContent = state.stepIndex === steps.length - 1 ? t("nav.finish") : t("nav.next");
    shell.cancelBtn.textContent = t("nav.cancel");

    updateUrlState();
    restoreFocusKey(shell, focusKey, scrollTop);
  }

  // MARK: - 歡迎頁

  function renderWelcome(container: HTMLElement): void {
    container.appendChild(el("div", "vca-h1", t("welcome.h1")));
    container.appendChild(el("div", "vca-lead", t("welcome.p1")));
    container.appendChild(el("div", "vca-p", t("welcome.p2")));
    container.appendChild(el("div", "vca-p", t("welcome.p3")));

    // 適配之輸入法版本（#114514 之小字；值來自本目錄之 version.txt）。
    container.appendChild(
      el("div", "vca-version", tf("welcome.targetVersion", [VCA_TARGET_VERSION.display]))
    );

    var group = el("fieldset", "vca-group", null);
    group.appendChild(el("legend", null, t("welcome.language")));
    var select = el("select", "vca-select", null) as HTMLSelectElement;
    for (var i = 0; i < LANG_ORDER.length; i += 1) {
      var code = LANG_ORDER[i];
      var option = el("option", null, LANG_DISPLAY_NAMES[code] || code) as HTMLOptionElement;
      option.value = code;
      if (code === state.lang) option.selected = true;
      select.appendChild(option);
    }
    select.onchange = function () { handleLang(select.value); };
    group.appendChild(select);
    container.appendChild(group);

    container.appendChild(el("hr", "vca-rule", null));
    container.appendChild(el("div", "vca-hint", t("summary.disclaimer")));
  }

  // MARK: - 題組頁

  function renderQuestionPage(step: Step, container: HTMLElement): void {
    container.appendChild(el("div", "vca-h1", t(step.titleKey)));
    container.appendChild(el("div", "vca-lead", t(step.introKey)));

    if (step.optional) {
      var titleRow = el("div", "vca-hint", null);
      titleRow.appendChild(el("span", "vca-badge", t("q.optionalStep")));
      container.appendChild(titleRow);
    }

    if (step.skippedByOS > 0) {
      container.appendChild(el("div", "vca-hint", tf("q.osSkipped", [
        osVersion === null ? "?" : formatOSCode(osVersion), step.skippedByOS,
      ])));
    }

    var handlers: QuestionHandlers = {
      setAnswer: setAnswer,
      clearAnswer: clearAnswer,
      changed: function () { render(); },
    };

    var hasEntryQuestion = false;
    for (var i = 0; i < step.questions.length; i += 1) {
      var question = step.questions[i];
      if (question.entry) hasEntryQuestion = true;
      container.appendChild(renderQuestion(question, state, docPathFor(step, state), handlers));
    }

    // 來源頁：該來源若有專屬之接待說明（如 macOS 內建注音＝多半無須改動），即顯示於題目之下。
    if (step.id === "background") {
      var noteKey = NOTE_KEY_BY_ORIGIN[state.profile.origin];
      if (noteKey) container.appendChild(el("div", "vca-note-box", t(noteKey)));
    }

    if (hasEntryQuestion) {
      container.appendChild(el("hr", "vca-rule", null));
      var row = renderCheckbox(
        "fill-" + step.id,
        t("q.fillRecommended"),
        state.fillRecommended[step.id] === true,
        function (checked: boolean) { toggleFillRecommended(step, checked); }
      );
      container.appendChild(row);
      container.appendChild(el("div", "vca-hint", t("q.fillRecommendedNote")));
    }
  }

  // MARK: - 摘要頁

  /// 以 rawValue 取當前流程中之題目（俾使摘要表能以題目自身之選項標籤呈現值）。
  function questionIndexByRawValue(): { [rawValue: string]: Question } {
    var table: { [rawValue: string]: Question } = {};
    var steps = currentSteps();
    for (var s = 0; s < steps.length; s += 1) {
      for (var q = 0; q < steps[s].questions.length; q += 1) {
        var entry = steps[s].questions[q].entry;
        if (entry) table[entry.rawValue] = steps[s].questions[q];
      }
    }
    return table;
  }

  function renderSummary(container: HTMLElement): void {
    var preset = currentPreset();
    var questionIndex = questionIndexByRawValue();
    container.appendChild(el("div", "vca-h1", t("summary.h1")));
    container.appendChild(el("div", "vca-lead", t("summary.lead")));

    container.appendChild(metaField(
      "meta-title", t("summary.metaTitle"), state.metaTitle, t("summary.defaultTitle"),
      function (value: string) { state.metaTitle = value; }
    ));
    container.appendChild(metaField(
      "meta-description", t("summary.metaDescription"), state.metaDescription,
      t("summary.defaultDescription"),
      function (value: string) { state.metaDescription = value; }
    ));

    if (preset.accepted.length === 0) {
      container.appendChild(el("div", "vca-warn", t("summary.empty")));
    } else {
      container.appendChild(el("div", "vca-p", tf("summary.count", [preset.accepted.length])));
      var table = el("table", "vca-table", null);
      var header = el("tr", null, null);
      header.appendChild(el("th", null, t("summary.tableKey")));
      header.appendChild(el("th", null, t("summary.tableValue")));
      table.appendChild(header);
      for (var i = 0; i < preset.accepted.length; i += 1) {
        var accepted = preset.accepted[i];
        var row = el("tr", null, null);
        row.appendChild(el("td", null, shortTitleOf(accepted.entry, state.lang)));
        var question = questionIndex[accepted.entry.rawValue];
        var valueText = question
          ? labelForValue(question, accepted.value, state.lang)
          : formatValue(accepted.entry, accepted.value, state.lang);
        row.appendChild(el("td", "vca-td-value", valueText));
        table.appendChild(row);
      }
      container.appendChild(table);
    }

    if (preset.rejected.length > 0) {
      var rejectedText = "";
      for (var r = 0; r < preset.rejected.length; r += 1) {
        rejectedText += "⚠ " + preset.rejected[r].key + ": " + preset.rejected[r].reason + "\n";
      }
      container.appendChild(el("pre", "vca-warn", rejectedText));
    }

    container.appendChild(el("hr", "vca-rule", null));

    var buttons = el("div", null, null);
    var status = el("div", "vca-hint", "");
    var copyBtn = el("button", "vca-btn", t("summary.copy")) as HTMLButtonElement;
    copyBtn.type = "button";
    copyBtn.onclick = function () {
      copyText(preset.json, function (ok: boolean) {
        status.textContent = ok ? t("summary.copied") : t("summary.copyFailed");
        if (!ok) {
          state.jsonVisible = true;
          render();
        }
      });
      return false;
    };
    var downloadBtn = el("button", "vca-btn", t("summary.download")) as HTMLButtonElement;
    downloadBtn.type = "button";
    downloadBtn.onclick = function () {
      var ok = downloadText(PRESET_FILENAME, preset.json);
      status.textContent = ok ? t("summary.downloadHint") : t("summary.copyManual");
      if (!ok) {
        state.jsonVisible = true;
        render();
      }
      return false;
    };
    buttons.appendChild(copyBtn);
    buttons.appendChild(downloadBtn);
    container.appendChild(buttons);
    container.appendChild(status);

    container.appendChild(el("hr", "vca-rule", null));

    container.appendChild(el("div", "vca-h2", t("summary.next")));
    var list = el("ol", "vca-steps", null);
    list.appendChild(el("li", null, t("summary.next1")));
    list.appendChild(el("li", null, t("summary.next2")));
    list.appendChild(el("li", null, t("summary.next3")));
    container.appendChild(list);

    var jsonToggle = el("a", "vca-link", state.jsonVisible ? t("summary.hideJson") : t("summary.showJson"));
    (jsonToggle as HTMLAnchorElement).href = "#";
    jsonToggle.onclick = function () {
      state.jsonVisible = !state.jsonVisible;
      render();
      return false;
    };
    container.appendChild(jsonToggle);

    if (state.jsonVisible) {
      var area = document.createElement("textarea") as HTMLTextAreaElement;
      area.className = "vca-textarea";
      area.setAttribute("data-focus-key", "summary-json");
      area.value = preset.json;
      area.readOnly = true;
      container.appendChild(area);
      container.appendChild(el("div", "vca-hint", t("summary.copyManual")));
    }

    container.appendChild(el("hr", "vca-rule", null));
    container.appendChild(el("div", "vca-hint", t("summary.defaultsNote")));
    container.appendChild(el("div", "vca-hint", t("summary.disclaimer")));
  }

  function metaField(
    focusKey: string, label: string, value: string, placeholder: string,
    onChange: (value: string) => void
  )
    : HTMLElement {
    var host = el("div", "vca-q", null);
    host.appendChild(el("div", "vca-q-title", label));
    var input = document.createElement("input") as HTMLInputElement;
    input.type = "text";
    input.className = "vca-input";
    input.value = value;
    input.setAttribute("placeholder", placeholder);
    input.setAttribute("data-focus-key", focusKey);
    input.onchange = function () { onChange(input.value); };
    input.onblur = function () { onChange(input.value); };
    host.appendChild(input);
    return host;
  }

  // MARK: - 狀態操作

  function setAnswer(question: Question, value: PrefValue): void {
    if (!question.entry) {
      if (question.id === "origin") state.profile.origin = String(value);
      if (question.id === "typing") {
        state.profile.typing = String(value);
        pruneHiddenAnswers();
      }
      return;
    }
    state.answers[question.entry.rawValue] = value;
    state.manual[question.entry.rawValue] = true;
  }

  function clearAnswer(question: Question): void {
    if (!question.entry) {
      if (question.id === "origin") state.profile.origin = "";
      if (question.id === "typing") {
        state.profile.typing = "";
        pruneHiddenAnswers();
      }
      return;
    }
    delete state.answers[question.entry.rawValue];
    delete state.manual[question.entry.rawValue];
  }

  /// 分支切換後，丟棄已不可見之題目的答案（免得把使用者看不到的鍵寫進配置包）。
  function pruneHiddenAnswers(): void {
    var steps = currentSteps();
    var visible: { [rawValue: string]: boolean } = {};
    for (var s = 0; s < steps.length; s += 1) {
      for (var q = 0; q < steps[s].questions.length; q += 1) {
        var entry = steps[s].questions[q].entry;
        if (entry) visible[entry.rawValue] = true;
      }
    }
    var raws = Object.keys(state.answers);
    for (var i = 0; i < raws.length; i += 1) {
      if (visible[raws[i]]) continue;
      delete state.answers[raws[i]];
      delete state.manual[raws[i]];
    }
  }

  function toggleFillRecommended(step: Step, checked: boolean): void {
    state.fillRecommended[step.id] = checked;
    var added = state.fillAdded[step.id] || [];
    if (checked) {
      var additions = fillSuggestions(step, state);
      var raws = Object.keys(additions);
      for (var i = 0; i < raws.length; i += 1) {
        state.answers[raws[i]] = additions[raws[i]];
        if (added.indexOf(raws[i]) < 0) added.push(raws[i]);
      }
    } else {
      for (var j = 0; j < added.length; j += 1) {
        if (state.manual[added[j]]) continue;
        delete state.answers[added[j]];
      }
      added = [];
    }
    state.fillAdded[step.id] = added;
    render();
  }

  function effectiveTitle(): string {
    return state.metaTitle.replace(/^\s+|\s+$/g, "") || t("summary.defaultTitle");
  }

  function effectiveDescription(): string {
    return state.metaDescription.replace(/^\s+|\s+$/g, "") || t("summary.defaultDescription");
  }

  function currentPreset(): PresetBuildResult {
    return buildPreset({
      answers: state.answers,
      title: effectiveTitle(),
      description: effectiveDescription(),
    });
  }

  // MARK: - 導覽

  function handleNav(action: string): void {
    var steps = currentSteps();
    if (action === "cancel") {
      showConfirm(
        t("nav.confirmTitle"), t("nav.confirmMessage"), t("nav.confirmYes"), t("nav.confirmNo"),
        function () {
          state = createInitialState(state.lang);
          render();
        },
        function () { /* 繼續作答 */ }
      );
      return;
    }
    if (action === "back") {
      if (state.stepIndex > 0) {
        state.stepIndex -= 1;
        render();
      }
      return;
    }
    if (action === "next") {
      if (state.stepIndex < steps.length - 1) {
        state.stepIndex += 1;
        render();
        return;
      }
      showFinishDialog();
    }
  }

  function showFinishDialog(): void {
    showInfo(t("summary.h1"), [
      t("summary.next1"), t("summary.next2"), t("summary.next3"),
    ].join("\n"), "OK");
  }

  function handleLang(lang: string): void {
    setLang(lang);
    state.lang = currentLang;
    document.documentElement.setAttribute("lang", state.lang);
    render();
  }

  /// 鍵盤導覽：Alt+← 上一步、Enter 下一步（輸入框內之 Enter 先落定再前進）。
  function handleKey(event: KeyboardEvent): void {
    if (modalOpen) return;
    var target = event.target as HTMLElement | null;
    var tag = target && target.tagName ? String(target.tagName).toLowerCase() : "";
    if (tag === "textarea" || tag === "select") return;
    if (event.altKey && event.keyCode === 37) {
      handleNav("back");
      return;
    }
    if (event.keyCode !== 13) return;
    if (tag === "button" || tag === "a") return;
    if (tag === "input") {
      var inputType = String((target as HTMLInputElement).type).toLowerCase();
      if (inputType === "radio" || inputType === "checkbox") return;
      if (typeof (target as HTMLInputElement).blur === "function") (target as HTMLInputElement).blur();
    }
    handleNav("next");
  }

  // MARK: - 網址狀態（供分享與深層連結）

  function updateUrlState(): void {
    try {
      var historyAny = window.history as unknown as {
        replaceState?: (data: unknown, title: string, url: string) => void;
      };
      if (!historyAny || typeof historyAny.replaceState !== "function") return;
      var query = "?lang=" + encodeURIComponent(state.lang) + "&step=" + (state.stepIndex + 1);
      historyAny.replaceState(null, document.title, window.location.pathname + query);
    } catch (error) {
      // `file://` 之下可能拋錯：忽略即可（助手之功能不依賴網址）。
    }
  }

  function parseQuery(search: string): { [key: string]: string } {
    var result: { [key: string]: string } = {};
    if (!search) return result;
    var body = search.charAt(0) === "?" ? search.slice(1) : search;
    var pairs = body.split("&");
    for (var i = 0; i < pairs.length; i += 1) {
      if (!pairs[i]) continue;
      var separator = pairs[i].indexOf("=");
      var key = separator < 0 ? pairs[i] : pairs[i].slice(0, separator);
      var value = separator < 0 ? "" : pairs[i].slice(separator + 1);
      result[decodeURIComponent(key)] = decodeURIComponent(value.replace(/\+/g, " "));
    }
    return result;
  }
}
