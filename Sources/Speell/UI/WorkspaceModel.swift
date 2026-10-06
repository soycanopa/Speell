import Combine
import Foundation

/// Qué sesión abrir en una tab de agente. Lo elige el menú del `+`.
enum AgentTabChoice {
    case fresh
    case session(SessionRef)
}

/// Petición de modal de sesiones. Se identifica por agente para que SwiftUI
/// sepa cuándo presentarlo y cuándo cerrarlo.
struct SessionPickerRequest: Identifiable, Equatable {
    let agent: AgentKind

    var id: String { agent.rawValue }
}

/// Modo de la app: el workspace o la configuración. Las surfaces y procesos
/// siguen vivos al entrar a settings; al volver, el workspace está exacto.
enum AppMode {
    case workspace
    case settings
}

    /// Sección de la configuración. Se lista en la sidebar y sus opciones salen
    /// en el área de contenido, sin tabs.
    enum SettingsSection: String, CaseIterable, Identifiable {
        case apariencia
        case agentes
        case notificaciones
        case archivados

        var id: String { rawValue }

        var title: String {
            switch self {
            case .apariencia: return "Apariencia"
            case .agentes: return "Agentes"
            case .notificaciones: return "Notificaciones"
            case .archivados: return "Archivados"
            }
        }

        var systemImage: String {
            switch self {
            case .apariencia: return "paintbrush"
            case .agentes: return "cpu"
            case .notificaciones: return "bell"
            case .archivados: return "archivebox"
            }
        }
    }

/// Estado que consume la UI y las intenciones que emite.
/// La vista no conoce stores, ni libghostty, ni arma comandos.
/// Las intenciones se emiten desde el hilo principal (botones y menús).
@MainActor
final class WorkspaceModel: ObservableObject {
    @Published var projects: [Project] = []
    /// Proyectos cuyo path ya no existe en disco. La fila queda rota, no se borra.
    @Published var missingProjectIds: Set<UUID> = []
    /// Proyectos archivados (settings → Archivados). Fuera de la sidebar
    /// hasta que el usuario los recupere.
    @Published var archivedProjects: [Project] = []
    @Published var tabs: [Tab] = []
    @Published var activeProjectId: UUID?
    @Published var activeTabId: UUID?
    /// Distancia desde el borde izquierdo del app bar hasta donde empieza la
    /// terminal. Lo publica el composition root cuando cambia el divider, para
    /// que el app bar pueda alinear los tabs con el borde de la terminal sin
    /// conocer el split.
    ///
    /// No es el ancho de la sidebar: es su borde derecho más el divisor del
    /// split. Los botones de ventana no se suman porque solo ocupan la parte
    /// de la franja que cae sobre la sidebar.
    @Published var contentLeadingOffset: CGFloat = 241

    /// Agentes que ya tienen adaptador. El menú del `+` muestra estos.
    @Published var availableAgents: [AgentKind] = []
    /// El canal de avisos real de cada agente, declarado por su adaptador
    /// (docs/decisions/0006). La configuración lo muestra tal cual.
    @Published var noticeSources: [AgentKind: NoticeSource] = [:]
    /// La campana de Agy depende de una clave documentada en el
    /// `settings.json` del propio CLI; aquí vive su estado real, leído al
    /// arrancar. La escritura es siempre una acción del usuario.
    @Published var agyNoticesEnabled = false
    /// No nulo = modal de sesiones abierto para ese agente.
    @Published var sessionPicker: SessionPickerRequest?
    @Published var agentSessions: [SessionRef] = []
    @Published var loadingSessions = false

    /// Agentes habilitados por el usuario (settings → Agentes). Persistido;
    /// los ausentes están habilitados. Reinicia al arrancar.
    @Published var agentPreferences: AgentPreferences = AgentPreferences()

    /// Tabs con aviso pendiente de mirar (el agente mandó algo o terminó).
    /// El punto de la tab vive aquí; se limpia al seleccionar la tab.
    @Published var noticedTabIds: Set<UUID> = []
    /// Proyectos con al menos una tab con aviso pendiente (FLOW F4 paso 2:
    /// "la sidebar marca el proyecto"). Derivado de `noticedTabIds`; no es
    /// fuente de verdad de nada.
    @Published var noticedProjectIds: Set<UUID> = []

    /// Preferencias de notificaciones persistidas (settings → Notificaciones).
    @Published var notificationPreferences = NotificationPreferences()

    /// Chequeos de actualización por agente (solo los CLIs con chequeo
    /// documentado). Lo llena settings → Agentes.
    @Published var updateChecks: [AgentKind: AgentUpdate] = [:]
    /// Chequeo o instalación en curso: el agente ocupado, para deshabilitar.
    @Published var updateWorkInProgress = false

    /// Modo de la app y sección activa de la configuración.
    @Published var appMode: AppMode = .workspace
    @Published var settingsSection: SettingsSection = .apariencia

    /// El fondo vigente de la terminal, en hex. Lo publica el composition
    /// root al arrancar (leído del override persistido) y cada vez que cambia
    /// desde la configuración; el chrome que empalma con la terminal (tab
    /// activa, vacío del pane) pinta con este valor.
    @Published var terminalBackgroundHex: String = TerminalPalette.backgroundHex

    var onAddProject: () -> Void = {}
    var onSelectProject: (UUID) -> Void = { _ in }
    var onRemoveProject: (UUID) -> Void = { _ in }
    /// Archivar desde el menú contextual: sale de la sidebar, queda en
    /// settings → Archivados.
    var onArchiveProject: (UUID) -> Void = { _ in }
    /// Recuperar un archivado desde settings → Archivados.
    var onRestoreProject: (UUID) -> Void = { _ in }
    /// Cambiar el nombre visible desde el menú contextual. El nombre vive
    /// solo en Speell; la carpeta queda igual.
    var onRenameProject: (UUID) -> Void = { _ in }
    var onNewTerminal: () -> Void = {}
    var onNewAgentTab: (AgentKind, AgentTabChoice) -> Void = { _, _ in }
    var onPickAgentSession: (AgentKind) -> Void = { _ in }
    var onCancelSessionPicker: () -> Void = {}
    var onSelectTab: (UUID) -> Void = { _ in }
    var onCloseTab: (UUID) -> Void = { _ in }
    /// Cambio de apariencia de la terminal desde la configuración:
    /// fondo `#RRGGBB`, tipografía (`nil` = la bundled del CLI) y tamaño.
    var onAppearanceChange: (String, String?, Double) -> Void = { _, _, _ in }
    /// Toggle de un agente en settings → Agentes: habilitar o deshabilitar.
    var onAgentToggle: (AgentKind, Bool) -> Void = { _, _ in }
    /// Cambio de preferencias de notificaciones.
    var onNotificationPreferencesChange: (NotificationPreferences) -> Void = { _ in }
    /// Activar la campana de Agy: escribe la clave documentada en el
    /// `settings.json` del CLI (docs/decisions/0006).
    var onEnableAgyNotices: () -> Void = {}
    /// Buscar actualizaciones de todos los CLIs capaces.
    var onCheckForUpdates: () -> Void = {}
    /// Instalar la actualización de un agente.
    var onUpdateAgent: (AgentKind) -> Void = { _ in }

    var activeProject: Project? {
        projects.first { $0.id == activeProjectId }
    }
}
