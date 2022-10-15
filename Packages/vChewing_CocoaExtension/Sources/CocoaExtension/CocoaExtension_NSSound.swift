// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AVFoundation
import Cocoa

extension NSSound {
  public static func buzz(fart: Bool = false) {
    let filePath = Bundle.main.path(forResource: fart ? "Fart" : "Beep", ofType: "m4a")!
    let fileURL = URL(fileURLWithPath: filePath)
    var soundID: SystemSoundID = 0
    AudioServicesCreateSystemSoundID(fileURL as CFURL, &soundID)
    AudioServicesPlaySystemSound(soundID)
  }

  public static func buzz(fart _: Bool = false, count: Int) {
    if count <= 1 {
      NSSound.buzz()
      return
    }
    for _ in 0...count {
      NSSound.buzz()
      usleep(500_000)
    }
  }
}
