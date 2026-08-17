import SwiftUI
import AppKit

/// Compositor de e-mail (E7). Gera o PDF da folha e ABRE a janela de e-mail do sistema
/// com o anexo pronto — quem clica em Enviar e o MEDICO (o app nunca envia sozinho).
/// E o mesmo modelo da caixa de impressao: prepara, o usuario confirma.
@MainActor
func comporEmailComFolha(paciente: Paciente, medida: Medida, tipo: TipoFolha = .adulto,
                         para destinatario: String = "") {
    // 1. gera a MESMA folha (motor) em PDF num arquivo temporario
    let nome = paciente.nome.replacingOccurrences(of: " ", with: "_")
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("OpenBody_\(nome).pdf")
    if let pdf = SheetRender.pdfData(paciente, medida, tipo: tipo) { try? pdf.write(to: url) }

    // 2. abre a janela de composicao do sistema com o anexo (o envio e do usuario)
    let servico = NSSharingService(named: .composeEmail)
    servico?.subject = "OpenBody · \(paciente.nome)"
    if !destinatario.isEmpty { servico?.recipients = [destinatario] }
    if servico?.canPerform(withItems: [url]) == true {
        servico?.perform(withItems: [url])
    } else {
        // sem cliente de e-mail configurado: mostra o PDF pronto para anexar a mao
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

/// PDF da folha em memória (para anexar no envio direto por SMTP).
@MainActor
func pdfDaFolha(paciente: Paciente, medida: Medida, tipo: TipoFolha = .adulto) -> Data? {
    SheetRender.pdfData(paciente, medida, tipo: tipo)
}

/// Envio DIRETO pelo servidor de e-mail configurado (Setup A-05), como no LookinBody do
/// Windows: anexa as folhas escolhidas em PDF e manda. Devolve nil se deu certo, ou a
/// mensagem de erro. Bloqueante: chamar fora da thread principal.
func enviarEmailComFolhas(para: String, assunto: String, corpo: String,
                          anexos: [(nome: String, dados: Data)]) -> String? {
    do {
        try SMTP.enviar(para: para, assunto: assunto, corpo: corpo,
                        anexos: anexos.map { ($0.nome, $0.dados, "application/pdf") })
        return nil
    } catch {
        return error.localizedDescription
    }
}
