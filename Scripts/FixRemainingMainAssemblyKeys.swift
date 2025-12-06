#!/usr/bin/env swift

import Foundation

let mapping: [String: String] = [
  "i18n:MainAssembly.debugMode": "i18n:Settings.Option.debugMode",
  "i18n:MainAssembly.defaultsWriteOrgAtelierinmuInputmethodVchewingCassettepathStringFilepathendedwithouttrailingslash": "i18n:Settings.TerminalCommand.cassettePath",
  "i18n:MainAssembly.defaultsWriteOrgAtelierinmuInputmethodVchewingUserdatafolderspecifiedStringFolderpathendedwithtrailingslash": "i18n:Settings.TerminalCommand.userDataFolder",
  "i18n:MainAssembly.enableCassetteModeSuppressingPhonabetInput": "i18n:Settings.Description.enableCassetteModeSuppressingPhonabetInput",
  "i18n:MainAssembly.exampleInitialRestphraseInitialRestphrase1Restphrase2Restphrase3": "i18n:UI.Example.initialRestPhraseInitialRestPhrase1RestPhrase2RestPhrase3",
  "i18n:MainAssembly.exampleOldphraseNewphraseComment": "i18n:UI.Example.oldPhraseNewPhraseComment",
  "i18n:MainAssembly.experimental": "i18n:UI.Label.experimental",
  "i18n:MainAssembly.forExampleWhenTyping章太炎AndYouWantToOverrideThe太With泰AndTheRawOperationIndexRange12WhichBoundsAreCuttingTheCurrentNode章太炎InRange03IfHavingLackOfThePreConsolidationProcessThisWordWillBecomeSomethingLike張泰言AfterTheCandidateSelectionOnlyIfWeEnableThisConsolidationThisWordWillBecome章泰炎WhichIsTheExpectedResultThatTheContextIsKeptAsIs": "i18n:Settings.Help.consolidationExample",
  "i18n:MainAssembly.hardenVerticalPunctuationsDuringVerticalTypingNotRecommended": "i18n:Settings.Description.hardenVerticalPunctuationsDuringVerticalTypingNotRecommended",
  "i18n:MainAssembly.holdToChooseAssociates": "i18n:UI.Label.holdToChooseAssociates",
  "i18n:MainAssembly.ifNotFillingTheWeightItWillBe00TheMaximumOneAnIdealWeightSituatesIn950MakingItselfCanBeCapturedByTheSentenceCompositionAlgorithmTheExceptionIs114514TheDisciplinaryWeightTheSentenceCompositionAlgorithmWillIgnoreItUnlessItIsTheUniqueResult": "i18n:UI.Help.weightExplanation",
  "i18n:MainAssembly.ifUncheckedTheEscKeyWillTryCleaningTheUnfinishedReadingsStrokesFirstAndWillCommitTheCurrentCompositionBufferIfThereSNoUnfinishedReadingsStrokes": "i18n:Settings.Help.escKeyBehavior",
  "i18n:MainAssembly.imemenuTotalramusedLabelheader": "i18n:Menu.totalRamUsedLabelHeader",
  "i18n:MainAssembly.newVersionAvailable": "i18n:UpdateCheck.newVersionAvailable",
  "i18n:MainAssembly.pleaseCheckThePermissionAt:%@": "i18n:Error.pleaseCheckThePermissionAt:%@",
  "i18n:MainAssembly.someClientsWithWebBasedFrontUiMayHaveIssuesRenderingSegmentedThickUnderlinesDrawnByTheirImplementedSetmarkedtextThisOptionStopsTheInputMethodFromDeliveringSegmentedThickUnderlinesToClientSetmarkedtextNoteThatSegmentedThickUnderlinesAreOnlyUsedInMarkingModeUnlessTheClientItselfMisimplementsTheImktextinputMethodSetmarkedtextThisOptionOnlyAffectsTheInlineCompositionBuffer": "i18n:Settings.Help.someClientsWithWebBasedFrontUiMayHaveIssuesRenderingSegmentedThickUnderlinesDrawnByTheirImplementedSetmarkedtextThisOptionStopsTheInputMethodFromDeliveringSegmentedThickUnderlinesToClientSetmarkedtextNoteThingSegmentedThickUnderlinesAreOnlyUsedInMarkingModeUnlessTheClientItselfMisimplementsTheImktextinputMethodSetmarkedtextThisOptionOnlyAffectsTheInlineCompositionBuffer",
  "i18n:MainAssembly.space": "i18n:UI.Label.space",
  "i18n:MainAssembly.tadokoroCandidateWindowShows4RowsColumnsByDefaultProvidingSimilarExperiencesFromMicrosoftNewPhoneticImeAndMacosBultInChineseImeSinceMacos109HoweverForSomeUsersWhoHavePresbyopiaTheyPreferGiantCandidateFontSizesResultingAConcernThatMultipleRowsColumnsOfCandidatesCanMakeTheCandidateWindowLooksTooBigHenceThisOptionNoteThatThisOptionWillBeDismissedIfTheTypingContextIsVerticalForcingTheCandidatesToBeShownInOnlyOneRowColumnOnlyOneReverseLookupResultCanBeMadeAvailableInSingleRowColumnModeDueToReducedCandidateWindowSize": "i18n:Settings.Help.tadokoroCandidateWindowShows4RowsColumnsByDefaultProvidingSimilarExperiencesFromMicrosoftNewPhoneticImeAndMacosBultInChineseImeSinceMacos109HoweverForSomeUsersWhoHavePresbyopiaTheyPreferGiantCandidateFontSizesResultingAConcernThatMultipleRowsColumnsOfCandidatesCanMakeTheCandidateWindowLooksTooBigHenceThisOptionNoteThishisOptionWillBeDismissedIfTheTypingContextIsVerticalForcingTheCandidatesToBeShownInOnlyOneRowColumnOnlyOneReverseLookupResultCanBeMadeAvailableInSingleRowColumnModeDueToReducedCandidateWindowSize",
  "i18n:MainAssembly.theassociates": "i18n:UI.Label.theAssociates",
  "i18n:MainAssembly.theEndOfSupportForImkCandidateWindow": "i18n:Settings.Warning.theEndOfSupportForImkCandidateWindow",
  "i18n:MainAssembly.thefilter": "i18n:UI.Label.theFilter",
  "i18n:MainAssembly.thephrases": "i18n:UI.Label.thePhrases",
  "i18n:MainAssembly.thereMayBeNoInternetConnectionOrTheServerFailedToRespondErrorMessage:%@": "i18n:Error.thereMayBeNoInternetConnectionOrTheServerFailedToRespondErrorMessage:%@",
  "i18n:MainAssembly.thereplacements": "i18n:UI.Label.theReplacements",
  "i18n:MainAssembly.thesymbols": "i18n:UI.Label.theSymbols",
  "i18n:MainAssembly.thisFeatureRequiresMacosAndAbove:%@": "i18n:Settings.Help.thisFeatureRequiresMacosAndAbove:%@",
  "i18n:MainAssembly.typingmethodRomannumeralsErrorInvalidcharacter": "i18n:TypingMethod.RomanNumerals.Error.InvalidCharacter",
  "i18n:MainAssembly.typingmethodRomannumeralsErrorInvalidinput": "i18n:TypingMethod.RomanNumerals.Error.InvalidInput",
  "i18n:MainAssembly.typingmethodRomannumeralsErrorValueoutofrange": "i18n:TypingMethod.RomanNumerals.Error.ValueOutOfRange",
  "i18n:MainAssembly.typingmethodRomannumeralsTooltip": "i18n:TypingMethod.RomanNumerals.Tooltip",
  "i18n:MainAssembly.updateCheckCompleted": "i18n:UpdateCheck.completed",
  "i18n:MainAssembly.updateCheckFailed": "i18n:UpdateCheck.failed",
  "i18n:MainAssembly.userPhraseFolderPathIsNotCustomizableInMacos1091012": "i18n:Settings.Help.userPhraseFolderPathIsNotCustomizableInMacos109Til1012",
  "i18n:MainAssembly.vchewing": "i18n:UI.Label.vChewing",
  "i18n:MainAssembly.warningThisPageIsForTestingFutureFeaturesFeaturesListedHereMayNotWorkAsExpected": "i18n:Settings.Warning.thisPageIsForTestingFutureFeaturesNFeaturesListedHereMayNotWorkAsExpected",
  "i18n:MainAssembly.whereSImkCandidateWindow": "i18n:UI.Label.whereIsImkCandidateWindow",
  "i18n:MainAssembly.youReCurrentlyUsingVchewingANewVersionIsNowAvailableDoYouWantToVisitVchewingSWebsiteToDownloadTheVersion:%@": "i18n:UpdateCheck.youReCurrentlyUsingVchewingANewVersionIsNowAvailableDoYouWantToVisitVchewingSWebsiteToDownloadTheVersion:%@:%@:%@:%@",
]

