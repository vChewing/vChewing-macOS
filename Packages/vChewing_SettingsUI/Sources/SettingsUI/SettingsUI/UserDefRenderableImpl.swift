// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import SwiftUI

// MARK: - UserDef 自繪控件擴充（必須與特化 render() 同模組，以正確解析方法呼叫）

/// 讓 UserDef 可直接產生帶有內建 @AppStorage 繫結的 SwiftUI 控件，
/// 無需在各個 Pane 中重複宣告 @AppStorage 屬性。

@available(macOS 14, *)
extension UserDef {
  /// 自動產生對應的 SwiftUI 控件，內建 @AppStorage 繫結，無需外部 Binding。
  /// - Parameter onChange: 值變更後的額外回呼（選填）。
  @ViewBuilder
  public func renderUI(onChange: (() -> ())? = nil) -> some View {
    UserDefRendered(for: self, onChange: onChange)
  }
}

// MARK: - UserDefRendered

@available(macOS 14, *)
struct UserDefRendered: View {
  // MARK: Lifecycle

  init(for userDef: UserDef, onChange: (() -> ())? = nil) {
    self.userDef = userDef
    self.onChange = onChange
  }

  // MARK: Internal

  var body: some View {
    Group {
      // 若有搜尋文字則過濾，不匹配者佔位但不顯示。
      if viewModel?.matchesSearchable(userDef) ?? true {
        switch userDef.dataType {
        case .bool:
          _UDAutoViewBool(def: userDef, onChange: onChange)
        case .integer:
          _UDAutoViewInt(def: userDef, onChange: onChange)
        case .double:
          _UDAutoViewDouble(def: userDef, onChange: onChange)
        case .string:
          _UDAutoViewString(def: userDef, onChange: onChange)
        default:
          EmptyView()
        }
      }
    }
    // 向 ViewModel 登記此 UserDef 出現在當前 Tab。
    .onAppear {
      if let tab = currentTab {
        viewModel?.register(userDef, in: tab)
      }
    }
  }

  // MARK: Private

  @Environment(SettingsUIViewModel.self)
  private var viewModel: SettingsUIViewModel?

  @Environment(\.currentSettingsTab)
  private var currentTab

  private let userDef: UserDef
  private let onChange: (() -> ())?
}

@available(macOS 14, *)
extension UserDefRendered {
  // MARK: - _UDAutoViewBool

  /// 自繪 Bool 型偏好設定控件。
  private struct _UDAutoViewBool: View {
    // MARK: Lifecycle

    init(def: UserDef, onChange: (() -> ())?) {
      self.def = def
      self.onChange = onChange
      _value = AppStorage(wrappedValue: def.boolDefaultValue, def.rawValue)
    }

    // MARK: Internal

    let def: UserDef
    let onChange: (() -> ())?

    var body: some View {
      if let onChange {
        def.bind($value.didChange(onChange)).render()
      } else {
        def.bind($value).render()
      }
    }

    // MARK: Private

    @AppStorage
    private var value: Bool
  }

  // MARK: - _UDAutoViewInt

  /// 自繪 Int 型偏好設定控件。
  private struct _UDAutoViewInt: View {
    // MARK: Lifecycle

    init(def: UserDef, onChange: (() -> ())?) {
      self.def = def
      self.onChange = onChange
      _value = AppStorage(wrappedValue: def.intDefaultValue, def.rawValue)
    }

    // MARK: Internal

    let def: UserDef
    let onChange: (() -> ())?

    var body: some View {
      if let onChange {
        def.bind($value.didChange(onChange)).render()
      } else {
        def.bind($value).render()
      }
    }

    // MARK: Private

    @AppStorage
    private var value: Int
  }

  // MARK: - _UDAutoViewDouble

  /// 自繪 Double 型偏好設定控件。
  private struct _UDAutoViewDouble: View {
    // MARK: Lifecycle

    init(def: UserDef, onChange: (() -> ())?) {
      self.def = def
      self.onChange = onChange
      _value = AppStorage(wrappedValue: def.doubleDefaultValue, def.rawValue)
    }

    // MARK: Internal

    let def: UserDef
    let onChange: (() -> ())?

    var body: some View {
      if let onChange {
        def.bind($value.didChange(onChange)).render()
      } else {
        def.bind($value).render()
      }
    }

    // MARK: Private

    @AppStorage
    private var value: Double
  }

