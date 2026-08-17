import Foundation
import SwiftUI
import AppKit

/// Ponto ÚNICO de geração da folha como imagem/PNG. Folha adulta dos 4 modelos suportados
/// (770/120/270/370S) sai do MOTOR ORIGINAL (EngineSheet); água/criança e o fallback usam o
/// desenho nativo SwiftUI (FolhaResultado). Todo caminho de impressão/exportação passa por aqui.
enum SheetRender {

    /// Exames do paciente do exame `e` p/ trás (mais recente primeiro), p/ o gráfico de histórico.
    static func historico(_ p: Paciente, _ e: Medida) -> [Medida] {
        if let idx = p.exames.firstIndex(where: { $0.data == e.data }) { return Array(p.exames[idx...]) }
        return p.exames
    }

    /// NSImage da folha (motor p/ adulto suportado; nativo caso contrário ou se o motor falhar).
    @MainActor static func imagem(_ p: Paciente, _ e: Medida, tipo: TipoFolha, scale: CGFloat = 3) -> NSImage? {
        if EngineSheet.suportado(e.equip, tipo),
           let img = EngineSheet.render(e, p, historico: historico(p, e), tipo: tipo) {
            return img
        }
        let r = ImageRenderer(content: FolhaResultado(paciente: p, e: e, tipo: tipo))
        r.scale = scale
        return r.nsImage
    }

    /// PNG da folha.
    @MainActor static func png(_ p: Paciente, _ e: Medida, tipo: TipoFolha, scale: CGFloat = 3) -> Data? {
        guard let img = imagem(p, e, tipo: tipo, scale: scale),
              let tiff = img.tiffRepresentation, let bmp = NSBitmapImageRep(data: tiff)
        else { return nil }
        return bmp.representation(using: .png, properties: [:])
    }

    /// PDF de 1 página da folha (imagem do motor/nativo). Para exportar/e-mail.
    @MainActor static func pdfData(_ p: Paciente, _ e: Medida, tipo: TipoFolha) -> Data? {
        guard let img = imagem(p, e, tipo: tipo),
              let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let data = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: cg.width, height: cg.height)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let ctx = CGContext(consumer: consumer, mediaBox: &box, nil) else { return nil }
        ctx.beginPDFPage(nil); ctx.draw(cg, in: box); ctx.endPDFPage(); ctx.closePDF()
        return data as Data
    }
}

/// View de preview: mostra a folha do MOTOR (assíncrono, fora da main thread) e cai no
/// desenho nativo se o motor não suportar/falhar. Usada nas telas de visualização.
struct FolhaEngineView: View {
    let paciente: Paciente
    let e: Medida
    var tipo: TipoFolha = .adulto
    @State private var img: NSImage?
    @State private var pronto = false

    var body: some View {
        ZStack {
            if let img {
                // mesmo tamanho da folha nativa (826,67 × 1169,33 = A4/3), senão estoura no ScrollView
                Image(nsImage: img).resizable()
                    .frame(width: 2480.0 / 3.0, height: 3508.0 / 3.0)
            } else if !pronto {
                ProgressView("Gerando folha…").frame(maxWidth: .infinity, minHeight: 500)
            } else {
                FolhaResultado(paciente: paciente, e: e, tipo: tipo)   // reserva nativa
            }
        }
        .task(id: "\(e.data)|\(tipo)|\(Idioma.atual.rawValue)") {
            pronto = false; img = nil
            let p = paciente, ex = e, t = tipo
            let hist = SheetRender.historico(p, ex)
            img = await Task.detached { EngineSheet.render(ex, p, historico: hist, tipo: t) }.value
            pronto = true
        }
    }
}
