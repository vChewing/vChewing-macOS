/*
 *  InputState.cpp
 *
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

import Cocoa

/// Represents the states for the input method controller.
///
/// An input method is actually a finite state machine. It receives the inputs
/// from hardware like keyboard and mouse, changes its state, updates user
/// interface by the state, and finally produces the text output and then them
/// to the client apps. It should be a one-way data flow, and the user interface
/// and text output should follow unconditionally one single data source.
///
/// The InputState class is for representing what the input controller is doing,
/// and the place to store the variables that could be used. For example, the
/// array for the candidate list is useful only when the user is choosing a
/// candidate, and the array should not exist when the input controller is in
/// another state.
///
/// They are immutable objects. When the state changes, the controller should
/// create a new state object to replace the current state instead of modifying
/// the existing one.
///
/// vChewing's input controller has following possible states:
///
/// - Deactivated: The user is not using vChewing yet.
/// - Empty: The user has switched to vChewing but did not input anything yet,
///   or, he or she has committed text into the client apps and starts a new
///   input phase.
/// - Committing: The input controller is sending text to the client apps.
/// - Inputting: The user has inputted something and the input buffer is
///   visible.
/// - Marking: The user is creating a area in the input buffer and about to
///   create a new user phrase.
/// - Choosing Candidate: The candidate window is open to let the user to choose
///   one among the candidates.
class InputState: NSObject {
}

/// Represents that the input controller is deactivated.
class InputStateDeactivated: InputState {
	override var description: String {
		"<InputStateDeactivated>"
	}
}

/// Represents that the composing buffer is empty.
class InputStateEmpty: InputState {
	@objc var composingBuffer: String {
		""
	}
}

/// Represents that the composing buffer is empty.
class InputStateEmptyIgnoringPreviousState: InputState {
	@objc var composingBuffer: String {
		""
	}
}

/// Represents that the input controller is committing text into client app.
class InputStateCommitting: InputState {
	@objc private(set) var poppedText: String = ""

	@objc convenience init(poppedText: String) {
		self.init()
		self.poppedText = poppedText
	}

	override var description: String {
		"<InputStateCommitting poppedText:\(poppedText)>"
	}
}

/// Represents that the composing buffer is not empty.
class InputStateNotEmpty: InputState {
	@objc private(set) var composingBuffer: String = ""
	@objc private(set) var cursorIndex: UInt = 0

	@objc init(composingBuffer: String, cursorIndex: UInt) {
		self.composingBuffer = composingBuffer
		self.cursorIndex = cursorIndex
	}

	override var description: String {
		"<InputStateNotEmpty, composingBuffer:\(composingBuffer), cursorIndex:\(cursorIndex)>"
	}
}

/// Represents that the user is inputting text.
class InputStateInputting: InputStateNotEmpty {
	@objc var bpmfReading: String = ""
	@objc var bpmfReadingCursorIndex: UInt8 = 0
	@objc var poppedText: String = ""

	@objc override init(composingBuffer: String, cursorIndex: UInt) {
		super.init(composingBuffer: composingBuffer, cursorIndex: cursorIndex)
	}

	@objc var attributedString: NSAttributedString {
		let attributedSting = NSAttributedString(string: composingBuffer, attributes: [
			.underlineStyle: NSUnderlineStyle.single.rawValue,
			.markedClauseSegment: 0
		])
		return attributedSting
	}

	override var description: String {
		"<InputStateInputting, composingBuffer:\(composingBuffer), cursorIndex:\(cursorIndex), poppedText:\(poppedText)>"
	}
}

private let kMinMarkRangeLength = 2
private let kMaxMarkRangeLength = Preferences.maxCandidateLength

/// Represents that the user is marking a range in the composing buffer.
class InputStateMarking: InputStateNotEmpty {
	@objc private(set) var markerIndex: UInt
	@objc private(set) var markedRange: NSRange
	@objc var tooltip: String {

		if Preferences.phraseReplacementEnabled {
			return NSLocalizedString("⚠︎ Phrase replacement mode enabled, interfering user phrase entry.", comment: "")
		}

		if markedRange.length == 0 {
			return ""
		}

		let text = (composingBuffer as NSString).substring(with: markedRange)
		if markedRange.length < kMinMarkRangeLength {
			return String(format: NSLocalizedString("\"%@\" length must ≥ 2 for a user phrase.", comment: ""), text)
		} else if (markedRange.length > kMaxMarkRangeLength) {
			return String(format: NSLocalizedString("\"%@\" length should ≤ %d for a user phrase.", comment: ""), text, kMaxMarkRangeLength)
		}
		return String(format: NSLocalizedString("\"%@\" selected. ENTER to add user phrase.", comment: ""), text)
	}

	@objc private(set) var readings: [String] = []

	@objc init(composingBuffer: String, cursorIndex: UInt, markerIndex: UInt, readings: [String]) {
		self.markerIndex = markerIndex
		let begin = min(cursorIndex, markerIndex)
		let end = max(cursorIndex, markerIndex)
		markedRange = NSMakeRange(Int(begin), Int(end - begin))
		self.readings = readings
		super.init(composingBuffer: composingBuffer, cursorIndex: cursorIndex)
	}

	@objc var attributedString: NSAttributedString {
		let attributedSting = NSMutableAttributedString(string: composingBuffer)
		let end = markedRange.location + markedRange.length

		attributedSting.setAttributes([
			.underlineStyle: NSUnderlineStyle.single.rawValue,
			.markedClauseSegment: 0
		], range: NSRange(location: 0, length: markedRange.location))
		attributedSting.setAttributes([
			.underlineStyle: NSUnderlineStyle.thick.rawValue,
			.markedClauseSegment: 1
		], range: markedRange)
		attributedSting.setAttributes([
			.underlineStyle: NSUnderlineStyle.single.rawValue,
			.markedClauseSegment: 2
		], range: NSRange(location: end,
				length: composingBuffer.count - end))
		return attributedSting
	}

	override var description: String {
		"<InputStateMarking, composingBuffer:\(composingBuffer), cursorIndex:\(cursorIndex), markedRange:\(markedRange), readings:\(readings)>"
	}

	@objc func convertToInputting() -> InputStateInputting {
		let state = InputStateInputting(composingBuffer: composingBuffer, cursorIndex: cursorIndex)
		return state
	}

	@objc var validToWrite: Bool {
		markedRange.length >= kMinMarkRangeLength && markedRange.length <= kMaxMarkRangeLength
	}

	@objc var userPhrase: String {
		let text = (composingBuffer as NSString).substring(with: markedRange)
		let end = markedRange.location + markedRange.length
		let readings = readings[markedRange.location..<end]
		let joined = readings.joined(separator: "-")
		return "\(text) \(joined)"
	}
}

/// Represents that the user is choosing in a candidates list.
class InputStateChoosingCandidate: InputStateNotEmpty {
	@objc private(set) var candidates: [String] = []
	@objc private(set) var useVerticalMode: Bool = false

	@objc init(composingBuffer: String, cursorIndex: UInt, candidates: [String], useVerticalMode: Bool) {
		self.candidates = candidates
		self.useVerticalMode = useVerticalMode
		super.init(composingBuffer: composingBuffer, cursorIndex: cursorIndex)
	}

	@objc var attributedString: NSAttributedString {
		let attributedSting = NSAttributedString(string: composingBuffer, attributes: [
			.underlineStyle: NSUnderlineStyle.single.rawValue,
			.markedClauseSegment: 0
		])
		return attributedSting
	}

	override var description: String {
		"<InputStateChoosingCandidate, candidates:\(candidates), useVerticalMode:\(useVerticalMode), composingBuffer:\(composingBuffer), cursorIndex:\(cursorIndex)>"
	}
}
