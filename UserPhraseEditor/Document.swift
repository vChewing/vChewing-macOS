// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

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
    true
  }

  // This enables asynchronous-writing.
  override func canAsynchronouslyWrite(
    to _: URL, ofType _: String, for _: NSDocument.SaveOperationType
  ) -> Bool {
    true
  }

  // This enables asynchronous reading.
  override class func canConcurrentlyReadDocuments(ofType: String) -> Bool {
    ofType == "public.plain-text"
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
  override func read(from data: Data, ofType _: String) throws {
    var strToDealWith = String(decoding: data, as: UTF8.self)
    strToDealWith.formatConsolidate()
    let processedIncomingData = Data(strToDealWith.utf8)
    content.read(from: processedIncomingData)
  }

  /// - Tag: writeExample
  override func data(ofType _: String) throws -> Data {
    var strToDealWith = content.contentString
    strToDealWith.formatConsolidate()
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
      forKey: NSPrintInfo.AttributeKey.headerAndFooter as NSCopying
    )

    return thePrintInfo
  }

  @objc
  func printOperationDidRun(
    _: NSPrintOperation, success _: Bool, contextInfo _: UnsafeMutableRawPointer?
  ) {
    // Printing finished...
  }

  @IBAction override func printDocument(_: Any?) {
    // Print the NSTextView.

    // Create a copy to manipulate for printing.
    let pageSize = NSSize(
      width: printInfo.paperSize.width, height: printInfo.paperSize.height
    )
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
      didRun: #selector(printOperationDidRun(_:success:contextInfo:)), contextInfo: nil
    )
  }
}