  // MARK: - _UDAutoViewString

  /// 自繪 String 型偏好設定控件。
  private struct _UDAutoViewString: View {
    // MARK: Lifecycle

    init(def: UserDef, onChange: (() -> ())?) {
      self.def = def
      self.onChange = onChange
      _value = AppStorage(wrappedValue: def.stringDefaultValue, def.rawValue)
    }

    // MARK: Internal

    let def: UserDef
    let onChange: (() -> ())?

    var body: some View {
      if let onChange {
        def.bind($value.didChange(onChange)).render()
      } else {
        def.bind($value).render()
      }
    }

    // MARK: Private

    @AppStorage
    private var value: String
  }
}

// MARK: - UserDefRenderable Extension

@available(macOS 14, *)
extension UserDefRenderable<String> {
  @ViewBuilder
  public func render() -> some View {
    if let metaData = metaData {
      VStack(alignment: .leading) {
        Group {
          switch (def.dataType, def) {
          case (.arrayOfStrings, .kAppleLanguages):
            Picker(LocalizedStringKey(metaData.shortTitle ?? ""), selection: binding) {
              Text(LocalizedStringKey("i18n:Settings.FollowOSSettings")).tag("auto")
              Text(LocalizedStringKey("i18n:LanguageName.LocaleCodeZHHans")).tag("zh-Hans")
              Text(LocalizedStringKey("i18n:LanguageName.LocaleCodeZHHant")).tag("zh-Hant")
              Text(LocalizedStringKey("i18n:LanguageName.LocaleCodeJA")).tag("ja")
              Text(LocalizedStringKey("i18n:LanguageName.LocaleCodeEN")).tag("en")
            }
          case (.string, .kCandidateKeys):
            HStack {
              Text(LocalizedStringKey(metaData.shortTitle ?? ""))
              Spacer()
              ComboBox(
                items: CandidateKey.suggestions,
                text: binding,
                width: 180
              )
            }
          case (.string, .kAlphanumericalKeyboardLayout):
            Picker(LocalizedStringKey(metaData.shortTitle ?? ""), selection: binding) {
              ForEach(
                0 ... (IMKHelper.allowedAlphanumericalTISInputSources.count - 1),
                id: \.self
              ) { id in
                let theEntry = IMKHelper.allowedAlphanumericalTISInputSources[id]
                Text(theEntry.titleLocalized).tag(theEntry.id)
              }
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
              }
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
          case .integer where options.isEmpty && ![.kKeyboardParser4Pinyin, .kKeyboardParser4Zhuyin]
            .contains(def):
            Text("[Debug] Needs Review: \(def.rawValue)")
          case .integer where options.isEmpty && [.kKeyboardParser4Pinyin, .kKeyboardParser4Zhuyin]
            .contains(def): // 鐵恨注拼引擎的佈局模式選項（注音/拼音各自列示其值域）。
            Picker(
              LocalizedStringKey(metaData.shortTitle ?? ""),
              selection: binding
            ) {
              ForEach(
                KeyboardParser.allCases.filter { parser in
                  switch def {
                  case .kKeyboardParser4Zhuyin: return parser.rawValue < 100
                  case .kKeyboardParser4Pinyin: return parser.rawValue >= 100
                  default: return true
                  }
                },
                id: \.self
              ) { item in
                if [7, 100].contains(item.rawValue) { Divider() }
                Text(item.localizedMenuName).tag(item.rawValue)
              }
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

/// SwiftUI 原生下拉建議文字框：左側為可自由輸入的文字框，
/// 右側為建議值選單按鈕，選取後將該值寫回文字框繫結。
@available(macOS 14, *)
public struct ComboBox: View {
  // The items that will show up in the pop-up menu:
  public var items: [String] = []

  // The property on our parent view that gets synced to the current
  // text content, whether the user typed it in or selected it from the list:
  @Binding
  public var text: String

  // The overall width of the control, text field and menu button combined:
  public var width: CGFloat = 128

  public var body: some View {
    HStack(spacing: 0) {
      TextField("", text: $text)
        .textFieldStyle(.roundedBorder)
      Menu {
        ForEach(items, id: \.self) { item in
          Button(item) { text = item }
        }
      } label: {
        Text("▾")
      }
      .menuStyle(.button)
      .menuIndicator(.hidden)
      .frame(width: 24)
    }
    .frame(width: width)
  }
}
