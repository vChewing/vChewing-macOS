//
//  Ref: https://stackoverflow.com/a/71058587/4162914
//  License: https://creativecommons.org/licenses/by-sa/4.0/
//

import SwiftUI

// MARK: - NSComboBox
// Ref: https://stackoverflow.com/a/71058587/4162914
@available(macOS 11.0, *)
struct ComboBox: NSViewRepresentable {
	// The items that will show up in the pop-up menu:
	var items: [String]

	// The property on our parent view that gets synced to the current
	// stringValue of the NSComboBox, whether the user typed it in or
	// selected it from the list:
	@Binding var text: String

	func makeCoordinator() -> Coordinator {
		return Coordinator(self)
	}

	func makeNSView(context: Context) -> NSComboBox {
		let comboBox = NSComboBox()
		comboBox.usesDataSource = false
		comboBox.completes = false
		comboBox.delegate = context.coordinator
		comboBox.intercellSpacing = NSSize(width: 0.0, height: 10.0)
		return comboBox
	}

	func updateNSView(_ nsView: NSComboBox, context: Context) {
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

	class Coordinator: NSObject, NSComboBoxDelegate {
		var parent: ComboBox
		var ignoreSelectionChanges: Bool = false

		init(_ parent: ComboBox) {
			self.parent = parent
		}

		func comboBoxSelectionDidChange(_ notification: Notification) {
			if !ignoreSelectionChanges,
				let box: NSComboBox = notification.object as? NSComboBox,
				let newStringValue: String = box.objectValueOfSelectedItem as? String
			{
				parent.text = newStringValue
			}
		}

		func controlTextDidEndEditing(_ obj: Notification) {
			if let textField = obj.object as? NSTextField {
				parent.text = textField.stringValue
			}
		}
	}
}
