//
// clsSFX.swift
//
// Copyright (c) 2021-2022 The vChewing Project.
//
// Contributors:
//     Shiki Suen (@ShikiSuen) @ vChewing
//     Isaac Xen a.k.a. ix4n33 (@IsaacXen) @ no affiliation
//
// Based on the Syrup Project and the Formosana Library
// by Lukhnos Liu (@lukhnos).
//
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following
// conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
//

import Cocoa

@objc public class clsSFX: NSObject, NSSoundDelegate {
    private static let shared = clsSFX()
    private override init(){
        super.init()
    }
    private var currentBeep: NSSound?
    private func beep() {
        // Stop existing beep
        if let beep = currentBeep {
            if beep.isPlaying {
                beep.stop()
            }
        }
        // Create a new beep sound if possible
        var sndBeep:String
        if Preferences.shouldNotFartInLieuOfBeep == false {
            sndBeep = "Fart"
        } else {
            sndBeep = "Beep"
        }
        guard
            let beep = NSSound(named:sndBeep)
        else {
            NSSound.beep()
            return
        }
        beep.delegate = self
        beep.volume = 0.4
        beep.play()
        currentBeep = beep
    }
    @objc public func sound(_ sound: NSSound, didFinishPlaying flag: Bool) {
        currentBeep = nil
    }
    @objc static func beep() {
        shared.beep()
    }
}
