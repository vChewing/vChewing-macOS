// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

// 這其實是 UserDefRenderable 的另一個版本，但用的是 AppKit 而非 SwiftUI。

import AppKit
import Foundation

// MARK: - UserDefRenderableCocoa

public final class UserDefRenderableCocoa: NSObject, Identifiable {
  // MARK: Lifecycle

  public init(def: UserDef) {
    self.def = def
    if let rawOptions = def.metaData?.options, !rawOptions.isEmpty {
      var newOptions: [Int: String] = [:]
      rawOptions.forEach { key, value in
        newOptions[key] = value.localized
      }
      self.optionsLocalized = rawOptions.sorted(by: { $0.key < $1.key })
    } else {
      self.optionsLocalized = []
    }

    var objOptions = [(String, String)?]()
    var intOptions = [(Int, String)?]()
    checkDef: switch def {
    case .kAlphanumericalKeyboardLayout:
      IMKHelper.allowedAlphanumericalTISInputSources.forEach { currentTIS in
        objOptions.append((currentTIS.id, currentTIS.titleLocalized))
      }
      self.optionsLocalizedAsIdentifiables = objOptions
    case .kBasicKeyboardLayout:
      IMKHelper.allowedBasicLayoutsAsTISInputSources.forEach { currentTIS in
        guard let currentTIS = currentTIS else {
          objOptions.append(nil)
          return
        }
        objOptions.append((currentTIS.id, currentTIS.titleLocalized))
      }
      self.optionsLocalizedAsIdentifiables = objOptions
    case .kKeyboardParser:
      KeyboardParser.allCases.forEach { currentParser in
        if [7, 100].contains(currentParser.rawValue) { intOptions.append(nil) }
        intOptions.append((currentParser.rawValue, currentParser.localizedMenuName))
      }
      self.optionsLocalized = intOptions
    default: break checkDef
    }

    super.init()
    guard let metaData = def.metaData else {
      self.inlineDescriptionLocalized = nil
      return
    }
    var stringStack = [String]()
    if let promptText = metaData.inlinePrompt?.localized, !promptText.isEmpty {
      stringStack.append(promptText)
    }
    if let descText = metaData.description?.localized, !descText.isEmpty {
      stringStack.append(descText)
    }
    if metaData.minimumOS > 10.9 {
      var strOSReq = " "
      strOSReq += String(
        format: "This feature requires macOS %@ and above.".localized, arguments: ["12.0"]
      )
      stringStack.append(strOSReq)
    }
    self.currentControl = renderFunctionControl()
    guard !stringStack.isEmpty else {
      self.inlineDescriptionLocalized = nil
      return
    }
    self.inlineDescriptionLocalized = stringStack.joined(separator: "\n")
  }

  // MARK: Public

  public let def: UserDef
  public var optionsLocalized: [(Int, String)?]
  public var inlineDescriptionLocalized: String?
  public var hideTitle: Bool = false
  public var mainViewOverride: (() -> NSView?)?
  public var currentControl: NSControl?
  public var tinySize: Bool = false

  public var id: String { def.rawValue }

  // MARK: Private

  private var optionsLocalizedAsIdentifiables: [(String, String)?] = [] // 非 Int 型資料專用（例：鍵盤佈局選擇器）。
}

extension UserDefRenderableCocoa {
  public func render(fixWidth fixedWith: CGFloat? = nil) -> NSView? {
    let result: NSStackView? = NSStackView.build(.vertical) {
      renderMainLine(fixedWidth: fixedWith)
      renderDescription(fixedWidth: fixedWith)
    }
    result?.makeSimpleConstraint(.width, relation: .equal, value: fixedWith)
    return result
  }

