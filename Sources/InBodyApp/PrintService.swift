import SwiftUI
import AppKit

/// Impressao direta da folha de resultado (E6). Reusa a MESMA renderizacao ja provada
/// (FolhaResultado -> ImageRenderer), entao o que sai na impressora e a folha fiel.
/// Regua: sem margem, retrato, cada folha ocupa uma pagina inteira (escala proporcional).
/// NOTA: o resultado impresso so pode ser conferido numa impressora real; aqui garante-se
/// que a IMAGEM impressa e a mesma do PDF provado.

/// Impressora escolhida em Setup > A-02. nil = usa a padrão do sistema.
enum ImpressoraEscolhida {
    private static let chave = "InBodyMac.impressora"
    static func carregar() -> String? { UserDefaults.standard.string(forKey: chave) }
    static func salvar(_ nome: String?) {
        if let nome { UserDefaults.standard.set(nome, forKey: chave) }
        else { UserDefaults.standard.removeObject(forKey: chave) }
    }
}

/// Uma folha a imprimir.
struct FolhaParaImprimir {
    let paciente: Paciente
    let medida: Medida
    let tipo: TipoFolha
}

/// Imprime uma ou mais folhas num job so (uma folha por pagina). `dialogo`:
/// true = abre o diálogo padrão do macOS (o usuário escolhe a impressora de rede,
/// cópias etc.); false = imprime CALADO na impressora padrão (usado no automático
/// pós-exame, como o Windows).
@MainActor
func imprimirFolhas(_ folhas: [FolhaParaImprimir], dialogo: Bool = true, copias: Int = 1) {
    guard !folhas.isEmpty else { return }
    // Motor original pros modelos suportados; nativo como reserva. MESMA folha da tela/exportação.
    let base: [NSImage] = folhas.compactMap { f in
        SheetRender.imagem(f.paciente, f.medida, tipo: f.tipo)
    }
    guard !base.isEmpty else { return }
    // Cópias: no automático (sem diálogo) repete o conjunto N vezes; no diálogo o
    // usuário escolhe cópias na própria caixa do macOS, então não duplicamos aqui.
    let vezes = dialogo ? 1 : max(1, copias)
    let imagens = Array(repeating: base, count: vezes).flatMap { $0 }

    let info = (NSPrintInfo.shared.copy() as? NSPrintInfo) ?? NSPrintInfo.shared
    info.topMargin = 0; info.bottomMargin = 0; info.leftMargin = 0; info.rightMargin = 0
    info.horizontalPagination = .fit          // largura: encaixa na pagina
    info.verticalPagination = .automatic      // altura: quebra por pagina (1 folha/pagina)
    info.isHorizontallyCentered = true
    info.isVerticallyCentered = false
    // Paisagem quando TODAS as folhas do job são paisagem (folha de Histórico).
    info.orientation = folhas.allSatisfy(\.tipo.paisagem) ? .landscape : .portrait
    // Impressora escolhida em Setup > A-02 (importa no automático, que não abre diálogo).
    if let nome = ImpressoraEscolhida.carregar(), let pr = NSPrinter(name: nome) {
        info.printer = pr
    }

    let view = FolhasPrintView(imagens: imagens, pageSize: info.paperSize)
    let op = NSPrintOperation(view: view, printInfo: info)
    op.jobTitle = "InBody"
    if !dialogo {
        op.showsPrintPanel = false            // automático: sem caixa de diálogo
        op.showsProgressPanel = false
    }
    op.run()
}

@MainActor
func imprimirFolha(paciente: Paciente, medida: Medida, tipo: TipoFolha = .adulto) {
    imprimirFolhas([FolhaParaImprimir(paciente: paciente, medida: medida, tipo: tipo)])
}

/// Monta as folhas de um exame para os tipos escolhidos (na ordem canônica das folhas).
@MainActor
func folhasDoExame(_ paciente: Paciente, _ medida: Medida, tipos: Set<TipoFolha>) -> [FolhaParaImprimir] {
    TipoFolha.allCases
        .filter { tipos.contains($0) }
        .map { FolhaParaImprimir(paciente: paciente, medida: medida, tipo: $0) }
}

/// NSView paginada: uma imagem por pagina (padrao canonico knowsPageRange/rectForPage).
/// Flipped para a pagina 1 ficar no topo.
private final class FolhasPrintView: NSView {
    let imagens: [NSImage]
    let pageSize: NSSize
    init(imagens: [NSImage], pageSize: NSSize) {
        self.imagens = imagens
        self.pageSize = pageSize
        super.init(frame: NSRect(x: 0, y: 0, width: pageSize.width, height: pageSize.height * CGFloat(imagens.count)))
    }
    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }

    override func knowsPageRange(_ range: NSRangePointer) -> Bool {
        range.pointee = NSRange(location: 1, length: imagens.count)
        return true
    }
    override func rectForPage(_ page: Int) -> NSRect {
        NSRect(x: 0, y: CGFloat(page - 1) * pageSize.height, width: pageSize.width, height: pageSize.height)
    }
    override func draw(_ dirtyRect: NSRect) {
        // Ajuste fino de alinhamento (Setup A-03), em pontos. Flipped: +dy = para baixo.
        let dx = CGFloat(AlinhamentoImpressao.dxPt), dy = CGFloat(AlinhamentoImpressao.dyPt)
        for (i, img) in imagens.enumerated() {
            let destino = NSRect(x: 0, y: CGFloat(i) * pageSize.height, width: pageSize.width, height: pageSize.height)
            guard destino.intersects(dirtyRect) else { continue }
            // escala proporcional, centrada na largura
            let escala = min(pageSize.width / img.size.width, pageSize.height / img.size.height)
            let w = img.size.width * escala, h = img.size.height * escala
            let x = (pageSize.width - w) / 2
            img.draw(in: NSRect(x: x + dx, y: destino.minY + dy, width: w, height: h))
        }
    }
}
