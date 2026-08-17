import SwiftUI

// Folhas CRIANÇA (ResultsSheetInBodyChildV2) e ÁGUA (ResultsSheetBodyWater770),
// portes VERBATIM dos drivers A4 decompilados, validados bloco a bloco pelo
// oráculo (run_opdiff.py child|water). Âncoras com base.Left=1 e:
//   criança: base.Top=6 (driver soma +1)   água: base.Top=4 (driver soma -1)

// Largura aproximada de MeasureString do GDI+ (mesma fórmula do shim do oráculo:
// DrawingShim.MeasureWidth). Usada onde o ORIGINAL posiciona por MeasureString
// (ex.: "%" depois da faixa de percentil da curva de crescimento). Convenção
// compartilhada com o oráculo — os dois lados usam a MESMA régua.
func measureShim(_ s: String, _ pt: CGFloat) -> CGFloat {
    let em = pt * 96.0 / 72.0
    var w: CGFloat = 0
    for c in s {
        let adv: CGFloat
        switch c {
        case "0"..."9": adv = 0.556
        case ".", ",", ":": adv = 0.278
        case "(", ")", " ": adv = 0.333
        case "~", "-": adv = 0.584
        default: adv = 0.6
        }
        w += adv * em
    }
    return w + em / 3.0
}

// GetGrowthRank VERBATIM (ClsDrawLeftOutput:8919) sobre as tabelas geradas do
// ResGrowth.resx (GrowthGen.swift). Saída com vírgula BR ("0~10", "25~50", ...).
// Idade > 18: chave ausente -> "" (mesmo comportamento do original: exceção engolida).
func getGrowthRank(graphType: String, growthType: String, age: Double, gender: String,
                   value: Double) -> String {
    var num3 = Int(age)          // (int)Convert.ToSingle — trunca
    var num4 = num3 + 1
    if num3 < 3 { num3 = 3 }
    if num4 > 18 { num4 = 18 }
    let key1 = "\(graphType)_\(growthType.uppercased())_\(gender)_\(num3)"
    let key2 = "\(graphType)_\(growthType.uppercased())_\(gender)_\(num4)"
    guard let t1 = ResGrowth.tables[key1], let t2 = ResGrowth.tables[key2],
          let tp = ResGrowth.tables["PERCENT_\(growthType)"] else { return "" }
    let a2 = t1.split(separator: ";").compactMap { Double($0) }
    let a3 = t2.split(separator: ";").compactMap { Double($0) }
    let pcts = tp.split(separator: ";").map(String.init)
    guard a2.count == a3.count, a2.count == pcts.count else { return "" }
    var arr = [Double](repeating: 0, count: a2.count)
    for i in 0..<arr.count {
        var d = a3[i] - a2[i]
        d = d / 10.0 * ((age - Double(num3)) * 10.0)
        arr[i] = a2[i] + d
    }
    var idx = -1
    var j = 0
    while j < arr.count && arr[j] <= value { idx = j; j += 1 }
    if idx == -1 { return "0~" + pcts[0] }
    if idx == arr.count - 1 { return pcts.last! + "~100" }
    return pcts[idx] + "~" + pcts[idx + 1]
}

// ClsLineGraph.DrawHistoryGraph (RecentGraph) VERBATIM para as folhas criança (HistoryE)
// e água (HistoryB): grade, pontos, rótulo do último valor e datas em 2 linhas.
// Datas golden vêm numa op com "\n\r"; o diff fatia o rect em 2 — desenho cada linha
// nesses meios-rects (mesma convenção do run_opdiff.split_multiline).
func drawLineGraphRecent(_ e: inout FolhaResultado.Elementos, _ s: FolhaResultado,
                         fL: CGFloat, fT: CGFloat, graphW: CGFloat, graphH: CGFloat,
                         dateH: CGFloat, maxLen: Int, ellipse: CGFloat, dateCenterGap: CGFloat,
                         series: [[String]], datas: [String]) {
    let cols = series.count
    let n = series.first?.count ?? 0
    guard n > 0, cols > 0 else { return }
    let topMargin = 10 * 96.0 / 72.0 * 1.16   // MeasureString("0", Arial10).Height
    let dataHeight = topMargin
    let bottomMargin: CGFloat = 5
    let osw = graphW / CGFloat(maxLen)
    let osh = (graphH - dateH) / CGFloat(cols)
    let pdh = osh - (topMargin + bottomMargin + ellipse / 2)
    let num19 = osw / 2 - ellipse / 2
    // fundo da faixa de datas + grade
    e.barras.append(Barra(x: fL, y: fT + osh * CGFloat(cols), w: graphW, h: dateH, cor: .white))
    for i in 1...cols {
        e.linhas.append(vline(fL, fT + CGFloat(i - 1) * osh + (cols == 1 ? 0 : osh / 7),
                              fT + CGFloat(i) * osh, .black, 1))
        e.linhas.append(hline(fL, fT + CGFloat(i) * osh, fL + graphW, .black, 1))
    }
    let gradeCor = Color(red: 214/255, green: 214/255, blue: 214/255)
    let dataCor = Color(red: 151/255, green: 151/255, blue: 153/255)
    for k in 1..<maxLen {
        let vx = fL + CGFloat(k) * osw
        e.linhas.append(vline(vx, fT, fT + graphH - dateH, gradeCor, 1))
        e.linhas.append(vline(vx, fT + graphH - dateH, fT + graphH, dataCor, 1))
    }
    // séries: min/max próprios; 1 ponto => num31 = pdh - ellipse
    for col in 0..<cols {
        let vals = series[col].map { Double($0.replacingOccurrences(of: ",", with: ".")) ?? 0 }
        let mn = vals.min() ?? 0, mx = vals.max() ?? 0
        let rng = mx - mn
        var pts: [(CGFloat, CGFloat)] = []
        for jj in 0..<n {
            let num31: CGFloat = rng == 0 ? (pdh - ellipse) : pdh / CGFloat(rng) * CGFloat(mx - vals[jj])
            let x = fL + CGFloat(jj) * osw + num19 + ellipse / 2
            let y = fT + topMargin + CGFloat(col) * osh + num31 + ellipse / 2
            pts.append((x, y))
        }
        for jj in 0..<n {
            let p = pts[jj]
            if jj < n - 1 { e.linhas.append(Linha(pts: [p, pts[jj + 1]], cor: .black, w: 1)) }
            e.pontos.append(Ponto(x: p.0, y: p.1, r: ellipse / 2, cor: .black))
            let txt = series[col][jj]
            if jj == n - 1 {   // último: caixa larga (osw+20, -10), fontLastValue Arial 10
                e.campos.append(gcell(s, txt, p.0 - num19 - ellipse / 2 - 10, p.1 - dataHeight - 2,
                                      osw + 20, dataHeight, pt: 10, .c))
            } else {
                e.campos.append(gcell(s, txt, p.0 - num19 - ellipse / 2, p.1 - topMargin - 2,
                                      osw, topMargin, pt: 10, .c))
            }
        }
    }
    // datas: rect (fL + j*osw - 3, fT + gap + osh*cols - 2, osw+6, dateH), 2 linhas centradas
    let dateY = fT + dateCenterGap + osh * CGFloat(cols) - 2
    for jj in 0..<n {
        let rx = fL + CGFloat(jj) * osw - 3
        let (l1, l2) = histDataLinhasE(datas[jj])
        e.campos.append(gcell(s, l1, rx, dateY, osw + 6, dateH / 2, pt: 6, .c))
        if !l2.isEmpty { e.campos.append(gcell(s, l2, rx, dateY + dateH / 2, osw + 6, dateH / 2, pt: 6, .c)) }
    }
}

