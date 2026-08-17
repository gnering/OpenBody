import SwiftUI

// ================= FOLHA HISTÓRICO DA COMPOSIÇÃO CORPORAL (BodyHistory) =================
// Porte do ResultsSheetBodyHistory.DrawResultsSheetA4 (ExtractedBodyHistorySheet.cs +
// BodyHistoryBlocks.cs). Diferente das outras 3: é PAISAGEM e não tem arte de fundo —
// é toda desenhada com linhas/texto, por isso não existe inbody_historico.jpg.
//
// Constantes do original (BodyHistoryBlocks.cs:150, ResultsSheetFrameSet):
//   UnitX=-43 UnitY=28 UnitW=41 UnitH=38 UnitGap=95
//   BGX=-137 CheckX=-141 CheckSize=18 LineX=-140
//   DateHeight=39 GraphWidth=907 OneGraphHeight=95 MaxDataLength=15 EllipseSize=7
//   DateCenterGap=4  |  gráfico em (Left+191, Top+200); cabeçalho em (Left+10, Top+18)
//   GraphHeight = OneGraphHeight*linhas + DateHeight ; BGY/CheckY/LineY derivam disso.
//
// Itens: HEALTHREPORT_DEFAULT_SET_TBL linha MLT_770 (a que a clínica usa) marca com "2"
// (padrão ligado): WT, SMM, BFM, PBF, ECW_TBW, LLM, BMI, BMR, WHR, VFA. A folha mostra
// 5 por página; esta é a primeira página (os 5 primeiros).
struct InBodyHistorySheet {
    let s: FolhaResultado
    init(_ s: FolhaResultado) { self.s = s }
    var p: Paciente { s.pac }

    // Constantes do driver original
    private let graphW: CGFloat = 907
    private let oneH: CGFloat = 95
    private let dateH: CGFloat = 39
    private let maxLen: Int = 15
    private let ellipse: CGFloat = 7
    private let dateCenterGap: CGFloat = 4
    private let unitX: CGFloat = -43, unitY: CGFloat = 28, unitW: CGFloat = 41, unitH: CGFloat = 38
    private let unitGap: CGFloat = 95
    private let lineX: CGFloat = -140

    /// As 5 séries da 1ª página, na ordem do original (rótulo pt-BR, unidade, valor, casas).
    private var linhas: [(rotulo: String, unidade: String, valor: (Medida) -> Double, casas: Int)] {
        [
            (T("Weight"),                          "kg", { $0.peso },    1),
            (T("Skeletal Muscle\nMass"),   "kg", { $0.smm },     1),
            (T("Body Fat Mass"),              "kg", { $0.gordura }, 1),
            (T("Percent\nBody Fat"),        "%",  { $0.pgc },     1),
            (T("ECW/TBW"),                   "",   { $0.ecwTbw },  3),
        ]
    }

    func build() -> E {
        var e = E()
        let fL: CGFloat = 191, fT: CGFloat = 200
        cabecalho(&e)
        grafico(&e, fL: fL, fT: fT)
        rodape(&e)
        return e
    }

    // Cabeçalho (ClsDrawHeaderBodyHistory.DrawBodyHistory em Left+10, Top+18): identificação
    // do paciente e o período coberto pelo histórico.
    private func cabecalho(_ e: inout E) {
        let hL: CGFloat = 10, hT: CGFloat = 18
        e.campos.append(gpt(s, T("Body Composition History"), hL + 40, hT + 6, pt: 16, .black, box: 500))
        let chron = Array(p.exames.reversed())
        let periodo: String
        if let a = chron.first?.data, let b = chron.last?.data {
            periodo = "\(dataCurta(a)) ~ \(dataCurta(b))"
        } else { periodo = "" }

        // faixa de identificação: ID | Nome | Sexo | Idade | Altura | Período
        let y = hT + 40
        let cols: [(String, String, CGFloat)] = [
            ("ID", p.id, 150),
            (T("Name"), p.nome, 240),
            (T("Gender"), p.sexo == "F" ? T("Female") : T("Male"), 110),
            (T("Age"), "\(p.idade)", 70),
            (T("Height"), "\(s.fmt(p.altura, 0)) cm", 110),
            (T("Period"), periodo, 260),
        ]
        var x = hL + 40
        e.linhas.append(hline(hL + 40, y - 4, hL + 40 + cols.reduce(0) { $0 + $1.2 }, .black, 1))
        for (rot, val, w) in cols {
            e.campos.append(gcell(s, rot, x, y, w, 16, pt: 8, .n))
            e.campos.append(gcell(s, val, x, y + 16, w, 20, pt: 11, .n))
            x += w
        }
        e.linhas.append(hline(hL + 40, y + 40, hL + 40 + cols.reduce(0) { $0 + $1.2 }, .black, 1))
    }

