import SwiftUI
import AppKit

/// Exporta a folha de resultado em PDF, como o original imprime.
@MainActor
func exportarPDF(paciente: Paciente, medida: Medida, tipo: TipoFolha = .adulto) {
    guard let pdf = SheetRender.pdfData(paciente, medida, tipo: tipo) else { return }
    let painel = NSSavePanel()
    painel.nameFieldStringValue = "OpenBody_\(paciente.nome.replacingOccurrences(of: " ", with: "_")).pdf"
    painel.allowedContentTypes = [.pdf]
    guard painel.runModal() == .OK, let url = painel.url else { return }
    try? pdf.write(to: url)
}
