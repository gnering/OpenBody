import Foundation

/// Backup na nuvem (B-02): você VINCULA uma pasta (a do iCloud Drive, Google Drive ou
/// OneDrive, ou qualquer outra que sincronize) por um botão, e o app grava a cópia completa
/// do banco lá dentro. O app da nuvem sincroniza sozinho. Sem OAuth, sem senha, sem API.
enum CloudBackup {
    private static let kPasta = "InBodyMac.cloud.pasta"
    private static let kAuto  = "InBodyMac.cloud.auto"

    /// Pasta vinculada pelo usuário (caminho). nil = ainda não vinculou.
    static var pastaVinculada: String? {
        get {
            guard let p = UserDefaults.standard.string(forKey: kPasta), !p.isEmpty else { return nil }
            return p
        }
        set { UserDefaults.standard.set(newValue, forKey: kPasta) }
    }

    /// Fazer backup automático na nuvem na abertura do app?
    static var autoAtivo: Bool {
        get { UserDefaults.standard.bool(forKey: kAuto) }
        set { UserDefaults.standard.set(newValue, forKey: kAuto) }
    }

    /// Copia um snapshot já pronto do banco para dentro da pasta (subpasta "InBody Backups"),
    /// com nome carimbado. Puro (sem tocar no Banco vivo) — por isso testável fora do main actor.
    static func copiarSnapshot(_ snap: String, paraPasta pasta: String) -> String? {
        let fm = FileManager.default
        let destinoDir = (pasta as NSString).appendingPathComponent("InBody Backups")
        try? fm.createDirectory(atPath: destinoDir, withIntermediateDirectories: true)
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd_HHmmss"
        let destino = (destinoDir as NSString).appendingPathComponent("InBody_\(f.string(from: Date())).sqlite")
        do {
            if fm.fileExists(atPath: destino) { try fm.removeItem(atPath: destino) }
            try fm.copyItem(atPath: snap, toPath: destino)
            return destino
        } catch { return nil }
    }

    /// Grava a cópia completa do banco vivo numa pasta. Base = VACUUM INTO (consistente).
    @MainActor @discardableResult
    static func gravarBackup(emPasta pasta: String) -> String? {
        copiarSnapshot(Banco.shared.fazerBackup(), paraPasta: pasta)
    }

    /// Backup na pasta vinculada. Devolve (caminho, nil) em sucesso ou (nil, motivo) em erro.
    @MainActor
    static func backupVinculado() -> (caminho: String?, erro: String?) {
        guard let pasta = pastaVinculada else {
            return (nil, T("No folder linked. Click Connect and choose your cloud folder."))
        }
        guard FileManager.default.fileExists(atPath: pasta) else {
            return (nil, T("The linked folder no longer exists:") + "\n\(pasta)")
        }
        guard let caminho = gravarBackup(emPasta: pasta) else {
            return (nil, T("Could not write to") + " \(pasta).")
        }
        return (caminho, nil)
    }
}
