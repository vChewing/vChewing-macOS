// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import Combine
import LangModelAssembly
import OSFrameworkImpl
import Shared_DarwinImpl
import SwiftUI

private let loc: String =
  (UserDefaults.current.array(forKey: UserDef.kAppleLanguages.rawValue) as? [String] ?? ["auto"])[0]

// MARK: - VwrPhraseEditorUI

@available(macOS 14, *)
public struct VwrPhraseEditorUI: View {
  // MARK: Lifecycle

  // MARK: -

  public init(delegate theDelegate: PhraseEditorDelegate? = nil, window: NSWindow? = nil) {
    _txtContent = .init(
      get: { Self.txtContentStorage },
      set: { newValue, _ in
        Self.txtContentStorage.removeAll()
        Self.txtContentStorage.append(newValue)
      }
    )
    guard let theDelegate = theDelegate else { return }
    defer {
      delegate = theDelegate
      self.window = window
    }
  }

  // MARK: Public

  @Binding
  public var txtContent: String
  @ObservedObject
  public var fileChangeIndicator = PEReloadEventObserver.shared
  @State
  public var selInputMode: Shared.InputMode = .imeModeNULL
  @State
  public var selUserDataType: LMAssembly.ReplacableUserDataType = .thePhrases

  public weak var window: NSWindow?

  public var currentIMEInputMode: Shared.InputMode {
    delegate?.currentInputMode ?? selInputMode
  }

  public var delegate: PhraseEditorDelegate? {
    didSet {
      guard let delegate = delegate else { return }
      selInputMode = delegate.currentInputMode
      update()
    }
  }

  // MARK: - Main View.

