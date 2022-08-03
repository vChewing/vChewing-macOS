// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AVFoundation
import Foundation

public enum clsSFX {
  static func beep() {
    let filePath = Bundle.main.path(forResource: mgrPrefs.shouldNotFartInLieuOfBeep ? "Beep" : "Fart", ofType: "m4a")!
    let fileURL = URL(fileURLWithPath: filePath)
    var soundID: SystemSoundID = 0
    AudioServicesCreateSystemSoundID(fileURL as CFURL, &soundID)
    AudioServicesPlaySystemSound(soundID)
  }

  static func beep(count: Int = 1) {
    if count <= 1 {
      clsSFX.beep()
      return
    }
    for _ in 0...count {
      clsSFX.beep()
      usleep(500_000)
    }
  }
}