    // Gráfico: N faixas empilhadas (uma por item), grade, pontos ligados, rótulo do último
    // valor e a faixa de datas embaixo. Mesma mecânica do ClsLineGraph das outras folhas.
    private func grafico(_ e: inout E, fL: CGFloat, fT: CGFloat) {
        let chron = Array(p.exames.reversed())          // antigo -> recente
        let n = min(chron.count, maxLen)
        let cols = linhas.count
        let alturaGrafico = oneH * CGFloat(cols) + dateH
        let osw = graphW / CGFloat(maxLen)
        let topMargin = 10 * 96.0 / 72.0 * 1.16          // MeasureString("0", Arial10).Height
        let bottomMargin: CGFloat = 5
        let pdh = oneH - (topMargin + bottomMargin + ellipse / 2)
        let num19 = osw / 2 - ellipse / 2
        let grade = Color(red: 214/255, green: 214/255, blue: 214/255)
        let corData = Color(red: 151/255, green: 151/255, blue: 153/255)

        // fundo branco da faixa de datas + moldura de cada faixa
        e.barras.append(Barra(x: fL, y: fT + oneH * CGFloat(cols), w: graphW, h: dateH, cor: .white))
        for i in 1...cols {
            e.linhas.append(vline(fL, fT + CGFloat(i - 1) * oneH + oneH / 7, fT + CGFloat(i) * oneH, .black, 1))
            e.linhas.append(hline(fL, fT + CGFloat(i) * oneH, fL + graphW, .black, 1))
        }
        for k in 1..<maxLen {
            let vx = fL + CGFloat(k) * osw
            e.linhas.append(vline(vx, fT, fT + alturaGrafico - dateH, grade, 1))
            e.linhas.append(vline(vx, fT + alturaGrafico - dateH, fT + alturaGrafico, corData, 1))
        }

        // rótulo + unidade de cada faixa (à esquerda do gráfico, UnitX/UnitGap do original)
        for (i, l) in linhas.enumerated() {
            let y = fT + unitY + unitGap * CGFloat(i) - unitH
            e.campos.append(gcell(s, l.rotulo, fL + lineX + 6, y, 88, unitH, pt: 10, .n))
            if !l.unidade.isEmpty {
                e.campos.append(gcell(s, "(\(l.unidade))", fL + unitX, y, unitW, unitH, pt: 8, .f))
            }
        }

        guard n > 0 else { return }

        // séries: escala própria por faixa (min/max da própria série), como o ClsLineGraph
        for (col, l) in linhas.enumerated() {
            let vals = chron.suffix(n).map { l.valor($0) }
            let mn = vals.min() ?? 0, mx = vals.max() ?? 0
            let rng = mx - mn
            var pts: [(CGFloat, CGFloat)] = []
            for j in 0..<n {
                let dy: CGFloat = rng == 0 ? (pdh - ellipse) : pdh / CGFloat(rng) * CGFloat(mx - vals[j])
                pts.append((fL + CGFloat(j) * osw + num19 + ellipse / 2,
                            fT + topMargin + CGFloat(col) * oneH + dy + ellipse / 2))
            }
            for j in 0..<n {
                if j < n - 1 { e.linhas.append(Linha(pts: [pts[j], pts[j + 1]], cor: .black, w: 1)) }
                e.pontos.append(Ponto(x: pts[j].0, y: pts[j].1, r: ellipse / 2, cor: .black))
                let txt = s.fmt(vals[j], l.casas)
                if j == n - 1 {   // último valor em caixa mais larga (fontLastValue)
                    e.campos.append(gcell(s, txt, pts[j].0 - num19 - ellipse / 2 - 10,
                                          pts[j].1 - topMargin - 2, osw + 20, topMargin, pt: 10, .c))
                } else {
                    e.campos.append(gcell(s, txt, pts[j].0 - num19 - ellipse / 2,
                                          pts[j].1 - topMargin - 2, osw, topMargin, pt: 10, .c))
                }
            }
        }

        // datas em 2 linhas (data / hora), centradas na coluna
        let dateY = fT + dateCenterGap + oneH * CGFloat(cols) - 2
        for j in 0..<n {
            let rx = fL + CGFloat(j) * osw - 3
            let (d, h) = histDataLinhasE(chron.suffix(n)[chron.suffix(n).startIndex + j].data)
            e.campos.append(gcell(s, d, rx, dateY, osw + 6, dateH / 2, pt: 6, .c))
            if !h.isEmpty { e.campos.append(gcell(s, h, rx, dateY + dateH / 2, osw + 6, dateH / 2, pt: 6, .c)) }
        }
    }

    private func dataCurta(_ raw: String) -> String { histDataLinhasE(raw).0 }

    private func rodape(_ e: inout E) {
        e.campos.append(gpt(s, "Ver.LookinBody120.5.0.0.0", 40, 790, pt: 6, .black,
                            box: 420, italic: true))
        e.campos.append(gpt(s, "[InBody770]", 940, 40, pt: 8))
    }
}
