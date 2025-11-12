// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import MegrezTestComponents
import XCTest

@testable import Megrez

private typealias SimpleLM = MegrezTestComponents.SimpleLM
private typealias MockLM = MegrezTestComponents.MockLM

private let baselineOverrideScore: Double = 114_514

// MARK: - NodeOverrideStatusTests

final class NodeOverrideStatusTests: XCTestCase {
  /// 測試 FIUUID 的基本功能
  func testFIUUID() throws {
    let uuid1 = FIUUID()
    let uuid2 = FIUUID()

    // 確保每個 UUID 都是唯一的
    XCTAssertNotEqual(uuid1, uuid2)

    // 測試 UUID 字串格式
    let uuidString = uuid1.uuidString()
    XCTAssertEqual(uuidString.count, 36)
    XCTAssertTrue(uuidString.contains("-"))
    XCTAssertTrue(uuidString.allSatisfy { $0 == "-" || "0123456789ABCDEF".contains($0) })

    // 測試 Codable
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    let encoded = try encoder.encode(uuid1)
    let decoded = try decoder.decode(FIUUID.self, from: encoded)
    XCTAssertEqual(uuid1, decoded)
  }

  /// 測試 NodeOverrideStatus 的基本功能
  func testNodeOverrideStatus() throws {
    let status = NodeOverrideStatus(
      overridingScore: 100.0,
      currentOverrideType: .withSpecified,
      currentUnigramIndex: 2
    )

    XCTAssertEqual(status.overridingScore, 100.0)
    XCTAssertEqual(status.currentOverrideType, .withSpecified)
    XCTAssertEqual(status.currentUnigramIndex, 2)

    // 測試 Codable
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    let encoded = try encoder.encode(status)
    let decoded = try decoder.decode(NodeOverrideStatus.self, from: encoded)
    XCTAssertEqual(status, decoded)
  }

  /// 測試 Node 的 ID 系統和 overrideStatus 動態屬性
  func testNodeIdAndOverrideStatus() throws {
    let mockLM = SimpleLM(input: "test tst -1\ntest2 ts2 -2")
    let node1 = Megrez.Node(
      keyArray: ["test"],
      segLength: 1,
      unigrams: mockLM.unigramsFor(keyArray: ["test"])
    )
    let node2 = Megrez.Node(
      keyArray: ["test2"],
      segLength: 1,
      unigrams: mockLM.unigramsFor(keyArray: ["test2"])
    )

    // 確保每個節點都有唯一的 ID
    XCTAssertNotEqual(node1.id, node2.id)

    // 測試初始狀態
    let initialStatus = node1.overrideStatus
    XCTAssertEqual(initialStatus.overridingScore, 114_514)
    XCTAssertNil(initialStatus.currentOverrideType)
    XCTAssertEqual(initialStatus.currentUnigramIndex, 0)

    // 修改節點狀態
    node1.overridingScore = 200.0
    _ = node1.selectOverrideUnigram(value: node1.unigrams[0].value, type: .withSpecified)

    // 驗證通過 overrideStatus 能正確讀取
    let modifiedStatus = node1.overrideStatus
    XCTAssertEqual(modifiedStatus.overridingScore, baselineOverrideScore)
    XCTAssertEqual(modifiedStatus.currentOverrideType, .withSpecified)
    XCTAssertEqual(modifiedStatus.currentUnigramIndex, 0)

    // 測試通過 overrideStatus 設定狀態
    let newStatus = NodeOverrideStatus(
      overridingScore: 300.0,
      currentOverrideType: .withTopGramScore,
      currentUnigramIndex: 0
    )
    node1.overrideStatus = newStatus

    XCTAssertEqual(node1.overridingScore, 300.0)
    XCTAssertEqual(node1.currentOverrideType, .withTopGramScore)
    XCTAssertEqual(node1.currentUnigramIndex, 0)
  }