// "yyyyMMddHHmmss" ou "yyyy/MM/dd HH:mm" -> ("dd.MM.yy.", "HH:mm") no DateFormat
// da clínica (settings "dd.MM.yyyy." com yyyy->yy, como o setter do ClsLineGraph).
func histDataLinhasE(_ raw: String) -> (String, String) {
    let digits = raw.filter { $0.isNumber }
    guard digits.count >= 12 else { return (raw, "") }
    let a = Array(digits)
    let yy = String(a[2...3]), mm = String(a[4...5]), dd = String(a[6...7])
    let hh = String(a[8...9]), mi = String(a[10...11])
    let fmt = SheetSettings.dateFormat.replacingOccurrences(of: "yyyy", with: "yy")
    var d = fmt
    d = d.replacingOccurrences(of: "dd", with: dd)
    d = d.replacingOccurrences(of: "MM", with: mm)
    d = d.replacingOccurrences(of: "yy", with: yy)
    return (d, "\(hh):\(mi)")
}

// ================= FOLHA DA CRIANÇA (ChildV2) =================
struct InBodyChildSheet {
    let s: FolhaResultado
    init(_ s: FolhaResultado) { self.s = s }
    var m: Medida { s.med }
    var p: Paciente { s.pac }
    var isM: Bool { p.sexo == "M" }

    func build() -> E {
        var e = E()
        composicaoB(&e)                                            // DrawBodyCompositionAnalysisB (344,149)
        drawMuscleFatSection(&e, s, m: m, isM: isM, fL: 123, fT0: 323)
        drawObesitySection(&e, s, m: m, isM: isM, idade: Double(p.idade), fL: 123, fT0: 469)
        curvaCrescimento(&e)                                       // DrawGrowthGraphA (27,593)
        historicoE(&e)                                             // DrawBodyCompostionHistoryE (120,891)
        colunaDireita(&e)                                          // conteúdo estrutural (fora do placar)
        rodape(&e)
        return e
    }

    // DrawBodyCompositionAnalysisB: 5 linhas valor(far)+parênteses(25 espaços)+faixa(center).
    private func composicaoB(_ e: inout E) {
        let fL: CGFloat = 344, fT: CGFloat = 149
        let hg: CGFloat = 26
        let bracket = "(" + String(repeating: " ", count: 25) + ")"
        // (valor, casas, unidade, faixa, casasFaixa)
        let rows: [(v: Double, c: Int, u: String, f: Referencia?, fc: Int)] = [
            (m.tbw, 1, "L", m.refTbw, 1),
            (m.proteina, 1, "kg", m.refProteina, 1),
            (m.mineral, 2, "kg", m.refMineral, 2),
            (m.gordura, 1, "kg", m.refGordura, 1),
            (m.peso, 1, "kg", m.refPeso, 1),
        ]
        for (i, row) in rows.enumerated() {
            let y = hg * CGFloat(i)
            if row.v != 0 {
                e.campos.append(gcell(s, "(\(row.u))", fL - 43, fT + 2 + y, 40, 20, pt: 7, .f))
                e.campos.append(gcell(s, s.fmt(row.v, row.c), fL, fT + y, 60, 24, pt: 10, .f))
            }
            if let f = row.f, f.lo != 0 {
                e.campos.append(gcell(s, bracket, fL + 50, fT + y, 110, 24, pt: 8, .c))
                e.campos.append(gcell(s, "\(s.fmt(f.lo, row.fc))~\(s.fmt(f.hi, row.fc))",
                                      fL + 50, fT + y, 110, 24, pt: 8, .c))
            }
        }
    }

    // DrawGrowthGraphA + DrawGrowthGraph + DrawGrowthGraphPercent (GROW=WHO, sem BMI).
    // Arte real WHO_<sexo>_HT/WT (gerada do resx) a 1/3; pontos por fórmula do .exe.
    private func curvaCrescimento(_ e: inout E) {
        let fL: CGFloat = 27, fT: CGFloat = 593
        let sexo = p.sexo == "M" ? "M" : "F"
        let htName = "WHO_\(sexo)_HT", wtName = "WHO_\(sexo)_WT"
        guard let dHT = ResGrowth.imgDims[htName], let dWT = ResGrowth.imgDims[wtName] else { return }
        let w3 = CGFloat(dHT[0]) / 3.0, h3 = CGFloat(dHT[1]) / 3.0
        e.imgs.append(FolhaResultado.Img(nome: "inbody_growth_\(htName)", x: fL, y: fT + 8, w: w3, h: h3, ext: "gif"))
        e.imgs.append(FolhaResultado.Img(nome: "inbody_growth_\(wtName)", x: fL + w3, y: fT + 8,
                                         w: CGFloat(dWT[0]) / 3.0, h: CGFloat(dWT[1]) / 3.0, ext: "gif"))
        // rótulos dos gráficos (Font6B = Arial 6 bold)
        e.campos.append(gpt(s, ResGrowth.strings["GrowthHeight"] ?? "Altura (cm)", fL, fT - 1, pt: 6, .black, bold: true))
        e.campos.append(gcell(s, ResGrowth.strings["GrowthAge"] ?? "Idade", fL, fT + h3 + 6, w3 - 17, 15, pt: 6, .f, .black, bold: true))
        e.campos.append(gpt(s, ResGrowth.strings["GrowthWeight"] ?? "Peso (kg)", fL + 1 + w3, fT - 1, pt: 6, .black, bold: true))
        e.campos.append(gcell(s, ResGrowth.strings["GrowthAge"] ?? "Idade", fL + 2 + w3, fT + h3 + 6, w3 - 17, 15, pt: 6, .f, .black, bold: true))
        // pontos (DrawPoint: elipse 7 + cruz de 21px, pena 2)
        var age = Double(p.idade); if age < 3 { age = 3 }; if age > 18 { age = 18 }
        var ht = p.altura; if ht < 80 { ht = 80 }; if ht > 190 { ht = 190 }   // WHO: base 80
        var wt = m.peso; if wt < 5 { wt = 5 }; if wt > 115 { wt = 115 }
        let num10 = CGFloat(13.466666 * (age - 3) + 14.5)
        let num12 = CGFloat(246.5 - 2.1318183 * (ht - 80))
        let num13 = CGFloat(246.5 - 2.1318183 * (wt - 5))
        func drawPoint(_ px: CGFloat, _ py: CGFloat) {
            e.pontos.append(Ponto(x: px, y: py, r: 3.5, cor: .black))
            e.linhas.append(hline(px - 10, py, px + 10, .black, 2))
            e.linhas.append(vline(px, py - 10, py + 10, .black, 2))
        }
        drawPoint(fL + num10, fT + num12)
        let wInt = CGFloat(dHT[0] / 3)   // (float)(val.Width / 3) — divisão INTEIRA do .exe
        drawPoint(fL + num10 + wInt, fT + num13)
        // faixas de percentil (DrawGrowthGraphPercent, não-KR: fTop-3; Font16B / Font10R).
        // O .exe compara o valor FORMATADO da folha (F1), não o cru do banco — na fronteira
        // exata de percentil (ex.: 50,3 kg = P10) o cru cai do lado errado.
        func f1v(_ v: Double) -> Double {
            Double(fmtSheet(v, 1).replacingOccurrences(of: ",", with: ".")) ?? v
        }
        let rankHT = getGrowthRank(graphType: "HT", growthType: "WHO", age: Double(p.idade),
                                   gender: sexo, value: f1v(p.altura))
        if !rankHT.isEmpty {
            e.campos.append(gpt(s, rankHT.replacingOccurrences(of: ".", with: ","), fL + 117, fT - 23, pt: 16, .black, bold: true))
            let nx = fL + measureShim(rankHT, 16) - 5 + 117
            e.campos.append(gpt(s, "%", nx, fT - 18, pt: 10))
        }
        let rankWT = getGrowthRank(graphType: "WT", growthType: "WHO", age: Double(p.idade),
                                   gender: sexo, value: f1v(m.peso))
        if !rankWT.isEmpty {
            e.campos.append(gpt(s, rankWT.replacingOccurrences(of: ".", with: ","), fL + 234 + 117, fT - 23, pt: 16, .black, bold: true))
            let nx = fL + 234 + measureShim(rankWT, 16) - 5 + 117
            e.campos.append(gpt(s, "%", nx, fT - 18, pt: 10))
        }
    }

