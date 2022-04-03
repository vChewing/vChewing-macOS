// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service
marks, or product names of Contributor, except as required to fulfill notice
requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import Cocoa

class Document: NSDocument {

	@objc var content = Content(contentString: "")
	var contentViewController: ViewController!

	override init() {
		super.init()
		// Add your subclass-specific initialization here.
	}

	// MARK: - Enablers

	// This enables auto save.
	override class var autosavesInPlace: Bool {
		return true
	}

	// This enables asynchronous-writing.
	override func canAsynchronouslyWrite(
		to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType
	) -> Bool {
		return true
	}

	// This enables asynchronous reading.
	override class func canConcurrentlyReadDocuments(ofType: String) -> Bool {
		return ofType == "public.plain-text"
	}

	// MARK: - User Interface

	/// - Tag: makeWindowControllersExample
	override func makeWindowControllers() {
		// Returns the storyboard that contains your document window.
		let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
		if let windowController =
			storyboard.instantiateController(
				withIdentifier: NSStoryboard.SceneIdentifier("Document Window Controller"))
			as? NSWindowController
		{
			addWindowController(windowController)

			// Set the view controller's represented object as your document.
			if let contentVC = windowController.contentViewController as? ViewController {
				contentVC.representedObject = content
				contentViewController = contentVC
			}
		}
	}

	// MARK: - Reading and Writing

	/// - Tag: readExample
	override func read(from data: Data, ofType typeName: String) throws {
		var strToDealWith = String(decoding: data, as: UTF8.self)
		strToDealWith.formatConsolidate(cnvHYPYtoBPMF: false)
		let processedIncomingData = Data(strToDealWith.utf8)
		content.read(from: processedIncomingData)
	}

	/// - Tag: writeExample
	override func data(ofType typeName: String) throws -> Data {
		var strToDealWith = content.contentString
		strToDealWith.formatConsolidate(cnvHYPYtoBPMF: true)
		let outputData = Data(strToDealWith.utf8)
		return outputData
	}

	// MARK: - Printing

	func thePrintInfo() -> NSPrintInfo {
		let thePrintInfo = NSPrintInfo()
		thePrintInfo.horizontalPagination = .fit
		thePrintInfo.isHorizontallyCentered = false
		thePrintInfo.isVerticallyCentered = false

		// One inch margin all the way around.
		thePrintInfo.leftMargin = 72.0
		thePrintInfo.rightMargin = 72.0
		thePrintInfo.topMargin = 72.0
		thePrintInfo.bottomMargin = 72.0

		printInfo.dictionary().setObject(
			NSNumber(value: true),
			forKey: NSPrintInfo.AttributeKey.headerAndFooter as NSCopying)

		return thePrintInfo
	}

	@objc
	func printOperationDidRun(
		_ printOperation: NSPrintOperation, success: Bool, contextInfo: UnsafeMutableRawPointer?
	) {
		// Printing finished...
	}

	@IBAction override func printDocument(_ sender: Any?) {
		// Print the NSTextView.

		// Create a copy to manipulate for printing.
		let pageSize = NSSize(
			width: (printInfo.paperSize.width), height: (printInfo.paperSize.height))
		let textView = NSTextView(
			frame: NSRect(x: 0.0, y: 0.0, width: pageSize.width, height: pageSize.height))

		// Make sure we print on a white background.
		textView.appearance = NSAppearance(named: .aqua)

		// Copy the attributed string.
		textView.textStorage?.append(NSAttributedString(string: content.contentString))

		let printOperation = NSPrintOperation(view: textView)
		printOperation.runModal(
			for: windowControllers[0].window!,
			delegate: self,
			didRun: #selector(printOperationDidRun(_:success:contextInfo:)), contextInfo: nil)
	}

}
