import AppKit

/// Icono de un agente para el chrome. Los agentes sin arte propio usan un
/// glifo SF Symbol. El SVG se carga como plantilla, así que toma el color
/// del sistema en claro y oscuro.
enum AgentIcon {
    static func image(for agent: AgentKind) -> NSImage? {
        switch agent {
        case .grok: return template(named: "grok")
        case .opencode2: return template(named: "opencode")
        case .agy: return template(named: "antigravity")
        }
    }

    private static func template(named name: String) -> NSImage? {
        // Los svgs viven en `Resources/` del bundle (Package.swift copia la
        // carpeta completa), que es lo que resuelve `Bundle.module`.
        guard let url = Bundle.module.url(
                  forResource: name,
                  withExtension: "svg",
                  subdirectory: "Resources"),
              let image = NSImage(contentsOf: url)
        else {
            return nil
        }
        image.isTemplate = true
        return image
    }
}
