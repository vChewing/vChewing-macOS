// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import HomaSharedTestComponents
import Testing

@testable import Homa

private let baselineOverrideScore: Double = 114_514

// MARK: - HomaTests_NodeOverrideStatus

struct HomaTests_NodeOverrideStatus: HomaTestSuite {
  @Test("FIUUID Basics")
  func testFIUUIDBasics() throws {
    let uuid1 = FIUUID()
    let uuid2 = FIUUID()

    #expect(uuid1 != uuid2)

    let uuidString = uuid1.uuidString()
    #expect(uuidString.count == 36)
    #expect(uuidString.contains("-"))
    #expect(uuidString.allSatisfy { $0 == "-" || $0.isHexDigit })

    let encoded = try JSONEncoder().encode(uuid1)
    let decoded = try JSONDecoder().decode(FIUUID.self, from: encoded)
    #expect(decoded == uuid1)
  }

  @Test("NodeOverrideStatus Initialization")
  func testNodeOverrideStatusInitialization() {
    // Test default initialization
    let defaultStatus = Homa.NodeOverrideStatus()
    #expect(defaultStatus.overridingScore == 114_514)
    #expect(defaultStatus.currentOverrideType == nil)
    #expect(defaultStatus.currentUnigramIndex == 0)
    #expect(defaultStatus.isExplicitlyOverridden == false)

    // Test custom initialization
    let customStatus = Homa.NodeOverrideStatus(
      overridingScore: 999.0,
      currentOverrideType: .withSpecified,
      currentUnigramIndex: 5
    )
    #expect(customStatus.overridingScore == 999.0)
    #expect(customStatus.currentOverrideType == .withSpecified)
    #expect(customStatus.currentUnigramIndex == 5)
    #expect(customStatus.isExplicitlyOverridden == false)
  }

  @Test("NodeOverrideStatus Equality")
  func testNodeOverrideStatusEquality() {
    let status1 = Homa.NodeOverrideStatus(
      overridingScore: 100.0,
      currentOverrideType: .withTopGramScore,
      currentUnigramIndex: 2
    )

    let status2 = Homa.NodeOverrideStatus(
      overridingScore: 100.0,
      currentOverrideType: .withTopGramScore,
      currentUnigramIndex: 2
    )

    let status3 = Homa.NodeOverrideStatus(
      overridingScore: 200.0,
      currentOverrideType: .withTopGramScore,
      currentUnigramIndex: 2
    )

    #expect(status1 == status2)
    #expect(status1 != status3)
  }

  @Test("Node OverrideStatus Property")
  func testNodeOverrideStatusProperty() {
    let keyArray = ["ㄅ", "ㄧ"]
    let testData = [
      Homa.GramRAW(keyArray: keyArray, value: "逼", probability: -5.0, previous: nil),
      Homa.GramRAW(keyArray: keyArray, value: "比", probability: -8.0, previous: nil),
    ]

    let grams = testData.map { Homa.Gram($0) }
    let node = Homa.Node(keyArray: keyArray, grams: grams)

    // Test getting override status
    let initialStatus = node.overrideStatus
    #expect(initialStatus.overridingScore == 114_514)
    #expect(initialStatus.currentOverrideType == nil)
    #expect(initialStatus.currentUnigramIndex == 0)
    #expect(initialStatus.isExplicitlyOverridden == false)

    // Verify selecting an override promotes the overriding score to the baseline constant.
    node.overridingScore = 42
    let firstGram = grams[0]
    let selectionResult = try? node.selectOverrideGram(
      keyArray: firstGram.keyArray,
      value: firstGram.current,
      previous: firstGram.previous,
      type: .withSpecified
    )
    #expect(selectionResult != nil)
    #expect(node.overridingScore == baselineOverrideScore)
    #expect(node.currentOverrideType == .withSpecified)
    #expect(node.currentGramIndex == 0)

    // Test setting override status
    let newStatus = Homa.NodeOverrideStatus(
      overridingScore: 500.0,
      currentOverrideType: .withSpecified,
      isExplicitlyOverridden: true,
      currentUnigramIndex: 1
    )
    node.overrideStatus = newStatus

    #expect(node.overridingScore == 500.0)
    #expect(node.currentOverrideType == .withSpecified)
    #expect(node.currentGramIndex == 1)
    #expect(node.overrideStatus.isExplicitlyOverridden == true)

    // Test getting updated status
    let updatedStatus = node.overrideStatus
    #expect(updatedStatus.overridingScore == 500.0)
    #expect(updatedStatus.currentOverrideType == .withSpecified)
    #expect(updatedStatus.currentUnigramIndex == 1)
    #expect(updatedStatus.isExplicitlyOverridden == true)
  }

  @Test("NodeOverrideStatus Overflow Protection")
  func testNodeOverrideStatusOverflowProtection() {
    let keyArray = ["ㄅ"]
    let grams = [
      Homa.GramRAW(keyArray: keyArray, value: "逼", probability: -5.0, previous: nil),
    ].map { Homa.Gram($0) }
    let node = Homa.Node(keyArray: keyArray, grams: grams)

    let overflowStatus = Homa.NodeOverrideStatus(
      overridingScore: 100.0,
      currentOverrideType: .withSpecified,
      isExplicitlyOverridden: true,
      currentUnigramIndex: 999
    )

    node.overrideStatus = overflowStatus

    #expect(node.currentOverrideType == nil)
    #expect(node.currentGramIndex == 0)
    #expect(node.overrideStatus.isExplicitlyOverridden == false)
  }

