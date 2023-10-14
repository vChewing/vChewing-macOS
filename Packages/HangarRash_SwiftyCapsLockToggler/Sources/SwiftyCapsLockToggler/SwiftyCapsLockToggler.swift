// Ref: https://stackoverflow.com/a/75870807/4162914

// #import <IOKit/IOKitLib.h>
// #import <IOKit/hid/IOHIDBase.h>

import CapsLockToggler

public enum CapsLockToggler {
  public static func toggle() {
    let thePort: mach_port_t = {
      if #available(macOS 12.0, *) {
        return kIOMainPortDefault
      }
      return kIOMasterPortDefault
    }()
    let ioService: io_service_t = IOServiceGetMatchingService(thePort, IOServiceMatching(kIOHIDSystemClass))
    var ioConnect: io_connect_t = 0
    IOServiceOpen(ioService, mach_task_self_, UInt32(kIOHIDParamConnectType), &ioConnect)
    var state = false
    IOHIDGetModifierLockState(ioConnect, Int32(kIOHIDCapsLockState), &state)
    state.toggle()
    IOHIDSetModifierLockState(ioConnect, Int32(kIOHIDCapsLockState), state)
    IOServiceClose(ioConnect)
  }

  public static func turnOff() {
    let thePort: mach_port_t = {
      if #available(macOS 12.0, *) {
        return kIOMainPortDefault
      }
      return kIOMasterPortDefault
    }()
    let ioService: io_service_t = IOServiceGetMatchingService(thePort, IOServiceMatching(kIOHIDSystemClass))
    var ioConnect: io_connect_t = 0
    IOServiceOpen(ioService, mach_task_self_, UInt32(kIOHIDParamConnectType), &ioConnect)
    IOHIDSetModifierLockState(ioConnect, Int32(kIOHIDCapsLockState), false)
    IOServiceClose(ioConnect)
  }
}
