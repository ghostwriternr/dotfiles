import Foundation

// Listens for macOS appearance changes (Light <-> Dark) and reloads the
// userland tools whose colours need to follow the system theme:
//   - SketchyBar: status bar
//   - JankyBorders: window borders
//   - sync-pi-theme: writes ~/.pi/agent/themes/everforest.json with the
//     correct variant; pi hot-reloads the active theme file on write.
//
// The sync-pi-theme errors are swallowed (`|| true`) so a transient pi
// state (e.g. ~/.pi/ not yet created on a brand-new install) doesn't
// block sketchybar/borders from reloading.

let center = DistributedNotificationCenter.default()
center.addObserver(
  forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
  object: nil,
  queue: .main
) { _ in
  let task = Process()
  task.launchPath = "/bin/sh"
  task.arguments = [
    "-c",
    """
    /opt/homebrew/bin/sketchybar --reload; \
    launchctl kickstart -k gui/$(id -u)/homebrew.mxcl.borders 2>/dev/null; \
    "$HOME/.local/bin/sync-pi-theme" || true
    """
  ]
  task.launch()
}

RunLoop.main.run()
