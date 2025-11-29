# Tekkon Engine 鐵恨引擎

該引擎已經實裝於基於純 Swift 語言完成的 **唯音輸入法** 內，歡迎好奇者嘗試：[GitHub](https://github.com/vChewing/vChewing-macOS ) | [Gitee](https://gitee.com/vchewing/vChewing-macOS ) 。

- Gitee: [Swift](https://gitee.com/vChewing/Tekkon) | [C#](https://gitee.com/vChewing/TekkonNT) | [C++](https://gitee.com/vChewing/TekkonCC)
- GitHub: [Swift](https://github.com/vChewing/Tekkon) | [C#](https://github.com/vChewing/TekkonNT) | [C++](https://github.com/vChewing/TekkonCC)

鐵恨引擎是用來處理注音輸入法並擊行為的一個模組。該倉庫乃唯音專案的弒神行動（Operation Longinus）的一部分。

Tekkon Engine is a module made for processing combo-composition of stroke-based Mandarin Chinese phonetics (i.e. Zhuyin / Bopomofo). This repository is part of Operation Longinus of The vChewing Project.

羅馬拼音輸入目前僅支援漢語拼音、國音二式、耶魯拼音、華羅拼音、通用拼音、韋氏拼音（威妥瑪拼音）。

- 因為**趙元任國語羅馬字拼音「無法製作通用的聲調確認鍵」**，故鐵恨引擎在技術上無法實現對趙元任國語羅馬字拼音的支援。

Regarding pinyin input support, we only support: Hanyu Pinyin, Secondary Pinyin, Yale Pinyin, Hualuo Pinyin, Wade-Giles Pinyin and Universal Pinyin.

- **Tekkon is unable to provide support for Zhao Yuan-Ren's Gwoyeu Romatzyh at this moment** because there is no consistent method to check whether the intonation key has been pressed. Tekkon is designed to confirm input with intonation keys.

> 注意：該引擎會將「ㄅㄨㄥ ㄆㄨㄥ ㄇㄨㄥ ㄈㄨㄥ」這四種讀音自動轉換成「ㄅㄥ ㄆㄥ ㄇㄥ ㄈㄥ」、將「ㄅㄨㄛ ㄆㄨㄛ ㄇㄨㄛ ㄈㄨㄛ」這四種讀音自動轉換成「ㄅㄛ ㄆㄛ ㄇㄛ ㄈㄛ」。如果您正在開發的輸入法的詞庫內的「甮」字的讀音沒有從「ㄈㄨㄥˋ」改成「ㄈㄥˋ」、或者說需要保留「ㄈㄨㄥˋ」的讀音的話，請按需修改「receiveKey(fromPhonabet:)」函式當中的相關步驟、來跳過該轉換。該情形為十分罕見之情形。類似情形則是台澎金馬審音的慣用讀音「ㄌㄩㄢˊ」，因為使用者眾、所以不會被該引擎自動轉換成「ㄌㄨㄢˊ」。唯音輸入法內部已經從辭典角度做了處理、允許在敲「ㄌㄨㄢˊ」的時候出現以「ㄌㄩㄢˊ」為讀音的漢字。我們鼓勵輸入法開發者們使用 [唯音語彙庫](https://gitee.com/vChewing/libvchewing-data) 來實現對兩岸讀音習慣的同時兼顧。

## 使用說明

### §1. 初期化

在你的 IMKInputController (InputMethodController) 或者 InputHandler 內初期化一份 Tekkon.Composer 注拼槽副本（這裡將該副本命名為「`_composer`」）。由於 Tekkon.Composer 的型別是 Struct 型別，所以其副本必須為變數（var），否則無法自我 mutate。

以 InputHandler 為例：
```swift
class InputHandler: NSObject {
  // 先設定好變數
  var _composer: Tekkon.Composer = .init()
  ...
}
```

以 IMKInputController 為例：
```swift
@objc(IMKMyInputController)  // 根據 info.plist 內的情況來確定型別的命名
class IMKMyInputController: IMKInputController {
  // 先設定好變數
  var _composer: Tekkon.Composer = .init()
  ...
}
```


由於 Swift 會在某個大副本（InputHandler 或者 IMKInputController 副本）被銷毀的時候自動銷毀其中的全部副本，所以 Tekkon.Composer 的副本初期化沒必要寫在 init() 當中。但你很可能會想在 init() 時指定 Tekkon.Composer 所使用的注音排列（是大千？還是倚天傳統？還是神通？等）。

這裡就需要在 _composer 這個副本所在的型別當中額外寫一個過程函式。

下文範例 `ensureParser()` 是這樣：假設 PrefMgr 用來管理 UserDefaults 資料，那麼就從裡面取資料來判定 _composer 的注音排列分析器究竟該選哪個。

```swift
  // MARK: - Extracted methods and functions (Tekkon).

  func ensureParser() {
    switch PrefMgr.shared.mandarinParser {
      case MandarinParser.ofStandard.rawValue:
        _composer.ensureParser(arrange: .ofDachen)  // 大千
      case MandarinParser.ofETen.rawValue:
        _composer.ensureParser(arrange: .ofETen)  // 倚天傳統
      case MandarinParser.ofHsu.rawValue:
        _composer.ensureParser(arrange: .ofHsu)  // 許氏國音
      case MandarinParser.ofETen26.rawValue:
        _composer.ensureParser(arrange: .ofETen26)  // 倚天忘形26鍵
      case MandarinParser.ofIBM.rawValue:
        _composer.ensureParser(arrange: .ofIBM)  // IBM
      case MandarinParser.ofMiTAC.rawValue:
        _composer.ensureParser(arrange: .ofMiTAC)  // 神通
      case MandarinParser.ofFakeSeigyou.rawValue:
        _composer.ensureParser(arrange: .ofFakeSeigyou)  // 偽精業
      case MandarinParser.ofHanyuPinyin.rawValue:
        _composer.ensureParser(arrange: .ofHanyuPinyin)  // 漢語拼音
      case MandarinParser.ofSecondaryPinyin.rawValue:
        _composer.ensureParser(arrange: .ofSecondaryPinyin)  // 國音二式
      case MandarinParser.ofYalePinyin.rawValue:
        _composer.ensureParser(arrange: .ofYalePinyin)  // 耶魯拼音
      case MandarinParser.ofHualuoPinyin.rawValue:
        _composer.ensureParser(arrange: .ofHualuoPinyin)  // 華羅拼音
      case MandarinParser.ofUniversalPinyin.rawValue:
        _composer.ensureParser(arrange: .ofUniversalPinyin)  // 通用拼音
      default:
        _composer.ensureParser(arrange: .ofDachen)  // 預設情況下按照 PrefMgr 內定義預設值來處理
        PrefMgr.shared.mandarinParser = MandarinParser.ofStandard.rawValue
    }
    _composer.clear()
  }
```

然後你可以在想用這個函式的時候用。比如說在 _composer 這個副本所在的型別的 `init()` 內的 super.init() 後面寫上步驟即可：

```swift
  override init() {
    ...
    super.init()
    ensureParser()
    ...
  }
```

或者你可以在最開始初始化 _composer 副本的時候加上參數，也就是寫成這樣（比如說大千佈局）：

```swift
  var _composer: Tekkon.Composer = .init(arrange: .ofDachen)
```

總之用法有很多。這裡不再一一列舉。

### §2. 函式介紹與按鍵訊號處理

#### // 1. 獲取注拼槽內現有的注音拼寫內容

這裡分用途說明一下，請結合 TekkonTests.swift 理解。

首先，InputMethodKit 的 updateClientComposingBuffer() 當中可以使用 _composer 的 getInlineCompositionForDisplay() 函式。如果你想讓組字緩衝區內顯示拼音而不是注音的話，可以這樣改參數：

```swift
let XXX = getInlineCompositionForDisplay(isHanyuPinyin: true)
```

那要是用來生成用來檢索的注音呢？畢竟這時不需要漢語拼音的實時輸入狀態顯示、而是要求一直都輸出準確的拼音結果。那就：

```swift
let AAA = getComposition(isHanyuPinyin: false)  // 輸出注音
let BBB = getComposition(isHanyuPinyin: false, isTextBookStyle: true)  // 輸出教科書排版的注音（先寫輕聲）
let CCC = getComposition(isHanyuPinyin: true)  // 輸出漢語拼音二式（漢語拼音+數字標調）
let DDD = getComposition(isHanyuPinyin: true, isTextBookStyle: true)  // 輸出漢語拼音一式（教科書排版的漢語拼音）
```

那原始資料值呢？用 _composer.value 可以拿到原始資料值，但請注意：這個資料值裡面的注音的陰平聲調是以一個西文半形空格來體現的。

各位可以自行修改一下 TekkonTests.swift 試試看，比如說在其檔案內新增一個 Extension 與測試函式：

```swift
import XCTest

@testable import Tekkon

extension Tekkon.Composer {
  public var realCompositionInHanyuPinyin: String {
    Tekkon.cnvPhonaToHanyuPinyin(target: value)
  }
}

final class TekkonTests: XCTestCase {
  func 測試某位樂壇歌王常用的口頭禪() throws {
    var composer = Tekkon.Composer(arrange: .ofDachen)

    // Test Key Receiving
    composer.receiveKey(fromCharCode: 0x0032)  // 2, ㄉ
    composer.receiveKey(fromString: "u")  // ㄧ
    composer.receiveKey(fromString: "l")  // ㄠ
    composer.receiveKey(fromString: "3")  // 上聲
    XCTAssertEqual(composer.realCompositionInHanyuPinyin, "diao3")
  }
...
```

#### // 2. 訊號處理

無論是 InputHandler 還是 IMKInputController 都得要處理被傳入的 NSEvent 當中的 charCode 訊號。

比如 IMKInputController 內：
```swift
func handleInputText(_ inputText: String?, key keyCode: Int, modifiers flags: Int, client: Any?) -> Bool {
...
}
```

或者 InputHandler 內：
```swift
extension InputHandler {
  func handle(input: InputSignalProtocol) -> Bool {
    let charCode: UniChar = input.charCode
...
}
```

但對注拼槽的處理都是一樣的。

有關於唯音輸入法在 InputHandler 內對 _composer 的用法，請洽其倉庫內的 InputHandler_HandleComposition.swift 檔案。

如果收到的按鍵訊號是 BackSpace 的話，可以用 _composer.doBackSpace() 來移除注拼槽內最前方的元素。

鐵恨引擎的注拼槽 Composer 型別內的函式都有對應的詳細註解說明。這裡不再贅述。

## 著作權 (Credits)

- Development by (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
	- Original Swift developer: Shiki Suen
	- C# and Cpp version developer: Shiki Suen

```
// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.
```

敝專案採雙授權發佈措施。除了 LGPLv3 以外，對商業使用者也提供不同的授權條款（比如允許閉源使用等）。詳情請[電郵聯絡作者](shikisuen@yeah.net)。

$ EOF.
