// Copyright (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are (c) 2021 and onwards The vChewing Project (MIT-NTL License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
documentation files (the "Software"), to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and
to permit persons to whom the Software is furnished to do so, subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service marks, or product names of Contributor,
   except as required to fulfill notice requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
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

    /// Represents that the input controller is deactivated.
    @objc (InputStateDeactivated)
    class Deactivated: InputState {
        override var description: String {
            "<InputState.Deactivated>"
        }
    }

    // MARK: -

    /// Represents that the composing buffer is empty.
    @objc (InputStateEmpty)
    class Empty: InputState {
        @objc var composingBuffer: String {
            ""
        }

        override var description: String {
            "<InputState.Empty>"
        }
    }

    // MARK: -

    /// Represents that the composing buffer is empty.
    @objc (InputStateEmptyIgnoringPreviousState)
    class EmptyIgnoringPreviousState: InputState {
        @objc var composingBuffer: String {
            ""
        }
        override var description: String {
            "<InputState.EmptyIgnoringPreviousState>"
        }
    }

    // MARK: -

    /// Represents that the input controller is committing text into client app.
    @objc (InputStateCommitting)
    class Committing: InputState {
        @objc private(set) var poppedText: String = ""

        @objc convenience init(poppedText: String) {
            self.init()
            self.poppedText = poppedText
        }

        override var description: String {
            "<InputState.Committing poppedText:\(poppedText)>"
        }
    }

    // MARK: -

    /// Represents that the composing buffer is not empty.
    @objc (InputStateNotEmpty)
    class NotEmpty: InputState {
        @objc private(set) var composingBuffer: String
        @objc private(set) var cursorIndex: UInt

        @objc init(composingBuffer: String, cursorIndex: UInt) {
            self.composingBuffer = composingBuffer
            self.cursorIndex = cursorIndex
        }

        override var description: String {
            "<InputState.NotEmpty, composingBuffer:\(composingBuffer), cursorIndex:\(cursorIndex)>"
        }
    }

    // MARK: -

    /// Represents that the user is inputting text.
    @objc (InputStateInputting)
    class Inputting: NotEmpty {
        @objc var poppedText: String = ""
        @objc var tooltip: String = ""

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
            "<InputState.Inputting, composingBuffer:\(composingBuffer), cursorIndex:\(cursorIndex)>, poppedText:\(poppedText)>"
        }
    }

    // MARK: -

    private let kMinMarkRangeLength = 2
    private let kMaxMarkRangeLength = Preferences.maxCandidateLength

    /// Represents that the user is marking a range in the composing buffer.
    @objc (InputStateMarking)
    class Marking: NotEmpty {

        @objc private(set) var markerIndex: UInt
        @objc private(set) var markedRange: NSRange
        @objc var tooltip: String {

            if composingBuffer.count != readings.count {
                return NSLocalizedString("⚠︎ Unhandlable char selected for user phrases.", comment: "")
            }

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

            let (exactBegin, _) = (composingBuffer as NSString).characterIndex(from: markedRange.location)
            let (exactEnd, _) = (composingBuffer as NSString).characterIndex(from: markedRange.location + markedRange.length)
            let selectedReadings = readings[exactBegin..<exactEnd]
            let joined = selectedReadings.joined(separator: "-")
            let exist = mgrLangModel.checkIfUserPhraseExist(userPhrase: text, mode: ctlInputMethod.currentKeyHandler.inputMode, key: joined)
            if exist {
                return String(format: NSLocalizedString("\"%@\" already exists, ENTER to override its priority.", comment: ""), text)
            }

            return String(format: NSLocalizedString("\"%@\" selected. ENTER to add user phrase.", comment: ""), text)
        }

        @objc var tooltipForInputting: String = ""
        @objc private(set) var readings: [String]

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
                              length: (composingBuffer as NSString).length - end))
            return attributedSting
        }

        override var description: String {
            "<InputState.Marking, composingBuffer:\(composingBuffer), cursorIndex:\(cursorIndex), markedRange:\(markedRange)>"
        }

        @objc func convertToInputting() -> Inputting {
            let state = Inputting(composingBuffer: composingBuffer, cursorIndex: cursorIndex)
            state.tooltip = tooltipForInputting
            return state
        }

        @objc var validToWrite: Bool {
            /// vChewing allows users to input a string whose length differs
            /// from the amount of Bopomofo readings. In this case, the range
            /// in the composing buffer and the readings could not match, so
            /// we disable the function to write user phrases in this case.
            if composingBuffer.count != readings.count {
                return false
            }
            if  markedRange.length < kMinMarkRangeLength {
                return false
            }
            if markedRange.length > kMaxMarkRangeLength {
                return false
            }
            return markedRange.length >= kMinMarkRangeLength && markedRange.length <= kMaxMarkRangeLength
        }

        @objc var chkIfUserPhraseExists: Bool {
            let text = (composingBuffer as NSString).substring(with: markedRange)
            let (exactBegin, _) = (composingBuffer as NSString).characterIndex(from: markedRange.location)
            let (exactEnd, _) = (composingBuffer as NSString).characterIndex(from: markedRange.location + markedRange.length)
            let selectedReadings = readings[exactBegin..<exactEnd]
            let joined = selectedReadings.joined(separator: "-")
            return mgrLangModel.checkIfUserPhraseExist(userPhrase: text, mode: ctlInputMethod.currentKeyHandler.inputMode, key: joined) == true
        }

        @objc var userPhrase: String {
            let text = (composingBuffer as NSString).substring(with: markedRange)
            let (exactBegin, _) = (composingBuffer as NSString).characterIndex(from: markedRange.location)
            let (exactEnd, _) = (composingBuffer as NSString).characterIndex(from: markedRange.location + markedRange.length)
            let selectedReadings = readings[exactBegin..<exactEnd]
            let joined = selectedReadings.joined(separator: "-")
            return "\(text) \(joined)"
        }
    }

    // MARK: -

    /// Represents that the user is choosing in a candidates list.
    @objc (InputStateChoosingCandidate)
    class ChoosingCandidate: NotEmpty {
        @objc private(set) var candidates: [String]
        @objc private(set) var useVerticalMode: Bool

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
            "<InputState.ChoosingCandidate, candidates:\(candidates), useVerticalMode:\(useVerticalMode),  composingBuffer:\(composingBuffer), cursorIndex:\(cursorIndex)>"
        }
    }

    // MARK: -

    /// Represents that the user is choosing in a candidates list
    /// in the associated phrases mode.
    @objc (InputStateAssociatedPhrases)
    class AssociatedPhrases: InputState {
        @objc private(set) var candidates: [String] = []
        @objc private(set) var useVerticalMode: Bool = false
        @objc init(candidates: [String], useVerticalMode: Bool) {
            self.candidates = candidates
            self.useVerticalMode = useVerticalMode
            super.init()
        }

        override var description: String {
            "<InputState.AssociatedPhrases, candidates:\(candidates), useVerticalMode:\(useVerticalMode)>"
        }
    }

    @objc (InputStateSymbolTable)
    class SymbolTable: ChoosingCandidate {
        @objc var node: SymbolNode

        @objc init(node: SymbolNode, useVerticalMode: Bool) {
            self.node = node
            let candidates = node.children?.map { $0.title } ?? [String]()
            super.init(composingBuffer: "", cursorIndex: 0, candidates: candidates, useVerticalMode: useVerticalMode)
        }

        override var description: String {
            "<InputState.SymbolTable, candidates:\(candidates), useVerticalMode:\(useVerticalMode),  composingBuffer:\(composingBuffer), cursorIndex:\(cursorIndex)>"
        }
    }

}

