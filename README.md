语言：*简体中文* | [繁體中文](./README-CHT.md)

---

因不可控原因，该仓库只能保证在 Gitee 有最新的内容可用：

- 下载：https://gitee.com/vchewing/vChewing-macOS/releases
- 源码仓库：https://gitee.com/vchewing/vChewing-macOS

# vChewing 威注音输入法

威注音输入法基于小麦注音二次开发，是**原生简体中文、原生繁体中文注音输入法**：

- 威注音是业界现阶段支持注音排列种类数量与输入用拼音种类数量最多的注音输入法。
  - 受威注音自家的铁恨注音并击引擎加持。
- 威注音的原厂词库内不存在任何可以妨碍该输入法在世界上任何地方传播的内容。
- 相比中州韵（鼠须管）而言，威注音能够做到真正的大千声韵并击。
- 拥有拼音并击模式，不懂注音的人群也可以受益于该输入法所带来的稳定的平均输入速度。
  - 相比小鹤双拼等双拼方案而言，威注音双手声韵分工明确、且重码率只有双拼的五分之一。
- 威注音对陆规审音完全相容：不熟悉台澎金马审音的大陆用户不会遇到与汉字读音有关的不便。
  - 反之亦然。

>威注音有很多特色功能。在此仅列举部分：
>- 支持 macOS 屏幕模拟键盘（仅传统大千与传统倚天布局）。
>- 可以将自己打的繁体中文自动转成日本 JIS 新字体来输出（包括基础的字词转换）、也可以转成康熙繁体来输出。
>- 简繁体中文语料库彼此分离，彻底杜绝任何繁简转换过程可能造成的失误。
>- 支持近年的全字库汉字输入。
>- 可以自动整理使用者语汇档案格式、自订联想词。
>- ……

威注音分支专案及威注音词库由孙志贵（Shiki Suen）维护，其内容属于可在 Gitee 公开展示的合法内容。小麦注音官方原始仓库内的词库的内容均与孙志贵无关。

## 系统需求

编译用系统需求：

