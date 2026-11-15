import SwiftUI
import WebKit

/// State shown in the cheat sheet window.
@Observable
final class CheatSheetModel {
  var layerName: String = ""
  var svg: String? = nil
  var message: String? = nil
}

/// Floating window content: the active layer's keymap-drawer diagram.
struct CheatSheetView: View {
  let model: CheatSheetModel

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      if let svg = model.svg {
        // keymap-drawer already titles each layer inside the diagram.
        DiagramWebView(html: Self.html(for: svg))
      } else {
        Text(model.layerName.isEmpty ? "Keymap" : model.layerName)
          .font(.headline)
        Text(model.message ?? "Loading...")
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .padding(10)
    .frame(minWidth: 320, minHeight: 160)
  }

  /// Inline the SVG so its own styles (including keymap-drawer's dark mode
  /// media queries) apply, and scale it to the window width.
  static func html(for svg: String) -> String {
    """
    <!doctype html><html><head><meta charset="utf-8"><style>
    html, body { margin: 0; padding: 0; background: transparent; }
    svg { width: 100%; height: auto; display: block; }
    </style></head><body>\(svg)</body></html>
    """
  }
}

/// WKWebView wrapper. Diagrams are read by the app and loaded as inline HTML,
/// so a cropped layer can be shown and raw GitHub links (served as
/// text/plain) still render. JavaScript is disabled: a keymap diagram
/// never needs it.
struct DiagramWebView: NSViewRepresentable {
  let html: String

  func makeNSView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    configuration.defaultWebpagePreferences.allowsContentJavaScript = false
    let view = WKWebView(frame: .zero, configuration: configuration)
    view.setValue(false, forKey: "drawsBackground")
    return view
  }

  func updateNSView(_ view: WKWebView, context: Context) {
    guard context.coordinator.loadedHTML != html else { return }
    context.coordinator.loadedHTML = html
    view.loadHTMLString(html, baseURL: nil)
  }

  func makeCoordinator() -> Coordinator { Coordinator() }

  final class Coordinator {
    var loadedHTML = ""
  }
}
