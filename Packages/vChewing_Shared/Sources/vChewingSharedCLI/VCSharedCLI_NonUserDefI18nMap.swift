// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// MARK: - Phase 75: Non-UserDef bare English → i18n: key mapping

/// Explicit mapping table for i18n keys that are **not** part of the `UserDef` system.
///
/// Unlike `UserDef.i18nKeyConvMapTotal` (which uses `Mirror` to automatically derive
/// old→new key pairs from `MetaData` fields), these keys have no programmatic
/// relationship between their old bare‑English form and their new `i18n:` form.
/// They must be mapped explicitly.
///
/// Keys are the **actual unescaped** string values (as they appear in Swift code).
/// The CLI uses `escapeForLiteralSearch(_:)` to match them in `.strings` files and
/// Swift source code.
enum NonUserDefI18nMap {
  /// `[bareEnglishOldValue: newI18nKey]`
  static let keyMap: [String: String] = [
    // MARK: - StatusMessage (39 keys)

    "- Succeeded in nerfing a candidate.": "i18n:PhraseOperation.NerfCandidateSucceeded",
    "- Succeeded in nerfing a user phrase.": "i18n:PhraseOperation.NerfUserPhraseSucceeded",
    "- Succeeded in unfiltering a phrase.": "i18n:PhraseOperation.UnfilterPhraseSucceeded",
    "! Succeeded in filtering a candidate.": "i18n:PhraseOperation.FilterCandidateSucceeded",
    "! Succeeded in filtering a user phrase.": "i18n:PhraseOperation.FilterUserPhraseSucceeded",
    "+ Succeeded in adding / boosting a user phrase.": "i18n:PhraseOperation.AddBoostUserPhraseSucceeded",
    "+ Succeeded in boosting a candidate.": "i18n:PhraseOperation.BoostCandidateSucceeded",
    "⚠︎ Failed from boosting a candidate.": "i18n:PhraseOperation.BoostCandidateFailed",
    "⚠︎ Failed from filtering a candidate.": "i18n:PhraseOperation.FilterCandidateFailed",
    "⚠︎ Failed from nerfing a candidate.": "i18n:PhraseOperation.NerfCandidateFailed",
    "⚠︎ Phrase replacement mode enabled, interfering user phrase entry.": "i18n:PhraseOperation.PhraseReplacementInterfering",
    "⚠︎ This will reboot the vChewing IME.": "i18n:StateOfInputting.Tooltip.RebootWarning",
    "⚠︎ Unhandlable: Chars and Readings in buffer doesn't match.": "i18n:StateOfInputting.Tooltip.CharsReadingsMismatch",
    "Factory dictionary not loaded yet.": "i18n:DictionaryStatus.FactoryDictNotLoaded",
    "Loading CHS Core Dict...": "i18n:DictionaryStatus.LoadingCHSCoreDict",
    "Loading CHT Core Dict...": "i18n:DictionaryStatus.LoadingCHTCoreDict",
    "Loading complete.": "i18n:DictionaryStatus.LoadingComplete",
    "Loading…": "i18n:DictionaryStatus.Loading",
    "New Version Available": "i18n:UpdateNotification.NewVersionAvailable",
    "Previous intonation has been overridden.": "i18n:StateOfInputting.Tooltip.PreviousIntonationOverridden",
    "Check for Update Completed": "i18n:UpdateNotification.CheckForUpdateCompleted",
    "Update Check Completed": "i18n:UpdateNotification.UpdateCheckCompleted",
    "Update Check Failed": "i18n:UpdateNotification.UpdateCheckFailed",
    "NotificationSwitchOFF": "i18n:NotificationSwitch.Off",
    "NotificationSwitchON": "i18n:NotificationSwitch.On",
    "NotificationSwitchRevolver": "i18n:NotificationSwitch.Revolver",
    "Quick Candidates": "i18n:StateOfInputting.Tooltip.QuickCandidates",
    "Switch to %@ Input Mode": "i18n:InputMode.SwitchToInputMode:%@",
    "Target Input Mode Activation Required": "i18n:InputMode.TargetInputModeActivationRequired",
    "\"%@\" already exists:\n ENTER to boost, SHIFT+COMMAND+ENTER to nerf, \n BackSpace or Delete key to exclude.": "i18n:StateOfMarking.Tooltip.PhraseExistsBoostNerfExclude:%@",
    "\"%@\" already exists:\n ENTER to boost, SHIFT+COMMAND+ENTER to nerf.": "i18n:StateOfMarking.Tooltip.PhraseExistsBoostNerf:%@",
    "\"%@\" length must ≥ 2 for a user phrase.": "i18n:StateOfMarking.Tooltip.PhraseLengthTooShort:%@",
    "\"%@\" length should ≤ %d for a user phrase.": "i18n:StateOfMarking.Tooltip.PhraseLengthTooLong:%@%d",
    "\"%@\" selected. ENTER to add user phrase.": "i18n:StateOfMarking.Tooltip.SelectedEnterToAdd:%@",
    "\"%@\" selected. ENTER to unfilter this phrase.": "i18n:StateOfMarking.Tooltip.SelectedEnterToUnfilter:%@",
    "%@-Stroke": "i18n:StateOfInputting.Tooltip.StrokeFormat:%@",
    "Intonation mark. ENTER to commit.\nSPACE to insert into composition buffer.": "i18n:StateOfInputting.Tooltip.IntonationMarkInstruction",
    "It will attempt to combine with the incoming phonabet input.": "i18n:StateOfInputting.Tooltip.AttemptCombinePhonabet",
    "Hold ⇧ to choose associates.": "i18n:StateOfInputting.Tooltip.HoldShiftChooseAssociates",

    // MARK: - Menu (29 keys)

    "About vChewing…": "i18n:Menu.AboutVChewing",
    "Alphanumerical Input Mode": "i18n:Menu.AlphanumericalInputMode",
    "Check for Updates…": "i18n:Menu.CheckForUpdates",
    "Chinese Input Mode": "i18n:Menu.ChineseInputMode",
    "Clear Memorized Phrases": "i18n:Menu.ClearMemorizedPhrases",
    "Code Point Input.": "i18n:Menu.CodePointInput",
    "Copy All to Clipboard": "i18n:Menu.CopyAllToClipboard",
    "Edit Associated Phrases…": "i18n:Menu.EditAssociatedPhrases",
    "Edit Excluded Phrases…": "i18n:Menu.EditExcludedPhrases",
    "Edit Phrase Replacement Table…": "i18n:Menu.EditPhraseReplacementTable",
    "Edit User Symbol & Emoji Data…": "i18n:Menu.EditUserSymbolEmojiData",
    "Edit vChewing User Phrases…": "i18n:Menu.EditVChewingUserPhrases",
    "Edit…": "i18n:Menu.Edit",
    "Open App Support Folder": "i18n:Menu.OpenAppSupportFolder",
    "Open User Dictionary Folder": "i18n:Menu.OpenUserDictionaryFolder",
    "Optimize Memorized Phrases": "i18n:Menu.OptimizeMemorizedPhrases",
    "Reboot vChewing…": "i18n:Menu.RebootVChewing",
    "Reload User Phrases": "i18n:Menu.ReloadUserPhrases",
    "Service Menu Editor": "i18n:Menu.ServiceMenuEditor",
    "Symbol & Emoji Input": "i18n:Menu.SymbolEmojiInput",
    "Uninstall vChewing…": "i18n:Menu.UninstallVChewing",
    "vChewing Preferences…": "i18n:Menu.VChewingPreferences",
    "Visit Website": "i18n:Menu.VisitWebsite",
    "Where's IMK Candidate Window?": "i18n:Menu.WhereIsIMKCandidateWindow",
    "Hanin Keyboard Symbol Input.": "i18n:Menu.HaninKeyboardSymbolInput",
    "The End of Support for IMK Candidate Window": "i18n:Menu.EndOfIMKCandidateWindow",
    "CheatSheet": "i18n:Menu.CheatSheet",
    "Push the cursor in front of the phrase after selection": "i18n:Menu.PushCursorAfterSelection",
    "Use Phrase Replacement": "i18n:Menu.UsePhraseReplacement",

    // MARK: - KeyboardLayout (18 keys)

    "Alvin Liu (Imitative)": "i18n:KeyboardLayout.AlvinLiuImitative",
    "Apple ABC (equivalent to English US)": "i18n:KeyboardLayout.AppleABC",
    "Apple Chewing - Dachen": "i18n:KeyboardLayout.AppleChewingDachen",
    "Apple Chewing - Eten Traditional": "i18n:KeyboardLayout.AppleChewingEtenTraditional",
    "Apple Zhuyin Bopomofo (Dachen)": "i18n:KeyboardLayout.AppleZhuyinBopomofoDachen",
    "Apple Zhuyin Eten (Traditional)": "i18n:KeyboardLayout.AppleZhuyinEtenTraditional",
    "Dachen (Microsoft Standard / Wang / 01, etc.)": "i18n:KeyboardLayout.DachenMicrosoftStandard",
    "Dachen 26 (libChewing)": "i18n:KeyboardLayout.Dachen26",
    "Dachen Trad.": "i18n:KeyboardLayout.DachenTraditional",
    "Eten 26": "i18n:KeyboardLayout.Eten26",
    "Eten Trad.": "i18n:KeyboardLayout.EtenTraditionalShort",
    "Eten Traditional": "i18n:KeyboardLayout.EtenTraditional",
    "Fake Seigyou": "i18n:KeyboardLayout.FakeSeigyou",
    "Hsu": "i18n:KeyboardLayout.Hsu",
    "IBM": "i18n:KeyboardLayout.IBM",
    "MiTAC": "i18n:KeyboardLayout.MiTAC",
    "Seigyou": "i18n:KeyboardLayout.Seigyou",
    "Starlight": "i18n:KeyboardLayout.Starlight",

    // MARK: - TypingMethod (10 keys)

    "Hanyu Pinyin with Numeral Intonation": "i18n:TypingMethod.HanyuPinyinNumeral",
    "Hualuo Pinyin with Numeral Intonation": "i18n:TypingMethod.HualuoPinyinNumeral",
    "Secondary Pinyin with Numeral Intonation": "i18n:TypingMethod.SecondaryPinyinNumeral",
    "Universal Pinyin with Numeral Intonation": "i18n:TypingMethod.UniversalPinyinNumeral",
    "Wade-Giles Pinyin with Numeral Intonation": "i18n:TypingMethod.WadeGilesPinyinNumeral",
    "Yale Pinyin with Numeral Intonation": "i18n:TypingMethod.YalePinyinNumeral",
    "typingMethod.romanNumerals.error.invalidCharacter": "i18n:TypingMethod.RomanNumerals.ErrorInvalidCharacter",
    "typingMethod.romanNumerals.error.invalidInput": "i18n:TypingMethod.RomanNumerals.ErrorInvalidInput",
    "typingMethod.romanNumerals.error.valueOutOfRange": "i18n:TypingMethod.RomanNumerals.ErrorValueOutOfRange",
    "typingMethod.romanNumerals.tooltip": "i18n:TypingMethod.RomanNumerals.Tooltip",

    // MARK: - SymbolCategory (25 keys)

    "catAlphabets": "i18n:SymbolCategory.Alphabets",
    "catBracketedASCII": "i18n:SymbolCategory.BracketedASCII",
    "catBracketKanjis": "i18n:SymbolCategory.BracketKanjis",
    "catCircledASCII": "i18n:SymbolCategory.CircledASCII",
    "catCircledKanjis": "i18n:SymbolCategory.CircledKanjis",
    "catCircledKataKana": "i18n:SymbolCategory.CircledKataKana",
    "catCombinations": "i18n:SymbolCategory.Combinations",
    "catCommonSymbols": "i18n:SymbolCategory.CommonSymbols",
    "catCurrencyUnits": "i18n:SymbolCategory.CurrencyUnits",
    "catDoubleTableLines": "i18n:SymbolCategory.DoubleTableLines",
    "catFillingBlocks": "i18n:SymbolCategory.FillingBlocks",
    "catHoriBrackets": "i18n:SymbolCategory.HorizontalBrackets",
    "catKana": "i18n:SymbolCategory.Kana",
    "catLineSegments": "i18n:SymbolCategory.LineSegments",
    "catMathSymbols": "i18n:SymbolCategory.MathSymbols",
    "catMusicSymbols": "i18n:SymbolCategory.MusicSymbols",
    "catPhonabets": "i18n:SymbolCategory.Phonabets",
    "catRadicals": "i18n:SymbolCategory.Radicals",
    "catSingleTableLines": "i18n:SymbolCategory.SingleTableLines",
    "catSpecialNumbers": "i18n:SymbolCategory.SpecialNumbers",
    "catSpecialSymbols": "i18n:SymbolCategory.SpecialSymbols",
    "catThai": "i18n:SymbolCategory.Thai",
    "catUnicodeSymbols": "i18n:SymbolCategory.UnicodeSymbols",
    "catVertBrackets": "i18n:SymbolCategory.VerticalBrackets",
    "catYi": "i18n:SymbolCategory.Yi",

    // MARK: - LanguageName (8 keys)

    "en": "i18n:LanguageName.LocaleCodeEN",
    "English": "i18n:LanguageName.LocaleCodeEN",
    "ja": "i18n:LanguageName.LocaleCodeJA",
    "Japanese": "i18n:LanguageName.LocaleCodeJA",
    "Simplified Chinese": "i18n:LanguageName.LocaleCodeZHHans",
    "Traditional Chinese": "i18n:LanguageName.LocaleCodeZHHant",
    "zh-Hans": "i18n:LanguageName.LocaleCodeZHHans",
    "zh-Hant": "i18n:LanguageName.LocaleCodeZHHant",

    // MARK: - Common (23 keys)

    "Cancel": "i18n:Common.Cancel",
    "Check Later": "i18n:Common.CheckLater",
    "Comment": "i18n:Common.Comment",
    "Consolidate": "i18n:Common.Consolidate",
    "Initial": "i18n:Common.Initial",
    "Just Select": "i18n:Common.JustSelect",
    "Leave it checked": "i18n:Common.LeaveItChecked",
    "No": "i18n:Common.No",
    "Not Now": "i18n:Common.NotNow",
    "OK": "i18n:Common.OK",
    "Add": "i18n:Common.Add",
    "Phrase": "i18n:Common.Phrase",
    "Reading/Stroke": "i18n:Common.ReadingStroke",
    "Reload": "i18n:Common.Reload",
    "Remove Selected": "i18n:Common.RemoveSelected",
    "Replace to": "i18n:Common.ReplaceTo",
    "Reset Default": "i18n:Common.ResetDefault",
    "Save": "i18n:Common.Save",
    "Uncheck": "i18n:Common.Uncheck",
    "Warning": "i18n:Common.Warning",
    "Weight": "i18n:Common.Weight",
    "Yes": "i18n:Common.Yes",
    "Please select…": "i18n:Common.PleaseSelect",
    "Please try again.": "i18n:Common.PleaseTryAgain",

    // MARK: - Settings (20 keys)

    "auto": "i18n:Settings.OptionAuto",
    "Choose the phonetic layout for Mandarin parser.": "i18n:Settings.ChoosePhoneticLayoutPrompt",
    "Choose the target application bundle.": "i18n:Settings.ChooseTargetAppBundle",
    "Choose your desired user data folder.": "i18n:Settings.ChooseUserDataFolder",
    "Completely disable using Shift key to toggle alphanumerical mode": "i18n:Settings.DisableShiftToggleAlphanumerical",
    "Enable experimental Swift UI typesetting method": "i18n:Settings.EnableExperimentalSwiftUITypesetting",
    "Experience": "i18n:Settings.TabExperience",
    "Experimental:": "i18n:Settings.SectionExperimental",
    "Follow OS settings": "i18n:Settings.FollowOSSettings",
    "Keyboard Shortcuts:": "i18n:Settings.SectionKeyboardShortcuts",
    "Misc Settings:": "i18n:Settings.SectionMiscSettings",
    "Only load factory language models if needed": "i18n:Settings.OnlyLoadFactoryLanguageModels",
    "Output Settings:": "i18n:Settings.SectionOutputSettings",
    "Phonetic Parser:": "i18n:Settings.SectionPhoneticParser",
    "Quick Setup:": "i18n:Settings.SectionQuickSetup",
    "Space:": "i18n:Settings.SectionSpace",
    "Typing Settings:": "i18n:Settings.SectionTypingSettings",
    "Typing Style:": "i18n:Settings.SectionTypingStyle",
    "Some previous options are moved to other tabs.": "i18n:Settings.OptionsMovedToOtherTabs",
    "Warning: This page is for testing future features. \nFeatures listed here may not work as expected.": "i18n:Settings.DevZoneWarning",

    // MARK: - PhraseEditor (16 keys)

    "Phrase Editor": "i18n:PhraseEditor.Title",
    "Char\tReading(s)\n": "i18n:PhraseEditor.CharReadingHeader",
    "Example:\nCandidate Reading-Reading #Comment": "i18n:PhraseEditor.ExamplePhrase",
    "Example:\nCandidate Reading-Reading Weight #Comment\nCandidate Reading-Reading #Comment": "i18n:PhraseEditor.ExamplePhraseWithWeight",
    "Example:\nInitial RestPhrase\nInitial RestPhrase1 RestPhrase2 RestPhrase3...": "i18n:PhraseEditor.ExampleAssociates",
    "Example:\nOldPhrase NewPhrase #Comment": "i18n:PhraseEditor.ExampleReplacement",
    "How to Fill": "i18n:PhraseEditor.HowToFill",
    "Inline comments are not supported in associated phrases.": "i18n:PhraseEditor.InlineCommentsNotSupported",
    "One record per line. Use Option+Enter to break lines.\nBlank lines will be dismissed.": "i18n:PhraseEditor.OneRecordPerLine",
    "Please select Simplified / Traditional Chinese mode above.": "i18n:PhraseEditor.SelectModeFirst",
    "If not filling the weight, it will be 0.0, the maximum one. An ideal weight situates in [-9.5, 0], making itself can be captured by the sentence-composition algorithm. The exception is -114.514, the disciplinary weight. The sentence-composition algorithm will ignore it unless it is the unique result.": "i18n:PhraseEditor.WeightExplanation",
    "theAssociates": "i18n:PhraseEditor.TabAssociates",
    "theFilter": "i18n:PhraseEditor.TabFilter",
    "thePhrases": "i18n:PhraseEditor.TabPhrases",
    "theReplacements": "i18n:PhraseEditor.TabReplacements",
    "theSymbols": "i18n:PhraseEditor.TabSymbols",

    // MARK: - ClientManager (10 keys)

    "Client Manager": "i18n:ClientManager.Title",
    "Add Client": "i18n:ClientManager.AddClient",
    "Add Service": "i18n:ClientManager.AddService",
    "Do you want to enable the popup composition buffer for this client?": "i18n:ClientManager.EnablePopupCompositionBuffer",
    "Please drag the apps into the Client Manager window from Finder.": "i18n:ClientManager.DragAppsInstruction",
    "Please drag the desired target from Finder to this place.": "i18n:ClientManager.DragTargetInstruction",
    "Please enter the client app bundle identifier(s) you want to register.": "i18n:ClientManager.EnterBundleIdentifier",
    "Please manage the list of those clients here which are: 1) IMKTextInput-incompatible; 2) suspected from abusing the contents of the inline composition buffer. A client listed here, if checked, will use popup composition buffer with maximum 20 reading counts holdable.": "i18n:ClientManager.ManageClientsDescription",
    "Please manually enter the identifier(s).": "i18n:ClientManager.ManuallyEnterIdentifier",
    "Some client apps may have different compatibility issues in IMKTextInput implementation.": "i18n:ClientManager.CompatibilityNote",

    // MARK: - ErrorMessage (14 keys)

    "Candidate keys can only contain printable ASCII characters like alphanumericals.": "i18n:ErrorMessage.CandidateKeysASCIIOnly",
    "Candidate keys cannot contain space.": "i18n:ErrorMessage.CandidateKeysNoSpace",
    "Invalid Code Point.": "i18n:ErrorMessage.InvalidCodePoint",
    "Invalid Selection Keys.": "i18n:ErrorMessage.InvalidSelectionKeys",
    "Maximum 10 candidate keys allowed.": "i18n:ErrorMessage.MaxCandidateKeys",
    "Maximum 15 results returnable.": "i18n:ErrorMessage.MaxResultsReturnable",
    "Minimum 6 candidate keys allowed.": "i18n:ErrorMessage.MinCandidateKeys",
    "Plist downloaded cannot be parsed correctly.": "i18n:ErrorMessage.PlistParseError",
    "Plist downloaded is nil.": "i18n:ErrorMessage.PlistNil",
    "The selected item is either not a valid macOS application bundle or not having a valid app bundle identifier.": "i18n:ErrorMessage.InvalidAppBundle",
    "The selected item's identifier is already in the list.": "i18n:ErrorMessage.IdentifierAlreadyExists",
    "Unable to create the user phrase file.": "i18n:ErrorMessage.UnableToCreateUserPhraseFile",
    "Wildcard key cannot be the initial key.": "i18n:ErrorMessage.WildcardKeyNotInitial",
    "Please check the permission at \"%@\".": "i18n:ErrorMessage.CheckPermission:%@",

    // MARK: - InfoMessage (24 keys)

    "You may follow:": "i18n:InfoMessage.YouMayFollow",
    "There may be no internet connection or the server failed to respond.\n\nError message: %@": "i18n:InfoMessage.NetworkError:%@",
    "This feature requires macOS %@ and above.": "i18n:InfoMessage.FeatureRequiresMacOS:%@",
    "This only works with Tadokoro candidate window.": "i18n:InfoMessage.OnlyTadokoroCandidateWindow",
    "This update will upgrade vChewing from Aqua Special Edition to Mainstream Release (recommended for your current OS version).": "i18n:InfoMessage.UpdateToMainstreamRelease",
    "This will remove vChewing Input Method from this user account, requiring your confirmation.": "i18n:InfoMessage.UninstallConfirmation",
    "User phrase folder path is not customizable in macOS 10.9 - 10.12.": "i18n:InfoMessage.UserPhrasePathNotCustomizable",
    "You are already using the latest version of vChewing.": "i18n:InfoMessage.AlreadyLatestVersionVChewing",
    "You are already using the latest version.": "i18n:InfoMessage.AlreadyLatestVersion",
    "You are proceeding to System Preferences to enable the Input Source which corresponds to the input mode you are going to switch to.": "i18n:InfoMessage.ProceedingToSystemPreferences",
    "You're currently using vChewing %@ (%@), a new version %@ (%@) is now available. Do you want to visit vChewing's website to download the version?": "i18n:InfoMessage.NewVersionAvailableDetail:%@%@@%@@%@",
    "vChewing crashed while handling previously loaded POM observation data. These data files are cleaned now to ensure the usability.": "i18n:InfoMessage.POMDataCleaned",
    "vChewing is rebooted due to a memory-excessive-usage problem. If convenient, please inform the developer that you are having this issue, stating whether you are using an Intel Mac or Apple Silicon Mac. An NSLog is generated with the current memory footprint size.": "i18n:InfoMessage.MemoryExcessiveReboot",
    "Some features are unavailable for macOS 10.15 and macOS 11 due to API limitations.": "i18n:InfoMessage.FeaturesUnavailableForOlderMacOS",
    "Please use mouse wheel to scroll each page if needed. The CheatSheet is available in the IME menu.": "i18n:InfoMessage.MouseWheelScrollWithCheatSheet",
    "Please use mouse wheel to scroll this page. The CheatSheet is available in the IME menu.": "i18n:InfoMessage.MouseWheelScrollThisPage",
    "Note: The “Delete ⌫” key on Mac keyboard is named as “BackSpace ⌫” here in order to distinguish the real “Delete ⌦” key from full-sized desktop keyboards. If you want to use the real “Delete ⌦” key on a Mac keyboard with no numpad equipped, you have to press “Fn+⌫” instead.": "i18n:InfoMessage.DeleteKeyNote",
    "Please manually implement the symbols of this menu \nin the user phrase file with “_punctuation_list” key.": "i18n:InfoMessage.ManuallyImplementSymbols",
    "defaults write org.atelierInmu.inputmethod.vChewing CassettePath -string \"~/FilePathEndedWithoutTrailingSlash\"": "i18n:InfoMessage.DefaultsWriteCassettePath",
    "defaults write org.atelierInmu.inputmethod.vChewing UserDataFolderSpecified -string \"~/FolderPathEndedWithTrailingSlash/\"": "i18n:InfoMessage.DefaultsWriteUserDataFolder",
    "Please use “defaults write” terminal command to modify this String value:": "i18n:InfoMessage.UseDefaultsWrite",
    "[Technical Reason] macOS releases earlier than 10.13 have an issue: If calling NSOpenPanel directly from an input method, both the input method and its current client app hang in a dead-loop. Furthermore, it makes other apps hang in the same way when you switch into another app. If you don't want to hard-reboot your computer, your last resort is to use SSH to connect to your current computer from another computer and kill the input method process by Terminal commands. That's why vChewing cannot offer access to NSOpenPanel for macOS 10.12 and earlier.": "i18n:InfoMessage.TechnicalReasonNSOpenPanel",
    "Due to security concerns, we don't consider implementing anything related to shell script execution here. An input method doing this without implementing App Sandbox will definitely have system-wide vulnerabilities, considering that its related UserDefaults are easily tamperable to execute malicious shell scripts. vChewing is designed to be invulnerable from this kind of attack. Also, official releases of vChewing are Sandboxed.": "i18n:InfoMessage.SecurityConcernsNoShellScript",
    "There is a bug in macOS 10.9, preventing an input method from accessing its own file panels. Doing so will result in eternal hang-crash of not only the input method but all client apps it tries attached to, requiring SSH connection to this computer to terminate the input method process by executing “killall vChewing”. Due to possible concerns of the same possible issue in macOS 10.10 and 10.11, we completely disabled this feature.": "i18n:InfoMessage.MacOS10_9Bug",
    "1) Only macOS has IMKCandidates. Since it relies on a dedicated ObjC Bridging Header to expose necessary internal APIs to work, it hinders vChewing from completely modularized for multi-platform support.\n\n2) IMKCandidates is buggy. It is not likely to be completely fixed by Apple, and its devs are not allowed to talk about it to non-Apple individuals. That's why we have had enough with IMKCandidates. It is likely the reason why Apple had never used IMKCandidates in their official InputMethodKit sample projects (as of August 2023).": "i18n:InfoMessage.EndOfIMKCandidatesExplanation",

    // MARK: - IME Misc (2 keys)

    "imeMenu.totalRAMUsed.labelHeader": "i18n:IME.RAMUsedLabelHeader",
    "vChewing": "i18n:Common.VChewing",

    // MARK: - Uninstaller (1 key)

    "Uninstallation": "i18n:Uninstaller.Title",

    // MARK: - Installer (21 keys)

    "Abort": "i18n:Installer.Abort",
    "Attention": "i18n:Installer.Attention",
    "Cannot activate the input method.": "i18n:Installer.CannotActivateInputMethod",
    "Cannot copy the file to the destination.": "i18n:Installer.CannotCopyFileToDestination",
    "Cannot find input source %@ after registration.": "i18n:Installer.CannotFindInputSourceAfterRegistration:%@",
    "Cannot register input source %@ at %@.": "i18n:Installer.CannotRegisterInputSource:%@%@@",
    "Continue Installation": "i18n:Installer.ContinueInstallation",
    "Continue": "i18n:Installer.Continue",
    "Download Mainstream Releases": "i18n:Installer.DownloadMainstreamReleases",
    "Fatal Error": "i18n:Installer.FatalError",
    "Input method may not be fully enabled. Please enable it through System Preferences > Keyboard > Input Sources.": "i18n:Installer.InputMethodMayNotBeFullyEnabled",
    "Install Failed": "i18n:Installer.InstallFailed",
    "Installation Successful": "i18n:Installer.InstallationSuccessful",
    "Please use mainstream releases for the current system version.": "i18n:Installer.PleaseUseMainstreamReleases",
    "Quit Installation": "i18n:Installer.QuitInstallation",
    "Stopping the old version. This may take up to one minute…": "i18n:Installer.StoppingOldVersion",
    "The current installer only installs version suitable for macOS 10.9 Mavericks, and it theoreotically works with macOS 10.10 Yosemite - macOS 12 Monterey. Meanwhile, the mainstream releases is made available for most recent macOS release.": "i18n:Installer.LegacyInstallerNotice",
    "vChewing Input Method": "i18n:Installer.VChewingInputMethod",
    "vChewing is ready to use. \n\nPlease relogin if this is the first time you install it in this user account.": "i18n:Installer.ReadyToUse",
    "vChewing is upgraded, but please log out or reboot for the new version to be fully functional.": "i18n:Installer.UpgradedPleaseRelogin",
  ]
}
