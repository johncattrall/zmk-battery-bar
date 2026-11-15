import AppKit
import SwiftUI
import os

/// Owns the floating cheat sheet window and keeps it on the active layer.
///
/// Diagrams are fetched only while the window is open, cached per URL, and
/// the cache is dropped whenever the keyboard reports a different firmware
/// build, since a new build usually means new diagrams.
@MainActor
final class CheatSheetController {
  private static let logger = Logger(subsystem: "com.johncattrall.zmkstatbar", category: "CheatSheet")

  private var panel: NSPanel?
  private let model = CheatSheetModel()
  private var cache: [URL: String] = [:]
  private var cacheBuildID: String?
  private var loadTask: Task<Void, Never>?
  private var lastLayerName: String?
  private var lastTemplate = ""

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
    refresh()
  }

  /// Called whenever the layer, the template or the firmware build changes.
  func update(layerName: String?, template: String, buildID: String?) {
    if buildID != cacheBuildID {
      cache = [:]
      cacheBuildID = buildID
    }
    lastLayerName = layerName
    lastTemplate = template
    if isOpen {
      refresh()
    }
  }

  private func refresh() {
    model.layerName = lastLayerName ?? ""
    guard let layerName = lastLayerName,
          let url = LayerDiagramURL.url(template: lastTemplate, layerName: layerName)
    else {
      loadTask?.cancel()
      model.svg = nil
      model.message = lastTemplate.isEmpty
        ? "Set a diagram URL in the menu to show your keymap here."
        : "Waiting for the keyboard's layer."
      return
    }
    if let svg = cache[url] {
      loadTask?.cancel()
      model.svg = svg
      model.message = nil
      return
    }
    loadTask?.cancel()
    loadTask = Task { [weak self] in
      do {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard !Task.isCancelled, let self else { return }
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let text = String(data: data, encoding: .utf8),
              text.contains("<svg")
        else {
          self.model.svg = nil
          self.model.message = "No diagram found for \(layerName)."
          return
        }
        self.cache[url] = text
        self.model.svg = text
        self.model.message = nil
      } catch {
        guard !Task.isCancelled, let self else { return }
        Self.logger.error("Diagram fetch failed: \(error.localizedDescription, privacy: .public)")
        self.model.svg = nil
        self.model.message = "Could not load the diagram."
      }
    }
  }
}