- 至少 macOS 11 Big Sur & Xcode 13。
    - 原因：Swift 封包管理支持与 Swift 5.5 所需。
    - 我们已经没有条件测试 macOS 10.15 Catalina & Xcode 12 环境了。硬要在这个环境下编译的话，可能需要额外安装[新版 Swift](https://www.swift.org/download/) 才可以。
- 请使用正式发行版 Xcode，且最小子版本号越高越好（因为 Bug 相对而言最少）。
    - 如果是某个大版本的 Xcode 的 Release Candidate 版本的话，我们可能会对此做相容性测试。

编译出的成品对应系统需求：

- 至少 macOS El Capitan 10.11.5，否则无法处理 Unicode 8.0 的汉字。即便如此，仍需手动升级苹方至至少 macOS 10.12 开始随赠的版本、以支持 Unicode 8.0 的通用规范汉字表用字（全字库没有「𫫇」字）。
  - 保留该系统支持的原因：非 Unibody 机种的 MacBook Pro 支持的最后一版 macOS 就是 El Capitan。

- **推荐最低系统版本**：macOS 10.12 Sierra，对 Unicode 8.0 开始的《通用规范汉字表》汉字有原生的苹方支持。

  - 同时建议**系统运存应至少 4GB**。威注音输入法占用运存约 115MB 左右（简繁双模式）、75MB左右（单模式），供参考。
    - 请务必使用 SSD 硬盘，否则可能会影响每次开机之后输入法首次载入的速度。从 10.10 Yosemite 开始，macOS 就已经是针对机械硬盘负优化的操作系统了。
    - 注：能装 macOS 10.13 High Sierra 就不要去碰 macOS 10.12 Sierra 这个半成品。

- 关于全字库支持，因下述事实而在理论上很难做到最完美：

  - 很可惜 GB18030-2005 并没有官方提供的逐字读音对照表，所以目前才用了全字库。然而全字库并不等于完美。
  - 有条件者可以安装全字库字型与花园明朝，否则全字库等高万国码码位汉字恐无法在输入法的选字窗内完整显示。
    - 全字库汉字显示支持会受到具体系统版本对万国码版本的支持的限制。
    - 有些全字库汉字一开始会依赖万国码的私人造字区，且在之后被新版本万国码所支持。

## 编译流程

安装 Xcode 之后，请先配置 Xcode 允许其直接构建在专案所在的资料夹下的 build 资料夹内。步骤：
```
「Xcode」->「Preferences...」->「Locations」；
「File」->「Project/WorkspaceSettings...」->「Advanced」；
选「Custom」->「Relative to Workspace」即可。不选的话，make 的过程会出错。
```
在终端机内定位到威注音的克隆本地专案的本地仓库的目录之后，执行 `make update` 以获取最新词库。

接下来就是直接开 Xcode 专案，Product -> Scheme 选「vChewingInstaller」，编译即可。

> 之前说「在成功之后执行 `make` 即可编译、再执行 `make install` 可以触发威注音的安装程式」，这对新版威注音而言**当且仅当**使用纯 Swift 编译脚本工序时方可使用。目前的 libvchewing-data 模组已经针对 macOS 版威注音实装了纯 Swift 词库编译脚本。

第一次安装完，日后源码或词库有任何修改，只要重覆上述流程，再次安装威注音即可。

要注意的是 macOS 可能会限制同一次 login session 能终结同一个输入法的执行进程的次数（安装程式透过 kill input method process 来让新版的输入法生效）。如果安装若干次后，发现程式修改的结果并没有出现、或甚至输入法已无法再选用，只需要登出目前的 macOS 系统帐号、再重新登入即可。

补记: 该输入法是在 2021 年 11 月初「28ae7deb4092f067539cff600397292e66a5dd56」这一版小麦注音编译的基础上完成的。因为在清洗词库的时候清洗了全部的 git commit 历史，所以无法自动从小麦注音官方仓库上游继承任何改动，只能手动同步任何在此之后的程式修正。最近一次同步参照是上游主仓库的 2.2.2 版、以及 zonble 的分支「5cb6819e132a02bbcba77dbf083ada418750dab7」。

## 应用授权

威注音专案仅用到小麦注音的下述程式组件（MIT License）：

- 状态管理引擎 & NSStringUtils & FSEventStreamHelper (by Zonble Yang)。
- 半衰记忆模组，因故障暂时无法启用 (by Mengjuei Hsieh)。
- 仅供研发人员调试方便而使用的 App 版安装程式 (by Zonble Yang)。
- Voltaire MK2 选字窗、飘云通知视窗、工具提示 (by Zonble Yang)，有大幅度修改。

威注音输入法 macOS 版以 MIT-NTL License 授权释出 (与 MIT 相容)：© 2021-2022 vChewing 专案。

- 威注音输入法 macOS 版程式维护：Shiki Suen。特别感谢 Isaac Xen 与 Hiraku Wong 等人的技术协力。
- 铁恨注音并击处理引擎：Shiki Suen (MIT-NTL License)。
- 天权星语汇处理引擎：Shiki Suen (MIT-NTL License)。
- 威注音词库由 Shiki Suen 维护，以 3-Clause BSD License 授权释出。其中的词频数据[由 NAER 授权用于非商业用途](https://twitter.com/ShikiSuen/status/1479329302713831424)。

使用者可自由使用、散播本软件，惟散播时必须完整保留版权声明及软件授权、且一旦经过修改便不可以再继续使用威注音的产品名称。

## 资料来源

原厂词库主要词语资料来源：

- 《重编国语辞典修订本 2015》的六字以内的词语资料 (CC BY-ND 3.0)。
- 《CNS11643中文标准交换码全字库(简称全字库)》 (OGDv1 License)。
- LibTaBE (by Pai-Hsiang Hsiao under 3-Clause BSD License)。
- [《新加坡华语资料库》](https://www.languagecouncils.sg/mandarin/ch/learning-resources/singaporean-mandarin-database)。
- 原始词频资料取自 NAER，有经过换算处理与按需调整。
    - 威注音并未使用由 LibTaBE 内建的来自 Sinica 语料库的词频资料。
- 威注音语汇库作者自行维护新增的词语资料，包括：
    - 尽可能所有字词的陆规审音与齐铁恨广播读音。
    - 中国大陆常用资讯电子术语等常用语，以确保简体中文母语者在使用输入法时不会受到审音差异的困扰。
- 其他使用者建议收录的资料。

## 格式规范等与参与研发时需要注意的事项

该专案对源码格式有规范，且 Swift 与其他 (Obj)C(++) 系语言持不同规范。请洽该仓库内的「[CONTRIBUTING.md](./CONTRIBUTING.md)」档案。

## 其他

为了您的精神卫生，任何使用威注音输入法时遇到的产品问题、请勿提报至小麦注音。哪怕您确信小麦注音也有该问题。

滥用沉默权来浪费对方的时间与热情，也是一种暴力。**当对方最最最开始就把你当敌人的时候，你连呼吸都是错的**。

$ EOF.