    // DrawBodyCompostionHistoryE: 5 faixas Altura/Peso/MME/Gordura/PGC + ClsLineGraph.
    private func historicoE(_ e: inout E) {
        let fL: CGFloat = 120, fT: CGFloat = 891
        // unidades: linha 0 em UnitY-3; demais a passo (UnitGap-10)=39
        let units = ["(cm)", "(kg)", "(kg)", "(kg)", "(%)"]
        for (i, u) in units.enumerated() {
            let uy = i == 0 ? fT - 3 : fT + 39 * CGFloat(i)
            e.campos.append(gcell(s, u, fL - 35, uy, 35, 38, pt: 7, .f))
        }
        // títulos das faixas (arte r_h_*) + legenda/check + linha base (visual)
        for (i, nome) in ["r_h_height", "r_h_weight", "r_h_skemus", "r_h_infat", "r_h_pbf"].enumerated() {
            e.imgs.append(FolhaResultado.Img(nome: "inbody_hist_\(nome)", x: fL - 95, y: fT + 3 + 39 * CGFloat(i), w: 95, h: 36))
        }
        e.imgs.append(FolhaResultado.Img(nome: "inbody_hist_bg", x: fL - 93, y: fT + 200, w: 96, h: 40.0/3.0))
        e.imgs.append(FolhaResultado.Img(nome: "inbody_hist_check", x: fL - 96, y: fT + 194, w: 12, h: 12))
        e.linhas.append(hline(fL - 95, fT + 194, fL + 378, .black, 1))
        // séries do exame (histórico de 1+ pontos, cronológico antigo->recente)
        let chron = Array(p.exames.reversed())
        let series: [[String]] = [
            chron.map { s.fmt($0.altura > 0 ? $0.altura : p.altura, 1) },
            chron.map { s.fmt($0.peso, 1) },
            chron.map { s.fmt($0.smm, 1) },
            chron.map { s.fmt($0.gordura, 1) },
            chron.map { s.fmt($0.pgc, 1) },
        ]
        drawLineGraphRecent(&e, s, fL: fL, fT: fT, graphW: 378, graphH: 214, dateH: 20,
                            maxLen: 8, ellipse: 6, dateCenterGap: 4,
                            series: series, datas: chron.map { $0.data })
    }

