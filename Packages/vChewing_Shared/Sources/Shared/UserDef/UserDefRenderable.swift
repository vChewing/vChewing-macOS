// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

#if canImport(SwiftUI)

  import Foundation
  import SwiftUI

  // MARK: - UserDefRenderable

  @available(macOS 10.15, *)
  public struct UserDefRenderable<Value>: Identifiable {
    // MARK: Lifecycle

    public init(_ userDef: UserDef, binding: Binding<Value>) {
      self.def = userDef
      self.binding = binding
      self.options = (def.metaData?.options ?? [:]).sorted(by: { $0.key < $1.key })
    }

    // MARK: Public

    public typealias RawFormat = (key: UserDef, value: Binding<Value>)

    public let def: UserDef
    public let binding: Binding<Value>
    public let options: [Dictionary<Int, String>.Element]

    public var id: String { def.rawValue }
    public var metaData: UserDef.MetaData? { def.metaData }

    public var hasInlineDescription: Bool {
      guard let meta = def.metaData else { return false }
      return meta.description != nil || meta.inlinePrompt != nil || meta.minimumOS > 10.9
    }

    @ViewBuilder
    public func render() -> some View {
      EmptyView()
    }

    @ViewBuilder
    public func descriptionView() -> some View {
      if let metaData = metaData {
        if hasInlineDescription { Spacer().frame(height: 6) }
        let descText = metaData.description
        let promptText = metaData.inlinePrompt
        let descriptionSource: [String] = [promptText, descText].compactMap { $0 }

        if !descriptionSource.isEmpty {
          ForEach(Array(descriptionSource.enumerated()), id: \.offset) { _, i18nKey in
            Text(LocalizedStringKey(i18nKey)).settingsDescription()
          }
        }
        if metaData.minimumOS > 10.9 {
          Group {
            Text(" ") +
              Text(
                LocalizedStringKey(
                  "This feature requires macOS \(metaData.minimumOS.description) and above."
                )
              )
          }.settingsDescription()
        }
      }
    }
  }

  extension UserDefRenderable<Any> {
    public func batch(_ input: [RawFormat]) -> [UserDefRenderable<Value>] {
      input.compactMap { metaPair in
        metaPair.key.bind(binding)
      }
    }
  }

  // MARK: - Identifiable + Identifiable

  #if hasFeature(RetroactiveAttribute)
    extension [UserDefRenderable<Any>]: @retroactive Identifiable {}
  #else
    extension [UserDefRenderable<Any>]: Identifiable {}
  #endif

  extension [UserDefRenderable<Any>] {
    public var id: String { map(\.id).description }
  }

  // MARK: - UserDef metaData Extension

  extension UserDef {
    public func bind<Value>(_ binding: Binding<Value>) -> UserDefRenderable<Value> {
      UserDefRenderable(self, binding: binding)
    }
  }

  // MARK: - Private View Extension

  @available(macOS 10.15, *)
  extension View {
    fileprivate func settingsDescription(maxWidth: CGFloat? = .infinity) -> some View {
      controlSize(.small)
        .frame(maxWidth: maxWidth, alignment: .leading)
        // TODO: Use `.foregroundStyle` when targeting macOS 12.
        .foregroundColor(.secondary)
    }
  }

#endif