  public var body: some View {
    VStack(spacing: 4) {
      HStack {
        Picker("", selection: $selInputMode.didChange { dropDownMenuDidChange() }) {
          switch currentIMEInputMode {
          case .imeModeCHS:
            Text(Shared.InputMode.imeModeCHS.localizedDescription).tag(Shared.InputMode.imeModeCHS)
            Text(Shared.InputMode.imeModeCHT.localizedDescription).tag(Shared.InputMode.imeModeCHT)
          case .imeModeCHT:
            Text(Shared.InputMode.imeModeCHT.localizedDescription).tag(Shared.InputMode.imeModeCHT)
            Text(Shared.InputMode.imeModeCHS.localizedDescription).tag(Shared.InputMode.imeModeCHS)
          case .imeModeNULL:
            Text(Shared.InputMode.imeModeNULL.localizedDescription)
              .tag(Shared.InputMode.imeModeNULL)
            if loc.contains("Hans") {
              Text(Shared.InputMode.imeModeCHS.localizedDescription)
                .tag(Shared.InputMode.imeModeCHS)
              Text(Shared.InputMode.imeModeCHT.localizedDescription)
                .tag(Shared.InputMode.imeModeCHT)
            } else {
              Text(Shared.InputMode.imeModeCHT.localizedDescription)
                .tag(Shared.InputMode.imeModeCHT)
              Text(Shared.InputMode.imeModeCHS.localizedDescription)
                .tag(Shared.InputMode.imeModeCHS)
            }
          }
        }
        .labelsHidden()
        Picker("", selection: $selUserDataType.didChange { dropDownMenuDidChange() }) {
          Text(LMAssembly.ReplacableUserDataType.thePhrases.localizedDescription).tag(
            LMAssembly.ReplacableUserDataType.thePhrases
          )
          Text(LMAssembly.ReplacableUserDataType.theFilter.localizedDescription).tag(
            LMAssembly.ReplacableUserDataType.theFilter
          )
          Text(LMAssembly.ReplacableUserDataType.theReplacements.localizedDescription).tag(
            LMAssembly.ReplacableUserDataType.theReplacements
          )
          Text(LMAssembly.ReplacableUserDataType.theAssociates.localizedDescription).tag(
            LMAssembly.ReplacableUserDataType.theAssociates
          )
          Text(LMAssembly.ReplacableUserDataType.theSymbols.localizedDescription).tag(
            LMAssembly.ReplacableUserDataType.theSymbols
          )
        }
        .labelsHidden()
        Button("Reload") {
          asyncOnMain { update() }
        }.disabled(selInputMode == .imeModeNULL || isLoading)
        Button("Consolidate") {
          consolidate()
        }.disabled(selInputMode == .imeModeNULL || isLoading)
        Button("Save") {
          asyncOnMain { saveAndReload() }
        }.keyboardShortcut("s", modifiers: [.command])
          .disabled(delegate == nil)
        Button("...") {
          asyncOnMain {
            saveAndReload()
            callExternalAppToOpenPhraseFile()
          }
        }
      }

      GroupBox {
        TextEditorEX(text: $txtContent)
          .disabled(selInputMode == .imeModeNULL || isLoading)
          .frame(minWidth: 320, minHeight: 240)
          .onChange(of: fileChangeIndicator.id) { _ in
            Task {
              if autoReloadExternalModifications { update() }
            }
          }
      }

      VStack(spacing: 4) {
        if selUserDataType != .theAssociates {
          HStack {
            TextField(lblAddPhraseTag4, text: $txtAddPhraseField4)
              .autocorrectionDisabled(true)
          }
        }
        HStack {
          TextField(lblAddPhraseTag1, text: $txtAddPhraseField1)
            .autocorrectionDisabled(true)
          TextField(lblAddPhraseTag2, text: $txtAddPhraseField2)
            .autocorrectionDisabled(true)
          if selUserDataType == .thePhrases {
            TextField(
              lblAddPhraseTag3,
              text: $txtAddPhraseField3.didChange {
                guard let weightVal = Double(txtAddPhraseField3) else { return }
                if weightVal > 0 { txtAddPhraseField3 = "" }
              }
            )
            .autocorrectionDisabled(true)
            .help(PETerms.TooltipTexts.weightInputBox.localized)
          }
          Button("?") {
            guard let window = window else { return }
            window.callAlert(
              title: "You may follow:".i18n,
              text: PETerms.TooltipTexts.sampleDictionaryContent(for: selUserDataType)
            )
          }.disabled(window == nil)
          Button(PETerms.AddPhrases.locAdd.localized.0) {
            asyncOnMain { insertEntry() }
          }.disabled(txtAddPhraseField1.isEmpty || txtAddPhraseField2.isEmpty)
        }
      }.disabled(selInputMode == Shared.InputMode.imeModeNULL || isLoading)
      HStack {
        Toggle(
          LocalizedStringKey(
            "This editor only: Auto-reload modifications happened outside of this editor"
          ),
          isOn: $selAutoReloadExternalModifications.didChange {
            autoReloadExternalModifications = selAutoReloadExternalModifications
          }
        )
        .controlSize(.small)
        Spacer()
      }
    }.onDisappear {
      selInputMode = .imeModeNULL
      selUserDataType = .thePhrases
      txtContent = "Please select Simplified / Traditional Chinese mode above.".i18n
      isLoading = true
      Self.txtContentStorage = ""
    }.onAppear {
      guard let delegate = delegate else { return }
      selInputMode = delegate.currentInputMode
      update()
    }
  }

  public func update() {
    guard let delegate = delegate else { return }
    updateLabels()
    clearAllFields()
    txtContent = "Loading…".i18n
    isLoading = true
    asyncOnMain {
      txtContent = delegate.retrieveData(mode: selInputMode, type: selUserDataType)
      textEditorTooltip = PETerms.TooltipTexts.sampleDictionaryContent(for: selUserDataType)
      isLoading = false
    }
  }

  // MARK: Internal

  static var txtContentStorage: String = "Please select Simplified / Traditional Chinese mode above.".i18n

