// (c) 2022 and onwards Shaps Benkau (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

import SwiftUI

#if os(iOS)
  import QuickLook

  final class PreviewController<Items>: UIViewController, UIAdaptivePresentationControllerDelegate,
    QLPreviewControllerDelegate, QLPreviewControllerDataSource
  where Items: RandomAccessCollection, Items.Element == URL {
    var items: Items

    var selection: Binding<Items.Element?> {
      didSet {
        updateControllerLifecycle(
          from: oldValue.wrappedValue,
          to: selection.wrappedValue
        )
      }
    }

    init(selection: Binding<Items.Element?>, in items: Items) {
      self.selection = selection
      self.items = items
      super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    private func updateControllerLifecycle(from oldValue: Items.Element?, to newValue: Items.Element?) {
      switch (oldValue, newValue) {
        case (.none, .some):
          presentController()
        case (.some, .some):
          updateController()
        case (.some, .none):
          dismissController()
        case (.none, .none):
          break
      }
    }

    private func presentController() {
      print("Present")
      let controller = QLPreviewController(nibName: nil, bundle: nil)
      controller.dataSource = self
      controller.delegate = self
      present(controller, animated: true)
      updateController()
    }

    private func updateController() {
      let controller = presentedViewController as? QLPreviewController
      controller?.reloadData()
      let index = selection.wrappedValue.flatMap { items.firstIndex(of: $0) }
      controller?.currentPreviewItemIndex = items.distance(from: items.startIndex, to: index ?? items.startIndex)
    }

    private func dismissController() {
      DispatchQueue.main.async {
        self.selection.wrappedValue = nil
      }
    }

    func numberOfPreviewItems(in _: QLPreviewController) -> Int {
      items.isEmpty ? 1 : items.count
    }

    func previewController(_: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
      if items.isEmpty {
        return (selection.wrappedValue ?? URL(fileURLWithPath: "")) as NSURL
      } else {
        let index = items.index(items.startIndex, offsetBy: index)
        return items[index] as NSURL
      }
    }

    func previewControllerDidDismiss(_: QLPreviewController) {
      dismissController()
    }
  }
#endif
