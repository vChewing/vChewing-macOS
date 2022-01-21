/* 
 *  VerticalCandidateController.swift
 *  
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

import Cocoa

fileprivate class VerticalCandidateView: NSView {
    var highlightedIndex: UInt = 0
    var action: Selector?
    weak var target: AnyObject?

    private var keyLabels: [String] = []
    private var displayedCandidates: [String] = []
    private var dispCandidatesWithLabels: [String] = []
    private var keyLabelHeight: CGFloat = 0
    private var keyLabelWidth: CGFloat = 0
    private var candidateTextHeight: CGFloat = 0
    private var cellPadding: CGFloat = 0
    private var keyLabelAttrDict: [NSAttributedString.Key: AnyObject] = [:]
    private var candidateAttrDict: [NSAttributedString.Key: AnyObject] = [:]
    private var candidateWithLabelAttrDict: [NSAttributedString.Key: AnyObject] = [:]
    private var windowWidth: CGFloat = 0
    private var elementWidths: [CGFloat] = []
    private var elementHeights: [CGFloat] = []
    private var trackingHighlightedIndex: UInt = UInt.max

    override var isFlipped: Bool {
        true
    }

    var sizeForView: NSSize {
        var result = NSSize.zero

        if !elementWidths.isEmpty {
            result.width = windowWidth
            result.height = elementHeights.reduce(0, +)
        }
        return result
    }

    @objc(setKeyLabels:displayedCandidates:)
    func set(keyLabels labels: [String], displayedCandidates candidates: [String]) {
        let count = min(labels.count, candidates.count)
        keyLabels = Array(labels[0..<count])
        displayedCandidates = Array(candidates[0..<count])
        dispCandidatesWithLabels = zip(keyLabels,displayedCandidates).map() {$0 + $1}

        var newWidths = [CGFloat]()
        var calculatedWindowWidth = CGFloat()
        var newHeights = [CGFloat]()
        let baseSize = NSSize(width: 10240.0, height: 10240.0)
        for index in 0..<count {
            let rctCandidate = (dispCandidatesWithLabels[index] as NSString).boundingRect(with: baseSize, options: .usesLineFragmentOrigin, attributes: candidateWithLabelAttrDict)
            let cellWidth = rctCandidate.size.width + cellPadding
            let cellHeight = rctCandidate.size.height + cellPadding
            if (calculatedWindowWidth < rctCandidate.size.width) {
                calculatedWindowWidth = rctCandidate.size.width
            }
            newWidths.append(cellWidth)
            newHeights.append(cellHeight)
        }
        elementWidths = newWidths
        elementHeights = newHeights
        windowWidth = calculatedWindowWidth + cellPadding;
    }

    @objc(setKeyLabelFont:candidateFont:)
    func set(keyLabelFont labelFont: NSFont, candidateFont: NSFont) {
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.setParagraphStyle(NSParagraphStyle.default)
        paraStyle.alignment = .left
        
        candidateWithLabelAttrDict = [.font: candidateFont,
                             .paragraphStyle: paraStyle,
                             .foregroundColor: NSColor.labelColor] // We still need this dummy section to make sure the space occupations of the candidates are correct.
        
        keyLabelAttrDict = [.font: labelFont,
                            .paragraphStyle: paraStyle,
                            .foregroundColor: NSColor.secondaryLabelColor] // Candidate phrase text color
        candidateAttrDict = [.font: candidateFont,
                             .paragraphStyle: paraStyle,
                             .foregroundColor: NSColor.labelColor] // Candidate index text color
        let labelFontSize = labelFont.pointSize
        let candidateFontSize = candidateFont.pointSize
        let biggestSize = max(labelFontSize, candidateFontSize)
        keyLabelWidth = ceil(labelFontSize)
        keyLabelHeight = ceil(labelFontSize * 1.20)
        candidateTextHeight = ceil(candidateFontSize * 1.20)
        cellPadding = ceil(biggestSize / 2.0)
    }

    override func draw(_ dirtyRect: NSRect) {
        
        // Give a standalone layer to the candidate list panel
        self.wantsLayer = true
        self.layer?.borderColor = NSColor.selectedMenuItemTextColor.withAlphaComponent(0.30).cgColor
        self.layer?.borderWidth = 1.0
        self.layer?.cornerRadius = 6.0
        
        let bounds = self.bounds
        NSColor.controlBackgroundColor.setFill() // Candidate list panel base background
        NSBezierPath.fill(bounds)

        if #available(macOS 10.14, *) {
            NSColor.separatorColor.setStroke()
        } else {
            NSColor.darkGray.setStroke()
        }

        NSBezierPath.strokeLine(from: NSPoint(x: bounds.size.width, y: 0.0), to: NSPoint(x: bounds.size.width, y: bounds.size.height))

        var accuHeight: CGFloat = 0
        for index in 0..<elementHeights.count {
            let currentHeight = elementHeights[index]
            let rctCandidateArea = NSRect(x: 0.0, y: accuHeight, width: windowWidth, height: candidateTextHeight + cellPadding)
            let rctLabel = NSRect(x: cellPadding / 2 - 1, y: accuHeight + cellPadding / 2, width: keyLabelWidth, height: candidateTextHeight)
            let rctCandidatePhrase = NSRect(x: cellPadding / 2 - 1 + keyLabelWidth, y: accuHeight + cellPadding / 2 - 1, width: windowWidth - keyLabelWidth, height: candidateTextHeight)

            var activeCandidateIndexAttr = keyLabelAttrDict
            var activeCandidateAttr = candidateAttrDict
            if index == highlightedIndex {
                NSColor.alternateSelectedControlColor.setFill() // The background color of the highlightened candidate
                activeCandidateIndexAttr[.foregroundColor] = NSColor.selectedMenuItemTextColor.withAlphaComponent(0.84) // The index text color of the highlightened candidate
                activeCandidateAttr[.foregroundColor] = NSColor.selectedMenuItemTextColor // The phrase text color of the highlightened candidate
            } else {
                NSColor.controlBackgroundColor.setFill()
            }
            NSBezierPath.fill(rctCandidateArea)
            (keyLabels[index] as NSString).draw(in: rctLabel, withAttributes: activeCandidateIndexAttr)
            (displayedCandidates[index] as NSString).draw(in: rctCandidatePhrase, withAttributes: activeCandidateAttr)
            accuHeight += currentHeight
        }
    }

    private func findHitIndex(event: NSEvent) -> UInt? {
        let location = convert(event.locationInWindow, to: nil)
        if !NSPointInRect(location, self.bounds) {
            return nil
        }
        var accuHeight: CGFloat = 0.0
        for index in 0..<elementHeights.count {
            let currentHeight = elementHeights[index]

            if location.y >= accuHeight && location.y <= accuHeight + currentHeight {
                return UInt(index)
            }
            accuHeight += currentHeight
        }
        return nil

    }

    override func mouseUp(with event: NSEvent) {
        trackingHighlightedIndex = highlightedIndex
        guard let newIndex = findHitIndex(event: event) else {
            return
        }
        highlightedIndex = newIndex
        self.setNeedsDisplay(self.bounds)
    }

    override func mouseDown(with event: NSEvent) {
        guard let newIndex = findHitIndex(event: event) else {
            return
        }
        var triggerAction = false
        if newIndex == highlightedIndex {
            triggerAction = true
        } else {
            highlightedIndex = trackingHighlightedIndex
        }

        trackingHighlightedIndex = 0
        self.setNeedsDisplay(self.bounds)
        if triggerAction {
            if let target = target as? NSObject, let action = action {
                target.perform(action, with: self)
            }
        }
    }
}

@objc(VTVerticalCandidateController)
public class VerticalCandidateController: CandidateController {
    private var candidateView: VerticalCandidateView
    private var prevPageButton: NSButton
    private var nextPageButton: NSButton
    private var currentPage: UInt = 0

    public init() {
        var contentRect = NSRect(x: 128.0, y: 128.0, width: 0.0, height: 0.0)
        let styleMask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel]
        let panel = NSPanel(contentRect: contentRect, styleMask: styleMask, backing: .buffered, defer: false)
        panel.level = NSWindow.Level(Int(kCGPopUpMenuWindowLevel) + 1)
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = NSColor.clear // Transparentify everything outside of the candidate list panel
        
        contentRect.origin = NSPoint.zero
        candidateView = VerticalCandidateView(frame: contentRect)
        panel.contentView?.addSubview(candidateView)
        
        contentRect.size = NSSize(width: 20.0, height: 15.0) // Reduce the button width
        nextPageButton = NSButton(frame: contentRect)
        nextPageButton.setButtonType(.momentaryLight)
        nextPageButton.bezelStyle = .shadowlessSquare
        nextPageButton.wantsLayer = true
        nextPageButton.layer?.masksToBounds = true
        nextPageButton.layer?.borderColor = NSColor.clear.cgColor // Attempt to remove the system default layer border color - step 1
        nextPageButton.layer?.borderWidth = 0.0 // Attempt to remove the system default layer border color - step 2
        nextPageButton.layer?.backgroundColor = NSColor.black.cgColor // Button Background Color. Otherwise the button will be half-transparent in macOS Monterey Dark Mode.
        nextPageButton.attributedTitle = NSMutableAttributedString(string: "➡︎") // Next Page Arrow
        prevPageButton = NSButton(frame: contentRect)
        prevPageButton.setButtonType(.momentaryLight)
        prevPageButton.bezelStyle = .shadowlessSquare
        prevPageButton.wantsLayer = true
        prevPageButton.layer?.masksToBounds = true
        prevPageButton.layer?.borderColor = NSColor.clear.cgColor // Attempt to remove the system default layer border color - step 1
        prevPageButton.layer?.borderWidth = 0.0 // Attempt to remove the system default layer border color - step 2
        prevPageButton.layer?.backgroundColor = NSColor.black.cgColor // Button Background Color. Otherwise the button will be half-transparent in macOS Monterey Dark Mode.
        prevPageButton.attributedTitle = NSMutableAttributedString(string: "⬅︎") // Previous Page Arrow
        panel.contentView?.addSubview(nextPageButton)
        panel.contentView?.addSubview(prevPageButton)

        super.init(window: panel)

        candidateView.target = self
        candidateView.action = #selector(candidateViewMouseDidClick(_:))

        nextPageButton.target = self
        nextPageButton.action = #selector(pageButtonAction(_:))

        prevPageButton.target = self
        prevPageButton.action = #selector(pageButtonAction(_:))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func reloadData() {
        candidateView.highlightedIndex = 0
        currentPage = 0
        layoutCandidateView()
    }

    public override func showNextPage() -> Bool {
        guard delegate != nil else {
            return false
        }

        if currentPage + 1 >= pageCount {
            return false
        }

        currentPage += 1
        candidateView.highlightedIndex = 0
        layoutCandidateView()
        return true
    }

    public override func showPreviousPage() -> Bool {
        guard delegate != nil else {
            return false
        }

        if currentPage == 0 {
            return false
        }

        currentPage -= 1
        candidateView.highlightedIndex = 0
        layoutCandidateView()
        return true
    }

    public override func highlightNextCandidate() -> Bool {
        guard let delegate = delegate else {
            return false
        }

        let currentIndex = selectedCandidateIndex
        if currentIndex + 1 >= delegate.candidateCountForController(self) {
            return false
        }
        selectedCandidateIndex = currentIndex + 1
        return true
    }

    public override func highlightPreviousCandidate() -> Bool {
        guard delegate != nil else {
            return false
        }

        let currentIndex = selectedCandidateIndex
        if currentIndex == 0 {
            return false
        }

        selectedCandidateIndex = currentIndex - 1
        return true
    }

    public override func candidateIndexAtKeyLabelIndex(_ index: UInt) -> UInt {
        guard let delegate = delegate else {
            return UInt.max
        }

        let result = currentPage * UInt(keyLabels.count) + index
        return result < delegate.candidateCountForController(self) ? result : UInt.max
    }

    public override var selectedCandidateIndex: UInt {
        get {
            currentPage * UInt(keyLabels.count) + candidateView.highlightedIndex
        }
        set {
            guard let delegate = delegate else {
                return
            }
            let keyLabelCount = UInt(keyLabels.count)
            if newValue < delegate.candidateCountForController(self) {
                currentPage = newValue / keyLabelCount
                candidateView.highlightedIndex = newValue % keyLabelCount
                layoutCandidateView()
            }
        }
    }
}

extension VerticalCandidateController {

    private var pageCount: UInt {
        guard let delegate = delegate else {
            return 0
        }
        let totalCount = delegate.candidateCountForController(self)
        let keyLabelCount = UInt(keyLabels.count)
        return totalCount / keyLabelCount + ((totalCount % keyLabelCount) != 0 ? 1 : 0)
    }

    private func layoutCandidateView() {
        guard let delegate = delegate else {
            return
        }

        candidateView.set(keyLabelFont: keyLabelFont, candidateFont: candidateFont)
        var candidates = [String]()
        let count = delegate.candidateCountForController(self)
        let keyLabelCount = UInt(keyLabels.count)

        let begin = currentPage * keyLabelCount
        for index in begin..<min(begin + keyLabelCount, count) {
            let candidate = delegate.candidateController(self, candidateAtIndex: index)
            candidates.append(candidate)
        }
        candidateView.set(keyLabels: keyLabels, displayedCandidates: candidates)
        var newSize = candidateView.sizeForView
        var frameRect = candidateView.frame
        frameRect.size = newSize
        candidateView.frame = frameRect

        if pageCount > 1 {
            var buttonRect = nextPageButton.frame
            let spacing:CGFloat = 0.0

            // buttonRect.size.height = floor(candidateTextHeight + cellPadding / 2)

            let buttonOriginY = (newSize.height - (buttonRect.size.height * 2.0 + spacing)) // / 2.0
            buttonRect.origin = NSPoint(x: newSize.width + 8.0, y: buttonOriginY)
            nextPageButton.frame = buttonRect

            buttonRect.origin = NSPoint(x: newSize.width + 8.0, y: buttonOriginY + buttonRect.size.height + spacing)
            prevPageButton.frame = buttonRect

            newSize.width += 52.0
            nextPageButton.isHidden = false
            prevPageButton.isHidden = false
        } else {
            nextPageButton.isHidden = true
            prevPageButton.isHidden = true
        }

        frameRect = window?.frame ?? NSRect.zero

        let topLeftPoint = NSMakePoint(frameRect.origin.x, frameRect.origin.y + frameRect.size.height)
        frameRect.size = newSize
        frameRect.origin = NSMakePoint(topLeftPoint.x, topLeftPoint.y - frameRect.size.height)
        self.window?.setFrame(frameRect, display: false)
        candidateView.setNeedsDisplay(candidateView.bounds)
    }

    @objc fileprivate func pageButtonAction(_ sender: Any) {
        guard let sender = sender as? NSButton else {
            return
        }
        if sender == nextPageButton {
            _ = showNextPage()
        } else if sender == prevPageButton {
            _ = showPreviousPage()
        }
    }

    @objc fileprivate func candidateViewMouseDidClick(_ sender: Any) {
        delegate?.candidateController(self, didSelectCandidateAtIndex: selectedCandidateIndex)
    }

}