    // Coluna direita pediátrica (checklist I: grow_score, nut_eval, obe_eval, body_bal_eval,
    // seg_lean_anal_child, ICW, ECW, BMR, obe_deg_child, BMC, impedância, QR). Fundo é código.
    // Porte VERBATIM de ClsDrawRightOutput (settings.xml INBODY770_RESULTS_SHEET_CHILD_RIGHT_SET):
    // r_grow_score;r_nut_eval|1;r_obe_eval|1;r_body_bal_eval|1;r_seg_lean_anal_child;r_rp_icw;
    // r_rp_ecw;r_rp_bmr;r_rp_obe_deg_child;r_rp_bmc;r_rp_bcm;r_re_grow_graph;r_re_qr;r_impedance.
    // fLeft=1+510+5+7=523, fTop=6+160+5-17=154 (ResultsSheetInBodyChildV2.cs:271, caminho A4-BR).
    private func colunaDireita(_ e: inout E) {
        let fLeft: CGFloat = 523, fTop0: CGFloat = 154
        var fSzie: CGFloat = 0
        func RB(_ v: CGFloat) -> CGFloat { CGFloat(Int(v.rounded(.toNearestOrEven))) }
        func raw(_ k: String) -> Double { m.sheetRaw[k] ?? 0 }
        func vv(_ k: String) -> String { m.rightRaw[k] ?? "" }
        func comma(_ t: String) -> String { t.replacingOccurrences(of: ".", with: ",") }
        func blockImg(_ name: String, _ w: Int, _ h: Int, at top: CGFloat) {
            e.imgs.append(FolhaResultado.Img(nome: "inbody_right_\(name)", x: fLeft, y: top, w: CGFloat(w)/3, h: CGFloat(h)/3))
        }

        // 1) r_grow_score (imgH 280 -> +93,33). Valor sobre a arte, sfFar, Arial 20.
        do {
            let fTop = fTop0 + fSzie
            blockImg("r_grow_score", 733, 280, at: fTop)
            var sc = Int(raw("totScore").rounded()); if sc < 1 { sc = 1 }
            e.campos.append(gcell(s, "\(sc)", fLeft + 40, RB(fTop) + 29, 80, 30, pt: 20, .f))
            fSzie += 280.0/3.0
        }
        // 2) r_nut_eval|1 (imgH 252 -> +84). Check por etype2[0][1][2], 2 estados (0/1), col=widthGap(52).
        do {
            let fTop = fTop0 + fSzie
            blockImg("r_nut_eval", 733, 252, at: fTop)
            let et = Array(m.etype2)
            if et.count >= 3 {
                for (row, idx) in [0, 1, 2].enumerated() {
                    let d = Int(String(et[idx])) ?? 0
                    guard d == 0 || d == 1 else { continue }
                    let cx = fLeft + 67 + (d == 1 ? 52 : 0)
                    let cy = fTop + 23 + 21 * CGFloat(row)
                    e.imgs.append(FolhaResultado.Img(nome: "inbody_right_Check", x: cx, y: cy, w: 12, h: 12))
                }
            }
            fSzie += 252.0/3.0
        }
        // 3) r_obe_eval|1 (imgH 252 -> +84). Check por etype2[6] (4 estados: 0/1/2/3) e etype2[7] (0|1/2/3).
        do {
            let fTop = fTop0 + fSzie
            blockImg("r_obe_eval", 733, 252, at: fTop)
            let et = Array(m.etype2)
            if et.count >= 8 {
                let widthGap: CGFloat = 52, widthOver: CGFloat = 64, heightGap: CGFloat = 39
                let d6 = Int(String(et[6])) ?? 0
                let cx6: CGFloat? = d6 == 0 ? fLeft+67 : d6 == 1 ? fLeft+67+widthGap : d6 == 2 ? fLeft+67+widthGap*2 : d6 == 3 ? fLeft+67+widthGap*2+widthOver : nil
                if let cx6 { e.imgs.append(FolhaResultado.Img(nome: "inbody_right_Check", x: cx6, y: fTop+21, w: 12, h: 14)) }
                let d7 = Int(String(et[7])) ?? 0
                let cx7: CGFloat? = (d7 == 0 || d7 == 1) ? fLeft+67 : d7 == 2 ? fLeft+67+widthGap : d7 == 3 ? fLeft+67+widthGap+widthOver : nil
                if let cx7 { e.imgs.append(FolhaResultado.Img(nome: "inbody_right_Check", x: cx7, y: fTop+21+heightGap, w: 12, h: 14)) }
            }
            fSzie += 252.0/3.0
        }
        // 4) r_body_bal_eval|1 (imgH 252 -> +84). Igual ao adulto: check por etype2[9][10][11].
        do {
            let fTop = fTop0 + fSzie
            blockImg("r_body_bal_eval", 733, 252, at: fTop)
            let et = Array(m.etype2)
            if et.count >= 12 {
                let widthGap: CGFloat = 52, widthOver: CGFloat = 64, heightGap: CGFloat = 21
                for (row, idx) in [9, 10, 11].enumerated() {
                    let d = Int(String(et[idx])) ?? 0
                    let addW: CGFloat = d == 0 ? 0 : widthGap
                    let addWover: CGFloat = d == 2 ? widthOver : 0
                    let cx = fLeft + 67 + addW + addWover
                    let cy = fTop + 21 + heightGap * CGFloat(row)
                    e.imgs.append(FolhaResultado.Img(nome: "inbody_right_Check", x: cx, y: cy, w: 12, h: 12))
                }
            }
            fSzie += 252.0/3.0
        }
        // 5) r_seg_lean_anal_child (imgH 392 -> +130,67). 5 linhas kg + faixa (LB_TBL.L*_MIN/MAX,
        //    driver reusa RA->LA e RL->LL). ValueX=45 W=100 sfFar; RangeX=168 W=80 sfCenter.
        do {
            let fTop = fTop0 + fSzie
            blockImg("r_seg_lean_anal_child", 733, 392, at: fTop)
            let iTop = RB(fTop)
            let rows: [(kg: Double, mn: Double, mx: Double)] = [
                (m.seg["RA"] ?? 0, m.segMin["RA"] ?? 0, m.segMax["RA"] ?? 0),
                (m.seg["LA"] ?? 0, m.segMin["RA"] ?? 0, m.segMax["RA"] ?? 0),
                (m.seg["TR"] ?? 0, m.segMin["TR"] ?? 0, m.segMax["TR"] ?? 0),
                (m.seg["RL"] ?? 0, m.segMin["RL"] ?? 0, m.segMax["RL"] ?? 0),
                (m.seg["LL"] ?? 0, m.segMin["RL"] ?? 0, m.segMax["RL"] ?? 0),
            ]
            for (row, r) in rows.enumerated() {
                let uy = iTop + 24 + 21 * CGFloat(row)
                e.campos.append(gcell(s, "kg", fLeft + 145, uy, 30, 21, pt: 7, .n))
                e.campos.append(gcell(s, comma(s.fmt(r.kg, 2)), fLeft + 45, uy, 100, 21, pt: 10, .f))
                // bRangeUse=false no driver (settings.xml): golden não mostra faixa aqui.
            }
            fSzie += 392.0/3.0
        }
        // 6) Dados Adicionais — icw/ecw/bmr/obe_deg_child/bmc/bcm (r_rp_icw reusado, "r_rp_title" 1x).
        do {
            struct RP { let name: String; let val: String; let unit: String; let rangeLo: String; let rangeHi: String }
            let iwt = raw("iwt")
            let odVal = iwt > 0 ? comma(s.fmt(raw("obesityDeg"), 0)) : ""
            let rows: [RP] = [
                RP(name: "r_rp_icw", val: comma(vv("icw")), unit: "L", rangeLo: vv("icwMin"), rangeHi: vv("icwMax")),
                RP(name: "r_rp_ecw", val: comma(vv("ecw")), unit: "L", rangeLo: vv("ecwMin"), rangeHi: vv("ecwMax")),
                RP(name: "r_rp_bmr", val: vv("bmr"), unit: "kcal", rangeLo: vv("bmrMin"), rangeHi: vv("bmrMax")),
                RP(name: "r_rp_obe_deg_child", val: odVal, unit: "%",
                   rangeLo: comma(s.fmt(raw("odMin"), 0)), rangeHi: comma(s.fmt(raw("odMax"), 0))),
                RP(name: "r_rp_bmc", val: comma(s.fmt(raw("bmc"), 2)), unit: "kg",
                   rangeLo: comma(s.fmt(raw("bmcMin"), 2)), rangeHi: comma(s.fmt(raw("bmcMax"), 2))),
                RP(name: "r_rp_bcm", val: comma(vv("bcm")), unit: "kg", rangeLo: vv("bcmMin"), rangeHi: vv("bcmMax")),
            ]
            var titlePrinted = false
            for r in rows {
                let fTop = fTop0 + fSzie
                var add: CGFloat = 0
                if !titlePrinted {
                    blockImg("r_rp_title", 733, 56, at: fTop)
                    add = 56.0/3.0
                    titlePrinted = true
                }
                blockImg(r.name, 733, 56, at: fTop + add)
                let nAdd = CGFloat(Int(add.rounded(.toNearestOrEven)))
                let iTop = RB(fTop)
                let backH: CGFloat = 19
                if !r.val.isEmpty {
                    e.campos.append(gcell(s, r.val, fLeft + 80, iTop - 3 + nAdd, 65, backH, pt: 10, .f))
                }
                if !r.unit.isEmpty {
                    e.campos.append(gcell(s, r.unit, fLeft + 145, iTop - 3 + nAdd, 35, backH, pt: 7, .n))
                }
                if !r.rangeLo.isEmpty {
                    e.campos.append(gcell(s, comma("\(r.rangeLo)~\(r.rangeHi)"), fLeft + 174, iTop - 3 + nAdd, 70, backH, pt: 8, .c))
                }
                fSzie += add + backH
            }
        }
        // 7) r_re_grow_graph (imgH 168 -> +56) + 8) r_re_qr (imgH 336 -> +112; nType=1 -> "_child_770").
        do {
            let fTop = fTop0 + fSzie
            blockImg("r_re_grow_graph", 733, 168, at: fTop)
            fSzie += 168.0/3.0
        }
        do {
            let fTop = fTop0 + fSzie
            blockImg("r_re_qr", 733, 336, at: fTop)
            e.imgs.append(FolhaResultado.Img(nome: "inbody_right_r_re_qr_child_770", x: fLeft + 155, y: fTop + 26, w: 231.0/3, h: 231.0/3))
            fSzie += 336.0/3.0
        }
        // 9) Impedância (r_impedance_770 verbatim: FirstX=62,FirstY=33,ColGap=35,RowGap=14 --
        //    mesma fórmula/reuso do adulto e água; tronco é chave "T", não "TR").
        do {
            let fTop = fTop0 + fSzie
            blockImg("r_impedance_770", 733, 364, at: fTop)
            let colSeg = ["RA", "LA", "T", "RL", "LL"]
            let colX: [CGFloat] = (0..<5).map { fLeft + 62 + 35 * CGFloat($0) }
            for (row, freq) in ["1", "5", "50", "250", "500", "1M"].enumerated() {
                let y = RB(fTop) + 33 + 14 * CGFloat(row)
                for (c, seg) in colSeg.enumerated() {
                    let raw = m.rightRaw["I\(seg)\(freq)"] ?? ""
                    if !raw.isEmpty {
                        e.campos.append(gcell(s, raw.replacingOccurrences(of: ".", with: ","), colX[c], y, 35, 15, pt: 7, .c))
                    }
                }
            }
            fSzie += 364.0/3.0
        }
    }

