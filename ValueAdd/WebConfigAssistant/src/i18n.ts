// 唯音輸入法配置助手 // 助手自身之介面文案（四語系）。
//
// **產品名一律取 app l10n 之全稱**（`i18n:Common.VChewing`）：「唯音輸入法」／「唯音输入法」／
// 「vChewing」／「唯音入力アプリ」，其後接「配置助手」——故本檔之 `app.title`、`welcome.h1`、
// `nav.confirmTitle`、`summary.defaultDescription` 皆用全稱。**唯一例外**：`summary.next3` 內
// 所引之字串係 app 按鈕文案之逐字引用（其作「由配置助手生成的」），不得改動。
//
// 分工：**偏好選項之標題與說明不在此檔**——那些由 app 之 `.strings` 經
// `vChewingSharedCLI dump-userdef-metadata` 導出（見 assets/userdef-metadata.json），
// 故助手之措辭永不與 app 分歧。本檔只承載「助手自己發明的句子」（步驟標題、按鈕、
// 摘要頁、自訂題目之選項……）。
//
// 語體紀律：`zh-Hans` 一律為 **zh-Hans-TW**（臺灣華語、簡體字形）——只簡化字形、
// 不改成大陸用語（詳見 README；並由 tests/i18n.test.js 守住）。

namespace VCA {
  /// 語系之決定序：URL `?lang=` ＞ `navigator.language` ＞ `zh-Hant`。
  export var LANG_ORDER: string[] = ["zh-Hant", "zh-Hans", "en", "ja"];

  /// 語言選單內之顯示名（一律以該語言自稱）。
  export var LANG_DISPLAY_NAMES: { [code: string]: string } = {
    "zh-Hant": "繁體中文",
    "zh-Hans": "简体中文",
    "en": "English",
    "ja": "日本語",
  };

