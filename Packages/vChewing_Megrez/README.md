# Megrez Engine 天權星引擎

- Gitee: [Swift](https://gitee.com/vChewing/Megrez) | [C#](https://gitee.com/vChewing/MegrezNT)
- GitHub: [Swift](https://github.com/vChewing/Megrez) | [C#](https://github.com/vChewing/MegrezNT)

> 該引擎已經實裝於基於純 Swift 語言完成的 **威注音輸入法** 內，歡迎好奇者嘗試：[GitHub](https://github.com/vChewing/vChewing-macOS ) | [Gitee](https://gitee.com/vchewing/vChewing-macOS ) 。

天權星引擎是用來處理輸入法語彙庫的一個模組。該倉庫乃威注音專案的弒神行動（Operation Longinus）的一部分。

Megrez Engine is a module made for processing lingual data of an input method. This repository is part of Operation Longinus of The vChewing Project.

## 使用說明

### §1. 初期化

在你的 IMKInputController 或者 InputHandler 內初期化一份 Megrez.Compositor 組字器副本（這裡將該副本命名為「`compositor`」）。由於 Megrez.Compositor 的型別是 Struct 型別（為了讓 Compositor 可以 deep copy），所以其副本可以用 var 來宣告。

以 InputHandler 為例：
```swift
class InputHandler {
  // 先設定好變數
  var compositor: Megrez.Compositor = .init()
  ...
}
```

以 IMKInputController 為例：
```swift
@objc(IMKMyInputController)  // 根據 info.plist 內的情況來確定型別的命名
class IMKMyInputController: IMKInputController {
  // 先設定好變數
  var compositor: Megrez.Compositor = .init()
  ...
}
```

由於 Swift 會在某個大副本（InputHandler 或者 IMKInputController 副本）被銷毀的時候自動銷毀其中的全部副本，所以 Megrez.Compositor 的副本初期化沒必要寫在 init() 當中。但你很可能會想在 init() 時指定 Tekkon.Composer 所對接的語言模組型別、以及其可以允許的最大詞長。

這裡就需要在 init() 時使用參數：
```swift
  /// 組字器。
  /// - Parameters:
  ///   - lm: 語言模型。可以是任何基於 Megrez.LangModel 的衍生型別。
  ///   - length: 指定該組字器內可以允許的最大詞長，預設為 10 字。
  ///   - separator: 多字讀音鍵當中用以分割漢字讀音的記號，預設為空。
  var compositor: Megrez.Compositor = .init(lm: lmTest, length: 13, separator: "-")
```

### §2. 使用範例

請結合 MegrezTests.swift 檔案來學習。這裡只是給個概述。

#### // 1. 準備用作語言模型的專用型別

首先，Megrez 內建的 LangModel 型別是遠遠不夠用的，只能說是個類似於 protocol 一樣的存在。你需要自己單獨寫一個新的衍生型別：

```swift
class ExampleLM: Megrez.LangModel {
...
  override func unigramsFor(keyArray: [String]) -> [Megrez.Unigram] {
    ...
  }
...
}
```

這個型別需要下述兩個函式能夠針對給定的鍵回饋對應的資料值、或其存無狀態：
- unigramsFor(keyArray: [String]) -> [Megrez.Unigram]
- hasUnigramsFor(keyArray: [String]) -> Bool

MegrezTests.swift 檔案內的 SimpleLM 可以作為範例。

至於該檔案內的 FiniteStateMachine 則是一個「一次性讀取檔案/大字串且分析資料」的範例。

如果需要更實戰的範例的話，可以洽威注音專案的倉庫內的 LMInstantiator.swift 及其關聯檔案。

#### // 2. 怎樣與 compositor 互動：

這裡只講幾個常用函式：

- 游標位置 `compositor.cursorIndex` 是可以賦值與取值的動態變數，且會在賦值內容為超出位置範圍的數值時自動修正。初期值為 0。
- `compositor.insertKey("gao1")` 可以在當前的游標位置插入讀音「gao1」。
- `compositor.dropKey(direction: .front)` 的作用是：朝著往文字輸入方向、砍掉一個與游標相鄰的讀音。反之，`dropKey(direction: .rear)` 則朝著與文字輸入方向相反的方向、砍掉一個與游標相鄰的讀音。
  - 在威注音的術語體系當中，「文字輸入方向」為向前（Front）、與此相反的方向為向後（Rear）。
- `compositor.overrideCandidate(.init(keyArray: ["讀音"], value: "候選字"), at: 游標位置, overrideType: 覆寫模式)` 用來根據輸入法選中的候選字詞、據此更新當前游標位置選中的候選字詞節點當中的候選字詞。

輸入完內容之後，可以聲明一個用來接收結果的變數：

```swift
  /// 對已給定的軌格按照給定的位置與條件進行正向爬軌。
  var walked = compositor.walk()
```

MegrezTests.swift 是輸入了很多內容之後再 walk 的。實際上一款輸入法會在你每次插入讀音或刪除讀音的時候都重新 walk。那些處於候選字詞鎖定狀態的節點不會再受到之後的 walk 的行為的影響，但除此之外的節點會因為每次 walk 而可能各自的候選字詞會出現自動變化。如果給了 nodesLimit 一個非零的數值的話，則 walk 的範圍外的節點不會受到影響。

walk 之後的取值的方法及利用方法可以有很多種。這裡有其中的一個：

```swift
    var composed: [String] = walked.map(\.value)
    print(composed)
```

類似於：

```swift
    for phrase in walked {
        composed.append(phrase.value)
    }
    print(composed)
```

上述 print 結果就是 compositor 目前的組句，是這種陣列格式（以吳宗憲的詩句為例）：
```swift
    ["八月", "中秋", "山林", "涼", "風吹", "大地", "草枝", "擺"]
```

自己看 MegrezTests.swift 慢慢研究吧。

## 著作權 (Credits)

- Swiftified and further development by (c) 2022 and onwards The vChewing Project (MIT License).
  - Swift programmer: Shiki Suen
- Was initially rebranded from (c) Lukhnos Liu's C++ library "Gramambular 2" (MIT License).
