//
//  WeakValueCache.swift
//  OpenCC
//
//  Created by ddddxxx on 2020/1/3.
//

import Foundation

class WeakBox<Value: AnyObject> {
  private(set) weak var value: Value?

  init(_ value: Value) {
    self.value = value
  }
}

class WeakValueCache<Key: Hashable, Value: AnyObject> {
  private var storage: [Key: WeakBox<Value>] = [:]

  private var lock = NSLock()

  func value(for key: Key) -> Value? {
    storage[key]?.value
  }

  func value(for key: Key, make: () throws -> Value) rethrows -> Value {
    if let value = storage[key]?.value {
      return value
    }
    lock.lock()
    defer { lock.unlock() }
    if let value = storage[key]?.value {
      return value
    }
    let value = try make()
    storage[key] = WeakBox(value)
    return value
  }
}
