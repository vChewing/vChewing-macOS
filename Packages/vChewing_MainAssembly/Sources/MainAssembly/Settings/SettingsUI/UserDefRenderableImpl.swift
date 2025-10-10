// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import IMKUtils
import Shared
import SwiftUI

// MARK: - UserDefRenderable Extension

extension UserDefRenderable<String> {
  @ViewBuilder
  public func render() -> some View {
    if let metaData = metaData {
      VStack(alignment: .leading) {
        Group {
          switch (def.dataType, def) {
          case (.array, .kAppleLanguages):
            Picker(LocalizedStringKey(metaData.shortTitle ?? ""), selection: binding) {
              Text(LocalizedStringKey("Follow OS settings")).tag("auto")
              Text(LocalizedStringKey("Simplified Chinese")).tag("zh-Hans")
              Text(LocalizedStringKey("Traditional Chinese")).tag("zh-Hant")
              Text(LocalizedStringKey("Japanese")).tag("ja")
              Text(LocalizedStringKey("English")).tag("en")
            }
          case (.string, .kCandidateKeys):
            HStack {
              Text(LocalizedStringKey(metaData.shortTitle ?? ""))
              Spacer()
              ComboBox(
                items: CandidateKey.suggestions,
                text: binding
              ).frame(width: 180)
            }
          case (.string, .kAlphanumericalKeyboardLayout):
            Picker(LocalizedStringKey(metaData.shortTitle ?? ""), selection: binding) {
              ForEach(
                0 ... (IMKHelper.allowedAlphanumericalTISInputSources.count - 1),
                id: \.self
              ) { id in
                let theEntry = IMKHelper.allowedAlphanumericalTISInputSources[id]
                Text(theEntry.titleLocalized).tag(theEntry.id)
              }.id(UUID())
            }
          case (.string, .kBasicKeyboardLayout):
            Picker(LocalizedStringKey(metaData.shortTitle ?? ""), selection: binding) {
              ForEach(
                0 ... (IMKHelper.allowedBasicLayoutsAsTISInputSources.count - 1),
                id: \.self
              ) { id in
                let theEntry = IMKHelper.allowedBasicLayoutsAsTISInputSources[id]
                if let theEntry = theEntry {
                  Text(theEntry.titleLocalized).tag(theEntry.id)
                } else {
                  Divider()
                }
              }.id(UUID())
            }
          case (.string, .kCassettePath): EmptyView()
          case (.string, .kUserDataFolderSpecified): EmptyView()
          default: EmptyView()
          }
        }.disabled(OS.ifUnavailable(metaData.minimumOS))
        descriptionView()
      }
    }
  }
}

extension UserDefRenderable<Bool> {
  @ViewBuilder
  public func render() -> some View {
    if let metaData = metaData {
      VStack(alignment: .leading) {
        Group {
          switch def.dataType {
          case .bool where options.isEmpty: // 勾選項。
            Toggle(LocalizedStringKey(metaData.shortTitle ?? ""), isOn: binding)
          case .bool where !options.isEmpty: // 二選一的下拉選單。
            let shortTitle = metaData.shortTitle
            let picker = Picker(
              LocalizedStringKey(metaData.shortTitle ?? ""),
              selection: binding
            ) {
              ForEach(options, id: \.key) { theTag, strOption in
                Text(LocalizedStringKey(strOption)).tag(theTag == 0 ? false : true)
              }
            }
            if shortTitle == nil {
              picker.labelsHidden()
            } else {
              picker
            }
          default: Text("[Debug] Control Type Mismatch: \(def.rawValue)")
          }
        }.disabled(OS.ifUnavailable(metaData.minimumOS))
        descriptionView()
      }
    }
  }
}

