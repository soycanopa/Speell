import Foundation

/// Puntero a un hilo que el CLI del agente ya guarda.
/// Speell no copia el transcript: solo el id, y el título para poder elegir.
struct SessionRef: Equatable {
    var id: String
    var title: String
    var updatedAt: Date?
}
