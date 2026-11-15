import Foundation

/// Pure helpers for the cheat sheet: where the keymap diagram comes from, and
/// how to show a single layer of it.
///
/// keymap-drawer draws every layer into one SVG and wraps each layer in
/// `<g transform="translate(x, y)" class="layer-<name>">`, using the same
/// layer names the keyboard reports. Showing one layer is therefore a matter
/// of pointing the root `viewBox` at that layer's region; the other layers
/// fall outside it and are clipped. No per-layer files are needed.
enum KeymapDiagram {
  enum Source: Equatable {
    case file(URL)
    case remote(URL)
  }

  struct Layer: Equatable {
    var name: String
    var x: Double
    var y: Double
  }

  struct ViewBox: Equatable {
    var minX: Double
    var minY: Double
    var width: Double
    var height: Double
  }

  // MARK: - Source

  /// Interprets the user's setting: a local path (absolute or `~/...`), a
  /// `file://` URL, or an http(s) link. GitHub page links are rewritten to
  /// their raw file URL.
  static func source(from setting: String) -> Source? {
    let trimmed = setting.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    if trimmed.hasPrefix("/") || trimmed.hasPrefix("~") {
      let path = (trimmed as NSString).expandingTildeInPath
      return .file(URL(fileURLWithPath: path))
    }
    guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() else { return nil }
    switch scheme {
    case "file":
      return .file(url)
    case "http", "https":
      return .remote(rawURL(for: url))
    default:
      return nil
    }
  }

  /// `https://github.com/o/r/blob/<ref>/<path>` (or `/raw/`) becomes
  /// `https://raw.githubusercontent.com/o/r/<ref>/<path>`, since GitHub page
  /// links return HTML rather than the SVG. Other URLs are returned as is.
  static func rawURL(for url: URL) -> URL {
    guard let host = url.host?.lowercased(), host == "github.com" || host == "www.github.com"
    else { return url }
    let parts = url.path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
    guard parts.count >= 5, parts[2] == "blob" || parts[2] == "raw" else { return url }
    let rest = ([parts[0], parts[1]] + parts[3...]).joined(separator: "/")
    return URL(string: "https://raw.githubusercontent.com/\(rest)") ?? url
  }

  // MARK: - Parsing

