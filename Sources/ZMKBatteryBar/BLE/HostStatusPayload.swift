import Foundation

/// Keyboard status published by the zmk-host-status firmware module.
///
/// Layer bits are by keymap index: bit `i` set means the layer at index `i`
/// is active. `lockedLayers` are active layers that stay on with no key held
/// (toggled layers, NumWord-style auto layers, timed temp layers).
struct HostStatus: Equatable {
  var activeLayers: UInt32
  var lockedLayers: UInt32
  var peripheralsConnected: Int
  var peripheralsExpected: Int
  /// v2 fields, nil when the firmware sends a v1 payload.
  var extras: Extras? = nil

  struct Extras: Equatable {
    /// Held explicit modifiers, HID bit order (LCtrl, LShift, LAlt, LGui,
    /// RCtrl, RShift, RAlt, RGui).
    var modifiers: UInt8
    /// True when the keyboard's output is USB rather than Bluetooth.
    var usbOutput: Bool
    var bleProfileConnected: Bool
    var bleProfile: Int
  }

  /// True for non-split keyboards and when every expected half is linked.
  var splitLinkUp: Bool {
    peripheralsExpected == 0 || peripheralsConnected >= peripheralsExpected
  }
}

/// Pure parsers for the zmk-host-status GATT characteristics.
enum HostStatusPayload {
  /// Status payload v1 is 12 bytes. Later versions only append fields, so a
  /// longer payload with a higher version byte is still readable.
  static let minimumStatusLength = 12
  static let v2StatusLength = 15

  static func parseStatus(from data: Data?) -> HostStatus? {
    guard let data, data.count >= minimumStatusLength else { return nil }
    let bytes = [UInt8](data)
    guard bytes[0] >= 1 else { return nil }
    func u32(at offset: Int) -> UInt32 {
      UInt32(bytes[offset])
        | UInt32(bytes[offset + 1]) << 8
        | UInt32(bytes[offset + 2]) << 16
        | UInt32(bytes[offset + 3]) << 24
    }
    var status = HostStatus(
      activeLayers: u32(at: 2),
      lockedLayers: u32(at: 6),
      peripheralsConnected: Int(bytes[10]),
      peripheralsExpected: Int(bytes[11])
    )
    if bytes[0] >= 2, bytes.count >= v2StatusLength {
      status.extras = HostStatus.Extras(
        modifiers: bytes[12],
        usbOutput: bytes[13] & 0x01 != 0,
        bleProfileConnected: bytes[13] & 0x02 != 0,
        bleProfile: Int(bytes[14])
      )
    }
    return status
  }

  /// macOS-style glyphs for held modifiers, left and right combined, in the
  /// standard macOS order: Control, Option, Shift, Command.
  static func modifierGlyphs(_ mods: UInt8) -> String {
    let ctrl = mods & 0b0001_0001 != 0
    let shift = mods & 0b0010_0010 != 0
    let alt = mods & 0b0100_0100 != 0
    let gui = mods & 0b1000_1000 != 0
    return (ctrl ? "\u{2303}" : "") + (alt ? "\u{2325}" : "")
      + (shift ? "\u{21E7}" : "") + (gui ? "\u{2318}" : "")
  }

  /// Layer names in keymap index order, newline-separated by the firmware.
  static func parseLayerNames(from data: Data?) -> [String]? {
    guard let data, !data.isEmpty,
          let text = String(data: data, encoding: .utf8)
    else { return nil }
    return text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
  }

  /// Firmware build id (git short SHA, or "local" for non-CI builds).
  static func parseBuildID(from data: Data?) -> String? {
    guard let data, let text = String(data: data, encoding: .utf8) else { return nil }
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters))
    return trimmed.isEmpty ? nil : trimmed
  }
}
