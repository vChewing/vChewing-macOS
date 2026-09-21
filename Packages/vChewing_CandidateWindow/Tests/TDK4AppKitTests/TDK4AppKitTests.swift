// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import AppKit
import Shared_DarwinImpl
import Testing

@testable import TDK4AppKit

// MARK: - TDK4AppKitTests

@Suite(.serialized)
struct TDK4AppKitTests {
  let variableCandidatesINMU: [CandidateInState] = [
    "二十四歲是學生", "二十四歲", "昏睡紅茶", "食雪漢", "意味深", "學生", "便乗",
    "迫真", "驚愕", "論證", "正論", "惱", "悲", "屑", "食", "雪", "漢", "意", "味",
    "深", "二", "十", "四", "歲", "是", "學", "生", "昏", "睡", "紅", "茶", "便", "乗",
    "嗯", "哼", "啊",
  ].map { candidate in
    let keys: [String] = .init(repeating: "", count: candidate.count)
    return (keys, candidate)
  }

  let wideCandidates: [CandidateInState] = [
    "八月中秋山林涼", "風吹大地草枝擺", "甘霖老母趕羚羊", "來年羊毛超級賣",
    "庭院織芭為君開", "督蘭山曉金桔擺", "天摇地動舟渡嵐", "嗚呼甘霖老師埋",
  ].map { candidate in
    let keys: [String] = .init(repeating: "", count: candidate.count)
    return (keys, candidate)
  }

  @Test
  func testPoolHorizontal() throws {
    let pool = TDK4AppKit.CandidatePool4AppKit(
      candidates: variableCandidatesINMU, selectionKeys: "123456", layout: .horizontal
    )
    var strOutput = ""
    pool.candidateLines.forEach {
      $0.forEach {
        strOutput += $0.displayedText + ", "
      }
      strOutput += "\n"
    }
    print("The matrix:")
    print(strOutput)
  }

  @Test
  func testPoolVertical() throws {
    let pool = TDK4AppKit.CandidatePool4AppKit(
      candidates: variableCandidatesINMU, selectionKeys: "123456", layout: .vertical
    )
    var strOutput = ""
    pool.candidateLines.forEach {
      $0.forEach {
        strOutput += $0.displayedText + ", "
      }
      strOutput += "\n"
    }
    print("The matrix:")
    print(strOutput)
  }

  // MARK: - 動態行容量測試

