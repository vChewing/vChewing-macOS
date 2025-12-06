// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit

// MARK: - SettingsPanesCocoa.Phrases

extension SettingsPanesCocoa {
  public final class Phrases: NSViewController {
    // MARK: Lifecycle

    deinit { observation?.invalidate() }

    // MARK: Public

    override public func loadView() {
      observation = Broadcaster.shared
        .observe(\.eventForReloadingPhraseEditor, options: [.new]) { _, _ in
          self.updatePhraseEditor()
        }
      initPhraseEditor()
      view = body ?? .init()
      (view as? NSStackView)?.alignment = .centerX
      view.makeSimpleConstraint(.width, relation: .equal, value: windowWidth)
    }

    override public func viewWillAppear() {
      initPhraseEditor()
    }

    override public func viewWillDisappear() {
      tfdPETextEditor.string.removeAll()
    }

    public func createTextViewStack() -> NSScrollView {
      let contentSize = scrollview.contentSize

      if let n = tfdPETextEditor.textContainer {
        n.containerSize = CGSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        n.widthTracksTextView = true
      }

      tfdPETextEditor.minSize = CGSize(width: 0, height: 0)
      tfdPETextEditor.maxSize = CGSize(
        width: CGFloat.greatestFiniteMagnitude,
        height: CGFloat.greatestFiniteMagnitude
      )
      tfdPETextEditor.isVerticallyResizable = true
      tfdPETextEditor.frame = CGRect(
        x: 0,
        y: 0,
        width: contentSize.width,
        height: contentSize.height
      )
      tfdPETextEditor.autoresizingMask = [.width]
      tfdPETextEditor.delegate = self

      scrollview.borderType = .noBorder
      scrollview.hasVerticalScroller = true
      scrollview.hasHorizontalScroller = true
      scrollview.documentView = tfdPETextEditor
      scrollview.scrollerStyle = .legacy
      scrollview.autohidesScrollers = true

      return scrollview
    }

    // MARK: Internal

    let cmbPEInputModeMenu = NSPopUpButton()
    let cmbPEDataTypeMenu = NSPopUpButton()
    let btnPEReload = NSButton()
    let btnPEConsolidate = NSButton()
    let btnPESave = NSButton()
    let btnPEOpenExternally = NSButton()
    let txtPECommentField = NSTextField()
    let txtPEField1 = NSTextField()
    let txtPEField2 = NSTextField()
    let txtPEField3 = NSTextField()
    let btnPEAdd = NSButton()
    let formatter: NumberFormatter = {
      let formatter = NumberFormatter()
      formatter.numberStyle = .decimal
      formatter.maximum = 1.0
      formatter.minimum = -114.514
      return formatter
    }()

    lazy var scrollview = NSScrollView()
    lazy var tfdPETextEditor: NSTextView = {
      let result = NSTextView(frame: CGRect())
      result.font = NSFont.systemFont(ofSize: 13)
      result.allowsUndo = true
      return result
    }()

    @objc
    var observation: NSKeyValueObservation?

    var windowWidth: CGFloat { SettingsPanesCocoa.windowWidth }
    var contentWidth: CGFloat { SettingsPanesCocoa.contentWidth }
    var innerContentWidth: CGFloat { SettingsPanesCocoa.innerContentWidth }
    var tabContainerWidth: CGFloat { SettingsPanesCocoa.tabContainerWidth }
    var contentHalfWidth: CGFloat { SettingsPanesCocoa.contentHalfWidth }
    var isLoading = false {
      didSet { setPEUIControlAvailability() }
    }

