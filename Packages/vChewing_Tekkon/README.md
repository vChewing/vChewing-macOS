# Tekkon Engine 鐵恨引擎

該引擎已經實裝於基於純 Swift 語言完成的 **威注音輸入法** 內，歡迎好奇者嘗試：[GitHub](https://github.com/vChewing/vChewing-macOS ) | [Gitee](https://gitee.com/vchewing/vChewing-macOS ) 。

- Gitee: [Swift](https://gitee.com/vChewing/Tekkon) | [C#](https://gitee.com/vChewing/TekkonNT) | [C++](https://gitee.com/vChewing/TekkonCC)
- GitHub: [Swift](https://github.com/vChewing/Tekkon) | [C#](https://github.com/vChewing/TekkonNT) | [C++](https://github.com/vChewing/TekkonCC)

鐵恨引擎是用來處理注音輸入法並擊行為的一個模組。該倉庫乃威注音專案的弒神行動（Operation Longinus）的一部分。

Tekkon Engine is a module made for processing combo-composition of stroke-based Mandarin Chinese phonetics (i.e. Zhuyin / Bopomofo). This repository is part of Operation Longinus of The vChewing Project.

羅馬拼音輸入目前僅支援漢語拼音、國音二式、耶魯拼音、華羅拼音、通用拼音。

- 因為**韋氏拼音（威妥瑪拼音）輔音清濁不分的問題非常嚴重**、無法與注音符號形成逐一對應，故鐵恨引擎在技術上無法實現對韋氏拼音的支援。

Regarding pinyin input support, we only support: Hanyu Pinyin, Secondary Pinyin, Yale Pinyin, Hualuo Pinyin, and Universal Pinyin.

- **Tekkon is unable to provide Wade–Giles Pinyin support** since it is impossible to make one-to-one mappings to all possible phonabet combinations (especially it cannot distinguish "k" and "g").

> 注意：該引擎會將「ㄅㄨㄥ ㄆㄨㄥ ㄇㄨㄥ ㄈㄨㄥ」這四種讀音自動轉換成「ㄅㄥ ㄆㄥ ㄇㄥ ㄈㄥ」、將「ㄅㄨㄛ ㄆㄨㄛ ㄇㄨㄛ ㄈㄨㄛ」這四種讀音自動轉換成「ㄅㄛ ㄆㄛ ㄇㄛ ㄈㄛ」。如果您正在開發的輸入法的詞庫內的「甮」字的讀音沒有從「ㄈㄨㄥˋ」改成「ㄈㄥˋ」、或者說需要保留「ㄈㄨㄥˋ」的讀音的話，請按需修改「receiveKey(fromPhonabet:)」函式當中的相關步驟、來跳過該轉換。該情形為十分罕見之情形。類似情形則是台澎金馬審音的慣用讀音「ㄌㄩㄢˊ」，因為使用者眾、所以不會被該引擎自動轉換成「ㄌㄨㄢˊ」。威注音輸入法內部已經從辭典角度做了處理、允許在敲「ㄌㄨㄢˊ」的時候出現以「ㄌㄩㄢˊ」為讀音的漢字。我們鼓勵輸入法開發者們使用 [威注音語彙庫](https://gitee.com/vChewing/libvchewing-data) 來實現對兩岸讀音習慣的同時兼顧。

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
  func handle(
    input: InputHandler,
    state: InputState,
    stateCallback: @escaping (InputState) -> Void,
    errorCallback: @escaping (String) -> Void
  ) -> Bool {
    let charCode: UniChar = input.charCode
...
}
```

但對注拼槽的處理都是一樣的。

這裡分享一下威注音輸入法在 InputHandler 內對 _composer 的用法。

如果收到的按鍵訊號是 BackSpace 的話，可以用 _composer.doBackSpace() 來移除注拼槽內最前方的元素。

鐵恨引擎的注拼槽 Composer 型別內的函式都有對應的詳細註解說明。這裡不再贅述。



> (這裡的範例取自威注音，只用作演示用途。威注音實際的 codebase 可能會有出入。請留意這一段內的漢語註解。)
> 
> (不是所有輸入法都有狀態管理引擎，請根據各自專案的實際情況來結合理解這段程式碼。)

```swift
// MARK: Handle BPMF Keys.

var keyConsumedByReading = false
let skipPhoneticHandling = input.isReservedKey || input.isControlHold || input.isOptionHold

// See if Phonetic reading is valid.
// 這裡 inputValidityCheck() 是讓 _composer 檢查 charCode 這個 UniChar 是否是合法的注音輸入。
// 如果是的話，就將這次傳入的這個按鍵訊號塞入 _composer 內且標記為「keyConsumedByReading」。
// 函式 _composer.receiveKey() 可以既接收 String 又接收 UniChar。
if !skipPhoneticHandling && _composer.inputValidityCheck(key: charCode) {
  _composer.receiveKey(fromCharCode: charCode)
  keyConsumedByReading = true

  // If we have a tone marker, we have to insert the reading to the
  // compositor in other words, if we don't have a tone marker, we just
  // update the composing buffer.
  // 沒有調號的話，只需要 updateClientComposingBuffer() 且終止處理（return true）即可。
  // 有調號的話，則不需要這樣處理，轉而繼續在此之後的處理。
  let composeReading = _composer.hasToneMarker()
  if !composeReading {
    stateCallback(generateStateOfInputting())
    return true
  }
}

// 這裡不需要做排他性判斷。
var composeReading = _composer.hasToneMarker()

// See if we have composition if Enter/Space is hit and buffer is not empty.
// We use "|=" conditioning so that the tone marker key is also taken into account.
// However, Swift does not support "|=".
// 如果當前的按鍵是 Enter 或 Space 的話，這時就可以取出 _composer 內的注音來做檢查了。
// 來看看詞庫內到底有沒有對應的讀音索引。這裡用了類似「|=」的判斷處理方式。
composeReading = composeReading || (!_composer.isEmpty && (input.isSpace || input.isEnter))
if composeReading {  // 符合按鍵組合條件
  if input.isSpace && !_composer.hasToneMarker() {
    _composer.receiveKey(fromString: " ")  // 補上空格，否則倚天忘形與許氏排列某些音無法響應不了陰平聲調。
    // 某些輸入法使用 OVMandarin 而不是鐵恨引擎，所以不需要這樣補。但鐵恨引擎對所有聲調一視同仁。
  }
  let reading = _composer.getComposition()  // 拿取用來進行索引檢索用的注音
  // 如果輸入法的辭典索引是漢語拼音的話，要注意上一行拿到的內容得是漢語拼音。

  // See whether we have a unigram for this...
  // 向語言模型詢問是否有對應的記錄
  if !ifLangModelHasUnigrams(forKey: reading) {  // 如果沒有的話
    vCLog("B49C0979：語彙庫內無「\(reading)」的匹配記錄。")
    errorCallback("114514")  // 向狀態管理引擎回呼一個錯誤狀態
    _composer.clear()  // 清空注拼槽的內容
    // 根據「天權星引擎 (威注音) 或 Gramambular (小麥) 的組字器是否為空」來判定回呼哪一種狀態
    stateCallback(
      (getCompositorLength() == 0) ? InputState.EmptyIgnoringPreviousState() : generateStateOfInputting())
    return true  // 向 IMK 報告說這個按鍵訊號已經被輸入法攔截處理了
  }

  // ... and insert it into the grid...
  // 將該讀音插入至天權星（或 Gramambular）組字器內的軌格當中
  insertReadingToCompositorAtCursor(reading: reading)

  // ... then walk the grid...
  // 讓組字器反爬軌格
  let poppedText = popOverflowComposingTextAndWalk()

  // ... get and tweak override model suggestion if possible...
  // 看看半衰記憶模組是否會對目前的狀態給出自動選字建議
  dealWithOverrideModelSuggestions()

  // ... then update the text.
  // 之後就是更新組字區了。先清空注拼槽的內容。
  _composer.clear()
  // 再以回呼組字狀態的方式來執行updateClientComposingBuffer()
  let inputting = generateStateOfInputting()
  inputting.poppedText = poppedText
  stateCallback(inputting)

  return true  // 向 IMK 報告說這個按鍵訊號已經被輸入法攔截處理了
}
```

## 著作權 (Credits)

- (c) 2022 and onwards The vChewing Project (MIT-NTL License).
	- Swift programmer: Shiki Suen

$ EOF.
