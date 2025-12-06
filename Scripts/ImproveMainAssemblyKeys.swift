#!/usr/bin/env swift

// Script to improve MainAssembly key names with better context

import Foundation

let mapping: [String: String] = [
  // Settings descriptions and options
  "i18n:MainAssembly.acceptLeadingIntonationsInRareCases": "i18n:Settings.Description.acceptLeadingIntonationsInRareCases",
  "i18n:MainAssembly.adjustCandidateWindowLocationAccordingToCurrentNodeLength": "i18n:Settings.Description.adjustCandidateWindowLocationAccordingToCurrentNodeLength",
  "i18n:MainAssembly.allowBackspaceEditingMiscomposedReadings": "i18n:Settings.Description.allowBackspaceEditingMiscomposedReadings",
  "i18n:MainAssembly.allowBoostingExcludingACandidateOfSingleKanjiWhenMarking": "i18n:Settings.Description.allowBoostingExcludingACandidateOfSingleKanjiWhenMarking",
  "i18n:MainAssembly.allowUsingEnterKeyToConfirmAssociatedCandidateSelection": "i18n:Settings.Description.allowUsingEnterKeyToConfirmAssociatedCandidateSelection",
  "i18n:MainAssembly.alwaysDirectlyCommitLowercasedLetters": "i18n:Settings.Description.alwaysDirectlyCommitLowercasedLetters",
  "i18n:MainAssembly.alwaysDirectlyCommitUppercasedLetters": "i18n:Settings.Description.alwaysDirectlyCommitUppercasedLetters",
  "i18n:MainAssembly.alwaysDropThePreviousReading": "i18n:Settings.Description.alwaysDropThePreviousReading",
  "i18n:MainAssembly.alwaysExpandCandidateWindowPanel": "i18n:Settings.Description.alwaysExpandCandidateWindowPanel",
  "i18n:MainAssembly.alwaysShowTooltipTextsHorizontally": "i18n:Settings.Description.alwaysShowTooltipTextsHorizontally",
  "i18n:MainAssembly.alwaysTypeIntonationsToTheInlineCompositionBuffer": "i18n:Settings.Description.alwaysTypeIntonationsToTheInlineCompositionBuffer",
  "i18n:MainAssembly.alwaysUseFixedListingOrderInCandidateWindow": "i18n:Settings.Description.alwaysUseFixedListingOrderInCandidateWindow",
  "i18n:MainAssembly.anAccommodationForElderComputerUsers": "i18n:Settings.Description.anAccommodationForElderComputerUsers",
  "i18n:MainAssembly.autoCompositeWhenTheLongestPossibleKeyIsFormed": "i18n:Settings.Description.autoCompositeWhenTheLongestPossibleKeyIsFormed",
  "i18n:MainAssembly.autoConvertTraditionalChineseGlyphsToJisShinjitaiCharacters": "i18n:Settings.Description.autoConvertTraditionalChineseGlyphsToJisShinjitaiCharacters",
  "i18n:MainAssembly.autoConvertTraditionalChineseGlyphsToKangxiCharacters": "i18n:Settings.Description.autoConvertTraditionalChineseGlyphsToKangxiCharacters",
  "i18n:MainAssembly.automaticallyCorrectReadingCombinationsWhenTyping": "i18n:Settings.Description.automaticallyCorrectReadingCombinationsWhenTyping",
  "i18n:MainAssembly.automaticallyReloadUserDataFilesIfChangesDetected": "i18n:Settings.Description.automaticallyReloadUserDataFilesIfChangesDetected",
  "i18n:MainAssembly.auto": "i18n:Settings.Option.followSystemSettings",
  
  // Candidate window and selection
  "i18n:MainAssembly.candidateKeysCanOnlyContainPrintableAsciiCharactersLikeAlphanumericals": "i18n:Settings.Validation.candidateKeysCanOnlyContainPrintableAsciiCharactersLikeAlphanumericals",
  "i18n:MainAssembly.candidateKeysCannotContainSpace": "i18n:Settings.Validation.candidateKeysCannotContainSpace",
  "i18n:MainAssembly.chooseCandidateFontSizeForBetterVisualClarity": "i18n:Settings.Help.chooseCandidateFontSizeForBetterVisualClarity",
  "i18n:MainAssembly.chooseOrHitEnterToConfimYourPreferedKeysForSelectingCandidates": "i18n:Settings.Help.chooseOrHitEnterToConfimYourPreferedKeysForSelectingCandidates",
  "i18n:MainAssembly.chooseTheCursorPositionWhereYouWantToListPossibleCandidates": "i18n:Settings.Help.chooseTheCursorPositionWhereYouWantToListPossibleCandidates",
  "i18n:MainAssembly.chooseYourPreferredLayoutOfTheCandidateWindow": "i18n:Settings.Help.chooseYourPreferredLayoutOfTheCandidateWindow",
  
  // Keyboard and input settings
  "i18n:MainAssembly.chooseTheBehaviorOfShiftLetterKeyWithLetterInputs": "i18n:Settings.Help.chooseTheBehaviorOfShiftLetterKeyWithLetterInputs",
  "i18n:MainAssembly.chooseTheBehaviorOfShiftSpaceKeyWithCandidates": "i18n:Settings.Help.chooseTheBehaviorOfShiftSpaceKeyWithCandidates",
  "i18n:MainAssembly.chooseTheBehaviorOfShiftTabKeyInTheCandidateWindow": "i18n:Settings.Help.chooseTheBehaviorOfShiftTabKeyInTheCandidateWindow",
  "i18n:MainAssembly.chooseTheMacosLevelAlphanumericalKeyboardLayoutThisSettingIsForShiftToggledAlphanumericalModeOnly": "i18n:Settings.Help.chooseTheMacosLevelAlphanumericalKeyboardLayoutThisSettingIsForShiftToggledAlphanumericalModeOnly",
  "i18n:MainAssembly.chooseThePhoneticLayoutForMandarinParser": "i18n:Settings.Help.chooseThePhoneticLayoutForMandarinParser",
  "i18n:MainAssembly.completelyDisableUsingShiftKeyToToggleAlphanumericalMode": "i18n:Settings.Description.completelyDisableUsingShiftKeyToToggleAlphanumericalMode",
  
  // File and folder paths
  "i18n:MainAssembly.chooseTheTargetApplicationBundle": "i18n:Settings.Help.chooseTheTargetApplicationBundle",
  "i18n:MainAssembly.chooseYourDesiredCassetteFilePathWillBeOmittedIfInvalid": "i18n:Settings.Help.chooseYourDesiredCassetteFilePathWillBeOmittedIfInvalid",
  "i18n:MainAssembly.chooseYourDesiredUserDataFolder": "i18n:Settings.Help.chooseYourDesiredUserDataFolder",
  "i18n:MainAssembly.chooseYourDesiredUserDataFolderPathWillBeOmittedIfInvalid": "i18n:Settings.Help.chooseYourDesiredUserDataFolderPathWillBeOmittedIfInvalid",
  
  // Menu items
  "i18n:MainAssembly.clearMemorizedPhrases": "i18n:Menu.ClearMemorizedPhrases",
  "i18n:MainAssembly.clientManager": "i18n:Menu.ClientManager",
  
  // UI labels
  "i18n:MainAssembly.comment": "i18n:UI.Label.comment",
  "i18n:MainAssembly.consolidate": "i18n:UI.Label.consolidate",
  "i18n:MainAssembly.charReadingS": "i18n:UI.Label.charReadingS",
  "i18n:MainAssembly.cheatsheet": "i18n:UI.Label.cheatSheet",
  
  // Status and notification messages
  "i18n:MainAssembly.checkForUpdateCompleted": "i18n:Notification.checkForUpdateCompleted",
  "i18n:MainAssembly.checkForUpdatesAutomatically": "i18n:Settings.Description.checkForUpdatesAutomatically",
  "i18n:MainAssembly.changeUserInterfaceLanguageWillRebootTheIme": "i18n:Settings.Help.changeUserInterfaceLanguageWillRebootTheIme",
  "i18n:MainAssembly.clearTheEntireInlineCompositionBufferLikeShiftDelete": "i18n:Settings.Help.clearTheEntireInlineCompositionBufferLikeShiftDelete",
  
  // Cassette mode
  "i18n:MainAssembly.cassetteModeIsSimilarToTheCinSupportOfTheYahooKeykeyImeAllowingUsersToUseTheirOwnCinTablesToImplementTheirStrokedBasedInputSchemaEGWubiCangjieBoshiamyEtcAsAPlanBInVchewingImeHoweverSinceVchewingWonTCompromiseItsPhonabetInputModeExperienceForThisCassetteModeUsersMightNotFeelComfortableEnoughComparingToTheirExperiencesWithRimeRecommendedOrOpenvanillaDeprecated": "i18n:Settings.Help.cassetteMode",
  
  // Consolidation
  "i18n:MainAssembly.consolidateTheContextOnConfirmingCandidateSelection": "i18n:Settings.Description.consolidateTheContextOnConfirmingCandidateSelection",
  
  // Core dictionary
  "i18n:MainAssembly.coreDictLoadingComplete": "i18n:Loading.coreDictComplete",
  
  // Default commands
  "i18n:MainAssembly.defaultsWriteOrgAtelierinmuInputmethodVchewingCassettePathStringFilePathEndedWithoutTrailingSlash": "i18n:Settings.TerminalCommand.cassettePath",
  "i18n:MainAssembly.defaultsWriteOrgAtelierinmuInputmethodVchewingUserDataFolderSpecifiedStringFolderPathEndedWithTrailingSlash": "i18n:Settings.TerminalCommand.userDataFolder",
  
  // Descriptions
  "i18n:MainAssembly.directlyCommitLowercasedLettersOnlyIfTheCompositorIsEmpty": "i18n:Settings.Description.directlyCommitLowercasedLettersOnlyIfTheCompositorIsEmpty",
  "i18n:MainAssembly.directlyCommitUppercasedLettersOnlyIfTheCompositorIsEmpty": "i18n:Settings.Description.directlyCommitUppercasedLettersOnlyIfTheCompositorIsEmpty",
  "i18n:MainAssembly.disableForcedConversionForCassetteOutputs": "i18n:Settings.Description.disableForcedConversionForCassetteOutputs",
  "i18n:MainAssembly.disableSegmentedThickUnderlineInMarkingModeForManagedClients": "i18n:Settings.Description.disableSegmentedThickUnderlineInMarkingModeForManagedClients",
  "i18n:MainAssembly.disassembleThePreviousReadingDroppingItsIntonation": "i18n:Settings.Description.disassembleThePreviousReadingDroppingItsIntonation",
  "i18n:MainAssembly.disassemblingProcessDoesNotWorkWithNonPhoneticReadingKeys": "i18n:Settings.Help.disassemblingProcessDoesNotWorkWithNonPhoneticReadingKeys",
  
  // Dialogs
  "i18n:MainAssembly.doYouWantToEnableThePopupCompositionBufferForThisClient": "i18n:Dialog.doYouWantToEnableThePopupCompositionBufferForThisClient",
  "i18n:MainAssembly.dueToSecurityConcernsWeDonTConsiderImplementingAnythingRelatedToShellScriptExecutionHereAnInputMethodDoingThisWithoutImplementingAppSandboxWillDefinitelyHaveSystemWideVulnerabilitiesConsideringThatItsRelatedUserdefaultsAreEasilyTamperableToExecuteMaliciousShellScriptsVchewingIsDesignedToBeInvulnerableFromThisKindOfAttackAlsoOfficialReleasesOfVchewingAreSandboxed": "i18n:Settings.Help.securityConcernsAboutShellScriptExecution",
  
  // Edit menus
  "i18n:MainAssembly.editAssociatedPhrases": "i18n:Menu.EditAssociatedPhrases",
  "i18n:MainAssembly.editExcludedPhrases": "i18n:Menu.EditExcludedPhrases",
  "i18n:MainAssembly.editPhraseReplacementTable": "i18n:Menu.EditPhraseReplacementTable",
  "i18n:MainAssembly.editUserSymbolEmojiData": "i18n:Menu.EditUserSymbolEmojiData",
  "i18n:MainAssembly.editVchewingUserPhrases": "i18n:Menu.EditVchewingUserPhrases",
  "i18n:MainAssembly.edit": "i18n:Menu.Edit",
  
  // Emulation
  "i18n:MainAssembly.emulatingSelectCandidatePerCharacterMode": "i18n:Settings.Description.emulatingSelectCandidatePerCharacterMode",
  "i18n:MainAssembly.enableCassetteModeSupPressingPhonabetInput": "i18n:Settings.Description.enableCassetteModeSupPressingPhonabetInput",
  "i18n:MainAssembly.enableExperimentalSwiftUiTypesettingMethod": "i18n:Settings.Description.enableExperimentalSwiftUiTypesettingMethod",
  "i18n:MainAssembly.enableMouseWheelSupportForTadokoroCandidateWindow": "i18n:Settings.Description.enableMouseWheelSupportForTadokoroCandidateWindow",
  "i18n:MainAssembly.enablePhraseReplacementTable": "i18n:Settings.Description.enablePhraseReplacementTable",
  "i18n:MainAssembly.enableSpaceKeyForCallingCandidateWindow": "i18n:Settings.Description.enableSpaceKeyForCallingCandidateWindow",
  "i18n:MainAssembly.enableSymbolInputSupportInclCertainEmojiSymbols": "i18n:Settings.Description.enableSymbolInputSupportInclCertainEmojiSymbols",
  "i18n:MainAssembly.enforceConversionInBothInputModes": "i18n:Settings.Description.enforceConversionInBothInputModes",
  
  // Examples
  "i18n:MainAssembly.exampleCandidateReadingReadingComment": "i18n:UI.Example.candidateReadingReadingComment",
  "i18n:MainAssembly.exampleCandidateReadingReadingWeightCommentCandidateReadingReadingComment": "i18n:UI.Example.candidateReadingReadingWeightCommentCandidateReadingReadingComment",
  "i18n:MainAssembly.exampleInitialRestPhraseInitialRestPhrase1RestPhrase2RestPhrase3": "i18n:UI.Example.initialRestPhraseInitialRestPhrase1RestPhrase2RestPhrase3",
  "i18n:MainAssembly.exampleOldPhraseNewPhraseComment": "i18n:UI.Example.oldPhraseNewPhraseComment",
  
  // Factory dictionary
  "i18n:MainAssembly.factoryDictionaryNotLoadedYet": "i18n:Error.factoryDictionaryNotLoadedYet",
  "i18n:MainAssembly.followOsSettings": "i18n:Settings.Option.followOsSettings",
  
  // Explanations
  "i18n:MainAssembly.forExampleWhenTypingAndYouWantToOverrideTheWithAndTheRawOperationIndexRange12WhichBoundsAreCuttingTheCurrentNodeInRange03IfHavingLackOfThePreConsolidationProcessThisWordWillBecomeSomethingLikeAfterTheCandidateSelectionOnlyIfWeEnableThisConsolidationThisWordWillBecomeWhichIsTheExpectedResultThatTheContextIsKeptAsIs": "i18n:Settings.Help.consolidationExample",
  "i18n:MainAssembly.forRevolvingCandidates": "i18n:Settings.Option.forRevolvingCandidates",
  "i18n:MainAssembly.forRevolvingPages": "i18n:Settings.Option.forRevolvingPages",
  
  // Horizontal
  "i18n:MainAssembly.horizontal": "i18n:UI.Option.horizontal",
  "i18n:MainAssembly.howToFill": "i18n:UI.Label.howToFill",
  
  // if conditions
  "i18n:MainAssembly.ifDisabledThisWillInsertSpaceInstead": "i18n:Settings.Help.ifDisabledThisWillInsertSpaceInstead",
  "i18n:MainAssembly.ifNotFillingTheWeightItWillBe00TheMaximumOneAnIdealWeightSituatesIn950MakingItselfCanBeCapturedByTheSentenceCompositionAlgorithmTheExceptionIs11451 4TheDisciplinaryWeightTheSentenceCompositionAlgorithmWillIgnoreItUnlessItIsTheUniqueResult": "i18n:UI.Help.weightExplanation",
  "i18n:MainAssembly.ifUncheckedTheEscKeyWillTryCleaningTheUnfinishedReadingsStrokesFirstAndWillCommitTheCurrentCompositionBufferIfThereS NoUnfinishedReadingsStrokes": "i18n:Settings.Help.escKeyBehavior",
  
  // Inline comments
  "i18n:MainAssembly.inlineCommentsAreNotSupportedInAssociatedPhrases": "i18n:UI.Help.inlineCommentsAreNotSupportedInAssociatedPhrases",
  "i18n:MainAssembly.intonationMarkEnterToCommitSpaceToInsertIntoCompositionBuffer": "i18n:UI.Tooltip.intonationMarkEnterToCommitSpaceToInsertIntoCompositionBuffer",
  
  // Initial
  "i18n:MainAssembly.initial": "i18n:UI.Label.initial",
  
  // In front of / at the rear of
  "i18n:MainAssembly.inFrontOfThePhraseLikeMacosBuiltInZhuyinIme": "i18n:Settings.Option.inFrontOfThePhraseLikeMacosBuiltInZhuyinIme",
  "i18n:MainAssembly.atTheRearOfThePhraseLikeMicrosoftNewPhonetic": "i18n:Settings.Option.atTheRearOfThePhraseLikeMicrosoftNewPhonetic",
  
  // It will attempt
  "i18n:MainAssembly.itWillAttemptToCombineWithTheIncomingPhonabetInput": "i18n:Settings.Help.itWillAttemptToCombineWithTheIncomingPhonabetInput",
  
  // Just select
  "i18n:MainAssembly.justSelect": "i18n:UI.Option.justSelect",
  
  // Key names
  "i18n:MainAssembly.keyNamesInTooltipWillBeShownAsSymbolsWhenTheTooltipIsVerticalHoweverThisOptionWillBeIgnoredSinceTooltipWillAlwaysBeHorizontalIfTheUiLanguageIsEnglish": "i18n:Settings.Help.keyNamesInTooltipWillBeShownAsSymbolsWhenTheTooltipIsVerticalHoweverThisOptionWillBeIgnoredSinceTooltipWillAlwaysBeHorizontalIfTheUiLanguageIsEnglish",
  
  // Leave it checked
  "i18n:MainAssembly.leaveItChecked": "i18n:Settings.Help.leaveItChecked",
  
  // Loading
  "i18n:MainAssembly.loadingChsCoreDict": "i18n:Loading.chsCoreDict",
  "i18n:MainAssembly.loadingChtCoreDict": "i18n:Loading.chtCoreDict",
  
  // Maximum/Minimum
  "i18n:MainAssembly.maximum10CandidateKeysAllowed": "i18n:Settings.Validation.maximum10CandidateKeysAllowed",
  "i18n:MainAssembly.maximum15ResultsReturnable": "i18n:Settings.Validation.maximum15ResultsReturnable",
  "i18n:MainAssembly.minimum6CandidateKeysAllowed": "i18n:Settings.Validation.minimum6CandidateKeysAllowed",
  
  // Note
  "i18n:MainAssembly.noteTheDeleteKeyOnMacKeyboardIsNamedAsBackspaceHereInOrderToDistinguishTheRealDeleteKeyFromFullSizedDesktopKeyboardsIfYouWantToUseTheRealDeleteKeyOnAMacKeyboardWithNoNumpadEquippedYouHaveToPressFnInstead": "i18n:Settings.Help.noteAboutDeleteKey",
  
  // Only enforce
  "i18n:MainAssembly.onlyEnforceConversionInSimplifiedChineseMode": "i18n:Settings.Option.onlyEnforceConversionInSimplifiedChineseMode",
  "i18n:MainAssembly.onlyEnforceConversionInTraditionalChineseMode": "i18n:Settings.Option.onlyEnforceConversionInTraditionalChineseMode",
  "i18n:MainAssembly.onlyLoadFactoryLanguageModelsIfNeeded": "i18n:Settings.Description.onlyLoadFactoryLanguageModelsIfNeeded",
  "i18n:MainAssembly.onlyOverrideTheIntonationOfThePreviousReadingIfDifferent": "i18n:Settings.Description.onlyOverrideTheIntonationOfThePreviousReadingIfDifferent",
  
  // One record per line
  "i18n:MainAssembly.oneRecordPerLineUseOptionEnterToBreakLinesBlankLinesWillBeDismissed": "i18n:UI.Help.oneRecordPerLineUseOptionEnterToBreakLinesBlankLinesWillBeDismissed",
  
  // Open folders
  "i18n:MainAssembly.openUserDictionaryFolder": "i18n:Menu.OpenUserDictionaryFolder",
  
  // Optimize
  "i18n:MainAssembly.optimizeMemorizedPhrases": "i18n:Menu.OptimizeMemorizedPhrases",
  
  // Otherwise
  "i18n:MainAssembly.otherwiseOnlyTheCandidateKeysAreAllowedToConfirmAssociates": "i18n:Settings.Help.otherwiseOnlyTheCandidateKeysAreAllowedToConfirmAssociates",
  
  // Override
  "i18n:MainAssembly.overrideThePreviousReadingSIntonationWithCandidateReset": "i18n:Settings.Description.overrideThePreviousReadingSIntonationWithCandidateReset",
  
  // Phrase
  "i18n:MainAssembly.phrase": "i18n:UI.Label.phrase",
  "i18n:MainAssembly.phraseReplacementModeEnabledInterferingUserPhraseEntry": "i18n:Warning.phraseReplacementModeEnabledInterferingUserPhraseEntry",
  
  // Please
  "i18n:MainAssembly.pleaseCheckThePermissionAt": "i18n:Error.pleaseCheckThePermissionAt:%@",
  "i18n:MainAssembly.pleaseDragTheAppsIntoTheClientManagerWindowFromFinder": "i18n:UI.Help.pleaseDragTheAppsIntoTheClientManagerWindowFromFinder",
  "i18n:MainAssembly.pleaseDragTheDesiredTargetFromFinderToThisPlace": "i18n:UI.Help.pleaseDragTheDesiredTargetFromFinderToThisPlace",
  "i18n:MainAssembly.pleaseEnterTheClientAppBundleIdentifierSYouWantToRegister": "i18n:UI.Help.pleaseEnterTheClientAppBundleIdentifierSYouWantToRegister",
  "i18n:MainAssembly.pleaseManageTheListOfThoseClientsHereWhichAre1ImktextinputIncompatible2SuspectedFromAbusingTheContentsOfTheInlineCompositionBufferAClientListedHereIfCheckedWillUsePopupCompositionBufferWithMaximum20ReadingCountsHoldable": "i18n:UI.Help.pleaseManageTheListOfThoseClientsHereWhichAre1ImktextinputIncompatible2SuspectedFromAbusingTheContentsOfTheInlineCompositionBufferAClientListedHereIfCheckedWillUsePopupCompositionBufferWithMaximum20ReadingCountsHoldable",
  "i18n:MainAssembly.pleaseManuallyEnterTheIdentifierS": "i18n:UI.Help.pleaseManuallyEnterTheIdentifierS",
  "i18n:MainAssembly.pleaseManuallyImplementTheSymbolsOfThisMenuInTheUserPhraseFileWithPunctuationListKey": "i18n:UI.Help.pleaseManuallyImplementTheSymbolsOfThisMenuInTheUserPhraseFileWithPunctuationListKey",
  "i18n:MainAssembly.pleaseSelectSimplifiedTraditionalChineseModeAbove": "i18n:UI.Help.pleaseSelectSimplifiedTraditionalChineseModeAbove",
  "i18n:MainAssembly.pleaseSelect": "i18n:UI.Label.pleaseSelect",
  "i18n:MainAssembly.pleaseTryAgain": "i18n:UI.Message.pleaseTryAgain",
  "i18n:MainAssembly.pleaseUseDefaultsWriteTerminalCommandToModifyThisStringValue": "i18n:Settings.Help.pleaseUseDefaultsWriteTerminalCommandToModifyThisStringValue",
  "i18n:MainAssembly.pleaseUseMouseWheelToScrollEachPageIfNeededTheCheatsheetIsAvailableInTheImeMenu": "i18n:UI.Help.pleaseUseMouseWheelToScrollEachPageIfNeededTheCheatsheetIsAvailableInTheImeMenu",
  "i18n:MainAssembly.pleaseUseMouseWheelToScrollThisPageTheCheatsheetIsAvailableInTheImeMenu": "i18n:UI.Help.pleaseUseMouseWheelToScrollThisPageTheCheatsheetIsAvailableInTheImeMenu",
  
  // Plist
  "i18n:MainAssembly.plistDownloadedCannotBeParsedCorrectly": "i18n:Error.plistDownloadedCannotBeParsedCorrectly",
  "i18n:MainAssembly.plistDownloadedIsNil": "i18n:Error.plistDownloadedIsNil",
  
  // Previous intonation
  "i18n:MainAssembly.previousIntonationHasBeenOverridden": "i18n:Notification.previousIntonationHasBeenOverridden",
  
  // Push cursor
  "i18n:MainAssembly.pushTheCursorInFrontOfThePhraseAfterSelection": "i18n:Settings.Description.pushTheCursorInFrontOfThePhraseAfterSelection",
  
  // Quick candidates
  "i18n:MainAssembly.quickCandidates": "i18n:UI.Label.quickCandidates",
  
  // Read external
  "i18n:MainAssembly.readExternalFactoryDictionaryFilesIfPossible": "i18n:Settings.Description.readExternalFactoryDictionaryFilesIfPossible",
  "i18n:MainAssembly.readingStroke": "i18n:UI.Label.readingStroke",
  
  // Reload
  "i18n:MainAssembly.reloadUserPhrases": "i18n:Menu.ReloadUserPhrases",
  "i18n:MainAssembly.replaceTo": "i18n:UI.Label.replaceTo",
  
  // Reverse lookup
  "i18n:MainAssembly.reverseLookupPhonabets": "i18n:Menu.ReverseLookupPhonabets",
  
  // Security harden
  "i18n:MainAssembly.securityHardenTheCompositionBufferForAllClients": "i18n:Settings.Description.securityHardenTheCompositionBufferForAllClients",
  
  // Share alphanumerical
  "i18n:MainAssembly.shareAlphanumericalModeStatusAcrossAllClients": "i18n:Settings.Description.shareAlphanumericalModeStatusAcrossAllClients",
  
  // Shift+BackSpace/Letter/Space
  "i18n:MainAssembly.shiftBackspace": "i18n:Settings.Label.shiftBackspace",
  "i18n:MainAssembly.shiftLetter": "i18n:Settings.Label.shiftLetter",
  "i18n:MainAssembly.shiftSpace": "i18n:Settings.Label.shiftSpace",
  
  // Show
  "i18n:MainAssembly.showAvailableReverseLookupResultsInCandidateWindow": "i18n:Settings.Description.showAvailableReverseLookupResultsInCandidateWindow",
  "i18n:MainAssembly.showHanyuPinyinInTheInlineCompositionBuffer": "i18n:Settings.Description.showHanyuPinyinInTheInlineCompositionBuffer",
  "i18n:MainAssembly.showNotificationsWhenTogglingCapsLock": "i18n:Settings.Description.showNotificationsWhenTogglingCapsLock",
  "i18n:MainAssembly.showTranslatedStrokesInCompositionBuffer": "i18n:Settings.Description.showTranslatedStrokesInCompositionBuffer",
  
  // Some client apps
  "i18n:MainAssembly.someClientAppsMayHaveDifferentCompatibilityIssuesInImktextinputImplementation": "i18n:Settings.Help.someClientAppsMayHaveDifferentCompatibilityIssuesInImktextinputImplementation",
  "i18n:MainAssembly.someClientsWithWebBasedFrontUiMayHaveIssuesRenderingSegmentedThickUnderlinesDrawnByTheirImplementedSetmarkedtextThisOptionStopsTheInputMethodFromDeliveringSegmentedThickUnderlinesToClientSetmarkedtextNoteThingSegmentedThickUnderlinesAreOnlyUsedInMarkingModeUnlessTheClientItselfMisimplementsTheImktextinputMethodSetmarkedtextThisOptionOnlyAffectsTheInlineCompositionBuffer": "i18n:Settings.Help.someClientsWithWebBasedFrontUiMayHaveIssuesRenderingSegmentedThickUnderlinesDrawnByTheirImplementedSetmarkedtextThisOptionStopsTheInputMethodFromDeliveringSegmentedThickUnderlinesToClientSetmarkedtextNoteThingSegmentedThickUnderlinesAreOnlyUsedInMarkingModeUnlessTheClientItselfMisimplementsTheImktextinputMethodSetmarkedtextThisOptionOnlyAffectsTheInlineCompositionBuffer",
  "i18n:MainAssembly.someFeaturesAreUnavailableForMacos1015AndMacos11DueToApiLimitations": "i18n:Settings.Help.someFeaturesAreUnavailableForMacos1015AndMacos11DueToApiLimitations",
  "i18n:MainAssembly.somePreviousOptionsAreMovedToOtherTabs": "i18n:Settings.Help.somePreviousOptionsAreMovedToOtherTabs",
  
  // Space options
  "i18n:MainAssembly.spaceToRevolveCandidatesShiftSpaceToRevolvePages": "i18n:Settings.Option.spaceToRevolveCandidatesShiftSpaceToRevolvePages",
  "i18n:MainAssembly.spaceToRevolvePagesShiftSpaceToRevolveCandidates": "i18n:Settings.Option.spaceToRevolvePagesShiftSpaceToRevolveCandidates",
  
  // Specify
  "i18n:MainAssembly.specifyTheBehaviorOfIntonationKeyWhenSyllableComposerIsEmpty": "i18n:Settings.Help.specifyTheBehaviorOfIntonationKeyWhenSyllableComposerIsEmpty",
  
  // Stop farting
  "i18n:MainAssembly.stopFartingWhenTypedPhoneticCombinationIsInvalidEtc": "i18n:Settings.Description.stopFartingWhenTypedPhoneticCombinationIsInvalidEtc",
  
  // Tadokoro
  "i18n:MainAssembly.tadokoroCandidateWindowShows4RowsColumnsByDefaultProvidingSimilarExperiencesFromMicrosoftNewPhoneticImeAndMacosBultInChineseImeSinceMacos109HoweverForSomeUsersWhoHavePresbyopiaTheyPreferGiantCandidateFontSizesResultingAConcernThatMultipleRowsColumnsOfCandidatesCanMakeTheCandidateWindowLooksTooBigHenceThisOptionNoteThishisOptionWillBeDismissedIfTheTypingContextIsVerticalForcingTheCandidatesToBeShownInOnlyOneRowColumnOnlyOneReverseLookupResultCanBeMadeAvailableInSingleRowColumnModeDueToReducedCandidateWindowSize": "i18n:Settings.Help.tadokoroCandidateWindowShows4RowsColumnsByDefaultProvidingSimilarExperiencesFromMicrosoftNewPhoneticImeAndMacosBultInChineseImeSinceMacos109HoweverForSomeUsersWhoHavePresbyopiaTheyPreferGiantCandidateFontSizesResultingAConcernThatMultipleRowsColumnsOfCandidatesCanMakeTheCandidateWindowLooksTooBigHenceThisOptionNoteThishisOptionWillBeDismissedIfTheTypingContextIsVerticalForcingTheCandidatesToBeShownInOnlyOneRowColumnOnlyOneReverseLookupResultCanBeMadeAvailableInSingleRowColumnModeDueToReducedCandidateWindowSize",
  
  // Technical reason
  "i18n:MainAssembly.technicalReasonMacosReleasesEarlierThan1013HaveAnIssueIfCallingNsopenpanelDirectlyFromAnInputMethodBothTheInputMethodAndItsCurrentClientAppHangInADeadLoopFurthermoreItMakesOtherAppsHangInTheSameWayWhenYouSwitchIntoAnotherAppIfYouDonTWantToHardRebootYourComputerYourLastResortIsToUseSshToConnectToYourCurrentComputerFromAnotherComputerAndKillTheInputMethodProcessByTerminalCommandsThatSWhyVchewingCannotOfferAccessToNsopenpanelForMacos1012AndEarlier": "i18n:Settings.Help.technicalReasonMacosReleasesEarlierThan1013HaveAnIssueIfCallingNsopenpanelDirectlyFromAnInputMethodBothTheInputMethodAndItsCurrentClientAppHangInADeadLoopFurthermoreItMakesOtherAppsHangInTheSameWayWhenYouSwitchIntoAnotherAppIfYouDonTWantToHardRebootYourComputerYourLastResortIsToUseSshToConnectToYourCurrentComputerFromAnotherComputerAndKillTheInputMethodProcessByTerminalCommandsThatSWhyVchewingCannotOfferAccessToNsopenpanelForMacos1012AndEarlier",
  
  // The lookup results
  "i18n:MainAssembly.theLookupResultsAreSuppliedByTheCinCassetteModule": "i18n:UI.Message.theLookupResultsAreSuppliedByTheCinCassetteModule",
  
  // The selected item
  "i18n:MainAssembly.theSelectedItemIsEitherNotAValidMacosApplicationBundleOrNotHavingAValidAppBundleIdentifier": "i18n:Error.theSelectedItemIsEitherNotAValidMacosApplicationBundleOrNotHavingAValidAppBundleIdentifier",
  "i18n:MainAssembly.theSelectedItemSIdentifierIsAlreadyInTheList": "i18n:Error.theSelectedItemSIdentifierIsAlreadyInTheList",
  
  // The user override model
  "i18n:MainAssembly.theUserOverrideModelOnlyPossessesMemoriesTemporarilyEachMemoryRecordGraduallyBecomesIneffectiveWithinApproximatelyLessThan6DaysYouCanEraseAllMemoryRecordsThroughTheInputMethodMenu": "i18n:Settings.Help.theUserOverrideModelOnlyPossessesMemoriesTemporarilyEachMemoryRecordGraduallyBecomesIneffectiveWithinApproximatelyLessThan6DaysYouCanEraseAllMemoryRecordsThroughTheInputMethodMenu",
  
  // There is a bug
  "i18n:MainAssembly.thereIsABugInMacos109PreventingAnInputMethodFromAccessingItsOwnFilePanelsDoingSoWillResultInEternalHangCrashOfNotOnlyTheInputMethodButAllClientAppsItTriesAttachedToRequiringSshConnectionToThisComputerToTerminateTheInputMethodProcessByExecutingKillallVchewingDueToPossibleConcernsOfTheSamePossibleIssueInMacos1010And1011WeCompletelyDisabledThisFeature": "i18n:Settings.Help.thereIsABugInMacos109PreventingAnInputMethodFromAccessingItsOwnFilePanelsDoingSoWillResultInEternalHangCrashOfNotOnlyTheInputMethodButAllClientAppsItTriesAttachedToRequiringSshConnectionToThisComputerToTerminateTheInputMethodProcessByExecutingKillallVchewingDueToPossibleConcernsOfTheSamePossibleIssueInMacos1010And1011WeCompletelyDisabledThisFeature",
  
  // There may be
  "i18n:MainAssembly.thereMayBeNoInternetConnectionOrTheServerFailedToRespondErrorMessage": "i18n:Error.thereMayBeNoInternetConnectionOrTheServerFailedToRespondErrorMessage:%@",
  
  // This conversion
  "i18n:MainAssembly.thisConversionOnlyAffectsTheCassetteModuleConvertingTypedContentsToEitherSimplifiedChineseOrTraditionalChineseInAccordanceWithThisSettingAndYourCurrentInputMode": "i18n:Settings.Help.thisConversionOnlyAffectsTheCassetteModuleConvertingTypedContentsToEitherSimplifiedChineseOrTraditionalChineseInAccordanceWithThisSettingAndYourCurrentInputMode",
  
  // This editor only
  "i18n:MainAssembly.thisEditorOnlyAutoReloadModificationsHappenedOutsideOfThisEditor": "i18n:Settings.Description.thisEditorOnlyAutoReloadModificationsHappenedOutsideOfThisEditor",
  
  // This feature
  "i18n:MainAssembly.thisFeatureAccommodatesCertainTypingMistakesThatTheIntonationMarkMightBeTypedAtFirstWhichIsSequentiallyWrongFromACommonSenseThatIntonationMarksAreSupposedToBeUsedForConfirmingCombinationsItWonTWorkIfTheCurrentParserIsOfAnyPinyinAlsoThisFeatureWonTWorkWhenAnIntonationOverrideIsPossibleAndEnabled": "i18n:Settings.Help.thisFeatureAccommodatesCertainTypingMistakesThatTheIntonationMarkMightBeTypedAtFirstWhichIsSequentiallyWrongFromACommonSenseThatIntonationMarksAreSupposedToBeUsedForConfirmingCombinationsItWonTWorkIfTheCurrentParserIsOfAnyPinyinAlsoThisFeatureWonTWorkWhenAnIntonationOverrideIsPossibleAndEnabled",
  "i18n:MainAssembly.thisFeatureIsUsefulOnlyWhenTheFontYouAreUsingDoesnTSupportDynamicVerticalPunctuationsHoweverTypedVerticalPunctuationsWillAlwaysShownAsVerticalPunctuationsEvenIfYourEditorHasChangedTheTypingDirectionToHorizontal": "i18n:Warning.thisFeatureIsUsefulOnlyWhenTheFontYouAreUsingDoesnTSupportDynamicVerticalPunctuationsHoweverTypedVerticalPunctuationsWillAlwaysShownAsVerticalPunctuationsEvenIfYourEditorHasChangedTheTypingDirectionToHorizontal",
  "i18n:MainAssembly.thisFeatureRequiresMacosAndAbove": "i18n:Settings.Help.thisFeatureRequiresMacosAndAbove:%@",
  
  // This hinders
  "i18n:MainAssembly.thisHindersAllClientAppsFromUnwelcomelyAccessingYourUncommittedContentsInTheCompositionBufferAPopupCompositionBufferWillBeShownInstead": "i18n:Settings.Help.thisHindersAllClientAppsFromUnwelcomelyAccessingYourUncommittedContentsInTheCompositionBufferAPopupCompositionBufferWillBeShownInstead",
  
  // This may hinder
  "i18n:MainAssembly.thisMayHinderTheSentenceCompositionAlgorithmFromGivingAppropriateResults": "i18n:Warning.thisMayHinderTheSentenceCompositionAlgorithmFromGivingAppropriateResults",
  
  // This only works
  "i18n:MainAssembly.thisOnlyWorksWhenBeingToggledByShiftKeyAndJisEisuKey": "i18n:Settings.Help.thisOnlyWorksWhenBeingToggledByShiftKeyAndJisEisuKey",
  "i18n:MainAssembly.thisOnlyWorksWithTadokoroCandidateWindow": "i18n:Settings.Help.thisOnlyWorksWithTadokoroCandidateWindow",
  
  // This update
  "i18n:MainAssembly.thisUpdateWillUpgradeVchewingFromAquaSpecialEditionToMainstreamReleaseRecommendedForYourCurrentOsVersion": "i18n:UpdateCheck.thisUpdateWillUpgradeVchewingFromAquaSpecialEditionToMainstreamReleaseRecommendedForYourCurrentOsVersion",
  
  // This will
  "i18n:MainAssembly.thisWillAlsoAffectTheRowColumnCapacityOfTheCandidateWindow": "i18n:Settings.Help.thisWillAlsoAffectTheRowColumnCapacityOfTheCandidateWindow",
  "i18n:MainAssembly.thisWillBatchReplaceSpecifiedCandidates": "i18n:UI.Help.thisWillBatchReplaceSpecifiedCandidates",
  "i18n:MainAssembly.thisWillRebootTheVchewingIme": "i18n:Warning.thisWillRebootTheVchewingIme",
  "i18n:MainAssembly.thisWillRemoveVchewingInputMethodFromThisUserAccountRequiringYourConfirmation": "i18n:Dialog.thisWillRemoveVchewingInputMethodFromThisUserAccountRequiringYourConfirmation",
  "i18n:MainAssembly.thisWillStopUserOverrideModelFromAffectingHowCandidatesGetSorted": "i18n:Settings.Help.thisWillStopUserOverrideModelFromAffectingHowCandidatesGetSorted",
  "i18n:MainAssembly.thisWillUseTheSqliteDatabaseDeployedByTheMakeInstallCommandFromLibvchewingDataIfPossible": "i18n:Settings.Help.thisWillUseTheSqliteDatabaseDeployedByTheMakeInstallCommandFromLibvchewingDataIfPossible",
  
  // Toggle
  "i18n:MainAssembly.toggleAlphanumericalModeWithLeftShift": "i18n:Settings.Description.toggleAlphanumericalModeWithLeftShift",
  "i18n:MainAssembly.toggleAlphanumericalModeWithRightShift": "i18n:Settings.Description.toggleAlphanumericalModeWithRightShift",
  
  // Trim unfinished
  "i18n:MainAssembly.trimUnfinishedReadingsStrokesOnCommit": "i18n:Settings.Description.trimUnfinishedReadingsStrokesOnCommit",
  
  // Type them
  "i18n:MainAssembly.typeThemIntoInlineCompositionBuffer": "i18n:Settings.Option.typeThemIntoInlineCompositionBuffer",
  
  // Unable
  "i18n:MainAssembly.unableToCreateTheUserPhraseFile": "i18n:Error.unableToCreateTheUserPhraseFile",
  "i18n:MainAssembly.uncheck": "i18n:UI.Button.uncheck",
  
  // Unhandlable
  "i18n:MainAssembly.unhandlableCharsAndReadingsInBufferDoesnTMatch": "i18n:Error.unhandlableCharsAndReadingsInBufferDoesnTMatch",
  
  // Uninstallation
  "i18n:MainAssembly.uninstallation": "i18n:Dialog.uninstallation",
  
  // Use ESC key
  "i18n:MainAssembly.useEscKeyToClearTheEntireInputBuffer": "i18n:Settings.Description.useEscKeyToClearTheEntireInputBuffer",
  "i18n:MainAssembly.useOnlyOneRowColumnInCandidateWindow": "i18n:Settings.Description.useOnlyOneRowColumnInCandidateWindow",
  "i18n:MainAssembly.usePhraseReplacement": "i18n:TypingMode.PhraseReplacement",
  "i18n:MainAssembly.useSpaceToConfirmHighlightedCandidateInPerCharSelectMode": "i18n:Settings.Description.useSpaceToConfirmHighlightedCandidateInPerCharSelectMode",
  
  // User phrase folder
  "i18n:MainAssembly.userPhraseFolderPathIsNotCustomizableInMacos109Til1012": "i18n:Settings.Help.userPhraseFolderPathIsNotCustomizableInMacos109Til1012",
  
  // vChewing crashed
  "i18n:MainAssembly.vchewingCrashedWhileHandlingPreviouslyLoadedPomObservationDataTheseDataFilesAreCleanedNowToEnsureTheUsability": "i18n:Error.vchewingCrashedWhileHandlingPreviouslyLoadedPomObservationDataTheseDataFilesAreCleanedNowToEnsureTheUsability",
  
  // vChewing is rebooted
  "i18n:MainAssembly.vchewingIsRebootedDueToAMemoryExcessiveUsageProblemIfConvenientPleaseInformTheDeveloperThatYouAreHavingThisIssueStatingWhetherYouAreUsingAnIntelMacOrAppleSiliconMacAnNslogIsGeneratedWithTheCurrentMemoryFootprintSize": "i18n:Error.vchewingIsRebootedDueToAMemoryExcessiveUsageProblemIfConvenientPleaseInformTheDeveloperThatYouAreHavingThisIssueStatingWhetherYouAreUsingAnIntelMacOrAppleSiliconMacAnNslogIsGeneratedWithTheCurrentMemoryFootprintSize",
  
  // Vertical
  "i18n:MainAssembly.vertical": "i18n:UI.Option.vertical",
  
  // Warning
  "i18n:MainAssembly.warningThisPageIsForTestingFutureFeaturesNFeaturesListedHereMayNotWorkAsExpected": "i18n:Settings.Warning.thisPageIsForTestingFutureFeaturesNFeaturesListedHereMayNotWorkAsExpected",
  "i18n:MainAssembly.warning": "i18n:Dialog.warning",
  
  // Weight
  "i18n:MainAssembly.weight": "i18n:UI.Label.weight",
  
  // Wildcard
  "i18n:MainAssembly.wildcardKeyCannotBeTheInitialKey": "i18n:Settings.Validation.wildcardKeyCannotBeTheInitialKey",
  
  // You are about
  "i18n:MainAssembly.youAreAboutToUncheckThisFartSuppressorYouAreResponsibleForAllConsequencesLeadByLettingPeopleNearbyHearTheFartSoundComeFromYourComputerWeStronglyAdviseAgainstUncheckingThisInAnyPublicCircumstanceThatProhibitsNsfwNetas": "i18n:Settings.Warning.youAreAboutToUncheckThisFartSuppressorYouAreResponsibleForAllConsequencesLeadByLettingPeopleNearbyHearTheFartSoundComeFromYourComputerWeStronglyAdviseAgainstUncheckingThisInAnyPublicCircumstanceThatProhibitsNsfwNetas",
  "i18n:MainAssembly.youAreAlreadyUsingTheLatestVersionOfVchewing": "i18n:UpdateCheck.youAreAlreadyUsingTheLatestVersionOfVchewing",
  "i18n:MainAssembly.youAreAlreadyUsingTheLatestVersion": "i18n:UpdateCheck.youAreAlreadyUsingTheLatestVersion",
  "i18n:MainAssembly.youAreProceedingToSystemPreferencesToEnableTheInputSourceWhichCorrespondsToTheInputModeYouAreGoingToSwitchTo": "i18n:Dialog.youAreProceedingToSystemPreferencesToEnableTheInputSourceWhichCorrespondsToTheInputModeYouAreGoingToSwitchTo",
  "i18n:MainAssembly.youMayFollow": "i18n:UI.Label.youMayFollow",
  "i18n:MainAssembly.youReCurrentlyUsingVchewingANewVersionIsNowAvailableDoYouWantToVisitVchewingSWebsiteToDownloadTheVersion": "i18n:UpdateCheck.youReCurrentlyUsingVchewingANewVersionIsNowAvailableDoYouWantToVisitVchewingSWebsiteToDownloadTheVersion:%@:%@:%@:%@",
  
  // IMKCandidates explanation
  "i18n:MainAssembly.1OnlyMacosHasImkcandidatesSinceItReliesOnADedicatedObjcBridgingHeaderToExposeNecessaryInternalApisToWorkItHindersVchewingFromCompletelyModularizedForMultiPlatformSupport2ImkcandidatesIsBuggyItIsNotLikelyToBeCompletelyFixedByAppleAndItsDevsAreNotAllowedToTalkAboutItToNonAppleIndividualsThatSWhyWeHaveHadEnoughWithImkcandidatesItIsLikelyTheReasonWhyAppleHadNeverUsedImkcandidatesInTheirOfficialInputmethodkitSampleProjectsAsOfAugust2023": "i18n:UI.Help.imkCandidatesExplanation",
  
  // Apple Zhuyin layouts that don't match actual Apple names
  "i18n:MainAssembly.appleZhuyinEtenTraditional": "i18n:KeyboardLayout.AppleZhuyinEten",
  "i18n:MainAssembly.applyingTypingSuggestionsFromPerceptionOverrideModel": "i18n:Settings.Description.applyingTypingSuggestionsFromPerceptionOverrideModel",
  
  // Alvin Liu
  "i18n:MainAssembly.alvinLiuImitative": "i18n:Settings.Option.alvinLiuImitative",
  
  // All strokes
  "i18n:MainAssembly.allStrokesInTheCompositionBufferWillBeShownAsAsciiKeyboardCharactersUnlessThisOptionIsEnabledStrokeIsDefinableInTheKeynameSectionOfTheCinFile": "i18n:Settings.Help.allStrokesInTheCompositionBufferWillBeShownAsAsciiKeyboardCharactersUnlessThisOptionIsEnabledStrokeIsDefinableInTheKeynameSectionOfTheCinFile",
  
  // Choose the macOS-level basic keyboard layout
  "i18n:MainAssembly.chooseTheMacosLevelBasicKeyboardLayoutNonQwertyAlphanumericalKeyboardLayoutsAreForPinyinParserOnlyThisOptionWillOnlyAffectTheAppearanceOfTheOnScreenKeyboardIfTheCurrentMandarinParserIsNeitherAnyPinyinNorDynamicallyReparsableWithDifferentWesternKeyboardLayoutsLikeEten26HsuEtc": "i18n:Settings.Help.chooseTheMacosLevelBasicKeyboardLayoutNonQwertyAlphanumericalKeyboardLayoutsAreForPinyinParserOnlyThisOptionWillOnlyAffectTheAppearanceOfTheOnScreenKeyboardIfTheCurrentMandarinParserIsNeitherAnyPinyinNorDynamicallyReparsableWithDifferentWesternKeyboardLayoutsLikeEten26HsuEtc",
]

print("Mapping \(mapping.count) keys...")

// Apply mapping
let cwd = FileManager.default.currentDirectoryPath
let baseURL = URL(fileURLWithPath: cwd)
let localeRoot = baseURL.appendingPathComponent("Source/Resources")
let fileManager = FileManager.default

let regex = try NSRegularExpression(
  pattern: "^\\s*\"(?<key>(?:\\\\.|[^\\\\\"\\r\\n])*)\"\\s*=\\s*\"(?<value>(?:\\\\.|[^\\\\\"\\r\\n])*)\";\\s*$",
  options: [.anchorsMatchLines]
)

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

let localeDirs = try fileManager.contentsOfDirectory(atPath: localeRoot.path)
  .filter { $0.hasSuffix(".lproj") }

for dir in localeDirs {
  let fileURL = localeRoot.appendingPathComponent(dir).appendingPathComponent("Localizable.strings")
  guard fileManager.fileExists(atPath: fileURL.path) else { continue }
  
  print("Processing \(dir)...")
  try rewriteStrings(at: fileURL)
}

print("\n✓ Successfully improved MainAssembly key names")
print("✓ Processed \(localeDirs.count) locale files")