  @State
  var lblAddPhraseTag1 = PETerms.AddPhrases.locPhrase.localized.0
  @State
  var lblAddPhraseTag2 = PETerms.AddPhrases.locReadingOrStroke.localized.0
  @State
  var lblAddPhraseTag3 = PETerms.AddPhrases.locWeight.localized.0
  @State
  var lblAddPhraseTag4 = PETerms.AddPhrases.locComment.localized.0
  @State
  var txtAddPhraseField1 = ""
  @State
  var txtAddPhraseField2 = ""
  @State
  var txtAddPhraseField3 = ""
  @State
  var txtAddPhraseField4 = ""

  // MARK: Private

  @AppStorage("PhraseEditorAutoReloadExternalModifications")
  private var autoReloadExternalModifications: Bool = true
  @State
  private var selAutoReloadExternalModifications: Bool = UserDefaults.current.bool(
    forKey: UserDef.kPhraseEditorAutoReloadExternalModifications.rawValue
  )
  @State
  private var isLoading = false
  @State
  private var textEditorTooltip = PETerms.TooltipTexts
    .sampleDictionaryContent(for: .thePhrases)

  private func updateLabels() {
    clearAllFields()
    switch selUserDataType {
    case .thePhrases:
      lblAddPhraseTag1 = PETerms.AddPhrases.locPhrase.localized.0
      lblAddPhraseTag2 = PETerms.AddPhrases.locReadingOrStroke.localized.0
      lblAddPhraseTag3 = PETerms.AddPhrases.locWeight.localized.0
      lblAddPhraseTag4 = PETerms.AddPhrases.locComment.localized.0
    case .theFilter:
      lblAddPhraseTag1 = PETerms.AddPhrases.locPhrase.localized.0
      lblAddPhraseTag2 = PETerms.AddPhrases.locReadingOrStroke.localized.0
      lblAddPhraseTag3 = ""
      lblAddPhraseTag4 = PETerms.AddPhrases.locComment.localized.0
    case .theReplacements:
      lblAddPhraseTag1 = PETerms.AddPhrases.locReplaceTo.localized.0
      lblAddPhraseTag2 = PETerms.AddPhrases.locReplaceTo.localized.1
      lblAddPhraseTag3 = ""
      lblAddPhraseTag4 = PETerms.AddPhrases.locComment.localized.0
    case .theAssociates:
      lblAddPhraseTag1 = PETerms.AddPhrases.locInitial.localized.0
      lblAddPhraseTag2 = {
        let result = PETerms.AddPhrases.locPhrase.localized.0
        return (result == "Phrase") ? "Phrases" : result
      }()
      lblAddPhraseTag3 = ""
      lblAddPhraseTag4 = ""
    case .theSymbols:
      lblAddPhraseTag1 = PETerms.AddPhrases.locPhrase.localized.0
      lblAddPhraseTag2 = PETerms.AddPhrases.locReadingOrStroke.localized.0
      lblAddPhraseTag3 = ""
      lblAddPhraseTag4 = PETerms.AddPhrases.locComment.localized.0
    }
  }

