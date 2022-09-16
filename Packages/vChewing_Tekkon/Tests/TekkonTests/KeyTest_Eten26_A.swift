// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import XCTest

@testable import Tekkon

extension TekkonTestsKeyboardArrangments {
  func testETen26KeysA() throws {
    var composer = Tekkon.Composer(arrange: .ofETen26)
    XCTAssertEqual(composer.convertSequenceToRawComposition("ket"), "ㄎㄧㄤ")
    // XCTAssertEqual(composer.convertSequenceToRawComposition("vezf"), "ㄍㄧㄠˊ")
    // XCTAssertEqual(composer.convertSequenceToRawComposition("ven"), "ㄍㄧㄣ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("betf"), "ㄅㄧㄤˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("betk"), "ㄅㄧㄤˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dxt"), "ㄉㄨㄤ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("ba"), "ㄅㄚ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("baf"), "ㄅㄚˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("baj"), "ㄅㄚˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bak"), "ㄅㄚˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bad"), "ㄅㄚ˙")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bo"), "ㄅㄛ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bof"), "ㄅㄛˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("boj"), "ㄅㄛˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bok"), "ㄅㄛˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bod"), "ㄅㄛ˙")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bi"), "ㄅㄞ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bif"), "ㄅㄞˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bij"), "ㄅㄞˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bik"), "ㄅㄞˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bid"), "ㄅㄞ˙")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bq"), "ㄅㄟ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bqj"), "ㄅㄟˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bqk"), "ㄅㄟˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bqd"), "ㄅㄟ˙")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bz"), "ㄅㄠ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bzf"), "ㄅㄠˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bzj"), "ㄅㄠˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bzk"), "ㄅㄠˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bm"), "ㄅㄢ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bmj"), "ㄅㄢˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bmk"), "ㄅㄢˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bn"), "ㄅㄣ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bnj"), "ㄅㄣˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bnk"), "ㄅㄣˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bt"), "ㄅㄤ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("btj"), "ㄅㄤˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("btk"), "ㄅㄤˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bl"), "ㄅㄥ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("blf"), "ㄅㄥˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("blj"), "ㄅㄥˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("blk"), "ㄅㄥˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("be"), "ㄅㄧ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bef"), "ㄅㄧˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bej"), "ㄅㄧˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bek"), "ㄅㄧˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bew"), "ㄅㄧㄝ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bewf"), "ㄅㄧㄝˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bewj"), "ㄅㄧㄝˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bewk"), "ㄅㄧㄝˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bez"), "ㄅㄧㄠ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bezj"), "ㄅㄧㄠˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bezk"), "ㄅㄧㄠˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bem"), "ㄅㄧㄢ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bemf"), "ㄅㄧㄢˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bemj"), "ㄅㄧㄢˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bemk"), "ㄅㄧㄢˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("ben"), "ㄅㄧㄣ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("benj"), "ㄅㄧㄣˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("benk"), "ㄅㄧㄣˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bel"), "ㄅㄧㄥ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("belj"), "ㄅㄧㄥˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("belk"), "ㄅㄧㄥˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bx"), "ㄅㄨ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bxf"), "ㄅㄨˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bxj"), "ㄅㄨˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("bxk"), "ㄅㄨˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pa"), "ㄆㄚ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("paf"), "ㄆㄚˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("paj"), "ㄆㄚˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pak"), "ㄆㄚˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pad"), "ㄆㄚ˙")
    XCTAssertEqual(composer.convertSequenceToRawComposition("po"), "ㄆㄛ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pof"), "ㄆㄛˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("poj"), "ㄆㄛˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pok"), "ㄆㄛˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pi"), "ㄆㄞ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pif"), "ㄆㄞˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pij"), "ㄆㄞˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pik"), "ㄆㄞˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pq"), "ㄆㄟ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pqf"), "ㄆㄟˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pqj"), "ㄆㄟˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pqk"), "ㄆㄟˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pz"), "ㄆㄠ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pzf"), "ㄆㄠˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pzj"), "ㄆㄠˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pzk"), "ㄆㄠˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pp"), "ㄆㄡ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("ppf"), "ㄆㄡˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("ppj"), "ㄆㄡˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("ppk"), "ㄆㄡˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pm"), "ㄆㄢ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pmf"), "ㄆㄢˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pmj"), "ㄆㄢˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pmk"), "ㄆㄢˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pn"), "ㄆㄣ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pnf"), "ㄆㄣˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pnj"), "ㄆㄣˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pnk"), "ㄆㄣˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pt"), "ㄆㄤ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("ptf"), "ㄆㄤˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("ptj"), "ㄆㄤˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("ptk"), "ㄆㄤˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pl"), "ㄆㄥ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("plf"), "ㄆㄥˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("plj"), "ㄆㄥˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("plk"), "ㄆㄥˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pe"), "ㄆㄧ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pef"), "ㄆㄧˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pej"), "ㄆㄧˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pek"), "ㄆㄧˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pea"), "ㄆㄧㄚ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pew"), "ㄆㄧㄝ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pewj"), "ㄆㄧㄝˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pewk"), "ㄆㄧㄝˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pez"), "ㄆㄧㄠ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pezf"), "ㄆㄧㄠˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pezj"), "ㄆㄧㄠˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pezk"), "ㄆㄧㄠˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pem"), "ㄆㄧㄢ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pemf"), "ㄆㄧㄢˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pemj"), "ㄆㄧㄢˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pemk"), "ㄆㄧㄢˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pen"), "ㄆㄧㄣ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("penf"), "ㄆㄧㄣˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("penj"), "ㄆㄧㄣˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("penk"), "ㄆㄧㄣˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pel"), "ㄆㄧㄥ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pelf"), "ㄆㄧㄥˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pelj"), "ㄆㄧㄥˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pelk"), "ㄆㄧㄥˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("px"), "ㄆㄨ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pxf"), "ㄆㄨˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pxj"), "ㄆㄨˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("pxk"), "ㄆㄨˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("ma"), "ㄇㄚ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("maf"), "ㄇㄚˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("maj"), "ㄇㄚˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mak"), "ㄇㄚˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mad"), "ㄇㄚ˙")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mo"), "ㄇㄛ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mof"), "ㄇㄛˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("moj"), "ㄇㄛˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mok"), "ㄇㄛˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mod"), "ㄇㄛ˙")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mr"), "ㄇㄜ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mrk"), "ㄇㄜˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mrd"), "ㄇㄜ˙")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mi"), "ㄇㄞ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mif"), "ㄇㄞˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mij"), "ㄇㄞˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mik"), "ㄇㄞˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mqf"), "ㄇㄟˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mqj"), "ㄇㄟˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mqk"), "ㄇㄟˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mz"), "ㄇㄠ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mzf"), "ㄇㄠˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mzj"), "ㄇㄠˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mzk"), "ㄇㄠˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mpf"), "ㄇㄡˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mpj"), "ㄇㄡˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mpk"), "ㄇㄡˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mm"), "ㄇㄢ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mmf"), "ㄇㄢˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mmj"), "ㄇㄢˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mmk"), "ㄇㄢˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mn"), "ㄇㄣ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mnf"), "ㄇㄣˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mnj"), "ㄇㄣˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mnk"), "ㄇㄣˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mnd"), "ㄇㄣ˙")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mt"), "ㄇㄤ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mtf"), "ㄇㄤˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mtj"), "ㄇㄤˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mtk"), "ㄇㄤˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("ml"), "ㄇㄥ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mlf"), "ㄇㄥˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mlj"), "ㄇㄥˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mlk"), "ㄇㄥˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("me"), "ㄇㄧ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mef"), "ㄇㄧˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mej"), "ㄇㄧˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mek"), "ㄇㄧˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mew"), "ㄇㄧㄝ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mewf"), "ㄇㄧㄝˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mewk"), "ㄇㄧㄝˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mez"), "ㄇㄧㄠ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mezf"), "ㄇㄧㄠˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mezj"), "ㄇㄧㄠˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mezk"), "ㄇㄧㄠˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mepf"), "ㄇㄧㄡˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mepj"), "ㄇㄧㄡˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mepk"), "ㄇㄧㄡˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mem"), "ㄇㄧㄢ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("memf"), "ㄇㄧㄢˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("memj"), "ㄇㄧㄢˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("memk"), "ㄇㄧㄢˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("men"), "ㄇㄧㄣ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("menf"), "ㄇㄧㄣˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("menj"), "ㄇㄧㄣˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("melf"), "ㄇㄧㄥˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("melj"), "ㄇㄧㄥˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("melk"), "ㄇㄧㄥˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mxf"), "ㄇㄨˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mxj"), "ㄇㄨˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("mxk"), "ㄇㄨˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("fa"), "ㄈㄚ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("faf"), "ㄈㄚˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("faj"), "ㄈㄚˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("fak"), "ㄈㄚˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("fof"), "ㄈㄛˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("fq"), "ㄈㄟ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("fqf"), "ㄈㄟˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("fqj"), "ㄈㄟˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("fqk"), "ㄈㄟˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("fp"), "ㄈㄡ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("fpf"), "ㄈㄡˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("fpj"), "ㄈㄡˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("fpk"), "ㄈㄡˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("fm"), "ㄈㄢ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("fmf"), "ㄈㄢˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("fmj"), "ㄈㄢˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("fmk"), "ㄈㄢˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("fn"), "ㄈㄣ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("fnf"), "ㄈㄣˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("fnj"), "ㄈㄣˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("fnk"), "ㄈㄣˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("fnd"), "ㄈㄣ˙")
    XCTAssertEqual(composer.convertSequenceToRawComposition("ft"), "ㄈㄤ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("ftf"), "ㄈㄤˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("ftj"), "ㄈㄤˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("ftk"), "ㄈㄤˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("fl"), "ㄈㄥ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("flf"), "ㄈㄥˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("flj"), "ㄈㄥˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("flk"), "ㄈㄥˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("fezk"), "ㄈㄧㄠˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("fx"), "ㄈㄨ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("fxf"), "ㄈㄨˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("fxj"), "ㄈㄨˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("fxk"), "ㄈㄨˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("da"), "ㄉㄚ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("daf"), "ㄉㄚˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("daj"), "ㄉㄚˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dak"), "ㄉㄚˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dad"), "ㄉㄚ˙")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dr"), "ㄉㄜ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("drf"), "ㄉㄜˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("drd"), "ㄉㄜ˙")
    XCTAssertEqual(composer.convertSequenceToRawComposition("di"), "ㄉㄞ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dij"), "ㄉㄞˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dik"), "ㄉㄞˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dqj"), "ㄉㄟˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dz"), "ㄉㄠ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dzf"), "ㄉㄠˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dzj"), "ㄉㄠˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dzk"), "ㄉㄠˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dp"), "ㄉㄡ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dpf"), "ㄉㄡˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dpj"), "ㄉㄡˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dpk"), "ㄉㄡˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dm"), "ㄉㄢ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dmj"), "ㄉㄢˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dmk"), "ㄉㄢˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dnk"), "ㄉㄣˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dt"), "ㄉㄤ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dtj"), "ㄉㄤˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dtk"), "ㄉㄤˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dl"), "ㄉㄥ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dlj"), "ㄉㄥˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dlk"), "ㄉㄥˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("de"), "ㄉㄧ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("def"), "ㄉㄧˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dej"), "ㄉㄧˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dek"), "ㄉㄧˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("deaj"), "ㄉㄧㄚˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dew"), "ㄉㄧㄝ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dewf"), "ㄉㄧㄝˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dewj"), "ㄉㄧㄝˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dewk"), "ㄉㄧㄝˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dez"), "ㄉㄧㄠ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dezj"), "ㄉㄧㄠˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dezk"), "ㄉㄧㄠˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dep"), "ㄉㄧㄡ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dem"), "ㄉㄧㄢ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("demf"), "ㄉㄧㄢˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("demj"), "ㄉㄧㄢˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("demk"), "ㄉㄧㄢˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("del"), "ㄉㄧㄥ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("delf"), "ㄉㄧㄥˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("delj"), "ㄉㄧㄥˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("delk"), "ㄉㄧㄥˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dx"), "ㄉㄨ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dxf"), "ㄉㄨˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dxj"), "ㄉㄨˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dxk"), "ㄉㄨˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dxo"), "ㄉㄨㄛ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dxof"), "ㄉㄨㄛˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dxoj"), "ㄉㄨㄛˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dxok"), "ㄉㄨㄛˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dxod"), "ㄉㄨㄛ˙")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dxq"), "ㄉㄨㄟ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dxqj"), "ㄉㄨㄟˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dxqk"), "ㄉㄨㄟˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dxm"), "ㄉㄨㄢ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dxmj"), "ㄉㄨㄢˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dxmk"), "ㄉㄨㄢˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dxn"), "ㄉㄨㄣ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dxnj"), "ㄉㄨㄣˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dxnk"), "ㄉㄨㄣˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dxl"), "ㄉㄨㄥ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dxlj"), "ㄉㄨㄥˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("dxlk"), "ㄉㄨㄥˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("ta"), "ㄊㄚ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("taj"), "ㄊㄚˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("tak"), "ㄊㄚˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("trk"), "ㄊㄜˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("ti"), "ㄊㄞ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("tif"), "ㄊㄞˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("tij"), "ㄊㄞˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("tik"), "ㄊㄞˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("tid"), "ㄊㄞ˙")
    XCTAssertEqual(composer.convertSequenceToRawComposition("tz"), "ㄊㄠ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("tzf"), "ㄊㄠˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("tzj"), "ㄊㄠˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("tzk"), "ㄊㄠˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("tzd"), "ㄊㄠ˙")
    XCTAssertEqual(composer.convertSequenceToRawComposition("tp"), "ㄊㄡ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("tpf"), "ㄊㄡˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("tpj"), "ㄊㄡˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("tpk"), "ㄊㄡˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("tpd"), "ㄊㄡ˙")
    XCTAssertEqual(composer.convertSequenceToRawComposition("tm"), "ㄊㄢ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("tmf"), "ㄊㄢˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("tmj"), "ㄊㄢˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("tmk"), "ㄊㄢˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("tt"), "ㄊㄤ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("ttf"), "ㄊㄤˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("ttj"), "ㄊㄤˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("ttk"), "ㄊㄤˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("tl"), "ㄊㄥ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("tlf"), "ㄊㄥˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("tlk"), "ㄊㄥˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("te"), "ㄊㄧ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("tef"), "ㄊㄧˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("tej"), "ㄊㄧˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("tek"), "ㄊㄧˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("tew"), "ㄊㄧㄝ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("tewf"), "ㄊㄧㄝˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("tewj"), "ㄊㄧㄝˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("tewk"), "ㄊㄧㄝˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("tez"), "ㄊㄧㄠ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("tezf"), "ㄊㄧㄠˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("tezj"), "ㄊㄧㄠˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("tezk"), "ㄊㄧㄠˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("tem"), "ㄊㄧㄢ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("temf"), "ㄊㄧㄢˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("temj"), "ㄊㄧㄢˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("temk"), "ㄊㄧㄢˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("tel"), "ㄊㄧㄥ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("telf"), "ㄊㄧㄥˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("telj"), "ㄊㄧㄥˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("telk"), "ㄊㄧㄥˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("tx"), "ㄊㄨ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("txf"), "ㄊㄨˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("txj"), "ㄊㄨˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("txk"), "ㄊㄨˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("txo"), "ㄊㄨㄛ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("txof"), "ㄊㄨㄛˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("txoj"), "ㄊㄨㄛˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("txok"), "ㄊㄨㄛˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("txq"), "ㄊㄨㄟ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("txqf"), "ㄊㄨㄟˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("txqj"), "ㄊㄨㄟˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("txqk"), "ㄊㄨㄟˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("txm"), "ㄊㄨㄢ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("txmf"), "ㄊㄨㄢˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("txmj"), "ㄊㄨㄢˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("txmk"), "ㄊㄨㄢˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("txn"), "ㄊㄨㄣ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("txnf"), "ㄊㄨㄣˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("txnj"), "ㄊㄨㄣˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("txnk"), "ㄊㄨㄣˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("txl"), "ㄊㄨㄥ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("txlf"), "ㄊㄨㄥˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("txlj"), "ㄊㄨㄥˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("txlk"), "ㄊㄨㄥˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("na"), "ㄋㄚ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("naf"), "ㄋㄚˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("naj"), "ㄋㄚˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nak"), "ㄋㄚˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nad"), "ㄋㄚ˙")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nrk"), "ㄋㄜˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nrd"), "ㄋㄜ˙")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nif"), "ㄋㄞˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nij"), "ㄋㄞˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nik"), "ㄋㄞˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nqf"), "ㄋㄟˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nqj"), "ㄋㄟˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nqk"), "ㄋㄟˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nz"), "ㄋㄠ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nzf"), "ㄋㄠˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nzj"), "ㄋㄠˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nzk"), "ㄋㄠˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("npf"), "ㄋㄡˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("npj"), "ㄋㄡˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("npk"), "ㄋㄡˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nm"), "ㄋㄢ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nmf"), "ㄋㄢˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nmj"), "ㄋㄢˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nmk"), "ㄋㄢˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nnj"), "ㄋㄣˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nnk"), "ㄋㄣˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nt"), "ㄋㄤ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("ntf"), "ㄋㄤˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("ntj"), "ㄋㄤˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("ntk"), "ㄋㄤˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("ntd"), "ㄋㄤ˙")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nlf"), "ㄋㄥˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nlj"), "ㄋㄥˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("ne"), "ㄋㄧ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nef"), "ㄋㄧˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nej"), "ㄋㄧˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nek"), "ㄋㄧˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("new"), "ㄋㄧㄝ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("newf"), "ㄋㄧㄝˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("newk"), "ㄋㄧㄝˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nezj"), "ㄋㄧㄠˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nezk"), "ㄋㄧㄠˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nep"), "ㄋㄧㄡ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nepf"), "ㄋㄧㄡˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nepj"), "ㄋㄧㄡˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nepk"), "ㄋㄧㄡˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nem"), "ㄋㄧㄢ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nemf"), "ㄋㄧㄢˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nemj"), "ㄋㄧㄢˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nemk"), "ㄋㄧㄢˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nen"), "ㄋㄧㄣ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nenf"), "ㄋㄧㄣˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nenj"), "ㄋㄧㄣˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nenk"), "ㄋㄧㄣˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("netf"), "ㄋㄧㄤˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("netj"), "ㄋㄧㄤˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("netk"), "ㄋㄧㄤˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nelf"), "ㄋㄧㄥˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nelj"), "ㄋㄧㄥˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nelk"), "ㄋㄧㄥˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nxf"), "ㄋㄨˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nxj"), "ㄋㄨˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nxk"), "ㄋㄨˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nxof"), "ㄋㄨㄛˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nxoj"), "ㄋㄨㄛˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nxok"), "ㄋㄨㄛˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nxqf"), "ㄋㄨㄟˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nxmf"), "ㄋㄨㄢˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nxmj"), "ㄋㄨㄢˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nxmk"), "ㄋㄨㄢˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nxnf"), "ㄋㄨㄣˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nxlf"), "ㄋㄨㄥˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nxlj"), "ㄋㄨㄥˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nxlk"), "ㄋㄨㄥˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nuf"), "ㄋㄩˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nuj"), "ㄋㄩˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nuk"), "ㄋㄩˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("nuwk"), "ㄋㄩㄝˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("la"), "ㄌㄚ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("laf"), "ㄌㄚˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("laj"), "ㄌㄚˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("lak"), "ㄌㄚˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("lad"), "ㄌㄚ˙")
    XCTAssertEqual(composer.convertSequenceToRawComposition("lo"), "ㄌㄛ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("lod"), "ㄌㄛ˙")
    XCTAssertEqual(composer.convertSequenceToRawComposition("lr"), "ㄌㄜ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("lrf"), "ㄌㄜˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("lrk"), "ㄌㄜˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("lrd"), "ㄌㄜ˙")
    XCTAssertEqual(composer.convertSequenceToRawComposition("lif"), "ㄌㄞˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("lij"), "ㄌㄞˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("lik"), "ㄌㄞˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("lq"), "ㄌㄟ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("lqf"), "ㄌㄟˊ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("lqj"), "ㄌㄟˇ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("lqk"), "ㄌㄟˋ")
    XCTAssertEqual(composer.convertSequenceToRawComposition("lqd"), "ㄌㄟ˙")
  }
}