  /// 驗證：當 `_maxLinesPerPage == 1` (lines: 1) 時，
  /// 橫向排列的 pool 仍需根據候選字詞的實際寬度動態調整每行容量。
  /// 若含有長詞的行仍塞滿 maxLineCapacity 個候選字，則代表故障存在。
  @Test
  func testHorizontalDynamicRowCapacity_SingleLineShouldStillAdjust() throws {
    // lines: 4（多行模式）作為對照組。
    let poolMultiLine = TDK4AppKit.CandidatePool4AppKit(
      candidates: variableCandidatesINMU,
      lines: 4,
      isExpanded: true,
      selectionKeys: "123456",
      layout: .horizontal
    )
    // lines: 1（單行模式）作為實驗組。
    let poolSingleLine = TDK4AppKit.CandidatePool4AppKit(
      candidates: variableCandidatesINMU,
      lines: 1,
      isExpanded: true,
      selectionKeys: "123456",
      layout: .horizontal
    )

    print("=== Multi-line (lines: 4) candidateLines ===")
    for (i, line) in poolMultiLine.candidateLines.enumerated() {
      let texts = line.map(\.displayedText).joined(separator: ", ")
      print("  Line \(i): [\(line.count) items] \(texts)")
    }

    print("=== Single-line (lines: 1) candidateLines ===")
    for (i, line) in poolSingleLine.candidateLines.enumerated() {
      let texts = line.map(\.displayedText).joined(separator: ", ")
      print("  Line \(i): [\(line.count) items] \(texts)")
    }

    // 對照組第一行包含 "二十四歲是學生"（7 chars）等寬候選字，
    // 動態調整後該行的項數應少於 maxLineCapacity（6）。
    let multiLineFirstRowCount = poolMultiLine.candidateLines[0].count
    #expect(multiLineFirstRowCount < 6, "對照組第一行應因寬候選字而少於 6 個項目")

    // 實驗組的行分佈應與對照組完全一致——
    // 因為行容量計算只取決於 maxRowWidth 與各候選字寬度，與 _maxLinesPerPage 無關。
    #expect(
      poolSingleLine.candidateLines.count == poolMultiLine.candidateLines.count,
      "單行模式與多行模式的總行數應一致"
    )
    for i in 0 ..< min(poolSingleLine.candidateLines.count, poolMultiLine.candidateLines.count) {
      let singleLineRow = poolSingleLine.candidateLines[i].map(\.displayedText)
      let multiLineRow = poolMultiLine.candidateLines[i].map(\.displayedText)
      #expect(
        singleLineRow == multiLineRow,
        "第 \(i) 行的候選字分佈應一致：single=\(singleLineRow) vs multi=\(multiLineRow)"
      )
    }
  }

  /// 驗證：含有不同寬度候選字的行應該被動態分配，
  /// 而非一律填滿 maxLineCapacity 個詞。
  @Test
  func testHorizontalDynamicRowCapacity_WideItemsReduceRowCount() throws {
    // 全部使用長字詞。
    let wideCandidates: [CandidateInState] = [
      "八月中秋山林涼", "風吹大地草枝擺", "甘霖老母趕羚羊", "來年羊毛超級賣",
      "庭院織芭為君開", "督蘭山曉金桔擺", "天摇地動舟渡嵐", "嗚呼甘霖老師埋",
    ].map { candidate in
      let keys: [String] = .init(repeating: "", count: candidate.count)
      return (keys, candidate)
    }

    let pool = TDK4AppKit.CandidatePool4AppKit(
      candidates: wideCandidates,
      lines: 1,
      isExpanded: true,
      selectionKeys: "123456",
      layout: .horizontal
    )

    print("=== Wide candidates (lines: 1) ===")
    for (i, line) in pool.candidateLines.enumerated() {
      let texts = line.map(\.displayedText).joined(separator: ", ")
      print("  Line \(i): [\(line.count) items] \(texts)")
    }

    // 寬字詞不可能全部塞進一行，應產生多於 2 行。
    #expect(
      pool.candidateLines.count > 2,
      "含 9 個七字詞時，行數應大於 2，但目前為 \(pool.candidateLines.count)"
    )

    // 每行的項數應隨寬度而減少（不應都等於 6）。
    let maxItemsPerLine = pool.candidateLines.map(\.count).max() ?? 0
    #expect(
      maxItemsPerLine < 6,
      "七字詞組成的行不該有 6 個項目，但最大行項數為 \(maxItemsPerLine)"
    )
  }

  // MARK: - isExpanded 狀態保留測試

  /// 驗證：reinit 時傳入的 isExpanded 值不該被 cleanDataOnMain 覆寫。
  /// 此場景模擬「選字窗已展開，使用者移動游標後觸發 reloadData → reinit」的情形。
  @Test
  func testIsExpandedPreservedAfterReinit() throws {
    // 先建一個展開的 pool。
    let pool = TDK4AppKit.CandidatePool4AppKit(
      candidates: variableCandidatesINMU,
      lines: 4,
      isExpanded: true,
      selectionKeys: "123456",
      layout: .horizontal
    )
    #expect(pool.isExpanded == true, "初期化後應處於展開狀態")
    #expect(pool.maxLinesPerPage == 4, "展開時 maxLinesPerPage 應為 4")

    // 模擬 reloadData：用 reinit 重建，保持 isExpanded: true。
    pool.reinit(
      candidates: variableCandidatesINMU,
      lines: 4,
      isExpanded: true,
      selectionKeys: "123456",
      layout: .horizontal
    )
    #expect(pool.isExpanded == true, "reinit 後 isExpanded 應被正確保留為 true")
    #expect(pool.maxLinesPerPage == 4, "reinit 後 maxLinesPerPage 應仍為 4")

    // 再模擬 reloadData：isExpanded: false（使用者未手動展開）。
    pool.reinit(
      candidates: variableCandidatesINMU,
      lines: 4,
      isExpanded: false,
      selectionKeys: "123456",
      layout: .horizontal
    )
    #expect(pool.isExpanded == false, "reinit 傳入 false 後 isExpanded 應為 false")
    #expect(pool.maxLinesPerPage == 1, "未展開時 maxLinesPerPage 應為 1")
  }

  /// 驗證：init 構造時 isExpanded 也應被正確保留。
  @Test
  func testIsExpandedCorrectAfterInit() throws {
    let poolExpanded = TDK4AppKit.CandidatePool4AppKit(
      candidates: variableCandidatesINMU,
      lines: 4,
      isExpanded: true,
      selectionKeys: "123456",
      layout: .horizontal
    )
    #expect(poolExpanded.isExpanded == true)
    #expect(poolExpanded.maxLinesPerPage == 4)

    let poolCollapsed = TDK4AppKit.CandidatePool4AppKit(
      candidates: variableCandidatesINMU,
      lines: 4,
      isExpanded: false,
      selectionKeys: "123456",
      layout: .horizontal
    )
    #expect(poolCollapsed.isExpanded == false)
    #expect(poolCollapsed.maxLinesPerPage == 1)
  }

  // MARK: - GSI 捲動模型測試

  /// 迴歸鎖定：橫向排版的行步進（`lineStep`，即捲動模式視口的高度單位）必須跟隨偏好中的
  /// 候選字字級，而非任何建池時或行程初期的字級快照。範本 cell（`shitCell`）的 `textDimension`
  /// 只在該靜態成員初次初始化時定影一次，故行步進若自該處取值，行程存活期間更動字級便不會
  /// 反映在視口最大高度上——這正是「橫向排版縱向展頁時的最大高度不隨字級遞增」之病灶
  /// （縱向排版量的是實際排版寬度，故不受此影響）。
  @Test
  func testGSILineStepFollowsCandidateFontSize() throws {
    let baselineSize = PrefMgr.shared.candidateListTextSize
    defer { PrefMgr.shared.candidateListTextSize = baselineSize }

    // 先在環境字級下定影範本 cell，再放大字級建池——模擬「使用者於 IME 行程存活期間調大候選字字級」。
    _ = TDK4AppKit.CandidatePool4AppKit.shitCell.textDimension
    PrefMgr.shared.candidateListTextSize = baselineSize + 24

    let pool = TDK4AppKit.CandidatePool4AppKit(
      candidates: variableCandidatesINMU, lines: 4, isExpanded: true,
      selectionKeys: "123456", layout: .horizontal
    )
    pool.computeCandidateOnlySize()

    let expectedLineHeight =
      CGFloat(TDK4AppKit.CandidateCellData4AppKit.unifiedTextHeight) + 2 * pool.padding
    #expect(pool.lineStep == expectedLineHeight, "行步進應等於當前字級下的實際行高")
    #expect(
      pool.pageCandidateSize.height == expectedLineHeight * CGFloat(pool.maxLinesPerPage),
      "捲動視口高度應隨字級遞增（每頁 \(pool.maxLinesPerPage) 行）"
    )
    // 行步進必須與實際排版出的行距一致（第二行原點 y 減去第一行原點 y）。
    #expect(
      pool.lineStep
        == pool.candidateLines[1][0].visualOrigin.y - pool.candidateLines[0][0].visualOrigin.y,
      "行步進應與實際排版行距一致"
    )
    // 捲至末行時，內容底端應恰好貼齊視口底端。
    pool.scrollToMakeLineVisible(pool.candidateLines.count - 1)
    #expect(
      abs(pool.scrollOffset - (pool.candidateOnlySize.height - pool.pageCandidateSize.height))
        < 0.001,
      "捲至末行的偏移量應等於內容高度與視口高度之差"
    )
  }

  // MARK: - 選字鍵標籤之顯示區域

  /// 迴歸鎖定：選字鍵標籤之顯示區域必須是**正方形**（邊長＝該標籤自身之行高），
  /// 不得隨字級而變成「窄高」形；候選字詞自該正方形右緣起排，且該區域之增寬
  /// 不得使候選字詞超出該格。
  @Test
  func testCandidateKeyLabelDisplayAreaIsSquare() throws {
    let baselineSize = PrefMgr.shared.candidateListTextSize
    defer { PrefMgr.shared.candidateListTextSize = baselineSize }

    for size in [12, 16, 24, 40, 96, 196] {
      PrefMgr.shared.candidateListTextSize = size
      let pool = TDK4AppKit.CandidatePool4AppKit(
        candidates: [(keyArray: [""], value: "我"), (keyArray: [""], value: "好")],
        lines: 1, isExpanded: true, selectionKeys: "12", layout: .horizontal
      )
      pool.updateMetrics()
      let cell = pool.candidateLines[0][1]
      let keyFont = cell.selectionKeyFont()
      let keyLineHeight = ceil(keyFont.ascender + abs(keyFont.descender) + keyFont.leading)
      #expect(
        cell.keyLabelBoxSide == keyLineHeight,
        "字級 \(size)：標籤顯示區域之邊長應等於標籤自身行高"
      )
      #expect(
        cell.phraseDrawXOffset == cell.keyLabelBoxSide,
        "字級 \(size)：候選字詞應自正方形區域右緣起排"
      )
      // （標籤之「光學居中」由 `testCandidateKeyLabelInkIsCenteredInItsBox` 專責鎖定：
      //   該處斷言位移不取整、且以墨跡盒之中點對齊區域中點。）
      let phraseWidth = cell.makeAttributedStringPhrase(isMatrix: false).size().width
      #expect(
        2 * pool.padding + cell.phraseDrawXOffset + phraseWidth <= cell.visualDimension.width,
        "字級 \(size)：標籤區域不得將候選字詞擠出該格"
      )
    }
  }

  /// 迴歸鎖定：選字鍵標籤之顯示區域自「標籤字級」擴為「標籤行高」之正方形後，
  /// 標籤右緣、連帶緊隨其右緣的候選字詞一齊右移；該擴大量須由該格之總寬度一併吸收（補償），
  /// 且候選字詞之尾端內距須留足 4 × padding（實機目視定案之額度）——否則字詞會貼齊該格右緣。
  @Test
  func testCandidateCellWidthCompensatesKeyLabelBoxGrowth() throws {
    let baselineSize = PrefMgr.shared.candidateListTextSize
    defer { PrefMgr.shared.candidateListTextSize = baselineSize }

    let candidates: [CandidateInState] = [
      (keyArray: [""], value: "我"),
      (keyArray: [""], value: "淺草"),
      (keyArray: [""], value: "二十四歲是學生"),
      (keyArray: [""], value: "hello"),
    ]

    for size in [12, 16, 24, 40, 96, 196] {
      PrefMgr.shared.candidateListTextSize = size
      let pool = TDK4AppKit.CandidatePool4AppKit(
        candidates: candidates,
        lines: 1, isExpanded: true, selectionKeys: "123456", layout: .horizontal
      )
      pool.updateMetrics()
      for cell in pool.candidateLines.flatMap({ $0 }) where cell.visualDimension.width > 0 {
        let padding = pool.padding
        // 補償：標籤盒相對「舊制之顯示區域寬度」（＝標籤字級）之擴大量，須見於該格之總寬度；
        // 否則被吃掉的是尾端內距。
        let keyLabelBoxGrowth = cell.keyLabelBoxSide - cell.fontSizeKey
        #expect(
          cell.visualDimension.width >= cell.textDimension.width + 4 * padding + keyLabelBoxGrowth,
          "字級 \(size)／\(cell.displayedText)：該格寬度須一併吸收標籤盒之擴大量"
        )
        // 尾端內距：內容自 2 × padding（前端內距）起算、經標籤盒而至候選字詞，其後須留 4 × padding
        // （該額度經實機目視定案——2 × padding 不足以擺脫「字詞貼齊該格右緣」之觀感）。
        let phraseWidth = cell.makeAttributedStringPhrase(isMatrix: false).size().width
        let trailing = cell.visualDimension.width
          - (2 * padding + cell.phraseDrawXOffset + phraseWidth)
        #expect(
          trailing >= 4 * padding,
          "字級 \(size)／\(cell.displayedText)：尾端內距 \(trailing) 小於 4 × padding"
        )
      }
    }
  }

  /// 迴歸鎖定：橫排多行（matrix）模式下，cell 寬度改由 `cellWidthMultiplied` 覆寫，
  /// 故「標籤盒 ＋ 候選字詞」之約束不在該路徑上；該路徑之最小格寬本就遠寬於兩者之和，
  /// 此處逐字級鎖住這個不變式（避免日後調整 matrix 最小寬度時擠到標籤或字詞）。
  @Test
  func testKeyLabelFitsInsideHorizontalMatrixCells() throws {
    let baselineSize = PrefMgr.shared.candidateListTextSize
    defer { PrefMgr.shared.candidateListTextSize = baselineSize }

    for size in [12, 16, 24, 40, 96, 196] {
      PrefMgr.shared.candidateListTextSize = size
      let pool = TDK4AppKit.CandidatePool4AppKit(
        candidates: [(keyArray: [""], value: "我"), (keyArray: [""], value: "好")],
        lines: 4, isExpanded: true, selectionKeys: "12", layout: .horizontal
      )
      pool.updateMetrics()
      let cell = pool.candidateLines[0][1]
      let phraseWidth = cell.makeAttributedStringPhrase(isMatrix: false).size().width
      #expect(
        2 * pool.padding + cell.phraseDrawXOffset + phraseWidth <= cell.visualDimension.width,
        "字級 \(size)：橫排多行格內應同時容得下標籤盒與候選字詞"
      )
    }
  }

  /// 迴歸鎖定：標籤之**墨跡**應光學居中於其正方形區域（兩側留白相等）。
  /// 舊制以 `ceil` 取整居中、位移恆偏正向，肉眼可見「偏 center-trailing」（實測留白差可達 1.8 點）。
  @Test
  func testCandidateKeyLabelInkIsCenteredInItsBox() throws {
    let baselineSize = PrefMgr.shared.candidateListTextSize
    let baselineAppearance = TDK4AppKit.CandidateAppearance.current
    defer {
      PrefMgr.shared.candidateListTextSize = baselineSize
      TDK4AppKit.CandidateAppearance.current = baselineAppearance
    }

    for size in [24, 40, 96] {
      PrefMgr.shared.candidateListTextSize = size
      let pool = TDK4AppKit.CandidatePool4AppKit(
        candidates: [(keyArray: [""], value: "我"), (keyArray: [""], value: "好"), (keyArray: [""], value: "的")],
        lines: 1, isExpanded: true, selectionKeys: "123456", layout: .horizontal
      )
      pool.updateMetrics()
      let cell = pool.candidateLines[0][2] // 非高亮格

      // 不取整：位移須令墨跡盒之中點落在區域中點上（取整即会留下單側偏差）。
      let inkMidX = cell.keyLabelInkBounds.isEmpty
        ? cell.makeAttributedStringHeader().size().width / 2
        : cell.keyLabelInkBounds.midX
      let idealOffset = cell.keyLabelBoxSide / 2 - inkMidX
      #expect(
        abs(cell.headerDrawXOffset - idealOffset) < 0.001,
        "字級 \(size)：標籤橫向位移必須恰好置中（不得取整）"
      )

      // 繪製實查（可繪製時）：兩側留白差 ≤ 1 點。強制兩種外觀各跑一次，
      // 以免斷言結果隨環境（runner 之系統外觀）而異。
      for appearance in [TDK4AppKit.CandidateAppearance.light, .dark] {
        TDK4AppKit.CandidateAppearance.current = appearance
        guard let scan = OffscreenInkScan(view: TDK4AppKit.VwrCandidateTDK4AppKit(thePool: pool)) else {
          continue
        }
        let scale = scan.scale
        let boxMinX = (cell.visualOrigin.x + 2 * pool.padding) * scale
        let boxMaxX = boxMinX + cell.keyLabelBoxSide * scale
        let boxMinY = (cell.visualOrigin.y + cell.headerDrawYOffset) * scale
        let boxMaxY = boxMinY + cell.keyLabelBoxSide * scale
        guard let box = scan.inkBox(
          xRange: Int(boxMinX) ..< Int(boxMaxX.rounded(.up)),
          yRange: Int(boxMinY) ..< Int(boxMaxY.rounded(.up))
        ) else { continue }
        let leading = (CGFloat(box.minX) - boxMinX) / scale
        let trailing = (boxMaxX - CGFloat(box.maxX + 1)) / scale
        #expect(
          abs(leading - trailing) <= 1.0,
          "字級 \(size)／外觀 \(appearance)：標籤兩側留白應相等（實測 leading \(leading)／trailing \(trailing)）"
        )
      }
    }
  }

  /// 驗證：選字窗之外觀覆寫（jailed 於本模組）——rawValue 語義、解析結果、
  /// 以及各處顏色確實隨之切換；`auto` 跟隨系統、`light`／`dark` 各自強制。
  @Test
  func testCandidateAppearanceOverride() throws {
    typealias Appearance = TDK4AppKit.CandidateAppearance
    let previous = Appearance.current
    defer { Appearance.current = previous }

    #expect(Appearance.auto.rawValue == 0)
    #expect(Appearance.light.rawValue == 1)
    #expect(Appearance.dark.rawValue == -1)
    #expect(Appearance.light.isDarkModeResolved == false)
    #expect(Appearance.dark.isDarkModeResolved == true)
    #expect(Appearance.auto.nsAppearance == nil, "auto 不應覆寫 NSAppearance")
    #expect(Appearance.light.nsAppearance?.name == .aqua)
    #expect(Appearance.dark.nsAppearance?.name == .darkAqua)

    // `auto` 於本機（>= macOS 10.14）跟隨系統；`macOS 10.13` 及以前一律解析為淺色（見實作之註）。
    Appearance.current = .auto
    #expect(Appearance.isDarkModeResolved == NSApplication.isDarkMode)

    // 屬性寄存在 pool 內，且會同步至模組層（供 cell 之靜態色解析）。
    let pool = TDK4AppKit.CandidatePool4AppKit(
      candidates: [(keyArray: [""], value: "我")], lines: 1, isExpanded: true,
      selectionKeys: "1", layout: .horizontal
    )
    #expect(pool.candidateAppearance == .auto, "池之預設外觀應為 auto")
    pool.candidateAppearance = .dark
    #expect(pool.isDarkModeResolved == true)
    #expect(Appearance.current == .dark, "池內設定應同步至模組層")
    #expect(TDK4AppKit.CandidateCellData4AppKit.absoluteTextColor == .white)
    pool.candidateAppearance = .light
    #expect(pool.isDarkModeResolved == false)
    #expect(TDK4AppKit.CandidateCellData4AppKit.absoluteTextColor == .black)

    Appearance.current = .dark
    #expect(TDK4AppKit.CandidateCellData4AppKit.absoluteTextColor == .white)
    let darkListBackground = TDK4AppKit.VwrCandidateTDK4AppKit.candidateListBackground
    let darkListBackgroundGSI = GSI4AppKit.VwrCandidateGSI4AppKit.candidateListBackground

    Appearance.current = .light
    #expect(TDK4AppKit.CandidateCellData4AppKit.absoluteTextColor == .black)
    let lightListBackground = TDK4AppKit.VwrCandidateTDK4AppKit.candidateListBackground
    let lightListBackgroundGSI = GSI4AppKit.VwrCandidateGSI4AppKit.candidateListBackground

    #expect(darkListBackground != lightListBackground, "TDK 視圖底應隨外觀覆寫切換")
    #expect(darkListBackgroundGSI != lightListBackgroundGSI, "GSI 視圖底應隨外觀覆寫切換")
  }

  // MARK: - GSI 捲動模式之頂部 pane

  /// 迴歸鎖定：GSI 捲動模式必須繪出頂部 pane（未完成讀音）——
  /// 視窗高度需恰為其讀出「pane 高 ＋ padding」之空間，且該 pane 確實被繪製。
  @Test
  func testGSIScrollModeShowsTopPane() throws {
    let baselineSize = PrefMgr.shared.candidateListTextSize
    let baselineAppearance = TDK4AppKit.CandidateAppearance.current
    defer {
      PrefMgr.shared.candidateListTextSize = baselineSize
      TDK4AppKit.CandidateAppearance.current = baselineAppearance
    }
    PrefMgr.shared.candidateListTextSize = 20

    func makeView(paneText: String?)
      -> (view: GSI4AppKit.VwrCandidateGSI4AppKit, pool: TDK4AppKit.CandidatePool4AppKit) {
      let pool = TDK4AppKit.CandidatePool4AppKit(
        candidates: (0 ..< 40).map { (keyArray: ["", ""], value: "字\($0)") },
        lines: 4, isExpanded: true, selectionKeys: "123456", layout: .horizontal
      )
      pool.unfinishedReadingResult = paneText
      pool.updateMetrics()
      pool.computeCandidateOnlySize()
      let view = GSI4AppKit.VwrCandidateGSI4AppKit(thePool: pool)
      view.rendersInScrollMode = true
      return (view, pool)
    }

    let without = makeView(paneText: nil)
    let with = makeView(paneText: "ban")
    let paneDimension = with.pool.attributedDescriptionUnfinishedReading
      .getBoundingDimension(forceFallback: true)
    let expectedShift = ceil(paneDimension.height) + with.pool.padding
    #expect(paneDimension.height > 0, "前置條件：pane 應有高度")
    // 幾何（不依賴繪製）：pane 之下移量、以及其讀出之空間。
    #expect(with.view.topPaneShift == expectedShift, "頂部 pane 之下移量應為「pane 高 ＋ padding」")
    #expect(without.view.topPaneShift == 0, "未提供未完成讀音時不應有下移量")
    #expect(
      with.view.fittingSize.height - without.view.fittingSize.height == expectedShift,
      "捲動模式下視窗高度應為頂部 pane 讓出「pane 高 ＋ padding」"
    )
    #expect(
      with.view.fittingSize.width >= paneDimension.width + with.pool.originDelta * 2,
      "視窗寬度應足以容納頂部 pane"
    )
    // 捲動軌道：頂端隨 pane 下移，底端仍應貼齊候選區下緣（不得因 pane 而變短）。
    if with.pool.maxScrollOffset > 0 {
      let track = with.view.scrollerTrackRect(candidateAreaSize: with.pool.pageCandidateSize)
      let expectedBottom = with.pool.originDelta + expectedShift + with.pool.pageCandidateSize.height
      #expect(
        abs(track.maxY - expectedBottom) < 0.001,
        "捲動軌道底端應貼齊候選區下緣（實測 \(track.maxY) vs \(expectedBottom)）"
      )
    }

    // 繪製實查（可繪製時）：以點陣圖掃描證明 pane 確實被畫出——
    // 其所在之頂帶內有墨跡（非空白），且該帶之墨跡橫向範圍遠窄於「未提供 pane」時
    // （後者之頂帶裝的是整行候選字，故橫向墨跡幾乎滿版面）。
    // 繪製之裁決性查核：以「同一版面、僅換 pane 文字」之兩張圖互比——
    // 兩者之 pane 高度（＝下移量）與候選內容完全相同，故任何差異只可能來自 pane 之字形。
    let withAlt = makeView(paneText: "xyz")
    let altPaneDimension = withAlt.pool.attributedDescriptionUnfinishedReading
      .getBoundingDimension(forceFallback: true)
    #expect(
      ceil(altPaneDimension.height) == ceil(paneDimension.height),
      "前置條件：兩組 pane 文字之高度須相同（否則候選區位移量不同）"
    )
    for appearance in [TDK4AppKit.CandidateAppearance.light, .dark] {
      with.pool.candidateAppearance = appearance
      without.pool.candidateAppearance = appearance
      withAlt.pool.candidateAppearance = appearance
      let paneBand = 0 ..< max(1, Int(expectedShift))
      guard let paneScan = OffscreenInkScan(view: with.view),
            let altScan = OffscreenInkScan(view: withAlt.view) else { continue }
      #expect(
        paneScan.inkedColumnCount(rows: paneBand) > 0,
        "提供未完成讀音時，頂部 pane 應被繪出（其列帶內應有墨跡）"
      )
      let paneWidth = max(paneDimension.width, altPaneDimension.width)
      if let diff = paneScan.pixelDifference(comparedTo: altScan, rows: paneBand) {
        #expect(
          diff.count > 20,
          "頂部 pane 之文字應被繪出：外觀 \(appearance) 換掉其文字後差異像素僅 \(diff.count)"
        )
        #expect(
          Double(diff.minX) >= (with.pool.originDelta * paneScan.scale) - 2,
          "差異應自 pane 之左緣起（外觀 \(appearance) 實測 minX \(diff.minX)）"
        )
        #expect(
          Double(diff.maxX) <= (with.pool.originDelta + paneWidth + 8) * paneScan.scale,
          "差異應止於 pane 之右緣（外觀 \(appearance) 實測 maxX \(diff.maxX)）"
        )
      } else {
        Issue.record("外觀 \(appearance)：兩張僅 pane 文字不同之圖竟完全相同")
      }
    }
  }

  /// 驗證：computeCandidateOnlySize 能正確計算全部候選行的完整尺寸。
  @Test
  func testGSIComputeCandidateOnlySize() throws {
    let pool = TDK4AppKit.CandidatePool4AppKit(
      candidates: variableCandidatesINMU, lines: 4, isExpanded: true,
      selectionKeys: "123456", layout: .horizontal
    )
    pool.computeCandidateOnlySize()
    #expect(pool.candidateOnlySize.width > 0, "完整候選區寬度應大於零")
    #expect(pool.candidateOnlySize.height > 0, "完整候選區高度應大於零")
    #expect(pool.candidateOnlySize.height >= pool.pageCandidateSize.height, "完整高度應不小於頁面高度")
  }

  /// 驗證：scrollOffset 邊界箝制正確（不可負值、不可超過 maxScrollOffset）。
  @Test
  func testGSIScrollOffsetClamping() throws {
    let pool = TDK4AppKit.CandidatePool4AppKit(
      candidates: variableCandidatesINMU, lines: 4, isExpanded: true,
      selectionKeys: "123456", layout: .horizontal
    )
    pool.computeCandidateOnlySize()
    #expect(pool.scrollOffset == 0, "初始 scrollOffset 應為零")
    pool.scrollByPixels(-100)
    #expect(pool.scrollOffset == 0, "負向捲動不應使 scrollOffset 變為負值")
    pool.scrollByPixels(pool.maxScrollOffset + 1_000)
    #expect(pool.scrollOffset == pool.maxScrollOffset, "正向捲動不應超過 maxScrollOffset")
  }

  /// 驗證：snapScrollOffset 能精確吸附至最近的行邊界。
  @Test
  func testGSISnapScrollOffsetPrecision() throws {
    let pool = TDK4AppKit.CandidatePool4AppKit(
      candidates: variableCandidatesINMU, lines: 4, isExpanded: true,
      selectionKeys: "123456", layout: .horizontal
    )
    pool.computeCandidateOnlySize()
    let step = pool.lineStep
    #expect(step > 0, "行步進值應大於零")
    pool.scrollOffset = step * 1.4
    pool.snapScrollOffset()
    #expect(pool.scrollOffset == step, "1.4 倍步進應吸附至 1 倍步進")
    pool.scrollOffset = step * 1.6
    pool.snapScrollOffset()
    #expect(pool.scrollOffset == step * 2, "1.6 倍步進應吸附至 2 倍步進")
  }

  /// 驗證：scrollToMakeLineVisible 能將目標行保持於 viewport 內。
  @Test
  func testGSIScrollToMakeLineVisible() throws {
    let pool = TDK4AppKit.CandidatePool4AppKit(
      candidates: variableCandidatesINMU, lines: 4, isExpanded: true,
      selectionKeys: "123456", layout: .horizontal
    )
    pool.computeCandidateOnlySize()
    let totalLines = pool.candidateLines.count
    #expect(totalLines > pool.maxLinesPerPage, "總行數應大於每頁最大行數")
    pool.scrollToMakeLineVisible(6)
    #expect(pool.scrollOffset <= pool.maxScrollOffset, "捲動至第 6 行後 scrollOffset 不應超限")
    pool.scrollToMakeLineVisible(totalLines - 1)
    #expect(pool.scrollOffset <= pool.maxScrollOffset, "捲動至末行後 scrollOffset 不應超限")
  }

  /// 驗證：scrollerThumbRatio 與 scrollerThumbPosition 計算正確。
  @Test
  func testGSIScrollerCalculations() throws {
    let pool = TDK4AppKit.CandidatePool4AppKit(
      candidates: variableCandidatesINMU, lines: 4, isExpanded: true,
      selectionKeys: "123456", layout: .horizontal
    )
    pool.computeCandidateOnlySize()
    #expect(pool.scrollerThumbRatio > 0 && pool.scrollerThumbRatio <= 1, "thumb 比例應在 (0, 1] 範圍內")
    #expect(pool.scrollerThumbPosition == 0, "初始 thumb 位置應為零")
    pool.scrollOffset = pool.maxScrollOffset
    #expect(pool.scrollerThumbPosition == 1, "捲至末尾時 thumb 位置應為 1")
  }

  /// 驗證：resetScrollOffset 能正確重置捲動偏移量至零。
  @Test
  func testGSIResetScrollOffset() throws {
    let pool = TDK4AppKit.CandidatePool4AppKit(
      candidates: variableCandidatesINMU, lines: 4, isExpanded: true,
      selectionKeys: "123456", layout: .horizontal
    )
    pool.computeCandidateOnlySize()
    pool.scrollByLines(3)
    #expect(pool.scrollOffset > 0, "捲動後 scrollOffset 應大於零")
    pool.resetScrollOffset()
    #expect(pool.scrollOffset == 0, "重置後 scrollOffset 應歸零")
  }

  /// 迴歸鎖定：struct 值語義下 candidateLines 與 candidateDataAll 各自持獨立副本，
  /// 高亮狀態必須同步寫入兩份陣列——視圖繪製、展頁判定（expandIfNeeded 的
  /// 「目前頁內含高亮 cell」guard）與高亮排版矩形（圓角半徑的輸入）都讀 candidateLines。
  @Test
  func testHighlightSyncsCandidateLinesAndMetrics() throws {
    let pool = TDK4AppKit.CandidatePool4AppKit(
      candidates: variableCandidatesINMU, lines: 4, isExpanded: true,
      selectionKeys: "123456", layout: .horizontal
    )
    // 初始：索引 0 高亮，candidateLines 內的對應 cell 必須同步。
    var highlightedInLines = pool.candidateLines.flatMap { $0 }.filter(\.isHighlighted)
    #expect(highlightedInLines.count == 1)
    #expect(highlightedInLines.first?.index == 0)

    // 移動高亮後：candidateLines 內的高亮 cell 需同步移動（方向鍵高亮移動的繪製來源）。
    pool.highlight(at: 3)
    highlightedInLines = pool.candidateLines.flatMap { $0 }.filter(\.isHighlighted)
    #expect(highlightedInLines.count == 1)
    #expect(highlightedInLines.first?.index == 3)

    // 展頁判定所依賴的「目前頁內含高亮 cell」必須成立。
    let shown = pool.candidateLines[pool.lineRangeForCurrentPage].flatMap { $0 }
    #expect(!shown.filter(\.isHighlighted).isEmpty, "目前頁內應含高亮 cell（展頁 guard 依賴）")

    // 高亮排版矩形（cellRadius / windowRadius 的輸入）不得為零，否則視窗圓角塌縮成方型。
    pool.updateMetrics()
    #expect(pool.metrics.highlightedCandidate.height > 0, "高亮排版矩形不得為零（圓角半徑輸入）")

    // 選字鍵需同步寫入 candidateDataAll（兩陣列保持一致）：
    // 鍵值 = selectionKeys 的第 subIndex 個字元（subIndex 為 cell 在其行內的欄位）。
    let cell = pool.candidateDataAll[3]
    let expectedKey = pool.selectionKeys.map(\.description)[cell.subIndex]
    #expect(cell.selectionKey == expectedKey, "高亮 cell 的選字鍵應為其 subIndex 對應鍵")
  }

  /// 迴歸鎖定：任何翻頁／翻行／跳轉操作序列之後，updateMetrics 附加的空白填充行
  /// 皆不得寫回 candidateLines——真實候選行的內容與索引必須始終保持建池時的原樣，
  /// 否則填充範本（💩 cell）會覆寫真實候選行、污染後續繪製與點擊判定。
  @Test
  func testNavigationNeverCorruptsCandidateLines() throws {
    for layout in [UILayoutOrientation.horizontal, .vertical] {
      let pool = TDK4AppKit.CandidatePool4AppKit(
        candidates: variableCandidatesINMU, lines: 4, isExpanded: true,
        selectionKeys: "1234", layout: layout
      )
      let expectedLines = pool.candidateLines.map { $0.map(\.displayedText) }
      let expectedIndices = pool.candidateLines.map { $0.map(\.index) }
      let totalLines = pool.candidateLines.count
      #expect(totalLines > 4, "前置條件：總行數應大於每頁行數")

      // 涵蓋頁面往返、行往返、邊界回繞與跳轉的操作序列。
      let operations: [(String, () -> ())] = [
        ("翻至末頁", { while pool.flipPage(isBackward: false) {} }),
        ("逐行至末行", { while pool.consecutivelyFlipLines(isBackward: false, count: 1) {} }),
        ("回繞高亮", { pool.highlightNeighborCandidate(isBackward: false) }),
        ("翻回首頁", { while pool.flipPage(isBackward: true) {} }),
        ("逐行回首行", { while pool.consecutivelyFlipLines(isBackward: true, count: 1) {} }),
        ("跳轉至末位", { pool.highlight(at: pool.candidateDataAll.count - 1) }),
        ("跳轉回首位", { pool.highlight(at: 0) }),
        ("末頁附近往返", {
          pool.highlight(at: pool.candidateDataAll.count - 1)
          pool.flipPage(isBackward: true)
          pool.flipPage(isBackward: false)
          pool.consecutivelyFlipLines(isBackward: true, count: 1)
        }),
      ]
      for (name, operation) in operations {
        operation()
        pool.updateMetrics()
        let actualLines = pool.candidateLines.map { $0.map(\.displayedText) }
        let actualIndices = pool.candidateLines.map { $0.map(\.index) }
        #expect(
          actualLines == expectedLines,
          "\(layout) \(name)後：候選行內容不得被填充行覆寫"
        )
        #expect(
          actualIndices == expectedIndices,
          "\(layout) \(name)後：候選行索引不得被填充行覆寫"
        )
        #expect(
          !actualLines.flatMap(\.self).contains("💩"),
          "\(layout) \(name)後：資料池內不得出現填充範本 cell"
        )
      }
    }
  }

  // MARK: - 頂部 pane（Unfinished Reading）測試

  /// 驗證：未指派 unfinishedReadingResult 時，頂部 pane 完全隱藏——
  /// 屬性字串為空、排版矩形為零、版面與未提供資料時相同。
  @Test
  func testUnfinishedReadingPaneHiddenWhenNotProvided() throws {
    let pool = TDK4AppKit.CandidatePool4AppKit(
      candidates: variableCandidatesINMU, lines: 1, isExpanded: true,
      selectionKeys: "123456", layout: .horizontal
    )
    #expect(pool.unfinishedReadingResult == nil)
    #expect(pool.attributedDescriptionUnfinishedReading.string.isEmpty)
    #expect(pool.metrics.unfinishedReading == .zero)
  }

  /// 驗證：提供 unfinishedReadingResult 後，頂部 pane 佔據候選區上方的空間——
  /// 候選 cell 與高亮矩形整體下移、fittingSize 加高、視窗寬度足以容納 pane；
  /// 撤除資料後版面回到原樣。
  @Test
  func testUnfinishedReadingPaneShiftsCandidatesDown() throws {
    let pool = TDK4AppKit.CandidatePool4AppKit(
      candidates: variableCandidatesINMU, lines: 1, isExpanded: true,
      selectionKeys: "123456", layout: .horizontal
    )
    let baselineCellOriginY = pool.candidateLines[0][0].visualOrigin.y
    let baselineHighlightedLineY = pool.metrics.highlightedLine.origin.y
    let baselineHighlightedCandidateY = pool.metrics.highlightedCandidate.origin.y
    let baselineFittingHeight = pool.metrics.fittingSize.height
    let baselineFittingWidth = pool.metrics.fittingSize.width

    pool.unfinishedReadingResult = "ban"
    pool.updateMetrics()

    let paneRect = pool.metrics.unfinishedReading
    #expect(paneRect != .zero, "提供未完成讀音後頂部 pane 矩形不得為零")
    #expect(paneRect.origin.y == pool.originDelta, "頂部 pane 應貼齊內容區頂端")
    #expect(paneRect.height > 0)
    #expect(paneRect.width > 0)

    // 候選區整體下移 pane 高度＋padding。
    let expectedShift = paneRect.height + pool.padding
    #expect(
      abs(pool.candidateLines[0][0].visualOrigin.y - (baselineCellOriginY + expectedShift)) < 0.001,
      "候選 cell 應隨頂部 pane 下移"
    )
    #expect(
      abs(pool.metrics.highlightedLine.origin.y - (baselineHighlightedLineY + expectedShift)) < 0.001,
      "高亮行矩形應隨之下移"
    )
    #expect(
      abs(pool.metrics.highlightedCandidate.origin.y - (baselineHighlightedCandidateY + expectedShift)) < 0.001,
      "高亮候選矩形應隨之下移"
    )
    #expect(
      abs(pool.metrics.fittingSize.height - (baselineFittingHeight + expectedShift)) < 0.001,
      "視窗高度應隨 pane 增加"
    )
    #expect(
      pool.metrics.fittingSize.width >= paneRect.width + pool.originDelta * 2,
      "視窗寬度應足以容納頂部 pane（含左右邊距）"
    )
    #expect(
      pool.metrics.fittingSize.width >= baselineFittingWidth,
      "視窗寬度不得因 pane 而縮小"
    )

    // 撤除資料後回到原樣。
    pool.unfinishedReadingResult = nil
    pool.updateMetrics()
    #expect(pool.metrics.unfinishedReading == .zero)
    #expect(
      abs(pool.candidateLines[0][0].visualOrigin.y - baselineCellOriginY) < 0.001,
      "撤除後候選 cell 應回到原位"
    )
    #expect(
      abs(pool.metrics.fittingSize.height - baselineFittingHeight) < 0.001,
      "撤除後視窗高度應回到原樣"
    )
  }

  // MARK: - 讀音 Disambiguation 拼音顯示（PhonabetPinyinConverter）測試

  /// 驗證：未指派 phonabetPinyinConverter 時，讀音 disambiguation 維持注音讀音原樣。
  @Test
  func testReadingDisambiguationKeepsPhonabetWithoutConverter() throws {
    let candidates: [CandidateInState] = [
      (keyArray: ["ㄨㄛˇ"], value: "我"),
      (keyArray: ["ㄨㄛ"], value: "我"),
    ]
    let pool = TDK4AppKit.CandidatePool4AppKit(
      candidates: candidates, selectionKeys: "123", layout: .horizontal
    )
    defer { pool.phonabetPinyinConverter = nil }

    pool.updateReadingDisambiguation()
    #expect(pool.readingDisambiguationResult == "ㄨㄛˇ")
  }

  /// 驗證：指派 phonabetPinyinConverter 後，讀音 disambiguation 顯示轉換後的內容。
  /// （轉換鏈本身由 Tekkon 提供，此處以 stub converter 驗證 pool 的指派契約。）
  @Test
  func testReadingDisambiguationUsesConverterWhenAssigned() throws {
    let candidates: [CandidateInState] = [
      (keyArray: ["ㄨㄛˇ"], value: "我"),
      (keyArray: ["ㄨㄛ"], value: "我"),
    ]
    let pool = TDK4AppKit.CandidatePool4AppKit(
      candidates: candidates, selectionKeys: "123", layout: .horizontal
    )
    defer { pool.phonabetPinyinConverter = nil }

    pool.phonabetPinyinConverter = { reading in
      switch reading {
      case "ㄨㄛˇ": return "wǒ"
      case "ㄨㄛ": return "wō"
      default: return reading
      }
    }
    pool.updateReadingDisambiguation()
    #expect(pool.readingDisambiguationResult == "wǒ")
  }

  /// 驗證：converter 對多讀音字詞逐 cell 生效，且以「-」連接；`_` 前綴 cell 維持「??」。
  @Test
  func testReadingDisambiguationConverterAppliesPerCell() throws {
    let candidates: [CandidateInState] = [
      (keyArray: ["ㄓㄨㄥ", "ㄍㄨㄛˊ"], value: "中國"),
      (keyArray: ["ㄓㄨㄥ", "ㄍㄨㄛ"], value: "中國"),
    ]
    let pool = TDK4AppKit.CandidatePool4AppKit(
      candidates: candidates, selectionKeys: "123", layout: .horizontal
    )
    defer { pool.phonabetPinyinConverter = nil }

    pool.phonabetPinyinConverter = { reading in
      reading.hasPrefix("ㄓㄨㄥ") ? "zhōng" : "guó"
    }
    pool.updateReadingDisambiguation()
    #expect(pool.readingDisambiguationResult == "zhōng-guó")
  }

  /// 驗證：即使指派了 converter，`_` 前綴的讀音 cell（標點／特殊鍵）仍顯示「??」。
  @Test
  func testReadingDisambiguationConverterSkipsUnderscoreCells() throws {
    let candidates: [CandidateInState] = [
      (keyArray: ["_punctuation"], value: "，"),
      (keyArray: ["ㄨㄛ"], value: "我"),
    ]
    let pool = TDK4AppKit.CandidatePool4AppKit(
      candidates: candidates, selectionKeys: "123", layout: .horizontal
    )
    defer { pool.phonabetPinyinConverter = nil }

    pool.phonabetPinyinConverter = { reading in
      reading == "ㄨㄛ" ? "wō" : reading
    }
    pool.updateReadingDisambiguation()
    // 任一讀音 cell 以 "_" 開頭 → 整段不顯示。
    #expect(pool.readingDisambiguationResult == nil)
  }
}