  /// 助手之介面文案。鍵集以 `zh-Hant` 為準，其餘語系缺鍵時回退至 `zh-Hant`，
  /// 完整性由 tests/i18n.test.js 守住。
  export var UI_STRINGS: { [lang: string]: UIStringTable } = {
    "zh-Hant": {
      // 共用
      "app.title": "唯音輸入法配置助手",
      "app.stepCounter": "第 %1 步，共 %2 步",
      "nav.back": "＜ 上一步",
      "nav.next": "下一步 ＞",
      "nav.finish": "完成",
      "nav.cancel": "取消",
      "nav.toSummary": "跳到摘要 ＞",
      "nav.confirmTitle": "取消唯音輸入法配置助手",
      "nav.confirmMessage": "確定要取消嗎？目前為止的作答內容都會被清空。",
      "nav.confirmYes": "確定",
      "nav.confirmNo": "繼續作答",
      "q.keepUnchanged": "維持不變",
      "q.keepUnchangedNote": "推薦；保留您目前在唯音內的設定值，出廠預設為：%1",
      "q.fillRecommended": "以推薦值（或出廠預設值）補齊本頁未答之項目",
      "q.fillRecommendedNote": "勾選後，本頁中有推薦值、但您尚未表態的項目會一併寫入配置包。",
      "q.recommended": "推薦值：%1",
      "q.why": "為什麼問這個？",
      "q.moreInfo": "深入說明 →",
      "q.range": "可輸入 %1 ～ %2。",
      "q.textHint": "留空即維持不變。",
      "q.osTooOld": "此選項需要 macOS %1 或以上（您的系統為 %2），故已略過。",
      "q.osSkipped": "已依您的系統版本（%1）略過 %2 個需要較新系統的選項。",
      "q.optionalStep": "可整頁跳過",

      // 歡迎頁
      "welcome.h1": "歡迎使用唯音輸入法配置助手",
      "welcome.p1": "唯音的偏好設定有上百個選項，對第一次接觸的人並不友善。本助手會問您幾組簡單的問題，據此整理出一份「配置包」；您再把配置包匯入唯音即可。",
      "welcome.p2": "每一題的預設答案都是「維持不變」：您沒有表態的項目，助手一律不會代您決定。",
      "welcome.p3": "本助手完全在您的瀏覽器內運作，不會擅自將您填入的偏好帶離這台電腦，也不會讀取您電腦上的任何設定。",
      "welcome.p4": "選妥您原本使用的輸入法之後，助手會先給出一組現成的「起始配置」；套用它即可直接產生配置包，不必逐頁回答。",
      "welcome.targetVersion": "適配唯音輸入法 %1",
      "welcome.language": "介面語言：",

      // 步驟標題與導言
      "step.background.title": "您的輸入習慣",
      "step.background.intro": "這兩題不會寫入任何設定，只決定助手推薦給您的起始配置、以及接下來問您哪些問題。",
      "step.starter.title": "起始配置",
      "step.starter.intro": "唯音針對您原本使用的輸入法，準備了一組建議先套用的設定；套用之後，您可以直接產生配置包，也可以繼續逐項微調。",
      "step.method.title": "打字方式",
      "step.method.intro": "唯音支援注音組句、注音逐字選字（「ㄅ半」）、漢語拼音與 CIN 字根（行列、倉頡、嘸蝦米……）。",
      "step.rhythm.title": "打字節奏與聲調",
      "step.rhythm.intro": "這些選項決定唯音如何處理聲調、讀音糾正與未完成的拼寫。",
      "step.keys.title": "按鍵行為",
      "step.keys.intro": "這些選項決定 Shift、空格、Tab、Enter 等按鍵在唯音內的意義。",
      "step.candidate.title": "選字窗",
      "step.candidate.intro": "選字窗是唯音最常被看到的介面。這裡的選項只影響外觀與操作，不影響辭典內容。",
      "step.mixed.title": "中英混打",
      "step.mixed.intro": "唯音可以在同一段輸入內處理中文與英數，不必反覆切換輸入法。",
      "step.punctuation.title": "標點、數字與符號",
      "step.punctuation.intro": "這些選項決定標點的全形／半形、以及數字與符號的輸出方式。",
      "step.lexicon.title": "辭典與智慧功能",
      "step.lexicon.intro": "這些選項決定唯音查辭典、以及學習您選字習慣的方式。",
      "step.notify.title": "通知與系統整合",
      "step.notify.intro": "這些選項決定唯音在畫面上顯示哪些提示、以及與系統其他部分的互動。",
      "step.advanced.title": "進階選項",
      "step.advanced.intro": "這些選項多半與疑難排解或特殊客體軟體有關。沒有遇到問題的話，整頁跳過即可。",
      "step.summary.title": "摘要與產生",
      "step.summary.intro": "請確認下面的內容，然後產生配置包。",

      // 左側水印區之職能說明（`left.<stepId>`；一句話說明「這一頁在替您做什麼」）
      "left.welcome": "說明本助手的用途與流程",
      "left.background": "決定推薦內容與後續頁面",
      "left.starter": "可先套用，亦可略過",
      "left.method": "打字方式相關的設定",
      "left.rhythm": "聲調與打字節奏",
      "left.keys": "按鍵在唯音內的意義",
      "left.candidate": "選字窗的外觀與操作",
      "left.mixed": "中英混打時的行為",
      "left.punctuation": "標點、數字與符號",
      "left.lexicon": "辭典查詢與學習方式",
      "left.notify": "畫面提示與系統整合",
      "left.advanced": "疑難排解與特殊客體",
      "left.summary": "核對內容並產生配置包",

      // 自訂題目：原始輸入法
      "origin.title": "您原本用哪一款輸入法？",
      "origin.intro": "若您原本用的是這裡沒列出的輸入法，請選「我是全新使用者」。",
      "origin.opt.macoszhuyin": "macOS 內建注音（10.6 Snow Leopard 起）",
      "origin.opt.msnewphonetic": "微軟新注音（Windows）",
      "origin.opt.kimo": "雅虎奇摩輸入法",
      "origin.opt.mcbpmf": "小麥注音",
      "origin.opt.ov": "OpenVanilla",
      "origin.opt.hanin": "漢音輸入法",
      "origin.opt.goingime": "自然輸入法",
      "origin.opt.asus": "華碩／ASUS",
      "origin.opt.cin": "行列三十／倉頡／嘸蝦米等字根輸入法",
      "origin.opt.pinyin": "狂拼流漢語拼音輸入法（微軟拼音／微信輸入法／搜狗拼音／昇陽拼音／智能狂拼／紫光拼音／Rime）",
      "origin.opt.newbie": "我是全新使用者",

      // 自訂題目：打字方式
      "typing.title": "您主要用哪一種打字方式？",
      "typing.intro": "這只影響助手推薦的起始配置與接下來問您哪些問題，本身不會寫入任何設定。",
      "origin.note.macoszhuyin": "唯音的預設值就是照 macOS 10.9 開始的內建注音的習慣來的（含聲調鍵覆寫字音、選字游標置於詞語前方）——您多半不需要改任何設定，直接按「下一步」即可。",
      "origin.short.pinyin": "狂拼流漢語拼音輸入法",
      "typing.opt.zhuyin": "注音組句（打一整串再選字）",
      "typing.opt.zhuyinmix": "注音組句＋中英混打",
      "typing.opt.scpc": "注音逐字選字（倚天中文 DOS 系統「ㄅ半」派）",
      "typing.opt.pinyin": "漢語拼音",
      "typing.opt.cin": "CIN 字根（行列、倉頡、嘸蝦米……）",
      "typing.opt.unsure": "還不確定／其他",

      // 起始配置頁
      "starter.title": "是否套用這組起始配置？",
      "starter.intro": "套用與否皆不影響其他選項；未套用者一律維持您目前的設定。",
      "starter.opt.off": "不套用（維持不變）",
      "starter.opt.on": "套用這組起始配置",
      "starter.lead": "您原本使用的是「%1」。以下是唯音建議先套用的起始配置。",
      "starter.leadUnknown": "以下是唯音建議先套用的起始配置。",
      "starter.empty": "唯音的出廠預設值已經貼近您原本的習慣，本組配置沒有指名任何項目（下列各項仍可逐項決定是否回歸出廠預設）。",
      "starter.namedNoteOff": "您取消了 %1 項指名項目：這些項目不予更動，將維持唯音目前的設定。",
      "starter.namedTitle": "本組指名的項目（共 %1 項）",
      "starter.resetTitle": "一併回歸唯音出廠預設的項目（共 %1 項）",
      "starter.undoHint": "套用後仍可逐項改回「維持不變」；取消套用則整組撤回。",
      "starter.resetNoteOn": "以上各項本組未特別指定，仍一併寫入唯音的出廠預設值——同一台電腦上若有人套用過別的配置，唯有如此才能確保您拿到的是這一組配置的樣子。不需要的項目請取消勾選。",
      "starter.resetNoteOff": "您取消了 %1 項的回歸：他人（或您先前）套用過的配置，可能仍在這些項目上留下痕跡。",
      "starter.resetUncheckAll": "全部取消勾選",
      "starter.resetCheckAll": "全部勾選",
      "starter.noteExpress": "多數使用者到這裡就夠了。套用之後按「下一步」即直接前往摘要、產生配置包——後面的逐項問題只有在您想更細緻地調整時才需要回答。",
      "starter.noteDetail": "提醒：您隨時可以按「跳到摘要」直接產生配置包，不必回答完後面的問題。",
      "starter.express": "只套用起始配置：跳過後面的逐項問題，直接前往摘要",
      "starter.expressNote": "取消勾選即可繼續回答後面的逐項問題（各項皆可維持不變）。",

      // 摘要頁
      "summary.h1": "摘要與產生",
      "summary.lead": "以下是助手將寫入配置包的內容。未列出的項目一律維持您目前的設定。",
      "summary.empty": "您尚未表態任何項目。您仍可產生一份空的配置包，或按「＜ 上一步」回頭作答。",
      "summary.tableKey": "偏好選項",
      "summary.tableValue": "將寫入的值",
      "summary.count": "共 %1 項。",
      "summary.metaTitle": "配置名稱：",
      "summary.metaDescription": "這份配置的用途（會顯示在唯音的匯入確認視窗內）：",
      "summary.defaultTitle": "自訂配置",
      "summary.starterTitle": "%1的起始配置",
      "summary.defaultDescription": "由唯音輸入法配置助手產生。",
      "summary.copy": "拷貝配置資料",
      "summary.download": "下載配置檔案",
      "summary.copied": "已拷貝到剪貼簿。",
      "summary.copyManual": "您的瀏覽器不支援自動拷貝。請在下方文字區內按 Command+A 全選、再按 Command+C 拷貝。",
      "summary.copyFailed": "自動拷貝失敗。請在下方文字區內按 Command+A 全選、再按 Command+C 拷貝。",
      "summary.showJson": "顯示配置包內容（JSON）",
      "summary.hideJson": "隱藏配置包內容（JSON）",
      "summary.next": "接下來怎麼做？",
      "summary.next1": "① 按「拷貝配置資料」。",
      "summary.next2": "② 開啟「唯音偏好設定 → 一般設定」。",
      "summary.next3": "③ 按「點此從剪貼簿匯入（由配置助手生成的）配置資料」，核對清單後按「套用」。",
      "summary.downloadHint": "下載的配置檔也可以直接拖進「唯音偏好設定 → 開發道場」的匯入區。",
      "summary.disclaimer": "助手提供的是可選的起點、不是必須。所有變更都只是寫入偏好設定，隨時可以在唯音偏好設定內改回來。",
      "summary.starterScope": "上列每一項都由此配置決定：其中未指名者一律回歸唯音出廠預設，故不會殘留他人（或您先前）套用過的配置。",
      "summary.starterScopeOff": "本配置只寫入您表態的項目；未指名者一律不動——他人先前套用過的配置可能仍在那些項目上。",
      "summary.starterScopePartial": "上列之中，您取消了 %1 項的回歸出廠預設；那些項目不予更動，他人先前套用過的配置可能仍在。",
      "summary.starterNamedExcluded": "您取消了 %1 項指名項目——那些項目不予更動，將維持唯音目前的設定。",
      "summary.defaultsNote": "「維持不變」的項目不會寫入；極少數項目（例如字級）會由唯音於匯入後再行校正。部分變更須待下次啟用輸入法時才會生效。",

      // 值之格式化
      "value.on": "啟用",
      "value.off": "停用",
      "value.none": "（無）",
    },

    "zh-Hans": {
      // 共用
      "app.title": "唯音输入法配置助手",
      "app.stepCounter": "第 %1 步，共 %2 步",
      "nav.back": "＜ 上一步",
      "nav.next": "下一步 ＞",
      "nav.finish": "完成",
      "nav.cancel": "取消",
      "nav.toSummary": "跳到摘要 ＞",
      "nav.confirmTitle": "取消唯音输入法配置助手",
      "nav.confirmMessage": "确定要取消吗？目前為止的作答内容都会被清空。",
      "nav.confirmYes": "确定",
      "nav.confirmNo": "继续作答",
      "q.keepUnchanged": "维持不变",
      "q.keepUnchangedNote": "推荐；保留您目前在唯音内的设定值，出厂预设为：%1",
      "q.fillRecommended": "以推荐值（或出厂预设值）补齐本页未答的项目",
      "q.fillRecommendedNote": "勾选后，本页中有推荐值、但您尚未表态的项目会一併写入配置包。",
      "q.recommended": "推荐值：%1",
      "q.why": "为什么问这个？",
      "q.moreInfo": "深入说明 →",
      "q.range": "可输入 %1 ～ %2。",
      "q.textHint": "留空即维持不变。",
      "q.osTooOld": "此项目需要 macOS %1 或以上（您的系统为 %2），故已略过。",
      "q.osSkipped": "已依您的系统版本（%1）略过 %2 个需要较新系统的项目。",
      "q.optionalStep": "可整页跳过",

      // 欢迎页
      "welcome.h1": "欢迎使用唯音输入法配置助手",
      "welcome.p1": "唯音的偏好设定有上百个项目，对第一次接触的人并不友善。本助手会问您几组简单的问题，据此整理出一份「配置包」；您再把配置包汇入唯音即可。",
      "welcome.p2": "每一题的预设答案都是「维持不变」：您没有表态的项目，助手一律不会代您决定。",
      "welcome.p3": "本助手完全在您的浏览器内运作，不会擅自将您填入的偏好带离这台电脑，也不会读取您电脑上的任何设定。",
      "welcome.p4": "选妥您原本使用的输入法之后，助手会先给出一组现成的「起始配置」；套用它即可直接产生配置包，不必逐页回答。",
      "welcome.targetVersion": "适配唯音输入法 %1",
      "welcome.language": "介面语言：",

      // 步骤标题与导言
      "step.background.title": "您的输入习惯",
      "step.background.intro": "这两题不会写入任何设定，只决定助手推荐给您的起始配置、以及接下来问您哪些项目。",
      "step.starter.title": "起始配置",
      "step.starter.intro": "唯音针对您原本使用的输入法，准备了一组建议先套用的设定；套用之后，您可以直接产生配置包，也可以继续逐项微调。",
      "step.method.title": "打字方式",
      "step.method.intro": "唯音支援注音组句、注音逐字选字（「ㄅ半」）、汉语拼音与 CIN 字根（行列、仓颉、呒虾米……）。",
      "step.rhythm.title": "打字节奏与声调",
      "step.rhythm.intro": "这些项目决定唯音如何处理声调、读音纠正与未完成的拼写。",
      "step.keys.title": "按键行为",
      "step.keys.intro": "这些项目决定 Shift、空格、Tab、Enter 等按键在唯音内的意义。",
      "step.candidate.title": "选字窗",
      "step.candidate.intro": "选字窗是唯音最常被看到的介面。这里的项目只影响外观与操作，不影响辞典内容。",
      "step.mixed.title": "中英混打",
      "step.mixed.intro": "唯音可以在同一段输入内处理中文与英数，不必反覆切换输入法。",
      "step.punctuation.title": "标点、数字与符号",
      "step.punctuation.intro": "这些项目决定标点的全形／半形、以及数字与符号的输出方式。",
      "step.lexicon.title": "辞典与智慧功能",
      "step.lexicon.intro": "这些项目决定唯音查辞典、以及学习您选字习惯的方式。",
      "step.notify.title": "通知与系统整合",
      "step.notify.intro": "这些项目决定唯音在画面上显示哪些提示、以及与系统其他部分的互动。",
      "step.advanced.title": "进阶项目",
      "step.advanced.intro": "这些项目多半与疑难排解或特殊客体软体有关。没有遇到问题的话，整页跳过即可。",
      "step.summary.title": "摘要与产生",
      "step.summary.intro": "请确认下面的内容，然后产生配置包。",

      // 左侧水印区之职能说明（`left.<stepId>`；一句话说明「这一页在替您做什么」）
      "left.welcome": "说明本助手的用途与流程",
      "left.background": "决定推荐内容与后续页面",
      "left.starter": "可先套用，亦可略过",
      "left.method": "打字方式相关的设定",
      "left.rhythm": "声调与打字节奏",
      "left.keys": "按键在唯音内的意义",
      "left.candidate": "选字窗的外观与操作",
      "left.mixed": "中英混打时的行为",
      "left.punctuation": "标点、数字与符号",
      "left.lexicon": "辞典查询与学习方式",
      "left.notify": "画面提示与系统整合",
      "left.advanced": "疑难排解与特殊客体",
      "left.summary": "核对内容并产生配置包",

      // 自订题目：原始输入法
      "origin.title": "您原本用哪一款输入法？",
      "origin.intro": "若您原本用的是这里没列出的输入法，请选「我是全新使用者」。",
      "origin.opt.macoszhuyin": "macOS 内建注音（10.6 Snow Leopard 起）",
      "origin.opt.msnewphonetic": "微软新注音（Windows）",
      "origin.opt.kimo": "雅虎奇摩输入法",
      "origin.opt.mcbpmf": "小麦注音",
      "origin.opt.ov": "OpenVanilla",
      "origin.opt.hanin": "汉音输入法",
      "origin.opt.goingime": "自然输入法",
      "origin.opt.asus": "华硕／ASUS",
      "origin.opt.cin": "行列三十／仓颉／呒虾米等字根输入法",
      "origin.opt.pinyin": "狂拼流汉语拼音输入法（微软拼音／微信输入法／搜狗拼音／升阳拼音／智能狂拼／紫光拼音／Rime）",
      "origin.opt.newbie": "我是全新使用者",

      // 自订题目：打字方式
      "typing.title": "您主要用哪一种打字方式？",
      "typing.intro": "这只影响助手推荐的起始配置与接下来问您哪些项目，本身不会写入任何设定。",
      "origin.note.macoszhuyin": "唯音的预设值就是照 macOS 10.9 开始的内建注音的习惯来的（含声调键覆写字音、选字游标置于词语前方）——您多半不需要改任何设定，直接按「下一步」即可。",
      "origin.short.pinyin": "狂拼流汉语拼音输入法",
      "typing.opt.zhuyin": "注音组句（打一整串再选字）",
      "typing.opt.zhuyinmix": "注音组句＋中英混打",
      "typing.opt.scpc": "注音逐字选字（倚天中文 DOS 系统「ㄅ半」派）",
      "typing.opt.pinyin": "汉语拼音",
      "typing.opt.cin": "CIN 字根（行列、仓颉、呒虾米……）",
      "typing.opt.unsure": "还不确定／其他",

      // 自订题目：选字窗字型

      // 起始配置页
      "starter.title": "是否套用这组起始配置？",
      "starter.intro": "套用与否皆不影响其他项目；未套用者一律维持您目前的设定。",
      "starter.opt.off": "不套用（维持不变）",
      "starter.opt.on": "套用这组起始配置",
      "starter.lead": "您原本使用的是「%1」。以下是唯音建议先套用的起始配置。",
      "starter.leadUnknown": "以下是唯音建议先套用的起始配置。",
      "starter.empty": "唯音的出厂预设值已经贴近您原本的习惯，本组配置没有指名任何项目（下列各项仍可逐项决定是否回归出厂预设）。",
      "starter.namedNoteOff": "您取消了 %1 项指名项目：这些项目不予更动，将维持唯音目前的设定。",
      "starter.namedTitle": "本组指名的项目（共 %1 项）",
      "starter.resetTitle": "一并回归唯音出厂预设的项目（共 %1 项）",
      "starter.undoHint": "套用后仍可逐项改回「维持不变」；取消套用则整组撤回。",
      "starter.resetNoteOn": "以上各项目本组未特别指定，仍一并写入唯音的出厂预设值——同一台电脑上若有人套用过别的配置，唯有如此才能确保您拿到的是这一组配置的样子。不需要的项目请取消勾选。",
      "starter.resetNoteOff": "您取消了 %1 项的回歸：他人（或您先前）套用过的配置，可能仍在这些项目上留下痕迹。",
      "starter.resetUncheckAll": "全部取消勾选",
      "starter.resetCheckAll": "全部勾选",
      "starter.noteExpress": "多数使用者到这里就够了。套用之后按「下一步」即直接前往摘要、产生配置包——后面的逐项问题只有在您想更细致的调整时才需要回答。",
      "starter.noteDetail": "提醒：您随时可以按「跳到摘要」直接产生配置包，不必回答完后面的问题。",
      "starter.express": "只套用起始配置：跳过后面的逐项问题，直接前往摘要",
      "starter.expressNote": "取消勾选即可继续回答后面的逐项问题（各项皆可维持不变）。",

      // 摘要页
      "summary.h1": "摘要与产生",
      "summary.lead": "以下是助手将写入配置包的内容。未列出的项目一律维持您目前的设定。",
      "summary.empty": "您尚未表态任何项目。您仍可产生一份空的配置包，或按「＜ 上一步」回头作答。",
      "summary.tableKey": "偏好项目",
      "summary.tableValue": "将写入的值",
      "summary.count": "共 %1 项。",
      "summary.metaTitle": "配置名称：",
      "summary.metaDescription": "这份配置的用途（会显示在唯音的汇入确认视窗内）：",
      "summary.defaultTitle": "自订配置",
      "summary.starterTitle": "%1的起始配置",
      "summary.defaultDescription": "由唯音输入法配置助手产生。",
      "summary.copy": "拷贝配置资料",
      "summary.download": "下载配置档案",
      "summary.copied": "已拷贝到剪贴簿。",
      "summary.copyManual": "您的浏览器不支援自动拷贝。请在下方文字区内按 Command+A 全选、再按 Command+C 拷贝。",
      "summary.copyFailed": "自动拷贝失败。请在下方文字区内按 Command+A 全选、再按 Command+C 拷贝。",
      "summary.showJson": "显示配置包内容（JSON）",
      "summary.hideJson": "隐藏配置包内容（JSON）",
      "summary.next": "接下来怎么做？",
      "summary.next1": "① 按「拷贝配置资料」。",
      "summary.next2": "② 开启「唯音偏好设定 → 一般设定」。",
      "summary.next3": "③ 按「点此从剪贴簿汇入（由配置助手生成的）配置资料」，核对清单后按「套用」。",
      "summary.downloadHint": "下载的配置档也可以直接拖进「唯音偏好设定 → 开发道场」的汇入区。",
      "summary.disclaimer": "助手提供的是可选的起点、不是必须。所有变更都只是写入偏好设定，随时可以在唯音偏好设定内改回来。",
      "summary.starterScope": "上列每一项目都由此配置决定：其中未指名者一律回归唯音出厂预设，故不会残留他人（或您先前）套用过的配置。",
      "summary.starterScopeOff": "本配置只写入您表态的项目；未指名者一律不动——他人先前套用过的配置可能仍在那些项目上。",
      "summary.starterScopePartial": "上列之中，您取消了 %1 项的回归出厂预设；那些项目不予更动，他人先前套用过的配置可能仍在。",
      "summary.starterNamedExcluded": "您取消了 %1 项指名项目——那些项目不予更动，将维持唯音目前的设定。",
      "summary.defaultsNote": "「维持不变」的项目不会写入；极少数项目（例如字号）会由唯音于汇入后再行校正。部分变更须待下次启用输入法时才会生效。",

      // 值之格式化
      "value.on": "启用",
      "value.off": "停用",
      "value.none": "（无）",
    },

    en: {
      // Shared
      "app.title": "vChewing Configuration Assistant",
      "app.stepCounter": "Step %1 of %2",
      "nav.back": "< Back",
      "nav.next": "Next >",
      "nav.finish": "Finish",
      "nav.cancel": "Cancel",
      "nav.toSummary": "Skip to summary >",
      "nav.confirmTitle": "Cancel the vChewing Configuration Assistant",
      "nav.confirmMessage": "Cancel for sure? Everything you have answered so far will be discarded.",
      "nav.confirmYes": "Yes",
      "nav.confirmNo": "Keep going",
      "q.keepUnchanged": "Keep unchanged",
      "q.keepUnchangedNote": "Recommended; keeps your current value in vChewing. Factory default: %1",
      "q.fillRecommended": "Fill in this page's unanswered items with recommended (or factory default) values",
      "q.fillRecommendedNote": "When checked, items on this page that have a recommended value but were left unanswered will also be written into the profile.",
      "q.recommended": "Recommended: %1",
      "q.why": "Why am I being asked this?",
      "q.moreInfo": "Read more →",
      "q.range": "Accepts %1 to %2.",
      "q.textHint": "Leave empty to keep unchanged.",
      "q.osTooOld": "This option requires macOS %1 or later (your system is %2), so it was skipped.",
      "q.osSkipped": "Skipped %2 options that require a newer system, based on your macOS version (%1).",
      "q.optionalStep": "Optional page",

      // Welcome
      "welcome.h1": "Welcome to the vChewing Configuration Assistant",
      "welcome.p1": "vChewing ships with well over a hundred preference items, which is not friendly to newcomers. This assistant asks you a handful of simple questions and turns your answers into a configuration profile that you then import into vChewing.",
      "welcome.p2": "Every question defaults to \"keep unchanged\": anything you do not answer will never be decided on your behalf.",
      "welcome.p3": "This assistant runs entirely inside your browser. It will never take the preferences you enter away from this computer on its own, and it never reads any setting on your computer.",
      "welcome.p4": "Once you have picked the input method you came from, the assistant offers a ready-made \"starter profile\". Apply it and you can produce your profile right away, without answering page after page.",
      "welcome.targetVersion": "Compatible with vChewing %1",
      "welcome.language": "Interface language:",

      // Step titles and leads
      "step.background.title": "How you used to type",
      "step.background.intro": "Neither answer writes any preference: together they decide the starter profile the assistant recommends and which questions come next.",
      "step.starter.title": "Starter profile",
      "step.starter.intro": "For the input method you came from, vChewing keeps a set of settings worth applying first. Apply it and you may produce your profile right away, or keep fine-tuning item by item.",
      "step.method.title": "How do you type?",
      "step.method.intro": "vChewing supports Zhuyin sentence composition, Zhuyin per-character selection (the classic \"Bopomofo half\" style), Hanyu Pinyin, and CIN tables (Array30, Cangjie, Boshiamy, …).",
      "step.rhythm.title": "Typing rhythm and tones",
      "step.rhythm.intro": "These options decide how vChewing treats tones, reading correction, and unfinished spellings.",
      "step.keys.title": "Key behaviours",
      "step.keys.intro": "These options decide what Shift, Space, Tab and Enter mean inside vChewing.",
      "step.candidate.title": "Candidate window",
      "step.candidate.intro": "The candidate window is the part of vChewing you see the most. Options here affect appearance and handling only, never the lexicon itself.",
      "step.mixed.title": "Mixing Chinese and alphanumerics",
      "step.mixed.intro": "vChewing can handle Chinese and alphanumerics within one typing session, without switching input sources back and forth.",
      "step.punctuation.title": "Punctuation, numerals and symbols",
      "step.punctuation.intro": "These options decide full-width versus half-width punctuation, and how numerals and symbols are produced.",
      "step.lexicon.title": "Lexicons and smart features",
      "step.lexicon.intro": "These options decide how vChewing consults its lexicons and learns from the candidates you pick.",
      "step.notify.title": "Notifications and system integration",
      "step.notify.intro": "These options decide which notices vChewing shows on screen and how it interacts with the rest of the system.",
      "step.advanced.title": "Advanced options",
      "step.advanced.intro": "Most of these relate to troubleshooting or to unusual client apps. If nothing is broken, feel free to skip this whole page.",
      "step.summary.title": "Summary and output",
      "step.summary.intro": "Review the list below, then produce your configuration profile.",

      // What this page is for, shown under the page title in the left pane (`left.<stepId>`)
      "left.welcome": "What this assistant does",
      "left.background": "Decides what we suggest next",
      "left.starter": "Apply now, or skip it",
      "left.method": "Settings about the typing method",
      "left.rhythm": "Tones and typing rhythm",
      "left.keys": "What the keys mean in vChewing",
      "left.candidate": "The candidate window",
      "left.mixed": "Mixing Chinese and alphanumerics",
      "left.punctuation": "Punctuation, numerals, symbols",
      "left.lexicon": "Lexicon lookups and learning",
      "left.notify": "Notices and system integration",
      "left.advanced": "Troubleshooting and odd clients",
      "left.summary": "Review, then produce the profile",

      // Custom question: previous input method
      "origin.title": "Which input method did you use before?",
      "origin.intro": "If your previous input method is not listed here, pick \"I am a brand-new user\".",
      "origin.opt.macoszhuyin": "macOS Built-in Zhuyin (since 10.6 Snow Leopard)",
      "origin.opt.msnewphonetic": "Microsoft New Phonetic (Windows)",
      "origin.opt.kimo": "Yahoo! KeyKey (Kimo)",
      "origin.opt.mcbpmf": "McBopomofo",
      "origin.opt.ov": "OpenVanilla",
      "origin.opt.hanin": "Hanin",
      "origin.opt.goingime": "Going IME",
      "origin.opt.asus": "ASUS",
      "origin.opt.cin": "CIN tables (Array30, Cangjie, Boshiamy, …)",
      "origin.opt.pinyin": "Furious-typing Hanyu Pinyin IMEs (Microsoft Pinyin / WeType / Sogou Pinyin / SunPinyin / ChineseStar / Ziguang Pinyin / Rime)",
      "origin.opt.newbie": "I am a brand-new user",

      // Custom question: typing method
      "typing.title": "How do you mainly type?",
      "typing.intro": "This only decides the starter profile the assistant recommends and which questions come next; it never writes any preference by itself.",
      "origin.note.macoszhuyin": "vChewing's defaults already follow the built-in Zhuyin input method of macOS 10.9 and later (including intonation keys overriding the reading, and the selection cursor placed before the phrase), so you most likely need not change anything — just press Next.",
      "origin.short.pinyin": "Furious-typing Hanyu Pinyin IMEs",
      "typing.opt.zhuyin": "Zhuyin sentence composition",
      "typing.opt.zhuyinmix": "Zhuyin sentence composition + mixed Chinese/English",
      "typing.opt.scpc": "Zhuyin per-character selection (ETen Chinese DOS \"Bo-Ban\")",
      "typing.opt.pinyin": "Hanyu Pinyin",
      "typing.opt.cin": "CIN tables (Array30, Cangjie, Boshiamy, …)",
      "typing.opt.unsure": "Not sure / something else",

      // Custom question: candidate font (that key has no readable label inside the app)

      // Starter profile
      "starter.title": "Apply this starter profile?",
      "starter.intro": "Either answer leaves everything else alone; anything you do not apply keeps your current settings.",
      "starter.opt.off": "Do not apply (keep unchanged)",
      "starter.opt.on": "Apply this starter profile",
      "starter.lead": "You used to type with \"%1\". Below is the starter profile vChewing suggests applying first.",
      "starter.leadUnknown": "Below is the starter profile vChewing suggests applying first.",
      "starter.empty": "vChewing's factory defaults already follow the habits you came from, so this profile names nothing (the items below can still be ticked off one by one).",
      "starter.namedNoteOff": "You unticked %1 item(s) this profile names: those are left alone and keep whatever vChewing has now.",
      "starter.namedTitle": "Items this profile names (%1)",
      "starter.resetTitle": "Items reset to vChewing's factory defaults (%1)",
      "starter.undoHint": "You may still switch any item back to \"keep unchanged\" afterwards; turning the starter profile off withdraws the whole set.",
      "starter.resetNoteOn": "This profile has no opinion on the items above, yet writes vChewing's factory defaults for them — on a shared computer, that is what keeps an earlier profile from lingering in your settings. Untick any you do not want.",
      "starter.resetNoteOff": "You unticked %1 item(s): an earlier profile — someone else's or your own — may still linger in those.",
      "starter.resetUncheckAll": "Untick all",
      "starter.resetCheckAll": "Tick all",
      "starter.noteExpress": "Most people are done here. Once you apply it, press Next to go straight to the summary and produce your profile — the item-by-item pages are only needed if you want finer control.",
      "starter.noteDetail": "Note: you can press \"Skip to summary\" at any time to produce your profile without answering the remaining pages.",
      "starter.express": "Apply the starter profile only: skip the remaining pages and go straight to the summary",
      "starter.expressNote": "Untick this box to keep answering the remaining pages (every item may stay unchanged).",

      // Summary
      "summary.h1": "Summary and output",
      "summary.lead": "Below is what the assistant will write into your configuration profile. Anything not listed stays exactly as it is now.",
      "summary.empty": "You have not answered anything yet. You may still produce an empty profile, or press \"< Back\" to answer some questions.",
      "summary.tableKey": "Preference",
      "summary.tableValue": "Value to write",
      "summary.count": "%1 item(s) in total.",
      "summary.metaTitle": "Profile name:",
      "summary.metaDescription": "What this profile is for (shown in the vChewing import confirmation):",
      "summary.defaultTitle": "Custom profile",
      "summary.starterTitle": "Starter profile for %1",
      "summary.defaultDescription": "Generated by the vChewing Configuration Assistant.",
      "summary.copy": "Copy profile data",
      "summary.download": "Download profile file",
      "summary.copied": "Copied to the clipboard.",
      "summary.copyManual": "Your browser does not support automatic copying. Click inside the text area below, press Command+A to select all, then Command+C to copy.",
      "summary.copyFailed": "Automatic copying failed. Click inside the text area below, press Command+A to select all, then Command+C to copy.",
      "summary.showJson": "Show the profile (JSON)",
      "summary.hideJson": "Hide the profile (JSON)",
      "summary.next": "What to do next",
      "summary.next1": "① Press \"Copy profile data\".",
      "summary.next2": "② Open \"vChewing Preferences → General\".",
      "summary.next3": "③ Press \"Import configuration data from clipboard (generated by the Configuration Assistant)\", review the list, then press Apply.",
      "summary.downloadHint": "You may also drag the downloaded file into the import area of \"vChewing Preferences → Developer Dojo\".",
      "summary.disclaimer": "These are optional starting points, not requirements. Everything here only writes preferences, and you may change it all back inside vChewing Preferences at any time.",
      "summary.starterScope": "This profile decides every item listed above; the ones it does not name go back to vChewing's factory defaults, so no earlier profile — yours or someone else's — lingers.",
      "summary.starterScopeOff": "This profile writes only the items you answered; anything it does not name is left alone — an earlier profile may still be in effect for those.",
      "summary.starterScopePartial": "You unticked the factory-default reset for %1 item(s) above; those are left alone, so an earlier profile may still be in effect for them.",
      "summary.starterNamedExcluded": "You unticked %1 named item(s) — those are left as they are in vChewing now.",
      "summary.defaultsNote": "Items kept unchanged are not written. A very few items (such as font sizes) are re-clamped by vChewing after import. Some changes only take effect the next time the input method is activated.",

      // Value formatting
      "value.on": "Enable",
      "value.off": "Disable",
      "value.none": "(none)",
    },

    ja: {
      // 共通
      "app.title": "唯音入力アプリ配置助手",
      "app.stepCounter": "%2 ステップ中 %1 番目",
      "nav.back": "＜ 戻る",
      "nav.next": "次へ ＞",
      "nav.finish": "完了",
      "nav.cancel": "キャンセル",
      "nav.toSummary": "まとめへ ＞",
      "nav.confirmTitle": "唯音入力アプリ配置助手を終了",
      "nav.confirmMessage": "本当に終了しますか？これまでに回答した内容はすべて破棄されます。",
      "nav.confirmYes": "終了する",
      "nav.confirmNo": "回答を続ける",
      "q.keepUnchanged": "変更しない",
      "q.keepUnchangedNote": "推奨。唯音内の現在の設定値をそのまま保ちます。工場出荷時の既定値：%1",
      "q.fillRecommended": "このページの未回答項目を推奨値（または出廠時の既定値）で補う",
      "q.fillRecommendedNote": "チェックすると、このページで推奨値があり、かつ未回答の項目も配置データに書き込まれます。",
      "q.recommended": "推奨値：%1",
      "q.why": "なぜこれを尋ねるのか？",
      "q.moreInfo": "詳しい説明 →",
      "q.range": "%1 ～ %2 を入力できます。",
      "q.textHint": "空欄のままにすると変更しません。",
      "q.osTooOld": "この項目には macOS %1 以上が必要です（お使いのシステムは %2）。そのため省略しました。",
      "q.osSkipped": "お使いの macOS のバージョン（%1）に基づき、より新しいシステムを要する %2 個の項目を省略しました。",
      "q.optionalStep": "ページごと省略可",

      // 歓迎ページ
      "welcome.h1": "唯音入力アプリ配置助手へようこそ",
      "welcome.p1": "唯音の環境設定には百を超える項目があり、初めての方には優しくありません。本助手はいくつかの簡単な質問をし、それに基づいて「配置データ」をまとめます。あとはそれを唯音に読み込むだけです。",
      "welcome.p2": "各設問の既定の答えは「変更しない」です。回答しなかった項目を、助手が勝手に決めることはありません。",
      "welcome.p3": "本助手はすべてお使いのブラウザー内で動作します。ご入力いただいた設定を勝手にこのパソコンの外へ持ち出すことはありませんし、お使いのコンピューターの設定も読み取りません。",
      "welcome.p4": "以前お使いだった入力方法を選ぶと、助手が「開始時の設定」をひとそろい用意します。それを適用すれば、ページごとに答えることなくそのまま配置データを生成できます。",
      "welcome.targetVersion": "唯音入力アプリ %1 に対応",
      "welcome.language": "表示言語：",

      // ステップの表題と導入
      "step.background.title": "お使いだった入力環境",
      "step.background.intro": "どちらの答えも設定は一切書き込みません。助手がご提案する開始時の設定と、以降の設問を決めるだけです。",
      "step.starter.title": "開始時の設定",
      "step.starter.intro": "以前お使いだった入力方法に合わせて、唯音には先に適用しておきたい設定のひとそろいがあります。適用すればそのまま配置データを生成できますし、項目ごとに微調整を続けることもできます。",
      "step.method.title": "入力方法",
      "step.method.intro": "唯音は注音による文節入力、注音の逐字選択（いわゆる「ㄅ半」）、漢語弁音、CIN テーブル（行列、倉頡、嘸蝦米など）に対応しています。",
      "step.rhythm.title": "入力のリズムと声調",
      "step.rhythm.intro": "これらの項目は、声調・読みの自動修正・未完成の綴りを唯音がどう扱うかを決めます。",
      "step.keys.title": "キーの動作",
      "step.keys.intro": "これらの項目は、Shift・空白・Tab・Enter などのキーが唯音内で何を意味するかを決めます。",
      "step.candidate.title": "候補ウィンドウ",
      "step.candidate.intro": "候補ウィンドウは唯音でもっとも目にする部分です。ここでの項目は外観と操作だけに影響し、辞書の中身には影響しません。",
      "step.mixed.title": "中国語と英数の混在入力",
      "step.mixed.intro": "唯音は、入力ソースを切り替えずに、ひと続きの入力の中で中国語と英数を扱えます。",
      "step.punctuation.title": "約物・数字・記号",
      "step.punctuation.intro": "これらの項目は、約物の全角／半角、および数字と記号の出力方法を決めます。",
      "step.lexicon.title": "辞書とスマート機能",
      "step.lexicon.intro": "これらの項目は、唯音が辞書を引く方法と、選択した候補から学習する方法を決めます。",
      "step.notify.title": "通知とシステム連携",
      "step.notify.intro": "これらの項目は、唯音が画面に表示する通知と、システムの他の部分との連携を決めます。",
      "step.advanced.title": "詳細項目",
      "step.advanced.intro": "これらの項目は、多くがトラブルシューティングや特殊な客体アプリに関係します。問題がなければページごと省略して構いません。",
      "step.summary.title": "まとめと生成",
      "step.summary.intro": "以下の内容を確認してから、配置データを生成してください。",

      // 左側の余白欄に表示する、このページの役割（`left.<stepId>`）
      "left.welcome": "本助手の目的と流れ",
      "left.background": "ご提案内容と以降の設問",
      "left.starter": "先に適用、または省略",
      "left.method": "入力方法まわりの設定",
      "left.rhythm": "声調と入力のリズム",
      "left.keys": "キーの意味づけ",
      "left.candidate": "候補ウィンドウの外観と操作",
      "left.mixed": "中国語と英数の混在入力",
      "left.punctuation": "約物・数字・記号",
      "left.lexicon": "辞書の参照と学習",
      "left.notify": "通知とシステム連携",
      "left.advanced": "トラブルシューティング",
      "left.summary": "内容の確認と配置データの生成",

      // 独自の設問：以前の入力方法
      "origin.title": "以前はどの入力方法をお使いでしたか？",
      "origin.intro": "ここに無い入力方法をお使いだった場合は「まったくの初心者です」を選んでください。",
      "origin.opt.macoszhuyin": "macOS 内蔵注音（10.6 Snow Leopard 以降）",
      "origin.opt.msnewphonetic": "Microsoft New Phonetic（Windows）",
      "origin.opt.kimo": "Yahoo! 奇摩輸入法",
      "origin.opt.mcbpmf": "小麥注音",
      "origin.opt.ov": "OpenVanilla",
      "origin.opt.hanin": "漢音輸入法",
      "origin.opt.goingime": "自然輸入法",
      "origin.opt.asus": "ASUS",
      "origin.opt.cin": "CIN テーブル（行列三十・倉頡・嘸蝦米など）",
      "origin.opt.pinyin": "狂拼流の漢語弁音入力（Microsoft Pinyin／WeType／Sogou Pinyin／SunPinyin／ChineseStar／紫光拼音／Rime）",
      "origin.opt.newbie": "まったくの初心者です",

      // 独自の設問：入力方法
      "typing.title": "主にどの方法で入力しますか？",
      "typing.intro": "これは助手がご提案する開始時の設定と、以降に尋ねる項目を決めるだけで、それ自体は何も書き込みません。",
      "origin.note.macoszhuyin": "唯音の既定値は macOS 10.9 以降の内蔵注音の習慣（声調キーによる読みの上書き、選択カーソルを語句の前方に置く等）に合わせてあります。多くの場合、設定を変える必要はありません——そのまま「次へ」を押してください。",
      "origin.short.pinyin": "狂拼流の漢語弁音入力",
      "typing.opt.zhuyin": "注音で文節入力（まとめて打ってから選ぶ）",
      "typing.opt.zhuyinmix": "注音で文節入力＋中国語と英数の混在入力",
      "typing.opt.scpc": "注音で漢字１つずつ全候補選択（ETen DOS 中国語漢字システムの「ㄅ半」派）",
      "typing.opt.pinyin": "漢語弁音",
      "typing.opt.cin": "CIN テーブル（行列・倉頡・嘸蝦米など）",
      "typing.opt.unsure": "未定／その他",

      // 独自の設問：候補ウィンドウのフォント

      // 開始時の設定
      "starter.title": "この開始時の設定を適用しますか？",
      "starter.intro": "適用の可否はほかの項目に影響しません。適用しない項目は現在の設定のままです。",
      "starter.opt.off": "適用しない（変更しない）",
      "starter.opt.on": "この開始時の設定を適用する",
      "starter.lead": "以前は「%1」をお使いでした。以下が唯音のご提案する開始時の設定です。",
      "starter.leadUnknown": "以下が唯音のご提案する開始時の設定です。",
      "starter.empty": "唯音の出荷時の既定値がすでに以前の習慣に沿っているため、この設定が指名する項目はありません（以下は項目ごとに既定値へ戻すかどうかを選べます）。",
      "starter.namedNoteOff": "この設定が指名する項目のうち %1 項目を外しました。それらはそのままとなり、唯音の現在の設定が維持されます。",
      "starter.namedTitle": "この設定が指名する項目（全 %1 項目）",
      "starter.resetTitle": "唯音の出荷時の既定値に戻す項目（全 %1 項目）",
      "starter.undoHint": "適用後も項目ごとに「変更しない」へ戻せます。適用を取り消せばひとそろい撤回されます。",
      "starter.resetNoteOn": "上記はいずれもこの設定が特に指定しない項目ですが、唯音の出荷時の既定値も併せて書き込みます——同じパソコンで他の方が別の配置を適用していても、この設定どおりの状態になるようにするためです。不要な項目はチェックを外してください。",
      "starter.resetNoteOff": "%1 項目の既定値への回帰を外しました。他の方（または以前のご自身）が適用した配置が、それらの項目に残っている可能性があります。",
      "starter.resetUncheckAll": "すべてチェックを外す",
      "starter.resetCheckAll": "すべてチェックする",
      "starter.noteExpress": "ほとんどの方はここまでで十分です。適用したうえで「次へ」を押せば、そのまままとめへ進んで配置データを生成できます——以降の項目別の設問は、より細かく調整したい場合だけお答えください。",
      "starter.noteDetail": "ご注意：以降の設問に答えずとも、「まとめへ」を押せばいつでも配置データを生成できます。",
      "starter.express": "開始時の設定だけを適用し、以降の項目別の設問を飛ばしてまとめへ進む",
      "starter.expressNote": "チェックを外すと、以降の項目別の設問が続きます（各項目は変更しないままでも構いません）。",

      // まとめページ
      "summary.h1": "まとめと生成",
      "summary.lead": "以下が配置データに書き込まれる内容です。ここに無い項目は、現在の設定のまま変更されません。",
      "summary.empty": "まだ何も回答していません。空の配置データを生成することも、「＜ 戻る」で回答を続けることもできます。",
      "summary.tableKey": "環境設定の項目",
      "summary.tableValue": "書き込む値",
      "summary.count": "全 %1 項目。",
      "summary.metaTitle": "配置の名前：",
      "summary.metaDescription": "この配置の目的（唯音の読み込み確認に表示されます）：",
      "summary.defaultTitle": "独自の配置",
      "summary.starterTitle": "%1の開始時の設定",
      "summary.defaultDescription": "唯音入力アプリ配置助手が生成しました。",
      "summary.copy": "配置データをコピー",
      "summary.download": "配置ファイルをダウンロード",
      "summary.copied": "クリップボードにコピーしました。",
      "summary.copyManual": "お使いのブラウザーは自動コピーに対応していません。下のテキスト領域内で Command+A を押して全選択し、Command+C でコピーしてください。",
      "summary.copyFailed": "自動コピーに失敗しました。下のテキスト領域内で Command+A を押して全選択し、Command+C でコピーしてください。",
      "summary.showJson": "配置データ（JSON）を表示",
      "summary.hideJson": "配置データ（JSON）を隠す",
      "summary.next": "次にすること",
      "summary.next1": "①「配置データをコピー」を押します。",
      "summary.next2": "②「唯音 環境設定 → 一般設定」を開きます。",
      "summary.next3": "③「（配置助手が生成した）配置データをクリップボードから読み込む」を押し、一覧を確認してから「適用」を押します。",
      "summary.downloadHint": "ダウンロードした配置ファイルは、「唯音 環境設定 → 開発道場」の読み込み領域にドラッグしても構いません。",
      "summary.disclaimer": "ここにあるのは任意の出発点であり、必須ではありません。変更は環境設定に書き込まれるだけで、いつでも唯音の環境設定内で元に戻せます。",
      "summary.starterScope": "上記の各項目はこの配置が決定します。指名されていない項目は唯音の出荷時の既定値に戻るため、他の方（または以前のご自身）が適用した配置は残りません。",
      "summary.starterScopeOff": "この配置は回答された項目のみを書き込みます。指名されていない項目はそのままです——他の方が以前に適用した配置が残っている可能性があります。",
      "summary.starterScopePartial": "上記のうち %1 項目について既定値への回帰を外しました。それらはそのままのため、他の方が以前に適用した配置が残っている可能性があります。",
      "summary.starterNamedExcluded": "指名項目のうち %1 項目を外しました——それらはそのままとなり、唯音の現在の設定が維持されます。",
      "summary.defaultsNote": "「変更しない」項目は書き込まれません。ごく一部の項目（文字サイズなど）は読み込み後に唯音側で補正されます。一部の変更は、次に輸入法を有効にしたときから有効になります。",

      // 値の整形
      "value.on": "有効",
      "value.off": "無効",
      "value.none": "（なし）",
    },
  };

