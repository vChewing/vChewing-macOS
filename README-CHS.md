语言：*简体中文* | [繁體中文](./README.md)

仅以此 README 纪念祁建华 (CHIEN-HUA CHI, 1921-2001)。

---

有关该仓库及该输入法的最新资讯，请洽产品主页：https://vchewing.github.io/

因不可控原因，该仓库只能保证在 Gitee 有最新的内容可用：

- 下载：https://gitee.com/vchewing/vChewing-macOS/releases
- 程式码仓库：https://gitee.com/vchewing/vChewing-macOS

# vChewing 唯音输入法

唯音输入法是一款为 macOS 平台开发的副厂**原生简体中文、原生繁体中文注音输入法**：

- 唯音是业界现阶段支援注音排列种类数量与输入用拼音种类数量最多的注音输入法。
    - 受唯音自家的铁恨注音并击引擎加持。
- 唯音的原厂词库内不存在任何可以妨碍该输入法在世界上任何地方传播的内容。
- 相比中州韵（鼠须管）而言，唯音能够做到真正的大千声韵并击。
- 拥有拼音并击模式，不懂注音的人群也可以受益于该输入法所带来的稳定的平均输入速度。
    - 相比小鹤双拼等双拼方案而言，唯音双手声韵分工明确、且重码率只有双拼的五分之一。
- 唯音对陆规审音完全相容：不熟悉台澎金马审音的大陆用户不会遇到与汉字读音有关的不便。
    - 反之亦然。
- 唯音输入法是最安全的 macOS 副厂中文输入法：
    - 有启用 Sandbox 特性，（相比其他没有开 Sandbox 而言）唯音输入法在原理上不可能拿到系统全局键盘权限。
    - 有「强化型组字区安全防护」模式，防止「接收打字的软体」提前存取您的组字区的内容。

>唯音有很多特色功能。在此仅列举部分：
>- 支援 macOS 萤幕模拟键盘（仅传统大千与传统倚天布局）。
>- 可以将自己打的繁体中文自动转成日本 JIS 新字体来输出（包括基础的字词转换）、也可以转成康熙繁体来输出。
>- 简繁体中文语料库彼此分离，彻底杜绝任何繁简转换过程可能造成的失误。
>- 支援近年的全字库汉字输入。
>- 可以自动整理使用者语汇档案格式、自订关联词语。
>- ……

唯音分支专案及唯音词库（先锋语料库）由孙志贵（Shiki Suen）维护，其内容属于可在 Gitee 公开展示的合法内容。但这些内容在被整理收入先锋语料库之前的原始资料的合规性不属于维护者的负责范围之内。

> 资安宣告：唯音输入法的 Shift 按键监测功能仅借由对 NSEvent 讯号资料流的上下文关系的观测来实现，仅接触借由 macOS 系统内建的 InputMethodKit 当中的 IMKServer 传来的 NSEvent 讯号资料流、而无须监听系统全局键盘事件，也无须向使用者申请用以达成这类「可能会引发资安疑虑」的行为所需的辅助权限，更不会将您的电脑内的任何资料传出去（本来就是这样，且自唯音 2.3.0 版引入的 Sandbox 特性更杜绝了这种可能性）。请放心使用。Shift 中英模式切换功能要求至少 macOS 10.15 Catalina 才可以用。

## 系统需求

建置用系统需求：

- **Xcode 26.3+ (macOS 15.6+ required)** 或单独安装的 **Swift 6.2 open-source toolchain** + **macOS 26 SDK**。
    - 原因：Swift 6.2 成为必需版本（用于改进 concurrency 安全特性、SPM 6.2.4+ API 支持、CommandPlugin 改进等）。
- 请使用正式发行版 Xcode，且最小子版本号越高越好（因为 Bug 相对而言最少）。
    - 如果是某个大版本的 Xcode 的 Release Candidate 版本的话，我们可能会对此做相容性测试。

编译出的成品对应系统需求：

- 至少 macOS 12 Monterey。
  - 如需要在更旧版的系统下运行的话，请前往[唯音输入法主页](https://vchewing.github.io/README.html)下载 Aqua 纪念版唯音输入法，可支援自 macOS 10.9 开始至 macOS 12 Monterey 为止的系统版本。

- **推荐最低系统版本**：macOS 14 Sonoma。

  - 同时建议**系统记忆体应至少 4GB**。唯音输入法占用记忆体约 115MB 左右（简繁双模式）、75MB左右（单模式），供参考。
    - 请务必使用 SSD 硬碟，否则可能会影响每次开机之后输入法首次载入的速度。从 10.10 Yosemite 开始，macOS 就已经是针对机械硬碟负优化的作业系统了。

- 关于全字库支援，因下述事实而在理论上很难做到最完美：

  - 很可惜 GB18030-2005 并没有官方提供的逐字读音对照表，所以目前才用了全字库。然而全字库并不等于完美。
  - 有条件者可以安装全字库字型与花园明朝，否则全字库等高万国码码位汉字恐无法在输入法的选字窗内完整显示。
    - 全字库汉字显示支援会受到具体系统版本对万国码版本的支援的限制。
    - 有些全字库汉字一开始会依赖万国码的私人造字区，且在之后被新版本万国码所支援。

## 建置流程

安装 Xcode 之后，请先配置 Xcode 允许其直接构建在专案所在的资料夹下的 build 资料夹内。步骤：
```
「Xcode」->「Preferences...」->「Locations」；
「File」->「Project/WorkspaceSettings...」->「Advanced」；
选「Custom」->「Relative to Workspace」即可。不选的话，make 的过程会出错。
```

在终端机内定位到唯音的克隆本地专案的本地仓库的目录之后，执行下列指令：

- `make update`：取得最新词库资源（使用远端 Swift Package plugin）。
- `make release`：建置通用二进制版本（arm64 + x86_64），输出至 `Build/Products/Release/`。
- `make archive`：建置通用版本并产生 `.xcarchive` 存档（含 dSYM），存入 Xcode Archives 目录。
- `make debug`：快速侦错组建（单一架构）。

或者直接开启 Xcode 专案，Product -> Scheme 选「vChewingInstaller」，编译即可。

第一次安装完之后，如有修改原厂辞典与程式码的话，只要重复上述流程重新安装输入法即可。

如果安装若干次后，发现程式修改的结果并没有出现、或甚至输入法已无法再选用的话，请重新登入系统。

## 关于该仓库的历史记录

该输入法早于 4.1.3 版的记录全部放在[vChewing-macOS-AncientArchive](https://github.com/vChewing/vChewing-macOS-AncientArchive)仓库内。

## 应用授权

唯音输入法 macOS 版以 MIT-NTL License 授权释出 (与 MIT 相容)：© 2021-2022 vChewing 专案。

- 唯音输入法 macOS 版程式维护：Shiki Suen。特别感谢 Isaac Xen 与 Hiraku Wong 等人的技术协力。
- 铁恨注音并击处理引擎：Shiki Suen (AGPL-3.0-or-later License)。
- 天权星语汇处理引擎：Shiki Suen (AGPL-3.0-or-later License)。
- 唯音词库（先锋语料库）由 Shiki Suen 维护，以 3-Clause BSD License 授权释出。其中的词频资料[由 NAER 授权用于非商业用途](https://twitter.com/ShikiSuen/status/1479329302713831424)。

使用者可自由使用、散播本软体，惟散播时必须完整保留版权声明及软体授权、且「一旦经过修改便不可以再继续使用唯音的产品名称」。换言之，这条相对上游 MIT 而言新增的规定就是：你 Fork 可以，但 Fork 成单独发行的产品名称时就必须修改产品名称。

$ EOF.
