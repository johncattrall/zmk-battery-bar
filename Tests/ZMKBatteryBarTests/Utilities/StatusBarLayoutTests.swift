import Testing

@testable import ZMKBatteryBar

@Suite("StatusBarLayout")
struct StatusBarLayoutTests {
  @Test(
    "digitCount across ranges",
    arguments: [
      (Int?.none, 2),
      (.some(0), 1),
      (.some(1), 1),
      (.some(9), 1),
      (.some(10), 2),
      (.some(99), 2),
      (.some(100), 3),
    ]
  )
  func digitCountCases(level: Int?, expected: Int) {
    #expect(StatusBarLayout.digitCount(for: level) == expected)
  }

  @Test("batteries can be hidden only while a layer is shown")
  func showsBatteries() {
    let layer = LayerDisplayResolver.Display(current: "Base", currentLocked: false, badges: [])
    let withLayer = StatusBarLayerInfo(layer: layer)
    let capsOnly = StatusBarLayerInfo(capsLock: true)
    #expect(StatusBarLayout.showsBatteries(setting: true, layerInfo: withLayer))
    #expect(!StatusBarLayout.showsBatteries(setting: false, layerInfo: withLayer))
    #expect(StatusBarLayout.showsBatteries(setting: false, layerInfo: nil))
    #expect(StatusBarLayout.showsBatteries(setting: false, layerInfo: capsOnly))
  }
}