// MARK: - OffscreenInkScan

/// 離屏渲染之墨跡偵測。**刻意不使用 `bitmapData` 之原始位元組**：
/// 其通道序隨環境（系統外觀、繪圖驅動）而異——曾令 CI 之偵測把第 0 列誤判為墨跡
/// （實測 `firstRowWithPane` 與 `firstRowWithoutPane` 皆為 0，本地卻正常）。
/// 本掃描器一律以 `colorAt(x:y:)` 取值（與通道序無關），先除以 alpha 還原非預乘值，
/// 再以整張圖最常見之亮度為底色——深色／淺色模式皆適用。
struct OffscreenInkScan {
  // MARK: Lifecycle

  init?(view: NSView) {
    view.frame = CGRect(origin: .zero, size: view.fittingSize)
    let pointSize = view.bounds.size
    guard pointSize.width >= 1, pointSize.height >= 1,
          let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
    view.cacheDisplay(in: view.bounds, to: rep)
    self.rep = rep
    self.scale = CGFloat(rep.pixelsWide) / pointSize.width
    var histogram: [Int: Int] = [:]
    for y in stride(from: 0, to: rep.pixelsHigh, by: 3) {
      for x in stride(from: 0, to: rep.pixelsWide, by: 3) {
        guard let lum = Self.luminance(rep: rep, x: x, y: y) else { continue }
        histogram[Int(lum * 100), default: 0] += 1
      }
    }
    guard let mode = histogram.max(by: { $0.value < $1.value }) else { return nil }
    self.background = CGFloat(mode.key) / 100
  }