  /// 測試 overrideStatus 的溢出保護機制
  func testNodeOverrideStatusOverflowProtection() throws {
    let mockLM = SimpleLM(input: "test tst -1")
    let node = Megrez.Node(
      keyArray: ["test"],
      segLength: 1,
      unigrams: mockLM.unigramsFor(keyArray: ["test"])
    )

    // 嘗試設定溢出的索引
    let overflowStatus = NodeOverrideStatus(
      overridingScore: 100.0,
      currentOverrideType: .withSpecified,
      currentUnigramIndex: 999 // 遠超出 unigrams 陣列範圍
    )

    node.overrideStatus = overflowStatus

    // 應該觸發重設，狀態回到初始值
    XCTAssertNil(node.currentOverrideType)
    XCTAssertEqual(node.currentUnigramIndex, 0)
  }

  /// 測試 Compositor 的節點狀態鏡照功能
  func testCompositorNodeOverrideStatusMirror() throws {
    let compositor = Megrez.Compositor(with: MockLM())

    // 插入一些鍵值
    compositor.insertKey("h")
    compositor.insertKey("o")
    compositor.insertKey("g")

    // 確保有節點被創建
    XCTAssertFalse(compositor.segments.isEmpty)

    // 修改一些節點的狀態
    if let node = compositor.segments[0][1] {
      node.overridingScore = 500.0
      _ = node.selectOverrideUnigram(value: node.unigrams[0].value, type: .withSpecified)
    }

    if let node = compositor.segments[1][2] {
      node.overridingScore = 600.0
      _ = node.selectOverrideUnigram(value: node.unigrams[0].value, type: .withTopGramScore)
    }

    // 創建鏡照
    let mirror = compositor.createNodeOverrideStatusMirror()
    XCTAssertFalse(mirror.isEmpty)

    // 重設所有節點狀態
    compositor.segments.forEach { segment in
      segment.values.forEach { node in
        node.reset()
      }
    }

    // 驗證狀態確實被重設
    if let node = compositor.segments[0][1] {
      XCTAssertNil(node.currentOverrideType)
      XCTAssertEqual(node.currentUnigramIndex, 0)
    }

    // 從鏡照恢復狀態
    compositor.restoreFromNodeOverrideStatusMirror(mirror)

    // 驗證狀態被正確恢復
    if let node = compositor.segments[0][1] {
      XCTAssertEqual(node.overridingScore, baselineOverrideScore)
      XCTAssertEqual(node.currentOverrideType, .withSpecified)
    }

    if let node = compositor.segments[1][2] {
      XCTAssertEqual(node.overridingScore, baselineOverrideScore)
      XCTAssertEqual(node.currentOverrideType, .withTopGramScore)
    }
  }

  /// 測試輕量級狀態複製 vs 完整 Compositor 複製的效果對比
  func testLightweightStatusCopyVsFullCopy() throws {
    let compositor = Megrez.Compositor(with: MockLM())

    // 建立一個較複雜的狀態
    "hello world test".split(separator: " ").forEach { key in
      compositor.insertKey(key.description)
    }

    // 修改一些節點狀態
    var modifiedNodes = 0
    compositor.segments.forEach { segment in
      segment.values.forEach { node in
        node.overridingScore = Double.random(in: 100 ... 1_000)
        _ = node.selectOverrideUnigram(value: node.unigrams[0].value, type: .withSpecified)
        modifiedNodes += 1
      }
    }

    // 方法1：創建輕量級鏡照
    let mirror = compositor.createNodeOverrideStatusMirror()

    // 方法2：完整複製（舊方法）
    let fullyCopiedCompositor = compositor.copy

    // 驗證兩種方法都能保持狀態
    XCTAssertEqual(mirror.count, modifiedNodes)
    XCTAssertEqual(fullyCopiedCompositor.segments.count, compositor.segments.count)

    // 鏡照應該包含所有修改的狀態
    for (_, status) in mirror {
      XCTAssertEqual(status.currentOverrideType, .withSpecified)
      XCTAssertEqual(status.overridingScore, baselineOverrideScore)
    }

    // 現在清空原始 compositor 的狀態
    compositor.segments.forEach { segment in
      segment.values.forEach { node in
        node.reset()
      }
    }

    // 從鏡照恢復
    compositor.restoreFromNodeOverrideStatusMirror(mirror)

    // 驗證恢復效果
    var restoredNodes = 0
    compositor.segments.forEach { segment in
      segment.values.forEach { node in
        if node.currentOverrideType == .withSpecified {
          restoredNodes += 1
        }
      }
    }

    XCTAssertEqual(restoredNodes, modifiedNodes)
  }
}
