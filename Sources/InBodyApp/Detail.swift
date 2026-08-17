import SwiftUI

enum ModoVista: String, CaseIterable { case painel = "Panel", folha = "Results Sheet" }

struct DetalhePaciente: View {
    let paciente: Paciente
    @State private var modo: ModoVista = .painel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("", selection: $modo) {
                    ForEach(ModoVista.allCases, id: \.self) { Text(T($0.rawValue)).tag($0) }
                }.pickerStyle(.segmented).frame(width: 300)
                Spacer()
                if modo == .folha, let e = paciente.ultimo {
                    Button { imprimirFolha(paciente: paciente, medida: e) } label: {
                        Label(T("Print"), systemImage: "printer")
                    }
                    Button { comporEmailComFolha(paciente: paciente, medida: e, para: paciente.email) } label: {
                        Label(T("Email"), systemImage: "envelope")
                    }
                    Button { exportarPDF(paciente: paciente, medida: e) } label: {
                        Label(T("Export PDF"), systemImage: "arrow.down.doc")
                    }
                }
            }.padding(.horizontal, 22).padding(.vertical, 10)
            Divider()
            ScrollView {
                if let e = paciente.ultimo {
                    if modo == .painel {
                        VStack(alignment: .leading, spacing: 16) {
                            cabecalho(e)
                            composicao(e)
                            HStack(alignment: .top, spacing: 16) { indices(e); agua(e) }
                            segmentar(e)
                            if paciente.exames.count > 1 { historico() }
                        }.padding(22)
                    } else {
                        FolhaEngineView(paciente: paciente, e: e).padding(22)
                    }
                }
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }

    func cabecalho(_ e: Medida) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(paciente.nome).font(.system(size: 22, weight: .bold))
            Text("\(paciente.sexo == "F" ? T("Female") : T("Male")) · \(paciente.idade) \(T("yrs")) · \(Int(paciente.altura)) cm · \(T("measured on")) \(dataBR(e.data))")
                .font(.system(size: 13)).foregroundStyle(.secondary)
        }
    }

    func composicao(_ e: Medida) -> some View {
        Cartao(titulo: T("Body composition"),
               dica: T("The full bar is the measured value. The tick marks the lower bound of the range.")) {
            VStack(spacing: 0) {
                BarraComposicao(titulo: T("Body water"), sub: T("intra + extracellular"),
                                valor: e.tbw, unidade: "L", ref: e.refTbw, cor: .water)
                Divider()
                BarraComposicao(titulo: T("Fat Free Mass"), sub: T("everything but fat"),
                                valor: e.ffm, unidade: "kg", ref: e.refFfm, cor: .lean)
                Divider()
                BarraComposicao(titulo: T("Muscle mass"), sub: T("skeletal"),
                                valor: e.smm, unidade: "kg", ref: e.refSmm, cor: .lean)
                Divider()
                BarraComposicao(titulo: T("Body Fat Mass"), sub: T("adipose tissue"),
                                valor: e.gordura, unidade: "kg", ref: e.refGordura, cor: .fat)
            }
        }
    }

    func indices(_ e: Medida) -> some View {
        Cartao(titulo: T("Indices"), dica: T("Quick read of the exam.")) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                KPI(titulo: T("BMI"), valor: String(format: "%.1f", e.imc), unidade: "kg/m²")
                KPI(titulo: T("Fat"), valor: String(format: "%.1f", e.pgc), unidade: T("% of weight"))
                KPI(titulo: T("Lean mass"), valor: String(format: "%.1f", e.ffm), unidade: "kg")
                KPI(titulo: T("Metabolism"), valor: String(format: "%.0f", e.tmb), unidade: T("basal kcal"))
                KPI(titulo: T("Visceral fat"), valor: String(format: "%.0f", e.gv), unidade: "cm²")
                KPI(titulo: T("Waist-hip"), valor: String(format: "%.2f", e.rcq), unidade: "WHR")
            }
        }
        .frame(maxWidth: .infinity)
    }

    func agua(_ e: Medida) -> some View {
        let cls: Color = e.ecwTbw > 0.390 ? .high : (e.ecwTbw < 0.360 ? .low : .okc)
        let rot = e.ecwTbw > 0.390 ? "Retention" : (e.ecwTbw < 0.360 ? "Low" : "Balance")
        return Cartao(titulo: T("Water balance"), dica: T("Extracellular / total water ratio.")) {
            VStack(alignment: .leading, spacing: 10) {
                Text(String(format: "%.3f", e.ecwTbw))
                    .font(.system(size: 34, weight: .bold)).monospacedDigit().foregroundStyle(cls)
                Text(T(rot)).font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Capsule().fill(cls.opacity(0.16))).foregroundStyle(cls)
                HStack {
                    Label(String(format: "ICW %.1f L", e.icw), systemImage: "drop.fill").foregroundStyle(Color.water)
                    Spacer()
                    Label(String(format: "ECW %.1f L", e.ecw), systemImage: "drop").foregroundStyle(.secondary)
                }.font(.system(size: 12))
            }
        }
        .frame(maxWidth: .infinity)
    }

    func segmentar(_ e: Medida) -> some View {
        let nomes = ["RA": T("Right Arm"), "LA": T("Left Arm"), "TR": T("Trunk"),
                     "RL": T("Right Leg"), "LL": T("Left Leg")]
        return Cartao(titulo: T("Segmental lean mass analysis"),
                      dica: T("Lean mass per segment, in kilos and % of expected.")) {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    SegmentoCard(nome: nomes["LA"]!, kg: e.seg["LA"] ?? 0, pct: e.segp["LA"] ?? 0)
                    SegmentoCard(nome: nomes["RA"]!, kg: e.seg["RA"] ?? 0, pct: e.segp["RA"] ?? 0)
                }
                SegmentoCard(nome: nomes["TR"]!, kg: e.seg["TR"] ?? 0, pct: e.segp["TR"] ?? 0)
                    .frame(maxWidth: 260)
                HStack(spacing: 10) {
                    SegmentoCard(nome: nomes["LL"]!, kg: e.seg["LL"] ?? 0, pct: e.segp["LL"] ?? 0)
                    SegmentoCard(nome: nomes["RL"]!, kg: e.seg["RL"] ?? 0, pct: e.segp["RL"] ?? 0)
                }
            }
        }
    }

    func historico() -> some View {
        Cartao(titulo: T("History"), dica: T("Change across measurements.")) {
            GraficoHistorico(exames: paciente.exames)
        }
    }
}

