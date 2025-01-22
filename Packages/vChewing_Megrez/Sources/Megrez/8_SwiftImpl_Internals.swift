// Swiftified and further development by (c) 2022 and onwards The vChewing Project (MIT License).
// Was initially rebranded from (c) Lukhnos Liu's C++ library "Gramambular 2" (MIT License).
// Walking algorithm (Dijkstra) implemented by (c) 2025 and onwards The vChewing Project (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

// This package is trying to deprecate its dependency of Foundation, hence this file.

extension StringProtocol {
  func has(string target: any StringProtocol) -> Bool {
    let selfArray = Array(unicodeScalars)
    let targetArray = Array(target.description.unicodeScalars)
    guard !target.isEmpty else { return isEmpty }
    guard count >= target.count else { return false }
    for index in 0 ..< selfArray.count {
      let range = index ..< (Swift.min(index + targetArray.count, selfArray.count))
      let ripped = Array(selfArray[range])
      if ripped == targetArray { return true }
    }
    return false
  }

  func sliced(by separator: any StringProtocol = "") -> [String] {
    let selfArray = Array(unicodeScalars)
    let arrSeparator = Array(separator.description.unicodeScalars)
    var result: [String] = []
    var buffer: [Unicode.Scalar] = []
    var sleepCount = 0
    for index in 0 ..< selfArray.count {
      let currentChar = selfArray[index]
      let range = index ..< (Swift.min(index + arrSeparator.count, selfArray.count))
      let ripped = Array(selfArray[range])
      if ripped.isEmpty { continue }
      if ripped == arrSeparator {
        sleepCount = range.count
        result.append(buffer.map { String($0) }.joined())
        buffer.removeAll()
      }
      if sleepCount < 1 {
        buffer.append(currentChar)
      }
      sleepCount -= 1
    }
    result.append(buffer.map { String($0) }.joined())
    buffer.removeAll()
    return result
  }

  func swapping(_ target: String, with newString: String) -> String {
    let selfArray = Array(unicodeScalars)
    let arrTarget = Array(target.description.unicodeScalars)
    var result = ""
    var buffer: [Unicode.Scalar] = []
    var sleepCount = 0
    for index in 0 ..< selfArray.count {
      let currentChar = selfArray[index]
      let range = index ..< (Swift.min(index + arrTarget.count, selfArray.count))
      let ripped = Array(selfArray[range])
      if ripped.isEmpty { continue }
      if ripped == arrTarget {
        sleepCount = ripped.count
        result.append(buffer.map { String($0) }.joined())
        result.append(newString)
        buffer.removeAll()
      }
      if sleepCount < 1 {
        buffer.append(currentChar)
      }
      sleepCount -= 1
    }
    result.append(buffer.map { String($0) }.joined())
    buffer.removeAll()
    return result
  }
}

// MARK: - HybridPriorityQueue

/// 混合優先佇列，會根據元素數量在陣列式與堆積式實作之間自動切換。
struct HybridPriorityQueue<T: Comparable> {
  // MARK: Lifecycle

  init(reversed: Bool = false) {
    self.isReversed = reversed
    self.usingArray = true
    // 預先配置容量以避免頻繁重新調整大小
    self.sortedArray = ContiguousArray<T>()
    sortedArray.reserveCapacity(Self.initialCapacity)
    self.heap = Heap()
  }

  // MARK: Internal

  var isEmpty: Bool {
    // 單一資料來源原則。
    usingArray ? sortedArray.isEmpty : heap.isEmpty
  }

  mutating func enqueue(_ element: T) {
    if _fastPath(usingArray) {
      if sortedArray.count >= Self.threshold {
        switchToHeap()
        heap.insert(element)
        return
      }

      let count = sortedArray.count
      var left = 0
      var right = count

      // 修正：確保比較邏輯與 dequeue 行為一致。
      while left < right {
        let mid = (left + right) >> 1
        let currentElement = sortedArray[mid]

        // 修正：統一比較邏輯
        let comparison = if isReversed {
          element > currentElement // 反向排序：大的優先。
        } else {
          element < currentElement // 正向排序：小的優先。
        }

        if comparison {
          right = mid
        } else {
          left = mid + 1
        }
      }

      sortedArray.insert(element, at: left)
    } else {
      heap.insert(element)
    }
  }

  mutating func dequeue() -> T? {
    guard !isEmpty else { return nil }
    return _fastPath(usingArray) ? sortedArray.removeFirst() : heap.remove()
  }

  // MARK: Private

