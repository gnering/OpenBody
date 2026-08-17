import SwiftUI
import AppKit

/// Tabela de pacientes com colunas redimensionáveis (estilo Excel).
///
/// Desenho:
/// - Cada coluna tem largura PRÓPRIA (nada de dividir o espaço). Alargar uma coluna
///   só empurra as outras pro lado; nunca espreme nem quebra o texto das vizinhas.
/// - Quando a soma passa da largura do painel, entra ROLAGEM HORIZONTAL.
/// - Cabeçalho e linhas usam a MESMA largura por coluna, então sempre batem.
/// - É um componente isolado (State próprio): arrastar a divisa só redesenha a tabela,
///   por isso fica fluido mesmo com centenas de linhas.
struct TabelaPacientes: View {
    @EnvironmentObject var store: Store

    let onInfo: (Paciente.ID) -> Void
    let onInBody: (Paciente.ID) -> Void
    let onPressao: (Paciente.ID) -> Void
    let onGlicose: (Paciente.ID) -> Void

    private enum Col: String, CaseIterable { case nome, id, altura, idade, sexo, membro, saude }
    // Larguras de fabrica: Nome e ID largos o
    // suficiente pra nome completo e ID do InBody sem truncar.
    private static let padrao: [Col: CGFloat] = [
        .nome: 360, .id: 154, .altura: 80, .idade: 60, .sexo: 64, .membro: 130, .saude: 220,
    ]
    private let colCheck: CGFloat = 44
    private let minCol: CGFloat = 44
    private let maxCol: CGFloat = 600

