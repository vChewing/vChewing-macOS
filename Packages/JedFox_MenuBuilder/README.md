# MenuBuilder

A function builder for `NSMenu`s, similar in spirit to SwiftUI’s `ViewBuilder`.

Usage example (see demo or [read the documentation](https://menubuilder.jedfox.com) for more details):

```swift
let menu = NSMenu {
  MenuItem("Click me")
    .onSelect { print("clicked!") } 
  MenuItem("Item with a view")
    .view {
      MyMenuItemView() // any SwiftUI view
    }
  SeparatorItem()
  MenuItem("About") {
    // rendered as disabled items in a submenu
    MenuItem("Version 1.2.3")
    MenuItem("Copyright 2021")
  }
  MenuItem("Quit")
    .shortcut("q")
    .onSelect { NSApp.terminate(nil) }
}

// later, to replace the menu items with different/updated ones:
menu.replaceItems {
  MenuItem("Replaced item").onSelect { print("Hello!") }
}
```

Note that there is no way to preserve the existing menu items, although it should be possible to implement that — feel free to open an issue or PR adding update support if you want it!

## Changelog

### v2.0.0
* (**BREAKING**) Migrate to `@resultBuilder` (Xcode 12.5+ is now required)
* Apply modifiers to shortcuts
* Add a `MenuItem.set(WriteableKeyPath, to: Value)` method to make it easier to customize the menu item
* Add a `MenuItem.apply { menuItem in }` method to allow arbitrary customization of the menu item
* Add `IndentGroup` to make it easier to indent several adjacent menu items
* Add `CustomMenuItem` which allows you to include custom subclasses of `NSMenuItem` in a `MenuBuilder`

### v1.3.0

Fixes & cleanup

### v1.2.0

Add loop support

### v1.1.0

Add conditional support

### v1.0.1

Add license, clean up code

### v1.0.0

Initial version!


## Contributing

Open the `MenuBuilder.xcworkspace` to view the package and demo at the same time. PRs and issues are appreciated!
