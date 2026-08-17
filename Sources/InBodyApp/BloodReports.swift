import SwiftUI

/// Health Report : Blood Pressure (manual p.61-62).
/// Gráfico sistólica/diastólica + carta de categorias de hipertensão.
struct BloodPressureReportView: View {
    let paciente: Paciente
    var aoFechar: () -> Void
    @State private var modoTotal = false
    private let azul = Color(red: 0.16, green: 0.24, blue: 0.42)

    // Leituras reais do membro (do monitor / Edit), ordenadas por data crescente.
    private var leituras: [LeituraPressao] {
        let ord = paciente.pressoes.sorted { $0.data < $1.data }
        return modoTotal ? ord : Array(ord.suffix(14))
    }
    private var sistolica: Int? { leituras.last?.sistolica }
    private var diastolica: Int? { leituras.last?.diastolica }

    var body: some View {
        VStack(spacing: 0) {
            HealthHeaderBar(titulo: "Health Report : Blood Pressure", paciente: paciente,
                            rotuloFolha: "Blood Pressure\nResults Sheet", aoFechar: aoFechar, cor: azul)
            HStack {
                Spacer()
                Button(T("Hide Interpretation")) {}.buttonStyle(.plain).font(.system(size: 11))
                    .frame(width: 130, height: 24).overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.gray.opacity(0.4)))
                RecentTotalToggle(total: $modoTotal)
            }.padding(.horizontal, 12).padding(.vertical, 6)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(T("Systolic/Diastolic Blood Pressure ")).font(.system(size: 13, weight: .bold))
                        + Text(T("(mmHg)")).font(.system(size: 11)).foregroundStyle(.secondary)

                    if leituras.isEmpty {
                        estadoVazio("No readings yet. Readings come from the blood pressure monitor or from Edit.")
                    } else {
                        TendenciaGrafico(pontos: leituras.map { (rotuloData($0.data), Double($0.sistolica)) },
                                         sufixo: "", cor: azul)
                        TendenciaGrafico(pontos: leituras.map { (rotuloData($0.data), Double($0.diastolica)) },
                                         sufixo: "", cor: .teal)
                    }

                    HStack(spacing: 4) {
                        Text(T("Recent Results :")).font(.system(size: 11, weight: .semibold))
                        Text(T("Systolic")).font(.system(size: 10)).foregroundStyle(.secondary)
                        Text(sistolica.map { "\($0)" } ?? "—").font(.system(size: 12, weight: .bold)).foregroundStyle(.red)
                        Text(T("mmHg  Diastolic")).font(.system(size: 10)).foregroundStyle(.secondary)
                        Text(diastolica.map { "\($0)" } ?? "—").font(.system(size: 12, weight: .bold)).foregroundStyle(.red)
                        Text(T("mmHg")).font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    if let s = sistolica, let d = diastolica {
                        Text("\(T("Category:")) \(categoria(s, d))").font(.system(size: 11, weight: .semibold))
                    }
                    cartaHipertensao
                }.padding(16)
            }
        }
        .frame(width: 640, height: 620).background(Color.white).foregroundStyle(.black)
    }

    private func rotuloData(_ s: String) -> String { String(s.prefix(10)) }

    private func categoria(_ s: Int, _ d: Int) -> String {
        if s >= 160 || d >= 100 { return "Stage 2 Hypertension" }
        if s >= 140 || d >= 90 { return "Stage 1 Hypertension" }
        if s >= 120 || d >= 80 { return "Prehypertension" }
        return "Normal"
    }

    private func estadoVazio(_ t: String) -> some View {
        Text(T(t)).font(.system(size: 11)).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.05)))
    }

    // Carta de categorias: eixo X sistólica (110-190), Y diastólica (70-110), com ponto plotado.
    private var cartaHipertensao: some View {
        // limiares reais em fração do eixo
        let sxMin = 110.0, sxMax = 190.0, dyMin = 70.0, dyMax = 110.0
        return GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let plotL: CGFloat = 34, plotB: CGFloat = 18
            let pw = w - plotL, ph = h - plotB
            let fx: (Double) -> CGFloat = { plotL + CGFloat(($0 - sxMin) / (sxMax - sxMin)) * pw }
            let fy: (Double) -> CGFloat = { (h - plotB) - CGFloat(($0 - dyMin) / (dyMax - dyMin)) * ph }
            ZStack(alignment: .topLeading) {
                // zonas por limiar real (sistólica: 120/140/160 ; diastólica: 80/90/100)
                zonaRect(fx(sxMin), fy(dyMin), fx(120), fy(80), Color.blue.opacity(0.10), "Normal")
                zonaRect(fx(120), fy(dyMin), fx(140), fy(90), Color.green.opacity(0.12), "Prehypertension")
                zonaRect(fx(140), fy(dyMin), fx(160), fy(100), Color.orange.opacity(0.14), "Stage 1")
                zonaRect(fx(160), fy(dyMin), fx(sxMax), fy(dyMax), Color.red.opacity(0.14), "Stage 2")
                // eixos
                Rectangle().fill(Color.gray.opacity(0.4)).frame(width: 1).offset(x: plotL)
                Rectangle().fill(Color.gray.opacity(0.4)).frame(height: 1).offset(y: h - plotB)
                Text(T("Systolic (mmHg)")).font(.system(size: 8)).foregroundStyle(.secondary)
                    .position(x: w/2, y: h - 6)
                // ponto do membro
                if let s = sistolica, let d = diastolica {
                    let x = fx(min(max(Double(s), sxMin), sxMax))
                    let y = fy(min(max(Double(d), dyMin), dyMax))
                    Circle().fill(Color.red).frame(width: 9, height: 9).position(x: x, y: y)
                }
            }
        }.frame(height: 200)
        .overlay(Rectangle().stroke(Color.gray.opacity(0.2)))
    }

    private func zonaRect(_ x0: CGFloat, _ yBottom: CGFloat, _ x1: CGFloat, _ yTop: CGFloat, _ cor: Color, _ t: String) -> some View {
        Rectangle().fill(cor)
            .frame(width: max(0, x1 - x0), height: max(0, yBottom - yTop))
            .offset(x: x0, y: yTop)
            .overlay(Text(T(t)).font(.system(size: 8)).foregroundStyle(.secondary).padding(2)
                .offset(x: x0 + 2, y: yTop + 2), alignment: .topLeading)
    }
}

