import AppKit
import SwiftUI
import os

/// Owns the floating cheat sheet window and keeps it on the active layer.
///
/// The diagram is one keymap-drawer SVG with every layer in it, read from a
/// local file or downloaded from a link. Nothing is loaded while the window
/// is closed. A local file is reloaded when its modification date changes; a
/// download is repeated when the window opens or the keyboard reports a
/// different firmware build.
@MainActor
final class CheatSheetController {
  private static let logger = Logger(subsystem: "com.johncattrall.zmkstatbar", category: "CheatSheet")

  private var panel: NSPanel?
  private let model = CheatSheetModel()

  private var setting = ""
  private var layerName: String?
  private var buildID: String?

  private var loadedSource: KeymapDiagram.Source?
  private var loadedFileDate: Date?
  private var loadedBuildID: String?
  private var svg: String?
  private var loadError: String?
  private var loadTask: Task<Void, Never>?

  var isOpen: Bool { panel?.isVisible ?? false }

  func toggle() {
    if isOpen {
      panel?.orderOut(nil)
    } else {
      show()
    }
  }

  private func show() {
    if panel == nil {
      let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 640, height: 300),
        styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
        backing: .buffered,
        defer: false
      )
      panel.title = "Cheat Sheet"
      panel.isFloatingPanel = true
      panel.level = .floating
      panel.hidesOnDeactivate = false
      panel.isReleasedWhenClosed = false
      panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
      panel.contentView = NSHostingView(rootView: CheatSheetView(model: model))
      if !panel.setFrameUsingName("ZMKStatbarCheatSheet") {
        panel.center()
      }
      panel.setFrameAutosaveName("ZMKStatbarCheatSheet")
      self.panel = panel
    }
    panel?.orderFrontRegardless()
    // Opening the window is the moment to pick up a newly pushed diagram.
    if case .remote = loadedSource { loadedSource = nil }
    refresh()
  }

  /// Called whenever the layer, the diagram setting or the firmware build
  /// changes.
  func update(layerName: String?, setting: String, buildID: String?) {
    self.layerName = layerName
    self.setting = setting
    self.buildID = buildID
    if isOpen {
      refresh()
    }
  }

  private func refresh() {
    model.layerName = layerName ?? ""
    guard let source = KeymapDiagram.source(from: setting) else {
      cancelLoad()
      svg = nil
      loadedSource = nil
      show(message: setting.trimmingCharacters(in: .whitespaces).isEmpty
        ? "Choose your keymap-drawer SVG under Keymap Diagram in the menu."
        : "The keymap diagram setting is not a file path or a web link.")
      return
    }
    switch source {
    case .file(let url):
      loadFileIfChanged(url, source: source)
    case .remote(let url):
      if loadedSource != source || loadedBuildID != buildID {
        download(url, source: source)
        return
      }
    }
    render()
  }

  private func loadFileIfChanged(_ url: URL, source: KeymapDiagram.Source) {
    let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    guard loadedSource != source || date != loadedFileDate else { return }
    cancelLoad()
    loadedSource = source
    loadedFileDate = date
    if let text = try? String(contentsOf: url, encoding: .utf8), text.contains("<svg") {
      svg = text
      loadError = nil
    } else {
      svg = nil
      loadError = "Could not read \(url.lastPathComponent) as an SVG."
    }
  }

  private func download(_ url: URL, source: KeymapDiagram.Source) {
    cancelLoad()
    if loadedSource != source {
      svg = nil
      loadError = nil
    }
    loadedSource = source
    loadedBuildID = buildID
    if svg == nil { show(message: "Loading...") }
    loadTask = Task { [weak self] in
      do {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard !Task.isCancelled, let self else { return }
        if (response as? HTTPURLResponse)?.statusCode == 200,
           let text = String(data: data, encoding: .utf8), text.contains("<svg") {
          self.svg = text
          self.loadError = nil
        } else {
          self.svg = nil
          self.loadError = "No SVG at that link. Private repositories need a local file instead."
        }
        self.render()
      } catch {
        guard !Task.isCancelled, let self else { return }
        Self.logger.error("Diagram download failed: \(error.localizedDescription, privacy: .public)")
        // Keep showing the previous diagram if there is one. Opening the
        // window again retries.
        if self.svg == nil { self.loadError = "Could not download the diagram." }
        self.render()
      }
    }
  }

  private func render() {
    if let loadError, svg == nil {
      show(message: loadError)
      return
    }
    guard let svg else { return }
    guard let layerName, !layerName.isEmpty else {
      show(message: "Waiting for the keyboard's layer.")
      return
    }
    switch KeymapDiagram.svg(svg, forLayer: layerName) {
    case .layer(let cropped):
      model.svg = cropped
      model.message = nil
    case .whole(let whole):
      model.svg = whole
      model.message = nil
    case .notFound(let available):
      show(message: "No \"\(layerName)\" layer in this diagram. It has: \(available.joined(separator: ", ")).")
    }
  }

  private func show(message: String) {
    model.svg = nil
    model.message = message
  }

  private func cancelLoad() {
    loadTask?.cancel()
    loadTask = nil
  }
}
