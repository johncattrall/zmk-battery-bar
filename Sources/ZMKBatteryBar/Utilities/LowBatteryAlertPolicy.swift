import Foundation

/// Decides when to raise a low-battery alert for one keyboard half.
///
/// Alerts fire once per drop below the threshold. The alert re-arms only
/// after the level climbs `rearmMargin` points above the threshold, so a
/// reading that jitters around the threshold cannot alert repeatedly.
enum LowBatteryAlertPolicy {
  static let rearmMargin = 5

  struct Result: Equatable {
    let shouldAlert: Bool
    let armed: Bool
  }

  static func evaluate(level: Int?, threshold: Int, armed: Bool) -> Result {
    guard let level else { return Result(shouldAlert: false, armed: armed) }
    if armed && level <= threshold {
      return Result(shouldAlert: true, armed: false)
    }
    if !armed && level >= threshold + rearmMargin {
      return Result(shouldAlert: false, armed: true)
    }
    return Result(shouldAlert: false, armed: armed)
  }
}