    // Rodapé + rótulo do modelo (DrawInBodyChild: equip 770 -> "580"; hx=-16, hy=-12).
    private func rodape(_ e: inout E) {
        e.campos.append(gpt(s, "Ver.LookinBody120.5.0.0.0", 31, 1123, pt: 6, .black, box: 420, italic: true))
        e.campos.append(gcell(s, "[InBody580]", -16 + 217, -12 + 64, 300, 20, pt: 10, .f, .black))
    }
}

// ================= FOLHA DA ÁGUA (BodyWater770) =================
struct InBodyWaterSheet {
    let s: FolhaResultado
    init(_ s: FolhaResultado) { self.s = s }
    var m: Medida { s.med }
    var p: Paciente { s.pac }
    var isM: Bool { p.sexo == "M" }

    private func raw(_ k: String) -> Double { m.sheetRaw[k] ?? 0 }

    func build() -> E {
        var e = E()
        composicaoAgua(&e)      // DrawBodyWaterCompositionA (127,167)
        taxaAEC(&e)             // DrawECWRatioAnalysisA (127,334)
        aguaSegmentar(&e)       // DrawSegmentalBodyWaterAnalysisA (127,427)
        aecSegmentar(&e)        // DrawSegmentalECWRatioAnalysisA4 (125,658)
        historicoB(&e)          // DrawBodyWaterCompositionHistoryB (127,894)
        colunaDireita(&e)       // conteúdo estrutural (fora do placar)
        rodape(&e)
        return e
    }

    // Linha de barra padrão dos blocos de água (mesma família do Músculo-Gordura):
    // escala centrada nos ticks (Arial 6), '%' no fim, barra por percentual, valor em fT+17.
    // overflowX/overflowW: caixa branca de estouro -- formula PROPRIA de cada funcao C#
    // de origem (achado 05-ago, resíduo de forma em bwcomp): DrawBodyWaterCompositionA
    // usa BarLength-35/largura 25 pra CAIXA mas BarLength-41 pro TEXTO (offsets diferentes
    // entre si, achado ao reconferir); DrawSegmentalBodyWaterAnalysisA usa BarLength-40/30
    // pros dois (caixa e texto iguais). Nao e' uma constante unica.
    private func barRow(_ e: inout E, fL: CGFloat, fT: CGFloat, scale: [Double], interval: Double,
                       pct: Double, valor: String, gh: CGFloat,
                       overflowX: CGFloat = -40, overflowW: CGFloat = 25, overflowTextX: CGFloat? = nil) {
        let firstW: CGFloat = 19, sw: CGFloat = 32.5, barW: CGFloat = 7, barLen: CGFloat = 370
        let ticks = (0...10).map { firstW + sw * CGFloat($0) }
        drawGrade(&e, s, fL: fL, fT: fT, barLen: barLen, gh: gh, ticks: ticks,
                  labels: (0...10).map { fmtSc(scale[$0]) }, borderOffset: -6)
        e.campos.append(gpt(s, "%", fL + barLen - 10, fT + 5, pt: 6))
        var num = getBarWidth(scale[0], interval, pct, percent: true, sw, Int(barLen) - 50)
        if num >= Double(Int(barLen) - 50) {
            num = Double(Int(barLen) - 50)
            e.barras.append(Barra(x: fL + barLen + overflowX, y: fT + 6, w: overflowW, h: 10, cor: .white))
            e.campos.append(gpt(s, "(\(s.fmt(pct, 0)))", fL + barLen + (overflowTextX ?? overflowX), fT + 6, pt: 6))
        }
        let valuePos = firstW + CGFloat(num) + 2
        let yTop = fT + (gh - barW) / 2 + 12 - barW - 0.5
        fillBar(&e, xLeft: fL, valuePos: valuePos, yTop: yTop, thick: barW + 1,
                midStart: ticks[2], midLen: sw * 2, baseCor: IB.dark, midCor: IB.gray137, ticks: ticks)
        e.campos.append(gpt(s, valor, fL + 25 + CGFloat(num), fT + 15, pt: 10))
    }

    // ACT / Água Intra / Água Extracelular: 3 barras (escala 70..180, intervalo 10).
    private func composicaoAgua(_ e: inout E) {
        // Alinhamento medido no render (06-ago): as linhas da folha de fundo têm passo de
        // 37,33pt (112px @3x) e o bloco estava 3pt abaixo do centro da linha. Antes: fT0=167,
        // passo 38 nas barras e 37 no "(L)" — o passo maior acumulava desvio a cada linha.
        let fL: CGFloat = 118, fT0: CGFloat = 160.7, passo: CGFloat = 37.3
        for i in 0..<3 {
            e.campos.append(gcell(s, "(L)", fL - 33, fT0 + passo * CGFloat(i), 28, 32, pt: 7, .f))
        }
        let rows: [(pct: Double, val: String)] = [
            (raw("ptbw"), s.fmt(m.tbw, 1)),
            (raw("picw"), s.fmt(m.icw, 1)),
            (raw("pecw"), s.fmt(m.ecw, 1)),
        ]
        for (i, r) in rows.enumerated() {
            barRow(&e, fL: fL, fT: fT0 + passo * CGFloat(i), scale: Escala.tbw, interval: 10,
                   pct: (r.pct).rounded(), valor: r.val, gh: 38, overflowX: -35, overflowW: 25, overflowTextX: -41)
        }
    }

