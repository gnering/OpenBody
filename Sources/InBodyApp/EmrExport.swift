import SwiftUI
import AppKit

/// Exportação para EMR/prontuário (B-05): a folha vira PNG e o exame vira CSV numa pasta
/// de destino, como o LookinBody faz. Um arquivo por exame; nome = ID+data.
enum EmrExport {
    /// PNG da folha de resultado (mesma renderização provada do PDF/impressão).
    @MainActor
    static func pngDaFolha(paciente: Paciente, medida: Medida, tipo: TipoFolha) -> Data? {
        SheetRender.png(paciente, medida, tipo: tipo)
    }

    /// Grava o PNG da folha na pasta. Devolve o caminho, ou nil em falha.
    @MainActor
    static func exportarImagem(paciente: Paciente, medida: Medida, tipo: TipoFolha, pasta: String) -> String? {
        guard let png = pngDaFolha(paciente: paciente, medida: medida, tipo: tipo) else { return nil }
        let destino = (pasta as NSString).appendingPathComponent(nomeArquivo(paciente, medida) + ".png")
        return (try? png.write(to: URL(fileURLWithPath: destino))) != nil ? destino : nil
    }

    /// Grava um CSV de UMA linha (o exame) na pasta. Devolve o caminho, ou nil em falha.
    static func exportarCSVExame(paciente: Paciente, medida: Medida, pasta: String) -> String? {
        let header = ["ID", "Nome", "Sexo", "Idade", "Altura", "Data",
                      "Peso", "MME", "Gordura", "PGC", "IMC", "TMB"]
        let linha = [paciente.id, paciente.nome, paciente.sexo, "\(paciente.idade)",
                     f(paciente.altura), medida.data, f(medida.peso), f(medida.smm),
                     f(medida.gordura), f(medida.pgc), f(medida.imc), f(medida.tmb)]
        let csv = header.joined(separator: ",") + "\n" + linha.map(esc).joined(separator: ",") + "\n"
        let destino = (pasta as NSString).appendingPathComponent(nomeArquivo(paciente, medida) + ".csv")
        return (try? csv.write(toFile: destino, atomically: true, encoding: .utf8)) != nil ? destino : nil
    }

    private static func nomeArquivo(_ p: Paciente, _ m: Medida) -> String {
        "\(sanitizar(p.id))_\(m.data.filter { $0.isNumber })"
    }
    private static func f(_ v: Double) -> String { String(format: "%.1f", v) }
    private static func esc(_ s: String) -> String {
        (s.contains(",") || s.contains("\"") || s.contains("\n"))
            ? "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\"" : s
    }
    private static func sanitizar(_ s: String) -> String {
        let ok = String(s.map { $0.isLetter || $0.isNumber ? $0 : "_" })
        return ok.isEmpty ? "exame" : ok
    }
}
