// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Combine
import Foundation
import LangModelAssembly
import Shared
import SwiftExtension
import SwiftUI
import SwiftUIBackports

private let loc: String =
  (UserDefaults.standard.array(forKey: UserDef.kAppleLanguages.rawValue) as? [String] ?? ["auto"])[0]

@available(macOS 10.15, *)
extension VwrPhraseEditorUI {
  @Backport.AppStorage("PhraseEditorAutoReloadExternalModifications")
  private static var autoReloadExternalModifications: Bool = true
}

@available(macOS 10.15, *)
public struct VwrPhraseEditorUI: View {
  static var txtContentStorage: String = NSLocalizedString(
    "Please select Simplified / Traditional Chinese mode above.", comment: ""
  )
  @Binding public var txtContent: String
  @ObservedObject public var fileChangeIndicator = FileObserveProject.shared
  @State private var selAutoReloadExternalModifications: Bool = UserDefaults.standard.bool(
    forKey: UserDef.kPhraseEditorAutoReloadExternalModifications.rawValue)
  @State var lblAddPhraseTag1 = UITerms.AddPhrases.locPhrase.localized.0
  @State var lblAddPhraseTag2 = UITerms.AddPhrases.locReadingOrStroke.localized.0
  @State var lblAddPhraseTag3 = UITerms.AddPhrases.locWeight.localized.0
  @State var lblAddPhraseTag4 = UITerms.AddPhrases.locComment.localized.0
  @State var txtAddPhraseField1 = ""
  @State var txtAddPhraseField2 = ""
  @State var txtAddPhraseField3 = ""
  @State var txtAddPhraseField4 = ""
  @State public var selInputMode: Shared.InputMode = .imeModeNULL
  @State public var selUserDataType: vChewingLM.ReplacableUserDataType = .thePhrases
  @State private var isLoading = false
  @State private var isSaved = false
  @State private var redrawTrigger = false

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

  // MARK: -

  public init(delegate theDelegate: PhraseEditorDelegate? = nil) {
    _txtContent = .init(
      get: { Self.txtContentStorage },
      set: { newValue, _ in
        Self.txtContentStorage.removeAll()
        Self.txtContentStorage.append(newValue)
      }
    )
    guard let theDelegate = theDelegate else { return }
    defer { delegate = theDelegate }
  }

  public func update() {
    guard let delegate = delegate else { return }
    updateLabels()
    clearAllFields()
    isLoading = true
    txtContent = NSLocalizedString("Loading…", comment: "")
    redrawTrigger.toggle()
    DispatchQueue.main.async {
      txtContent = delegate.retrieveData(mode: selInputMode, type: selUserDataType)
      redrawTrigger.toggle()
      isSaved = true
      isLoading = false
    }
  }

