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

#import "Composer.hh"
#import "Mandarin.h"
#import "vChewing-Swift.h"

static Mandarin::BopomofoReadingBuffer *PhoneticBuffer;

@implementation Composer

+ (BOOL)chkKeyValidity:(UniChar)charCode
{
    return PhoneticBuffer->isValidKey((char)charCode);
}

+ (BOOL)isBufferEmpty
{
    return PhoneticBuffer->isEmpty();
}

+ (void)clearBuffer
{
    PhoneticBuffer->clear();
}

+ (void)combineReadingKey:(UniChar)charCode
{
    PhoneticBuffer->combineKey((char)charCode);
}

+ (BOOL)checkWhetherToneMarkerConfirms
{
    return PhoneticBuffer->hasToneMarker();
}

+ (NSString *)getSyllableComposition
{
    return [NSString stringWithUTF8String:PhoneticBuffer->syllable().composedString().c_str()];
}

+ (void)doBackSpaceToBuffer
{
    PhoneticBuffer->backspace();
}

+ (NSString *)getComposition
{
    return [NSString stringWithUTF8String:PhoneticBuffer->composedString().c_str()];
}

+ (void)ensureParser
{
    if (PhoneticBuffer)
    {
        switch (mgrPrefs.mandarinParser)
        {
        case MandarinParserOfStandard:
            PhoneticBuffer->setKeyboardLayout(Mandarin::BopomofoKeyboardLayout::StandardLayout());
            break;
        case MandarinParserOfEten:
            PhoneticBuffer->setKeyboardLayout(Mandarin::BopomofoKeyboardLayout::ETenLayout());
            break;
        case MandarinParserOfHsu:
            PhoneticBuffer->setKeyboardLayout(Mandarin::BopomofoKeyboardLayout::HsuLayout());
            break;
        case MandarinParserOfEen26:
            PhoneticBuffer->setKeyboardLayout(Mandarin::BopomofoKeyboardLayout::ETen26Layout());
            break;
        case MandarinParserOfIBM:
            PhoneticBuffer->setKeyboardLayout(Mandarin::BopomofoKeyboardLayout::IBMLayout());
            break;
        case MandarinParserOfMiTAC:
            PhoneticBuffer->setKeyboardLayout(Mandarin::BopomofoKeyboardLayout::MiTACLayout());
            break;
        case MandarinParserOfFakeSeigyou:
            PhoneticBuffer->setKeyboardLayout(Mandarin::BopomofoKeyboardLayout::FakeSeigyouLayout());
            break;
        case MandarinParserOfHanyuPinyin:
            PhoneticBuffer->setKeyboardLayout(Mandarin::BopomofoKeyboardLayout::HanyuPinyinLayout());
            break;
        default:
            PhoneticBuffer->setKeyboardLayout(Mandarin::BopomofoKeyboardLayout::StandardLayout());
            mgrPrefs.mandarinParser = MandarinParserOfStandard;
        }
        PhoneticBuffer->clear();
    }
    else
    {
        PhoneticBuffer = new Mandarin::BopomofoReadingBuffer(Mandarin::BopomofoKeyboardLayout::StandardLayout());
    }
}

@end