@objc class SymbolNode: NSObject {
    @objc var title: String
    @objc var children: [SymbolNode]?

    @objc init(_ title: String, _ children: [SymbolNode]? = nil) {
        self.title = title
        self.children = children
        super.init()
    }

    @objc init(_ title: String, symbols: String) {
        self.title = title
        self.children = Array(symbols).map { SymbolNode(String($0), nil) }
        super.init()
    }

    @objc static let catCommonSymbols = String(format: NSLocalizedString("catCommonSymbols", comment: ""))
    @objc static let catHoriBrackets = String(format: NSLocalizedString("catHoriBrackets", comment: ""))
    @objc static let catVertBrackets = String(format: NSLocalizedString("catVertBrackets", comment: ""))
    @objc static let catGreekLetters = String(format: NSLocalizedString("catGreekLetters", comment: ""))
    @objc static let catMathSymbols = String(format: NSLocalizedString("catMathSymbols", comment: ""))
    @objc static let catCurrencyUnits = String(format: NSLocalizedString("catCurrencyUnits", comment: ""))
    @objc static let catSpecialSymbols = String(format: NSLocalizedString("catSpecialSymbols", comment: ""))
    @objc static let catUnicodeSymbols = String(format: NSLocalizedString("catUnicodeSymbols", comment: ""))
    @objc static let catCircledKanjis = String(format: NSLocalizedString("catCircledKanjis", comment: ""))
    @objc static let catCircledKataKana = String(format: NSLocalizedString("catCircledKataKana", comment: ""))
    @objc static let catBracketKanjis = String(format: NSLocalizedString("catBracketKanjis", comment: ""))
    @objc static let catSingleTableLines = String(format: NSLocalizedString("catSingleTableLines", comment: ""))
    @objc static let catDoubleTableLines = String(format: NSLocalizedString("catDoubleTableLines", comment: ""))
    @objc static let catFillingBlocks = String(format: NSLocalizedString("catFillingBlocks", comment: ""))
    @objc static let catLineSegments = String(format: NSLocalizedString("catLineSegments", comment: ""))
    
