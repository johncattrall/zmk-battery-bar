import Foundation
import Testing

@testable import ZMKBatteryBar

@Suite("LowBatteryAlertPolicy")
struct LowBatteryAlertPolicyTests {
  @Test("alerts once when dropping to the threshold")
  func alertsOnce() {
    let first = LowBatteryAlertPolicy.evaluate(level: 15, threshold: 15, armed: true)
    #expect(first == .init(shouldAlert: true, armed: false))
    let again = LowBatteryAlertPolicy.evaluate(level: 12, threshold: 15, armed: first.armed)
    #expect(again == .init(shouldAlert: false, armed: false))
  }

  @Test("re-arms only after climbing past the margin")
  func rearms() {
    #expect(LowBatteryAlertPolicy.evaluate(level: 18, threshold: 15, armed: false).armed == false)
    #expect(LowBatteryAlertPolicy.evaluate(level: 20, threshold: 15, armed: false).armed == true)
  }

  @Test("unknown level changes nothing")
  func unknownLevel() {
    #expect(LowBatteryAlertPolicy.evaluate(level: nil, threshold: 15, armed: true)
      == .init(shouldAlert: false, armed: true))
  }
}
