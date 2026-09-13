// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

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
      // No need for AudioServicesDisposeSystemSoundID(soundID).
      // Reason: It hinders audio from being played back.
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