/// Health Report : Blood Glucose (manual p.63-64).
struct BloodGlucoseReportView: View {
    let paciente: Paciente
    var aoFechar: () -> Void
    @State private var modoTotal = false
    private let azul = Color(red: 0.16, green: 0.24, blue: 0.42)

    private var leituras: [LeituraGlicose] {
        let ord = paciente.glicoses.sorted { $0.data < $1.data }
        return modoTotal ? ord : Array(ord.suffix(14))
    }

    var body: some View {
        VStack(spacing: 0) {
            HealthHeaderBar(titulo: "Health Report : Blood Glucose", paciente: paciente,
                            rotuloFolha: "Blood Glucose\nResults Sheet", aoFechar: aoFechar, cor: azul)
            HStack {
                Spacer()
                Button(T("Hide Interpretation")) {}.buttonStyle(.plain).font(.system(size: 11))
                    .frame(width: 130, height: 24).overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.gray.opacity(0.4)))
                RecentTotalToggle(total: $modoTotal)
            }.padding(.horizontal, 12).padding(.vertical, 6)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    secao("Fasting Blood Glucose", "mg/dL",
                          leituras.compactMap { g in g.jejum.map { (String(g.data.prefix(10)), Double($0)) } },
                          "Fasting Blood Glucose Level is the level of glucose in the blood after eight hours of fasting and is used as a screening test for diabetes.")
                    secao("Blood Glucose 2 Hours after a Meal", "mg/dL",
                          leituras.compactMap { g in g.posPrandial.map { (String(g.data.prefix(10)), Double($0)) } },
                          "Measured two hours after a meal to evaluate the body's ability to process glucose.")
                    if leituras.isEmpty {
                        Text(T("No readings yet. Blood glucose is entered via Edit."))
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }.padding(16)
            }
        }.frame(width: 640, height: 620).background(Color.white).foregroundStyle(.black)
    }

    private func secao(_ nome: String, _ un: String, _ pontos: [(String, Double)], _ interp: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(nome) ").font(.system(size: 13, weight: .bold))
                + Text("(\(un))").font(.system(size: 11)).foregroundStyle(.secondary)
            if pontos.isEmpty {
                Text(T("—")).font(.system(size: 15, weight: .bold)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.05)))
            } else {
                TendenciaGrafico(pontos: pontos, sufixo: "", cor: azul)
            }
            HStack(spacing: 8) {
                categoria("Normal", .green); categoria("Over", .orange); categoria("Extremely Over", .red)
            }
            Text(T("Results Interpretation: ")).font(.system(size: 10, weight: .semibold))
                + Text(T(interp)).font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }
    private func categoria(_ t: String, _ c: Color) -> some View {
        Text(T(t)).font(.system(size: 9)).padding(.horizontal, 8).padding(.vertical, 2)
            .background(c.opacity(0.15)).foregroundStyle(c)
    }
}