    // Taxa de AEC (reuso verbatim do bloco do adulto, âncora da água).
    private func taxaAEC(_ e: inout E) {
        let fL: CGFloat = 118, fT: CGFloat = 327.7
        let firstW: CGFloat = 19, sw: CGFloat = 32.5, gh: CGFloat = 30, barW: CGFloat = 7, barLen: CGFloat = 370
        let ticks = (0...10).map { firstW + sw * CGFloat($0) }
        let edema = m.wed
        drawGrade(&e, s, fL: fL, fT: fT, barLen: barLen, gh: gh, ticks: ticks,
                  labels: (0...10).map { s.fmt(Escala.wed[$0], 3) }, borderOffset: 4)
        var bw: Double
        if edema > 0.38 {
            bw = getBarWidth(0.320, 0.02, 0.380, percent: false, sw, Int(barLen) - 50)
            bw += getBarWidth2(0.320, 0.01, 0.32 + edema - 0.38, sw, Int(barLen) - 50)
        } else {
            bw = getBarWidth(0.320, 0.02, edema, percent: false, sw, Int(barLen) - 50)
        }
        if bw >= Double(Int(barLen) - 50) {
            bw = Double(Int(barLen) - 52)
            e.barras.append(Barra(x: fL + barLen - 45, y: fT + 6, w: 30, h: 9, cor: .white))
            e.campos.append(gpt(s, "(\(s.fmt(edema, 3)))", fL + barLen - 41, fT + 6, pt: 6))
        }
        let valuePos = firstW + CGFloat(bw) + 2
        let yTop = fT + (gh - barW) / 2 + 18 - barW - 0.5
        fillBar(&e, xLeft: fL, valuePos: valuePos, yTop: yTop, thick: barW + 1,
                midStart: ticks[2], midLen: sw * 2, baseCor: IB.dark, midCor: IB.gray137, ticks: ticks)
        e.campos.append(gpt(s, s.fmt(edema, 3), fL + 25 + CGFloat(bw), fT + 18, pt: 10))
    }

    // Água Segmentar: 5 barras (escala segmentar por sexo; braço/tronco/perna).
    private func aguaSegmentar(_ e: inout E) {
        // Mesmo alinhamento medido da composição: passo do fundo 37,33pt e bloco 3,33pt acima
        // (antes fT0=427 deixava folga 27 em cima e 7 embaixo dentro da linha do fundo).
        let fL: CGFloat = 118, fT0: CGFloat = 420.7, passo: CGFloat = 37.5
        let armScale = isM ? Escala.segMaleArm : Escala.segFemaleArm
        let trunkScale = isM ? Escala.segMaleTrunk : Escala.segFemaleTrunk
        let legScale = isM ? Escala.segMaleLeg : Escala.segFemaleLeg
        func iv(_ sc: [Double]) -> Double { abs(sc[0] - sc[1]) }
        for i in 0..<5 {
            e.campos.append(gcell(s, "(L)", fL - 33, fT0 + passo * CGFloat(i), 28, 32, pt: 7, .f))
        }
        // Tronco usa 1 casa decimal na folha real (achado no JPEG do aparelho, 04-ago);
        // braço/perna usam 2. Quirk do dispositivo, não arredondamento nosso.
        let rows: [(ww: Double, pct: Double, scale: [Double], casas: Int)] = [
            (raw("wwRA"), raw("pinwRA"), armScale, 2),
            (raw("wwLA"), raw("pinwLA"), armScale, 2),
            (raw("wwT"),  raw("pinwT"),  trunkScale, 1),
            (raw("wwRL"), raw("pinwRL"), legScale, 2),
            (raw("wwLL"), raw("pinwLL"), legScale, 2),
        ]
        for (i, r) in rows.enumerated() {
            barRow(&e, fL: fL, fT: fT0 + passo * CGFloat(i), scale: r.scale, interval: iv(r.scale),
                   pct: r.pct.rounded(), valor: s.fmt(r.ww, r.casas), gh: 38, overflowX: -40, overflowW: 30)
        }
    }

    // Taxa de AEC Segmentar (DrawSegmentalECWRatioAnalysisA4 + PointA4) — VERBATIM.
    private func aecSegmentar(_ e: inout E) {
        // fT medido contra o fundo: as linhas 0,40 e 0,39 têm que cair exatamente nas divisões
        // das faixas Acima/Levemente acima/Normal (fundo em 728,8 e 753,8). Com fT=651 as duas
        // batem (651+78=729 e 651+102=753); antes fT=658 jogava as duas ~7pt abaixo.
        let fL: CGFloat = 116, fT: CGFloat = 651
        let grade = IB.gray200
        e.linhas.append(vline(fL + 2, fT, fT + 171, .black, 1))
        for i in 0..<4 { e.linhas.append(vline(fL + 96 + 70 * CGFloat(i), fT, fT + 171, grade, 0.7)) }
        for i in 0..<4 { e.linhas.append(vline(fL + 96 + 70 * CGFloat(i), fT + 174, fT + 196, grade, 0.7)) }
        // rótulos dos segmentos (FontSegECW: 7pt — 10pt não cabe na caixa de 70px; premissa
        // compartilhada com o oráculo, sfValue=SfCF)
        let labels = ["Braço Direito", "Braço Esquerdo", "Tronco", "Perna Direita", "Perna Esquerda"]
        for (i, t) in labels.enumerated() {
            e.campos.append(gcell(s, t, CGFloat(Int(fL)) + 24 + 70 * CGFloat(i), CGFloat(Int(fT)) + 176, 70, 22, pt: 7, .c))
        }
        // escala Y (0,43..0,36) + ticks + faixa normal tracejada em 0,40/0,39
        e.linhas.append(hline(fL + 2, fT + 15, fL + 5, .black, 1))
        e.campos.append(gpt(s, s.fmt(0.43, 2), fL + 8, fT + 11, pt: 6))
        let ys: [CGFloat] = [30, 54, 78, 102, 126, 150]
        let vs = [0.42, 0.41, 0.40, 0.39, 0.38, 0.37]
        for k in 0..<6 {
            e.linhas.append(hline(fL + 2, fT + ys[k], fL + 5, .black, 1))
            if k == 2 || k == 3 { e.linhas.append(hline(fL + 32, fT + ys[k], fL + 373, grade, 0.7)) }
            e.campos.append(gpt(s, s.fmt(vs[k], 2), fL + 8, fT + ys[k] - 4, pt: 6))
        }
        e.linhas.append(hline(fL + 2, fT + 165, fL + 5, .black, 1))
        e.campos.append(gpt(s, s.fmt(0.36, 2), fL + 8, fT + 161, pt: 6))
        e.linhas.append(hline(fL + 2, fT + 171, fL + 373, .black, 1))
        e.linhas.append(hline(fL - 96, fT + 174, fL + 373, .black, 1))
        // pontos por segmento (PointA4): num8 por trechos; <=0 -> nada (exceção engolida no .exe)
        let segs = ["RA", "LA", "TR", "RL", "LL"]
        for (i, k) in segs.enumerated() {
            let v = m.segAEC[k] ?? 0
            guard v > 0 else { continue }
            var num8: CGFloat = 0
            let n2 = 0.36, n3 = 0.37, n4 = 0.43, n5 = 0.42
            let n6: CGFloat = 15, n7: CGFloat = 120
            if v < n2 { num8 = -2 }
            else if v > n4 { num8 = 155 }
            else if v <= n3 { num8 = n6 - CGFloat((v - n3) * (Double(n6) / (n2 - n3))) }
            else if v <= n5 { num8 = n6 + (n7 - CGFloat((v - n5) * (Double(n7) / (n3 - n5)))) }
            else { num8 = n6 + n7 + (n6 - CGFloat((v - n4) * (Double(n6) / (n5 - n4)))) }
            let px = fL + CGFloat(i) * 70 + 59
            let py = fT + 165 - num8
            // DrawPointValue: elipse 6 + risco horizontal + valor centrado no rect (x-40, y-15, 80, 15)
            e.pontos.append(Ponto(x: px, y: py, r: 3, cor: .black))
            e.linhas.append(hline(px - 10, py, px + 10, .black, 1))
            e.campos.append(gcell(s, s.fmt(v, 3), px - 40, py - 15, 80, 15, pt: 10, .c))
        }
    }

