// Copyright (c) 2022 and onwards Isaac Xen (MIT License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service
marks, or product names of Contributor, except as required to fulfill notice
requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import Cocoa

public class clsSFX: NSObject, NSSoundDelegate {
	private static let shared = clsSFX()
	override private init() {
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
		var sndBeep: String
		if mgrPrefs.shouldNotFartInLieuOfBeep == false {
			sndBeep = "Fart"
		} else {
			sndBeep = "Beep"
		}
		guard
			let beep = NSSound(named: sndBeep)
		else {
			NSSound.beep()
			return
		}
		beep.delegate = self
		beep.volume = 0.4
		beep.play()
		currentBeep = beep
	}

	@objc public func sound(_: NSSound, didFinishPlaying _: Bool) {
		currentBeep = nil
	}

	@objc static func beep() {
		shared.beep()
	}
}
