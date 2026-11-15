import Foundation

/// Builds the URL of a per-layer keymap diagram from a user template.
///
/// The template contains `{layer}`, replaced by a slug of the layer name:
/// lowercase, with every run of non-alphanumeric characters turned into a
/// single hyphen. This matches the file names keymap-drawer CI setups
/// commonly produce, e.g. "Nav/Num" -> "nav-num".
enum LayerDiagramURL {
  static let placeholder = "{layer}"

  static func slug(for layerName: String) -> String {
    var result = ""
    var pendingHyphen = false
    for scalar in layerName.lowercased().unicodeScalars {
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

  static func url(template: String, layerName: String) -> URL? {
    let trimmed = template.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.contains(placeholder) else { return nil }
    let slug = slug(for: layerName)
    guard !slug.isEmpty else { return nil }
    let urlString = trimmed.replacingOccurrences(of: placeholder, with: slug)
    guard let url = URL(string: urlString), let scheme = url.scheme?.lowercased(),
          scheme == "https" || scheme == "http"
    else { return nil }
    return url
  }
}