    // Histórico da Água (HistoryB): Peso/ACT/ICW/ECW/Taxa AEC; unidades kg/L/L/L (AEC sem).
    private func historicoB(_ e: inout E) {
        // fT = topo da 1ª linha do fundo (886,7), regra do adulto. O passo 39 já batia.
        let fL: CGFloat = 118, fT: CGFloat = 886.7
        let units = ["(kg)", "(L)", "(L)", "(L)"]
        for (i, u) in units.enumerated() {
            e.campos.append(gcell(s, u, fL - 35, fT + 39 * CGFloat(i), 31, 38, pt: 7, .f))
        }
        e.imgs.append(FolhaResultado.Img(nome: "inbody_hist_bg", x: fL - 93, y: fT + 201, w: 96, h: 40.0/3.0))
        e.imgs.append(FolhaResultado.Img(nome: "inbody_hist_check", x: fL - 95, y: fT + 197, w: 12, h: 12))
        e.linhas.append(hline(fL - 99, fT + 195, fL + 373, .black, 1))
        let chron = Array(p.exames.reversed())
        let series: [[String]] = [
            chron.map { s.fmt($0.peso, 1) },
            chron.map { s.fmt($0.tbw, 1) },
            chron.map { s.fmt($0.icw, 1) },
            chron.map { s.fmt($0.ecw, 1) },
            chron.map { s.fmt($0.ecwTbw, 3) },
        ]
        drawLineGraphRecent(&e, s, fL: fL, fT: fT, graphW: 373, graphH: 215, dateH: 23,
                            maxLen: 8, ellipse: 6, dateCenterGap: 4,
                            series: series, datas: chron.map { $0.data })
    }

