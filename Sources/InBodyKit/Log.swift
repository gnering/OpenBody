import Foundation

/// Log leve do kit: escreve avisos no stderr sem interromper o fluxo.
/// Usado para registrar CRC divergente e outras anomalias do protocolo.
public enum InBodyLog {
    public static func warn(_ message: String) {
        FileHandle.standardError.write(Data(("[InBody] " + message + "\n").utf8))
    }
}
