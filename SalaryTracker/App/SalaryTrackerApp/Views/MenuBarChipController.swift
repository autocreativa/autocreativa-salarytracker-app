import AppKit
import SwiftUI
import Combine
import SalaryTrackerCore

/// Chip de sueldo en la barra de menús, gestionado con **AppKit**
/// (`NSStatusItem` + `NSPopover`).
///
/// Sustituye a la escena `MenuBarExtra` porque `SceneBuilder` no admite
/// `if/else`: la escena no se puede ocultar en caliente, y el toggle
/// «Barra superior» (AppModel.showMenuBarChip) necesita mostrar/ocultar el
/// chip sin reiniciar la app. Replica el comportamiento de
/// `MenuBarExtra(menuBarExtraStyle: .window)`: clic → popover transitorio
/// con `PopoverView`; clic fuera → se cierra solo.
///
/// El label se hostea con `NSHostingView(MenuBarLabel)`: `MenuBarLabel`
/// pre-renderiza el chip a `NSImage` non-template (DigiSeven en vivo) de la
/// misma forma que lo hacía en `MenuBarExtra`.
@MainActor
final class MenuBarChipController: NSObject, NSPopoverDelegate {

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var chipObservation: AnyCancellable?
    private var lastVisible: Bool?
    private weak var model: AppModel?

    /// Conecta el modelo y (re)establece la visibilidad según su toggle.
    /// Se suscribe a `objectWillChange`: el toggle «Barra superior»
    /// (AppModel.showMenuBarChip) muestra/oculta el chip **en caliente**.
    /// `objectWillChange` avisa ANTES del cambio, así la lectura del valor
    /// nuevo se hace en la siguiente vuelta del main loop (`Task`); solo
    /// actúa si el valor efectivamente cambió (dedupe contra el tick de 1 s).
    func attach(model: AppModel) {
        self.model = model
        chipObservation = model.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in
                guard let self, let m = self.model else { return }
                self.apply(m.showMenuBarChip)
            }
        }
        apply(model.showMenuBarChip)
    }

    private func apply(_ visible: Bool) {
        guard visible != lastVisible else { return }
        lastVisible = visible
        visible ? show() : hide()
    }

    /// Muestra el chip (no-op si ya está visible).
    func show() {
        guard statusItem == nil, let model else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let host = NSHostingView(rootView: ChipHost(model: model))
            host.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(host)
            NSLayoutConstraint.activate([
                host.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 2),
                host.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -2),
                host.centerYAnchor.constraint(equalTo: button.centerYAnchor),
                host.heightAnchor.constraint(lessThanOrEqualTo: button.heightAnchor),
            ])
            button.imagePosition = .imageOnly
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.setAccessibilityLabel(L10n.str("a11y.menuBarChip"))
        }
        statusItem = item
        trace("show")
    }

    /// Oculta el chip (cierra el popover si está abierto).
    func hide() {
        if let popover, popover.isShown { popover.performClose(nil) }
        popover = nil
        statusItem?.button?.highlight(false)
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
        trace("hide")
    }

    /// TEMP-DEBUG (diagnóstico; se eliminará): traza (re)mostrados del chip.
    private func trace(_ event: String) {
        let payload: [String: Any] = [
            "event": event,
            "at": ISO8601DateFormatter().string(from: Date()),
        ]
        guard let d = try? JSONSerialization.data(withJSONObject: payload) else { return }
        let url = SharedPaths.stateDirectory.appendingPathComponent("chip-events.log")
        if let h = try? FileHandle(forWritingTo: url) {
            h.seekToEndOfFile()
            _ = try? h.write(contentsOf: d)
            try? h.write(contentsOf: Data("\n".utf8))
            try? h.close()
        } else {
            try? d.write(to: url)
        }
    }

    var isVisible: Bool { statusItem != nil }

    // MARK: - Popover

    @objc private func togglePopover(_ sender: NSButton) {
        guard let model else { return }
        if let popover, popover.isShown {
            popover.performClose(nil)
            return
        }
        let pop = NSPopover()
        pop.behavior = .transient
        pop.animates = true
        pop.delegate = self
        pop.contentViewController = NSHostingController(
            rootView: PopoverView()
                .environmentObject(model)
                .environment(\.locale, model.language.effectiveLocale)
        )
        popover = pop
        sender.highlight(true)
        pop.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        pop.contentViewController?.view.window?.makeKey()
    }

    // MARK: - NSPopoverDelegate

    nonisolated func popoverDidClose(_ notification: Notification) {
        Task { @MainActor [weak self] in
            self?.popover = nil
            self?.statusItem?.button?.highlight(false)
        }
    }
}

/// Contenedor observable: re-renderiza el chip en cada cambio de estado del
/// modelo (tick de 1 s) sin volver a crear el `NSStatusItem`.
private struct ChipHost: View {
    @ObservedObject var model: AppModel
    var body: some View {
        MenuBarLabel(state: model.state)
    }
}
