// Copyright (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
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

#import "KeyHandler.h"
#import "Mandarin.h"
#import "vChewing-Swift.h"
#import <string>

typedef Mandarin::BopomofoReadingBuffer PhoneticBuffer;

// NON-SWIFTIFIABLE
@implementation KeyHandler
{
    // the reading buffer that takes user input
    PhoneticBuffer *_bpmfReadingBuffer;
}

@synthesize delegate = _delegate;

// Not migrable as long as there's still ObjC++ components needed.
// Will deprecate this once Mandarin gets Swiftified.
- (instancetype)init
{
    self = [super init];
    if (self)
    {
        [self ensurePhoneticParser];
        [self setInputMode:ctlInputMethod.currentInputMode];
    }
    return self;
}

// NON-SWIFTIFIABLE: Mandarin
- (void)dealloc
{ // clean up everything
    if (_bpmfReadingBuffer)
        delete _bpmfReadingBuffer;
}

// MARK: - 目前到這裡了

#pragma mark - 必須用 ObjCpp 處理的部分: Mandarin

- (BOOL)chkKeyValidity:(UniChar)charCode
{
    return _bpmfReadingBuffer->isValidKey((char)charCode);
}

- (BOOL)isPhoneticReadingBufferEmpty
{
    return _bpmfReadingBuffer->isEmpty();
}

- (void)clearPhoneticReadingBuffer
{
    _bpmfReadingBuffer->clear();
}

- (void)combinePhoneticReadingBufferKey:(UniChar)charCode
{
    _bpmfReadingBuffer->combineKey((char)charCode);
}

- (BOOL)checkWhetherToneMarkerConfirmsPhoneticReadingBuffer
{
    return _bpmfReadingBuffer->hasToneMarker();
}

- (NSString *)getSyllableCompositionFromPhoneticReadingBuffer
{
    return [NSString stringWithUTF8String:_bpmfReadingBuffer->syllable().composedString().c_str()];
}

- (void)doBackSpaceToPhoneticReadingBuffer
{
    _bpmfReadingBuffer->backspace();
}

- (NSString *)getCompositionFromPhoneticReadingBuffer
{
    return [NSString stringWithUTF8String:_bpmfReadingBuffer->composedString().c_str()];
}

- (void)ensurePhoneticParser
{
    if (_bpmfReadingBuffer)
    {
        switch (mgrPrefs.mandarinParser)
        {
        case MandarinParserOfStandard:
            _bpmfReadingBuffer->setKeyboardLayout(Mandarin::BopomofoKeyboardLayout::StandardLayout());
            break;
        case MandarinParserOfEten:
            _bpmfReadingBuffer->setKeyboardLayout(Mandarin::BopomofoKeyboardLayout::ETenLayout());
            break;
        case MandarinParserOfHsu:
            _bpmfReadingBuffer->setKeyboardLayout(Mandarin::BopomofoKeyboardLayout::HsuLayout());
            break;
        case MandarinParserOfEen26:
            _bpmfReadingBuffer->setKeyboardLayout(Mandarin::BopomofoKeyboardLayout::ETen26Layout());
            break;
        case MandarinParserOfIBM:
            _bpmfReadingBuffer->setKeyboardLayout(Mandarin::BopomofoKeyboardLayout::IBMLayout());
            break;
        case MandarinParserOfMiTAC:
            _bpmfReadingBuffer->setKeyboardLayout(Mandarin::BopomofoKeyboardLayout::MiTACLayout());
            break;
        case MandarinParserOfFakeSeigyou:
            _bpmfReadingBuffer->setKeyboardLayout(Mandarin::BopomofoKeyboardLayout::FakeSeigyouLayout());
            break;
        case MandarinParserOfHanyuPinyin:
            _bpmfReadingBuffer->setKeyboardLayout(Mandarin::BopomofoKeyboardLayout::HanyuPinyinLayout());
            break;
        default:
            _bpmfReadingBuffer->setKeyboardLayout(Mandarin::BopomofoKeyboardLayout::StandardLayout());
            mgrPrefs.mandarinParser = MandarinParserOfStandard;
        }
    }
    else
    {
        _bpmfReadingBuffer = new Mandarin::BopomofoReadingBuffer(Mandarin::BopomofoKeyboardLayout::StandardLayout());
    }
}

#pragma mark - 威注音認為有必要單獨拿出來處理的部分，交給 Swift 則有些困難。

- (BOOL)isPrintable:(UniChar)charCode
{
    return isprint(charCode);
}

@end
