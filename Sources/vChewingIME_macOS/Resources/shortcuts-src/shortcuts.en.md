---
# 本文書群之正文一律 zh-Hant-TW；本檔之註解亦然（此處為施工說明，不隨產物出貨）。
# 英文版由繁體中文之權威原文（官網倉 `manual/shortcuts.md`）改寫而成；新增或修訂列一律回該檔取義。
# 現行卷：P285 自舊 HTML 逆推原稿並追平 4.8.6。
---
# Keyboard Shortcut CheatSheet（macOS）

This article uses certain macOS keyboard symbols to simplify the description. Note:

1. The names of BackSpace and Delete keys conform to Windows and Linux standard.
1. The names of arrow keys are redefined according to the text writing direction.
1. The verb "shang4-ping2 (上屏)" used in Simplified Chinese is replaced by its standard term "commit".
1. vChewing doesn't handle (real) numpad inputs (numbers and math symbols from there) except that the candidate window is shown up and number / math symbol keys are used as candidate keys.
1. The "number keys" referred by this article only indicate those number keys in the main keyboard area.
1. The term "ICB" is short for "inline composition buffer" which is also called "pre-edit area" by the Text Service Framework in Microsoft Windows.
1. The term "PCB" is short for "phonabet combination buffer" and is operated by the Tekkon composer. It appears in ICB when user is typing phonabets. The input method retrieves combined reading keys from PCB, checking whether they are valid (having records in the dictionary), and puts valid results into the Homa assembler. The entire ICB appears as a facade in front of Homa and Tekkon.
1. vChewing doesn't use Zonble's term "before" & "after" since they are extremely misleading. We use "front/rear (back, tail)" & "forward / backward" which refers to the typing direction.
1. The term "symbol menu state" only refers to the categorized symbol menu.

| Symbols | Mac Keyboard |
|-:|-|
| ⌘ | CMD (Command  / Windows / Super) |
| ⌥ | Alt (Option) |
| ⌃ | Ctrl (Control) |
| ⇧ | Shift |
| ⇪ | Caps (Caps Lock) |
| ⌫ | Bksp (BackSpace. Apple calls it "Delete") |
| ⌦ | Del (This is the real "Delete") |
| ⎋ | Esc (Escape) |
| ␣ | Space |
| ⇥ | Tab |
| ⏎ | Return (Combined with Enter ⌤ key) |
| ↑ | Left-hand key: Up when horizontal typing, Right when vertical typing. |
| ↓ | Right-hand key: Down when horizontal typing, Left when vertical typing. |
| ← | Backward key: Left when horizontal typing, Up when vertical typing. |
| → | Forward key: Right when horizontal typing, Down when vertical typing. |
| ↖︎ | Home |
| ↘︎ | End |
| ⇞ | PgUp (Page Up) |
| ⇟ | PgDn (Page Down) |
| ☰ | Context Menu Key (PC Keyboard Only) |

These shortcuts are for toggling certain function modes. You can disable these shortcuts in vChewing Preferences:

| Shortcuts | Function Modes |
|-:|-|
| ⌃⇧⌘ P | Per-character selection mode (i.e. SCPC mode). |
| ⌃⇧⌘ K | Revolve Kanji Conversion (Modern Trad. / KangXi / JIS; only effective in Traditional Chinese output mode). |
| ⌃⇧⌘ O | Associated phrases mode (only usable in SCPC mode). |
| ⌃⇧⌘ J | Pinyin / Zhuyin Typing Mode Switch. |
| ⌃⇧⌘ L | CNS+GBEX mode (some candidates will be shown as blanks unless you install CNS / GBEX fonts separately). |
| ⌃⇧⌘ H | Half-width punctuation mode. |
| ⌃⇧⌘ M | Currency numeral output. This converts "一二" to "壹貳". |
| ⌃⇧⌘ I | CIN cassette mode. |
| ⌃⇧⌘ D | CHS / CHT Input Mode Switch. |

These shortcuts are available for serving basic typing functions:

| Shortcuts | Functions | Notes |
|-:|-|-|
| ⏎ | Commit everything in the inline composition buffer. | Requiring that ICB is not empty and the IME is not in marking state. |
| ⇧⏎ | Commit everything first, then attempt to call associated phrases using the front node data. | This won't work with SCPC mode which calls associated phrases in a different way. |
| ⌥⇧⏎ | Commit everything in the inline composition buffer with all chars separated by an ASCII space. | Requiring that ICB is not empty. |
| ⌥→<br />⌥← | Push cursor forward by node.<br />Pull cursor back by node. | Requiring that ICB is not empty;<br />⌥→ / ⌥← when horizontal typing, ⌥↓ / ⌥↑ when vertical typing. |
| JIS Eisu | Toggling Alphanumerical Input Mode. | Only JIS keyboard has this key. |
| ⇧↑<br />⇧↓ | Revolve candidates clockwise.<br />Revolve candidates counter-clockwise. | Requiring that ICB is not empty. |
| ⌃⌘]<br />⌃⌘[ | Revolve candidates clockwise.<br />Revolve candidates counter-clockwise. | Requiring that ICB is not empty. |
| ☰<br />⇧☰ | Revolve candidates clockwise.<br />Revolve candidates counter-clockwise. | Requiring that ICB is not empty. |
| ⌥↑<br />⌥↓ | Revolve candidates clockwise.<br />Revolve candidates counter-clockwise. | Requiring that ICB is not empty;<br />⌥↑ / ⌥↓ when horizontal typing, ⌥← / ⌥→ when vertical typing. |
| ⇧ ␣<br />⇧⌘ ␣ | Revolve candidates clockwise.<br />Revolve candidates counter-clockwise. | The same as above, but optimized for single-hand operation: you can swipe your thumb from ⌘ to ␣ key. |
| ⇥<br />⇧⇥ | Revolve candidates clockwise.<br />Revolve candidates counter-clockwise. | The same as above by default, can be changed for calling candidate window (in vChewing Preferences). Has compatibility issues with Facebook which intercepts the Tab key. |
| ⌥⌃→<br />⌥⌃← | Push cursor to the front edge of the ICB.<br />Pull cursor to the tail of the ICB. | Requiring that ICB is not empty;<br />⌥⌃→ / ⌥⌃← when horizontal typing, ⌥⌃↓ / ⌥⌃↑ when vertical typing. |
| ↘︎<br />↖︎ | Push cursor to the front edge of the ICB.<br />Pull cursor to the tail of the ICB. | As above. |
| ⇧→<br />⇧← | Control the marking range in the ICB.<br />After that, you can do further operations prompted on the screen. | Requiring that ICB is not empty;<br />When there are things marked, the input method turns into Marking State. |
| ⏎ | Dump the marked range (reading-phrase pair) into user dictionary. If the pair already exists, this operation will boost its score weight. | Only works in marking state. |
| ⇧⌘⏎ | Nerf the marked existing reading-phrase pair with a negative score of -114.514. | Only works in marking state;<br />Nerfed weight (score) is saved in user dictionary;<br />Not effective with user associated phrases. |
| ⌫<br />⌦ | Dump the marked existing reading-phrase pair into the user phrase filter list. vChewing omits all pairs "on the list" when querying candidates from dictionary. | Only works in marking state;<br />Not effective with user associated phrases. |
| ⇧⌦ | Clear the entire ICB. | Requiring that ICB is not empty and the IME is not in marking state. |
| ⇧⌫ | Disassembly the previous reading (i.e. the reading at the rear of the cursor) and remove its intonation. Will remove the previous reading if it is not able to be disassembled. | Requiring that ICB is not empty and the IME is not in marking state.<br />Its behavior can be specified in vChewing Preferences. |
| Intonation key | Attempt to disassembly the previous reading (i.e. the reading at the rear of the cursor), remove its intonation, and override its intonation with the intonation key pressed. Will insert standalone intonation mark if previous reading doesn't exist or is not able to be disassembled. | Requiring that ICB is not empty and the IME is not in marking state.<br />Its behavior can be specified in vChewing Preferences. |
| ⌃⌥⌘⏎ | Commit content according to the「Command+Option+Ctrl+Enter:」option in the Behavior pane. Default: «Commit Bracketed Annotation»; other options include «Commit HTML Ruby Annotation», Braille, ButKo BPMFVS annotation, etc. | Requiring that ICB is not empty;<br />With a Braille option selected, the cassette mode always commits the bracketed annotation;<br />Holding Shift commits only the pronunciation string. |
| ⌃⌘⏎ | Dump the current ICB to pronunciation string thread. All intonations are written at last. If Hanyu-Pinyin, intonations are numerals. | Requiring that ICB is not empty;<br />One can specify whether it dumps Hanyu-Pinyin or Phonabets;<br />All readings are joined with ASCII half-width spaces by default. |
| ⌃⇧⌘⏎ | Dump the current ICB to pronunciation string thread. All intonations are written at last. If Hanyu-Pinyin, intonations are numerals. | Requiring that ICB is not empty;<br />One can specify whether it dumps Hanyu-Pinyin or Phonabets;<br />All readings are joined with ASCII half-width hyphens. |
| ⇧ ␣ | Type full-width space when the ICB is empty. | Can be press-and-hold for consecutive inputs. |
| Hold ⌥⇧<br />and type Number Keys | Type full-width Arabic numbers. | Will output half-width Arabic numbers instead if the IME is in half-width punctuation mode. |
| Hold ⌥<br />and type Number Keys | Type half-width Arabic numbers. | |
| ～ | Categorized symbol menu. It can be customized by creating your own "symbols.dat" file in libchewing symbol format and save it into your user dictionary folder. | JIS keyboards have to use the "_" key (to the left of your right-hand ⇧ key) instead since they don't have a "～" key. |
| ⌥ ～ | Tap once to switch to code point input mode;<br />tap once again to switch to Hanin keyboard symbol mode. | These input modes can be turned off by pressing Enter / Esc / Delete. |
| ⌥⇧ ～ | Non-categorized symbol menu, customizable in user phrases. | JIS keyboards have to use the "_" key (to the left of your right-hand ⇧ key) instead since they don't have a "～" key. |
| ⇞<br />⇟ | Call candidate window. | Requiring that ICB is not empty.<br />Candidate window automatically appears in SCPC mode. |
| ␣ | Call candidate window. | As above but can be disabled in vChewing Preferences. |
| ⎋ | Clear the entire ICB if not in marking state.<br />Quit the marking state if in the marking state. | Its behavior (when not in marking state) can be disabled in vChewing Preferences; if so, it will only clear the unfinished pronunciation in the PCB. |
| Left⇧<br />Right⇧ | Toggle alphanumerical input mode. | Can be disabled in vChewing Preferences. |
| ⌥⌦<br />⌥⌫ | Perform Delete / BackSpace for each phrase node.<br />⌥⌫ will clean unfinished readings / strokes first. | Requiring that ICB is not empty and the IME is not in marking state. |
| ⌃⌘/ | Call the Zhuyin reverse-lookup window. | Can be disabled in vChewing Preferences (enabled by default). |
| ⇧ + Candidate Key | Choose the highlighted candidate in the copilot candidate window. | Only effective when Furious Pinyin or Furious Zhuyin is enabled and the copilot candidate window is shown; without Shift, the candidate key types its own character as usual. |
| ↑ ↓ ← → | Solidify the unfinished reading and open the standard candidate window, in which the arrow keys then move the highlight among candidates. | Only effective when Furious Typing is enabled and the copilot candidate window is shown (not with any ⌃ / ⌥ / ⌘ combination). |
| ⇧ + ↑ ↓ ← → | Solidify the pending reading first, then perform range marking as usual. | Same as above; the PCB is emptied once the solidification succeeds. |
| Tab<br />⏎ | Solidify the pending reading. | Used in Furious Typing to confirm the current syllable (for Furious Zhuyin, the Space key stays the First Tone key and does not serve this purpose). |
| F1 ～ F20 | Input nothing. | While the ICB (including the PCB) still holds uncommitted content, these keys are intercepted in place by the input method with a beep, so that unfinished readings are not lost and you don't mistake the keys for being broken; when there is nothing uncommitted, they are always passed through to the system (hence the system functions of F1～F20 themselves are unaffected).<br />System hotkeys such as `Fn` + a letter (e.g. the emoji picker `Fn+E`) are unaffected by this behavior. |

The following shortcuts are usable when **the default Tadokoro Candidate Window** is shown up:

| Shortcuts | Functions | Notes |
|-:|-|-|
| ⏎ | Confirm the highlighted candidate. | Can be disabled (in vChewing preferences) for associated phrase candidates. |
| ⇧⏎ | Commit everything first, then attempt to call associated phrases using the highlighted candidate as index data.<br />If it is able to call the associated phrases, the current ICB will be committed first. | Associates require that the cursor must be situated in the most-front.<br />This won't work with SCPC mode which calls associated phrases in a different way. |
| ⌃⌘]<br />⌃⌘[ | Highlight the next candidate.<br />Highlight the previous candidate. | |
| ⇥<br />⇧⇥ | Highlight the next candidate.<br />Highlight the previous candidate. | Can be redesignated in vChewing Preferences for revolving pages with exception:<br />It only revolves through candidates when there's only one page. |
| ␣<br />⇧ ␣ | Revolve pages or candidates clockwise, according to its settings in vChewing Preferences. | It revolves through candidates when there is only one page. |
| ⇞<br />⇟ | Flip pages. | It revolves through candidates when there is only one page. |
| ↖︎<br />↘︎ | Choose the total first candidate.<br />Choose the total last candidate. | It buzzes / farts for unnecessary operations. |
| ⎋<br />⌫<br />⌦<br />⇧→<br />⇧← | Back to the previous symbol menu level. If not available, closes the candidate window. | It always closes the candidate window if not in the symbol menu state.<br />Among them, the Esc key may close the Spotlight window. |
| Hold ⇧<br />and type Candidate Keys | Choose a designated associated phrase candidate (with an on-screen hint). | Same behavior as Yahoo! KeyKey. |
| ⌥→<br />⌥← | Moving the cursor in the ICB by nodes while keeping the candidate window open. | ⌥→ / ⌥← when horizontal typing, ⌥↓ / ⌥↑ when vertical typing. |
| ⇧⌥→<br />⇧⌥← | Moving the cursor in the ICB by span while keeping the candidate window open. | ⇧⌥→ / ⇧⌥← when horizontal typing, ⇧⌥↓ / ⇧⌥↑ when vertical typing;<br />If the cursor cuts a character after the movement, the cursor will keep on moving to the edge of the current node. |

$ EOF.