extension String {
  var unescaped: String {
    var output = ""
    var iterator = makeIterator()
    while let char = iterator.next() {
      if char == "\\" {
        guard let next = iterator.next() else { break }
        switch next {
        case "\\": output.append("\\")
        case "\"": output.append("\"")
        case "n": output.append("\n")
        case "r": output.append("\r")
        case "t": output.append("\t")
        default: output.append(next)
        }
      } else {
        output.append(char)
      }
    }
    return output
  }
  
  var escaped: String {
    var result = ""
    for char in self {
      switch char {
      case "\\": result.append("\\\\")
      case "\"": result.append("\\\"")
      case "\n": result.append("\\n")
      case "\r": result.append("\\r")
      case "\t": result.append("\\t")
      default: result.append(char)
      }
    }
    return result
  }
}

let cwd = FileManager.default.currentDirectoryPath
let baseURL = URL(fileURLWithPath: cwd)
let regex = try NSRegularExpression(
  pattern: "^\\s*\"(?<key>(?:\\\\.|[^\\\\\"\\r\\n])*)\"\\s*=\\s*\"(?<value>(?:\\\\.|[^\\\\\"\\r\\n])*)\";\\s*$",
  options: [.anchorsMatchLines]
)

func rewriteStrings(at url: URL) throws {
  let raw = try String(contentsOf: url, encoding: .utf8)
  let lines = raw.split(separator: "\n", omittingEmptySubsequences: false)
  
  let rewritten = lines.map { line -> String in
    let lineStr = String(line)
    let ns = NSString(string: lineStr)
    let range = NSRange(location: 0, length: ns.length)
    
    guard let match = regex.firstMatch(in: lineStr, options: [], range: range) else {
      return lineStr
    }
    
    guard
      let keyRange = Range(match.range(withName: "key"), in: lineStr),
      let valueRange = Range(match.range(withName: "value"), in: lineStr)
    else {
      return lineStr
    }
    
    let rawKey = String(lineStr[keyRange])
    let unescapedKey = rawKey.unescaped
    let newKey = mapping[unescapedKey] ?? unescapedKey
    let value = String(lineStr[valueRange])
    
    return "\"\(newKey.escaped)\" = \"\(value)\";"
  }
  
  try rewritten.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
}

let localeRoot = baseURL.appendingPathComponent("Source/Resources")
let fileManager = FileManager.default
let localeDirs = try fileManager.contentsOfDirectory(atPath: localeRoot.path).filter { $0.hasSuffix(".lproj") }

for dir in localeDirs {
  let fileURL = localeRoot.appendingPathComponent(dir).appendingPathComponent("Localizable.strings")
  guard fileManager.fileExists(atPath: fileURL.path) else { continue }
  
  print("Processing \(dir)...")
  try rewriteStrings(at: fileURL)
}

print("\n✓ Fixed remaining \(mapping.count) MainAssembly keys")
