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

import Foundation

class SymbolNode {
  var title: String
  var children: [SymbolNode]?

  init(_ title: String, _ children: [SymbolNode]? = nil) {
    self.title = title
    self.children = children
  }

  init(_ title: String, symbols: String) {
    self.title = title
    children = Array(symbols).map { SymbolNode(String($0), nil) }
  }

  static func parseUserSymbolNodeData() {
    let url = mgrLangModel.userSymbolNodeDataURL()
    // 這兩個變數單獨拿出來，省得每次都重建還要浪費算力。
    var arrLines = [String.SubSequence]()
    var fieldSlice = [Substring.SubSequence]()
    var arrChildren = [SymbolNode]()
    do {
      arrLines = try String(contentsOfFile: url.path, encoding: .utf8).split(separator: "\n")
      for strLine in arrLines.lazy.filter({ !$0.isEmpty }) {
        fieldSlice = strLine.split(separator: "=")
        switch fieldSlice.count {
          case 1: arrChildren.append(.init(String(fieldSlice[0])))
          case 2: arrChildren.append(.init(String(fieldSlice[0]), symbols: .init(fieldSlice[1])))
          default: break
        }
      }
      if arrChildren.isEmpty {
        root = defaultSymbolRoot
      } else {
        root = .init("/", arrChildren)
      }
    } catch {
      root = defaultSymbolRoot
    }
  }

  // MARK: - Static data.

  static let catCommonSymbols = String(
    format: NSLocalizedString("catCommonSymbols", comment: ""))
  static let catHoriBrackets = String(
    format: NSLocalizedString("catHoriBrackets", comment: ""))
  static let catVertBrackets = String(
    format: NSLocalizedString("catVertBrackets", comment: ""))
  static let catGreekLetters = String(
    format: NSLocalizedString("catGreekLetters", comment: ""))
  static let catMathSymbols = String(
    format: NSLocalizedString("catMathSymbols", comment: ""))
  static let catCurrencyUnits = String(
    format: NSLocalizedString("catCurrencyUnits", comment: ""))
  static let catSpecialSymbols = String(
    format: NSLocalizedString("catSpecialSymbols", comment: ""))
  static let catUnicodeSymbols = String(
    format: NSLocalizedString("catUnicodeSymbols", comment: ""))
  static let catCircledKanjis = String(
    format: NSLocalizedString("catCircledKanjis", comment: ""))
  static let catCircledKataKana = String(
    format: NSLocalizedString("catCircledKataKana", comment: ""))
  static let catBracketKanjis = String(
    format: NSLocalizedString("catBracketKanjis", comment: ""))
  static let catSingleTableLines = String(
    format: NSLocalizedString("catSingleTableLines", comment: ""))
  static let catDoubleTableLines = String(
    format: NSLocalizedString("catDoubleTableLines", comment: ""))
  static let catFillingBlocks = String(
    format: NSLocalizedString("catFillingBlocks", comment: ""))
  static let catLineSegments = String(
    format: NSLocalizedString("catLineSegments", comment: ""))

  private(set) static var root: SymbolNode = .init("/")

  private static let defaultSymbolRoot: SymbolNode = .init(
    "/",
    [
      SymbolNode("｀"),
      SymbolNode(catCommonSymbols, symbols: "，、。．？！；：‧‥﹐﹒˙·‘’“”〝〞‵′〃～＄％＠＆＃＊"),
      SymbolNode(catHoriBrackets, symbols: "（）「」〔〕｛｝〈〉『』《》【】﹙﹚﹝﹞﹛﹜"),
      SymbolNode(catVertBrackets, symbols: "︵︶﹁﹂︹︺︷︸︿﹀﹃﹄︽︾︻︼"),
      SymbolNode(
        catGreekLetters, symbols: "αβγδεζηθικλμνξοπρστυφχψωΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩ"
      ),
      SymbolNode(catMathSymbols, symbols: "＋－×÷＝≠≒∞±√＜＞﹤﹥≦≧∩∪ˇ⊥∠∟⊿㏒㏑∫∮∵∴╳﹢"),
      SymbolNode(catCurrencyUnits, symbols: "$€¥¢£₽₨₩฿₺₮₱₭₴₦৲৳૱௹﷼₹₲₪₡₫៛₵₢₸₤₳₥₠₣₰₧₯₶₷"),
      SymbolNode(catSpecialSymbols, symbols: "↑↓←→↖↗↙↘↺⇧⇩⇦⇨⇄⇆⇅⇵↻◎○●⊕⊙※△▲☆★◇◆□■▽▼§￥〒￠￡♀♂↯"),
      SymbolNode(catUnicodeSymbols, symbols: "♨☀☁☂☃♠♥♣♦♩♪♫♬☺☻"),
      SymbolNode(catCircledKanjis, symbols: "㊟㊞㊚㊛㊊㊋㊌㊍㊎㊏㊐㊑㊒㊓㊔㊕㊖㊗︎㊘㊙︎㊜㊝㊠㊡㊢㊣㊤㊥㊦㊧㊨㊩㊪㊫㊬㊭㊮㊯㊰🈚︎🈯︎"),
      SymbolNode(
        catCircledKataKana, symbols: "㋐㋑㋒㋓㋔㋕㋖㋗㋘㋙㋚㋛㋜㋝㋞㋟㋠㋡㋢㋣㋤㋥㋦㋧㋨㋩㋪㋫㋬㋭㋮㋯㋰㋱㋲㋳㋴㋵㋶㋷㋸㋹㋺㋻㋼㋾"
      ),
      SymbolNode(catBracketKanjis, symbols: "㈪㈫㈬㈭㈮㈯㈰㈱㈲㈳㈴㈵㈶㈷㈸㈹㈺㈻㈼㈽㈾㈿㉀㉁㉂㉃"),
      SymbolNode(catSingleTableLines, symbols: "├─┼┴┬┤┌┐╞═╪╡│▕└┘╭╮╰╯"),
      SymbolNode(catDoubleTableLines, symbols: "╔╦╗╠═╬╣╓╥╖╒╤╕║╚╩╝╟╫╢╙╨╜╞╪╡╘╧╛"),
      SymbolNode(catFillingBlocks, symbols: "＿ˍ▁▂▃▄▅▆▇█▏▎▍▌▋▊▉◢◣◥◤"),
      SymbolNode(catLineSegments, symbols: "﹣﹦≡｜∣∥–︱—︳╴¯￣﹉﹊﹍﹎﹋﹌﹏︴∕﹨╱╲／＼"),
    ]
  )
}
