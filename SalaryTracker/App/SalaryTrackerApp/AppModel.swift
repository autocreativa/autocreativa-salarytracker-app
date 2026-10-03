import Foundation
import SwiftUI
import AppKit
import SalaryTrackerCore

/// Estado observable de la aplicación (design.md D7).
///
/// Es la única orquestación de la app: carga la configuración persistida, deriva
/// el estado con `TrackerEngine` (lógica pura, testeada) en cada tick y publica
/// `state`/`config` para la UI. La UI NUNCA calcula: solo renderiza el estado
/// derivado (pipeline único: `Config + instante → TrackerState`).
///
/// Temporización: un `Timer` de 1 s (tolerance 0.2) alineado al segundo. El valor
/// se calcula desde el instante exacto de cada tick (no por acumulación), por lo
/// que un gap de 3 s entre ticks produce el valor correcto del instante real.
@MainActor
final class AppModel: ObservableObject {

    /// Estado derivado actual (lo renderiza la barra y el popover).
    @Published private(set) var state: TrackerState = .notConfigured
    /// Configuración vigente (vigente persistida, o la pendiente en edición).
    @Published private(set) var config: SalaryConfig?

    /// Mensaje de carga inicial (p. ej. archivo corrupto); `nil` si todo OK.
    @Published private(set) var loadIssue: String?

    private let store: ConfigStore
    private let engine: TrackerEngine
    private let clock: Clock
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []

    init(store: ConfigStore = ConfigStore(),
         engine: TrackerEngine = TrackerEngine(),
         clock: Clock = SystemClock()) {
        self.store = store
        self.engine = engine
        self.clock = clock
        // Carga inicial (specs/configuration "Reconstrucción del estado al
        // iniciar"): sin archivo → notConfigured; corrupto → invalid (sin crash).
        do {
            self.config = try store.load()
            self.state = engine.state(config: self.config, now: clock.now)
        } catch {
            self.config = nil
            self.loadIssue = (error as? ConfigStore.StoreError)?.errorDescription
                ?? "No se pudo leer la configuración."
            self.state = .invalid(reason: self.loadIssue ?? "Configuración no legible.")
        }
        // Arranque inmediato (idempotente): la escena MenuBarExtra no expone
        // `onAppear` a nivel Scene, por lo que el ciclo se inicia al construir
        // el modelo (main thread).
        start()
    }

    /// Arranca el ciclo de actualización (timer 1 s + observadores de contexto).
    /// Idempotente: llamarlo varias veces no duplica timers ni observadores.
    func start() {
        guard timer == nil else { return }
        startTimer()
        observeContextChanges()
    }

    /// Para el ciclo (usado en tests / shutdown).
    func stop() {
        timer?.invalidate()
        timer = nil
        for o in observers { NotificationCenter.default.removeObserver(o) }
        observers.removeAll()
    }

    /// Re-deriva el estado desde el instante actual del reloj y publica.
    /// Es el método testeable: avanza el clock inyectado y el estado resultante
    /// debe ser el correcto (task 8.2).
    func evaluateNow() {
        state = engine.state(config: config, now: clock.now)
    }

    /// Guarda y persiste una nueva configuración (regla R-LIVE: re-deriva de
    /// inmediato, sin conservar valores del período anterior).
    func save(_ newConfig: SalaryConfig) {
        do {
            try store.save(newConfig)
            config = newConfig
            loadIssue = nil
            evaluateNow()
        } catch {
            // El guardado falló: la configuración previa sigue vigente (spec
            // "Validación antes de guardar": la previa válida se conserva).
            loadIssue = (error as? ConfigStore.StoreError)?.errorDescription
                ?? "No se pudo guardar."
        }
    }

    private func startTimer() {
        timer?.invalidate()
        // Alinear el primer fire al próximo segundo completo (design D7) y luego
        // repiten cada 1 s. Tolerance 0.2 permite coalescing del sistema (CPU).
        let interval: TimeInterval = 1.0
        let nowInterval = clock.now.timeIntervalSinceReferenceDate
        let nextWhole = ceil(nowInterval)
        let firstDelay = max(0, nextWhole - nowInterval)
        let fireDate = clock.now.addingTimeInterval(firstDelay)
        let t = Timer(fire: fireDate, interval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.evaluateNow()
            }
        }
        t.tolerance = 0.2
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func observeContextChanges() {
        // Cambio de zona horaria del sistema → re-derivar (R-TZ).
        observers.append(NotificationCenter.default.addObserver(
            forName: .NSSystemTimeZoneDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.evaluateNow() }
        })
        // Cruce de medianoche (cambio de día local) → re-derivar.
        observers.append(NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.evaluateNow() }
        })
        // Despertar de suspensión → la próxima actualización muestra el instante
        // actual (specs/menubar "Despertar de suspensión").
        let wake = Notification.Name("NSApplicationDidWakeNotification")
        observers.append(NotificationCenter.default.addObserver(
            forName: wake, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.evaluateNow() }
        })
    }
}