    var body: NSView? {
      NSStackView.build(.vertical, insets: .new(all: 14)) {
        NSStackView.buildSection(width: contentWidth) {
          NSStackView.build(.vertical) {
            NSStackView.build(.horizontal, spacing: 4) {
              cmbPEInputModeMenu
              cmbPEDataTypeMenu
              NSView()
              btnPEReload
              btnPEConsolidate
              btnPESave
              btnPEOpenExternally
            }
            createTextViewStack().makeSimpleConstraint(.height, relation: .equal, value: 370)
            NSStackView.build(.horizontal) {
              txtPECommentField
            }
            NSStackView.build(.horizontal) {
              txtPEField1.makeSimpleConstraint(.width, relation: .equal, value: 185)
              txtPEField2.makeSimpleConstraint(.width, relation: .greaterThanOrEqual, value: 80)
              txtPEField3.makeSimpleConstraint(.width, relation: .greaterThanOrEqual, value: 90)
              btnPEAdd
            }
            UserDef.kPhraseEditorAutoReloadExternalModifications
              .render(fixWidth: contentWidth) { renderable in
                renderable.tinySize = true
              }
          }
        }?.boxed()
        NSView().makeSimpleConstraint(.height, relation: .equal, value: NSFont.systemFontSize)
      }
    }

    @IBAction
    func sanityCheck(_: NSControl) {}
  }
}

// MARK: - SettingsPanesCocoa.Phrases + NSTextViewDelegate, NSTextFieldDelegate

extension SettingsPanesCocoa.Phrases: NSTextViewDelegate, NSTextFieldDelegate {
  var selInputMode: Shared.InputMode {
    switch cmbPEInputModeMenu.selectedTag() {
    case 0: return .imeModeCHS
    case 1: return .imeModeCHT
    default: return .imeModeNULL
    }
  }

  var selUserDataType: LMAssembly.ReplacableUserDataType {
    switch cmbPEDataTypeMenu.selectedTag() {
    case 0: return .thePhrases
    case 1: return .theFilter
    case 2: return .theReplacements
    case 3: return .theAssociates
    case 4: return .theSymbols
    default: return .thePhrases
    }
  }

  func updatePhraseEditor() {
    updateLabels()
    clearAllFields()
    isLoading = true
    tfdPETextEditor.string = "i18n:Loading.loading".localized
    asyncOnMain { [weak self] in
      guard let this = self else { return }
      this.tfdPETextEditor.string = LMMgr.retrieveData(
        mode: this.selInputMode,
        type: this.selUserDataType
      )
      this.tfdPETextEditor.toolTip = PETerminology.TooltipTexts
        .sampleDictionaryContent(for: this.selUserDataType)
      this.isLoading = false
    }
  }

  func setPEUIControlAvailability() {
    btnPEReload.isEnabled = selInputMode != .imeModeNULL && !isLoading
    btnPEConsolidate.isEnabled = selInputMode != .imeModeNULL && !isLoading
    btnPESave.isEnabled = true // 暫時沒辦法捕捉到 TextView 的內容變更事件，故作罷。
    btnPEAdd.isEnabled =
      !txtPEField1.stringValue.isEmpty && !txtPEField2.stringValue
        .isEmpty && selInputMode != .imeModeNULL && !isLoading
    tfdPETextEditor.isEditable = selInputMode != .imeModeNULL && !isLoading
    txtPEField1.isEnabled = selInputMode != .imeModeNULL && !isLoading
    txtPEField2.isEnabled = selInputMode != .imeModeNULL && !isLoading
    txtPEField3.isEnabled = selInputMode != .imeModeNULL && !isLoading
    txtPEField3.isHidden = selUserDataType != .thePhrases || isLoading
    txtPECommentField.isEnabled = selUserDataType != .theAssociates && !isLoading
  }

