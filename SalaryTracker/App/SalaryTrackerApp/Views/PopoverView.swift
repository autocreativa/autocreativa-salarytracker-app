import SwiftUI
import Foundation
import SalaryTrackerCore

/// Formateadores de fecha para el popover/settings (locale es_CL, zona actual).
enum DateFmt {
    /// "25 sep" (etiqueta compacta de período / próximo pago).
    static let short: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_CL")
        f.dateFormat = "dd MMM"
        return f
    }()
    /// "25 de septiembre de 2026, 09:00" (texto legible completo).
    static let full: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_CL")
        f.dateStyle = .long
        f.timeStyle = .short
        return f
    }()
    /// "30 de octubre de 2026" (solo día, mes y año; resumen de configuración).
    static let dateOnly: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_CL")
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }()
}

/// Popover de detalle en tiempo real (specs/menubar-experience "Popover de
/// detalle"). El valor ganado es el elemento dominante; muestra período,
/// próximo pago, tiempo restante, sueldo, progreso y acceso a configuración.
/// Varias variantes por estado.
struct PopoverView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            switch model.state {
            case .notConfigured:      notConfiguredBody
            case .invalid(let reason): invalidBody(reason)
            case .futureStart(let starts, let firstPay, let salary, let code):
                futureBody(starts: starts, firstPay: firstPay, salary: salary, code: code)
            case .active(let v):      activeBody(v)
            case .openEnded(let v):   openEndedBody(v)
            }
        }
        .padding(18)
        .frame(width: 320)
    }

    /// Abre la ventana dedicada de configuración (AppKit; al hacerse key, el
    /// popover de la barra se oculta solo).
    private func openSettings() {
        SettingsWindowController.shared.show(model: model)
    }

    // MARK: - Encabezado

    private var header: some View {
        HStack {
            Text("Salary Tracker")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                openSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Configuración")
        }
    }

    // MARK: - Estado activo

    private func activeBody(_ v: PeriodView) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            dominantValue(v.earned, code: v.currencyCode,
                          subtitle: "ganado de \(CurrencyFormatter.format(v.salary, code: v.currencyCode))")
            if let end = v.end {
                periodRow(start: v.start, end: end)
                ProgressGauge(progress: v.progress)
                Grid(alignment: .leading, verticalSpacing: 6) {
                    GridRow {
                        Text("Próximo pago").foregroundStyle(.secondary)
                        Text(DateFmt.short.string(from: end)).fontWeight(.medium)
                    }
                    GridRow {
                        Text("Tiempo restante").foregroundStyle(.secondary)
                        if let rem = v.remainingSeconds {
                            Text(CurrencyFormatter.formatRemaining(rem))
                                .monospacedDigit().fontWeight(.medium)
                        } else {
                            Text("—")
                        }
                    }
                }
                .font(.system(size: 13, design: .rounded))
            }
        }
    }

    // MARK: - Período abierto (fecha única agotada)

    private func openEndedBody(_ v: PeriodView) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            dominantValue(v.salary, code: v.currencyCode, subtitle: "período finalizado")
            periodRow(start: v.start, end: v.start) // inicio → (abierto)
            ProgressGauge(progress: 1.0)
            Grid(alignment: .leading, verticalSpacing: 6) {
                GridRow {
                    Text("Próximo pago").foregroundStyle(.secondary)
                    Text("sin próximo pago").italic().foregroundStyle(.secondary)
                }
            }
            .font(.system(size: 13, design: .rounded))
        }
    }

    // MARK: - Inicio futuro

    private func futureBody(starts: Date, firstPay: Date?, salary: Decimal, code: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            dominantValue(0, code: code, subtitle: "no iniciado")
            VStack(alignment: .leading, spacing: 6) {
                Label {
                    Text("Inicia el \(DateFmt.full.string(from: starts))")
                } icon: {
                    Image(systemName: "calendar.badge.clock")
                }
                .font(.system(size: 13, design: .rounded))
                if let firstPay {
                    Text("Primer pago: \(DateFmt.short.string(from: firstPay))")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            ProgressGauge(progress: 0)
        }
    }

    // MARK: - Invalid / notConfigured

    private func invalidBody(_ reason: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Configuración inválida", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.yellow)
            Text(reason)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Configurar") { openSettings() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var notConfiguredBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Bienvenido a Salary Tracker", systemImage: "dollarsign.circle.fill")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
            Text("Configura tu sueldo, moneda y regla de pago para empezar a ver tu dinero ganado en tiempo real.")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Configurar") { openSettings() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Componentes compartidos

    private func dominantValue(_ earned: Decimal, code: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(CurrencyFormatter.format(earned, code: code))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(subtitle)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private func periodRow(start: Date, end: Date) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "calendar")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text("\(DateFmt.short.string(from: start))  →  \(DateFmt.short.string(from: end))")
                .font(.system(size: 13, weight: .medium, design: .rounded))
        }
    }
}

/// Barra de progreso con porcentaje y marcas de inicio/fin de período
/// (scenario "Indicador de progreso").
struct ProgressGauge: View {
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)
                        .frame(height: 8)
                    Capsule()
                        .fill(.tint)
                        .frame(width: max(8, geo.size.width * min(max(progress, 0), 1)),
                               height: 8)
                }
            }
            .frame(height: 8)
            // Marcas de inicio y fin de período.
            HStack {
                Circle().frame(width: 4, height: 4).foregroundStyle(.secondary)
                Circle().frame(width: 4, height: 4).foregroundStyle(.secondary)
            }
            HStack {
                Text(CurrencyFormatter.formatProgress(progress))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Spacer()
            }
        }
    }
}