  public func renderDescription(fixedWidth: CGFloat? = nil) -> NSTextField? {
    guard let text = inlineDescriptionLocalized else { return nil }
    let textField = text.makeNSLabel(descriptive: true)
    if #available(macOS 10.10, *), tinySize {
      textField.controlSize = .small
      textField.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
    }
    textField.preferredMaxLayoutWidth = fixedWidth ?? 0
    if let fixedWidth = fixedWidth {
      textField.makeSimpleConstraint(.width, relation: .lessThanOrEqual, value: fixedWidth)
      textField.sizeToFit()
      textField.makeSimpleConstraint(
        .height,
        relation: .lessThanOrEqual,
        value: textField.fittingSize.height
      )
    }
    return textField
  }

  public func renderMainLine(fixedWidth: CGFloat? = nil) -> NSView? {
    if let mainViewOverride = mainViewOverride {
      return mainViewOverride()
    }
    guard let control: NSView = currentControl ?? renderFunctionControl() else { return nil }
    let controlWidth = control.fittingSize.width
    let textLabel: NSTextField? = {
      if !hideTitle, let strTitle = def.metaData?.shortTitle {
        return strTitle.makeNSLabel()
      }
      return nil
    }()
    let result = NSStackView.build(.horizontal) {
      if !hideTitle, let textlabel = textLabel {
        textlabel
        NSView()
      }
      control
    }
    if let fixedWidth = fixedWidth, let textLabel = textLabel {
      let specifiedWidth = fixedWidth - controlWidth - NSFont.systemFontSize
      textLabel.preferredMaxLayoutWidth = specifiedWidth
      textLabel.makeSimpleConstraint(.width, relation: .lessThanOrEqual, value: specifiedWidth)
      textLabel.sizeToFit()
      textLabel.makeSimpleConstraint(
        .height,
        relation: .lessThanOrEqual,
        value: textLabel.fittingSize.height
      )
    }
    textLabel?.sizeToFit()
    return result
  }

  private func renderFunctionControl() -> NSControl? {
    var result: NSControl? {
      switch def.dataType {
      case .string where def == .kCandidateKeys:
        let comboBox = NSComboBox()
        comboBox.makeSimpleConstraint(.width, relation: .equal, value: 128)
        comboBox.font = NSFont.systemFont(ofSize: 12)
        comboBox.intercellSpacing = CGSize(width: 0.0, height: 10.0)
        comboBox.addItems(withObjectValues: CandidateKey.suggestions)
        comboBox.bind(
          .value,
          to: NSUserDefaultsController.shared,
          withKeyPath: "values.\(def.rawValue)"
        )
        return comboBox
      case .bool where optionsLocalized.isEmpty:
        let checkBox: NSControl
        if #unavailable(macOS 10.15) {
          checkBox = NSButton()
          (checkBox as? NSButton)?.setButtonType(.switch)
          (checkBox as? NSButton)?.title = ""
        } else {
          checkBox = NSSwitch()
          checkBox.controlSize = .mini
        }
        checkBox.bind(
          .value,
          to: NSUserDefaultsController.shared,
          withKeyPath: "values.\(def.rawValue)",
          options: [.continuouslyUpdatesValue: true]
        )

        // 特殊情形開始：部分控件有啟用條件，條件不滿足則變灰。
        checkDef: switch def {
        case .kAlwaysExpandCandidateWindow:
          checkBox.bind(
            .enabled,
            to: NSUserDefaultsController.shared,
            withKeyPath: "values.\(UserDef.kCandidateWindowShowOnlyOneLine.rawValue)",
            options: [
              .valueTransformerName: NSValueTransformerName.negateBooleanTransformerName,
            ]
          )
        case .kUseDynamicCandidateWindowOrigin:
          checkBox.bind(
            .enabled,
            to: NSUserDefaultsController.shared,
            withKeyPath: "values.\(UserDef.kUseRearCursorMode.rawValue)",
            options: [
              .valueTransformerName: NSValueTransformerName.negateBooleanTransformerName,
            ]
          )
        default: break checkDef
        }
        // 特殊情形結束

        return checkBox
      case .integer, .double,
           .bool where !optionsLocalized.isEmpty,
           .string where !optionsLocalized.isEmpty,
           .string where !optionsLocalizedAsIdentifiables.isEmpty:
        let dropMenu: NSMenu = .init()
        let btnPopup = NSPopUpButton()
        var itemShouldBeChosen: NSMenuItem?
        if !optionsLocalizedAsIdentifiables.isEmpty {
          btnPopup.bind(
            .selectedObject,
            to: NSUserDefaultsController.shared,
            withKeyPath: "values.\(def.rawValue)",
            options: [.continuouslyUpdatesValue: true]
          )
          optionsLocalizedAsIdentifiables.forEach { entity in
            guard let obj = entity?.0, let title = entity?.1.localized else {
              dropMenu.addItem(.separator())
              return
            }
            let newItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            newItem.representedObject = .init(obj)
            if obj == UserDefaults.current.object(forKey: def.rawValue) as? String {
              itemShouldBeChosen = newItem
            }
            dropMenu.addItem(newItem)
          }
        } else {
          btnPopup.bind(
            .selectedTag,
            to: NSUserDefaultsController.shared,
            withKeyPath: "values.\(def.rawValue)",
            options: [.continuouslyUpdatesValue: true]
          )
          optionsLocalized.forEach { entity in
            guard let tag = entity?.0, let title = entity?.1.localized else {
              dropMenu.addItem(.separator())
              return
            }
            let newItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            newItem.tag = tag
            if tag == UserDefaults.current.integer(forKey: def.rawValue) {
              itemShouldBeChosen = newItem
            }
            if Double(tag) == UserDefaults.current.double(forKey: def.rawValue) {
              itemShouldBeChosen = newItem
            }
            dropMenu.addItem(newItem)
          }
        }
        btnPopup.menu = dropMenu
        btnPopup.font = NSFont.systemFont(ofSize: 12)
        btnPopup.setFrameSize(btnPopup.fittingSize)
        btnPopup.select(itemShouldBeChosen)
        return btnPopup
      case .array, .dictionary, .other: return nil
      default: return nil
      }
    }
    if #available(macOS 10.10, *), tinySize {
      result?.controlSize = .small
      return result?.makeSimpleConstraint(
        .height,
        relation: .greaterThanOrEqual,
        value: Swift.max(14, result?.fittingSize.height ?? 14)
      ) as? NSControl
    }
    return result?.makeSimpleConstraint(
      .height,
      relation: .greaterThanOrEqual,
      value: Swift.max(16, result?.fittingSize.height ?? 16)
    ) as? NSControl
  }
}

// MARK: - External Extensions.

extension UserDef {
  public func render(
    fixWidth: CGFloat? = nil,
    extraOps: ((inout UserDefRenderableCocoa) -> ())? = nil
  )
    -> NSView? {
    var renderable = toCocoaRenderable()
    extraOps?(&renderable)
    return renderable.render(fixWidth: fixWidth)
  }

  public func toCocoaRenderable() -> UserDefRenderableCocoa {
    .init(def: self)
  }
}