/// Gráfico de tendência genérico: linha por data, valor mais recente em vermelho.
struct TendenciaGrafico: View {
    let pontos: [(String, Double)]
    var sufixo: String = ""
    var cor: Color = .blue

    var body: some View {
        let vals = pontos.map { $0.1 }
        let mn = (vals.min() ?? 0) * 0.9
        let mx = (vals.max() ?? 1) * 1.1
        return VStack(spacing: 2) {
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                let x: (Int) -> CGFloat = { i in pontos.count <= 1 ? w/2 : 8 + CGFloat(i) * (w - 16) / CGFloat(pontos.count - 1) }
                let y: (Double) -> CGFloat = { v in mx == mn ? h/2 : h - 16 - CGFloat((v - mn) / (mx - mn)) * (h - 26) }
                ZStack {
                    Path { p in
                        for (i, pt) in pontos.enumerated() {
                            let c = CGPoint(x: x(i), y: y(pt.1))
                            if i == 0 { p.move(to: c) } else { p.addLine(to: c) }
                        }
                    }.stroke(cor.opacity(0.7), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    ForEach(pontos.indices, id: \.self) { i in
                        let ultimo = i == pontos.count - 1
                        Circle().fill(ultimo ? Color.red : cor).frame(width: ultimo ? 8 : 6, height: ultimo ? 8 : 6)
                            .position(x: x(i), y: y(pontos[i].1))
                        if ultimo {
                            Text("\(Int(pontos[i].1))\(sufixo)").font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.red)
                                .position(x: x(i), y: max(10, y(pontos[i].1) - 12))
                        }
                    }
                }
            }.frame(height: 70)
            HStack(spacing: 0) {
                ForEach(pontos.indices, id: \.self) { i in
                    Text(pontos[i].0).font(.system(size: 7)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.2)))
    }
}

// componentes compartilhados
struct HealthHeaderBar: View {
    let titulo: String; let paciente: Paciente; let rotuloFolha: String
    var aoFechar: () -> Void; let cor: Color
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(T(titulo)).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                Spacer()
                Button { aoFechar() } label: { Image(systemName: "xmark").foregroundStyle(.white) }.buttonStyle(.plain)
            }.padding(.horizontal, 12).padding(.vertical, 8).background(cor)
            HStack(spacing: 0) {
                cab("Name", paciente.nome); cab("ID", paciente.id)
                cab("Height", "\(Int(paciente.altura))cm"); cab("Age", "\(paciente.idade)")
                cab("Gender", paciente.sexo == "F" ? "Female" : "Male")
                Spacer()
                Text(T(rotuloFolha)).font(.system(size: 9)).multilineTextAlignment(.center)
                    .frame(width: 100, height: 30).overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.gray.opacity(0.4)))
            }.padding(.horizontal, 12).padding(.vertical, 8)
        }
    }
    private func cab(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(T(k)).font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
            Text(T(v)).font(.system(size: 11, weight: .medium))
        }.frame(minWidth: 66, alignment: .leading)
    }
}

struct RecentTotalToggle: View {
    @Binding var total: Bool
    var body: some View {
        HStack(spacing: 0) {
            btn("Recent", !total) { total = false }
            btn("Total", total) { total = true }
        }.overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.gray.opacity(0.4)))
    }
    private func btn(_ t: String, _ on: Bool, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Text(T(t)).font(.system(size: 11)).frame(width: 50, height: 22)
                .background(on ? Color.accentColor : Color.clear).foregroundStyle(on ? .white : .primary)
        }.buttonStyle(.plain)
    }
}
