// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
documentation files (the "Software"), to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and
to permit persons to whom the Software is furnished to do so, subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service marks, or product names of Contributor,
   except as required to fulfill notice requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import Foundation

extension String {
    mutating func regReplace(pattern: String, replaceWith: String = "") {
        // Ref: https://stackoverflow.com/a/40993403/4162914 && https://stackoverflow.com/a/71291137/4162914
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .anchorsMatchLines])
            let range = NSRange(self.startIndex..., in: self)
            self = regex.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: replaceWith)
        } catch { return }
    }
    mutating func formatConsolidate(HYPY2BPMF: Bool) {
        // Step 1: Consolidating formats per line.
        var strProcessed = self
        // 預處理格式
        strProcessed = strProcessed.replacingOccurrences(of: " #MACOS", with: "") // 去掉 macOS 標記
        // CJKWhiteSpace (\x{3000}) to ASCII Space
        // NonBreakWhiteSpace (\x{A0}) to ASCII Space
        // Tab to ASCII Space
        // 統整連續空格為一個 ASCII 空格
        strProcessed.regReplace(pattern: #"( +|　+| +|\t+)+"#, replaceWith: " ")
        strProcessed.regReplace(pattern: #"(^ | $)"#, replaceWith: "") // 去除行尾行首空格
        strProcessed.regReplace(pattern: #"(\f+|\r+|\n+)+"#, replaceWith: "\n") // CR & Form Feed to LF, 且去除重複行
        if strProcessed.prefix(1) == " " { // 去除檔案開頭空格
            strProcessed.removeFirst()
        }
        if strProcessed.suffix(1) == " " { // 去除檔案結尾空格
            strProcessed.removeLast()
        }
        var arrData = [""]
        if HYPY2BPMF {
            // Step 0: Convert HanyuPinyin to Bopomofo.
            arrData = strProcessed.components(separatedBy: "\n")
            strProcessed = "" // Reset its value
            for lineData in arrData {
                var varLineData = lineData
                // 漢語拼音轉注音，得先從最長的可能的拼音組合開始轉起，
                // 這樣等轉換到更短的可能的漢語拼音組合時就不會出錯。
                // 依此類推，聲調放在最後來轉換。
                varLineData.regReplace(pattern: "chuang", replaceWith: "ㄔㄨㄤ")
                varLineData.regReplace(pattern: "shuang", replaceWith: "ㄕㄨㄤ")
                varLineData.regReplace(pattern: "zhuang", replaceWith: "ㄓㄨㄤ")
                varLineData.regReplace(pattern: "chang", replaceWith: "ㄔㄤ")
                varLineData.regReplace(pattern: "cheng", replaceWith: "ㄔㄥ")
                varLineData.regReplace(pattern: "chong", replaceWith: "ㄔㄨㄥ")
                varLineData.regReplace(pattern: "chuai", replaceWith: "ㄔㄨㄞ")
                varLineData.regReplace(pattern: "chuan", replaceWith: "ㄔㄨㄢ")
                varLineData.regReplace(pattern: "guang", replaceWith: "ㄍㄨㄤ")
                varLineData.regReplace(pattern: "huang", replaceWith: "ㄏㄨㄤ")
                varLineData.regReplace(pattern: "jiang", replaceWith: "ㄐㄧㄤ")
                varLineData.regReplace(pattern: "jiong", replaceWith: "ㄐㄩㄥ")
                varLineData.regReplace(pattern: "kuang", replaceWith: "ㄎㄨㄤ")
                varLineData.regReplace(pattern: "liang", replaceWith: "ㄌㄧㄤ")
                varLineData.regReplace(pattern: "niang", replaceWith: "ㄋㄧㄤ")
                varLineData.regReplace(pattern: "qiang", replaceWith: "ㄑㄧㄤ")
                varLineData.regReplace(pattern: "qiong", replaceWith: "ㄑㄩㄥ")
                varLineData.regReplace(pattern: "shang", replaceWith: "ㄕㄤ")
                varLineData.regReplace(pattern: "sheng", replaceWith: "ㄕㄥ")
                varLineData.regReplace(pattern: "shuai", replaceWith: "ㄕㄨㄞ")
                varLineData.regReplace(pattern: "shuan", replaceWith: "ㄕㄨㄢ")
                varLineData.regReplace(pattern: "xiang", replaceWith: "ㄒㄧㄤ")
                varLineData.regReplace(pattern: "xiong", replaceWith: "ㄒㄩㄥ")
                varLineData.regReplace(pattern: "zhang", replaceWith: "ㄓㄤ")
                varLineData.regReplace(pattern: "zheng", replaceWith: "ㄓㄥ")
                varLineData.regReplace(pattern: "zhong", replaceWith: "ㄓㄨㄥ")
                varLineData.regReplace(pattern: "zhuai", replaceWith: "ㄓㄨㄞ")
                varLineData.regReplace(pattern: "zhuan", replaceWith: "ㄓㄨㄢ")
                varLineData.regReplace(pattern: "bang", replaceWith: "ㄅㄤ")
                varLineData.regReplace(pattern: "beng", replaceWith: "ㄅㄥ")
                varLineData.regReplace(pattern: "bian", replaceWith: "ㄅㄧㄢ")
                varLineData.regReplace(pattern: "biao", replaceWith: "ㄅㄧㄠ")
                varLineData.regReplace(pattern: "bing", replaceWith: "ㄅㄧㄥ")
                varLineData.regReplace(pattern: "cang", replaceWith: "ㄘㄤ")
                varLineData.regReplace(pattern: "ceng", replaceWith: "ㄘㄥ")
                varLineData.regReplace(pattern: "chai", replaceWith: "ㄔㄞ")
                varLineData.regReplace(pattern: "chan", replaceWith: "ㄔㄢ")
                varLineData.regReplace(pattern: "chao", replaceWith: "ㄔㄠ")
                varLineData.regReplace(pattern: "chen", replaceWith: "ㄔㄣ")
                varLineData.regReplace(pattern: "chou", replaceWith: "ㄔㄡ")
                varLineData.regReplace(pattern: "chua", replaceWith: "ㄔㄨㄚ")
                varLineData.regReplace(pattern: "chui", replaceWith: "ㄔㄨㄟ")
                varLineData.regReplace(pattern: "chun", replaceWith: "ㄔㄨㄣ")
                varLineData.regReplace(pattern: "chuo", replaceWith: "ㄔㄨㄛ")
                varLineData.regReplace(pattern: "cong", replaceWith: "ㄘㄨㄥ")
                varLineData.regReplace(pattern: "cuan", replaceWith: "ㄘㄨㄢ")
                varLineData.regReplace(pattern: "dang", replaceWith: "ㄉㄤ")
                varLineData.regReplace(pattern: "deng", replaceWith: "ㄉㄥ")
                varLineData.regReplace(pattern: "dian", replaceWith: "ㄉㄧㄢ")
                varLineData.regReplace(pattern: "diao", replaceWith: "ㄉㄧㄠ")
                varLineData.regReplace(pattern: "ding", replaceWith: "ㄉㄧㄥ")
                varLineData.regReplace(pattern: "dong", replaceWith: "ㄉㄨㄥ")
                varLineData.regReplace(pattern: "duan", replaceWith: "ㄉㄨㄢ")
                varLineData.regReplace(pattern: "fang", replaceWith: "ㄈㄤ")
                varLineData.regReplace(pattern: "feng", replaceWith: "ㄈㄥ")
                varLineData.regReplace(pattern: "fiao", replaceWith: "ㄈㄧㄠ")
                varLineData.regReplace(pattern: "fong", replaceWith: "ㄈㄨㄥ")
                varLineData.regReplace(pattern: "gang", replaceWith: "ㄍㄤ")
                varLineData.regReplace(pattern: "geng", replaceWith: "ㄍㄥ")
                varLineData.regReplace(pattern: "giao", replaceWith: "ㄍㄧㄠ")
                varLineData.regReplace(pattern: "gong", replaceWith: "ㄍㄨㄥ")
                varLineData.regReplace(pattern: "guai", replaceWith: "ㄍㄨㄞ")
                varLineData.regReplace(pattern: "guan", replaceWith: "ㄍㄨㄢ")
                varLineData.regReplace(pattern: "hang", replaceWith: "ㄏㄤ")
                varLineData.regReplace(pattern: "heng", replaceWith: "ㄏㄥ")
                varLineData.regReplace(pattern: "hong", replaceWith: "ㄏㄨㄥ")
                varLineData.regReplace(pattern: "huai", replaceWith: "ㄏㄨㄞ")
                varLineData.regReplace(pattern: "huan", replaceWith: "ㄏㄨㄢ")
                varLineData.regReplace(pattern: "jian", replaceWith: "ㄐㄧㄢ")
                varLineData.regReplace(pattern: "jiao", replaceWith: "ㄐㄧㄠ")
                varLineData.regReplace(pattern: "jing", replaceWith: "ㄐㄧㄥ")
                varLineData.regReplace(pattern: "juan", replaceWith: "ㄐㄩㄢ")
                varLineData.regReplace(pattern: "kang", replaceWith: "ㄎㄤ")
                varLineData.regReplace(pattern: "keng", replaceWith: "ㄎㄥ")
                varLineData.regReplace(pattern: "kong", replaceWith: "ㄎㄨㄥ")
                varLineData.regReplace(pattern: "kuai", replaceWith: "ㄎㄨㄞ")
                varLineData.regReplace(pattern: "kuan", replaceWith: "ㄎㄨㄢ")
                varLineData.regReplace(pattern: "lang", replaceWith: "ㄌㄤ")
                varLineData.regReplace(pattern: "leng", replaceWith: "ㄌㄥ")
                varLineData.regReplace(pattern: "lian", replaceWith: "ㄌㄧㄢ")
                varLineData.regReplace(pattern: "liao", replaceWith: "ㄌㄧㄠ")
                varLineData.regReplace(pattern: "ling", replaceWith: "ㄌㄧㄥ")
                varLineData.regReplace(pattern: "long", replaceWith: "ㄌㄨㄥ")
                varLineData.regReplace(pattern: "luan", replaceWith: "ㄌㄨㄢ")
                varLineData.regReplace(pattern: "lvan", replaceWith: "ㄌㄩㄢ")
                varLineData.regReplace(pattern: "mang", replaceWith: "ㄇㄤ")
                varLineData.regReplace(pattern: "meng", replaceWith: "ㄇㄥ")
                varLineData.regReplace(pattern: "mian", replaceWith: "ㄇㄧㄢ")
                varLineData.regReplace(pattern: "miao", replaceWith: "ㄇㄧㄠ")
                varLineData.regReplace(pattern: "ming", replaceWith: "ㄇㄧㄥ")
                varLineData.regReplace(pattern: "nang", replaceWith: "ㄋㄤ")
                varLineData.regReplace(pattern: "neng", replaceWith: "ㄋㄥ")
                varLineData.regReplace(pattern: "nian", replaceWith: "ㄋㄧㄢ")
                varLineData.regReplace(pattern: "niao", replaceWith: "ㄋㄧㄠ")
                varLineData.regReplace(pattern: "ning", replaceWith: "ㄋㄧㄥ")
                varLineData.regReplace(pattern: "nong", replaceWith: "ㄋㄨㄥ")
                varLineData.regReplace(pattern: "nuan", replaceWith: "ㄋㄨㄢ")
                varLineData.regReplace(pattern: "pang", replaceWith: "ㄆㄤ")
                varLineData.regReplace(pattern: "peng", replaceWith: "ㄆㄥ")
                varLineData.regReplace(pattern: "pian", replaceWith: "ㄆㄧㄢ")
                varLineData.regReplace(pattern: "piao", replaceWith: "ㄆㄧㄠ")
                varLineData.regReplace(pattern: "ping", replaceWith: "ㄆㄧㄥ")
                varLineData.regReplace(pattern: "qian", replaceWith: "ㄑㄧㄢ")
                varLineData.regReplace(pattern: "qiao", replaceWith: "ㄑㄧㄠ")
                varLineData.regReplace(pattern: "qing", replaceWith: "ㄑㄧㄥ")
                varLineData.regReplace(pattern: "quan", replaceWith: "ㄑㄩㄢ")
                varLineData.regReplace(pattern: "rang", replaceWith: "ㄖㄤ")
                varLineData.regReplace(pattern: "reng", replaceWith: "ㄖㄥ")
                varLineData.regReplace(pattern: "rong", replaceWith: "ㄖㄨㄥ")
                varLineData.regReplace(pattern: "ruan", replaceWith: "ㄖㄨㄢ")
                varLineData.regReplace(pattern: "sang", replaceWith: "ㄙㄤ")
                varLineData.regReplace(pattern: "seng", replaceWith: "ㄙㄥ")
                varLineData.regReplace(pattern: "shai", replaceWith: "ㄕㄞ")
                varLineData.regReplace(pattern: "shan", replaceWith: "ㄕㄢ")
                varLineData.regReplace(pattern: "shao", replaceWith: "ㄕㄠ")
                varLineData.regReplace(pattern: "shei", replaceWith: "ㄕㄟ")
                varLineData.regReplace(pattern: "shen", replaceWith: "ㄕㄣ")
                varLineData.regReplace(pattern: "shou", replaceWith: "ㄕㄡ")
                varLineData.regReplace(pattern: "shua", replaceWith: "ㄕㄨㄚ")
                varLineData.regReplace(pattern: "shui", replaceWith: "ㄕㄨㄟ")
                varLineData.regReplace(pattern: "shun", replaceWith: "ㄕㄨㄣ")
                varLineData.regReplace(pattern: "shuo", replaceWith: "ㄕㄨㄛ")
                varLineData.regReplace(pattern: "song", replaceWith: "ㄙㄨㄥ")
                varLineData.regReplace(pattern: "suan", replaceWith: "ㄙㄨㄢ")
                varLineData.regReplace(pattern: "tang", replaceWith: "ㄊㄤ")
                varLineData.regReplace(pattern: "teng", replaceWith: "ㄊㄥ")
                varLineData.regReplace(pattern: "tian", replaceWith: "ㄊㄧㄢ")
                varLineData.regReplace(pattern: "tiao", replaceWith: "ㄊㄧㄠ")
                varLineData.regReplace(pattern: "ting", replaceWith: "ㄊㄧㄥ")
                varLineData.regReplace(pattern: "tong", replaceWith: "ㄊㄨㄥ")
                varLineData.regReplace(pattern: "tuan", replaceWith: "ㄊㄨㄢ")
                varLineData.regReplace(pattern: "wang", replaceWith: "ㄨㄤ")
                varLineData.regReplace(pattern: "weng", replaceWith: "ㄨㄥ")
                varLineData.regReplace(pattern: "xian", replaceWith: "ㄒㄧㄢ")
                varLineData.regReplace(pattern: "xiao", replaceWith: "ㄒㄧㄠ")
                varLineData.regReplace(pattern: "xing", replaceWith: "ㄒㄧㄥ")
                varLineData.regReplace(pattern: "xuan", replaceWith: "ㄒㄩㄢ")
                varLineData.regReplace(pattern: "yang", replaceWith: "ㄧㄤ")
                varLineData.regReplace(pattern: "ying", replaceWith: "ㄧㄥ")
                varLineData.regReplace(pattern: "yong", replaceWith: "ㄩㄥ")
                varLineData.regReplace(pattern: "yuan", replaceWith: "ㄩㄢ")
                varLineData.regReplace(pattern: "zang", replaceWith: "ㄗㄤ")
                varLineData.regReplace(pattern: "zeng", replaceWith: "ㄗㄥ")
                varLineData.regReplace(pattern: "zhai", replaceWith: "ㄓㄞ")
                varLineData.regReplace(pattern: "zhan", replaceWith: "ㄓㄢ")
                varLineData.regReplace(pattern: "zhao", replaceWith: "ㄓㄠ")
                varLineData.regReplace(pattern: "zhei", replaceWith: "ㄓㄟ")
                varLineData.regReplace(pattern: "zhen", replaceWith: "ㄓㄣ")
                varLineData.regReplace(pattern: "zhou", replaceWith: "ㄓㄡ")
                varLineData.regReplace(pattern: "zhua", replaceWith: "ㄓㄨㄚ")
                varLineData.regReplace(pattern: "zhui", replaceWith: "ㄓㄨㄟ")
                varLineData.regReplace(pattern: "zhun", replaceWith: "ㄓㄨㄣ")
                varLineData.regReplace(pattern: "zhuo", replaceWith: "ㄓㄨㄛ")
                varLineData.regReplace(pattern: "zong", replaceWith: "ㄗㄨㄥ")
                varLineData.regReplace(pattern: "zuan", replaceWith: "ㄗㄨㄢ")
                varLineData.regReplace(pattern: "jun", replaceWith: "ㄐㄩㄣ")
                varLineData.regReplace(pattern: "ang", replaceWith: "ㄤ")
                varLineData.regReplace(pattern: "bai", replaceWith: "ㄅㄞ")
                varLineData.regReplace(pattern: "ban", replaceWith: "ㄅㄢ")
                varLineData.regReplace(pattern: "bao", replaceWith: "ㄅㄠ")
                varLineData.regReplace(pattern: "bei", replaceWith: "ㄅㄟ")
                varLineData.regReplace(pattern: "ben", replaceWith: "ㄅㄣ")
                varLineData.regReplace(pattern: "bie", replaceWith: "ㄅㄧㄝ")
                varLineData.regReplace(pattern: "bin", replaceWith: "ㄅㄧㄣ")
                varLineData.regReplace(pattern: "cai", replaceWith: "ㄘㄞ")
                varLineData.regReplace(pattern: "can", replaceWith: "ㄘㄢ")
                varLineData.regReplace(pattern: "cao", replaceWith: "ㄘㄠ")
                varLineData.regReplace(pattern: "cei", replaceWith: "ㄘㄟ")
                varLineData.regReplace(pattern: "cen", replaceWith: "ㄘㄣ")
                varLineData.regReplace(pattern: "cha", replaceWith: "ㄔㄚ")
                varLineData.regReplace(pattern: "che", replaceWith: "ㄔㄜ")
                varLineData.regReplace(pattern: "chi", replaceWith: "ㄔ")
                varLineData.regReplace(pattern: "chu", replaceWith: "ㄔㄨ")
                varLineData.regReplace(pattern: "cou", replaceWith: "ㄘㄡ")
                varLineData.regReplace(pattern: "cui", replaceWith: "ㄘㄨㄟ")
                varLineData.regReplace(pattern: "cun", replaceWith: "ㄘㄨㄣ")
                varLineData.regReplace(pattern: "cuo", replaceWith: "ㄘㄨㄛ")
                varLineData.regReplace(pattern: "dai", replaceWith: "ㄉㄞ")
                varLineData.regReplace(pattern: "dan", replaceWith: "ㄉㄢ")
                varLineData.regReplace(pattern: "dao", replaceWith: "ㄉㄠ")
                varLineData.regReplace(pattern: "dei", replaceWith: "ㄉㄟ")
                varLineData.regReplace(pattern: "den", replaceWith: "ㄉㄣ")
                varLineData.regReplace(pattern: "dia", replaceWith: "ㄉㄧㄚ")
                varLineData.regReplace(pattern: "die", replaceWith: "ㄉㄧㄝ")
                varLineData.regReplace(pattern: "diu", replaceWith: "ㄉㄧㄡ")
                varLineData.regReplace(pattern: "dou", replaceWith: "ㄉㄡ")
                varLineData.regReplace(pattern: "dui", replaceWith: "ㄉㄨㄟ")
                varLineData.regReplace(pattern: "dun", replaceWith: "ㄉㄨㄣ")
                varLineData.regReplace(pattern: "duo", replaceWith: "ㄉㄨㄛ")
                varLineData.regReplace(pattern: "eng", replaceWith: "ㄥ")
                varLineData.regReplace(pattern: "fan", replaceWith: "ㄈㄢ")
                varLineData.regReplace(pattern: "fei", replaceWith: "ㄈㄟ")
                varLineData.regReplace(pattern: "fen", replaceWith: "ㄈㄣ")
                varLineData.regReplace(pattern: "fou", replaceWith: "ㄈㄡ")
                varLineData.regReplace(pattern: "gai", replaceWith: "ㄍㄞ")
                varLineData.regReplace(pattern: "gan", replaceWith: "ㄍㄢ")
                varLineData.regReplace(pattern: "gao", replaceWith: "ㄍㄠ")
                varLineData.regReplace(pattern: "gei", replaceWith: "ㄍㄟ")
                varLineData.regReplace(pattern: "gin", replaceWith: "ㄍㄧㄣ")
                varLineData.regReplace(pattern: "gen", replaceWith: "ㄍㄣ")
                varLineData.regReplace(pattern: "gou", replaceWith: "ㄍㄡ")
                varLineData.regReplace(pattern: "gua", replaceWith: "ㄍㄨㄚ")
                varLineData.regReplace(pattern: "gue", replaceWith: "ㄍㄨㄜ")
                varLineData.regReplace(pattern: "gui", replaceWith: "ㄍㄨㄟ")
                varLineData.regReplace(pattern: "gun", replaceWith: "ㄍㄨㄣ")
                varLineData.regReplace(pattern: "guo", replaceWith: "ㄍㄨㄛ")
                varLineData.regReplace(pattern: "hai", replaceWith: "ㄏㄞ")
                varLineData.regReplace(pattern: "han", replaceWith: "ㄏㄢ")
                varLineData.regReplace(pattern: "hao", replaceWith: "ㄏㄠ")
                varLineData.regReplace(pattern: "hei", replaceWith: "ㄏㄟ")
                varLineData.regReplace(pattern: "hen", replaceWith: "ㄏㄣ")
                varLineData.regReplace(pattern: "hou", replaceWith: "ㄏㄡ")
                varLineData.regReplace(pattern: "hua", replaceWith: "ㄏㄨㄚ")
                varLineData.regReplace(pattern: "hui", replaceWith: "ㄏㄨㄟ")
                varLineData.regReplace(pattern: "hun", replaceWith: "ㄏㄨㄣ")
                varLineData.regReplace(pattern: "huo", replaceWith: "ㄏㄨㄛ")
                varLineData.regReplace(pattern: "jia", replaceWith: "ㄐㄧㄚ")
                varLineData.regReplace(pattern: "jie", replaceWith: "ㄐㄧㄝ")
                varLineData.regReplace(pattern: "jin", replaceWith: "ㄐㄧㄣ")
                varLineData.regReplace(pattern: "jiu", replaceWith: "ㄐㄧㄡ")
                varLineData.regReplace(pattern: "jue", replaceWith: "ㄐㄩㄝ")
                varLineData.regReplace(pattern: "kai", replaceWith: "ㄎㄞ")
                varLineData.regReplace(pattern: "kan", replaceWith: "ㄎㄢ")
                varLineData.regReplace(pattern: "kao", replaceWith: "ㄎㄠ")
                varLineData.regReplace(pattern: "ken", replaceWith: "ㄎㄣ")
                varLineData.regReplace(pattern: "kiu", replaceWith: "ㄎㄧㄡ")
                varLineData.regReplace(pattern: "kou", replaceWith: "ㄎㄡ")
                varLineData.regReplace(pattern: "kua", replaceWith: "ㄎㄨㄚ")
                varLineData.regReplace(pattern: "kui", replaceWith: "ㄎㄨㄟ")
                varLineData.regReplace(pattern: "kun", replaceWith: "ㄎㄨㄣ")
                varLineData.regReplace(pattern: "kuo", replaceWith: "ㄎㄨㄛ")
                varLineData.regReplace(pattern: "lai", replaceWith: "ㄌㄞ")
                varLineData.regReplace(pattern: "lan", replaceWith: "ㄌㄢ")
                varLineData.regReplace(pattern: "lao", replaceWith: "ㄌㄠ")
                varLineData.regReplace(pattern: "lei", replaceWith: "ㄌㄟ")
                varLineData.regReplace(pattern: "lia", replaceWith: "ㄌㄧㄚ")
                varLineData.regReplace(pattern: "lie", replaceWith: "ㄌㄧㄝ")
                varLineData.regReplace(pattern: "lin", replaceWith: "ㄌㄧㄣ")
                varLineData.regReplace(pattern: "liu", replaceWith: "ㄌㄧㄡ")
                varLineData.regReplace(pattern: "lou", replaceWith: "ㄌㄡ")
                varLineData.regReplace(pattern: "lun", replaceWith: "ㄌㄨㄣ")
                varLineData.regReplace(pattern: "luo", replaceWith: "ㄌㄨㄛ")
                varLineData.regReplace(pattern: "lve", replaceWith: "ㄌㄩㄝ")
                varLineData.regReplace(pattern: "mai", replaceWith: "ㄇㄞ")
                varLineData.regReplace(pattern: "man", replaceWith: "ㄇㄢ")
                varLineData.regReplace(pattern: "mao", replaceWith: "ㄇㄠ")
                varLineData.regReplace(pattern: "mei", replaceWith: "ㄇㄟ")
                varLineData.regReplace(pattern: "men", replaceWith: "ㄇㄣ")
                varLineData.regReplace(pattern: "mie", replaceWith: "ㄇㄧㄝ")
                varLineData.regReplace(pattern: "min", replaceWith: "ㄇㄧㄣ")
                varLineData.regReplace(pattern: "miu", replaceWith: "ㄇㄧㄡ")
                varLineData.regReplace(pattern: "mou", replaceWith: "ㄇㄡ")
                varLineData.regReplace(pattern: "nai", replaceWith: "ㄋㄞ")
                varLineData.regReplace(pattern: "nan", replaceWith: "ㄋㄢ")
                varLineData.regReplace(pattern: "nao", replaceWith: "ㄋㄠ")
                varLineData.regReplace(pattern: "nei", replaceWith: "ㄋㄟ")
                varLineData.regReplace(pattern: "nen", replaceWith: "ㄋㄣ")
                varLineData.regReplace(pattern: "nie", replaceWith: "ㄋㄧㄝ")
                varLineData.regReplace(pattern: "nin", replaceWith: "ㄋㄧㄣ")
                varLineData.regReplace(pattern: "niu", replaceWith: "ㄋㄧㄡ")
                varLineData.regReplace(pattern: "nou", replaceWith: "ㄋㄡ")
                varLineData.regReplace(pattern: "nui", replaceWith: "ㄋㄨㄟ")
                varLineData.regReplace(pattern: "nun", replaceWith: "ㄋㄨㄣ")
                varLineData.regReplace(pattern: "nuo", replaceWith: "ㄋㄨㄛ")
                varLineData.regReplace(pattern: "nve", replaceWith: "ㄋㄩㄝ")
                varLineData.regReplace(pattern: "pai", replaceWith: "ㄆㄞ")
                varLineData.regReplace(pattern: "pan", replaceWith: "ㄆㄢ")
                varLineData.regReplace(pattern: "pao", replaceWith: "ㄆㄠ")
                varLineData.regReplace(pattern: "pei", replaceWith: "ㄆㄟ")
                varLineData.regReplace(pattern: "pen", replaceWith: "ㄆㄣ")
                varLineData.regReplace(pattern: "pia", replaceWith: "ㄆㄧㄚ")
                varLineData.regReplace(pattern: "pie", replaceWith: "ㄆㄧㄝ")
                varLineData.regReplace(pattern: "pin", replaceWith: "ㄆㄧㄣ")
                varLineData.regReplace(pattern: "pou", replaceWith: "ㄆㄡ")
                varLineData.regReplace(pattern: "qia", replaceWith: "ㄑㄧㄚ")
                varLineData.regReplace(pattern: "qie", replaceWith: "ㄑㄧㄝ")
                varLineData.regReplace(pattern: "qin", replaceWith: "ㄑㄧㄣ")
                varLineData.regReplace(pattern: "qiu", replaceWith: "ㄑㄧㄡ")
                varLineData.regReplace(pattern: "que", replaceWith: "ㄑㄩㄝ")
                varLineData.regReplace(pattern: "qun", replaceWith: "ㄑㄩㄣ")
                varLineData.regReplace(pattern: "ran", replaceWith: "ㄖㄢ")
                varLineData.regReplace(pattern: "rao", replaceWith: "ㄖㄠ")
                varLineData.regReplace(pattern: "ren", replaceWith: "ㄖㄣ")
                varLineData.regReplace(pattern: "rou", replaceWith: "ㄖㄡ")
                varLineData.regReplace(pattern: "rui", replaceWith: "ㄖㄨㄟ")
                varLineData.regReplace(pattern: "run", replaceWith: "ㄖㄨㄣ")
                varLineData.regReplace(pattern: "ruo", replaceWith: "ㄖㄨㄛ")
                varLineData.regReplace(pattern: "sai", replaceWith: "ㄙㄞ")
                varLineData.regReplace(pattern: "san", replaceWith: "ㄙㄢ")
                varLineData.regReplace(pattern: "sao", replaceWith: "ㄙㄠ")
                varLineData.regReplace(pattern: "sei", replaceWith: "ㄙㄟ")
                varLineData.regReplace(pattern: "sen", replaceWith: "ㄙㄣ")
                varLineData.regReplace(pattern: "sha", replaceWith: "ㄕㄚ")
                varLineData.regReplace(pattern: "she", replaceWith: "ㄕㄜ")
                varLineData.regReplace(pattern: "shi", replaceWith: "ㄕ")
                varLineData.regReplace(pattern: "shu", replaceWith: "ㄕㄨ")
                varLineData.regReplace(pattern: "sou", replaceWith: "ㄙㄡ")
                varLineData.regReplace(pattern: "sui", replaceWith: "ㄙㄨㄟ")
                varLineData.regReplace(pattern: "sun", replaceWith: "ㄙㄨㄣ")
                varLineData.regReplace(pattern: "suo", replaceWith: "ㄙㄨㄛ")
                varLineData.regReplace(pattern: "tai", replaceWith: "ㄊㄞ")
                varLineData.regReplace(pattern: "tan", replaceWith: "ㄊㄢ")
                varLineData.regReplace(pattern: "tao", replaceWith: "ㄊㄠ")
                varLineData.regReplace(pattern: "tie", replaceWith: "ㄊㄧㄝ")
                varLineData.regReplace(pattern: "tou", replaceWith: "ㄊㄡ")
                varLineData.regReplace(pattern: "tui", replaceWith: "ㄊㄨㄟ")
                varLineData.regReplace(pattern: "tun", replaceWith: "ㄊㄨㄣ")
                varLineData.regReplace(pattern: "tuo", replaceWith: "ㄊㄨㄛ")
                varLineData.regReplace(pattern: "wai", replaceWith: "ㄨㄞ")
                varLineData.regReplace(pattern: "wan", replaceWith: "ㄨㄢ")
                varLineData.regReplace(pattern: "wei", replaceWith: "ㄨㄟ")
                varLineData.regReplace(pattern: "wen", replaceWith: "ㄨㄣ")
                varLineData.regReplace(pattern: "xia", replaceWith: "ㄒㄧㄚ")
                varLineData.regReplace(pattern: "xie", replaceWith: "ㄒㄧㄝ")
                varLineData.regReplace(pattern: "xin", replaceWith: "ㄒㄧㄣ")
                varLineData.regReplace(pattern: "xiu", replaceWith: "ㄒㄧㄡ")
                varLineData.regReplace(pattern: "xue", replaceWith: "ㄒㄩㄝ")
                varLineData.regReplace(pattern: "xun", replaceWith: "ㄒㄩㄣ")
                varLineData.regReplace(pattern: "yai", replaceWith: "ㄧㄞ")
                varLineData.regReplace(pattern: "yan", replaceWith: "ㄧㄢ")
                varLineData.regReplace(pattern: "yao", replaceWith: "ㄧㄠ")
                varLineData.regReplace(pattern: "yin", replaceWith: "ㄧㄣ")
                varLineData.regReplace(pattern: "you", replaceWith: "ㄧㄡ")
                varLineData.regReplace(pattern: "yue", replaceWith: "ㄩㄝ")
                varLineData.regReplace(pattern: "yun", replaceWith: "ㄩㄣ")
                varLineData.regReplace(pattern: "zai", replaceWith: "ㄗㄞ")
                varLineData.regReplace(pattern: "zan", replaceWith: "ㄗㄢ")
                varLineData.regReplace(pattern: "zao", replaceWith: "ㄗㄠ")
                varLineData.regReplace(pattern: "zei", replaceWith: "ㄗㄟ")
                varLineData.regReplace(pattern: "zen", replaceWith: "ㄗㄣ")
                varLineData.regReplace(pattern: "zha", replaceWith: "ㄓㄚ")
                varLineData.regReplace(pattern: "zhe", replaceWith: "ㄓㄜ")
                varLineData.regReplace(pattern: "zhi", replaceWith: "ㄓ")
                varLineData.regReplace(pattern: "zhu", replaceWith: "ㄓㄨ")
                varLineData.regReplace(pattern: "zou", replaceWith: "ㄗㄡ")
                varLineData.regReplace(pattern: "zui", replaceWith: "ㄗㄨㄟ")
                varLineData.regReplace(pattern: "zun", replaceWith: "ㄗㄨㄣ")
                varLineData.regReplace(pattern: "zuo", replaceWith: "ㄗㄨㄛ")
                varLineData.regReplace(pattern: "ai", replaceWith: "ㄞ")
                varLineData.regReplace(pattern: "an", replaceWith: "ㄢ")
                varLineData.regReplace(pattern: "ao", replaceWith: "ㄠ")
                varLineData.regReplace(pattern: "ba", replaceWith: "ㄅㄚ")
                varLineData.regReplace(pattern: "bi", replaceWith: "ㄅㄧ")
                varLineData.regReplace(pattern: "bo", replaceWith: "ㄅㄛ")
                varLineData.regReplace(pattern: "bu", replaceWith: "ㄅㄨ")
                varLineData.regReplace(pattern: "ca", replaceWith: "ㄘㄚ")
                varLineData.regReplace(pattern: "ce", replaceWith: "ㄘㄜ")
                varLineData.regReplace(pattern: "ci", replaceWith: "ㄘ")
                varLineData.regReplace(pattern: "cu", replaceWith: "ㄘㄨ")
                varLineData.regReplace(pattern: "da", replaceWith: "ㄉㄚ")
                varLineData.regReplace(pattern: "de", replaceWith: "ㄉㄜ")
                varLineData.regReplace(pattern: "di", replaceWith: "ㄉㄧ")
                varLineData.regReplace(pattern: "du", replaceWith: "ㄉㄨ")
                varLineData.regReplace(pattern: "eh", replaceWith: "ㄝ")
                varLineData.regReplace(pattern: "ei", replaceWith: "ㄟ")
                varLineData.regReplace(pattern: "en", replaceWith: "ㄣ")
                varLineData.regReplace(pattern: "er", replaceWith: "ㄦ")
                varLineData.regReplace(pattern: "fa", replaceWith: "ㄈㄚ")
                varLineData.regReplace(pattern: "fo", replaceWith: "ㄈㄛ")
                varLineData.regReplace(pattern: "fu", replaceWith: "ㄈㄨ")
                varLineData.regReplace(pattern: "ga", replaceWith: "ㄍㄚ")
                varLineData.regReplace(pattern: "ge", replaceWith: "ㄍㄜ")
                varLineData.regReplace(pattern: "gi", replaceWith: "ㄍㄧ")
                varLineData.regReplace(pattern: "gu", replaceWith: "ㄍㄨ")
                varLineData.regReplace(pattern: "ha", replaceWith: "ㄏㄚ")
                varLineData.regReplace(pattern: "he", replaceWith: "ㄏㄜ")
                varLineData.regReplace(pattern: "hu", replaceWith: "ㄏㄨ")
                varLineData.regReplace(pattern: "ji", replaceWith: "ㄐㄧ")
                varLineData.regReplace(pattern: "ju", replaceWith: "ㄐㄩ")
                varLineData.regReplace(pattern: "ka", replaceWith: "ㄎㄚ")
                varLineData.regReplace(pattern: "ke", replaceWith: "ㄎㄜ")
                varLineData.regReplace(pattern: "ku", replaceWith: "ㄎㄨ")
                varLineData.regReplace(pattern: "la", replaceWith: "ㄌㄚ")
                varLineData.regReplace(pattern: "le", replaceWith: "ㄌㄜ")
                varLineData.regReplace(pattern: "li", replaceWith: "ㄌㄧ")
                varLineData.regReplace(pattern: "lo", replaceWith: "ㄌㄛ")
                varLineData.regReplace(pattern: "lu", replaceWith: "ㄌㄨ")
                varLineData.regReplace(pattern: "lv", replaceWith: "ㄌㄩ")
                varLineData.regReplace(pattern: "ma", replaceWith: "ㄇㄚ")
                varLineData.regReplace(pattern: "me", replaceWith: "ㄇㄜ")
                varLineData.regReplace(pattern: "mi", replaceWith: "ㄇㄧ")
                varLineData.regReplace(pattern: "mo", replaceWith: "ㄇㄛ")
                varLineData.regReplace(pattern: "mu", replaceWith: "ㄇㄨ")
                varLineData.regReplace(pattern: "na", replaceWith: "ㄋㄚ")
                varLineData.regReplace(pattern: "ne", replaceWith: "ㄋㄜ")
                varLineData.regReplace(pattern: "ni", replaceWith: "ㄋㄧ")
                varLineData.regReplace(pattern: "nu", replaceWith: "ㄋㄨ")
                varLineData.regReplace(pattern: "nv", replaceWith: "ㄋㄩ")
                varLineData.regReplace(pattern: "ou", replaceWith: "ㄡ")
                varLineData.regReplace(pattern: "pa", replaceWith: "ㄆㄚ")
                varLineData.regReplace(pattern: "pi", replaceWith: "ㄆㄧ")
                varLineData.regReplace(pattern: "po", replaceWith: "ㄆㄛ")
                varLineData.regReplace(pattern: "pu", replaceWith: "ㄆㄨ")
                varLineData.regReplace(pattern: "qi", replaceWith: "ㄑㄧ")
                varLineData.regReplace(pattern: "qu", replaceWith: "ㄑㄩ")
                varLineData.regReplace(pattern: "re", replaceWith: "ㄖㄜ")
                varLineData.regReplace(pattern: "ri", replaceWith: "ㄖ")
                varLineData.regReplace(pattern: "ru", replaceWith: "ㄖㄨ")
                varLineData.regReplace(pattern: "sa", replaceWith: "ㄙㄚ")
                varLineData.regReplace(pattern: "se", replaceWith: "ㄙㄜ")
                varLineData.regReplace(pattern: "si", replaceWith: "ㄙ")
                varLineData.regReplace(pattern: "su", replaceWith: "ㄙㄨ")
                varLineData.regReplace(pattern: "ta", replaceWith: "ㄊㄚ")
                varLineData.regReplace(pattern: "te", replaceWith: "ㄊㄜ")
                varLineData.regReplace(pattern: "ti", replaceWith: "ㄊㄧ")
                varLineData.regReplace(pattern: "tu", replaceWith: "ㄊㄨ")
                varLineData.regReplace(pattern: "wa", replaceWith: "ㄨㄚ")
                varLineData.regReplace(pattern: "wo", replaceWith: "ㄨㄛ")
                varLineData.regReplace(pattern: "wu", replaceWith: "ㄨ")
                varLineData.regReplace(pattern: "xi", replaceWith: "ㄒㄧ")
                varLineData.regReplace(pattern: "xu", replaceWith: "ㄒㄩ")
                varLineData.regReplace(pattern: "ya", replaceWith: "ㄧㄚ")
                varLineData.regReplace(pattern: "ye", replaceWith: "ㄧㄝ")
                varLineData.regReplace(pattern: "yi", replaceWith: "ㄧ")
                varLineData.regReplace(pattern: "yo", replaceWith: "ㄧㄛ")
                varLineData.regReplace(pattern: "yu", replaceWith: "ㄩ")
                varLineData.regReplace(pattern: "za", replaceWith: "ㄗㄚ")
                varLineData.regReplace(pattern: "ze", replaceWith: "ㄗㄜ")
                varLineData.regReplace(pattern: "zi", replaceWith: "ㄗ")
                varLineData.regReplace(pattern: "zu", replaceWith: "ㄗㄨ")
                varLineData.regReplace(pattern: "a", replaceWith: "ㄚ")
                varLineData.regReplace(pattern: "e", replaceWith: "ㄜ")
                varLineData.regReplace(pattern: "o", replaceWith: "ㄛ")
                varLineData.regReplace(pattern: "q", replaceWith: "ㄑ")
                varLineData.regReplace(pattern: "2", replaceWith: "ˊ")
                varLineData.regReplace(pattern: "3", replaceWith: "ˇ")
                varLineData.regReplace(pattern: "4", replaceWith: "ˋ")
                varLineData.regReplace(pattern: "5", replaceWith: "˙")
                varLineData.regReplace(pattern: "1", replaceWith: "")
                strProcessed += varLineData
                strProcessed += "\n"
            }
        }
        
        // Step 3: Add Formatted Pragma
        let hdrFormatted = "# 𝙵𝙾𝚁𝙼𝙰𝚃 𝚘𝚛𝚐.𝚊𝚝𝚎𝚕𝚒𝚎𝚛𝙸𝚗𝚖𝚞.𝚟𝚌𝚑𝚎𝚠𝚒𝚗𝚐.𝚞𝚜𝚎𝚛𝙻𝚊𝚗𝚐𝚞𝚊𝚐𝚎𝙼𝚘𝚍𝚎𝚕𝙳𝚊𝚝𝚊.𝚏𝚘𝚛𝚖𝚊𝚝𝚝𝚎𝚍\n" // Sorted Header
        strProcessed = hdrFormatted + strProcessed // Add Sorted Header
        
        // Step 4: Deduplication.
        arrData = strProcessed.components(separatedBy: "\n")
        strProcessed = "" // Reset its value
        // 下面兩行的 reversed 是首尾顛倒，免得破壞最新的 override 資訊。
        let arrDataDeduplicated = Array(NSOrderedSet(array: arrData.reversed()).array as! [String])
        for lineData in arrDataDeduplicated.reversed() {
            strProcessed += lineData
            strProcessed += "\n"
        }
        
        // Step 5: Remove duplicated newlines at the end of the file.
        strProcessed.regReplace(pattern: "\\n+", replaceWith: "\n")
        
        // Step 6: Commit Formatted Contents.
        self = strProcessed
    }
}
