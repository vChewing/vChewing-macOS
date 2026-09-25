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

    // 起始配置預設即已套用（見 createInitialState），故開機即落答案——否則該頁會顯示
    // 「套用」選中而配置包仍是空的（狀態與產物不一致）。
    syncStarter();

    refs = buildShell(host, { onNav: handleNav, onLang: handleLang });
    // 深層連結：`?express=0` 表逐項路線（否則收到的頁碼會被快速路線夾到摘要）。
    if (query["express"] === "0") state.expressOnly = false;
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
      // 預設即「套用」（事主 2026-09-25：「使用者叫出這個配置畫面就是為了想切換配置的」）。
      starterOn: true,
      starterAdded: {},
      // 兩段皆為逐項核取清單，預設全選（故兩表為空＝無人被取消）。
      starterNamedOff: {},
      starterResetOff: {},
      // 預設即「只套用起始配置」：事主 2026-09-25 明示「不必硬控使用者走完十二頁，
      // 只套用 presets 的話四頁足矣」——故快速路線為預設，逐項微調為選項。
      expressOnly: true,
      skipFromIndex: -1,
      metaTitle: "",
      metaDescription: "",
      fillRecommended: {},
      jsonVisible: false,
    };
  }

  function currentSteps(): Step[] {
    return buildSteps(state.profile, osVersion, state.expressOnly);
  }

  /// 取某頁在當前流程內之索引；無該頁者回 -1。
  function stepIndexOf(steps: Step[], id: string): number {
    for (var i = 0; i < steps.length; i += 1) {
      if (steps[i].id === id) return i;
    }
    return -1;
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
    // 左側水印區之第三行：該頁之**職能**（原放助手全稱，與標題帶重複且無益）。
    updateLeftPane(shell, step.glyph, t(step.titleKey), t(step.noteKey));

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
    shell.skipBtn.textContent = t("nav.toSummary");
    // 「跳到摘要」只在起始配置之後露面，且僅當後面還有**兩頁以上**時才有意義
    // （只差一頁者，按「下一步」即是）。
    var starterIndex = stepIndexOf(steps, "starter");
    var summaryIndex = steps.length - 1;
    var showSkip = starterIndex >= 0 && state.stepIndex >= starterIndex &&
      state.stepIndex < summaryIndex - 1;
    shell.skipBtn.style.display = showSkip ? "" : "none";

    updateUrlState();
    restoreFocusKey(shell, focusKey, scrollTop);
  }

  // MARK: - 歡迎頁

  function renderWelcome(container: HTMLElement): void {
    container.appendChild(el("div", "vca-h1", t("welcome.h1")));
    container.appendChild(el("div", "vca-lead", t("welcome.p1")));
    container.appendChild(el("div", "vca-p", t("welcome.p4")));
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

    if (step.id === "starter") appendStarterHeader(container);

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

    if (step.id === "starter") appendStarterFooter(container);

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

  // MARK: - 起始配置頁

  /// 頁首：點明「依您原本的輸入法」＋**當下的提醒**（可提前結束，除非想要更細緻的配置）。
  function appendStarterHeader(container: HTMLElement): void {
    var origin = state.profile.origin;
    container.appendChild(el("div", "vca-p", origin === ""
      ? t("starter.leadUnknown")
      : tf("starter.lead", [originDisplayName()])));
    container.appendChild(el("div", "vca-note-box", t(
      state.expressOnly ? "starter.noteExpress" : "starter.noteDetail"
    )));
  }

  /// 頁尾：將寫入之內容預覽（明示、可核對）＋「只套用起始配置」之取捨。
  ///
  /// 預覽分兩段（見 starter.ts 檔首之封閉性）：本組**指名**者、以及**回歸出廠預設**者。
  /// 兩段之鍵數合計恆為全集之大小——故同一台電腦上換人套用時，後者必然完整覆蓋前者。
  function appendStarterFooter(container: HTMLElement): void {
    var starter = starterFor(state.profile, osVersion);
    if (state.starterOn) {
      // 兩段皆為**逐項核取清單**（預設全選）：使用者可就任何一項取消勾選。
      // 「指名」段為本組配置之立場；「回歸」段為本組未指名而一併寫回出廠預設者。
      if (starter.namedKeys.length === 0) {
        container.appendChild(el("div", "vca-hint", t("starter.empty")));
      } else {
        container.appendChild(starterBlockHeading(
          tf("starter.namedTitle", [starter.namedKeys.length]), starter, "named"));
        container.appendChild(preferenceCheckTable(starter, starter.namedKeys, "named"));
        var namedOff = excludedCountOfScope(starter, "named");
        if (namedOff > 0) {
          container.appendChild(el("div", "vca-hint", tf("starter.namedNoteOff", [namedOff])));
        }
      }
      if (starter.resetKeys.length > 0) {
        container.appendChild(starterBlockHeading(
          tf("starter.resetTitle", [starter.resetKeys.length]), starter, "reset"));
        container.appendChild(preferenceCheckTable(starter, starter.resetKeys, "reset"));
        var resetOff = excludedCountOfScope(starter, "reset");
        container.appendChild(el("div", "vca-hint", resetOff === 0
          ? t("starter.resetNoteOn")
          : tf("starter.resetNoteOff", [resetOff])));
      }
      if (starter.keys.length > 0) {
        container.appendChild(el("div", "vca-hint", t("starter.undoHint")));
      }
    }

    container.appendChild(el("hr", "vca-rule", null));
    container.appendChild(renderCheckbox(
      "starter-express",
      t("starter.express"),
      state.expressOnly,
      function (checked: boolean) {
        state.expressOnly = checked;
        render();
      }
    ));
    container.appendChild(el("div", "vca-hint", t("starter.expressNote")));
  }

  /// 該鍵於表格內之顯示名。
  ///
  /// 少數鍵自身無標籤（如 `kAssociatedPhrasesEnabled`——它只出現在輸入法選單，而選單項之
  /// 標籤由 `kUsingHotKeyAssociates` 承載）；此時改取其別名鍵之標籤，免得對使用者印出
  /// 內部 rawValue。
  function displayTitleOf(entry: UserDefEntry): string {
    var title = shortTitleOf(entry, state.lang);
    if (title !== entry.rawValue) return title;
    var aliasKey = LABEL_ENTRY_ALIAS[entry.key];
    var alias = aliasKey ? entryByKey(aliasKey) : null;
    return alias ? shortTitleOf(alias, state.lang) : title;
  }

  /// 某段之核取清單所對應之狀態表（`named` 為指名段、`reset` 為回歸段）。
  ///
  /// 兩表皆存「被取消者」——**預設為空即全選**，語意自明。
  function excludedTableOfScope(scope: string): { [rawValue: string]: boolean } {
    return scope === "named" ? state.starterNamedOff : state.starterResetOff;
  }

  /// 某段之全部鍵。
  function keysOfScope(starter: StarterPreset, scope: string): string[] {
    return scope === "named" ? starter.namedKeys : starter.resetKeys;
  }

  /// 某段中已被取消勾選之鍵數。
  function excludedCountOfScope(starter: StarterPreset, scope: string): number {
    return excludedKeyCount(keysOfScope(starter, scope), excludedTableOfScope(scope));
  }

  /// 段落標題（右綴該段之「全部取消勾選／全部勾選」連結）。
  ///
  /// 連結緊貼標題——兩段各有一條同名連結，緊貼標題方能一眼看出其作用範圍。
  function starterBlockHeading(titleText: string, starter: StarterPreset, scope: string): HTMLElement {
    var host = el("div", "vca-h2", null);
    host.appendChild(document.createTextNode(titleText));
    var allExcluded = excludedCountOfScope(starter, scope) === keysOfScope(starter, scope).length;
    var toggleAll = el("a", "vca-link", t(
      allExcluded ? "starter.resetCheckAll" : "starter.resetUncheckAll"
    ));
    (toggleAll as HTMLAnchorElement).href = "#";
    toggleAll.style.marginLeft = "8px";
    toggleAll.onclick = function () {
      setAllExcluded(starter, scope, !allExcluded);
      return false;
    };
    host.appendChild(toggleAll);
    return host;
  }

  /// 某段之逐項核取清單（預設全選）。
  ///
  /// 該段每一鍵各一核取項：取消者即不予更動（回到「稀疏」之舉）。
  function preferenceCheckTable(starter: StarterPreset, keys: string[], scope: string): HTMLElement {
    var questionIndex = questionIndexByRawValue();
    var table = el("table", "vca-table", null);
    var header = el("tr", null, null);
    header.appendChild(el("th", null, t("summary.tableKey")));
    header.appendChild(el("th", null, t("summary.tableValue")));
    table.appendChild(header);
    for (var i = 0; i < keys.length; i += 1) {
      var raw = keys[i];
      var entry = entryByRawValue(raw);
      if (!entry) continue;
      var row = el("tr", null, null);
      var labelCell = el("td", null, null);
      labelCell.appendChild(renderCheckbox(
        "starter-" + scope + "-" + raw,
        displayTitleOf(entry),
        excludedTableOfScope(scope)[raw] !== true,
        function (checked: boolean, key?: string) {
          if (key) setExcluded(scope, key, !checked);
        },
        raw
      ));
      row.appendChild(labelCell);
      var question = questionIndex[raw];
      var valueText = question
        ? labelForValue(question, starter.values[raw], state.lang)
        : formatValue(entry, starter.values[raw], state.lang);
      row.appendChild(el("td", "vca-td-value", valueText));
      table.appendChild(row);
    }
    return table;
  }

  /// 勾選／取消勾選某段之單一項，並即時重算答案集。
  function setExcluded(scope: string, rawValue: string, excluded: boolean): void {
    var table = excludedTableOfScope(scope);
    if (excluded) {
      table[rawValue] = true;
    } else {
      delete table[rawValue];
    }
    syncStarter();
    render();
  }

  /// 某段之全選／全部取消。
  function setAllExcluded(starter: StarterPreset, scope: string, excluded: boolean): void {
    var table: { [rawValue: string]: boolean } = {};
    if (excluded) {
      var keys = keysOfScope(starter, scope);
      for (var i = 0; i < keys.length; i += 1) table[keys[i]] = true;
    }
    if (scope === "named") {
      state.starterNamedOff = table;
    } else {
      state.starterResetOff = table;
    }
    syncStarter();
    render();
  }

  /// 套用（或取消套用）當前 profile 之起始配置。
  ///
  /// 本函式**不**負責重繪：呼叫端（`setAnswer`／`clearAnswer` 之既有流程）會處置。
  function applyStarter(on: boolean): void {
    state.starterOn = on;
    syncStarter();
  }

  /// 依 profile 重新推算起始配置之內容，並據以更新答案集。
  ///
  /// 兩條紀律：
  ///   ① 使用者**親自**表態者一律不動（起始配置不得覆蓋人的決定）；
  ///   ② 先前由起始配置加入、而使用者未改過者，於換 profile 或取消套用時撤回
  ///      ——免得把使用者看不到的鍵留在配置包內。
  function syncStarter(): void {
    var previous = Object.keys(state.starterAdded);
    for (var i = 0; i < previous.length; i += 1) {
      if (state.manual[previous[i]]) continue;
      delete state.answers[previous[i]];
    }
    state.starterAdded = {};
    if (!state.starterOn) return;
    var starter = starterFor(state.profile, osVersion);
    var written = starterWrittenKeys(starter, state.starterNamedOff, state.starterResetOff);
    for (var j = 0; j < written.length; j += 1) {
      var raw = written[j];
      if (state.manual[raw]) continue;
      state.answers[raw] = starter.values[raw];
      state.starterAdded[raw] = true;
    }
  }

  // MARK: - 摘要頁

  /// 以 rawValue 取題目（俾使摘要表能以題目自身之選項標籤呈現值）。
  ///
  /// 索引**一律取整份題庫**（且以「還不確定」之超集取之），而非當前流程或當前 profile
  /// 可見之頁面——快速路線上逐項頁面並不在流程內，而起始配置之「回歸」段更會觸及當前
  /// profile 根本不出題之鍵（如注音使用者之磁帶鍵），若只索引當前可見者，摘要表與預覽表
  /// 就會在那些鍵上退回 `formatValue`，把注音／拼音排列之類的選項印成裸數字（如 100）。
  /// 標籤之正確性與流程模式、分支皆無關，故索引亦不應隨之增減。
  function questionIndexByRawValue(): { [rawValue: string]: Question } {
    var table: { [rawValue: string]: Question } = {};
    var questions = allQuestionsFor({ origin: "newbie", typing: "unsure" }, osVersion);
    for (var q = 0; q < questions.length; q += 1) {
      var entry = questions[q].entry;
      if (entry) table[entry.rawValue] = questions[q];
    }
    return table;
  }

  /// 兩欄表之一列。
  interface PreferenceRow {
    key: string;
    value: PrefValue;
  }

  /// 兩欄表（偏好選項／將寫入的值）：摘要頁與起始配置頁共用。
  ///
  /// 值之呈現一律優先走題目自身之選項標籤（`labelForValue`）——`UserDef.metaData.options`
  /// 未收錄者（注音／拼音排列之選單名稱即為一例）若逕以 `formatValue` 印出即為裸數字。
  function preferenceTable(rows: PreferenceRow[]): HTMLElement {
    var questionIndex = questionIndexByRawValue();
    var table = el("table", "vca-table", null);
    var header = el("tr", null, null);
    header.appendChild(el("th", null, t("summary.tableKey")));
    header.appendChild(el("th", null, t("summary.tableValue")));
    table.appendChild(header);
    for (var i = 0; i < rows.length; i += 1) {
      var entry = entryByRawValue(rows[i].key);
      if (!entry) continue;
      var row = el("tr", null, null);
      row.appendChild(el("td", null, displayTitleOf(entry)));
      var question = questionIndex[rows[i].key];
      var valueText = question
        ? labelForValue(question, rows[i].value, state.lang)
        : formatValue(entry, rows[i].value, state.lang);
      row.appendChild(el("td", "vca-td-value", valueText));
      table.appendChild(row);
    }
    return table;
  }

  function renderSummary(container: HTMLElement): void {
    var preset = currentPreset();
    container.appendChild(el("div", "vca-h1", t("summary.h1")));
    container.appendChild(el("div", "vca-lead", t("summary.lead")));

    container.appendChild(metaField(
      "meta-title", t("summary.metaTitle"), state.metaTitle, defaultTitle(),
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
      // 已套用起始配置者：明示「這份配置對上列每一項都有決定權」——含未指名而回歸
      // 出廠預設者，此即同一台電腦上換人套用時不互相殘留之由來。
      if (state.starterOn) {
        var starterPreset = starterFor(state.profile, osVersion);
        var excludedNamed = excludedCountOfScope(starterPreset, "named");
        if (excludedNamed > 0) {
          container.appendChild(el("div", "vca-hint", tf("summary.starterNamedExcluded", [excludedNamed])));
        }
        var excludedReset = excludedCountOfScope(starterPreset, "reset");
        var scopeText = t("summary.starterScope");
        if (excludedReset > 0) {
          scopeText = excludedReset >= starterPreset.resetKeys.length
            ? t("summary.starterScopeOff")
            : tf("summary.starterScopePartial", [excludedReset]);
        }
        container.appendChild(el("div", "vca-hint", scopeText));
      }
      var rows: PreferenceRow[] = [];
      for (var i = 0; i < preset.accepted.length; i += 1) {
        rows.push({ key: preset.accepted[i].entry.rawValue, value: preset.accepted[i].value });
      }
      container.appendChild(preferenceTable(rows));
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
      if (question.id === "origin") {
        state.profile.origin = String(value);
        // 起始配置之內容由 profile 決定：換了來源即得重算（已套用者）。
        syncStarter();
      }
      if (question.id === "typing") {
        state.profile.typing = String(value);
        pruneHiddenAnswers();
        syncStarter();
      }
      if (question.id === "starter") applyStarter(value === "on");
      return;
    }
    state.answers[question.entry.rawValue] = value;
    state.manual[question.entry.rawValue] = true;
  }

  function clearAnswer(question: Question): void {
    if (!question.entry) {
      if (question.id === "origin") {
        state.profile.origin = "";
        syncStarter();
      }
      if (question.id === "typing") {
        state.profile.typing = "";
        pruneHiddenAnswers();
        syncStarter();
      }
      if (question.id === "starter") applyStarter(false);
      return;
    }
    delete state.answers[question.entry.rawValue];
    delete state.manual[question.entry.rawValue];
    delete state.starterAdded[question.entry.rawValue];
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
      delete state.starterAdded[raws[i]];
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

  /// 配置名稱：使用者填者優先；未填者於「已套用起始配置」時給出對應之預設名
  /// （唯音之匯入確認視窗會顯示它，故比「自訂配置」更該說明來歷）。
  function effectiveTitle(): string {
    var typed = state.metaTitle.replace(/^\s+|\s+$/g, "");
    return typed ? typed : defaultTitle();
  }

  function defaultTitle(): string {
    // 未套用起始配置者、或尚未表態來源者（此時無從命名），一律用通用之「自訂配置」
    // ——否則會得出「自訂配置的起始配置」這種疊字。
    if (!state.starterOn || state.profile.origin === "") return t("summary.defaultTitle");
    return tf("summary.starterTitle", [originDisplayName()]);
  }

  /// 當前來源之顯示名（未表態者回「自訂配置」之語意）。
  ///
  /// 標籤過長者（如並列七款產品之「狂拼流漢語拼音輸入法」）取短名——內文與配置名皆然；
  /// 該短名僅供**引用**，題目之選項仍顯示全名。
  function originDisplayName(): string {
    if (!state.profile.origin) return t("summary.defaultTitle");
    var shortKey = ORIGIN_SHORT_NAME_KEY[state.profile.origin];
    if (shortKey) return t(shortKey);
    return t("origin.opt." + state.profile.origin);
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
        // 由「跳到摘要」而來者，先原路折返至跳轉前所在之頁（而非逕退至最後一頁之逐項問題）。
        var fromSkip = state.skipFromIndex >= 0 && state.stepIndex === steps.length - 1;
        state.stepIndex = fromSkip ? state.skipFromIndex : state.stepIndex - 1;
        state.skipFromIndex = -1;
        render();
      }
      return;
    }
    if (action === "summary") {
      // 「跳到摘要」：就此收束（詳見 shell.ts 之 skipBtn）。**不改**流程模式——
      // 使用者若只是先看一眼，按「上一步」即回到原頁，其先前之逐項作答不會被動到。
      state.skipFromIndex = state.stepIndex;
      state.stepIndex = steps.length - 1;
      render();
      return;
    }
    if (action === "next") {
      state.skipFromIndex = -1;
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
      var query = "?lang=" + encodeURIComponent(state.lang) +
        "&express=" + (state.expressOnly ? "1" : "0") +
        "&step=" + (state.stepIndex + 1);
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
