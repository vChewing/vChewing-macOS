//
// VTHorizontalCandidateView.m
//
// Copyright (c) 2021-2022 The vChewing Project.
// Copyright (c) 2011-2022 The OpenVanilla Project.
//
// Contributors:
//     Lukhnos Liu (@lukhnos) @ OpenVanilla
//     Shiki Suen (@ShikiSuen) @ vChewing
//
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following
// conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
//

#import "VTHorizontalCandidateView.h"

// use these instead of MIN/MAX macro to keep compilers happy with pedantic warnings on
NS_INLINE CGFloat min(CGFloat a, CGFloat b) { return a < b ? a : b; }
NS_INLINE CGFloat max(CGFloat a, CGFloat b) { return a > b ? a : b; }

@implementation VTHorizontalCandidateView

@synthesize highlightedIndex = _highlightedIndex;
@synthesize action = _action;
@synthesize target = _target;

static NSColor *colorFromRGBA(unsigned char r, unsigned char g, unsigned char b, unsigned char a)
{
    return [NSColor colorWithDeviceRed:(r/255.0f) green:(g/255.0f) blue:(b/255.0f) alpha:(a/255.0f)];
}

- (void)dealloc
{
    _keyLabels = nil;
    _displayedCandidates = nil;
    _keyLabelAttrDict = nil;
    _candidateAttrDict = nil;
    _elementWidths = nil;
}

- (void)setKeyLabels:(NSArray *)labels displayedCandidates:(NSArray *)candidates
{
    NSUInteger count = min([labels count], [candidates count]);
    _keyLabels = [labels subarrayWithRange:NSMakeRange(0, count)];
    _displayedCandidates = [candidates subarrayWithRange:NSMakeRange(0, count)];
    
    NSMutableArray *newWidths = [NSMutableArray array];
    
    NSSize baseSize = NSMakeSize(10240.0, 10240.0);
    for (NSUInteger index = 0; index < count; index++) {
        NSRect labelRect = [[_keyLabels objectAtIndex:index] boundingRectWithSize:baseSize options:NSStringDrawingUsesLineFragmentOrigin attributes:_keyLabelAttrDict];
        
        NSRect candidateRect = [[_displayedCandidates objectAtIndex:index] boundingRectWithSize:baseSize options:NSStringDrawingUsesLineFragmentOrigin attributes:_candidateAttrDict];
        
        CGFloat width = max(labelRect.size.width, candidateRect.size.width) + _cellPadding;
        [newWidths addObject:[NSNumber numberWithDouble:width]];
    }

    _elementWidths = newWidths;
}

- (void)setKeyLabelFont:(NSFont *)labelFont candidateFont:(NSFont *)candidateFont
{
    NSColor *clrCandidateText = colorFromRGBA(233,233,233,255);
    NSColor *clrCandidateTextIndex = colorFromRGBA(233,233,233,213);
    NSMutableParagraphStyle *paraStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    [paraStyle setAlignment:NSCenterTextAlignment];

    _keyLabelAttrDict = [NSDictionary dictionaryWithObjectsAndKeys:
                         labelFont, NSFontAttributeName,
                         paraStyle, NSParagraphStyleAttributeName,
                         clrCandidateTextIndex, NSForegroundColorAttributeName,
                          nil];
    _candidateAttrDict = [NSDictionary dictionaryWithObjectsAndKeys:
                           candidateFont, NSFontAttributeName,
                           paraStyle, NSParagraphStyleAttributeName,
                          clrCandidateText, NSForegroundColorAttributeName,
                           nil];
    
    CGFloat labelFontSize = [labelFont pointSize];
    CGFloat candidateFontSize = [candidateFont pointSize];
    CGFloat biggestSize = max(labelFontSize, candidateFontSize);
    
    _keyLabelHeight = ceil(labelFontSize * 1.20);
    _candidateTextHeight = ceil(candidateFontSize * 1.20);
    _cellPadding = ceil(biggestSize / 2.0);
}


- (NSSize)sizeForView
{
    NSSize result = NSMakeSize(0.0, 0.0);
    if ([_elementWidths count]) {
        for (NSNumber *w in _elementWidths) {
            result.width += [w doubleValue];
        }
        
        result.width += [_elementWidths count];
        result.height = _keyLabelHeight + _candidateTextHeight + 1.0;
    }
    
    return result;
}