  /// 根據輸入法使用模式實證調校的閾值。
  ///
  /// 一般情況下選擇 16 的理由：
  /// 1. 大多數中文輸入序列為 1-7 個字符。
  /// 2. 2 的冪次對 CPU 快取較為友善。
  /// 3. 切換至堆積前預留緩衝空間。
  ///
  /// 至於選擇 8 則是為了針對 SandyBridge 做最佳化。
  private static var threshold: Int { 8 }

  /// 為一般使用情況預先配置容量
  private static var initialCapacity: Int { 16 }

  /// 使用 ContiguousArray 來改善值類型的效能表現。
  private var sortedArray: ContiguousArray<T>
  private var heap: Heap<T>
  private var usingArray: Bool
  private let isReversed: Bool

  private mutating func switchToHeap() {
    heap = Heap(array: Array(sortedArray), sort: isReversed ? (>) : (<))
    sortedArray.removeAll(keepingCapacity: true)
    usingArray = false
  }
}

// MARK: - Heap

/// 用於混合佇列堆積部分的二元堆積實作。
private struct Heap<T> where T: Comparable {
  // MARK: Lifecycle

  /// 初期化空堆積。
  init() {
    self.elements = []
  }

  /// 使用元素陣列初期化堆積。
  init(array: any RangeReplaceableCollection<T>, sort: @escaping (T, T) -> Bool) {
    self.elements = .init(array)
    self.sortFunction = sort
    buildHeap()
  }

  // MARK: Internal

  var isEmpty: Bool { elements.isEmpty }

  /// 將元素插入堆積。
  mutating func insert(_ element: T) {
    elements.append(element)
    siftUp(from: elements.count - 1)
  }

  /// 移除並回傳根元素。
  mutating func remove() -> T? {
    guard !elements.isEmpty else { return nil }

    if elements.count == 1 {
      return elements.removeLast()
    }

    let result = elements[0]
    elements[0] = elements.removeLast()
    siftDown(from: 0)

    return result
  }

  // MARK: Private

  private var elements: ContiguousArray<T> = []
  private var sortFunction: (T, T) -> Bool = (<)

  private mutating func buildHeap() {
    for i in stride(from: elements.count / 2 - 1, through: 0, by: -1) {
      siftDown(from: i)
    }
  }

  // 快取對齊最佳化。
  @inline(__always)
  private func parentIndex(of index: Int) -> Int {
    (index - 1) >> 1 // 使用位元運算。
  }

  @inline(__always)
  private func leftChildIndex(of index: Int) -> Int {
    (index << 1) + 1 // 使用位元運算。
  }

  @inline(__always)
  private func rightChildIndex(of index: Int) -> Int {
    (index << 1) + 2 // 使用位元運算替代乘法。
  }

  // 用於熱路徑優化的輔助方法。
  @inline(__always)
  private func shouldSwap(_ parent: Int, _ child: Int) -> Bool {
    sortFunction(elements[child], elements[parent])
  }

  private mutating func siftUp(from index: Int) {
    // 使用臨時變數減少記憶體存取。
    let element = elements[index]
    var child = index

    while child > 0 {
      let parent = parentIndex(of: child)
      // 減少元素交換：先比較後再交換。
      guard sortFunction(element, elements[parent]) else { break }
      elements[child] = elements[parent]
      child = parent
    }

    elements[child] = element
  }

  private mutating func siftDown(from index: Int) {
    let count = elements.count
    let element = elements[index] // 快取目標元素。
    var parent = index

    // 使用較快的位元運算計算首個可能的葉節點位置。
    let firstLeaf = (count - 1) >> 1

    // 當還未達到葉節點時持續下沉。
    while parent < firstLeaf {
      // 使用位元運算計算子節點。
      let leftIdx = (parent << 1) + 1
      let rightIdx = leftIdx + 1
      var candidate = leftIdx

      // 快取子節點值以減少記憶體存取。
      let leftChild = elements[leftIdx]

      // 最佳化分支預測：將較可能的情況放在前面。
      if rightIdx < count {
        let rightChild = elements[rightIdx]
        // 使用臨時變數減少函式呼叫。
        if sortFunction(rightChild, leftChild) {
          candidate = rightIdx
        }
      }

      // 使用已快取的值進行比較。
      if sortFunction(element, candidate == leftIdx ? leftChild : elements[candidate]) {
        break
      }

      // 直接賦值。
      elements[parent] = elements[candidate]
      parent = candidate
    }

    // 只在最終位置寫入一次。
    elements[parent] = element
  }
}