  // MARK: Internal

  /// 點陣圖像素 ÷ 視圖點之比例（Retina backing scale）。
  let scale: CGFloat

  /// 指定列帶內有墨跡之像素行數（取樣步進 2 像素）。
  func inkedColumnCount(rows: Range<Int>) -> Int {
    let clampedRows = max(0, rows.lowerBound) ..< min(rep.pixelsHigh, rows.upperBound)
    guard !clampedRows.isEmpty else { return 0 }
    var count = 0
    for x in stride(from: 0, to: rep.pixelsWide, by: 2) {
      for y in clampedRows where isInk(x: x, y: y) {
        count += 1
        break
      }
    }
    return count
  }

  /// 指定矩形內之墨跡範圍（像素座標）。

  /// 與另一張同尺寸之掃描逐像素比對，取差異之像素數與橫向範圍。
  /// （用來証明「某區域的內容確實因某要素而改變」：差異之橫向範圍即該要素之所在。）
  func pixelDifference(
    comparedTo other: Self, rows: Range<Int>
  )
    -> (count: Int, minX: Int, maxX: Int)? {
    let clampedRows = max(0, rows.lowerBound) ..< min(rep.pixelsHigh, other.rep.pixelsHigh, rows.upperBound)
    guard !clampedRows.isEmpty else { return nil }
    var count = 0, minX = Int.max, maxX = Int.min
    for y in clampedRows {
      for x in 0 ..< min(rep.pixelsWide, other.rep.pixelsWide) {
        let lhs = Self.colorComponents(rep: rep, x: x, y: y)
        let rhs = Self.colorComponents(rep: other.rep, x: x, y: y)
        guard let lhs, let rhs else {
          // 兩邊皆透明（如圓角外之裁切區）視為相同；僅單邊透明方算差異。
          if (lhs == nil) != (rhs == nil) {
            count += 1
            minX = min(minX, x); maxX = max(maxX, x)
          }
          continue
        }
        let delta = abs(lhs.0 - rhs.0) + abs(lhs.1 - rhs.1) + abs(lhs.2 - rhs.2)
        if delta > 0.25 {
          count += 1
          minX = min(minX, x); maxX = max(maxX, x)
        }
      }
    }
    return count > 0 ? (count, minX, maxX) : nil
  }

