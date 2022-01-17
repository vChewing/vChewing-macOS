/* 
 *  clsSFX.swift
 *  
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

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
