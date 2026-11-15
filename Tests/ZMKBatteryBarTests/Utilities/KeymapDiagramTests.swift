import Foundation
import Testing

@testable import ZMKBatteryBar

@Suite("KeymapDiagram")
struct KeymapDiagramTests {
  /// Shaped like keymap-drawer output: one root SVG, one group per layer.
  static let combined = """
    <svg width="1590" height="960" viewBox="0 0 795 960" class="keymap" xmlns="http://www.w3.org/2000/svg">
    <style>rect.key { fill: #f6f8fa; }</style>
    <g transform="translate(30, 0)" class="layer-Base">
    <g transform="translate(0, 56)"><rect class="key"/></g>
    </g>
    <g transform="translate(30, 320)" class="layer-Nav/Num">
    <rect class="key"/>
    </g>
    <g transform="translate(30, 641)" class="layer-Sym &amp; Fn">
    <rect class="key"/>
    </g>
    </svg>
    """

  // MARK: Source

  @Test("local paths and file URLs are files")
  func fileSources() {
    #expect(KeymapDiagram.source(from: "/tmp/crosses.svg") == .file(URL(fileURLWithPath: "/tmp/crosses.svg")))
    #expect(KeymapDiagram.source(from: "file:///tmp/a.svg") == .file(URL(string: "file:///tmp/a.svg")!))
    if case .file(let url) = KeymapDiagram.source(from: "~/a.svg") {
      #expect(!url.path.contains("~"))
    } else {
      Issue.record("tilde path was not treated as a file")
    }
  }

  @Test("GitHub page links become raw links")
  func githubLinks() {
    let blob = KeymapDiagram.source(
      from: " https://github.com/me/zmk-config/blob/main/keymap-drawer/crosses.svg ")
    #expect(blob == .remote(URL(string: "https://raw.githubusercontent.com/me/zmk-config/main/keymap-drawer/crosses.svg")!))
    let raw = KeymapDiagram.source(from: "https://raw.githubusercontent.com/me/c/main/a.svg")
    #expect(raw == .remote(URL(string: "https://raw.githubusercontent.com/me/c/main/a.svg")!))
    let other = KeymapDiagram.source(from: "https://example.com/a.svg")
    #expect(other == .remote(URL(string: "https://example.com/a.svg")!))
  }

  @Test("empty or unsupported settings have no source")
  func noSource() {
    #expect(KeymapDiagram.source(from: "") == nil)
    #expect(KeymapDiagram.source(from: "   ") == nil)
    #expect(KeymapDiagram.source(from: "ftp://example.com/a.svg") == nil)
    #expect(KeymapDiagram.source(from: "crosses.svg") == nil)
  }

  // MARK: Parsing

  @Test("finds layers with their offsets and unescaped names")
  func parsesLayers() {
    let layers = KeymapDiagram.layers(in: Self.combined)
    #expect(layers.map(\.name) == ["Base", "Nav/Num", "Sym & Fn"])
    #expect(layers.map(\.y) == [0, 320, 641])
    #expect(layers.allSatisfy { $0.x == 30 })
  }

  @Test("reads the root viewBox")
  func parsesViewBox() {
    #expect(KeymapDiagram.viewBox(in: Self.combined)
      == KeymapDiagram.ViewBox(minX: 0, minY: 0, width: 795, height: 960))
    #expect(KeymapDiagram.viewBox(in: #"<svg width="100" height="50">"#)
      == KeymapDiagram.ViewBox(minX: 0, minY: 0, width: 100, height: 50))
  }

  @Test("matches layer names loosely")
  func matchesNames() {
    let layers = KeymapDiagram.layers(in: Self.combined)
    #expect(KeymapDiagram.matchLayer("Nav/Num", in: layers)?.y == 320)
    #expect(KeymapDiagram.matchLayer("nav/num", in: layers)?.y == 320)
    #expect(KeymapDiagram.matchLayer("NAV NUM", in: layers)?.y == 320)
    #expect(KeymapDiagram.matchLayer("Mouse", in: layers) == nil)
  }

  @Test("a layer runs to the next layer, the last to the edge")
  func regions() {
    let layers = KeymapDiagram.layers(in: Self.combined)
    let box = KeymapDiagram.ViewBox(minX: 0, minY: 0, width: 795, height: 960)
    #expect(KeymapDiagram.region(of: layers[0], among: layers, in: box)
      == KeymapDiagram.ViewBox(minX: 0, minY: 0, width: 795, height: 320))
    #expect(KeymapDiagram.region(of: layers[2], among: layers, in: box)
      == KeymapDiagram.ViewBox(minX: 0, minY: 641, width: 795, height: 319))
  }

  @Test("columns split the width")
  func columnRegions() {
    let layers = [
      KeymapDiagram.Layer(name: "A", x: 30, y: 0),
      KeymapDiagram.Layer(name: "B", x: 430, y: 0),
      KeymapDiagram.Layer(name: "C", x: 30, y: 300),
    ]
    let box = KeymapDiagram.ViewBox(minX: 0, minY: 0, width: 800, height: 600)
    #expect(KeymapDiagram.region(of: layers[0], among: layers, in: box)
      == KeymapDiagram.ViewBox(minX: 0, minY: 0, width: 400, height: 300))
    #expect(KeymapDiagram.region(of: layers[1], among: layers, in: box)
      == KeymapDiagram.ViewBox(minX: 400, minY: 0, width: 400, height: 600))
  }

  // MARK: Rendering

  @Test("crops the root to the layer and drops the fixed size")
  func cropsToLayer() {
    guard case .layer(let svg) = KeymapDiagram.svg(Self.combined, forLayer: "Nav/Num") else {
      Issue.record("expected a cropped layer")
      return
    }
    let root = svg.prefix(while: { $0 != ">" })
    #expect(root.contains(#"viewBox="0 320 795 321""#))
    #expect(!root.contains("width="))
    #expect(!root.contains("height="))
    #expect(root.contains(#"class="keymap""#))
    #expect(svg.contains("<style>"))
  }

  @Test("reports available layers when there is no match")
  func notFound() {
    #expect(KeymapDiagram.svg(Self.combined, forLayer: "Mouse")
      == .notFound(available: ["Base", "Nav/Num", "Sym & Fn"]))
  }

  @Test("an SVG without layer groups is shown whole")
  func wholeSVG() {
    let plain = #"<svg viewBox="0 0 10 10"><rect/></svg>"#
    #expect(KeymapDiagram.svg(plain, forLayer: "Base") == .whole(plain))
  }
}