  func updateLabels() {
    clearAllFields()
    switch selUserDataType {
    case .thePhrases:
      (txtPEField1.cell as? NSTextFieldCell)?.placeholderString = PETerminology.AddPhrases.locPhrase
        .localized.0
      (txtPEField2.cell as? NSTextFieldCell)?.placeholderString = PETerminology.AddPhrases
        .locReadingOrStroke.localized.0
      (txtPEField3.cell as? NSTextFieldCell)?.placeholderString = PETerminology.AddPhrases.locWeight
        .localized.0
      (txtPECommentField.cell as? NSTextFieldCell)?.placeholderString = PETerminology.AddPhrases
        .locComment.localized.0
    case .theFilter:
      (txtPEField1.cell as? NSTextFieldCell)?.placeholderString = PETerminology.AddPhrases.locPhrase
        .localized.0
      (txtPEField2.cell as? NSTextFieldCell)?.placeholderString = PETerminology.AddPhrases
        .locReadingOrStroke.localized.0
      (txtPEField3.cell as? NSTextFieldCell)?.placeholderString = ""
      (txtPECommentField.cell as? NSTextFieldCell)?.placeholderString = PETerminology.AddPhrases
        .locComment.localized.0
    case .theReplacements:
      (txtPEField1.cell as? NSTextFieldCell)?.placeholderString = PETerminology.AddPhrases
        .locReplaceTo.localized.0
      (txtPEField2.cell as? NSTextFieldCell)?.placeholderString = PETerminology.AddPhrases
        .locReplaceTo.localized.1
      (txtPEField3.cell as? NSTextFieldCell)?.placeholderString = ""
      (txtPECommentField.cell as? NSTextFieldCell)?.placeholderString = PETerminology.AddPhrases
        .locComment.localized.0
    case .theAssociates:
      (txtPEField1.cell as? NSTextFieldCell)?.placeholderString = PETerminology.AddPhrases
        .locInitial.localized.0
      (txtPEField2.cell as? NSTextFieldCell)?.placeholderString = {
        let result = PETerminology.AddPhrases.locPhrase.localized.0
        return (result == "Phrase") ? "Phrases" : result
      }()
      (txtPEField3.cell as? NSTextFieldCell)?.placeholderString = ""
      (txtPECommentField.cell as? NSTextFieldCell)?.placeholderString = "i18n:Validation.inlineCommentsNotSupportedInAssociatedPhrases".localized
    case .theSymbols:
      (txtPEField1.cell as? NSTextFieldCell)?.placeholderString = PETerminology.AddPhrases.locPhrase
        .localized.0
      (txtPEField2.cell as? NSTextFieldCell)?.placeholderString = PETerminology.AddPhrases
        .locReadingOrStroke.localized.0
      (txtPEField3.cell as? NSTextFieldCell)?.placeholderString = ""
      (txtPECommentField.cell as? NSTextFieldCell)?.placeholderString = PETerminology.AddPhrases
        .locComment.localized.0
    }
  }

  func clearAllFields() {
    txtPEField1.stringValue = ""
    txtPEField2.stringValue = ""
    txtPEField3.stringValue = ""
    txtPECommentField.stringValue = ""
  }