    @State private var larg: [Col: CGFloat] = TabelaPacientes.padrao
    // Enquanto arrasta a divisa: NÃO mexemos nas larguras (a lista fica parada = fluido).
    // Só guardamos qual coluna e o deslocamento, e mostramos uma linha-guia deslizando.
    // A largura muda de fato quando solta (como o Excel clássico).
    @State private var dragCol: Col? = nil
    @State private var dragDX: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            // Quando as colunas somam menos que a janela, a tabela estica até
            // preencher a largura disponível (o fundo branco toma o painel todo,
            // sem sobrar vazio que muda ao mexer nas colunas). Quando somam mais,
            // usa a largura do conteúdo e a rolagem horizontal aparece.
            let largura = max(larguraTotal, geo.size.width)
            ScrollView(.horizontal, showsIndicators: true) {
                VStack(spacing: 0) {
                    cabecalho
                    ScrollView(.vertical) {
                        LazyVStack(spacing: 0) {
                            ForEach(store.filtrados, id: \.chave) { linha($0) }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white)
                    .overlay(Rectangle().stroke(Color.gray.opacity(0.2)))
                }
                .frame(width: largura, alignment: .leading)
                .overlay(alignment: .topLeading) { guiaArrasto }
            }
            .frame(maxHeight: .infinity)
        }
        .onAppear(perform: carregar)
    }

    private var larguraTotal: CGFloat {
        colCheck + Col.allCases.reduce(0) { $0 + (larg[$1] ?? 0) } + 16
    }

    // MARK: - Cabeçalho

    private var cabecalho: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: colCheck, height: 1)   // coluna do seletor (seleção única)
            celulaCab("Name", .nome, .leading)
            celulaCab("ID", .id, .leading)
            celulaCab("Height (cm)", .altura)
            celulaCab("Age", .idade)
            celulaCab("Gender", .sexo)
            celulaCab("Member Info.", .membro)
            celulaCab("Health Report", .saude, .leading)
        }
        .font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
        .padding(.horizontal, 8).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.10))
    }

    /// Só Nome e ID podem ser redimensionados; o resto é fixo.
    private static let ajustaveis: Set<Col> = [.nome, .id]

    /// Título; se a coluna for ajustável, ganha a divisa arrastável à direita. A
    /// largura/alinhamento são idênticos aos da célula da linha, então sempre batem.
    private func celulaCab(_ titulo: String, _ col: Col, _ align: Alignment = .center) -> some View {
        Text(T(titulo)).lineLimit(1).minimumScaleFactor(0.85).truncationMode(.tail)
            .frame(width: larg[col] ?? 0, alignment: align)
            .overlay(alignment: .trailing) {
                if TabelaPacientes.ajustaveis.contains(col) { alca(col) }
            }
    }

    /// Pega de redimensionar: barrinha cinza visível na divisa direita, com área de clique
    /// larga. Passe o mouse que o cursor vira seta dupla; arraste pra mudar a largura.
    private func alca(_ col: Col) -> some View {
        ZStack {
            Color.clear.frame(width: 16)
            Capsule().fill(Color.gray.opacity(0.55)).frame(width: 4, height: 20)
        }
        .contentShape(Rectangle())
        .onHover { dentro in
            if dentro { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
        }
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { v in
                    dragCol = col
                    let atual = larg[col] ?? 0
                    let alvo = min(maxCol, max(minCol, atual + v.translation.width))
                    dragDX = alvo - atual            // só a guia se move; a lista fica parada
                }
                .onEnded { _ in
                    if let c = dragCol {
                        larg[c] = min(maxCol, max(minCol, (larg[c] ?? 0) + dragDX))
                    }
                    dragCol = nil; dragDX = 0; salvar()
                }
        )
    }

    /// Linha-guia vertical que desliza enquanto você arrasta (feedback fluido, sem
    /// recalcular as linhas). Ao soltar, a coluna assume a largura onde a guia parou.
    @ViewBuilder private var guiaArrasto: some View {
        if let c = dragCol {
            Rectangle().fill(Color.accentColor)
                .frame(width: 2).frame(maxHeight: .infinity)
                .offset(x: 8 + colCheck + somaAte(c) + dragDX - 1)
                .allowsHitTesting(false)
        }
    }

    /// Soma das larguras da primeira coluna até `col` (inclusive) — dá o x da divisa direita.
    private func somaAte(_ col: Col) -> CGFloat {
        var s: CGFloat = 0
        for c in Col.allCases { s += larg[c] ?? 0; if c == col { break } }
        return s
    }

    // MARK: - Linha

    private func linha(_ p: Paciente) -> some View {
        let marcado = store.selecionados.contains(p.chave)
        let destacado = store.selecionado == p.id
        let temPressao = store.monitorPressaoConectado || !p.pressoes.isEmpty
        let temGlicose = !p.glicoses.isEmpty
        return HStack(spacing: 0) {
            Button {
                // Seleção ÚNICA: marcar um paciente limpa os demais (só 1 por vez).
                if store.selecionados.contains(p.chave) { store.selecionados.removeAll() }
                else { store.selecionados = [p.chave] }
                store.selecionado = p.id
            } label: {
                Image(systemName: marcado ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(marcado ? Color.accentColor : .secondary)
                    .frame(width: colCheck)
            }.buttonStyle(.plain)
            Text(p.nome).frame(width: larg[.nome] ?? 0, alignment: .leading).lineLimit(1).truncationMode(.tail)
            Text(p.id).frame(width: larg[.id] ?? 0, alignment: .leading).foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.tail)
            Text(p.altura > 0 ? "\(Int(p.altura))" : "—").frame(width: larg[.altura] ?? 0)
            Text(p.idade > 0 ? "\(p.idade)" : "—").frame(width: larg[.idade] ?? 0)
            Text(p.sexo.isEmpty ? "—" : p.sexo).frame(width: larg[.sexo] ?? 0)
            botao(T("Member Info.")) { onInfo(p.id) }.frame(width: larg[.membro] ?? 0)
            HStack(spacing: 4) {
                botao(T("InBody")) { onInBody(p.id) }
                if temPressao { botao(T("Pressão")) { onPressao(p.id) } }
                if temGlicose { botao(T("Glicose")) { onGlicose(p.id) } }
                Spacer(minLength: 0)
            }.frame(width: larg[.saude] ?? 0, alignment: .leading)
        }
        .font(.system(size: 15))
        .padding(.vertical, 8).padding(.horizontal, 8)
        .background(destacado ? Color.accentColor.opacity(0.14) : .clear)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.gray.opacity(0.10)).frame(height: 1) }
        .contentShape(Rectangle())
        .onTapGesture { store.selecionado = p.id }
    }

    private func botao(_ t: String, _ acao: @escaping () -> Void) -> some View {
        Button(action: acao) {
            Text(t).font(.system(size: 11)).foregroundStyle(.blue).lineLimit(1)
                .padding(.horizontal, 8).frame(height: 24)
                .background(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.35)))
        }.buttonStyle(.plain)
    }

    // MARK: - Persistência (guarda entre aberturas)

    private func salvar() {
        let d = UserDefaults.standard
        for c in Col.allCases { d.set(Double(larg[c] ?? 0), forKey: "col2.\(c.rawValue)") }
    }

    private func carregar() {
        let d = UserDefaults.standard
        for c in Col.allCases {
            let k = "col2.\(c.rawValue)"
            guard d.object(forKey: k) != nil else { continue }
            larg[c] = min(maxCol, max(minCol, CGFloat(d.double(forKey: k))))
        }
    }
}
