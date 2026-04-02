import Foundation

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
    "/opt/homebrew/bin/sketchybar --reload; launchctl kickstart -k gui/$(id -u)/homebrew.mxcl.borders 2>/dev/null"
  ]
  task.launch()
}

RunLoop.main.run()
