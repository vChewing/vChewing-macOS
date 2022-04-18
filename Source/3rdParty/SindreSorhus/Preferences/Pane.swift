// Copyright (c) 2018 and onwards Sindre Sorhus (MIT License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import SwiftUI

/// Represents a type that can be converted to `PreferencePane`.
///
/// Acts as type-eraser for `Preferences.Pane<T>`.
public protocol PreferencePaneConvertible {
	/**
	Convert `self` to equivalent `PreferencePane`.
	*/
	func asPreferencePane() -> PreferencePane
}

@available(macOS 10.15, *)
extension Preferences {
	/**
	Create a SwiftUI-based preference pane.

	SwiftUI equivalent of the `PreferencePane` protocol.
	*/
	public struct Pane<Content: View>: View, PreferencePaneConvertible {
		let identifier: PaneIdentifier
		let title: String
		let toolbarIcon: NSImage
		let content: Content

		public init(
			identifier: PaneIdentifier,
			title: String,
			toolbarIcon: NSImage,
			contentView: () -> Content
		) {
			self.identifier = identifier
			self.title = title
			self.toolbarIcon = toolbarIcon
			content = contentView()
		}

		public var body: some View { content }

		public func asPreferencePane() -> PreferencePane {
			PaneHostingController(pane: self)
		}
	}

	/**
	Hosting controller enabling `Preferences.Pane` to be used alongside AppKit `NSViewController`'s.
	*/
	public final class PaneHostingController<Content: View>: NSHostingController<Content>, PreferencePane {
		public let preferencePaneIdentifier: PaneIdentifier
		public let preferencePaneTitle: String
		public let toolbarItemIcon: NSImage

		init(
			identifier: PaneIdentifier,
			title: String,
			toolbarIcon: NSImage,
			content: Content
		) {
			preferencePaneIdentifier = identifier
			preferencePaneTitle = title
			toolbarItemIcon = toolbarIcon
			super.init(rootView: content)
		}

		public convenience init(pane: Pane<Content>) {
			self.init(
				identifier: pane.identifier,
				title: pane.title,
				toolbarIcon: pane.toolbarIcon,
				content: pane.content
			)
		}

		@available(*, unavailable)
		@objc
		dynamic required init?(coder _: NSCoder) {
			fatalError("init(coder:) has not been implemented")
		}
	}
}

@available(macOS 10.15, *)
extension View {
	/**
	Applies font and color for a label used for describing a preference.
	*/
	public func preferenceDescription() -> some View {
		font(.system(size: 11.0))
			// TODO: Use `.foregroundStyle` when targeting macOS 12.
			.foregroundColor(.secondary)
	}
}