  func initPhraseEditor() {
    // InputMode combobox.
    cmbPEInputModeMenu.menu?.removeAllItems()
    cmbPEInputModeMenu.menu?.appendItems {
      NSMenu.Item("Simplified Chinese")?.tag(0).represent(Shared.InputMode.imeModeCHS)
      NSMenu.Item("Traditional Chinese")?.tag(1).represent(Shared.InputMode.imeModeCHT)
    }
    let toSelect = cmbPEInputModeMenu.menu?.items.first {
      $0.representedObject as? Shared.InputMode == IMEApp.currentInputMode
    } ?? cmbPEInputModeMenu.menu?.items.first
    cmbPEInputModeMenu.select(toSelect)

    // DataType combobox.
    cmbPEDataTypeMenu.menu?.removeAllItems()
    // 嚴重警告：NSMenu.items 在 macOS 10.13 為止的系統下是唯讀的！！
    // 往這個 property 裡面直接寫東西會導致整個視窗叫不出來！！！
    cmbPEDataTypeMenu.menu?.appendItems {
      for (tag, neta) in LMAssembly.ReplacableUserDataType.allCases.enumerated() {
        NSMenu.Item(verbatim: neta.localizedDescription)?.tag(tag)
      }
    }
    cmbPEDataTypeMenu.select(cmbPEDataTypeMenu.menu?.items.first)

    // Buttons.
    btnPEReload.title = "↻"
    btnPEReload.toolTip = "i18n:Common.reload".localized
    btnPEConsolidate.title = "i18n:Common.consolidate".localized
    btnPESave.title = "i18n:Common.save".localized
    btnPEAdd.title = PETerminology.AddPhrases.locAdd.localized.0
    btnPEOpenExternally.title = "…"

    // DataFormatter.
    txtPEField3.formatter = formatter

    // Text Editor View
    tfdPETextEditor.font = NSFont.systemFont(ofSize: 13)
    tfdPETextEditor.isRichText = false

    // Tab key targets.
    tfdPETextEditor.delegate = self
    txtPECommentField.nextKeyView = txtPEField1
    txtPEField1.nextKeyView = txtPEField2
    txtPEField2.nextKeyView = txtPEField3
    txtPEField3.nextKeyView = btnPEAdd

    // Delegates.
    tfdPETextEditor.delegate = self
    txtPECommentField.delegate = self
    txtPEField1.delegate = self
    txtPEField2.delegate = self
    txtPEField3.delegate = self

    // Tooltip.
    txtPEField3.toolTip = PETerminology.TooltipTexts.weightInputBox.localized
    tfdPETextEditor.toolTip = PETerminology.TooltipTexts
      .sampleDictionaryContent(for: selUserDataType)

    // Appearance and Constraints.
    btnPEAdd.bezelStyle = .rounded
    btnPEReload.bezelStyle = .rounded
    btnPEConsolidate.bezelStyle = .rounded
    btnPESave.bezelStyle = .rounded
    btnPEOpenExternally.bezelStyle = .rounded
    if #available(macOS 10.10, *) {
      txtPECommentField.controlSize = .small
    }
    txtPECommentField.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
    cmbPEInputModeMenu.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
    cmbPEInputModeMenu.setContentHuggingPriority(.defaultHigh, for: .horizontal)

    // Key Equivalent
    btnPESave.keyEquivalent = "s"
    btnPESave.keyEquivalentModifierMask = .command
    btnPEConsolidate.keyEquivalent = "O"
    btnPEConsolidate.keyEquivalentModifierMask = [.command, .shift]
    btnPEReload.keyEquivalent = "r"
    btnPEReload.keyEquivalentModifierMask = .command

    // Action Selectors.
    cmbPEInputModeMenu.target = self
    cmbPEInputModeMenu.action = #selector(inputModePEMenuDidChange(_:))
    cmbPEDataTypeMenu.target = self
    cmbPEDataTypeMenu.action = #selector(dataTypePEMenuDidChange(_:))
    btnPEReload.target = self
    btnPEReload.action = #selector(reloadPEButtonClicked(_:))
    btnPEConsolidate.target = self
    btnPEConsolidate.action = #selector(consolidatePEButtonClicked(_:))
    btnPESave.target = self
    btnPESave.action = #selector(savePEButtonClicked(_:))
    btnPEConsolidate.target = self
    btnPEConsolidate.action = #selector(consolidatePEButtonClicked(_:))
    btnPEOpenExternally.target = self
    btnPEOpenExternally.action = #selector(openExternallyPEButtonClicked(_:))
    btnPEAdd.target = self
    btnPEAdd.action = #selector(addPEButtonClicked(_:))