    @objc static let root: SymbolNode = SymbolNode("/", [
        SymbolNode("｀"),
        SymbolNode(catCommonSymbols, symbols:"，、。．？！；：‧‥﹐﹒˙·‘’“”〝〞‵′〃～＄％＠＆＃＊"),
        SymbolNode(catHoriBrackets, symbols:"（）「」〔〕｛｝〈〉『』《》【】﹙﹚﹝﹞﹛﹜"),
        SymbolNode(catVertBrackets, symbols:"︵︶﹁﹂︹︺︷︸︿﹀﹃﹄︽︾︻︼"),
        SymbolNode(catGreekLetters, symbols:"αβγδεζηθικλμνξοπρστυφχψωΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩ"),
        SymbolNode(catMathSymbols, symbols:"＋－×÷＝≠≒∞±√＜＞﹤﹥≦≧∩∪ˇ⊥∠∟⊿㏒㏑∫∮∵∴╳﹢"),
        SymbolNode(catCurrencyUnits, symbols:"$€¥¢£₽₨₩฿₺₮₱₭₴₦৲৳૱௹﷼₹₲₪₡₫៛₵₢₸₤₳₥₠₣₰₧₯₶₷"),
        SymbolNode(catSpecialSymbols, symbols:"↑↓←→↖↗↙↘↺⇧⇩⇦⇨⇄⇆⇅⇵↻◎○●⊕⊙※△▲☆★◇◆□■▽▼§￥〒￠￡♀♂↯"),
        SymbolNode(catUnicodeSymbols, symbols:"♨☀☁☂☃♠♥♣♦♩♪♫♬☺☻"),
        SymbolNode(catCircledKanjis, symbols:"㊟㊞㊚㊛㊊㊋㊌㊍㊎㊏㊐㊑㊒㊓㊔㊕㊖㊗︎㊘㊙︎㊜㊝㊠㊡㊢㊣㊤㊥㊦㊧㊨㊩㊪㊫㊬㊭㊮㊯㊰🈚︎🈯︎"),
        SymbolNode(catCircledKataKana, symbols:"㋐㋑㋒㋓㋔㋕㋖㋗㋘㋙㋚㋛㋜㋝㋞㋟㋠㋡㋢㋣㋤㋥㋦㋧㋨㋩㋪㋫㋬㋭㋮㋯㋰㋱㋲㋳㋴㋵㋶㋷㋸㋹㋺㋻㋼㋾"),
        SymbolNode(catBracketKanjis, symbols:"㈪㈫㈬㈭㈮㈯㈰㈱㈲㈳㈴㈵㈶㈷㈸㈹㈺㈻㈼㈽㈾㈿㉀㉁㉂㉃"),
        SymbolNode(catSingleTableLines, symbols:"├─┼┴┬┤┌┐╞═╪╡│▕└┘╭╮╰╯"),
        SymbolNode(catDoubleTableLines, symbols:"╔╦╗╠═╬╣╓╥╖╒╤╕║╚╩╝╟╫╢╙╨╜╞╪╡╘╧╛"),
        SymbolNode(catFillingBlocks, symbols:"＿ˍ▁▂▃▄▅▆▇█▏▎▍▌▋▊▉◢◣◥◤"),
        SymbolNode(catLineSegments, symbols:"﹣﹦≡｜∣∥–︱—︳╴¯￣﹉﹊﹍﹎﹋﹌﹏︴∕﹨╱╲／＼"),
    ])
}