  func inkBox(xRange: Range<Int>, yRange: Range<Int>)
    -> (minX: Int, maxX: Int, minY: Int, maxY: Int)? {
    var minX = Int.max, maxX = Int.min, minY = Int.max, maxY = Int.min
    for y in max(0, yRange.lowerBound) ..< min(rep.pixelsHigh, yRange.upperBound) {
      for x in max(0, xRange.lowerBound) ..< min(rep.pixelsWide, xRange.upperBound) {
        guard isInk(x: x, y: y) else { continue }
        minX = min(minX, x); maxX = max(maxX, x)
        minY = min(minY, y); maxY = max(maxY, y)
      }
    }
    return minX <= maxX ? (minX, maxX, minY, maxY) : nil
  }

  // MARK: Private

  private let rep: NSBitmapImageRep
  private let background: CGFloat

  private static func colorComponents(rep: NSBitmapImageRep, x: Int, y: Int)
    -> (CGFloat, CGFloat, CGFloat)? {
    guard x >= 0, y >= 0, x < rep.pixelsWide, y < rep.pixelsHigh,
          let color = rep.colorAt(x: x, y: y), color.alphaComponent > 0.5 else { return nil }
    let alpha = max(color.alphaComponent, 0.0001)
    return (color.redComponent / alpha, color.greenComponent / alpha, color.blueComponent / alpha)
  }

  private static func luminance(rep: NSBitmapImageRep, x: Int, y: Int) -> CGFloat? {
    guard x >= 0, y >= 0, x < rep.pixelsWide, y < rep.pixelsHigh,
          let color = rep.colorAt(x: x, y: y), color.alphaComponent > 0.5 else { return nil }
    let alpha = max(color.alphaComponent, 0.0001)
    return (
      0.2126 * color.redComponent + 0.7152 * color.greenComponent
        + 0.0722 * color.blueComponent
    ) / alpha
  }

  private func isInk(x: Int, y: Int) -> Bool {
    guard let lum = Self.luminance(rep: rep, x: x, y: y) else { return false }
    return abs(lum - background) > 0.25
  }
}
