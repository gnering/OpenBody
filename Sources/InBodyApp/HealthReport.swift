import SwiftUI

/// Health Report : InBody (manual p.57-60). Cabeçalho azul, Recent/Total,
/// gráficos de tendência por métrica com interpretação, botão Results Sheet.
struct HealthReportView: View {
    @EnvironmentObject var store: Store
    let paciente: Paciente
    var aoFechar: () -> Void

    @State private var mostrarInterpretacao = true
    @State private var modoTotal = false

    private let azul = Color(red: 0.16, green: 0.24, blue: 0.42)

    private struct Metrica { let nome: String; let unidade: String; let valor: (Medida) -> Double; let interp: String; var casas: Int = 1 }

    /// Criança = idade informada e < 18. Define quais folhas fazem sentido.
    private var ehCrianca: Bool { paciente.idade > 0 && paciente.idade < 18 }

    /// Folhas ofertadas conforme o paciente: adulto NÃO vê "Criança"; criança NÃO vê a adulta.
    /// Água e Histórico servem aos dois.
    private var folhasDisponiveis: [TipoFolha] {
        TipoFolha.allCases.filter { t in
            switch t {
            case .adulto:     return !ehCrianca
            case .pediatrica: return ehCrianca
            default:          return true
            }
        }
    }

    /// Folha realmente usada: se a seleção global não vale p/ este paciente, cai na 1ª válida.
    private var folhaEfetiva: TipoFolha {
        folhasDisponiveis.contains(store.tipoFolha) ? store.tipoFolha : (folhasDisponiveis.first ?? .adulto)
    }

    /// Métricas de evolução exibidas conforme a FOLHA escolhida no seletor do topo.
    /// Trocar a folha troca o conjunto de gráficos (não abre preview nenhum).
    private var metricasAtuais: [Metrica] { metricasPara(folhaEfetiva) }

