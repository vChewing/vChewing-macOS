import PreferencePanes

@objc(Preferences)
public class Preferences: NSPreferencePane {
  @IBOutlet var lblDisclaimer: NSTextField!
  override public func mainViewDidLoad() {
    //      let label: NSTextField = {
    //        let result = NSTextField()
    //        result.stringValue = "114514"
    //        result.font = NSFont.systemFont(ofSize: 12)
    //        result.isEditable = false
    //        result.isSelectable = false
    //        return result
    //      }()
    //      mainView.addSubview(label)
    mainView.setFrameSize(.init(width: 420, height: 330.0))
    lblDisclaimer.sizeToFit()
    lblDisclaimer.setFrameSize(.init(width: 384.0, height: 296.0))
  }
}
