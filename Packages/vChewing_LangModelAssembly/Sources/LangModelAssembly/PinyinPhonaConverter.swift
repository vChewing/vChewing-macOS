// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// 該檔案使得 LMAssembly 擺脫對 Tekkon 的依賴。

private typealias LengthSortedDictionary = [Int: [String: String]]

private let mapHanyuPinyinToPhonabets: LengthSortedDictionary = {
  let parsed = try? JSONDecoder().decode(
    LengthSortedDictionary.self,
    from: jsnHanyuPinyinToMPS.data(using: .utf8) ?? Data([])
  )
  return parsed ?? [:]
}()

extension String {
  mutating func convertToPhonabets(newToneOne: String = "") {
    if isEmpty || contains("_") || !isNotPureAlphanumerical { return }
    let lengths = mapHanyuPinyinToPhonabets.keys.sorted().reversed()
    lengths.forEach { length in
      mapHanyuPinyinToPhonabets[length]?.forEach { key, value in
        self = replacingOccurrences(of: key, with: value)
      }
    }
    self = replacingOccurrences(of: " ", with: newToneOne)
  }
}

/// 偵測字串是否包含半形英數內容
extension String {
  fileprivate var isNotPureAlphanumerical: Bool {
    let x = unicodeScalars.map(\.value).filter {
      if $0 >= 48, $0 <= 57 { return false }
      if $0 >= 65, $0 <= 90 { return false }
      if $0 >= 97, $0 <= 122 { return false }
      return true
    }
    return !x.isEmpty
  }
}