    private func metricasPara(_ t: TipoFolha) -> [Metrica] {
        switch t {
        case .adulto, .pediatrica:
            return [
                .init(nome: T("Weight"), unidade: "kg", valor: { $0.peso },
                      interp: T("Weight is the sum of the four body composition components: Total Body Water, Protein, Minerals, and Body Fat Mass.")),
                .init(nome: T("Skeletal Muscle Mass"), unidade: "kg", valor: { $0.smm },
                      interp: T("Skeletal muscle mass is the muscle attached to bones and moved voluntarily. It increases with exercise.")),
                .init(nome: T("Body Fat Mass"), unidade: "kg", valor: { $0.gordura },
                      interp: T("Body fat mass is the sum of subcutaneous fat, visceral fat, and fat around the muscles.")),
                .init(nome: T("Percent Body Fat"), unidade: "%", valor: { $0.pgc },
                      interp: T("Percent body fat is the ratio of body fat mass to body weight.")),
            ]
        case .agua:
            return [
                .init(nome: T("Total Body Water"), unidade: "L", valor: { $0.tbw },
                      interp: T("Total Body Water is the sum of the water inside and outside the cells.")),
                .init(nome: T("Intracellular Water"), unidade: "L", valor: { $0.icw },
                      interp: T("Intracellular Water is the water contained inside the body cells.")),
                .init(nome: T("Extracellular Water"), unidade: "L", valor: { $0.ecw },
                      interp: T("Extracellular Water is the water outside the cells (blood and interstitial fluid).")),
                .init(nome: T("ECW/TBW Ratio"), unidade: "", valor: { $0.ecwTbw },
                      interp: T("Ratio of Extracellular Water to Total Body Water. A marker of fluid balance and inflammation."), casas: 3),
            ]
        case .historico:
            return [
                .init(nome: T("Weight"), unidade: "kg", valor: { $0.peso },
                      interp: T("Change in body weight across exams.")),
                .init(nome: T("Skeletal Muscle Mass"), unidade: "kg", valor: { $0.smm },
                      interp: T("Change in skeletal muscle mass.")),
                .init(nome: T("Body Fat Mass"), unidade: "kg", valor: { $0.gordura },
                      interp: T("Change in body fat mass.")),
                .init(nome: T("Percent Body Fat"), unidade: "%", valor: { $0.pgc },
                      interp: T("Change in percent body fat.")),
                .init(nome: T("Body Mass Index"), unidade: "kg/m²", valor: { $0.imc },
                      interp: T("Change in BMI (weight divided by height squared).")),
                .init(nome: T("Visceral Fat"), unidade: "cm²", valor: { $0.gv },
                      interp: T("Change in visceral fat area.")),
            ]
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            barra
            cabecalho
            controles
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(metricasAtuais.indices, id: \.self) { i in graficoMetrica(metricasAtuais[i]) }
                }.padding(16)
            }
        }
        .frame(width: 720, height: 600)
        .background(Color.white).foregroundStyle(.black)
    }

    private var barra: some View {
        HStack {
            Text(T("Health Report : InBody")).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
            Spacer()
            Button { aoFechar() } label: { Image(systemName: "xmark").foregroundStyle(.white) }.buttonStyle(.plain)
        }.padding(.horizontal, 12).padding(.vertical, 8).background(azul)
    }

    private var cabecalho: some View {
        HStack(spacing: 0) {
            campoCab("Name", paciente.nome)
            campoCab("ID", paciente.id)
            campoCab("Height", "\(Int(paciente.altura))cm")
            campoCab("Age", "\(paciente.idade)")
            campoCab("Gender", paciente.sexo == "F" ? "Female" : "Male")
            Spacer()
            // Seletor troca a FOLHA = troca o conjunto de gráficos de evolução mostrados.
            // Não abre preview nenhum.
            Menu {
                ForEach(folhasDisponiveis) { t in
                    Button(t.nomePT) { store.tipoFolha = t }
                }
            } label: {
                Text(folhaEfetiva.nomePT).font(.system(size: 11)).lineLimit(1)
                    .padding(.horizontal, 8).frame(height: 26)
                    .background(RoundedRectangle(cornerRadius: 3).stroke(Color.gray.opacity(0.4)))
            }.menuStyle(.borderlessButton).fixedSize()
        }.padding(.horizontal, 12).padding(.vertical, 8)
    }
    private func campoCab(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(T(k)).font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
            Text(T(v)).font(.system(size: 11, weight: .medium))
        }.frame(minWidth: 70, alignment: .leading)
    }

    private var controles: some View {
        HStack {
            Spacer()
            Button { mostrarInterpretacao.toggle() } label: {
                Text(mostrarInterpretacao ? T("Hide interpretation") : T("Show interpretation"))
                    .font(.system(size: 11)).frame(width: 150, height: 24)
                    .background(RoundedRectangle(cornerRadius: 3).stroke(Color.gray.opacity(0.4)))
            }.buttonStyle(.plain)
            HStack(spacing: 0) {
                toggleBtn("Recent", !modoTotal) { modoTotal = false }
                toggleBtn("Total", modoTotal) { modoTotal = true }
            }.overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.gray.opacity(0.4)))
        }.padding(.horizontal, 12).padding(.bottom, 6)
    }
    private func toggleBtn(_ t: String, _ on: Bool, _ acao: @escaping () -> Void) -> some View {
        Button(action: acao) {
            Text(T(t)).font(.system(size: 11)).frame(width: 50, height: 22)
                .background(on ? Color.accentColor : Color.clear)
                .foregroundStyle(on ? .white : .primary)
        }.buttonStyle(.plain)
    }

    /// DATETIMES/ISO do exame -> "dd/MM/aa" para o eixo do gráfico.
    private func dataCurta(_ raw: String) -> String {
        let inp = DateFormatter(); inp.locale = Locale(identifier: "en_US_POSIX")
        for f in ["yyyyMMddHHmmss", "yyyy/MM/dd HH:mm:ss", "yyyy/MM/dd HH:mm"] {
            inp.dateFormat = f
            if let d = inp.date(from: raw) {
                let out = DateFormatter(); out.locale = Locale(identifier: "pt_BR"); out.dateFormat = "dd/MM/yy"
                return out.string(from: d)
            }
        }
        return raw
    }

    private func graficoMetrica(_ m: Metrica) -> some View {
        // Recente = últimos 8 exames (detalhado); Total = todos (tendência longa).
        let exames = modoTotal ? paciente.exames : Array(paciente.exames.prefix(8))
        // Série do MAIS ANTIGO (esquerda) ao MAIS RECENTE (direita).
        let serie = exames.reversed().map { (v: m.valor($0), data: dataCurta($0.data)) }
        let pts = serie.map { $0.v }
        let atual = pts.last ?? 0
        let n = pts.count
        // Índices a rotular (valor+data). Poucos: todos. Muitos: ~7 espaçados + sempre o último.
        let rotulados: Set<Int> = {
            if n <= 10 { return Set(0..<n) }
            let passo = max(1, n / 7)
            var s = Set(stride(from: 0, to: n, by: passo)); s.insert(n - 1); return s
        }()
        return VStack(alignment: .leading, spacing: 6) {
            Text("\(m.nome) ").font(.system(size: 13, weight: .bold))
                + Text("(\(m.unidade))").font(.system(size: 11)).foregroundStyle(.secondary)
            GeometryReader { geo in
                let mn = (pts.min() ?? 0) * 0.92, mx = (pts.max() ?? 1) * 1.08
                let w = geo.size.width, h = geo.size.height
                let esq: CGFloat = 34, base = h - 22          // base acima da faixa de datas
                let passo = n <= 1 ? 0 : (w - esq - 8) / CGFloat(max(n - 1, 1))
                let px: (Int) -> CGFloat = { i in esq + CGFloat(i) * passo }
                let py: (Double) -> CGFloat = { v in mx > mn ? base - (v - mn)/(mx - mn) * (base - 18) : base/2 }
                ZStack(alignment: .topLeading) {
                    Rectangle().fill(Color.gray.opacity(0.25)).frame(height: 1).offset(y: base)
                    // linha da evolução (todos os pontos)
                    if n >= 1 {
                        Path { p in
                            for (i, v) in pts.enumerated() {
                                let pt = CGPoint(x: px(i), y: py(v))
                                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                            }
                        }.stroke(Color.black.opacity(0.55), lineWidth: 1.5)
                    }
                    // pontos rotulados: bolinha + valor (em cima) + data (embaixo). Atual em vermelho.
                    ForEach(Array(serie.enumerated()), id: \.offset) { i, s in
                        if rotulados.contains(i) {
                            let ehAtual = (i == n - 1)
                            Circle().fill(ehAtual ? .red : Color.black.opacity(0.55))
                                .frame(width: ehAtual ? 7 : 5, height: ehAtual ? 7 : 5)
                                .offset(x: px(i) - (ehAtual ? 3.5 : 2.5), y: py(s.v) - (ehAtual ? 3.5 : 2.5))
                            Text(String(format: "%.\(m.casas)f", s.v))
                                .font(.system(size: ehAtual ? 13 : 9, weight: ehAtual ? .bold : .regular))
                                .foregroundStyle(ehAtual ? .red : .primary).fixedSize()
                                .offset(x: min(max(px(i) - 14, 0), w - 32), y: max(0, py(s.v) - (ehAtual ? 22 : 15)))
                            Text(s.data).font(.system(size: 8)).foregroundStyle(.secondary).fixedSize()
                                .offset(x: min(max(px(i) - 16, 0), w - 42), y: base + 4)
                        }
                    }
                }
            }.frame(height: 100)
            Text(T("Recent Results : ")).font(.system(size: 11, weight: .semibold))
                + Text(String(format: "%.\(m.casas)f %@", atual, m.unidade)).font(.system(size: 13, weight: .bold)).foregroundStyle(.red)
            if mostrarInterpretacao {
                Text(T("Results Interpretation: ")).font(.system(size: 10, weight: .semibold))
                    + Text(m.interp).font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
    }
}