- (BOOL)isFlipped
{
    return YES;
}

- (void)drawRect:(NSRect)dirtyRect
{
    NSColor *clrCandidateSelectedBG = [NSColor alternateSelectedControlColor];
    NSColor *clrCandidateSelectedText = colorFromRGBA(233,233,233,255);
    NSColor *clrCandidateWindowBorder = colorFromRGBA(255,255,255,75);
    NSColor *clrCandidateWindowBG = colorFromRGBA(28,28,28,255);
    NSColor *clrCandidateBG = colorFromRGBA(28,28,28,255);

    [self setWantsLayer: YES];
    [self.layer setBorderColor: [clrCandidateWindowBorder CGColor]];
    [self.layer setBorderWidth: 1];
    [self.layer setCornerRadius: 6];
    
    NSRect bounds = [self bounds];
    
    [clrCandidateWindowBG setFill];
    [NSBezierPath fillRect:bounds];

    NSUInteger count = [_elementWidths count];
    CGFloat accuWidth = 0.0;
    
    for (NSUInteger index = 0; index < count; index++) {
        NSDictionary *activeCandidateAttr = _candidateAttrDict;
        CGFloat currentWidth = [[_elementWidths objectAtIndex:index] doubleValue];
        NSRect labelRect = NSMakeRect(accuWidth, 0.0, currentWidth + 1.0, _keyLabelHeight + 1.0);
        NSRect candidateRect = NSMakeRect(accuWidth, _keyLabelHeight + 1.0, currentWidth + 1.0, _candidateTextHeight);

        if (index == _highlightedIndex) {
            [clrCandidateSelectedBG setFill];
        }
        else {
            [clrCandidateBG setFill];
        }
        
        [NSBezierPath fillRect:labelRect];
        [[_keyLabels objectAtIndex:index] drawInRect:labelRect withAttributes:_keyLabelAttrDict];
        
        if (index == _highlightedIndex) {
            [clrCandidateSelectedBG setFill];
            activeCandidateAttr = [_candidateAttrDict mutableCopy];
            [(NSMutableDictionary *)activeCandidateAttr setObject:clrCandidateSelectedText forKey:NSForegroundColorAttributeName];
        }
        else {
            [clrCandidateBG setFill];
        }
        
        [NSBezierPath fillRect:candidateRect];
        [[_displayedCandidates objectAtIndex:index] drawInRect:candidateRect withAttributes:activeCandidateAttr];
        
        accuWidth += currentWidth + 1.0;
    }
}

- (NSUInteger)findHitIndex:(NSEvent *)theEvent
{
    NSUInteger result = NSUIntegerMax;
    
    NSPoint location = [self convertPoint:[theEvent locationInWindow] toView:nil];
    if (!NSPointInRect(location, [self bounds])) {
        return result;
    }
    
    NSUInteger count = [_elementWidths count];
    CGFloat accuWidth = 0.0;
    for (NSUInteger index = 0; index < count; index++) {
        CGFloat currentWidth = [[_elementWidths objectAtIndex:index] doubleValue];

        if (location.x >= accuWidth && location.x <= accuWidth + currentWidth) {
            result = index;
            break;
        }
        accuWidth += currentWidth;
    }
    
    return result;
}

- (void)mouseDown:(NSEvent *)theEvent
{
    NSUInteger newIndex = [self findHitIndex:theEvent];
    _trackingHighlightedIndex = _highlightedIndex;

    if (newIndex != NSUIntegerMax) {
        _highlightedIndex = newIndex;
        [self setNeedsDisplay:YES];
    }
}

- (void)mouseUp:(NSEvent *)theEvent
{
    NSUInteger newIndex = [self findHitIndex:theEvent];
    BOOL triggerAction = NO;

    if (newIndex == _highlightedIndex) {
        triggerAction = YES;
    }
    else {
        _highlightedIndex = _trackingHighlightedIndex;
    }

    _trackingHighlightedIndex = 0;
    [self setNeedsDisplay:YES];

#       pragma clang diagnostic push
#       pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    if (triggerAction && _target && _action) {
        [_target performSelector:_action withObject:self];
    }
#       pragma clang diagnostic pop
}

@end
