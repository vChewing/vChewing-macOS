// Ref: https://stackoverflow.com/a/75870807/4162914

// #import <IOKit/IOKitLib.h>
// #import <IOKit/hid/IOHIDBase.h>

import CapsLockToggler

// MARK: - CapsLockToggler

public enum CapsLockToggler {
  public static var isOn: Bool {
    var state = false
    try? IOKit.handleHIDSystemService { ioConnect in
      IOHIDGetModifierLockState(ioConnect, Int32(kIOHIDCapsLockState), &state)
    }
    return state
  }

  public static func toggle() {
    try? IOKit.handleHIDSystemService { ioConnect in
      var state = false
      IOHIDGetModifierLockState(ioConnect, Int32(kIOHIDCapsLockState), &state)
      state.toggle()
      IOHIDSetModifierLockState(ioConnect, Int32(kIOHIDCapsLockState), state)
    }
  }

  public static func turnOff() {
    try? IOKit.handleHIDSystemService { ioConnect in
      IOHIDSetModifierLockState(ioConnect, Int32(kIOHIDCapsLockState), false)
    }
  }
}

// MARK: - IOKit

// Refactored by Shiki Suen (MIT License)
public enum IOKit {
  public static func handleHIDSystemService(_ taskHandler: @escaping (io_connect_t) -> ()) throws {
    let ioService: io_service_t = IOServiceGetMatchingService(
      0,
      IOServiceMatching(kIOHIDSystemClass)
    )
    var connect: io_connect_t = 0
    let x = IOServiceOpen(ioService, mach_task_self_, UInt32(kIOHIDParamConnectType), &connect)
    if let errorOne = Mach.KernReturn(rawValue: x), errorOne != .success {
      throw errorOne
    }
    taskHandler(connect)
    let y = IOServiceClose(connect)
    if let errorTwo = Mach.KernReturn(rawValue: y), errorTwo != .success {
      throw errorTwo
    }
  }
}

// MARK: - Mach

// Refactored by Shiki Suen (MIT License)
public enum Mach {
  public enum KernReturn: Int32, Error {
    case success = 0
    case invalidAddress = 1
    case protectionFailure = 2
    case noSpace = 3
    case invalidArgument = 4
    case failure = 5
    case resourceShortage = 6
    case notReceiver = 7
    case noAccess = 8
    case memoryFailure = 9
  }
}
