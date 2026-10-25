import AppKit
import SwiftUI
import Combine
import SalaryTrackerCore

/// Chip de sueldo en la barra de menús, gestionado con **AppKit**
/// (`NSStatusItem` + `NSPopover`).
///
/// Sustituye a la escena `MenuBarExtra` porque `SceneBuilder` no admite
/// `if/else`: la escena no se puede ocultar en caliente, y el switch
/// maestro de widgets (AppModel.showMenuBarChip, derivado de
/// `WidgetState.menuBar`) necesita mostrar/ocultar el chip sin reiniciar la
/// app. Replica el comportamiento de
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
    /// Ventana ancla efímera (1×1, transparente) para mostrar el popover
    /// cuando el chip está oculto (aperturas externas: clic en el widget del
    /// centro de notificaciones): el popover se ancla junto a donde iría el
    /// chip (esquina superior derecha) y la ventana se cierra cuando el
    /// popover se cierra.
    private var anchorWindow: NSWindow?
    /// Monitores de «clic fuera» (popover `.applicationDefined`): el
    /// popover no se cierra solo; lo gestionamos nosotros para dar un grace
    /// period al clic que lo abre (pulsación del widget del centro de
    /// notificaciones: su mouse-down/panel puede llegar justo tras la
    /// apertura y un `.transient` lo cerraría al instante).
    private var outsideClickLocalMonitor: Any?
    private var outsideClickGlobalMonitor: Any?
    /// Momento de la apertura (para el grace period de ~0,5 s).
    private var popoverShownAt: Date?
    /// El modelo se retiene en fuerte: el ciclo de vida del chip está
    /// atado a este controlador. Con `weak`, el salto asíncrono a main
    /// podía encontrar el modelo ya liberado (o a `self` sin modelo) y el
    /// toggle «Barra superior» dejaría de ocultar/mostrar el chip.
    private var model: AppModel?
    private var applyScheduled = false

    /// Conecta el modelo y (re)establece la visibilidad según su toggle.
    /// Se suscribe a `objectWillChange`: el switch maestro de widgets
    /// (AppModel.showMenuBarChip) muestra/oculta el chip **en caliente**.
    /// `objectWillChange` avisa ANTES del cambio, así la lectura del valor
    /// se hace en la siguiente vuelta del main loop (`Task`), donde ya
    /// tiene el valor nuevo. Solo actúa si el valor efectivamente cambió
    /// (dedupe contra el tick de 1 s del chip).
    func attach(model: AppModel) {
        self.model = model
        chipObservation = model.objectWillChange.sink { [weak self] _ in
            self?.scheduleApply()
        }
        apply(model.showMenuBarChip)
    }

    /// Coalesce las emisiones de `objectWillChange` (el timer del chip
    /// dispara una por segundo) en un solo salto a main, y siempre aplica
    /// el valor **corriente** del switch al ejecutar (nunca un valor leído
    /// en el momento de la emisión, que podría estar desfasado).
    private func scheduleApply() {
        guard !applyScheduled else { return }
        applyScheduled = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.applyScheduled = false
            if let m = self.model {
                self.apply(m.showMenuBarChip)
            }
        }
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
    }

    /// Oculta el chip (cierra el popover si está abierto).
    func hide() {
        if let popover, popover.isShown { popover.performClose(nil) }
        popover = nil
        disarmOutsideClickDetection()
        statusItem?.button?.highlight(false)
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
        // Cerrar anclas efímeras
        anchorWindow?.close()
        anchorWindow = nil
    }

    var isVisible: Bool { statusItem != nil }

    // MARK: - Popover

    @objc private func togglePopover(_ sender: NSButton) {
        guard let popover, popover.isShown else {
            openPopover()
            return
        }
        popover.performClose(nil)
    }

    /// Abre el popover de sueldo («la vista que abre el widget de la barra
    /// superior»). Se usa tanto para el clic en el chip como para las
    /// aperturas externas (widget de la barra superior cuando el chip está
    /// oculto).
    ///
    /// - Con chip visible: se ancla debajo del chip.
    /// - Sin chip y con `point` (posición del clic, la envía el intent en la
    ///   petición de apertura): se ancla **a la izquierda del icono** en esa
    ///   posición. Es lo que pide el usuario: al pulsar el widget de la
    ///   barra superior, la vista sale a su izquierda y no centrada.
    /// - Sin chip y sin `point` (fallback): extremo superior derecho.
    ///
    /// **Siempre se recrea** (contenido y tamaño frescos): un `NSPopover`
    /// conserva el `contentSize` con el que se mostró por primera vez, así
    /// que reutilizarlo tras un cambio de estado (o de altura del
    /// contenido) dejaba bandas del fondo de la burbuja a la vista.
    @discardableResult
    func openPopover(near point: NSPoint? = nil) -> Bool {
        guard let model else { return false }
        teardownPopover()
        let pop = makePopover(model: model)
        popover = pop

        if let button = statusItem?.button {
            // Ancla normal: debajo del chip.
            button.highlight(true)
            pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            if !pop.isShown {
                // Primer tick tras crear el status item: la ventana del
                // botón puede no estar lista todavía → reintento en el
                // siguiente ciclo del main run loop (una sola vez).
                DispatchQueue.main.async { [weak self, weak button] in
                    guard let self, let btn = button,
                          let p = self.popover, !p.isShown else { return }
                    p.show(relativeTo: btn.bounds, of: btn, preferredEdge: .minY)
                }
            }
        } else if let anchor = makeAnchorWindow(at: point) {
            // Chip oculto: con la posición del clic, a la IZQUIERDA del
            // icono pulsado; sin ella, extremo superior derecho.
            anchorWindow = anchor
            anchor.orderFront(nil)
            anchor.layoutIfNeeded()
            guard let content = anchor.contentView else {
                popover = nil
                return false
            }
            let edge: NSRectEdge = point == nil ? .minY : .minX
            pop.show(relativeTo: content.bounds, of: content, preferredEdge: edge)
            if !pop.isShown {
                popover = nil
                return false
            }
        } else {
            popover = nil
            return false
        }
        pop.contentViewController?.view.window?.makeKey()
        armOutsideClickDetection()
        return pop.isShown
    }

    /// Crea el popover con **tamaño explícito** a partir del tamaño ideal
    /// de `PopoverView` (ancho fijo 344 en la propia vista).
    ///
    /// Sin fijar `preferredContentSize`/`contentSize`, `NSHostingController`
    /// negocia el tamaño con la burbuja y la vista hospedada termina más
    /// pequeña, anclada abajo-izquierda del `contentView`: se veía un marco
    /// del fondo del popover arriba y a la derecha.
    private func makePopover(model: AppModel) -> NSPopover {
        let pop = NSPopover()
        // `.applicationDefined`: la app decide cuándo cerrar (monitores de
        // «clic fuera» con grace period). Un `.transient` cerraba al
        // instante cuando el popover se abría desde el widget del centro de
        // notificaciones (los eventos del panel llegaban como «fuera»).
        pop.behavior = .applicationDefined
        pop.animates = true
        pop.delegate = self

        let hosting = NSHostingController(
            rootView: PopoverView()
                .environmentObject(model)
                .environment(\.locale, model.language.effectiveLocale)
        )
        // El tamaño lo fijamos nosotros midiendo el contenido con un ancho
        // propuesto de 344 (el ancho fijo de `PopoverView`); así la vista
        // hospedada y la burbuja miden EXACTAMENTE lo mismo.
        hosting.sizingOptions = []
        let fit = hosting.sizeThatFits(in: NSSize(width: 344, height: 4096))
        let size = NSSize(width: max(fit.width, 344), height: max(fit.height, 1))
        hosting.preferredContentSize = size
        pop.contentViewController = hosting
        pop.contentSize = size
        return pop
    }

    /// Cierra y descarta el popover actual (y las anclas efímeras).
    private func teardownPopover() {
        if let existing = popover {
            existing.performClose(nil)
            popover = nil
        }
        disarmOutsideClickDetection()
        statusItem?.button?.highlight(false)
        anchorWindow?.close()
        anchorWindow = nil
    }

    /// «Clic fuera» manual (complemento del `.applicationDefined`):
    /// - Global: clic/tecla en OTRO app (el popover no recibe el evento).
    /// - Local: clic en una ventana NO del popover (p. ej. Configuración).
    /// Con grace period de 0,5 s: los eventos de la propia pulsación que
    /// abrió el popover (widget del centro de notificaciones) no lo cierran.
    private func armOutsideClickDetection() {
        popoverShownAt = Date()
        outsideClickLocalMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, let pop = self.popover, pop.isShown else { return event }
            // «Dentro» = el popover MISMO, la ventana del botón del chip
            // (el status bar no es ventana de la app, y el clic que abre el
            // popover desde el chip llegaría como «fuera» y lo cerraría al
            // instante) o la ancla efímera.
            let friendly: [NSWindow] = [
                pop.contentViewController?.view.window,
                self.statusItem?.button?.window,
                self.anchorWindow
            ].compactMap { $0 }
            if let w = event.window, friendly.contains(where: { $0 === w }) {
                return event
            }
            self.closePopover()
            return event
        }
        outsideClickGlobalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            guard let self,
                  let shownAt = self.popoverShownAt,
                  Date().timeIntervalSince(shownAt) > 0.5
            else { return }
            self.closePopover()
        }
    }

    /// Quita los monitores de «clic fuera» (al cerrar el popover o al
    /// ocultar el chip).
    private func disarmOutsideClickDetection() {
        if let mon = outsideClickLocalMonitor {
            NSEvent.removeMonitor(mon)
            outsideClickLocalMonitor = nil
        }
        if let mon = outsideClickGlobalMonitor {
            NSEvent.removeMonitor(mon)
            outsideClickGlobalMonitor = nil
        }
        popoverShownAt = nil
    }

    /// Cierra el popover si está abierto.
    func closePopover() {
        guard let popover, popover.isShown else { return }
        popover.performClose(nil)
    }

    /// Ventana 1×1 transparente para anclar el popover cuando el chip está
    /// oculto.
    ///
    /// - Con `point` (clic en el icono/widget de la barra superior): se
    ///   coloca en esa posición y el popover se muestra a su **izquierda**
    ///   (`preferredEdge: .minX`), apuntando al icono pulsado.
    /// - Sin `point`: extremo superior derecho (respaldo), debajo de la
    ///   barra de menús.
    private func makeAnchorWindow(at point: NSPoint?) -> NSWindow? {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return nil }
        let frame: NSRect
        if let p = point {
            // Normalizar a la pantalla vigente (por si el icono está en un
            // borde): 2 pt para que la flecha del popover no quede debajo
            // del propio icono.
            let host = NSScreen.screens.first(where: { $0.frame.contains(p) }) ?? screen
            frame = NSRect(x: min(max(p.x - 2, host.frame.minX + 1), host.frame.maxX - 2),
                           y: min(max(p.y - 2, host.frame.minY + 1), host.frame.maxY - 2),
                           width: 1, height: 1)
        } else {
            // `visibleFrame` excluye la barra de menús y el Dock; el margen
            // de 10 pt deja la burbuja separada del borde.
            let vf = screen.visibleFrame
            frame = NSRect(x: vf.maxX - 10, y: vf.maxY - 10, width: 1, height: 1)
        }
        let win = NSWindow(
            contentRect: frame,
            styleMask: [.borderless], backing: .buffered, defer: false)
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = .popUpMenu
        win.ignoresMouseEvents = true
        win.hasShadow = false
        win.isReleasedWhenClosed = false
        win.contentView = NSView()
        return win
    }


    // MARK: - NSPopoverDelegate

    nonisolated func popoverDidClose(_ notification: Notification) {
        Task { @MainActor [weak self] in
            self?.popover = nil
            self?.disarmOutsideClickDetection()
            self?.statusItem?.button?.highlight(false)
            // Cierra las anclas efímeras (si existía) y re-aplica la
            // visibilidad del chip: si el chip estaba oculto cuando el
            // popover se abrió desde fuera, debe seguir oculto al cerrar.
            self?.anchorWindow?.close()
            self?.anchorWindow = nil
            if let m = self?.model {
                self?.apply(m.showMenuBarChip)
            }
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
