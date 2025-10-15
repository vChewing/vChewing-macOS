// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

#if canImport(AppKit)

  import AppKit
  import AVFoundation

  extension NSSound {
    public static func buzz(fart: Bool = false) {
      let resName = fart ? "Fart" : "Beep"
      let filePath = Bundle.main.path(forResource: resName, ofType: "m4a")
      guard let filePath else { return }
      let fileURL = URL(fileURLWithPath: filePath)
      var soundID: SystemSoundID = 0
      AudioServicesCreateSystemSoundID(fileURL as CFURL, &soundID)
      AudioServicesPlaySystemSound(soundID)
      AudioServicesDisposeSystemSoundID(soundID)
    }

    public static func buzz(fart: Bool = false, count: Int) {
      if count <= 1 {
        NSSound.buzz(fart: fart)
        return
      }
      for _ in 0 ... count {
        NSSound.buzz(fart: fart)
        usleep(500_000)
      }
    }
  }

#endif
