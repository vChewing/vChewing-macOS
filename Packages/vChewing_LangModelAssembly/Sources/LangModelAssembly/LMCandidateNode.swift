// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

public class CandidateNode {
  public var name: String
  public var members: [CandidateNode]
  public var previous: CandidateNode?

  public init(name: String, members: [CandidateNode] = [], previous: CandidateNode? = nil) {
    self.name = name
    self.members = members
    members.forEach { $0.previous = self }
    self.previous = previous
  }

  public init(name: String, symbols: String) {
    self.name = name
    members = Array(symbols).map { CandidateNode(name: String($0), symbols: []) }
    members.forEach { $0.previous = self }
  }

  public init(name: String, symbols: [String]) {
    self.name = name
    members = symbols.map { CandidateNode(name: $0, symbols: []) }
    members.forEach { $0.previous = self }
  }

  public static func load(url: URL) {
    DispatchQueue.main.async {
      // 這兩個變數單獨拿出來，省得每次都重建還要浪費算力。
      var arrLines = [String.SubSequence]()
      var fieldSlice = [Substring.SubSequence]()
      var arrMembers = [CandidateNode]()
      do {
        arrLines = try String(contentsOfFile: url.path, encoding: .utf8).split(separator: "\n")
        for strLine in arrLines.lazy.filter({ !$0.isEmpty }) {
          fieldSlice = strLine.split(separator: "=")
          switch fieldSlice.count {
            case 1: arrMembers.append(.init(name: String(fieldSlice[0])))
            case 2: arrMembers.append(.init(name: String(fieldSlice[0]), symbols: .init(fieldSlice[1])))
            default: break
          }
        }
        root = arrMembers.isEmpty ? defaultSymbolRoot : .init(name: "/", members: arrMembers)
      } catch {
        root = defaultSymbolRoot
      }
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

  public private(set) static var root: CandidateNode = .init(name: "/")

  private static let defaultSymbolRoot: CandidateNode = .init(
    name: "/",
    members: [
      CandidateNode(name: "　"),
      CandidateNode(name: "｀"),
      CandidateNode(name: catCommonSymbols, symbols: "，、。．？！；：‧‥﹐﹒˙·‘’“”〝〞‵′〃～＄％﹪＠＆＃＊・…—〜／＼＿―‖﹫﹟﹠﹡"),
      CandidateNode(
        name: catHoriBrackets,
        symbols:
          "（）［］｛｝〈〉《》「」『』【】〔〕〖〗〘〙〚〛︗︘︷︸︹︺︻︼︽︾︿﹀﹁﹂﹃﹄﹇﹈︵︶[]{}⁅⁆⎡⎢⎣⎤⎥⎦⎧⎨⎩⎪⎫⎬⎭⎰⎱｢｣❬❭❰❱❲❳❴❵⟦⟧⟨⟩⟪⟫⟬⟭⦃⦄⦇⦈⦉⦊⦋⦌⦍⦎⦏⦐⦑⦒⦓⦔⦕⦖⦗⦘⧼⧽⸂⸃⸄⸅⸉⸊⸌⸍⸜⸝⸢⸣⸤⸥⸦⸧⎴⎵⎶⏞⏟⏠⏡﹙﹚﹛﹜﹝﹞﹤﹥‘’“”〝〞‵′″＇"
      ),
      CandidateNode(name: catVertBrackets, symbols: "︵︶﹁﹂︹︺︷︸︿﹀﹃﹄︽︾︻︼"),
      CandidateNode(
        name: catAlphabets,
        symbols:
          "αβγδεζηθικλμνξοπρστυφχψωΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩабвгдежзийклмнопрстуфхцчшщъыьэюяёАБВГДЕЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯЁàáèéêìíòóùúüāēěīńňōūǎǐǒǔǖǘǚǜɑɡ¨·"
      ),
      CandidateNode(
        name: catSpecialNumbers, symbols: "ⅠⅡⅢⅣⅤⅥⅦⅧⅨⅩⅪⅫⅰⅱⅲⅳⅴⅵⅶⅷⅸⅹⅺⅻ〇〡〢〣〤〥〦〧〨〩"
      ),
      CandidateNode(
        name: catMathSymbols,
        symbols:
          "﹢﹤﹥＋－＜＝＞✕%+<=>¡¢«°±µ»¼½¾¿×÷ˇθπ‰₠₡₢₣₤₥₦₧₨₩₪₫€℀℁℃℅℆℉⅓⅔⅕⅖⅗⅘⅙⅚⅛⅜⅝⅞⅟∀∁∂∃∄∅∆∇∈∉∊∋∌∍∎∏∐∑−∓∔∕∖∗∘∙√∛∜∝∞∟∠∡∢∣∤∥∧∨∩∪∫∬∭∮∯∰∱∲∳∴∵∶∷∸∹∺∻∼∽∾∿≀≁≂≃≄≅≆≇≈≉≊≋≌≍≎≏≐≑≒≓≔≕≖≗≘≙≚≛≜≝≞≟≠≡≢≣≤≥≦≧≨≩≪≫≬≭≮≯≰≱≲≳≴≵≶≷≸≹≺≻≼≽≾≿⊀⊁⊂⊃⊄⊅⊆⊇⊈⊉⊊⊋⊌⊍⊎⊏⊐⊑⊒⊓⊔⊕⊖⊗⊘⊙⊚⊛⊜⊝⊞⊟⊠⊡⊢⊣⊤⊥⊦⊧⊨⊩⊪⊫⊬⊭⊮⊯⊰⊱⊲⊳⊴⊵⊶⊷⊸⊹⊺⊻⊼⊽⊾⊿⋀⋁⋂⋃⋄⋅⋆⋇⋈⋉⋊⋋⋌⋍⋎⋏⋐⋑⋒⋓⋔⋕⋖⋗⋘⋙⋚⋛⋜⋝⋞⋟⋠⋡⋢⋣⋤⋥⋦⋧⋨⋩⋪⋫⋬⋭⋮⋯⋰⋱"
      ),
      CandidateNode(name: catCurrencyUnits, symbols: "$€¥¢£₽₨₩฿₺₮₱₭₴₦৲৳૱௹﷼₹₲₪₡₫៛₵₢₸₤₳₥₠₣₰₧₯₶₷¤￠￥￡＄﹩￦"),
      CandidateNode(
        name: catSpecialSymbols,
        symbols:
          "↩⌘⎋⏏⇥⇤⇪⇧⌤⌥⎇␣⌃⌄⌅⌆⌦⌫⌧⇱↖↸⇲↘⇞⇟↑↓←→⇡⇣⇠⇢⚙⇭⌽⌀⌁⌂⌐⌑⌒⌓⌔⌕⌖⌗⌙⌨⎄⎅⎆⎈⎉⎊⎌⌚⌛⎗⎘⎙⎚⎀⎁⎂⎃⌇⌈⌉⌊⌋⌌⌍⌏⌠⎮⌡⌢⌣⌜⌝⌞⌟⁒〈〉⌬⌭⌮⌯⌰⌱⌲⌳↗↙↺⇩⇦⇨⇄⇆⇅⇵↻◎○●⊕⊙※△▲☆★◇◆□■▽▼№℡§〒♀♂↯¶©®™🜀🜁🜂🜃🜄🜅🜆🜇🜈🜉🜊🜋🜌🜍🜎🜏🜐🜑🜒🜓🜔🜕🜖🜗🜘🜙🜚🜛🜜🜝🜞🜟🜠🜡🜢🜣🜤🜥🜦🜧🜨🜩🜪🜫🜬🜭🜮🜯🜰🜱🜲🜳🜴🜵🜶🜷🜸🜹🜺🜻🜼🜽🜾🜿🝀🝁🝂🝃🝄🝅🝆🝇🝈🝉🝊🝋🝌🝍🝎🝏🝐🝑🝒🝓🝔🝕🝖🝗🝘🝙🝚🝛🝜🝝🝞🝟🝠🝡🝢🝣🝤🝥🝦🝧🝨🝩🝪🝫🝬🝭🝮🝯🝰🝱🝲🝳↚↛↜↝↞↟↠↡↢↣↤↥↦↧↨↪↫↬↭↮"
      ),
      CandidateNode(
        name: catUnicodeSymbols,
        symbols:
          "※∮∴∵∽☀☁☂☃☺☻♠♣♥♦♨♩♪♫♬♭♯■□▢▣▤▥▦▧▨▩▪▫▬▭▮▯▰▱▲△▴▵▶▷▸▹►▻▼▽▾▿◀◁◂◃◄◅◆◇◈◉◊○◌◍◎●◐◑◒◓◔◕◖◗◘◙◚◛◜◝◞◟◠◡◢◣◤◥◦◧◨◩◪◫◬◭◮◯◰◱◲◳◴◵◶◷◸◹◺◻◼◽◾◿☄★☆☇☈☉☊☋☌☍☎☏☐☑☒☓☔☕☖☗☘☙☚☛☜☝☞☟☠☡☢☣☤☥☦☧☨☩☪☫☬☭☮☯☰☱☲☳☴☵☶☷☸☹☼☽☾☿♀♁♂♃♄♅♆♇♈♉♊♋♌♍♎♏♐♑♒♓♔♕♖♗♘♙♚♛♜♝♞♟♡♢♤♧♮♰♱♲♳♴♵♶♷♸♹♺♻♼♽♾♿⚀⚁⚂⚃⚄⚅⚆⚇⚈⚉⚊⚋⚌⚍⚎⚏⚐⚑⚒⚓⚔⚕⚖⚗⚘⚙⚚⚛⚜⚝⚞⚟⚠⚡⚢⚣⚤⚥⚦⚧⚨⚩⚪⚫⚬⚭⚮⚯⚰⚱⚲⚳⚴⚵⚶⚷⚸⚹⚺⚻⚼⚽⚾⚿⛀⛁⛂⛃⛄⛅⛆⛇⛈⛉⛊⛋⛌⛍⛎⛏⛐⛑⛒⛓⛔⛕⛖⛗⛘⛙⛚⛛⛜⛝⛞⛟⛠⛡⛢⛣⛤⛥⛦⛧⛨⛩⛪⛫⛬⛭⛮⛯⛰⛱⛲⛳⛴⛵⛶⛷⛸⛹⛺⛻⛼⛽⛾⛿✁✂✃✄✅✆✇✈✉✊✋✌✍✎✏✐✑✒✓✔✕✖✗✘✙✚✛✜✝✞✟✠✡✢✣✤✥✦✧✨✩✪✫✬✭✮✯✰✱✲✳✴✵✶✷✸✹✺✻✼✽✾✿❀❁❂❃❄❅❆❇❈❉❊❋❌❍❎❏❐❑❒❓❔❕❖❗❘❙❚❛❜❝❞❟❠❡❢❣❤❥❦❧❨❩❪❫❬❭❮❯❰❱❲❳❴❵➔➕➖➗➘➙➚➛➜➝➞➟➠➡➢➣➤➥➦➧➨➩➪➫➬➭➮➯➰➱➲➳➴➵➶➷➸➹➺➻➼➽➾➿⬀⬁⬂⬃⬄⬅⬆⬇⬈⬉⬊⬋⬌⬍⬎⬏⬐⬑⬒⬓⬔⬕⬖⬗⬘⬙⬚⬛⬜⬝⬞⬟⬠⬡⬢⬣⬤⬥⬦⬧⬨⬩⬪⬫⬬⬭⬮⬯⬰⬱⬲⬳⬴⬵⬶⬷⬸⬹⬺⬻⬼⬽⬾⬿⭀⭁⭂⭃⭄⭅⭆⭇⭈⭉⭊⭋⭌⭐⭑⭒⭓⭔⭕⭖⭗⭘⭙₮〠〶ↀↁↂ₭〇〄㉿〆₯ℂ℄"
      ),
      CandidateNode(
        name: catMusicSymbols,
        symbols:
          "𝄀𝄁𝄂𝄃𝄄𝄅𝄆𝄇𝄈𝄉𝄊𝄋𝄌𝄍𝄎𝄏𝄐𝄑𝄒𝄓𝄔𝄕𝄖𝄗𝄘𝄙𝄚𝄛𝄜𝄝𝄞𝄟𝄠𝄡𝄢𝄣𝄤𝄥𝄦𝄩𝄪𝄫𝄬𝄭𝄮𝄯𝄰𝄱𝄲𝄳𝄴𝄵𝄶𝄷𝄸𝄹𝄺𝄻𝄼𝄽𝄾𝄿𝅀𝅁𝅂𝅃𝅄𝅅𝅆𝅇𝅈𝅉𝅊𝅋𝅌𝅍𝅎𝅏𝅐𝅑𝅒𝅓𝅔𝅕𝅖𝅗𝅗𝅥𝅘𝅘𝅥𝅘𝅥𝅮𝅘𝅥𝅯𝅘𝅥𝅰𝅘𝅥𝅱𝅘𝅧𝅨𝅩𝅥𝅲𝅥𝅦𝅙𝅚𝅛𝅜𝅝𝅪𝅫𝅬𝅮𝅯𝅰𝅱𝅲𝅭𝅳𝅴𝅵𝅶𝅷𝅸𝅹𝅺𝅻𝅼𝅽𝅾𝅿𝆀𝆁𝆂𝆃𝆄𝆊𝆋𝆅𝆆𝆇𝆈𝆉𝆌𝆍𝆎𝆏𝆐𝆑𝆒𝆓𝆔𝆕𝆖𝆗𝆘𝆙𝆚𝆛𝆜𝆝𝆞𝆟𝆠𝆡𝆢𝆣𝆤𝆥𝆦𝆧𝆨𝆩𝆪𝆫𝆬𝆭𝆮𝆯𝆰𝆱𝆲𝆳𝆴𝆵𝆶𝆷𝆸𝆹𝆹𝅥𝆹𝅥𝅮𝆹𝅥𝅯𝆺𝆺𝅥𝆺𝅥𝅮𝆺𝅥𝅯𝇁𝇂𝇃𝇄𝇅𝇆𝇇𝇈𝇉𝇊𝇋𝇌𝇍𝇎𝇏𝇐𝇑𝇒𝇓𝇔𝇕𝇖𝇗𝇘𝇙𝇚𝇛𝇜𝇝𝇞𝇟𝇠𝇡𝇢𝇣𝇤𝇥𝇦𝇧𝇨"
      ),
      CandidateNode(name: catCircledKanjis, symbols: "㊊㊋㊌㊍㊎㊏㊐㊑㊒㊓㊔㊕㊖㊗︎㊘㊙︎㊚㊛㊜㊝㊞㊟㊠㊡㊢㊣㊤㊥㊦㊧㊨㊩㊪㊫㊬㊭㊮㊯㊰㊀㊁㊂㊃㊄㊅㊆㊇㊈㊉🈚︎🈯︎"),
      CandidateNode(
        name: catCircledKataKana, symbols: "㋐㋑㋒㋓㋔㋕㋖㋗㋘㋙㋚㋛㋜㋝㋞㋟㋠㋡㋢㋣㋤㋥㋦㋧㋨㋩㋪㋫㋬㋭㋮㋯㋰㋱㋲㋳㋴㋵㋶㋷㋸㋹㋺㋻㋼㋽㋾"
      ),
      CandidateNode(name: catBracketKanjis, symbols: "㈪㈫㈬㈭㈮㈯㈰㈱㈲㈳㈴㈵㈶㈷㈸㈹㈺㈻㈼㈽㈾㈿㉀㉁㉂㉃"),
      CandidateNode(name: catSingleTableLines, symbols: "─│┌┐└┕┘├┤┬┴┼═╞╡╪╭╮╯╰▕"),
      CandidateNode(name: catDoubleTableLines, symbols: "═║╒╓╔╕╖╗╘╙╚╛╜╝╞╟╠╡╢╣╤╥╦╧╨╩╪╫╬"),
      CandidateNode(name: catFillingBlocks, symbols: "＿ˍ▁▂▃▄▅▆▇█▏▎▍▌▋▊▉◢◣◥◤"),
      CandidateNode(name: catLineSegments, symbols: "﹣﹦≡｜∣∥–︱—︳╴¯￣﹉﹊﹍﹎﹋﹌﹏︴∕﹨╱╲／＼ˍ━┃▕〓╳∏ˆ⌒┄┅┆┇┈┉┊┋"),
      CandidateNode(
        name: catKana,
        symbols:
          "ぁあぃいぅうゔぇえぉおかがきぎくぐけげこごさざしじすずせぜそぞただちぢっつづてでとどなにぬねのはばひびふぶへべほぼまみむめもゃやゅゆょよらら゚りり゚るる゚れれ゚ろろ゚ゎわわ゙ゐゐ゙ゑゑ゙をを゙んゕゖゝゞゟ〻゠ァアィイゥウヴェエォオカガキギクグケゲコゴサザシジスズセゼソゾタダチヂッツヅテデトドナニヌネノハバパヒビピフブプヘベペホボポマミムメモャヤュユョヨララ゚リリ゚ルル゚レレ゚ロロ゚ヮワヷヰヸヱヹヲヺンヵヶ・ーヽヾヿ々ㇰㇱㇲㇳㇴㇵㇶㇷㇸㇹㇺㇻㇼㇽㇾㇿ･ｦｧｨｩｪｫｬｭｮｯｰｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ ﾞ ﾟ〲〱〳〴〵"
      ),
      CandidateNode(
        name: catCombinations,
        symbols:
          "㍘㍙㍚㍛㍜㍝㍞㍟㍠㍡㍢㍣㍤㍥㍦㍧㍨㍩㍪㍫㍬㍭㍮㍯㍰㏠㏡㏢㏣㏤㏥㏦㏧㏨㏩㏪㏫㏬㏭㏮㏯㏰㏱㏲㏳㏴㏵㏶㏷㏸㏹㏺㏻㏼㏽㏾㍱㍲㍳㍴㍵㍶㍷㍸㍹㍺㎀㎁㎂㎃㎄㎅㎆㎇㎈㎉㎊㎋㎌㎍㎎㎏㎐㎑㎒㎓㎔㎕㎖㎗㎘㎙㎚㎛㎜㎝㎞㎟㎠㎡㎢㎣㎤㎥㎦㎧㎨㎩㎪㎫㎬㎭㎮㎯㎰㎱㎲㎳㎴㎵㎶㎷㎸㎹㎺㎻㎼㎽㎾㎿㏀㏁㏂㏃㏄㏅㏆㏇㏈㏉㏊㏋㏌㏍㏎㏏㏐㏑㏒㏓㏔㏕㏖㏗㏘㏙㏚㏛㏜㏝㏞㏟㏿㋿㍼㍽㍾㍻㍿㌀㌁㌂㌃㌄㌅㌆㌇㌈㌉㌊㌋㌌㌍㌎㌏㌐㌑㌒㌓㌔㌕㌖㌗㌘㌙㌚㌛㌜㌝㌞㌟㌠㌡㌢㌣㌤㌥㌦㌧㌨㌩㌪㌫㌬㌭㌮㌯㌰㌱㌲㌳㌴㌵㌶㌷㌸㌹㌺㌻㌼㌽㌾㌿㍀㍁㍂㍃㍄㍅㍆㍇㍈㍉㍊㍋㍌㍍㍎㍏㍐㍑㍒㍓㍔㍕㍖㍗"
      ),
      CandidateNode(
        name: catPhonabets, symbols: "ㄅㄆㄇㄈㄉㄊㄋㄌㄍㄎㄏㄐㄑㄒㄓㄔㄕㄖㄗㄘㄙㄚㄛㄜㄝㄞㄟㄠㄡㄢㄣㄤㄥㄦㄧㄨㄩㄪㄫㄬㄭㄮㄯㆵㆠㆡㆢㆣㆤㆥㆦㆧㆨㆩㆪㆫㆬㆭㆮㆯㆰㆱㆲㆳㆴㆶㆷㆸㆹㆺㆻㆼㆽㆾㆿ˙ˊˇˋ˪˫"
      ),
      CandidateNode(
        name: catCircledASCII,
        symbols:
          "①②③④⑤⑥⑦⑧⑨⑩⑪⑫⑬⑭⑮⑯⑰⑱⑲⑳ⒶⒷⒸⒹⒺⒻⒼⒽⒾⒿⓀⓁⓂⓂ︎ⓃⓄⓅⓆⓇⓈⓉⓊⓋⓌⓍⓎⓏⓐⓑⓒⓓⓔⓕⓖⓗⓘⓙⓚⓛⓜⓝⓞⓟⓠⓡⓢⓣⓤⓥⓦⓧⓨⓩ⓪⓫⓬⓭⓮⓯⓰⓱⓲⓳⓴⓵⓶⓷⓸⓹⓺⓻⓼⓽⓾⓿❶❷❸❹❺❻❼❽❾❿➀➁➂➃➄➅➆➇➈➉➊➋➌➍➎➏➐➑➒➓🄰🄱🄲🄳🄴🄵🄶🄷🄸🄹🄺🄻🄼🄽🄾🄿🅀🅁🅂🅃🅄🅅🅆🅇🅈🅉🅐🅑🅒🅓🅔🅕🅖🅗🅘🅙🅚🅛🅜🅝🅞🅟🅠🅡🅢🅣🅤🅥🅦🅧🅨🅩🅰🅱🅲🅳🅴🅵🅶🅷🅸🅹🅺🅻🅼🅽🅾🅿︎🆀🆁🆂🆃🆄🆅🆆🆇🆈🆉"
      ),
      CandidateNode(
        name: catBracketedASCII, symbols: "⑴⑵⑶⑷⑸⑹⑺⑻⑼⑽⑾⑿⒀⒁⒂⒃⒄⒅⒆⒇⒜⒝⒞⒟⒠⒡⒢⒣⒤⒥⒦⒧⒨⒩⒪⒫⒬⒭⒮⒯⒰⒱⒲⒳⒴⒵🄐🄑🄒🄓🄔🄕🄖🄗🄘🄙🄚🄛🄜🄝🄞🄟🄠🄡🄢🄣🄤🄥🄦🄧🄨🄩"
      ),
      CandidateNode(
        name: catThai,
        symbols: [
          "ก", "ข", "ฃ", "ค", "ฅ", "ฆ", "ง", "จ", "ฉ", "ช", "ซ", "ฌ", "ญ", "ฎ", "ฏ", "ฐ", "ฑ", "ฒ", "ณ", "ด", "ต", "ถ",
          "ท", "ธ", "น", "บ", "ป", "ผ", "ฝ", "พ", "ฟ", "ภ", "ม", "ย", "ร", "ฤ", "ล", "ฦ", "ว", "ศ", "ษ", "ส", "ห", "ฬ",
          "อ", "ฮ", "ฯ", "ะ", "ั", "า", "ำ", "ิ", "ี", "ึ", "ื", "ุ", "ู", "ฺ", "เ", "แ", "โ", "ใ", "ไ", "ๅ", "ๆ",
          "็", "่", "้", "๊", "๋", "์", "ํ", "๎", "๏", "๐", "๑", "๒", "๓", "๔", "๕", "๖", "๗", "๘", "๙", "๚", "๛",
        ]
      ),
      CandidateNode(
        name: catYi,
        symbols:
          "ꀀꀁꀂꀃꀄꀅꀆꀇꀈꀉꀊꀋꀌꀍꀎꀏꀐꀑꀒꀓꀔꀕꀖꀗꀘꀙꀚꀛꀜꀝꀞꀟꀠꀡꀢꀣꀤꀥꀦꀧꀨꀩꀪꀫꀬꀭꀮꀯꀰꀱꀲꀳꀴꀵꀶꀷꀸꀹꀺꀻꀼꀽꀾꀿꁀꁁꁂꁃꁄꁅꁆꁇꁈꁉꁊꁋꁌꁍꁎꁏꁐꁑꁒꁓꁔꁕꁖꁗꁘꁙꁚꁛꁜꁝꁞꁟꁠꁡꁢꁣꁤꁥꁦꁧꁨꁩꁪꁫꁬꁭꁮꁯꁰꁱꁲꁳꁴꁵꁶꁷꁸꁹꁺꁻꁼꁽꁾꁿꂀꂁꂂꂃꂄꂅꂆꂇꂈꂉꂊꂋꂌꂍꂎꂏꂐꂑꂒꂓꂔꂕꂖꂗꂘꂙꂚꂛꂜꂝꂞꂟꂠꂡꂢꂣꂤꂥꂦꂧꂨꂩꂪꂫꂬꂭꂮꂯꂰꂱꂲꂳꂴꂵꂶꂷꂸꂹꂺꂻꂼꂽꂾꂿꃀꃁꃂꃃꃄꃅꃆꃇꃈꃉꃊꃋꃌꃍꃎꃏꃐꃑꃒꃓꃔꃕꃖꃗꃘꃙꃚꃛꃜꃝꃞꃟꃠꃡꃢꃣꃤꃥꃦꃧꃨꃩꃪꃫꃬꃭꃮꃯꃰꃱꃲꃳꃴꃵꃶꃷꃸꃹꃺꃻꃼꃽꃾꃿꄀꄁꄂꄃꄄꄅꄆꄇꄈꄉꄊꄋꄌꄍꄎꄏꄐꄑꄒꄓꄔꄕꄖꄗꄘꄙꄚꄛꄜꄝꄞꄟꄠꄡꄢꄣꄤꄥꄦꄧꄨꄩꄪꄫꄬꄭꄮꄯꄰꄱꄲꄳꄴꄵꄶꄷꄸꄹꄺꄻꄼꄽꄾꄿꅀꅁꅂꅃꅄꅅꅆꅇꅈꅉꅊꅋꅌꅍꅎꅏꅐꅑꅒꅓꅔꅕꅖꅗꅘꅙꅚꅛꅜꅝꅞꅟꅠꅡꅢꅣꅤꅥꅦꅧꅨꅩꅪꅫꅬꅭꅮꅯꅰꅱꅲꅳꅴꅵꅶꅷꅸꅹꅺꅻꅼꅽꅾꅿꆀꆁꆂꆃꆄꆅꆆꆇꆈꆉꆊꆋꆌꆍꆎꆏꆐꆑꆒꆓꆔꆕꆖꆗꆘꆙꆚꆛꆜꆝꆞꆟꆠꆡꆢꆣꆤꆥꆦꆧꆨꆩꆪꆫꆬꆭꆮꆯꆰꆱꆲꆳꆴꆵꆶꆷꆸꆹꆺꆻꆼꆽꆾꆿꇀꇁꇂꇃꇄꇅꇆꇇꇈꇉꇊꇋꇌꇍꇎꇏꇐꇑꇒꇓꇔꇕꇖꇗꇘꇙꇚꇛꇜꇝꇞꇟꇠꇡꇢꇣꇤꇥꇦꇧꇨꇩꇪꇫꇬꇭꇮꇯꇰꇱꇲꇳꇴꇵꇶꇷꇸꇹꇺꇻꇼꇽꇾꇿꈀꈁꈂꈃꈄꈅꈆꈇꈈꈉꈊꈋꈌꈍꈎꈏꈐꈑꈒꈓꈔꈕꈖꈗꈘꈙꈚꈛꈜꈝꈞꈟꈠꈡꈢꈣꈤꈥꈦꈧꈨꈩꈪꈫꈬꈭꈮꈯꈰꈱꈲꈳꈴꈵꈶꈷꈸꈹꈺꈻꈼꈽꈾꈿꉀꉁꉂꉃꉄꉅꉆꉇꉈꉉꉊꉋꉌꉍꉎꉏꉐꉑꉒꉓꉔꉕꉖꉗꉘꉙꉚꉛꉜꉝꉞꉟꉠꉡꉢꉣꉤꉥꉦꉧꉨꉩꉪꉫꉬꉭꉮꉯꉰꉱꉲꉳꉴꉵꉶꉷꉸꉹꉺꉻꉼꉽꉾꉿꊀꊁꊂꊃꊄꊅꊆꊇꊈꊉꊊꊋꊌꊍꊎꊏꊐꊑꊒꊓꊔꊕꊖꊗꊘꊙꊚꊛꊜꊝꊞꊟꊠꊡꊢꊣꊤꊥꊦꊧꊨꊩꊪꊫꊬꊭꊮꊯꊰꊱꊲꊳꊴꊵꊶꊷꊸꊹꊺꊻꊼꊽꊾꊿꋀꋁꋂꋃꋄꋅꋆꋇꋈꋉꋊꋋꋌꋍꋎꋏꋐꋑꋒꋓꋔꋕꋖꋗꋘꋙꋚꋛꋜꋝꋞꋟꋠꋡꋢꋣꋤꋥꋦꋧꋨꋩꋪꋫꋬꋭꋮꋯꋰꋱꋲꋳꋴꋵꋶꋷꋸꋹꋺꋻꋼꋽꋾꋿꌀꌁꌂꌃꌄꌅꌆꌇꌈꌉꌊꌋꌌꌍꌎꌏꌐꌑꌒꌓꌔꌕꌖꌗꌘꌙꌚꌛꌜꌝꌞꌟꌠꌡꌢꌣꌤꌥꌦꌧꌨꌩꌪꌫꌬꌭꌮꌯꌰꌱꌲꌳꌴꌵꌶꌷꌸꌹꌺꌻꌼꌽꌾꌿꍀꍁꍂꍃꍄꍅꍆꍇꍈꍉꍊꍋꍌꍍꍎꍏꍐꍑꍒꍓꍔꍕꍖꍗꍘꍙꍚꍛꍜꍝꍞꍟꍠꍡꍢꍣꍤꍥꍦꍧꍨꍩꍪꍫꍬꍭꍮꍯꍰꍱꍲꍳꍴꍵꍶꍷꍸꍹꍺꍻꍼꍽꍾꍿꎀꎁꎂꎃꎄꎅꎆꎇꎈꎉꎊꎋꎌꎍꎎꎏꎐꎑꎒꎓꎔꎕꎖꎗꎘꎙꎚꎛꎜꎝꎞꎟꎠꎡꎢꎣꎤꎥꎦꎧꎨꎩꎪꎫꎬꎭꎮꎯꎰꎱꎲꎳꎴꎵꎶꎷꎸꎹꎺꎻꎼꎽꎾꎿꏀꏁꏂꏃꏄꏅꏆꏇꏈꏉꏊꏋꏌꏍꏎꏏꏐꏑꏒꏓꏔꏕꏖꏗꏘꏙꏚꏛꏜꏝꏞꏟꏠꏡꏢꏣꏤꏥꏦꏧꏨꏩꏪꏫꏬꏭꏮꏯꏰꏱꏲꏳꏴꏵꏶꏷꏸꏹꏺꏻꏼꏽꏾꏿꐀꐁꐂꐃꐄꐅꐆꐇꐈꐉꐊꐋꐌꐍꐎꐏꐐꐑꐒꐓꐔꐕꐖꐗꐘꐙꐚꐛꐜꐝꐞꐟꐠꐡꐢꐣꐤꐥꐦꐧꐨꐩꐪꐫꐬꐭꐮꐯꐰꐱꐲꐳꐴꐵꐶꐷꐸꐹꐺꐻꐼꐽꐾꐿꑀꑁꑂꑃꑄꑅꑆꑇꑈꑉꑊꑋꑌꑍꑎꑏꑐꑑꑒꑓꑔꑕꑖꑗꑘꑙꑚꑛꑜꑝꑞꑟꑠꑡꑢꑣꑤꑥꑦꑧꑨꑩꑪꑫꑬꑭꑮꑯꑰꑱꑲꑳꑴꑵꑶꑷꑸꑹꑺꑻꑼꑽꑾꑿꒀꒁꒂꒃꒄꒅꒆꒇꒈꒉꒊꒋꒌ꒐꒑꒒꒓꒔꒕꒖꒗꒘꒙꒚꒛꒜꒝꒞꒟꒠꒡꒢꒣꒤꒥꒦꒧꒨꒩꒪꒫꒬꒭꒮꒯꒰꒱꒲꒳꒴꒵꒶꒷꒸꒹꒺꒻꒼꒽꒾꒿꓀꓁꓂꓃꓄꓅꓆"
      ),
    ]
  )
}
