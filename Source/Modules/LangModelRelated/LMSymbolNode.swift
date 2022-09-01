// (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

class SymbolNode {
  var title: String
  var children: [SymbolNode]?
  var previous: SymbolNode?

  init(_ title: String, _ children: [SymbolNode]? = nil) {
    self.title = title
    self.children = children
  }

  init(_ title: String, symbols: String) {
    self.title = title
    children = Array(symbols).map { SymbolNode(String($0), nil) }
  }

  init(_ title: String, symbols: [String]) {
    self.title = title
    children = symbols.map { SymbolNode($0, nil) }
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
      root = arrChildren.isEmpty ? defaultSymbolRoot : .init("/", arrChildren)
    } catch {
      root = defaultSymbolRoot
    }
  }

  // MARK: - Static data.

  static let catCommonSymbols = NSLocalizedString("catCommonSymbols", comment: "")
  static let catHoriBrackets = NSLocalizedString("catHoriBrackets", comment: "")
  static let catVertBrackets = NSLocalizedString("catVertBrackets", comment: "")
  static let catAlphabets = NSLocalizedString("catAlphabets", comment: "")
  static let catSpecialNumbers = NSLocalizedString("catSpecialNumbers", comment: "")
  static let catMathSymbols = NSLocalizedString("catMathSymbols", comment: "")
  static let catCurrencyUnits = NSLocalizedString("catCurrencyUnits", comment: "")
  static let catSpecialSymbols = NSLocalizedString("catSpecialSymbols", comment: "")
  static let catUnicodeSymbols = NSLocalizedString("catUnicodeSymbols", comment: "")
  static let catCircledKanjis = NSLocalizedString("catCircledKanjis", comment: "")
  static let catCircledKataKana = NSLocalizedString("catCircledKataKana", comment: "")
  static let catBracketKanjis = NSLocalizedString("catBracketKanjis", comment: "")
  static let catSingleTableLines = NSLocalizedString("catSingleTableLines", comment: "")
  static let catDoubleTableLines = NSLocalizedString("catDoubleTableLines", comment: "")
  static let catFillingBlocks = NSLocalizedString("catFillingBlocks", comment: "")
  static let catLineSegments = NSLocalizedString("catLineSegments", comment: "")
  static let catKana = NSLocalizedString("catKana", comment: "")
  static let catCombinations = NSLocalizedString("catCombinations", comment: "")
  static let catPhonabets = NSLocalizedString("catPhonabets", comment: "")
  static let catCircledASCII = NSLocalizedString("catCircledASCII", comment: "")
  static let catBracketedASCII = NSLocalizedString("catBracketedASCII", comment: "")
  static let catMusicSymbols = NSLocalizedString("catMusicSymbols", comment: "")
  static let catThai = NSLocalizedString("catThai", comment: "")
  static let catYi = NSLocalizedString("catYi", comment: "")

  private(set) static var root: SymbolNode = .init("/")

  private static let defaultSymbolRoot: SymbolNode = .init(
    "/",
    [
      SymbolNode("　"),
      SymbolNode("｀"),
      SymbolNode(catCommonSymbols, symbols: "，、。．？！；：‧‥﹐﹒˙·‘’“”〝〞‵′〃～＄％﹪＠＆＃＊・…—〜／＼＿―‖﹫﹟﹠﹡"),
      SymbolNode(
        catHoriBrackets,
        symbols:
          "（）［］｛｝〈〉《》「」『』【】〔〕〖〗〘〙〚〛︗︘︷︸︹︺︻︼︽︾︿﹀﹁﹂﹃﹄﹇﹈︵︶[]{}⁅⁆⎡⎢⎣⎤⎥⎦⎧⎨⎩⎪⎫⎬⎭⎰⎱｢｣❬❭❰❱❲❳❴❵⟦⟧⟨⟩⟪⟫⟬⟭⦃⦄⦇⦈⦉⦊⦋⦌⦍⦎⦏⦐⦑⦒⦓⦔⦕⦖⦗⦘⧼⧽⸂⸃⸄⸅⸉⸊⸌⸍⸜⸝⸢⸣⸤⸥⸦⸧⎴⎵⎶⏞⏟⏠⏡﹙﹚﹛﹜﹝﹞﹤﹥‘’“”〝〞‵′″＇"
      ),
      SymbolNode(catVertBrackets, symbols: "︵︶﹁﹂︹︺︷︸︿﹀﹃﹄︽︾︻︼"),
      SymbolNode(
        catAlphabets,
        symbols:
          "αβγδεζηθικλμνξοπρστυφχψωΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩабвгдежзийклмнопрстуфхцчшщъыьэюяёАБВГДЕЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯЁàáèéêìíòóùúüāēěīńňōūǎǐǒǔǖǘǚǜɑɡ¨·"
      ),
      SymbolNode(
        catSpecialNumbers, symbols: "ⅠⅡⅢⅣⅤⅥⅦⅧⅨⅩⅪⅫⅰⅱⅲⅳⅴⅵⅶⅷⅸⅹⅺⅻ〇〡〢〣〤〥〦〧〨〩"
      ),
      SymbolNode(
        catMathSymbols,
        symbols:
          "﹢﹤﹥＋－＜＝＞✕%+<=>¡¢«°±µ»¼½¾¿×÷ˇθπ‰₠₡₢₣₤₥₦₧₨₩₪₫€℀℁℃℅℆℉⅓⅔⅕⅖⅗⅘⅙⅚⅛⅜⅝⅞⅟∀∁∂∃∄∅∆∇∈∉∊∋∌∍∎∏∐∑−∓∔∕∖∗∘∙√∛∜∝∞∟∠∡∢∣∤∥∧∨∩∪∫∬∭∮∯∰∱∲∳∴∵∶∷∸∹∺∻∼∽∾∿≀≁≂≃≄≅≆≇≈≉≊≋≌≍≎≏≐≑≒≓≔≕≖≗≘≙≚≛≜≝≞≟≠≡≢≣≤≥≦≧≨≩≪≫≬≭≮≯≰≱≲≳≴≵≶≷≸≹≺≻≼≽≾≿⊀⊁⊂⊃⊄⊅⊆⊇⊈⊉⊊⊋⊌⊍⊎⊏⊐⊑⊒⊓⊔⊕⊖⊗⊘⊙⊚⊛⊜⊝⊞⊟⊠⊡⊢⊣⊤⊥⊦⊧⊨⊩⊪⊫⊬⊭⊮⊯⊰⊱⊲⊳⊴⊵⊶⊷⊸⊹⊺⊻⊼⊽⊾⊿⋀⋁⋂⋃⋄⋅⋆⋇⋈⋉⋊⋋⋌⋍⋎⋏⋐⋑⋒⋓⋔⋕⋖⋗⋘⋙⋚⋛⋜⋝⋞⋟⋠⋡⋢⋣⋤⋥⋦⋧⋨⋩⋪⋫⋬⋭⋮⋯⋰⋱"
      ),
      SymbolNode(catCurrencyUnits, symbols: "$€¥¢£₽₨₩฿₺₮₱₭₴₦৲৳૱௹﷼₹₲₪₡₫៛₵₢₸₤₳₥₠₣₰₧₯₶₷¤￠￥￡＄﹩￦"),
      SymbolNode(
        catSpecialSymbols,
        symbols:
          "↩⌘⎋⏏⇥⇤⇪⇧⌤⌥⎇␣⌃⌄⌅⌆⌦⌫⌧⇱↖↸⇲↘⇞⇟↑↓←→⇡⇣⇠⇢⚙⇭⌽⌀⌁⌂⌐⌑⌒⌓⌔⌕⌖⌗⌙⌨⎄⎅⎆⎈⎉⎊⎌⌚⌛⎗⎘⎙⎚⎀⎁⎂⎃⌇⌈⌉⌊⌋⌌⌍⌏⌠⎮⌡⌢⌣⌜⌝⌞⌟⁒〈〉⌬⌭⌮⌯⌰⌱⌲⌳↗↙↺⇩⇦⇨⇄⇆⇅⇵↻◎○●⊕⊙※△▲☆★◇◆□■▽▼№℡§〒♀♂↯¶©®™🜀🜁🜂🜃🜄🜅🜆🜇🜈🜉🜊🜋🜌🜍🜎🜏🜐🜑🜒🜓🜔🜕🜖🜗🜘🜙🜚🜛🜜🜝🜞🜟🜠🜡🜢🜣🜤🜥🜦🜧🜨🜩🜪🜫🜬🜭🜮🜯🜰🜱🜲🜳🜴🜵🜶🜷🜸🜹🜺🜻🜼🜽🜾🜿🝀🝁🝂🝃🝄🝅🝆🝇🝈🝉🝊🝋🝌🝍🝎🝏🝐🝑🝒🝓🝔🝕🝖🝗🝘🝙🝚🝛🝜🝝🝞🝟🝠🝡🝢🝣🝤🝥🝦🝧🝨🝩🝪🝫🝬🝭🝮🝯🝰🝱🝲🝳↚↛↜↝↞↟↠↡↢↣↤↥↦↧↨↪↫↬↭↮"
      ),
      SymbolNode(
        catUnicodeSymbols,
        symbols:
          "※∮∴∵∽☀☁☂☃☺☻♠♣♥♦♨♩♪♫♬♭♯■□▢▣▤▥▦▧▨▩▪▫▬▭▮▯▰▱▲△▴▵▶▷▸▹►▻▼▽▾▿◀◁◂◃◄◅◆◇◈◉◊○◌◍◎●◐◑◒◓◔◕◖◗◘◙◚◛◜◝◞◟◠◡◢◣◤◥◦◧◨◩◪◫◬◭◮◯◰◱◲◳◴◵◶◷◸◹◺◻◼◽◾◿☄★☆☇☈☉☊☋☌☍☎☏☐☑☒☓☔☕☖☗☘☙☚☛☜☝☞☟☠☡☢☣☤☥☦☧☨☩☪☫☬☭☮☯☰☱☲☳☴☵☶☷☸☹☼☽☾☿♀♁♂♃♄♅♆♇♈♉♊♋♌♍♎♏♐♑♒♓♔♕♖♗♘♙♚♛♜♝♞♟♡♢♤♧♮♰♱♲♳♴♵♶♷♸♹♺♻♼♽♾♿⚀⚁⚂⚃⚄⚅⚆⚇⚈⚉⚊⚋⚌⚍⚎⚏⚐⚑⚒⚓⚔⚕⚖⚗⚘⚙⚚⚛⚜⚝⚞⚟⚠⚡⚢⚣⚤⚥⚦⚧⚨⚩⚪⚫⚬⚭⚮⚯⚰⚱⚲⚳⚴⚵⚶⚷⚸⚹⚺⚻⚼⚽⚾⚿⛀⛁⛂⛃⛄⛅⛆⛇⛈⛉⛊⛋⛌⛍⛎⛏⛐⛑⛒⛓⛔⛕⛖⛗⛘⛙⛚⛛⛜⛝⛞⛟⛠⛡⛢⛣⛤⛥⛦⛧⛨⛩⛪⛫⛬⛭⛮⛯⛰⛱⛲⛳⛴⛵⛶⛷⛸⛹⛺⛻⛼⛽⛾⛿✁✂✃✄✅✆✇✈✉✊✋✌✍✎✏✐✑✒✓✔✕✖✗✘✙✚✛✜✝✞✟✠✡✢✣✤✥✦✧✨✩✪✫✬✭✮✯✰✱✲✳✴✵✶✷✸✹✺✻✼✽✾✿❀❁❂❃❄❅❆❇❈❉❊❋❌❍❎❏❐❑❒❓❔❕❖❗❘❙❚❛❜❝❞❟❠❡❢❣❤❥❦❧❨❩❪❫❬❭❮❯❰❱❲❳❴❵➔➕➖➗➘➙➚➛➜➝➞➟➠➡➢➣➤➥➦➧➨➩➪➫➬➭➮➯➰➱➲➳➴➵➶➷➸➹➺➻➼➽➾➿⬀⬁⬂⬃⬄⬅⬆⬇⬈⬉⬊⬋⬌⬍⬎⬏⬐⬑⬒⬓⬔⬕⬖⬗⬘⬙⬚⬛⬜⬝⬞⬟⬠⬡⬢⬣⬤⬥⬦⬧⬨⬩⬪⬫⬬⬭⬮⬯⬰⬱⬲⬳⬴⬵⬶⬷⬸⬹⬺⬻⬼⬽⬾⬿⭀⭁⭂⭃⭄⭅⭆⭇⭈⭉⭊⭋⭌⭐⭑⭒⭓⭔⭕⭖⭗⭘⭙₮〠〶ↀↁↂ₭〇〄㉿〆₯ℂ℄"
      ),
      SymbolNode(
        catMusicSymbols,
        symbols:
          "𝄀𝄁𝄂𝄃𝄄𝄅𝄆𝄇𝄈𝄉𝄊𝄋𝄌𝄍𝄎𝄏𝄐𝄑𝄒𝄓𝄔𝄕𝄖𝄗𝄘𝄙𝄚𝄛𝄜𝄝𝄞𝄟𝄠𝄡𝄢𝄣𝄤𝄥𝄦𝄩𝄪𝄫𝄬𝄭𝄮𝄯𝄰𝄱𝄲𝄳𝄴𝄵𝄶𝄷𝄸𝄹𝄺𝄻𝄼𝄽𝄾𝄿𝅀𝅁𝅂𝅃𝅄𝅅𝅆𝅇𝅈𝅉𝅊𝅋𝅌𝅍𝅎𝅏𝅐𝅑𝅒𝅓𝅔𝅕𝅖𝅗𝅗𝅥𝅘𝅘𝅥𝅘𝅥𝅮𝅘𝅥𝅯𝅘𝅥𝅰𝅘𝅥𝅱𝅘𝅧𝅨𝅩𝅥𝅲𝅥𝅦𝅙𝅚𝅛𝅜𝅝𝅪𝅫𝅬𝅮𝅯𝅰𝅱𝅲𝅭𝅳𝅴𝅵𝅶𝅷𝅸𝅹𝅺𝅻𝅼𝅽𝅾𝅿𝆀𝆁𝆂𝆃𝆄𝆊𝆋𝆅𝆆𝆇𝆈𝆉𝆌𝆍𝆎𝆏𝆐𝆑𝆒𝆓𝆔𝆕𝆖𝆗𝆘𝆙𝆚𝆛𝆜𝆝𝆞𝆟𝆠𝆡𝆢𝆣𝆤𝆥𝆦𝆧𝆨𝆩𝆪𝆫𝆬𝆭𝆮𝆯𝆰𝆱𝆲𝆳𝆴𝆵𝆶𝆷𝆸𝆹𝆹𝅥𝆹𝅥𝅮𝆹𝅥𝅯𝆺𝆺𝅥𝆺𝅥𝅮𝆺𝅥𝅯𝇁𝇂𝇃𝇄𝇅𝇆𝇇𝇈𝇉𝇊𝇋𝇌𝇍𝇎𝇏𝇐𝇑𝇒𝇓𝇔𝇕𝇖𝇗𝇘𝇙𝇚𝇛𝇜𝇝𝇞𝇟𝇠𝇡𝇢𝇣𝇤𝇥𝇦𝇧𝇨"
      ),
      SymbolNode(catCircledKanjis, symbols: "㊊㊋㊌㊍㊎㊏㊐㊑㊒㊓㊔㊕㊖㊗︎㊘㊙︎㊚㊛㊜㊝㊞㊟㊠㊡㊢㊣㊤㊥㊦㊧㊨㊩㊪㊫㊬㊭㊮㊯㊰㊀㊁㊂㊃㊄㊅㊆㊇㊈㊉🈚︎🈯︎"),
      SymbolNode(
        catCircledKataKana, symbols: "㋐㋑㋒㋓㋔㋕㋖㋗㋘㋙㋚㋛㋜㋝㋞㋟㋠㋡㋢㋣㋤㋥㋦㋧㋨㋩㋪㋫㋬㋭㋮㋯㋰㋱㋲㋳㋴㋵㋶㋷㋸㋹㋺㋻㋼㋽㋾"
      ),
      SymbolNode(catBracketKanjis, symbols: "㈪㈫㈬㈭㈮㈯㈰㈱㈲㈳㈴㈵㈶㈷㈸㈹㈺㈻㈼㈽㈾㈿㉀㉁㉂㉃"),
      SymbolNode(catSingleTableLines, symbols: "─│┌┐└┕┘├┤┬┴┼═╞╡╪╭╮╯╰▕"),
      SymbolNode(catDoubleTableLines, symbols: "═║╒╓╔╕╖╗╘╙╚╛╜╝╞╟╠╡╢╣╤╥╦╧╨╩╪╫╬"),
      SymbolNode(catFillingBlocks, symbols: "＿ˍ▁▂▃▄▅▆▇█▏▎▍▌▋▊▉◢◣◥◤"),
      SymbolNode(catLineSegments, symbols: "﹣﹦≡｜∣∥–︱—︳╴¯￣﹉﹊﹍﹎﹋﹌﹏︴∕﹨╱╲／＼ˍ━┃▕〓╳∏ˆ⌒┄┅┆┇┈┉┊┋"),
      SymbolNode(
        catKana,
        symbols:
          "ぁあぃいぅうゔぇえぉおかがきぎくぐけげこごさざしじすずせぜそぞただちぢっつづてでとどなにぬねのはばひびふぶへべほぼまみむめもゃやゅゆょよらら゚りり゚るる゚れれ゚ろろ゚ゎわわ゙ゐゐ゙ゑゑ゙をを゙んゕゖゝゞゟ〻゠ァアィイゥウヴェエォオカガキギクグケゲコゴサザシジスズセゼソゾタダチヂッツヅテデトドナニヌネノハバパヒビピフブプヘベペホボポマミムメモャヤュユョヨララ゚リリ゚ルル゚レレ゚ロロ゚ヮワヷヰヸヱヹヲヺンヵヶ・ーヽヾヿ々ㇰㇱㇲㇳㇴㇵㇶㇷㇸㇹㇺㇻㇼㇽㇾㇿ･ｦｧｨｩｪｫｬｭｮｯｰｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ ﾞ ﾟ〲〱〳〴〵"
      ),
      SymbolNode(
        catCombinations,
        symbols:
          "㍘㍙㍚㍛㍜㍝㍞㍟㍠㍡㍢㍣㍤㍥㍦㍧㍨㍩㍪㍫㍬㍭㍮㍯㍰㏠㏡㏢㏣㏤㏥㏦㏧㏨㏩㏪㏫㏬㏭㏮㏯㏰㏱㏲㏳㏴㏵㏶㏷㏸㏹㏺㏻㏼㏽㏾㍱㍲㍳㍴㍵㍶㍷㍸㍹㍺㎀㎁㎂㎃㎄㎅㎆㎇㎈㎉㎊㎋㎌㎍㎎㎏㎐㎑㎒㎓㎔㎕㎖㎗㎘㎙㎚㎛㎜㎝㎞㎟㎠㎡㎢㎣㎤㎥㎦㎧㎨㎩㎪㎫㎬㎭㎮㎯㎰㎱㎲㎳㎴㎵㎶㎷㎸㎹㎺㎻㎼㎽㎾㎿㏀㏁㏂㏃㏄㏅㏆㏇㏈㏉㏊㏋㏌㏍㏎㏏㏐㏑㏒㏓㏔㏕㏖㏗㏘㏙㏚㏛㏜㏝㏞㏟㏿㋿㍼㍽㍾㍻㍿㌀㌁㌂㌃㌄㌅㌆㌇㌈㌉㌊㌋㌌㌍㌎㌏㌐㌑㌒㌓㌔㌕㌖㌗㌘㌙㌚㌛㌜㌝㌞㌟㌠㌡㌢㌣㌤㌥㌦㌧㌨㌩㌪㌫㌬㌭㌮㌯㌰㌱㌲㌳㌴㌵㌶㌷㌸㌹㌺㌻㌼㌽㌾㌿㍀㍁㍂㍃㍄㍅㍆㍇㍈㍉㍊㍋㍌㍍㍎㍏㍐㍑㍒㍓㍔㍕㍖㍗"
      ),
      SymbolNode(
        catPhonabets, symbols: "ㄅㄆㄇㄈㄉㄊㄋㄌㄍㄎㄏㄐㄑㄒㄓㄔㄕㄖㄗㄘㄙㄚㄛㄜㄝㄞㄟㄠㄡㄢㄣㄤㄥㄦㄧㄨㄩㄪㄫㄬㄭㄮㄯㆵㆠㆡㆢㆣㆤㆥㆦㆧㆨㆩㆪㆫㆬㆭㆮㆯㆰㆱㆲㆳㆴㆶㆷㆸㆹㆺㆻㆼㆽㆾㆿ˙ˊˇˋ˪˫"
      ),
      SymbolNode(
        catCircledASCII,
        symbols:
          "①②③④⑤⑥⑦⑧⑨⑩⑪⑫⑬⑭⑮⑯⑰⑱⑲⑳ⒶⒷⒸⒹⒺⒻⒼⒽⒾⒿⓀⓁⓂⓂ︎ⓃⓄⓅⓆⓇⓈⓉⓊⓋⓌⓍⓎⓏⓐⓑⓒⓓⓔⓕⓖⓗⓘⓙⓚⓛⓜⓝⓞⓟⓠⓡⓢⓣⓤⓥⓦⓧⓨⓩ⓪⓫⓬⓭⓮⓯⓰⓱⓲⓳⓴⓵⓶⓷⓸⓹⓺⓻⓼⓽⓾⓿❶❷❸❹❺❻❼❽❾❿➀➁➂➃➄➅➆➇➈➉➊➋➌➍➎➏➐➑➒➓🄰🄱🄲🄳🄴🄵🄶🄷🄸🄹🄺🄻🄼🄽🄾🄿🅀🅁🅂🅃🅄🅅🅆🅇🅈🅉🅐🅑🅒🅓🅔🅕🅖🅗🅘🅙🅚🅛🅜🅝🅞🅟🅠🅡🅢🅣🅤🅥🅦🅧🅨🅩🅰🅱🅲🅳🅴🅵🅶🅷🅸🅹🅺🅻🅼🅽🅾🅿︎🆀🆁🆂🆃🆄🆅🆆🆇🆈🆉"
      ),
      SymbolNode(
        catBracketedASCII, symbols: "⑴⑵⑶⑷⑸⑹⑺⑻⑼⑽⑾⑿⒀⒁⒂⒃⒄⒅⒆⒇⒜⒝⒞⒟⒠⒡⒢⒣⒤⒥⒦⒧⒨⒩⒪⒫⒬⒭⒮⒯⒰⒱⒲⒳⒴⒵🄐🄑🄒🄓🄔🄕🄖🄗🄘🄙🄚🄛🄜🄝🄞🄟🄠🄡🄢🄣🄤🄥🄦🄧🄨🄩"
      ),
      SymbolNode(
        catThai,
        symbols: [
          "ก", "ข", "ฃ", "ค", "ฅ", "ฆ", "ง", "จ", "ฉ", "ช", "ซ", "ฌ", "ญ", "ฎ", "ฏ", "ฐ", "ฑ", "ฒ", "ณ", "ด", "ต", "ถ",
          "ท", "ธ", "น", "บ", "ป", "ผ", "ฝ", "พ", "ฟ", "ภ", "ม", "ย", "ร", "ฤ", "ล", "ฦ", "ว", "ศ", "ษ", "ส", "ห", "ฬ",
          "อ", "ฮ", "ฯ", "ะ", "ั", "า", "ำ", "ิ", "ี", "ึ", "ื", "ุ", "ู", "ฺ", "เ", "แ", "โ", "ใ", "ไ", "ๅ", "ๆ",
          "็", "่", "้", "๊", "๋", "์", "ํ", "๎", "๏", "๐", "๑", "๒", "๓", "๔", "๕", "๖", "๗", "๘", "๙", "๚", "๛",
        ]
      ),
      SymbolNode(
        catYi,
        symbols:
          "ꀀꀁꀂꀃꀄꀅꀆꀇꀈꀉꀊꀋꀌꀍꀎꀏꀐꀑꀒꀓꀔꀕꀖꀗꀘꀙꀚꀛꀜꀝꀞꀟꀠꀡꀢꀣꀤꀥꀦꀧꀨꀩꀪꀫꀬꀭꀮꀯꀰꀱꀲꀳꀴꀵꀶꀷꀸꀹꀺꀻꀼꀽꀾꀿꁀꁁꁂꁃꁄꁅꁆꁇꁈꁉꁊꁋꁌꁍꁎꁏꁐꁑꁒꁓꁔꁕꁖꁗꁘꁙꁚꁛꁜꁝꁞꁟꁠꁡꁢꁣꁤꁥꁦꁧꁨꁩꁪꁫꁬꁭꁮꁯꁰꁱꁲꁳꁴꁵꁶꁷꁸꁹꁺꁻꁼꁽꁾꁿꂀꂁꂂꂃꂄꂅꂆꂇꂈꂉꂊꂋꂌꂍꂎꂏꂐꂑꂒꂓꂔꂕꂖꂗꂘꂙꂚꂛꂜꂝꂞꂟꂠꂡꂢꂣꂤꂥꂦꂧꂨꂩꂪꂫꂬꂭꂮꂯꂰꂱꂲꂳꂴꂵꂶꂷꂸꂹꂺꂻꂼꂽꂾꂿꃀꃁꃂꃃꃄꃅꃆꃇꃈꃉꃊꃋꃌꃍꃎꃏꃐꃑꃒꃓꃔꃕꃖꃗꃘꃙꃚꃛꃜꃝꃞꃟꃠꃡꃢꃣꃤꃥꃦꃧꃨꃩꃪꃫꃬꃭꃮꃯꃰꃱꃲꃳꃴꃵꃶꃷꃸꃹꃺꃻꃼꃽꃾꃿꄀꄁꄂꄃꄄꄅꄆꄇꄈꄉꄊꄋꄌꄍꄎꄏꄐꄑꄒꄓꄔꄕꄖꄗꄘꄙꄚꄛꄜꄝꄞꄟꄠꄡꄢꄣꄤꄥꄦꄧꄨꄩꄪꄫꄬꄭꄮꄯꄰꄱꄲꄳꄴꄵꄶꄷꄸꄹꄺꄻꄼꄽꄾꄿꅀꅁꅂꅃꅄꅅꅆꅇꅈꅉꅊꅋꅌꅍꅎꅏꅐꅑꅒꅓꅔꅕꅖꅗꅘꅙꅚꅛꅜꅝꅞꅟꅠꅡꅢꅣꅤꅥꅦꅧꅨꅩꅪꅫꅬꅭꅮꅯꅰꅱꅲꅳꅴꅵꅶꅷꅸꅹꅺꅻꅼꅽꅾꅿꆀꆁꆂꆃꆄꆅꆆꆇꆈꆉꆊꆋꆌꆍꆎꆏꆐꆑꆒꆓꆔꆕꆖꆗꆘꆙꆚꆛꆜꆝꆞꆟꆠꆡꆢꆣꆤꆥꆦꆧꆨꆩꆪꆫꆬꆭꆮꆯꆰꆱꆲꆳꆴꆵꆶꆷꆸꆹꆺꆻꆼꆽꆾꆿꇀꇁꇂꇃꇄꇅꇆꇇꇈꇉꇊꇋꇌꇍꇎꇏꇐꇑꇒꇓꇔꇕꇖꇗꇘꇙꇚꇛꇜꇝꇞꇟꇠꇡꇢꇣꇤꇥꇦꇧꇨꇩꇪꇫꇬꇭꇮꇯꇰꇱꇲꇳꇴꇵꇶꇷꇸꇹꇺꇻꇼꇽꇾꇿꈀꈁꈂꈃꈄꈅꈆꈇꈈꈉꈊꈋꈌꈍꈎꈏꈐꈑꈒꈓꈔꈕꈖꈗꈘꈙꈚꈛꈜꈝꈞꈟꈠꈡꈢꈣꈤꈥꈦꈧꈨꈩꈪꈫꈬꈭꈮꈯꈰꈱꈲꈳꈴꈵꈶꈷꈸꈹꈺꈻꈼꈽꈾꈿꉀꉁꉂꉃꉄꉅꉆꉇꉈꉉꉊꉋꉌꉍꉎꉏꉐꉑꉒꉓꉔꉕꉖꉗꉘꉙꉚꉛꉜꉝꉞꉟꉠꉡꉢꉣꉤꉥꉦꉧꉨꉩꉪꉫꉬꉭꉮꉯꉰꉱꉲꉳꉴꉵꉶꉷꉸꉹꉺꉻꉼꉽꉾꉿꊀꊁꊂꊃꊄꊅꊆꊇꊈꊉꊊꊋꊌꊍꊎꊏꊐꊑꊒꊓꊔꊕꊖꊗꊘꊙꊚꊛꊜꊝꊞꊟꊠꊡꊢꊣꊤꊥꊦꊧꊨꊩꊪꊫꊬꊭꊮꊯꊰꊱꊲꊳꊴꊵꊶꊷꊸꊹꊺꊻꊼꊽꊾꊿꋀꋁꋂꋃꋄꋅꋆꋇꋈꋉꋊꋋꋌꋍꋎꋏꋐꋑꋒꋓꋔꋕꋖꋗꋘꋙꋚꋛꋜꋝꋞꋟꋠꋡꋢꋣꋤꋥꋦꋧꋨꋩꋪꋫꋬꋭꋮꋯꋰꋱꋲꋳꋴꋵꋶꋷꋸꋹꋺꋻꋼꋽꋾꋿꌀꌁꌂꌃꌄꌅꌆꌇꌈꌉꌊꌋꌌꌍꌎꌏꌐꌑꌒꌓꌔꌕꌖꌗꌘꌙꌚꌛꌜꌝꌞꌟꌠꌡꌢꌣꌤꌥꌦꌧꌨꌩꌪꌫꌬꌭꌮꌯꌰꌱꌲꌳꌴꌵꌶꌷꌸꌹꌺꌻꌼꌽꌾꌿꍀꍁꍂꍃꍄꍅꍆꍇꍈꍉꍊꍋꍌꍍꍎꍏꍐꍑꍒꍓꍔꍕꍖꍗꍘꍙꍚꍛꍜꍝꍞꍟꍠꍡꍢꍣꍤꍥꍦꍧꍨꍩꍪꍫꍬꍭꍮꍯꍰꍱꍲꍳꍴꍵꍶꍷꍸꍹꍺꍻꍼꍽꍾꍿꎀꎁꎂꎃꎄꎅꎆꎇꎈꎉꎊꎋꎌꎍꎎꎏꎐꎑꎒꎓꎔꎕꎖꎗꎘꎙꎚꎛꎜꎝꎞꎟꎠꎡꎢꎣꎤꎥꎦꎧꎨꎩꎪꎫꎬꎭꎮꎯꎰꎱꎲꎳꎴꎵꎶꎷꎸꎹꎺꎻꎼꎽꎾꎿꏀꏁꏂꏃꏄꏅꏆꏇꏈꏉꏊꏋꏌꏍꏎꏏꏐꏑꏒꏓꏔꏕꏖꏗꏘꏙꏚꏛꏜꏝꏞꏟꏠꏡꏢꏣꏤꏥꏦꏧꏨꏩꏪꏫꏬꏭꏮꏯꏰꏱꏲꏳꏴꏵꏶꏷꏸꏹꏺꏻꏼꏽꏾꏿꐀꐁꐂꐃꐄꐅꐆꐇꐈꐉꐊꐋꐌꐍꐎꐏꐐꐑꐒꐓꐔꐕꐖꐗꐘꐙꐚꐛꐜꐝꐞꐟꐠꐡꐢꐣꐤꐥꐦꐧꐨꐩꐪꐫꐬꐭꐮꐯꐰꐱꐲꐳꐴꐵꐶꐷꐸꐹꐺꐻꐼꐽꐾꐿꑀꑁꑂꑃꑄꑅꑆꑇꑈꑉꑊꑋꑌꑍꑎꑏꑐꑑꑒꑓꑔꑕꑖꑗꑘꑙꑚꑛꑜꑝꑞꑟꑠꑡꑢꑣꑤꑥꑦꑧꑨꑩꑪꑫꑬꑭꑮꑯꑰꑱꑲꑳꑴꑵꑶꑷꑸꑹꑺꑻꑼꑽꑾꑿꒀꒁꒂꒃꒄꒅꒆꒇꒈꒉꒊꒋꒌ꒐꒑꒒꒓꒔꒕꒖꒗꒘꒙꒚꒛꒜꒝꒞꒟꒠꒡꒢꒣꒤꒥꒦꒧꒨꒩꒪꒫꒬꒭꒮꒯꒰꒱꒲꒳꒴꒵꒶꒷꒸꒹꒺꒻꒼꒽꒾꒿꓀꓁꓂꓃꓄꓅꓆"
      ),
    ]
  )
}