  @Test("Node ID Uniqueness")
  func testNodeIDUniqueness() {
    let keyArray = ["ㄅ", "ㄧ"]
    let testData = [
      Homa.GramRAW(keyArray: keyArray, value: "逼", probability: -5.0, previous: nil),
    ]

    let grams = testData.map { Homa.Gram($0) }
    let node1 = Homa.Node(keyArray: keyArray, grams: grams)
    let node2 = Homa.Node(keyArray: keyArray, grams: grams)

    // Each node should have a unique ID
    #expect(node1.id != node2.id)

    // Copy should have a different ID
    let node3 = node1.copy
    #expect(node1.id != node3.id)
  }

  @Test("Assembler Node Override Status Mirroring")
  func testAssemblerNodeOverrideStatusMirroring() throws {
    let assembler = Self.makeAssemblerUsingMockLM()

    try assembler.insertKeys(["a", "b", "c"])

    // Generate mirror before any changes
    let originalMirror = assembler.createNodeOverrideStatusMirror()
    #expect(!originalMirror.isEmpty)

    // Modify some node states (we'll modify the first available node we find)
    var modifiedNodeId: FIUUID?
    outerLoop: for segment in assembler.segments {
      for (_, node) in segment {
        node.overrideStatus = Homa.NodeOverrideStatus(
          overridingScore: 777.0,
          currentOverrideType: .withSpecified,
          isExplicitlyOverridden: true,
          currentUnigramIndex: 0
        )
        modifiedNodeId = node.id
        break outerLoop
      }
    }

    guard let nodeId = modifiedNodeId else {
      Issue.record("No nodes found to modify")
      return
    }

    // Generate new mirror after changes
    let modifiedMirror = assembler.createNodeOverrideStatusMirror()

    // Verify the change is reflected in the mirror
    #expect(modifiedMirror[nodeId]?.overridingScore == 777.0)
    #expect(modifiedMirror[nodeId]?.currentOverrideType == .withSpecified)
    #expect(modifiedMirror[nodeId]?.isExplicitlyOverridden == true)

    // Reset using original mirror
    assembler.restoreFromNodeOverrideStatusMirror(originalMirror)

    // Verify restoration
    let restoredMirror = assembler.createNodeOverrideStatusMirror()
    #expect(restoredMirror[nodeId]?.overridingScore == originalMirror[nodeId]?.overridingScore)
    #expect(
      restoredMirror[nodeId]?.currentOverrideType
        == originalMirror[nodeId]?
        .currentOverrideType
    )
    #expect(
      restoredMirror[nodeId]?.isExplicitlyOverridden
        == originalMirror[nodeId]?.isExplicitlyOverridden
    )
  }

  @Test("Assembler Node Override Status Mirror vs Copy")
  func testAssemblerNodeOverrideStatusMirrorVsCopy() throws {
    let assembler = Self.makeAssemblerUsingMockLM()

    try assembler.insertKeys(["hello", "world", "test"])

    var modifiedNodes = 0
    for segment in assembler.segments {
      for (_, node) in segment {
        guard let targetGram = node.grams.first else { continue }
        node.overridingScore = .random(in: 100 ... 1_000)
        let selected = try? node.selectOverrideGram(
          keyArray: targetGram.keyArray,
          value: targetGram.current,
          previous: targetGram.previous,
          type: .withSpecified
        )
        #expect(selected != nil)
        modifiedNodes += 1
      }
    }

    #expect(modifiedNodes > 0)

    let mirror = assembler.createNodeOverrideStatusMirror()
    let clonedAssembler = assembler.copy

    #expect(mirror.count == modifiedNodes)
    #expect(clonedAssembler.segments.count == assembler.segments.count)

    for (_, status) in mirror {
      #expect(status.currentOverrideType == .withSpecified)
      #expect(status.overridingScore == baselineOverrideScore)
    }

    assembler.segments.forEach { segment in
      segment.values.forEach { node in
        node.reset()
      }
    }

    assembler.restoreFromNodeOverrideStatusMirror(mirror)

    var restoredNodes = 0
    for segment in assembler.segments {
      for (_, node) in segment {
        if node.currentOverrideType == .withSpecified {
          restoredNodes += 1
          #expect(node.overrideStatus.overridingScore == baselineOverrideScore)
        }
      }
    }

    #expect(restoredNodes == modifiedNodes)
  }

  @Test("NodeOverrideStatus Codable")
  func testNodeOverrideStatusCodable() throws {
    let status = Homa.NodeOverrideStatus(
      overridingScore: 123.45,
      currentOverrideType: .withTopGramScore,
      isExplicitlyOverridden: true,
      currentUnigramIndex: 3
    )

    // Test encoding
    let encoded = try JSONEncoder().encode(status)

    // Test decoding
    let decoded = try JSONDecoder().decode(Homa.NodeOverrideStatus.self, from: encoded)

    #expect(decoded.overridingScore == 123.45)
    #expect(decoded.currentOverrideType == .withTopGramScore)
    #expect(decoded.currentUnigramIndex == 3)
    #expect(decoded.isExplicitlyOverridden == true)
  }
}