  /// 現行之介面語言。
  export var currentLang: string = "zh-Hant";

  /// 把任意字串正規化為本助手支援之語系碼；不認識者回 `null`。
  export function normalizeLang(raw: string | null | undefined): string | null {
    if (!raw) return null;
    var lowered = String(raw).toLowerCase();
    if (lowered === "zh-hant" || lowered === "zh-tw" || lowered === "zh-hk" || lowered === "zh-mo") {
      return "zh-Hant";
    }
    if (lowered === "zh-hans" || lowered === "zh-cn" || lowered === "zh-sg") {
      return "zh-Hans";
    }
    if (lowered.indexOf("ja") === 0) return "ja";
    if (lowered.indexOf("en") === 0) return "en";
    return null;
  }

  /// 決定介面語言：URL `?lang=` ＞ `navigator.language`（含其逐項）＞ `zh-Hant`。
  export function detectLang(queryLang: string | null, navigatorLang: string | null): string {
    var fromQuery = normalizeLang(queryLang);
    if (fromQuery) return fromQuery;
    var fromNavigator = normalizeLang(navigatorLang);
    if (fromNavigator) return fromNavigator;
    return "zh-Hant";
  }

  /// 切換介面語言（不影響任何已作答之內容）。
  export function setLang(lang: string): void {
    currentLang = normalizeLang(lang) || "zh-Hant";
  }

  /// 取一句介面文案。查無該語系之鍵時回退至 `zh-Hant`，再查無則回傳鍵名本身
  /// （寧可顯示鍵名、也不顯示空白）。
  export function t(key: string): string {
    var table = UI_STRINGS[currentLang];
    if (table && typeof table[key] === "string") return table[key];
    var fallback = UI_STRINGS["zh-Hant"];
    if (fallback && typeof fallback[key] === "string") return fallback[key];
    return key;
  }

  /// 取一句介面文案並代換 `%1`、`%2`…… 之佔位符。
  export function tf(key: string, args: (string | number)[]): string {
    var template = t(key);
    var result = "";
    var index = 0;
    while (index < template.length) {
      var ch = template.charAt(index);
      if (ch === "%" && index + 1 < template.length) {
        var digit = template.charAt(index + 1);
        var position = "123456789".indexOf(digit);
        if (position >= 0 && position < args.length) {
          result += String(args[position]);
          index += 2;
          continue;
        }
      }
      result += ch;
      index += 1;
    }
    return result;
  }
}