  /// Layer groups in document order.
  static func layers(in svg: String) -> [Layer] {
    let tags = matches(of: #"<g\b[^>]*\bclass="layer-([^"]*)"[^>]*>"#, in: svg)
    return tags.map { match in
      let tag = match[0]
      let name = unescape(match[1])
      var x = 0.0
      var y = 0.0
      if let t = matches(of: #"transform="\s*translate\(\s*(-?[\d.]+)(?:[\s,]+(-?[\d.]+))?\s*\)""#, in: tag).first {
        x = Double(t[1]) ?? 0
        y = Double(t[2]) ?? 0
      }
      return Layer(name: name, x: x, y: y)
    }
  }

  /// The root element's viewBox, or its width and height when there is none.
  static func viewBox(in svg: String) -> ViewBox? {
    guard let root = matches(of: #"<svg\b[^>]*>"#, in: svg).first?[0] else { return nil }
    if let vb = matches(of: #"\bviewBox="([^"]*)""#, in: root).first {
      let numbers = vb[1]
        .split(whereSeparator: { $0 == " " || $0 == "," })
        .compactMap { Double($0) }
      if numbers.count == 4 {
        return ViewBox(minX: numbers[0], minY: numbers[1], width: numbers[2], height: numbers[3])
      }
    }
    guard let w = attribute("width", in: root), let h = attribute("height", in: root) else { return nil }
    return ViewBox(minX: 0, minY: 0, width: w, height: h)
  }

  /// Finds the diagram layer for a keyboard layer name: exact match first,
  /// then case-insensitive, then ignoring punctuation and spacing.
  static func matchLayer(_ name: String, in layers: [Layer]) -> Layer? {
    if let exact = layers.first(where: { $0.name == name }) { return exact }
    let lowered = name.lowercased()
    if let match = layers.first(where: { $0.name.lowercased() == lowered }) { return match }
    let key = slug(for: name)
    guard !key.isEmpty else { return nil }
    return layers.first(where: { slug(for: $0.name) == key })
  }

  /// The region of the drawing that belongs to `layer`. Layers are stacked
  /// in columns (one column by default); a layer runs from its own offset to
  /// the next layer below it in the same column, or to the edge of the
  /// drawing.
  static func region(of layer: Layer, among layers: [Layer], in box: ViewBox) -> ViewBox {
    let minX = layers.map(\.x).min() ?? layer.x
    let nextX = layers.map(\.x).filter { $0 > layer.x }.min()
    let left = box.minX + (layer.x - minX)
    let right = nextX.map { box.minX + ($0 - minX) } ?? (box.minX + box.width)
    let nextY = layers.filter { $0.x == layer.x && $0.y > layer.y }.map(\.y).min()
    let top = layer.y
    let bottom = nextY ?? (box.minY + box.height)
    return ViewBox(minX: left, minY: top, width: max(right - left, 1), height: max(bottom - top, 1))
  }

  // MARK: - Rendering

  enum LayerResult: Equatable {
    /// The SVG cropped to the layer.
    case layer(String)
    /// The SVG has no keymap-drawer layer groups; show it whole.
    case whole(String)
    /// The SVG has layers, but none matching the name.
    case notFound(available: [String])
  }

  static func svg(_ svg: String, forLayer name: String) -> LayerResult {
    let all = layers(in: svg)
    guard !all.isEmpty else { return .whole(svg) }
    guard let layer = matchLayer(name, in: all),
          let box = viewBox(in: svg),
          let rootRange = svg.range(of: #"<svg\b[^>]*>"#, options: .regularExpression)
    else { return .notFound(available: all.map(\.name)) }

    let r = region(of: layer, among: all, in: box)
    var root = String(svg[rootRange])
    for attr in ["viewBox", "width", "height"] {
      root = root.replacingOccurrences(
        of: #"\s\#(attr)="[^"]*""#, with: "", options: .regularExpression)
    }
    let viewBox = "\(format(r.minX)) \(format(r.minY)) \(format(r.width)) \(format(r.height))"
    root = root.replacingOccurrences(
      of: #"^<svg"#, with: "<svg viewBox=\"\(viewBox)\"", options: .regularExpression)
    return .layer(svg.replacingCharacters(in: rootRange, with: root))
  }

  // MARK: - Helpers

  static func slug(for name: String) -> String {
    var result = ""
    var pendingHyphen = false
    for scalar in name.lowercased().unicodeScalars {
      if CharacterSet.alphanumerics.contains(scalar) {
        if pendingHyphen && !result.isEmpty { result.append("-") }
        pendingHyphen = false
        result.unicodeScalars.append(scalar)
      } else {
        pendingHyphen = true
      }
    }
    return result
  }

  private static func format(_ value: Double) -> String {
    value == value.rounded() ? String(Int(value)) : String(value)
  }

  private static func attribute(_ name: String, in tag: String) -> Double? {
    guard let m = matches(of: #"\b\#(name)="\s*(-?[\d.]+)"#, in: tag).first else { return nil }
    return Double(m[1])
  }

  private static func unescape(_ text: String) -> String {
    text
      .replacingOccurrences(of: "&lt;", with: "<")
      .replacingOccurrences(of: "&gt;", with: ">")
      .replacingOccurrences(of: "&quot;", with: "\"")
      .replacingOccurrences(of: "&#39;", with: "'")
      .replacingOccurrences(of: "&apos;", with: "'")
      .replacingOccurrences(of: "&amp;", with: "&")
  }

  /// All matches of `pattern`, each as [whole match, group 1, group 2, ...].
  /// Groups that did not participate are empty strings.
  private static func matches(of pattern: String, in text: String) -> [[String]] {
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
    let ns = text as NSString
    return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { result in
      (0..<result.numberOfRanges).map { i in
        let range = result.range(at: i)
        return range.location == NSNotFound ? "" : ns.substring(with: range)
      }
    }
  }
}