    // Finally, update the entire editor UI.
    updatePhraseEditor()
  }

  public func controlTextDidChange(_: Notification) { setPEUIControlAvailability() }

  @IBAction
  func inputModePEMenuDidChange(_: NSPopUpButton) { updatePhraseEditor() }

  @IBAction
  func dataTypePEMenuDidChange(_: NSPopUpButton) { updatePhraseEditor() }

  @IBAction
  func reloadPEButtonClicked(_: NSButton) { updatePhraseEditor() }

  @IBAction
  func consolidatePEButtonClicked(_: NSButton) {
    asyncOnMain { [weak self] in
      guard let this = self else { return }
      this.isLoading = true
      LMAssembly.LMConsolidator.consolidate(text: &this.tfdPETextEditor.string, pragma: false)
      if this.selUserDataType == .thePhrases {
        LMMgr.shared.tagOverrides(in: &this.tfdPETextEditor.string, mode: this.selInputMode)
      }
      this.isLoading = false
    }
  }

  @IBAction
  func savePEButtonClicked(_: NSButton) {
    let toSave = tfdPETextEditor.string
    isLoading = true
    tfdPETextEditor.string = "i18n:Loading.loading".localized
    let newResult = LMMgr.saveData(mode: selInputMode, type: selUserDataType, data: toSave)
    tfdPETextEditor.string = newResult
    isLoading = false
  }

  @IBAction
  func openExternallyPEButtonClicked(_: NSButton) {
    asyncOnMain { [weak self] in
      guard let this = self else { return }
      let app: FileOpenMethod = NSEvent.keyModifierFlags.contains(.option) ? .textEdit : .finder
      LMMgr.shared.openPhraseFile(mode: this.selInputMode, type: this.selUserDataType, using: app)
    }
  }

  @IBAction
  func addPEButtonClicked(_: NSButton) {
    asyncOnMain { [weak self] in
      guard let this = self else { return }
      this.txtPEField1.stringValue.removeAll { "　 \t\n\r".contains($0) }
      if this.selUserDataType != .theAssociates {
        this.txtPEField2.stringValue.regReplace(pattern: #"( +|　+| +|\t+)+"#, replaceWith: "-")
      }
      this.txtPEField2.stringValue.removeAll {
        this.selUserDataType == .theAssociates ? "\n\r".contains($0) : "　 \t\n\r".contains($0)
      }
      this.txtPEField3.stringValue.removeAll { !"0123456789.-".contains($0) }
      this.txtPECommentField.stringValue.removeAll { "\n\r".contains($0) }
      guard !this.txtPEField1.stringValue.isEmpty,
            !this.txtPEField2.stringValue.isEmpty else { return }
      var arrResult: [String] = [this.txtPEField1.stringValue, this.txtPEField2.stringValue]
      if let weightVal = Double(this.txtPEField3.stringValue), weightVal < 0 {
        arrResult.append(weightVal.description)
      }
      if !this.txtPECommentField.stringValue
        .isEmpty { arrResult.append("#" + this.txtPECommentField.stringValue) }
      if LMMgr.shared.checkIfPhrasePairExists(
        userPhrase: this.txtPEField1.stringValue, mode: this.selInputMode,
        key: this.txtPEField2.stringValue
      ) {
        arrResult.append(" #𝙾𝚟𝚎𝚛𝚛𝚒𝚍𝚎")
      }
      if let lastChar = this.tfdPETextEditor.string.last, !"\n".contains(lastChar) {
        arrResult.insert("\n", at: 0)
      }
      this.tfdPETextEditor.string.append(arrResult.joined(separator: " ") + "\n")
      this.clearAllFields()
    }
  }
}

// MARK: - PETerminology

private enum PETerminology {
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
        let loc = PrefMgr.shared.appleLanguages[0]
        return loc.prefix(2) == "zh" ? ("添入", "") : loc.prefix(2) == "ja" ? ("記入", "") : ("Add", "")
      }
      let rawArray = NSLocalizedString(rawValue, comment: "").components(separatedBy: " ")
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

    public var localized: String { rawValue.localized }

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
            .localized + "\n\n"
            + weightInputBox.localized
      case .theFilter: result = "i18n:Editor.exampleCandidateReadingComment".localized
      case .theReplacements: result = "i18n:Editor.exampleOldPhraseNewPhrase".localized
      case .theAssociates:
        result = "Example:\nInitial RestPhrase\nInitial RestPhrase1 RestPhrase2 RestPhrase3..."
          .localized
      case .theSymbols: result = "i18n:Editor.exampleCandidateReadingComment".localized
      }
      return result
    }
  }
}

@available(macOS 14.0, *)
#Preview(traits: .fixedLayout(width: 600, height: 768)) {
  SettingsPanesCocoa.Phrases()
}
