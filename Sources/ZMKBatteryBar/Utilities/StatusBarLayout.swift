import Foundation

enum StatusBarLayout {
  static func digitCount(for level: Int?) -> Int {
    level.map { String($0).count } ?? 2
  }

  /// Whether battery rows are drawn in the menu bar. They can be turned off
  /// only while a layer name is on show: otherwise the status item would be
  /// empty (and impossible to click) on keyboards without the firmware
  /// module, while disconnected, or with the layer indicator off.
  static func showsBatteries(setting: Bool, layerInfo: StatusBarLayerInfo?) -> Bool {
    setting || layerInfo?.layer == nil
  }
}
