import AppKit

/// Icono de un agente para el chrome. Los agentes sin arte propio usan un
/// glifo SF Symbol. El SVG se carga como plantilla, así que toma el color
/// del sistema en claro y oscuro.
enum AgentIcon {
    static func image(for agent: AgentKind) -> NSImage? {
        switch agent {
        case .grok:
            return template(named: "grok")
        case .opencode2, .agy:
            return nil
        }
    }

    private static func template(named name: String) -> NSImage? {
        // El recurso queda en `Contents/Resources` del bundle, que es lo que ya
        // resuelve `Bundle.module`: nada de subdirectorio.
        guard let url = Bundle.module.url(forResource: name, withExtension: "svg"),
              let image = NSImage(contentsOf: url)
        else {
            return nil
        }
        image.isTemplate = true
        return image
    }
}