struct GraficoHistorico: View {
    let exames: [Medida]
    var body: some View {
        let pts = exames.reversed().map { $0 }
        let series: [(String, Color, (Medida) -> Double)] = [
            (T("Lean mass"), .lean, { $0.ffm }),
            (T("Fat"), .fat, { $0.gordura }),
            (T("Water"), .water, { $0.tbw }),
        ]
        let todos = series.flatMap { s in pts.map { s.2($0) } }
        let mn = (todos.min() ?? 0) * 0.9, mx = (todos.max() ?? 1) * 1.05
        return VStack(alignment: .leading, spacing: 10) {
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                let x: (Int) -> Double = { i in pts.count <= 1 ? w/2 : 8 + Double(i) * (w - 16) / Double(pts.count - 1) }
                let y: (Double) -> Double = { v in h - 8 - (v - mn) / (mx - mn) * (h - 16) }
                ZStack {
                    ForEach(series.indices, id: \.self) { si in
                        let s = series[si]
                        Path { p in
                            for (i, m) in pts.enumerated() {
                                let pt = CGPoint(x: x(i), y: y(s.2(m)))
                                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                            }
                        }.stroke(s.1, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        ForEach(pts.indices, id: \.self) { i in
                            Circle().fill(Color(nsColor: .controlBackgroundColor))
                                .overlay(Circle().stroke(s.1, lineWidth: 2.5))
                                .frame(width: 8, height: 8)
                                .position(x: x(i), y: y(s.2(pts[i])))
                        }
                    }
                }
            }.frame(height: 170)
            HStack(spacing: 16) {
                ForEach(series.indices, id: \.self) { si in
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 2).fill(series[si].1).frame(width: 10, height: 10)
                        Text(series[si].0).font(.system(size: 11.5)).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