extension UserDefRenderable<Int> {
  @ViewBuilder
  public func render() -> some View {
    if let metaData = metaData {
      VStack(alignment: .leading) {
        Group {
          switch def.dataType {
          case .integer where options.isEmpty && def != .kKeyboardParser:
            Text("[Debug] Needs Review: \(def.rawValue)")
          case .integer where options.isEmpty && def == .kKeyboardParser: // 鐵恨注拼引擎的佈局模式選項。
            Picker(
              LocalizedStringKey(metaData.shortTitle ?? ""),
              selection: binding
            ) {
              ForEach(KeyboardParser.allCases, id: \.self) { item in
                if [7, 100].contains(item.rawValue) { Divider() }
                Text(item.localizedMenuName).tag(item.rawValue)
              }.id(UUID())
            }
          case .integer where !options.isEmpty:
            VStack(alignment: .leading) {
              let shortTitle = metaData.shortTitle
              let picker = Picker(
                LocalizedStringKey(metaData.shortTitle ?? ""),
                selection: binding
              ) {
                ForEach(options, id: \.key) { theTag, strOption in
                  Text(LocalizedStringKey(strOption)).tag(theTag)
                }
              }
              if shortTitle == nil {
                picker.labelsHidden()
              } else {
                picker
              }
            }
          default: Text("[Debug] Control Type Mismatch: \(def.rawValue)")
          }
        }.disabled(OS.ifUnavailable(metaData.minimumOS))
        descriptionView()
      }
    }
  }
}

extension UserDefRenderable<Double> {
  @ViewBuilder
  public func render() -> some View {
    if let metaData = metaData {
      VStack(alignment: .leading) {
        Group {
          switch def.dataType {
          case .double where options.isEmpty: // RAW 是 Double，但呈現出來卻是勾選項。
            Text("[Debug] Needs Review: \(def.rawValue)")
          case .double where !options.isEmpty:
            VStack(alignment: .leading) {
              let shortTitle = metaData.shortTitle
              let picker = Picker(
                LocalizedStringKey(metaData.shortTitle ?? ""),
                selection: binding
              ) {
                ForEach(options, id: \.key) { theTag, strOption in
                  Text(LocalizedStringKey(strOption)).tag(Double(theTag))
                }
              }
              if shortTitle == nil {
                picker.labelsHidden()
              } else {
                picker
              }
            }
          default: Text("[Debug] Control Type Mismatch: \(def.rawValue)")
          }
        }.disabled(OS.ifUnavailable(metaData.minimumOS))
        descriptionView()
      }
    }
  }
}

// MARK: - ComboBox

// Ref: https://stackoverflow.com/a/71058587/4162914
// License: https://creativecommons.org/licenses/by-sa/4.0/

@available(macOS 10.15, *)
public struct ComboBox: NSViewRepresentable {
  public class Coordinator: NSObject, NSComboBoxDelegate {
    // MARK: Lifecycle

    public init(_ parent: ComboBox) {
      self.parent = parent
    }

    // MARK: Public

    public var parent: ComboBox
    public var ignoreSelectionChanges = false

    public func comboBoxSelectionDidChange(_ notification: Notification) {
      if !ignoreSelectionChanges,
         let box: NSComboBox = notification.object as? NSComboBox,
         let newStringValue: String = box.objectValueOfSelectedItem as? String {
        parent.text = newStringValue
      }
    }

    public func controlTextDidEndEditing(_ obj: Notification) {
      if let textField = obj.object as? NSTextField {
        parent.text = textField.stringValue
      }
    }
  }

  // The items that will show up in the pop-up menu:
  public var items: [String] = []

  // The property on our parent view that gets synced to the current
  // stringValue of the NSComboBox, whether the user typed it in or
  // selected it from the list:
  @Binding
  public var text: String

  public func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  public func makeNSView(context: Context) -> NSComboBox {
    let comboBox = NSComboBox()
    comboBox.usesDataSource = false
    comboBox.completes = false
    comboBox.delegate = context.coordinator
    comboBox.intercellSpacing = CGSize(width: 0.0, height: 10.0)
    return comboBox
  }

  public func updateNSView(_ nsView: NSComboBox, context: Context) {
    nsView.removeAllItems()
    nsView.addItems(withObjectValues: items)

    // ComboBox doesn't automatically select the item matching its text;
    // we must do that manually. But we need the delegate to ignore that
    // selection-change or we'll get a "state modified during view update;
    // will cause undefined behavior" warning.
    context.coordinator.ignoreSelectionChanges = true
    nsView.stringValue = text
    nsView.selectItem(withObjectValue: text)
    context.coordinator.ignoreSelectionChanges = false
  }
}