private let jsnHanyuPinyinToMPS = #"""
{
"1":{"1":" ","2":"ˊ","3":"ˇ","4":"ˋ","5":"˙","a":"ㄚ","e":"ㄜ","o":"ㄛ","q":"ㄑ"},
"2":{"ai":"ㄞ","an":"ㄢ","ao":"ㄠ","ba":"ㄅㄚ","bi":"ㄅㄧ","bo":"ㄅㄛ","bu":"ㄅㄨ",
  "ca":"ㄘㄚ","ce":"ㄘㄜ","ci":"ㄘ","cu":"ㄘㄨ","da":"ㄉㄚ","de":"ㄉㄜ","di":"ㄉㄧ",
  "du":"ㄉㄨ","eh":"ㄝ","ei":"ㄟ","en":"ㄣ","er":"ㄦ","fa":"ㄈㄚ","fo":"ㄈㄛ",
  "fu":"ㄈㄨ","ga":"ㄍㄚ","ge":"ㄍㄜ","gi":"ㄍㄧ","gu":"ㄍㄨ","ha":"ㄏㄚ","he":"ㄏㄜ",
  "hu":"ㄏㄨ","ji":"ㄐㄧ","ju":"ㄐㄩ","ka":"ㄎㄚ","ke":"ㄎㄜ","ku":"ㄎㄨ","la":"ㄌㄚ",
  "le":"ㄌㄜ","li":"ㄌㄧ","lo":"ㄌㄛ","lu":"ㄌㄨ","lv":"ㄌㄩ","ma":"ㄇㄚ","me":"ㄇㄜ",
  "mi":"ㄇㄧ","mo":"ㄇㄛ","mu":"ㄇㄨ","na":"ㄋㄚ","ne":"ㄋㄜ","ni":"ㄋㄧ","nu":"ㄋㄨ",
  "nv":"ㄋㄩ","ou":"ㄡ","pa":"ㄆㄚ","pi":"ㄆㄧ","po":"ㄆㄛ","pu":"ㄆㄨ","qi":"ㄑㄧ",
  "qu":"ㄑㄩ","re":"ㄖㄜ","ri":"ㄖ","ru":"ㄖㄨ","sa":"ㄙㄚ","se":"ㄙㄜ","si":"ㄙ",
  "su":"ㄙㄨ","ta":"ㄊㄚ","te":"ㄊㄜ","ti":"ㄊㄧ","tu":"ㄊㄨ","wa":"ㄨㄚ","wo":"ㄨㄛ",
  "wu":"ㄨ","xi":"ㄒㄧ","xu":"ㄒㄩ","ya":"ㄧㄚ","ye":"ㄧㄝ","yi":"ㄧ","yo":"ㄧㄛ",
  "yu":"ㄩ","za":"ㄗㄚ","ze":"ㄗㄜ","zi":"ㄗ","zu":"ㄗㄨ"},
"3":{"ang":"ㄤ","bai":"ㄅㄞ","ban":"ㄅㄢ","bao":"ㄅㄠ","bei":"ㄅㄟ","ben":"ㄅㄣ",
  "bie":"ㄅㄧㄝ","bin":"ㄅㄧㄣ","cai":"ㄘㄞ","can":"ㄘㄢ","cao":"ㄘㄠ","cei":"ㄘㄟ",
  "cen":"ㄘㄣ","cha":"ㄔㄚ","che":"ㄔㄜ","chi":"ㄔ","chu":"ㄔㄨ","cou":"ㄘㄡ",
  "cui":"ㄘㄨㄟ","cun":"ㄘㄨㄣ","cuo":"ㄘㄨㄛ","dai":"ㄉㄞ","dan":"ㄉㄢ","dao":"ㄉㄠ",
  "dei":"ㄉㄟ","den":"ㄉㄣ","dia":"ㄉㄧㄚ","die":"ㄉㄧㄝ","diu":"ㄉㄧㄡ","dou":"ㄉㄡ",
  "dui":"ㄉㄨㄟ","dun":"ㄉㄨㄣ","duo":"ㄉㄨㄛ","eng":"ㄥ","fan":"ㄈㄢ","fei":"ㄈㄟ",
  "fen":"ㄈㄣ","fou":"ㄈㄡ","gai":"ㄍㄞ","gan":"ㄍㄢ","gao":"ㄍㄠ","gei":"ㄍㄟ",
  "gen":"ㄍㄣ","gin":"ㄍㄧㄣ","gou":"ㄍㄡ","gua":"ㄍㄨㄚ","gue":"ㄍㄨㄜ","gui":"ㄍㄨㄟ",
  "gun":"ㄍㄨㄣ","guo":"ㄍㄨㄛ","hai":"ㄏㄞ","han":"ㄏㄢ","hao":"ㄏㄠ","hei":"ㄏㄟ",
  "hen":"ㄏㄣ","hou":"ㄏㄡ","hua":"ㄏㄨㄚ","hui":"ㄏㄨㄟ","hun":"ㄏㄨㄣ","huo":"ㄏㄨㄛ",
  "jia":"ㄐㄧㄚ","jie":"ㄐㄧㄝ","jin":"ㄐㄧㄣ","jiu":"ㄐㄧㄡ","jue":"ㄐㄩㄝ",
  "jun":"ㄐㄩㄣ","kai":"ㄎㄞ","kan":"ㄎㄢ","kao":"ㄎㄠ","ken":"ㄎㄣ","kiu":"ㄎㄧㄡ",
  "kou":"ㄎㄡ","kua":"ㄎㄨㄚ","kui":"ㄎㄨㄟ","kun":"ㄎㄨㄣ","kuo":"ㄎㄨㄛ","lai":"ㄌㄞ",
  "lan":"ㄌㄢ","lao":"ㄌㄠ","lei":"ㄌㄟ","lia":"ㄌㄧㄚ","lie":"ㄌㄧㄝ","lin":"ㄌㄧㄣ",
  "liu":"ㄌㄧㄡ","lou":"ㄌㄡ","lun":"ㄌㄨㄣ","luo":"ㄌㄨㄛ","lve":"ㄌㄩㄝ","mai":"ㄇㄞ",
  "man":"ㄇㄢ","mao":"ㄇㄠ","mei":"ㄇㄟ","men":"ㄇㄣ","mie":"ㄇㄧㄝ","min":"ㄇㄧㄣ",
  "miu":"ㄇㄧㄡ","mou":"ㄇㄡ","nai":"ㄋㄞ","nan":"ㄋㄢ","nao":"ㄋㄠ","nei":"ㄋㄟ",
  "nen":"ㄋㄣ","nie":"ㄋㄧㄝ","nin":"ㄋㄧㄣ","niu":"ㄋㄧㄡ","nou":"ㄋㄡ","nui":"ㄋㄨㄟ",
  "nun":"ㄋㄨㄣ","nuo":"ㄋㄨㄛ","nve":"ㄋㄩㄝ","pai":"ㄆㄞ","pan":"ㄆㄢ","pao":"ㄆㄠ",
  "pei":"ㄆㄟ","pen":"ㄆㄣ","pia":"ㄆㄧㄚ","pie":"ㄆㄧㄝ","pin":"ㄆㄧㄣ","pou":"ㄆㄡ",
  "qia":"ㄑㄧㄚ","qie":"ㄑㄧㄝ","qin":"ㄑㄧㄣ","qiu":"ㄑㄧㄡ","que":"ㄑㄩㄝ",
  "qun":"ㄑㄩㄣ","ran":"ㄖㄢ","rao":"ㄖㄠ","ren":"ㄖㄣ","rou":"ㄖㄡ","rui":"ㄖㄨㄟ",
  "run":"ㄖㄨㄣ","ruo":"ㄖㄨㄛ","sai":"ㄙㄞ","san":"ㄙㄢ","sao":"ㄙㄠ","sei":"ㄙㄟ",
  "sen":"ㄙㄣ","sha":"ㄕㄚ","she":"ㄕㄜ","shi":"ㄕ","shu":"ㄕㄨ","sou":"ㄙㄡ",
  "sui":"ㄙㄨㄟ","sun":"ㄙㄨㄣ","suo":"ㄙㄨㄛ","tai":"ㄊㄞ","tan":"ㄊㄢ","tao":"ㄊㄠ",
  "tie":"ㄊㄧㄝ","tou":"ㄊㄡ","tui":"ㄊㄨㄟ","tun":"ㄊㄨㄣ","tuo":"ㄊㄨㄛ",
  "wai":"ㄨㄞ","wan":"ㄨㄢ","wei":"ㄨㄟ","wen":"ㄨㄣ","xia":"ㄒㄧㄚ","xie":"ㄒㄧㄝ",
  "xin":"ㄒㄧㄣ","xiu":"ㄒㄧㄡ","xue":"ㄒㄩㄝ","xun":"ㄒㄩㄣ","yai":"ㄧㄞ",
  "yan":"ㄧㄢ","yao":"ㄧㄠ","yin":"ㄧㄣ","you":"ㄧㄡ","yue":"ㄩㄝ","yun":"ㄩㄣ",
  "zai":"ㄗㄞ","zan":"ㄗㄢ","zao":"ㄗㄠ","zei":"ㄗㄟ","zen":"ㄗㄣ","zha":"ㄓㄚ",
  "zhe":"ㄓㄜ","zhi":"ㄓ","zhu":"ㄓㄨ","zou":"ㄗㄡ","zui":"ㄗㄨㄟ","zun":"ㄗㄨㄣ",
  "zuo":"ㄗㄨㄛ"},
"4":{"bang":"ㄅㄤ","beng":"ㄅㄥ","bian":"ㄅㄧㄢ","biao":"ㄅㄧㄠ","bing":"ㄅㄧㄥ",
  "cang":"ㄘㄤ","ceng":"ㄘㄥ","chai":"ㄔㄞ","chan":"ㄔㄢ","chao":"ㄔㄠ","chen":"ㄔㄣ",
  "chou":"ㄔㄡ","chua":"ㄔㄨㄚ","chui":"ㄔㄨㄟ","chun":"ㄔㄨㄣ","chuo":"ㄔㄨㄛ",
  "cong":"ㄘㄨㄥ","cuan":"ㄘㄨㄢ","dang":"ㄉㄤ","deng":"ㄉㄥ","dian":"ㄉㄧㄢ",
  "diao":"ㄉㄧㄠ","ding":"ㄉㄧㄥ","dong":"ㄉㄨㄥ","duan":"ㄉㄨㄢ","fang":"ㄈㄤ",
  "feng":"ㄈㄥ","fiao":"ㄈㄧㄠ","fong":"ㄈㄨㄥ","gang":"ㄍㄤ","geng":"ㄍㄥ",
  "giao":"ㄍㄧㄠ","gong":"ㄍㄨㄥ","guai":"ㄍㄨㄞ","guan":"ㄍㄨㄢ","hang":"ㄏㄤ",
  "heng":"ㄏㄥ","hong":"ㄏㄨㄥ","huai":"ㄏㄨㄞ","huan":"ㄏㄨㄢ","jian":"ㄐㄧㄢ",
  "jiao":"ㄐㄧㄠ","jing":"ㄐㄧㄥ","juan":"ㄐㄩㄢ","kang":"ㄎㄤ","keng":"ㄎㄥ",
  "kong":"ㄎㄨㄥ","kuai":"ㄎㄨㄞ","kuan":"ㄎㄨㄢ","lang":"ㄌㄤ","leng":"ㄌㄥ",
  "lian":"ㄌㄧㄢ","liao":"ㄌㄧㄠ","ling":"ㄌㄧㄥ","long":"ㄌㄨㄥ","luan":"ㄌㄨㄢ",
  "lvan":"ㄌㄩㄢ","mang":"ㄇㄤ","meng":"ㄇㄥ","mian":"ㄇㄧㄢ","miao":"ㄇㄧㄠ",
  "ming":"ㄇㄧㄥ","nang":"ㄋㄤ","neng":"ㄋㄥ","nian":"ㄋㄧㄢ","niao":"ㄋㄧㄠ",
  "ning":"ㄋㄧㄥ","nong":"ㄋㄨㄥ","nuan":"ㄋㄨㄢ","pang":"ㄆㄤ","peng":"ㄆㄥ",
  "pian":"ㄆㄧㄢ","piao":"ㄆㄧㄠ","ping":"ㄆㄧㄥ","qian":"ㄑㄧㄢ","qiao":"ㄑㄧㄠ",
  "qing":"ㄑㄧㄥ","quan":"ㄑㄩㄢ","rang":"ㄖㄤ","reng":"ㄖㄥ","rong":"ㄖㄨㄥ",
  "ruan":"ㄖㄨㄢ","sang":"ㄙㄤ","seng":"ㄙㄥ","shai":"ㄕㄞ","shan":"ㄕㄢ",
  "shao":"ㄕㄠ","shei":"ㄕㄟ","shen":"ㄕㄣ","shou":"ㄕㄡ","shua":"ㄕㄨㄚ",
  "shui":"ㄕㄨㄟ","shun":"ㄕㄨㄣ","shuo":"ㄕㄨㄛ","song":"ㄙㄨㄥ","suan":"ㄙㄨㄢ",
  "tang":"ㄊㄤ","teng":"ㄊㄥ","tian":"ㄊㄧㄢ","tiao":"ㄊㄧㄠ","ting":"ㄊㄧㄥ",
  "tong":"ㄊㄨㄥ","tuan":"ㄊㄨㄢ","wang":"ㄨㄤ","weng":"ㄨㄥ","xian":"ㄒㄧㄢ",
  "xiao":"ㄒㄧㄠ","xing":"ㄒㄧㄥ","xuan":"ㄒㄩㄢ","yang":"ㄧㄤ","ying":"ㄧㄥ",
  "yong":"ㄩㄥ","yuan":"ㄩㄢ","zang":"ㄗㄤ","zeng":"ㄗㄥ","zhai":"ㄓㄞ",
  "zhan":"ㄓㄢ","zhao":"ㄓㄠ","zhei":"ㄓㄟ","zhen":"ㄓㄣ","zhou":"ㄓㄡ",
  "zhua":"ㄓㄨㄚ","zhui":"ㄓㄨㄟ","zhun":"ㄓㄨㄣ","zhuo":"ㄓㄨㄛ",
  "zong":"ㄗㄨㄥ","zuan":"ㄗㄨㄢ"},
"5":{"biang":"ㄅㄧㄤ","chang":"ㄔㄤ","cheng":"ㄔㄥ","chong":"ㄔㄨㄥ","chuai":"ㄔㄨㄞ",
  "chuan":"ㄔㄨㄢ","duang":"ㄉㄨㄤ","guang":"ㄍㄨㄤ","huang":"ㄏㄨㄤ","jiang":"ㄐㄧㄤ",
  "jiong":"ㄐㄩㄥ","kiang":"ㄎㄧㄤ","kuang":"ㄎㄨㄤ","liang":"ㄌㄧㄤ","niang":"ㄋㄧㄤ",
  "qiang":"ㄑㄧㄤ","qiong":"ㄑㄩㄥ","shang":"ㄕㄤ","sheng":"ㄕㄥ","shuai":"ㄕㄨㄞ",
  "shuan":"ㄕㄨㄢ","xiang":"ㄒㄧㄤ","xiong":"ㄒㄩㄥ","zhang":"ㄓㄤ","zheng":"ㄓㄥ",
  "zhong":"ㄓㄨㄥ","zhuai":"ㄓㄨㄞ","zhuan":"ㄓㄨㄢ"},
"6":{"chuang":"ㄔㄨㄤ","shuang":"ㄕㄨㄤ","zhuang":"ㄓㄨㄤ"}
}
"""#