  private func insertEntry() {
    txtAddPhraseField1.removeAll { "　 \t\n\r".contains($0) }
    if selUserDataType != .theAssociates {
      txtAddPhraseField2.regReplace(pattern: #"( +|　+| +|\t+)+"#, replaceWith: "-")
    }
    txtAddPhraseField2.removeAll {
      selUserDataType == .theAssociates ? "\n\r".contains($0) : "　 \t\n\r".contains($0)
    }
    txtAddPhraseField3.removeAll { !"0123456789.-".contains($0) }
    txtAddPhraseField4.removeAll { "\n\r".contains($0) }
    guard !txtAddPhraseField1.isEmpty, !txtAddPhraseField2.isEmpty else { return }
    var arrResult: [String] = [txtAddPhraseField1, txtAddPhraseField2]
    if let weightVal = Double(txtAddPhraseField3), weightVal < 0 {
      arrResult.append(weightVal.description)
    }
    if !txtAddPhraseField4.isEmpty { arrResult.append("#" + txtAddPhraseField4) }
    if let delegate = delegate,
       delegate.checkIfPhrasePairExists(
         userPhrase: txtAddPhraseField1, mode: selInputMode, key: txtAddPhraseField2
       ) {
      arrResult.append(" #𝙾𝚟𝚎𝚛𝚛𝚒𝚍𝚎")
    }
    if let lastChar = txtContent.last, !"\n".contains(lastChar) {
      arrResult.insert("\n", at: 0)
    }
    txtContent.append(arrResult.joined(separator: " ") + "\n")
    clearAllFields()
  }

  private func clearAllFields() {
    txtAddPhraseField1 = ""
    txtAddPhraseField2 = ""
    txtAddPhraseField3 = ""
    txtAddPhraseField4 = ""
  }

  private func dropDownMenuDidChange() {
    update()
  }

  private func saveAndReload() {
    guard let delegate = delegate, selInputMode != .imeModeNULL else { return }
    let toSave = txtContent
    txtContent = "Loading…".i18n
    isLoading = true
    let newResult = delegate.saveData(mode: selInputMode, type: selUserDataType, data: toSave)
    txtContent = newResult
    isLoading = false
  }

  private func consolidate() {
    guard let delegate = delegate, selInputMode != .imeModeNULL else { return }
    asyncOnMain {
      isLoading = true
      delegate.consolidate(text: &txtContent, pragma: false) // 強制整理
      if selUserDataType == .thePhrases {
        delegate.tagOverrides(in: &txtContent, mode: selInputMode)
      }
      isLoading = false
    }
  }

  private func callExternalAppToOpenPhraseFile() {
    let app: FileOpenMethod = NSEvent.keyModifierFlags.contains(.option) ? .textEdit : .finder
    delegate?.openPhraseFile(mode: selInputMode, type: selUserDataType, using: app)
  }
}

// MARK: - ContentView_Previews

@available(macOS 14, *)
struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    VwrPhraseEditorUI()
  }
}

// MARK: - PETerms

public enum PETerms {
  public enum AddPhrases: String {
    case locPhrase = "Phrase"
    case locReadingOrStroke = "Reading/Stroke"
    case locWeight = "Weight"
    case locComment = "Comment"
    case locReplaceTo = "Replace to"
    case locAdd = "Add"
    case locInitial = "Initial"

    // MARK: Public

    public var localized: (String, String) {
      if self == .locAdd {
        return loc.prefix(2) == "zh" ? ("添入", "") : loc.prefix(2) == "ja" ? ("記入", "") : ("Add", "")
      }
      let rawArray = rawValue.i18n.components(separatedBy: " ")
      if rawArray.isEmpty { return ("N/A", "N/A") }
      let val1: String = rawArray[0]
      let val2: String = (rawArray.count >= 2) ? rawArray[1] : ""
      return (val1, val2)
    }
  }

  public enum TooltipTexts: String {
    case weightInputBox =
      "If not filling the weight, it will be 0.0, the maximum one. An ideal weight situates in [-9.5, 0], making itself can be captured by the sentence-composition algorithm. The exception is -114.514, the disciplinary weight. The sentence-composition algorithm will ignore it unless it is the unique result."

    // MARK: Public

    public var localized: String { rawValue.i18n }

    public static func sampleDictionaryContent(
      for type: LMAssembly
        .ReplacableUserDataType
    )
      -> String {
      var result = ""
      switch type {
      case .thePhrases:
        result =
          "Example:\nCandidate Reading-Reading Weight #Comment\nCandidate Reading-Reading #Comment"
            .i18n + "\n\n"
            + weightInputBox.localized
      case .theFilter: result = "Example:\nCandidate Reading-Reading #Comment".i18n
      case .theReplacements: result = "Example:\nOldPhrase NewPhrase #Comment".i18n
      case .theAssociates:
        result = "Example:\nInitial RestPhrase\nInitial RestPhrase1 RestPhrase2 RestPhrase3..."
          .i18n
      case .theSymbols: result = "Example:\nCandidate Reading-Reading #Comment".i18n
      }
      return result
    }
  }
}
