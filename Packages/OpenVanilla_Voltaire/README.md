# Voltaire

Voltaire is a UI component replacement for Apple's InputMethodKit (IMK). The
built-in candidate UI has a limited interaction model and is not very
extensible nor customizable.

The project also comes with a test app that demonstrates the features of the
UI component.

Voltaire MK3 provides following new features comparing to MK1 and MK2:

1. A brand-new candidate window design conforming to the latest macOS UI design style, plus a floating label indicating the current page number of candidates (a frequently-asked feature by vChewing users).
2. One class for both vertical and horizontal display purposes. This can be specified as a parameter on init().

3. Can specify whether default candidate fonts conform to MOE glyphs standard or continental glyphs standard, requiring macOS 12 Monterey or later.
4. Can specify whether page buttons are shown.

Regarding the horizontal and vertical layout:

1. It is recommended to use init() in lieu of directly changing the layout variable since the latter doesn't redraw page buttons correctly.
2. Vertical candidate mode doesn't support scrolling. This is a deliberated design.

---

Copyrights:
```
- (c) 2022 Shiki Suen for all modifications introduced to Voltaire MK3.
- (c) 2021 Zonble Yang for rewriting Voltaire MK2 in Swift.
- (c) 2012 Lukhnos Liu for Voltaire MK1 development in Objective-C.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
