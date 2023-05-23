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
  func testHsuKeysB() throws {
    var c = Tekkon.Composer(arrange: .ofHsu)
    XCTAssertEqual(c.cS2RC("laj"), "ㄌㄟˋ")
    XCTAssertEqual(c.cS2RC("las"), "ㄌㄟ˙")
    XCTAssertEqual(c.cS2RC("lw"), "ㄌㄠ")
    XCTAssertEqual(c.cS2RC("lwd"), "ㄌㄠˊ")
    XCTAssertEqual(c.cS2RC("lwf"), "ㄌㄠˇ")
    XCTAssertEqual(c.cS2RC("lwj"), "ㄌㄠˋ")
    XCTAssertEqual(c.cS2RC("lo"), "ㄌㄡ")
    XCTAssertEqual(c.cS2RC("lod"), "ㄌㄡˊ")
    XCTAssertEqual(c.cS2RC("lof"), "ㄌㄡˇ")
    XCTAssertEqual(c.cS2RC("loj"), "ㄌㄡˋ")
    XCTAssertEqual(c.cS2RC("los"), "ㄌㄡ˙")
    XCTAssertEqual(c.cS2RC("lmd"), "ㄌㄢˊ")
    XCTAssertEqual(c.cS2RC("lmf"), "ㄌㄢˇ")
    XCTAssertEqual(c.cS2RC("lmj"), "ㄌㄢˋ")
    XCTAssertEqual(c.cS2RC("lk"), "ㄌㄤ")
    XCTAssertEqual(c.cS2RC("lkd"), "ㄌㄤˊ")
    XCTAssertEqual(c.cS2RC("lkf"), "ㄌㄤˇ")
    XCTAssertEqual(c.cS2RC("lkj"), "ㄌㄤˋ")
    XCTAssertEqual(c.cS2RC("ll"), "ㄌㄥ")
    XCTAssertEqual(c.cS2RC("lld"), "ㄌㄥˊ")
    XCTAssertEqual(c.cS2RC("llf"), "ㄌㄥˇ")
    XCTAssertEqual(c.cS2RC("llj"), "ㄌㄥˋ")
    XCTAssertEqual(c.cS2RC("le"), "ㄌㄧ")
    XCTAssertEqual(c.cS2RC("led"), "ㄌㄧˊ")
    XCTAssertEqual(c.cS2RC("lef"), "ㄌㄧˇ")
    XCTAssertEqual(c.cS2RC("lej"), "ㄌㄧˋ")
    XCTAssertEqual(c.cS2RC("les"), "ㄌㄧ˙")
    XCTAssertEqual(c.cS2RC("leyf"), "ㄌㄧㄚˇ")
    XCTAssertEqual(c.cS2RC("lee"), "ㄌㄧㄝ")
    XCTAssertEqual(c.cS2RC("leed"), "ㄌㄧㄝˊ")
    XCTAssertEqual(c.cS2RC("leef"), "ㄌㄧㄝˇ")
    XCTAssertEqual(c.cS2RC("leej"), "ㄌㄧㄝˋ")
    XCTAssertEqual(c.cS2RC("lew"), "ㄌㄧㄠ")
    XCTAssertEqual(c.cS2RC("lewd"), "ㄌㄧㄠˊ")
    XCTAssertEqual(c.cS2RC("lewf"), "ㄌㄧㄠˇ")
    XCTAssertEqual(c.cS2RC("lewj"), "ㄌㄧㄠˋ")
    XCTAssertEqual(c.cS2RC("leo"), "ㄌㄧㄡ")
    XCTAssertEqual(c.cS2RC("leod"), "ㄌㄧㄡˊ")
    XCTAssertEqual(c.cS2RC("leof"), "ㄌㄧㄡˇ")
    XCTAssertEqual(c.cS2RC("leoj"), "ㄌㄧㄡˋ")
    XCTAssertEqual(c.cS2RC("lem"), "ㄌㄧㄢ")
    XCTAssertEqual(c.cS2RC("lemd"), "ㄌㄧㄢˊ")
    XCTAssertEqual(c.cS2RC("lemf"), "ㄌㄧㄢˇ")
    XCTAssertEqual(c.cS2RC("lemj"), "ㄌㄧㄢˋ")
    XCTAssertEqual(c.cS2RC("lend"), "ㄌㄧㄣˊ")
    XCTAssertEqual(c.cS2RC("lenf"), "ㄌㄧㄣˇ")
    XCTAssertEqual(c.cS2RC("lenj"), "ㄌㄧㄣˋ")
    XCTAssertEqual(c.cS2RC("lekd"), "ㄌㄧㄤˊ")
    XCTAssertEqual(c.cS2RC("lekf"), "ㄌㄧㄤˇ")
    XCTAssertEqual(c.cS2RC("lekj"), "ㄌㄧㄤˋ")
    XCTAssertEqual(c.cS2RC("lel"), "ㄌㄧㄥ")
    XCTAssertEqual(c.cS2RC("leld"), "ㄌㄧㄥˊ")
    XCTAssertEqual(c.cS2RC("lelf"), "ㄌㄧㄥˇ")
    XCTAssertEqual(c.cS2RC("lelj"), "ㄌㄧㄥˋ")
    XCTAssertEqual(c.cS2RC("lx"), "ㄌㄨ")
    XCTAssertEqual(c.cS2RC("lxd"), "ㄌㄨˊ")
    XCTAssertEqual(c.cS2RC("lxf"), "ㄌㄨˇ")
    XCTAssertEqual(c.cS2RC("lxj"), "ㄌㄨˋ")
    XCTAssertEqual(c.cS2RC("lxh"), "ㄌㄨㄛ")
    XCTAssertEqual(c.cS2RC("lxhd"), "ㄌㄨㄛˊ")
    XCTAssertEqual(c.cS2RC("lxhf"), "ㄌㄨㄛˇ")
    XCTAssertEqual(c.cS2RC("lxhj"), "ㄌㄨㄛˋ")
    XCTAssertEqual(c.cS2RC("lxhs"), "ㄌㄨㄛ˙")
    XCTAssertEqual(c.cS2RC("lxmd"), "ㄌㄨㄢˊ")
    XCTAssertEqual(c.cS2RC("lxmf"), "ㄌㄨㄢˇ")
    XCTAssertEqual(c.cS2RC("lxmj"), "ㄌㄨㄢˋ")
    XCTAssertEqual(c.cS2RC("lxn"), "ㄌㄨㄣ")
    XCTAssertEqual(c.cS2RC("lxnd"), "ㄌㄨㄣˊ")
    XCTAssertEqual(c.cS2RC("lxnf"), "ㄌㄨㄣˇ")
    XCTAssertEqual(c.cS2RC("lxnj"), "ㄌㄨㄣˋ")
    XCTAssertEqual(c.cS2RC("lxl"), "ㄌㄨㄥ")
    XCTAssertEqual(c.cS2RC("lxld"), "ㄌㄨㄥˊ")
    XCTAssertEqual(c.cS2RC("lxlf"), "ㄌㄨㄥˇ")
    XCTAssertEqual(c.cS2RC("lxlj"), "ㄌㄨㄥˋ")
    XCTAssertEqual(c.cS2RC("lu"), "ㄌㄩ")
    XCTAssertEqual(c.cS2RC("lud"), "ㄌㄩˊ")
    XCTAssertEqual(c.cS2RC("luf"), "ㄌㄩˇ")
    XCTAssertEqual(c.cS2RC("luj"), "ㄌㄩˋ")
    XCTAssertEqual(c.cS2RC("lue"), "ㄌㄩㄝ")
    XCTAssertEqual(c.cS2RC("luef"), "ㄌㄩㄝˇ")
    XCTAssertEqual(c.cS2RC("luej"), "ㄌㄩㄝˋ")
    XCTAssertEqual(c.cS2RC("lumd"), "ㄌㄩㄢˊ")
    XCTAssertEqual(c.cS2RC("lumf"), "ㄌㄩㄢˇ")
    XCTAssertEqual(c.cS2RC("gy"), "ㄍㄚ")
    XCTAssertEqual(c.cS2RC("gyd"), "ㄍㄚˊ")
    XCTAssertEqual(c.cS2RC("gyf"), "ㄍㄚˇ")
    XCTAssertEqual(c.cS2RC("gyj"), "ㄍㄚˋ")
    XCTAssertEqual(c.cS2RC("gys"), "ㄍㄚ˙")
    XCTAssertEqual(c.cS2RC("gg"), "ㄍㄜ")
    XCTAssertEqual(c.cS2RC("ggd"), "ㄍㄜˊ")
    XCTAssertEqual(c.cS2RC("ggf"), "ㄍㄜˇ")
    XCTAssertEqual(c.cS2RC("ggj"), "ㄍㄜˋ")
    XCTAssertEqual(c.cS2RC("ggs"), "ㄍㄜ˙")
    XCTAssertEqual(c.cS2RC("gi"), "ㄍㄞ")
    XCTAssertEqual(c.cS2RC("gif"), "ㄍㄞˇ")
    XCTAssertEqual(c.cS2RC("gij"), "ㄍㄞˋ")
    XCTAssertEqual(c.cS2RC("gaf"), "ㄍㄟˇ")
    XCTAssertEqual(c.cS2RC("gw"), "ㄍㄠ")
    XCTAssertEqual(c.cS2RC("gwf"), "ㄍㄠˇ")
    XCTAssertEqual(c.cS2RC("gwj"), "ㄍㄠˋ")
    XCTAssertEqual(c.cS2RC("go"), "ㄍㄡ")
    XCTAssertEqual(c.cS2RC("gof"), "ㄍㄡˇ")
    XCTAssertEqual(c.cS2RC("goj"), "ㄍㄡˋ")
    XCTAssertEqual(c.cS2RC("gm"), "ㄍㄢ")
    XCTAssertEqual(c.cS2RC("gmf"), "ㄍㄢˇ")
    XCTAssertEqual(c.cS2RC("gmj"), "ㄍㄢˋ")
    XCTAssertEqual(c.cS2RC("gn"), "ㄍㄣ")
    XCTAssertEqual(c.cS2RC("gnd"), "ㄍㄣˊ")
    XCTAssertEqual(c.cS2RC("gnf"), "ㄍㄣˇ")
    XCTAssertEqual(c.cS2RC("gnj"), "ㄍㄣˋ")
    XCTAssertEqual(c.cS2RC("gk"), "ㄍㄤ")
    XCTAssertEqual(c.cS2RC("gkf"), "ㄍㄤˇ")
    XCTAssertEqual(c.cS2RC("gkj"), "ㄍㄤˋ")
    XCTAssertEqual(c.cS2RC("gl"), "ㄍㄥ")
    XCTAssertEqual(c.cS2RC("glf"), "ㄍㄥˇ")
    XCTAssertEqual(c.cS2RC("glj"), "ㄍㄥˋ")
    XCTAssertEqual(c.cS2RC("gx"), "ㄍㄨ")
    XCTAssertEqual(c.cS2RC("gxd"), "ㄍㄨˊ")
    XCTAssertEqual(c.cS2RC("gxf"), "ㄍㄨˇ")
    XCTAssertEqual(c.cS2RC("gxj"), "ㄍㄨˋ")
    XCTAssertEqual(c.cS2RC("gxy"), "ㄍㄨㄚ")
    XCTAssertEqual(c.cS2RC("gxyd"), "ㄍㄨㄚˊ")
    XCTAssertEqual(c.cS2RC("gxyf"), "ㄍㄨㄚˇ")
    XCTAssertEqual(c.cS2RC("gxyj"), "ㄍㄨㄚˋ")
    XCTAssertEqual(c.cS2RC("gxh"), "ㄍㄨㄛ")
    XCTAssertEqual(c.cS2RC("gxhd"), "ㄍㄨㄛˊ")
    XCTAssertEqual(c.cS2RC("gxhf"), "ㄍㄨㄛˇ")
    XCTAssertEqual(c.cS2RC("gxhj"), "ㄍㄨㄛˋ")
    XCTAssertEqual(c.cS2RC("gxi"), "ㄍㄨㄞ")
    XCTAssertEqual(c.cS2RC("gxif"), "ㄍㄨㄞˇ")
    XCTAssertEqual(c.cS2RC("gxij"), "ㄍㄨㄞˋ")
    XCTAssertEqual(c.cS2RC("gxa"), "ㄍㄨㄟ")
    XCTAssertEqual(c.cS2RC("gxaf"), "ㄍㄨㄟˇ")
    XCTAssertEqual(c.cS2RC("gxaj"), "ㄍㄨㄟˋ")
    XCTAssertEqual(c.cS2RC("gxm"), "ㄍㄨㄢ")
    XCTAssertEqual(c.cS2RC("gxmf"), "ㄍㄨㄢˇ")
    XCTAssertEqual(c.cS2RC("gxmj"), "ㄍㄨㄢˋ")
    XCTAssertEqual(c.cS2RC("gxn"), "ㄍㄨㄣ")
    XCTAssertEqual(c.cS2RC("gxnf"), "ㄍㄨㄣˇ")
    XCTAssertEqual(c.cS2RC("gxnj"), "ㄍㄨㄣˋ")
    XCTAssertEqual(c.cS2RC("gxk"), "ㄍㄨㄤ")
    XCTAssertEqual(c.cS2RC("gxkf"), "ㄍㄨㄤˇ")
    XCTAssertEqual(c.cS2RC("gxkj"), "ㄍㄨㄤˋ")
    XCTAssertEqual(c.cS2RC("gxl"), "ㄍㄨㄥ")
    XCTAssertEqual(c.cS2RC("gxld"), "ㄍㄨㄥˊ")
    XCTAssertEqual(c.cS2RC("gxlf"), "ㄍㄨㄥˇ")
    XCTAssertEqual(c.cS2RC("gxlj"), "ㄍㄨㄥˋ")
    XCTAssertEqual(c.cS2RC("ky"), "ㄎㄚ")
    XCTAssertEqual(c.cS2RC("kyf"), "ㄎㄚˇ")
    XCTAssertEqual(c.cS2RC("kyj"), "ㄎㄚˋ")
    XCTAssertEqual(c.cS2RC("kg"), "ㄎㄜ")
    XCTAssertEqual(c.cS2RC("kgd"), "ㄎㄜˊ")
    XCTAssertEqual(c.cS2RC("kgf"), "ㄎㄜˇ")
    XCTAssertEqual(c.cS2RC("kgj"), "ㄎㄜˋ")
    XCTAssertEqual(c.cS2RC("ki"), "ㄎㄞ")
    XCTAssertEqual(c.cS2RC("kif"), "ㄎㄞˇ")
    XCTAssertEqual(c.cS2RC("kij"), "ㄎㄞˋ")
    XCTAssertEqual(c.cS2RC("kw"), "ㄎㄠ")
    XCTAssertEqual(c.cS2RC("kwf"), "ㄎㄠˇ")
    XCTAssertEqual(c.cS2RC("kwj"), "ㄎㄠˋ")
    XCTAssertEqual(c.cS2RC("ko"), "ㄎㄡ")
    XCTAssertEqual(c.cS2RC("kof"), "ㄎㄡˇ")
    XCTAssertEqual(c.cS2RC("koj"), "ㄎㄡˋ")
    XCTAssertEqual(c.cS2RC("km"), "ㄎㄢ")
    XCTAssertEqual(c.cS2RC("kmf"), "ㄎㄢˇ")
    XCTAssertEqual(c.cS2RC("kmj"), "ㄎㄢˋ")
    XCTAssertEqual(c.cS2RC("kn"), "ㄎㄣ")
    XCTAssertEqual(c.cS2RC("knf"), "ㄎㄣˇ")
    XCTAssertEqual(c.cS2RC("knj"), "ㄎㄣˋ")
    XCTAssertEqual(c.cS2RC("kk"), "ㄎㄤ")
    XCTAssertEqual(c.cS2RC("kkd"), "ㄎㄤˊ")
    XCTAssertEqual(c.cS2RC("kkf"), "ㄎㄤˇ")
    XCTAssertEqual(c.cS2RC("kkj"), "ㄎㄤˋ")
    XCTAssertEqual(c.cS2RC("kl"), "ㄎㄥ")
    XCTAssertEqual(c.cS2RC("klf"), "ㄎㄥˇ")
    XCTAssertEqual(c.cS2RC("kx"), "ㄎㄨ")
    XCTAssertEqual(c.cS2RC("kxd"), "ㄎㄨˊ")
    XCTAssertEqual(c.cS2RC("kxf"), "ㄎㄨˇ")
    XCTAssertEqual(c.cS2RC("kxj"), "ㄎㄨˋ")
    XCTAssertEqual(c.cS2RC("kxy"), "ㄎㄨㄚ")
    XCTAssertEqual(c.cS2RC("kxyf"), "ㄎㄨㄚˇ")
    XCTAssertEqual(c.cS2RC("kxyj"), "ㄎㄨㄚˋ")
    XCTAssertEqual(c.cS2RC("kxhj"), "ㄎㄨㄛˋ")
    XCTAssertEqual(c.cS2RC("kxi"), "ㄎㄨㄞ")
    XCTAssertEqual(c.cS2RC("kxif"), "ㄎㄨㄞˇ")
    XCTAssertEqual(c.cS2RC("kxij"), "ㄎㄨㄞˋ")
    XCTAssertEqual(c.cS2RC("kxa"), "ㄎㄨㄟ")
    XCTAssertEqual(c.cS2RC("kxad"), "ㄎㄨㄟˊ")
    XCTAssertEqual(c.cS2RC("kxaf"), "ㄎㄨㄟˇ")
    XCTAssertEqual(c.cS2RC("kxaj"), "ㄎㄨㄟˋ")
    XCTAssertEqual(c.cS2RC("kxm"), "ㄎㄨㄢ")
    XCTAssertEqual(c.cS2RC("kxmf"), "ㄎㄨㄢˇ")
    XCTAssertEqual(c.cS2RC("kxmj"), "ㄎㄨㄢˋ")
    XCTAssertEqual(c.cS2RC("kxn"), "ㄎㄨㄣ")
    XCTAssertEqual(c.cS2RC("kxnf"), "ㄎㄨㄣˇ")
    XCTAssertEqual(c.cS2RC("kxnj"), "ㄎㄨㄣˋ")
    XCTAssertEqual(c.cS2RC("kxk"), "ㄎㄨㄤ")
    XCTAssertEqual(c.cS2RC("kxkd"), "ㄎㄨㄤˊ")
    XCTAssertEqual(c.cS2RC("kxkf"), "ㄎㄨㄤˇ")
    XCTAssertEqual(c.cS2RC("kxkj"), "ㄎㄨㄤˋ")
    XCTAssertEqual(c.cS2RC("kxl"), "ㄎㄨㄥ")
    XCTAssertEqual(c.cS2RC("kxlf"), "ㄎㄨㄥˇ")
    XCTAssertEqual(c.cS2RC("kxlj"), "ㄎㄨㄥˋ")
    XCTAssertEqual(c.cS2RC("hy"), "ㄏㄚ")
    XCTAssertEqual(c.cS2RC("hyd"), "ㄏㄚˊ")
    XCTAssertEqual(c.cS2RC("hyf"), "ㄏㄚˇ")
    XCTAssertEqual(c.cS2RC("hg"), "ㄏㄜ")
    XCTAssertEqual(c.cS2RC("hgd"), "ㄏㄜˊ")
    XCTAssertEqual(c.cS2RC("hgf"), "ㄏㄜˇ")
    XCTAssertEqual(c.cS2RC("hgj"), "ㄏㄜˋ")
    XCTAssertEqual(c.cS2RC("hi"), "ㄏㄞ")
    XCTAssertEqual(c.cS2RC("hid"), "ㄏㄞˊ")
    XCTAssertEqual(c.cS2RC("hif"), "ㄏㄞˇ")
    XCTAssertEqual(c.cS2RC("hij"), "ㄏㄞˋ")
    XCTAssertEqual(c.cS2RC("ha"), "ㄏㄟ")
    XCTAssertEqual(c.cS2RC("haf"), "ㄏㄟˇ")
    XCTAssertEqual(c.cS2RC("hw"), "ㄏㄠ")
    XCTAssertEqual(c.cS2RC("hwd"), "ㄏㄠˊ")
    XCTAssertEqual(c.cS2RC("hwf"), "ㄏㄠˇ")
    XCTAssertEqual(c.cS2RC("hwj"), "ㄏㄠˋ")
    XCTAssertEqual(c.cS2RC("ho"), "ㄏㄡ")
    XCTAssertEqual(c.cS2RC("hod"), "ㄏㄡˊ")
    XCTAssertEqual(c.cS2RC("hof"), "ㄏㄡˇ")
    XCTAssertEqual(c.cS2RC("hoj"), "ㄏㄡˋ")
    XCTAssertEqual(c.cS2RC("hm"), "ㄏㄢ")
    XCTAssertEqual(c.cS2RC("hmd"), "ㄏㄢˊ")
    XCTAssertEqual(c.cS2RC("hmf"), "ㄏㄢˇ")
    XCTAssertEqual(c.cS2RC("hmj"), "ㄏㄢˋ")
    XCTAssertEqual(c.cS2RC("hn"), "ㄏㄣ")
    XCTAssertEqual(c.cS2RC("hnd"), "ㄏㄣˊ")
    XCTAssertEqual(c.cS2RC("hnf"), "ㄏㄣˇ")
    XCTAssertEqual(c.cS2RC("hnj"), "ㄏㄣˋ")
    XCTAssertEqual(c.cS2RC("hk"), "ㄏㄤ")
    XCTAssertEqual(c.cS2RC("hkd"), "ㄏㄤˊ")
    XCTAssertEqual(c.cS2RC("hkf"), "ㄏㄤˇ")
    XCTAssertEqual(c.cS2RC("hkj"), "ㄏㄤˋ")
    XCTAssertEqual(c.cS2RC("hl"), "ㄏㄥ")
    XCTAssertEqual(c.cS2RC("hld"), "ㄏㄥˊ")
    XCTAssertEqual(c.cS2RC("hlj"), "ㄏㄥˋ")
    XCTAssertEqual(c.cS2RC("hx"), "ㄏㄨ")
    XCTAssertEqual(c.cS2RC("hxd"), "ㄏㄨˊ")
    XCTAssertEqual(c.cS2RC("hxf"), "ㄏㄨˇ")
    XCTAssertEqual(c.cS2RC("hxj"), "ㄏㄨˋ")
    XCTAssertEqual(c.cS2RC("hxy"), "ㄏㄨㄚ")
    XCTAssertEqual(c.cS2RC("hxyd"), "ㄏㄨㄚˊ")
    XCTAssertEqual(c.cS2RC("hxyf"), "ㄏㄨㄚˇ")
    XCTAssertEqual(c.cS2RC("hxyj"), "ㄏㄨㄚˋ")
    XCTAssertEqual(c.cS2RC("hxh"), "ㄏㄨㄛ")
    XCTAssertEqual(c.cS2RC("hxhd"), "ㄏㄨㄛˊ")
    XCTAssertEqual(c.cS2RC("hxhf"), "ㄏㄨㄛˇ")
    XCTAssertEqual(c.cS2RC("hxhj"), "ㄏㄨㄛˋ")
    XCTAssertEqual(c.cS2RC("hxhs"), "ㄏㄨㄛ˙")
    XCTAssertEqual(c.cS2RC("hxid"), "ㄏㄨㄞˊ")
    XCTAssertEqual(c.cS2RC("hxij"), "ㄏㄨㄞˋ")
    XCTAssertEqual(c.cS2RC("hxa"), "ㄏㄨㄟ")
    XCTAssertEqual(c.cS2RC("hxad"), "ㄏㄨㄟˊ")
    XCTAssertEqual(c.cS2RC("hxaf"), "ㄏㄨㄟˇ")
    XCTAssertEqual(c.cS2RC("hxaj"), "ㄏㄨㄟˋ")
    XCTAssertEqual(c.cS2RC("hxm"), "ㄏㄨㄢ")
    XCTAssertEqual(c.cS2RC("hxmd"), "ㄏㄨㄢˊ")
    XCTAssertEqual(c.cS2RC("hxmf"), "ㄏㄨㄢˇ")
    XCTAssertEqual(c.cS2RC("hxmj"), "ㄏㄨㄢˋ")
    XCTAssertEqual(c.cS2RC("hxn"), "ㄏㄨㄣ")
    XCTAssertEqual(c.cS2RC("hxnd"), "ㄏㄨㄣˊ")
    XCTAssertEqual(c.cS2RC("hxnf"), "ㄏㄨㄣˇ")
    XCTAssertEqual(c.cS2RC("hxnj"), "ㄏㄨㄣˋ")
    XCTAssertEqual(c.cS2RC("hxk"), "ㄏㄨㄤ")
    XCTAssertEqual(c.cS2RC("hxkd"), "ㄏㄨㄤˊ")
    XCTAssertEqual(c.cS2RC("hxkf"), "ㄏㄨㄤˇ")
    XCTAssertEqual(c.cS2RC("hxkj"), "ㄏㄨㄤˋ")
    XCTAssertEqual(c.cS2RC("hxks"), "ㄏㄨㄤ˙")
    XCTAssertEqual(c.cS2RC("hxl"), "ㄏㄨㄥ")
    XCTAssertEqual(c.cS2RC("hxld"), "ㄏㄨㄥˊ")
    XCTAssertEqual(c.cS2RC("hxlf"), "ㄏㄨㄥˇ")
    XCTAssertEqual(c.cS2RC("hxlj"), "ㄏㄨㄥˋ")
    XCTAssertEqual(c.cS2RC("je"), "ㄐㄧ")
    XCTAssertEqual(c.cS2RC("jed"), "ㄐㄧˊ")
    XCTAssertEqual(c.cS2RC("jef"), "ㄐㄧˇ")
    XCTAssertEqual(c.cS2RC("jej"), "ㄐㄧˋ")
    XCTAssertEqual(c.cS2RC("jey"), "ㄐㄧㄚ")
    XCTAssertEqual(c.cS2RC("jeyd"), "ㄐㄧㄚˊ")
    XCTAssertEqual(c.cS2RC("jeyf"), "ㄐㄧㄚˇ")
    XCTAssertEqual(c.cS2RC("jeyj"), "ㄐㄧㄚˋ")
    XCTAssertEqual(c.cS2RC("jee"), "ㄐㄧㄝ")
    XCTAssertEqual(c.cS2RC("jeed"), "ㄐㄧㄝˊ")
    XCTAssertEqual(c.cS2RC("jeef"), "ㄐㄧㄝˇ")
    XCTAssertEqual(c.cS2RC("jeej"), "ㄐㄧㄝˋ")
    XCTAssertEqual(c.cS2RC("jees"), "ㄐㄧㄝ˙")
    XCTAssertEqual(c.cS2RC("jew"), "ㄐㄧㄠ")
    XCTAssertEqual(c.cS2RC("jewd"), "ㄐㄧㄠˊ")
    XCTAssertEqual(c.cS2RC("jewf"), "ㄐㄧㄠˇ")
    XCTAssertEqual(c.cS2RC("jewj"), "ㄐㄧㄠˋ")
    XCTAssertEqual(c.cS2RC("jeo"), "ㄐㄧㄡ")
    XCTAssertEqual(c.cS2RC("jeof"), "ㄐㄧㄡˇ")
    XCTAssertEqual(c.cS2RC("jeoj"), "ㄐㄧㄡˋ")
    XCTAssertEqual(c.cS2RC("jem"), "ㄐㄧㄢ")
    XCTAssertEqual(c.cS2RC("jemf"), "ㄐㄧㄢˇ")
    XCTAssertEqual(c.cS2RC("jemj"), "ㄐㄧㄢˋ")
    XCTAssertEqual(c.cS2RC("jen"), "ㄐㄧㄣ")
    XCTAssertEqual(c.cS2RC("jenf"), "ㄐㄧㄣˇ")
    XCTAssertEqual(c.cS2RC("jenj"), "ㄐㄧㄣˋ")
    XCTAssertEqual(c.cS2RC("jek"), "ㄐㄧㄤ")
    XCTAssertEqual(c.cS2RC("jekd"), "ㄐㄧㄤˊ")
    XCTAssertEqual(c.cS2RC("jekf"), "ㄐㄧㄤˇ")
    XCTAssertEqual(c.cS2RC("jekj"), "ㄐㄧㄤˋ")
    XCTAssertEqual(c.cS2RC("jel"), "ㄐㄧㄥ")
    XCTAssertEqual(c.cS2RC("jelf"), "ㄐㄧㄥˇ")
    XCTAssertEqual(c.cS2RC("jelj"), "ㄐㄧㄥˋ")
    XCTAssertEqual(c.cS2RC("ju"), "ㄐㄩ")
    XCTAssertEqual(c.cS2RC("jud"), "ㄐㄩˊ")
    XCTAssertEqual(c.cS2RC("juf"), "ㄐㄩˇ")
    XCTAssertEqual(c.cS2RC("juj"), "ㄐㄩˋ")
    XCTAssertEqual(c.cS2RC("jue"), "ㄐㄩㄝ")
    XCTAssertEqual(c.cS2RC("jued"), "ㄐㄩㄝˊ")
    XCTAssertEqual(c.cS2RC("juef"), "ㄐㄩㄝˇ")
    XCTAssertEqual(c.cS2RC("juej"), "ㄐㄩㄝˋ")
    XCTAssertEqual(c.cS2RC("jum"), "ㄐㄩㄢ")
    XCTAssertEqual(c.cS2RC("jumf"), "ㄐㄩㄢˇ")
    XCTAssertEqual(c.cS2RC("jumj"), "ㄐㄩㄢˋ")
    XCTAssertEqual(c.cS2RC("jun"), "ㄐㄩㄣ")
    XCTAssertEqual(c.cS2RC("jund"), "ㄐㄩㄣˊ")
    XCTAssertEqual(c.cS2RC("junf"), "ㄐㄩㄣˇ")
    XCTAssertEqual(c.cS2RC("junj"), "ㄐㄩㄣˋ")
    XCTAssertEqual(c.cS2RC("jul"), "ㄐㄩㄥ")
    XCTAssertEqual(c.cS2RC("julf"), "ㄐㄩㄥˇ")
    XCTAssertEqual(c.cS2RC("julj"), "ㄐㄩㄥˋ")
    XCTAssertEqual(c.cS2RC("vs"), "ㄑ˙")
    XCTAssertEqual(c.cS2RC("ve"), "ㄑㄧ")
    XCTAssertEqual(c.cS2RC("ved"), "ㄑㄧˊ")
    XCTAssertEqual(c.cS2RC("vef"), "ㄑㄧˇ")
    XCTAssertEqual(c.cS2RC("vej"), "ㄑㄧˋ")
    XCTAssertEqual(c.cS2RC("vey"), "ㄑㄧㄚ")
    XCTAssertEqual(c.cS2RC("veyd"), "ㄑㄧㄚˊ")
    XCTAssertEqual(c.cS2RC("veyf"), "ㄑㄧㄚˇ")
    XCTAssertEqual(c.cS2RC("veyj"), "ㄑㄧㄚˋ")
    XCTAssertEqual(c.cS2RC("vee"), "ㄑㄧㄝ")
    XCTAssertEqual(c.cS2RC("veed"), "ㄑㄧㄝˊ")
    XCTAssertEqual(c.cS2RC("veef"), "ㄑㄧㄝˇ")
    XCTAssertEqual(c.cS2RC("veej"), "ㄑㄧㄝˋ")
    XCTAssertEqual(c.cS2RC("vew"), "ㄑㄧㄠ")
    XCTAssertEqual(c.cS2RC("vewd"), "ㄑㄧㄠˊ")
    XCTAssertEqual(c.cS2RC("vewf"), "ㄑㄧㄠˇ")
    XCTAssertEqual(c.cS2RC("vewj"), "ㄑㄧㄠˋ")
    XCTAssertEqual(c.cS2RC("veo"), "ㄑㄧㄡ")
    XCTAssertEqual(c.cS2RC("veod"), "ㄑㄧㄡˊ")
    XCTAssertEqual(c.cS2RC("veof"), "ㄑㄧㄡˇ")
    XCTAssertEqual(c.cS2RC("veoj"), "ㄑㄧㄡˋ")
    XCTAssertEqual(c.cS2RC("vem"), "ㄑㄧㄢ")
    XCTAssertEqual(c.cS2RC("vemd"), "ㄑㄧㄢˊ")
    XCTAssertEqual(c.cS2RC("vemf"), "ㄑㄧㄢˇ")
    XCTAssertEqual(c.cS2RC("vemj"), "ㄑㄧㄢˋ")
    XCTAssertEqual(c.cS2RC("ven"), "ㄑㄧㄣ")
    XCTAssertEqual(c.cS2RC("vend"), "ㄑㄧㄣˊ")
    XCTAssertEqual(c.cS2RC("venf"), "ㄑㄧㄣˇ")
    XCTAssertEqual(c.cS2RC("venj"), "ㄑㄧㄣˋ")
    XCTAssertEqual(c.cS2RC("vek"), "ㄑㄧㄤ")
    XCTAssertEqual(c.cS2RC("vekd"), "ㄑㄧㄤˊ")
    XCTAssertEqual(c.cS2RC("vekf"), "ㄑㄧㄤˇ")
    XCTAssertEqual(c.cS2RC("vekj"), "ㄑㄧㄤˋ")
    XCTAssertEqual(c.cS2RC("vel"), "ㄑㄧㄥ")
    XCTAssertEqual(c.cS2RC("veld"), "ㄑㄧㄥˊ")
    XCTAssertEqual(c.cS2RC("velf"), "ㄑㄧㄥˇ")
    XCTAssertEqual(c.cS2RC("velj"), "ㄑㄧㄥˋ")
    XCTAssertEqual(c.cS2RC("vu"), "ㄑㄩ")
    XCTAssertEqual(c.cS2RC("vud"), "ㄑㄩˊ")
    XCTAssertEqual(c.cS2RC("vuf"), "ㄑㄩˇ")
    XCTAssertEqual(c.cS2RC("vuj"), "ㄑㄩˋ")
    XCTAssertEqual(c.cS2RC("vue"), "ㄑㄩㄝ")
    XCTAssertEqual(c.cS2RC("vued"), "ㄑㄩㄝˊ")
    XCTAssertEqual(c.cS2RC("vuej"), "ㄑㄩㄝˋ")
    XCTAssertEqual(c.cS2RC("vum"), "ㄑㄩㄢ")
    XCTAssertEqual(c.cS2RC("vumd"), "ㄑㄩㄢˊ")
    XCTAssertEqual(c.cS2RC("vumf"), "ㄑㄩㄢˇ")
    XCTAssertEqual(c.cS2RC("vumj"), "ㄑㄩㄢˋ")
    XCTAssertEqual(c.cS2RC("vun"), "ㄑㄩㄣ")
    XCTAssertEqual(c.cS2RC("vund"), "ㄑㄩㄣˊ")
    XCTAssertEqual(c.cS2RC("vunf"), "ㄑㄩㄣˇ")
    XCTAssertEqual(c.cS2RC("vunj"), "ㄑㄩㄣˋ")
    XCTAssertEqual(c.cS2RC("vul"), "ㄑㄩㄥ")
    XCTAssertEqual(c.cS2RC("vuld"), "ㄑㄩㄥˊ")
    XCTAssertEqual(c.cS2RC("vulf"), "ㄑㄩㄥˇ")
    XCTAssertEqual(c.cS2RC("vulj"), "ㄑㄩㄥˋ")
    XCTAssertEqual(c.cS2RC("ce"), "ㄒㄧ")
    XCTAssertEqual(c.cS2RC("ced"), "ㄒㄧˊ")
    XCTAssertEqual(c.cS2RC("cef"), "ㄒㄧˇ")
    XCTAssertEqual(c.cS2RC("cej"), "ㄒㄧˋ")
    XCTAssertEqual(c.cS2RC("cey"), "ㄒㄧㄚ")
    XCTAssertEqual(c.cS2RC("ceyd"), "ㄒㄧㄚˊ")
    XCTAssertEqual(c.cS2RC("ceyf"), "ㄒㄧㄚˇ")
    XCTAssertEqual(c.cS2RC("ceyj"), "ㄒㄧㄚˋ")
    XCTAssertEqual(c.cS2RC("cee"), "ㄒㄧㄝ")
    XCTAssertEqual(c.cS2RC("ceed"), "ㄒㄧㄝˊ")
    XCTAssertEqual(c.cS2RC("ceef"), "ㄒㄧㄝˇ")
    XCTAssertEqual(c.cS2RC("ceej"), "ㄒㄧㄝˋ")
    XCTAssertEqual(c.cS2RC("cew"), "ㄒㄧㄠ")
    XCTAssertEqual(c.cS2RC("cewd"), "ㄒㄧㄠˊ")
    XCTAssertEqual(c.cS2RC("cewf"), "ㄒㄧㄠˇ")
    XCTAssertEqual(c.cS2RC("cewj"), "ㄒㄧㄠˋ")
    XCTAssertEqual(c.cS2RC("ceo"), "ㄒㄧㄡ")
    XCTAssertEqual(c.cS2RC("ceod"), "ㄒㄧㄡˊ")
    XCTAssertEqual(c.cS2RC("ceof"), "ㄒㄧㄡˇ")
    XCTAssertEqual(c.cS2RC("ceoj"), "ㄒㄧㄡˋ")
    XCTAssertEqual(c.cS2RC("cem"), "ㄒㄧㄢ")
    XCTAssertEqual(c.cS2RC("cemd"), "ㄒㄧㄢˊ")
    XCTAssertEqual(c.cS2RC("cemf"), "ㄒㄧㄢˇ")
    XCTAssertEqual(c.cS2RC("cemj"), "ㄒㄧㄢˋ")
    XCTAssertEqual(c.cS2RC("cen"), "ㄒㄧㄣ")
    XCTAssertEqual(c.cS2RC("cend"), "ㄒㄧㄣˊ")
    XCTAssertEqual(c.cS2RC("cenf"), "ㄒㄧㄣˇ")
    XCTAssertEqual(c.cS2RC("cenj"), "ㄒㄧㄣˋ")
    XCTAssertEqual(c.cS2RC("cek"), "ㄒㄧㄤ")
    XCTAssertEqual(c.cS2RC("cekd"), "ㄒㄧㄤˊ")
    XCTAssertEqual(c.cS2RC("cekf"), "ㄒㄧㄤˇ")
    XCTAssertEqual(c.cS2RC("cekj"), "ㄒㄧㄤˋ")
    XCTAssertEqual(c.cS2RC("cel"), "ㄒㄧㄥ")
    XCTAssertEqual(c.cS2RC("celd"), "ㄒㄧㄥˊ")
    XCTAssertEqual(c.cS2RC("celf"), "ㄒㄧㄥˇ")
    XCTAssertEqual(c.cS2RC("celj"), "ㄒㄧㄥˋ")
    XCTAssertEqual(c.cS2RC("cu"), "ㄒㄩ")
    XCTAssertEqual(c.cS2RC("cud"), "ㄒㄩˊ")
    XCTAssertEqual(c.cS2RC("cuf"), "ㄒㄩˇ")
    XCTAssertEqual(c.cS2RC("cuj"), "ㄒㄩˋ")
    XCTAssertEqual(c.cS2RC("cue"), "ㄒㄩㄝ")
    XCTAssertEqual(c.cS2RC("cued"), "ㄒㄩㄝˊ")
    XCTAssertEqual(c.cS2RC("cuef"), "ㄒㄩㄝˇ")
    XCTAssertEqual(c.cS2RC("cuej"), "ㄒㄩㄝˋ")
    XCTAssertEqual(c.cS2RC("cum"), "ㄒㄩㄢ")
    XCTAssertEqual(c.cS2RC("cumd"), "ㄒㄩㄢˊ")
    XCTAssertEqual(c.cS2RC("cumf"), "ㄒㄩㄢˇ")
    XCTAssertEqual(c.cS2RC("cumj"), "ㄒㄩㄢˋ")
    XCTAssertEqual(c.cS2RC("cun"), "ㄒㄩㄣ")
    XCTAssertEqual(c.cS2RC("cund"), "ㄒㄩㄣˊ")
    XCTAssertEqual(c.cS2RC("cunj"), "ㄒㄩㄣˋ")
    XCTAssertEqual(c.cS2RC("cul"), "ㄒㄩㄥ")
    XCTAssertEqual(c.cS2RC("culd"), "ㄒㄩㄥˊ")
    XCTAssertEqual(c.cS2RC("culf"), "ㄒㄩㄥˇ")
    XCTAssertEqual(c.cS2RC("culj"), "ㄒㄩㄥˋ")
    XCTAssertEqual(c.cS2RC("j"), "ㄓ")
    XCTAssertEqual(c.cS2RC("jd"), "ㄓˊ")
    XCTAssertEqual(c.cS2RC("jf"), "ㄓˇ")
    XCTAssertEqual(c.cS2RC("jj"), "ㄓˋ")
    XCTAssertEqual(c.cS2RC("jy"), "ㄓㄚ")
    XCTAssertEqual(c.cS2RC("jyd"), "ㄓㄚˊ")
    XCTAssertEqual(c.cS2RC("jyf"), "ㄓㄚˇ")
    XCTAssertEqual(c.cS2RC("jyj"), "ㄓㄚˋ")
    XCTAssertEqual(c.cS2RC("jg"), "ㄓㄜ")
    XCTAssertEqual(c.cS2RC("jgd"), "ㄓㄜˊ")
    XCTAssertEqual(c.cS2RC("jgf"), "ㄓㄜˇ")
    XCTAssertEqual(c.cS2RC("jgj"), "ㄓㄜˋ")
    XCTAssertEqual(c.cS2RC("jgs"), "ㄓㄜ˙")
    XCTAssertEqual(c.cS2RC("ji"), "ㄓㄞ")
    XCTAssertEqual(c.cS2RC("jid"), "ㄓㄞˊ")
    XCTAssertEqual(c.cS2RC("jif"), "ㄓㄞˇ")
    XCTAssertEqual(c.cS2RC("jij"), "ㄓㄞˋ")
    XCTAssertEqual(c.cS2RC("jaj"), "ㄓㄟˋ")
    XCTAssertEqual(c.cS2RC("jw"), "ㄓㄠ")
    XCTAssertEqual(c.cS2RC("jwd"), "ㄓㄠˊ")
    XCTAssertEqual(c.cS2RC("jwf"), "ㄓㄠˇ")
    XCTAssertEqual(c.cS2RC("jwj"), "ㄓㄠˋ")
    XCTAssertEqual(c.cS2RC("jo"), "ㄓㄡ")
    XCTAssertEqual(c.cS2RC("jod"), "ㄓㄡˊ")
    XCTAssertEqual(c.cS2RC("jof"), "ㄓㄡˇ")
    XCTAssertEqual(c.cS2RC("joj"), "ㄓㄡˋ")
    XCTAssertEqual(c.cS2RC("jm"), "ㄓㄢ")
    XCTAssertEqual(c.cS2RC("jmf"), "ㄓㄢˇ")
    XCTAssertEqual(c.cS2RC("jmj"), "ㄓㄢˋ")
    XCTAssertEqual(c.cS2RC("jn"), "ㄓㄣ")
    XCTAssertEqual(c.cS2RC("jnd"), "ㄓㄣˊ")
    XCTAssertEqual(c.cS2RC("jnf"), "ㄓㄣˇ")
    XCTAssertEqual(c.cS2RC("jnj"), "ㄓㄣˋ")
    XCTAssertEqual(c.cS2RC("jk"), "ㄓㄤ")
    XCTAssertEqual(c.cS2RC("jkf"), "ㄓㄤˇ")
    XCTAssertEqual(c.cS2RC("jkj"), "ㄓㄤˋ")
    XCTAssertEqual(c.cS2RC("jl"), "ㄓㄥ")
    XCTAssertEqual(c.cS2RC("jlf"), "ㄓㄥˇ")
    XCTAssertEqual(c.cS2RC("jlj"), "ㄓㄥˋ")
    XCTAssertEqual(c.cS2RC("jx"), "ㄓㄨ")
    XCTAssertEqual(c.cS2RC("jxd"), "ㄓㄨˊ")
    XCTAssertEqual(c.cS2RC("jxf"), "ㄓㄨˇ")
    XCTAssertEqual(c.cS2RC("jxj"), "ㄓㄨˋ")
    XCTAssertEqual(c.cS2RC("jxy"), "ㄓㄨㄚ")
    XCTAssertEqual(c.cS2RC("jxyf"), "ㄓㄨㄚˇ")
    XCTAssertEqual(c.cS2RC("jxh"), "ㄓㄨㄛ")
  }
}