  private func updateLabels() {
    clearAllFields()
    switch selUserDataType {
      case .thePhrases:
        lblAddPhraseTag1 = UITerms.AddPhrases.locPhrase.localized.0
        lblAddPhraseTag2 = UITerms.AddPhrases.locReadingOrStroke.localized.0
        lblAddPhraseTag3 = UITerms.AddPhrases.locWeight.localized.0
        lblAddPhraseTag4 = UITerms.AddPhrases.locComment.localized.0
      case .theFilter:
        lblAddPhraseTag1 = UITerms.AddPhrases.locPhrase.localized.0
        lblAddPhraseTag2 = UITerms.AddPhrases.locReadingOrStroke.localized.0
        lblAddPhraseTag3 = ""
        lblAddPhraseTag4 = UITerms.AddPhrases.locComment.localized.0
      case .theReplacements:
        lblAddPhraseTag1 = UITerms.AddPhrases.locReplaceTo.localized.0
        lblAddPhraseTag2 = UITerms.AddPhrases.locReplaceTo.localized.1
        lblAddPhraseTag3 = ""
        lblAddPhraseTag4 = UITerms.AddPhrases.locComment.localized.0
      case .theAssociates:
        lblAddPhraseTag1 = UITerms.AddPhrases.locInitial.localized.0
        lblAddPhraseTag2 = {
          let result = UITerms.AddPhrases.locPhrase.localized.0
          return (result == "Phrase") ? "Phrases" : result
        }()
        lblAddPhraseTag3 = ""
        lblAddPhraseTag4 = ""
      case .theSymbols:
        lblAddPhraseTag1 = UITerms.AddPhrases.locPhrase.localized.0
        lblAddPhraseTag2 = UITerms.AddPhrases.locReadingOrStroke.localized.0
        lblAddPhraseTag3 = ""
        lblAddPhraseTag4 = UITerms.AddPhrases.locComment.localized.0
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
      delegate.checkIfUserPhraseExist(
        userPhrase: txtAddPhraseField1, mode: selInputMode, key: txtAddPhraseField2
      )
    {
      arrResult.append(" #𝙾𝚟𝚎𝚛𝚛𝚒𝚍𝚎")
    }
    if let lastChar = txtContent.last, !"\n".contains(lastChar) {
      arrResult.insert("\n", at: 0)
    }
    txtContent.append(arrResult.joined(separator: " ") + "\n")
    isSaved = false
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
    guard let delegate = delegate, selInputMode != .imeModeNULL, !isSaved else { return }
    let toSave = txtContent
    isLoading = true
    txtContent = NSLocalizedString("Loading…", comment: "")
    redrawTrigger.toggle()
    let newResult = delegate.saveData(mode: selInputMode, type: selUserDataType, data: toSave)
    txtContent = newResult
    redrawTrigger.toggle()
    isLoading = false
    isSaved = true
  }

  private func consolidate() {
    guard let delegate = delegate, selInputMode != .imeModeNULL else { return }
    DispatchQueue.main.async {
      isLoading = true
      delegate.consolidate(text: &txtContent, pragma: false)  // 強制整理
      isLoading = false
      isSaved = false
    }
  }

  private func callExternalAppToOpenPhraseFile() {
    let app: String = NSEvent.modifierFlags.contains(.option) ? "TextEdit" : "Finder"
    delegate?.openPhraseFile(mode: selInputMode, type: selUserDataType, app: app)
  }

  // MARK: - Main View.

  public var body: some View {
    VStack(spacing: 4) {
      HStack {
        Picker("", selection: $selInputMode.onChange { dropDownMenuDidChange() }) {
          switch currentIMEInputMode {
            case .imeModeCHS:
              Text(Shared.InputMode.imeModeCHS.localizedDescription).tag(Shared.InputMode.imeModeCHS)
              Text(Shared.InputMode.imeModeCHT.localizedDescription).tag(Shared.InputMode.imeModeCHT)
            case .imeModeCHT:
              Text(Shared.InputMode.imeModeCHT.localizedDescription).tag(Shared.InputMode.imeModeCHT)
              Text(Shared.InputMode.imeModeCHS.localizedDescription).tag(Shared.InputMode.imeModeCHS)
            case .imeModeNULL:
              Text(Shared.InputMode.imeModeNULL.localizedDescription).tag(Shared.InputMode.imeModeNULL)
              if loc.contains("Hans") {
                Text(Shared.InputMode.imeModeCHS.localizedDescription).tag(Shared.InputMode.imeModeCHS)
                Text(Shared.InputMode.imeModeCHT.localizedDescription).tag(Shared.InputMode.imeModeCHT)
              } else {
                Text(Shared.InputMode.imeModeCHT.localizedDescription).tag(Shared.InputMode.imeModeCHT)
                Text(Shared.InputMode.imeModeCHS.localizedDescription).tag(Shared.InputMode.imeModeCHS)
              }
          }
        }
        .labelsHidden()
        Picker("", selection: $selUserDataType.onChange { dropDownMenuDidChange() }) {
          Text(vChewingLM.ReplacableUserDataType.thePhrases.localizedDescription).tag(
            vChewingLM.ReplacableUserDataType.thePhrases)
          Text(vChewingLM.ReplacableUserDataType.theFilter.localizedDescription).tag(
            vChewingLM.ReplacableUserDataType.theFilter)
          Text(vChewingLM.ReplacableUserDataType.theReplacements.localizedDescription).tag(
            vChewingLM.ReplacableUserDataType.theReplacements)
          Text(vChewingLM.ReplacableUserDataType.theAssociates.localizedDescription).tag(
            vChewingLM.ReplacableUserDataType.theAssociates)
          Text(vChewingLM.ReplacableUserDataType.theSymbols.localizedDescription).tag(
            vChewingLM.ReplacableUserDataType.theSymbols)
        }
        .labelsHidden()
        Button("Reload") {
          DispatchQueue.main.async { update() }
        }.disabled(selInputMode == .imeModeNULL || isLoading)
        Button("Consolidate") {
          consolidate()
        }.disabled(selInputMode == .imeModeNULL || isLoading)
        if #available(macOS 11.0, *) {
          Button("Save") {
            DispatchQueue.main.async { saveAndReload() }
          }.keyboardShortcut("s", modifiers: [.command])
            .disabled(isSaved || delegate == nil)
        } else {
          Button("Save") {
            DispatchQueue.main.async { saveAndReload() }
          }.disabled(isSaved || delegate == nil)
        }
        Button("...") {
          DispatchQueue.main.async {
            saveAndReload()
            callExternalAppToOpenPhraseFile()
          }
        }
      }

      TextEditorEX(text: $txtContent.onChange { isSaved = false })
        .disabled(selInputMode == .imeModeNULL || isLoading)
        .frame(minWidth: 320, minHeight: 240)
        .backport.onChange(of: fileChangeIndicator.id) { _ in
          if Self.autoReloadExternalModifications { update() }
        }

      VStack(spacing: 4) {
        if selUserDataType != .theAssociates {
          HStack {
            TextField(lblAddPhraseTag4, text: $txtAddPhraseField4)
          }
        }
        HStack {
          TextField(lblAddPhraseTag1, text: $txtAddPhraseField1)
          TextField(lblAddPhraseTag2, text: $txtAddPhraseField2)
          if selUserDataType == .thePhrases {
            TextField(
              lblAddPhraseTag3,
              text: $txtAddPhraseField3.onChange {
                guard let weightVal = Double(txtAddPhraseField3) else { return }
                if weightVal > 0 { txtAddPhraseField3 = "" }
              }
            )
          }
          Button(UITerms.AddPhrases.locAdd.localized.0) {
            DispatchQueue.main.async { insertEntry() }
          }.disabled(txtAddPhraseField1.isEmpty || txtAddPhraseField2.isEmpty)
        }
      }.disabled(selInputMode == Shared.InputMode.imeModeNULL || isLoading)
      HStack {
        if #available(macOS 12, *) {
          Toggle(
            LocalizedStringKey("This editor only: Auto-reload modifications happened outside of this editor"),
            isOn: $selAutoReloadExternalModifications.onChange {
              Self.autoReloadExternalModifications = selAutoReloadExternalModifications
            }
          )
          .controlSize(.small)
        } else {
          Text("Some features are unavailable for macOS 10.15 and macOS 11 due to API limitations.")
            .font(.system(size: 11.0)).foregroundColor(.secondary)
        }
        Spacer()
      }
    }.onDisappear {
      selInputMode = .imeModeNULL
      selUserDataType = .thePhrases
      txtContent = NSLocalizedString("Please select Simplified / Traditional Chinese mode above.", comment: "")
      redrawTrigger.toggle()
    }.onAppear {
      guard let delegate = delegate else { return }
      selInputMode = delegate.currentInputMode
      update()
    }
  }
}

@available(macOS 10.15, *)
struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    VwrPhraseEditorUI()
  }
}

extension vChewingLM.ReplacableUserDataType {
  public var localizedDescription: String { NSLocalizedString(rawValue, comment: "") }
}

private enum UITerms {
  fileprivate enum AddPhrases: String {
    case locPhrase = "Phrase"
    case locReadingOrStroke = "Reading/Stroke"
    case locWeight = "Weight"
    case locComment = "Comment"
    case locReplaceTo = "Replace to"
    case locAdd = "Add"
    case locInitial = "Initial"

    var localized: (String, String) {
      if self == .locAdd {
        return loc.contains("zh") ? ("添入", "") : loc.contains("ja") ? ("記入", "") : ("Add", "")
      }
      let rawArray = NSLocalizedString(self.rawValue, comment: "").components(separatedBy: " ")
      if rawArray.isEmpty { return ("N/A", "N/A") }
      let val1: String = rawArray[0]
      let val2: String = (rawArray.count >= 2) ? rawArray[1] : ""
      return (val1, val2)
    }
  }
}