    // Coluna direita da folha de água (ClsDrawRightOutput.DrawRightOption verbatim,
    // fLeft=1+510+15=526, fTop=4+160-8=156). Extraído em ExtractedRightWater.cs
    // (r_bw_comp_ibw_right, r_seg_bw_anal, r_body_comp_anal_a4, r_mus_fat_anal_ibw_a4,
    // r_obe_anal_ibw) + reuso de r_rp_icw/r_wb_pa/r_impedance já validados no adulto.
    // Posições abaixo = as MESMAS do golden do oráculo (right_w), conferidas contra o
    // JPEG real do aparelho (mesmo paciente/exame, 04-ago). Títulos são arte no .exe
    // (fora do placar de texto); aqui viram legenda simples, mesmo conteúdo visual.
    private func colunaDireita(_ e: inout E) {
        let fL: CGFloat = 526
        func raw(_ k: String) -> Double { m.sheetRaw[k] ?? 0 }
        // Campos que só existem como STRING pré-formatada em rightRaw (mesma fonte da
        // coluna direita do adulto): WHR/RCQ, BMR/TMB, VFA/gordura visceral, BCM.
        // m.rcq/m.tmb/m.gv/m.refRcq/m.refBcm não são preenchidos pelo CLI (ficam 0);
        // ler direto do rightRaw evita depender desses campos zerados.
        func rr(_ k: String) -> Double { Double((m.rightRaw[k] ?? "").replacingOccurrences(of: ",", with: ".")) ?? 0 }
        // linha padrão dos blocos 1-5: unit(fL+145,far→near em w30), valor(fL+45→571,w100,far),
        // faixa(fL+168→694,w80,center). y = topo da linha (mesmo y do golden, já com o -1 do .exe).
        // ux/vx = X do unit/valor (150/50 no bloco segmentar; 145/45 nos demais — conferido
        // linha a linha contra os args exatos do case-dispatch decompilado). uy/ry = deltas de
        // Y relativos a `y` (0 no segmentar, onde Unit/Value/Range Y são iguais; +1/+2 nos outros).
        func blockImg(_ name: String, _ y: CGFloat, _ w: Int, _ h: Int) {
            e.imgs.append(FolhaResultado.Img(nome: "inbody_right_\(name)", x: fL, y: y, w: CGFloat(w)/3, h: CGFloat(h)/3))
        }
        func row1(_ y: CGFloat, _ unit: String, _ val: Double, _ c: Int, _ lo: Double, _ hi: Double, _ cr: Int = 1,
                  ux: CGFloat = 145, vx: CGFloat = 45, uy: CGFloat = 1, ry: CGFloat = 2) {
            e.campos.append(gcell(s, unit, fL+ux, y+uy, 30, 20, pt: 7, .n))
            e.campos.append(gcell(s, s.fmt(val,c), fL+vx, y, 100, 20, pt: 10, .f))
            if hi != 0 {
                e.campos.append(gcell(s, "\(s.fmt(lo,cr))~\(s.fmt(hi,cr))", fL+168, y+ry, 80, 20, pt: 7, .c))
            }
        }
        // linha padrão de "Dados Adicionais" (r_rp_icw): unit(fL+145,w35), valor(fL+80,w65,far),
        // faixa(fL+174,w70,center).
        // valor/unidade/faixa em rótulo_topo−3 (= y−6), igual ao adulto (ClsDrawRightOutput).
        // Antes ficavam em `y` (=rótulo_topo+3), meia-linha abaixo do rótulo.
        func row2(_ y: CGFloat, _ img: String, _ unit: String, _ val: Double, _ c: Int, _ lo: Double = 0, _ hi: Double = 0, _ cr: Int = 1) {
            blockImg(img, y - 3, 733, 56)
            e.campos.append(gcell(s, unit, fL+145, y - 6, 35, 19, pt: 7, .n))
            e.campos.append(gcell(s, s.fmt(val,c), fL+80, y - 6, 65, 19, pt: 10, .f))
            if hi != 0 {
                e.campos.append(gcell(s, "\(s.fmt(lo,cr))~\(s.fmt(hi,cr))", fL+174, y - 6, 70, 19, pt: 7, .c))
            }
        }
        func row2s(_ y: CGFloat, _ img: String, _ unit: String, _ val: String, _ lo: String = "", _ hi: String = "") {
            blockImg(img, y - 3, 733, 56)
            e.campos.append(gcell(s, unit, fL+145, y - 6, 35, 19, pt: 7, .n))
            e.campos.append(gcell(s, val, fL+80, y - 6, 65, 19, pt: 10, .f))
            if !hi.isEmpty { e.campos.append(gcell(s, "\(lo)~\(hi)", fL+174, y - 6, 70, 19, pt: 7, .c)) }
        }

        // 1) Composição da Água Corporal (arte real: título + 3 linhas, 252pt/3=84pt de altura)
        blockImg("r_bw_comp_ibw_right", 156, 733, 252)
        row1(180, "L", m.tbw, 1, m.refTbw.lo, m.refTbw.hi)
        row1(200, "L", m.icw, 1, raw("icwMinD"), raw("icwMaxD"))
        row1(220, "L", m.ecw, 1, raw("ecwMinD"), raw("ecwMaxD"))

        // 2) Análise da Água Segmentar (arte real, 392/3=131pt) — Tronco em 1 casa (achado no
        // real; braço/perna em 2). Faixa = a MESMA usada nas barras da esquerda (LB.WW*_MIN/MAX;
        // driver reusa a do lado direito para o esquerdo, verbatim — premissa já documentada no oráculo).
        blockImg("r_seg_bw_anal", 242, 733, 392)
        let segs: [(String,String,String,Int)] = [
            ("wwRA","wwRAMin","wwRAMax",2), ("wwLA","wwRAMin","wwRAMax",2),
            ("wwT","wwTMin","wwTMax",1), ("wwRL","wwRLMin","wwRLMax",2), ("wwLL","wwRLMin","wwRLMax",2),
        ]
        for (i, seg) in segs.enumerated() {
            let y = 265 + 21 * CGFloat(i)
            row1(y, "L", raw(seg.0), seg.3, raw(seg.1), raw(seg.2), seg.3, ux: 150, vx: 50, uy: 0, ry: 0)
        }

        // 3) Análise da Composição Corporal (arte real, 392/3=131pt): Proteína/Minerais/Gordura/MLG/BMC
        blockImg("r_body_comp_anal", 373, 733, 392)
        row1(395, "kg", m.proteina, 1, m.refProteina.lo, m.refProteina.hi)
        row1(416, "kg", m.mineral, 2, m.refMineral.lo, m.refMineral.hi, 2)
        row1(437, "kg", m.gordura, 1, m.refGordura.lo, m.refGordura.hi)
        row1(458, "kg", m.ffm, 1, m.refFfm.lo, m.refFfm.hi)
        row1(479, "kg", raw("bmc"), 2, raw("bmcMin"), raw("bmcMax"), 2)

        // 4) Análise Músculo-Gordura (arte real, 308/3=103pt): Peso/MME/Massa Magra Mole/Gordura
        blockImg("r_mus_fat_anal_ibw", 503, 733, 308)
        row1(524, "kg", m.peso, 1, m.refPeso.lo, m.refPeso.hi)
        row1(545, "kg", m.smm, 1, m.refSmm.lo, m.refSmm.hi)
        row1(564, "kg", m.slm, 1, m.refSlm.lo, m.refSlm.hi)
        row1(584, "kg", m.gordura, 1, m.refGordura.lo, m.refGordura.hi)

        // 5) Análise de Obesidade (arte real, 196/3=65pt): IMC/PGC
        blockImg("r_obe_anal_ibw", 606, 733, 196)
        row1(627, "kg/㎡", m.imc, 1, m.bmiMin, m.bmiMax)
        row1(647, "%", m.pgc, 1, m.pbfMin, m.pbfMax)

        // 6) Dados Adicionais. Título em 669 (limpo da obesidade). As linhas foram empurradas
        // +5px pra descolar do título (antes a 1ª linha em 685 encavalava com o título de 18,7px).
        blockImg("r_rp_title", 669, 733, 56)
        row2s(690, "r_rp_bmr", "kcal", "\(Int(rr("bmr")))", "\(Int(rr("bmrMin")))", "\(Int(rr("bmrMax")))")
        row2(709, "r_rp_whr", "", rr("whr"), 2, rr("whrMin"), rr("whrMax"), 2)
        row2(728, "r_rp_wc", "cm", raw("waistCirc"), 1)
        row2s(747, "r_rp_vfa", "cm²", s.fmt(rr("vfa"),1))
        row2(766, "r_rp_obe_deg", "%", raw("obesityDeg"), 0, raw("odMin"), raw("odMax"), 0)
        row2(785, "r_rp_bcm", "kg", rr("bcm"), 1, rr("bcmMin"), rr("bcmMax"))
        row2(804, "r_rp_ac", "cm", raw("ac"), 1)
        row2(823, "r_rp_amc", "cm", raw("amc"), 1)
        row2(842, "r_rp_tbw_ffm", "%", raw("tbwFfm"), 1)
        row2(861, "r_rp_ffmi", "kg/㎡", raw("ffmi"), 1)
        row2(880, "r_rp_fmi", "kg/㎡", raw("bfmi"), 1)

        // 7) Ângulo de Fase de Corpo Inteiro (arte real, 140/3=47pt)
        blockImg("r_wb_pa", 900, 733, 140)
        e.campos.append(gcell(s, "˚", fL+138, 919, 30, 20, pt: 7, .c))
        e.campos.append(gcell(s, s.fmt(rr("wbpa50"),1), fL+50, 922, 100, 20, pt: 10, .f))

        // 8) Impedância (arte real r_impedance_770, 364/3=121pt; 6 freq × 5 seg). rightRaw traz
        // I{seg}{freq} já pronto (m.impedancia não é preenchido pelo CLI — cairia no derivado).
        blockImg("r_impedance_770", 942, 733, 364)
        let colSeg = ["RA", "LA", "T", "RL", "LL"]   // impedância: tronco é "T" nas chaves IMP (não "TR")
        let colX: [CGFloat] = [588, 623, 658, 693, 728]
        for (row, freq) in ["1","5","50","250","500","1M"].enumerated() {
            let y = 977 + 14 * CGFloat(row)
            for (c, seg) in colSeg.enumerated() {
                let raw = m.rightRaw["I\(seg)\(freq)"] ?? ""
                if !raw.isEmpty {
                    e.campos.append(gcell(s, raw.replacingOccurrences(of: ".", with: ","), colX[c], y, 35, 15, pt: 7, .c))
                }
            }
        }
    }


    // Rodapé + rótulo do modelo (DrawBodyWater: Arial 8, caixa em hx+234/hy+66; hx=-13, hy=-10).
    private func rodape(_ e: inout E) {
        e.campos.append(gpt(s, "Ver.LookinBody120.5.0.0.0", 33, 1124, pt: 6, .black, box: 420, italic: true))
        e.campos.append(gcell(s, "[InBody770]", -13 + 234, -10 + 66, 300, 20, pt: 8, .f, .black))
    }
}
