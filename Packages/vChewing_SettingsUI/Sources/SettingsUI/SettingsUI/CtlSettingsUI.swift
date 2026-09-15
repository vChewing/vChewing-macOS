// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

// 本檔為 SwiftUI 專屬，legacy 倉庫（＝本倉的「子集 ＋ Swift 5.10 Dialect」，砍掉了 SwiftUI）無對位模組可繼承；
// 依「SwiftUI 之任何內容不得裸露於 5.10 可編的路徑上」整段圈進 compiler condition，<6.2 分支不提供替代實作。
#if compiler(>=6.2)

  import SwiftUI

  // MARK: - CtlSettingsUI

  // InputMethodServerPreferencesWindowControllerClass 非必需。

  @available(macOS 14, *)
  public final class CtlSettingsUI: NSWindowController, NSWindowDelegate {
    // MARK: Lifecycle

    nonisolated deinit {
      #if DEBUG
        NSLog("[CtlSettingsUI] deinit called")
      #endif
    }

    public init() {
      super.init(
        window: .init(
          contentRect: CGRect(x: 401, y: 295, width: 758, height: Self.contentMaxHeight),
          styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
          backing: .buffered,
          defer: true
        )
      )
      window?.titlebarAppearsTransparent = false
    }

    required init?(coder: NSCoder) {
      super.init(coder: coder)
    }

    // MARK: Public

    public static var shared: CtlSettingsUI?

    override public func windowDidLoad() {
      super.windowDidLoad()
      let viewModel = SettingsUIViewModel()
      window?.contentView = NSHostingView(
        rootView: VwrSettingsUI()
          .environment(viewModel)
          .ignoresSafeArea()
      )
      var preferencesTitleName = "i18n:Menu.vChewingSettings".i18n
      preferencesTitleName.removeLast()
      window?.title = preferencesTitleName
      asyncOnMain { [weak self] in
        self?.window?.setPosition(vertical: .top, horizontal: .right, padding: 20)
      }
    }

    override public func close() {
      // 由於我們使用靜態 `shared` 變數保留 window controller，
      // 因此每次關閉都要把它清掉，無論 CPU 架構為何。
      // 另外必須把 contentView 從 window 抽離，
      // 否則它會被 NSWindow 仍然持有，導致記憶體不會即時回收。
      autoreleasepool {
        // 先行斷開 delegate 與內容，避免循環引用
        window?.delegate = nil
        // 此舉抽離 contentView。
        window?.contentView = nil
        // 立即釋放語彙編輯器共享的程序級文字暫存，不依賴 onDisappear 時序。
        VwrPhraseEditorUI.txtContentStorage = ""
        super.close()
        Self.shared = nil
      }
    }

    @objc
    public static func show() {
      // 避免在先前已關閉視窗的 controller 上誤觸復活；
      // `shared` 會在 `close()` 或下方的 `windowWillClose(_:)`
      // 中被清空。
      autoreleasepool {
        if shared == nil {
          let newInstance = CtlSettingsUI()
          shared = newInstance
        }
        guard let shared = shared, let sharedWindow = shared.window else { return }
        sharedWindow.delegate = shared
        if !sharedWindow.isVisible {
          shared.windowDidLoad()
        }
        sharedWindow.setPosition(vertical: .top, horizontal: .right, padding: 20)
        // 單元測試／診斷宿主（pendingUnitTests）下略過「強制置前＋強迫視窗層級」，
        // 避免測試或 Instruments 錄製期間視窗搶焦點。
        if !UserDefaults.pendingUnitTests {
          sharedWindow.orderFrontRegardless() // 逼著視窗往最前方顯示
          sharedWindow.level = .statusBar
        }
        shared.showWindow(shared)
        if !UserDefaults.pendingUnitTests {
          NSApp.popup()
        }
      }
    }

    // MARK: - NSWindowDelegate helpers

    public func windowWillClose(_ notification: Notification) {
      // 使用者按紅色關閉按鈕或 ⌘W 時走的是這條路徑，
      // 不會觸發 NSWindowController.close() override，
      // 因此必須在此處做同等的清理。
      window?.delegate = nil
      window?.contentView = nil
      // 立即釋放語彙編輯器共享的程序級文字暫存，不依賴 onDisappear 時序。
      VwrPhraseEditorUI.txtContentStorage = ""
      Self.shared = nil
    }
  }

  // MARK: - Shared Static Variables and Constants

  @available(macOS 14, *)
  extension CtlSettingsUI {
    public static let sentenceSeparator: String = {
      switch PrefMgr.shared.appleLanguages[0] {
      case "ja":
        return ""
      default:
        if PrefMgr.shared.appleLanguages[0].contains("zh-Han") {
          return ""
        } else {
          return " "
        }
      }
    }()

    public static let contentMaxHeight: Double = 650

    public static let formWidth: Double = 614

    public static var isCJKInterface: Bool {
      PrefMgr.shared.appleLanguages[0].contains("zh-Han") || PrefMgr.shared.appleLanguages[0] == "ja"
    }
  }

  @available(macOS 10.15, *)
  extension View {
    public func settingsDescription(maxWidth: CGFloat? = .infinity) -> some View {
      controlSize(.small)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: maxWidth, alignment: .leading)
        // TODO: Use `.foregroundStyle` when targeting macOS 12.
        .foregroundColor(.secondary)
    }
  }

  @available(macOS 10.15, *)
  extension View {
    public func formStyled() -> some View {
      if #available(macOS 14, *) { return self.formStyle(.grouped) }
      return padding()
    }
  }

#endif
