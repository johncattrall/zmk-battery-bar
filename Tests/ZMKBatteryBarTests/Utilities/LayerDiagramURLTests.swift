import Foundation
import Testing

@testable import ZMKBatteryBar

@Suite("LayerDiagramURL")
struct LayerDiagramURLTests {
  @Test(
    "slugs match keymap-drawer style file names",
    arguments: [
      ("Base", "base"),
      ("Nav/Num", "nav-num"),
      ("Media/Win", "media-win"),
      ("NumPad", "numpad"),
      ("  Sym & Fn  ", "sym-fn"),
    ]
  )
  func slug(name: String, expected: String) {
    #expect(LayerDiagramURL.slug(for: name) == expected)
  }

  @Test("fills the template")
  func fillsTemplate() {
    let url = LayerDiagramURL.url(
      template: "https://example.com/keymap-drawer/crosses_{layer}.svg",
      layerName: "Nav/Num")
    #expect(url?.absoluteString == "https://example.com/keymap-drawer/crosses_nav-num.svg")
  }

  @Test("rejects templates without a placeholder or with a non-web scheme")
  func rejectsInvalid() {
    #expect(LayerDiagramURL.url(template: "https://example.com/a.svg", layerName: "Base") == nil)
    #expect(LayerDiagramURL.url(template: "file:///tmp/{layer}.svg", layerName: "Base") == nil)
    #expect(LayerDiagramURL.url(template: "", layerName: "Base") == nil)
    #expect(LayerDiagramURL.url(template: "https://e.com/{layer}.svg", layerName: "///") == nil)
  }
}
