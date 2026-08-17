import SwiftUI

// Helpers de desenho portados do .exe (ClsDrawCommon / ClsScale).
// Coordenadas em espaço lógico do .exe (826,67 × 1169,33), textos pelo canto sup-esq (GDI).

typealias Campo = FolhaResultado.Campo
typealias Barra = FolhaResultado.Barra
typealias Ponto = FolhaResultado.Ponto
typealias Linha = FolhaResultado.Linha

// Cores usadas nas barras/linhas (Color.FromArgb do .exe).
enum IB {
    static let dark = Color.black                                   // colorBarBase (770 usa preto)
    static let gray137 = Color(red: 137/255, green: 137/255, blue: 137/255) // zona normal (músculo/gordura/AEC)
    static let gray160 = Color(red: 160/255, green: 160/255, blue: 160/255) // zona normal (% segmentar)
    static let gray87  = Color(red: 87/255,  green: 87/255,  blue: 87/255)  // base da barra % segmentar
    static let gray200 = Color(red: 200/255, green: 200/255, blue: 200/255) // trilho claro / grade tracejada
    static let axis    = Color.black
    static let cinza   = Color(red: 93/255, green: 93/255, blue: 93/255)
    static let laranja = Color(red: 255/255, green: 106/255, blue: 26/255)
    static let darkRed = Color(red: 139/255, green: 0/255, blue: 0/255)      // marcador da curva de crescimento
}

// As escalas (enum Escala) sao GERADAS do resx real em EscalaGerada.swift
// (.exe-reference/oracle/gen_escala.py). Nao redefinir aqui.

// ClsDrawCommon.GetBarWidth (retorna comprimento da barra de valor).
func getBarWidth(_ base: Double, _ interval: Double, _ data: Double, percent: Bool,
                 _ scaleWidth: Double, _ barLength: Int) -> Double {
    var v: Double
    if percent {
        v = (data - base) / interval * scaleWidth - 2
    } else if data <= 100 {
        v = (data - base) / interval * scaleWidth - 2
    } else {
        v = scaleWidth * 3.0 + (data - 100.0) / (interval * 3.0) * scaleWidth - 2
    }
    if v < -11 { v = -2 }
    if v > Double(barLength) { v = Double(barLength) }
    return v
}

// ClsDrawCommon.GetBarWidth2 (usado no trecho não-linear da Taxa de AEC).
func getBarWidth2(_ base: Double, _ interval: Double, _ data: Double,
                  _ scaleWidth: Double, _ barLength: Int) -> Double {
    var v: Double
    if data <= 100 { v = (data - base) / interval * scaleWidth }
    else { v = (data - 100.0) / (interval * 3.0) * scaleWidth }
    if v < 0 { v = 0 }
    if v > Double(barLength) { v = Double(barLength) }
    return v
}

// ClsDrawCommon.GetBarWidth3 (gordura segmentar não-linear; trava em -2 abaixo de -11).
func getBarWidth3(_ base: Double, _ interval: Double, _ data: Double, percent: Bool,
                  _ scaleWidth: Double, _ barLength: Int) -> Double {
    var v: Double
    if percent { v = (data - base) / interval * scaleWidth - 2 }
    else if data <= 100 { v = (data - base) / interval * scaleWidth - 2 }
    else { v = scaleWidth * 3.0 + (data - 100.0) / (interval * 3.0) * scaleWidth }  // >100: SEM -2
    if v < -11 { v = -2 }
    if v > Double(barLength) { v = Double(barLength) }
    return v
}

// ClsDrawCommon.GetBarWidthBMI (IMC / PGC posicionados por tabela de 12 pontos).
func getBarWidthBMI(_ scale: [Double], _ scaleWidth: Double, _ val: Double, _ barLength: Double) -> Double {
    var num = scale.count - 1
    while num >= 0 && !((val - scale[num]) >= 0) { num -= 1 }
    if num == scale.count - 1 { return barLength - 46 }
    var v: Double
    if num != -1 {
        v = Double(num) * scaleWidth + (val - scale[num]) / (scale[num + 1] - scale[num]) * scaleWidth
    } else {
        v = Double(num) * scaleWidth + (val - 0) / scale[num + 1] * scaleWidth
    }
    if v < 0 { v = 0 }
    if v > barLength - 46 { v = barLength - 46 }
    return v
}

// Alinhamento GDI: n=Near(esq), c=Center, f=Far(dir). Vertical sempre centralizado no retângulo.
enum GA { case n, c, f }

private func alinhamento(_ a: GA) -> Alignment {
    switch a { case .n: return .leading; case .c: return .center; case .f: return .trailing }
}

// GDI pt -> px (96dpi), igual ao helper interno do ResultSheet.
private func gpx(_ pt: CGFloat) -> CGFloat { pt * 96.0 / 72.0 }

// DrawString(rect, sf) -> Campo. Centra verticalmente no retângulo como o GDI (LineAlignment=Center).
func gcell(_ s: FolhaResultado, _ txt: String, _ rx: CGFloat, _ ry: CGFloat, _ rw: CGFloat, _ rh: CGFloat,
           pt: CGFloat, _ align: GA, _ cor: Color = .black, bold: Bool = false) -> Campo {
    let emPx = gpx(pt)
    let yTop = ry + (rh - emPx * 1.16) / 2.0
    let x: CGFloat = (align == .c) ? rx + rw/2 : (align == .f ? rx + rw : rx)
    return Campo(txt: txt, x: x, y: yTop, size: emPx, fonte: "Arial", cor: cor,
                 alinha: alinhamento(align), boxW: rw, bold: bold)
}

// Texto por ponto (g.DrawString(txt,font,x,y)) = canto sup-esq.
func gpt(_ s: FolhaResultado, _ txt: String, _ x: CGFloat, _ y: CGFloat,
         pt: CGFloat, _ cor: Color = .black, bold: Bool = false, box: CGFloat = 200, _ align: GA = .n,
         italic: Bool = false) -> Campo {
    Campo(txt: txt, x: x, y: y, size: gpx(pt), fonte: "Arial", cor: cor,
          alinha: alinhamento(align), boxW: box, bold: bold, italic: italic)
}

// Valor no fim de uma barra, centrado verticalmente na LINHA da barra (como no InBody real).
// barTop/thick = geometria da barra; o texto fica na mesma altura da ponta, não abaixo dela.
func gbar(_ s: FolhaResultado, _ txt: String, x: CGFloat, barTop: CGFloat, thick: CGFloat,
          pt: CGFloat = 10, _ cor: Color = .black) -> Campo {
    let h = gpx(pt) * 1.16
    return gpt(s, txt, x, barTop + thick / 2 - h / 2, pt: pt, cor)
}

// Impedância derivada quando o exame não a traz (Z decresce com a frequência; braços>pernas>tronco).
func impedanciaDerivada(_ m: Medida, altura: Double) -> [String: [Int: Double]] {
    let h2 = pow(altura / 100.0, 2)
    func z50(_ segKg: Double, _ fator: Double) -> Double { fator * h2 / max(segKg, 0.3) }
    let base: [String: Double] = [
        "RA": z50(m.seg["RA"] ?? 2, 250), "LA": z50(m.seg["LA"] ?? 2, 252),
        "TR": z50(m.seg["TR"] ?? 20, 160), "RL": z50(m.seg["RL"] ?? 7, 630),
        "LL": z50(m.seg["LL"] ?? 7, 636),
    ]
    let ff: [Int: Double] = [1: 1.19, 5: 1.16, 50: 1.0, 250: 0.91, 500: 0.88, 1000: 0.85]
    var out: [String: [Int: Double]] = [:]
    for (seg, b) in base {
        var linha: [Int: Double] = [:]
        for (k, f) in ff { linha[k] = b * f }
        out[seg] = linha
    }
    return out
}

// Eixo + ticks + rótulos de escala de uma linha de gráfico (comum a várias seções).
// borderOffset: a borda esquerda vertical termina em fTop+GraphHeight+borderOffset no
// oraculo -- cada funcao C# de origem usa um valor DIFERENTE (nao e uma constante unica):
// DrawMuscleFatAnalysisA=-3, DrawObesityAnalysisA=-4, DrawSegmentalLeanAnalysisA=+6,
// DrawECWRatioAnalysisA=+4, DrawBodyWaterCompositionA/DrawSegmentalBodyWaterAnalysisA=-6.
// Verbatim por chamador (achado pelo instrumento de forma, nao visivel no op-diff de texto).
func drawGrade(_ e: inout FolhaResultado.Elementos, _ s: FolhaResultado, fL: CGFloat, fT: CGFloat,
               barLen: CGFloat, gh: CGFloat, ticks: [CGFloat], labels: [String]?, labelY: CGFloat = 6,
               borderOffset: CGFloat) {
    e.linhas.append(hline(fL, fT + 2, fL + barLen))
    e.linhas.append(vline(fL, fT + 2, fT + gh + borderOffset))
    for (j, tx) in ticks.enumerated() {
        e.linhas.append(vline(fL + tx, fT + 2, fT + 5))
        if let labels = labels, j < labels.count {
            e.campos.append(gpt(s, labels[j], fL + tx, fT + labelY, pt: 6, .black, box: 40, .c))
        }
    }
}

func fmtSc(_ v: Double) -> String { v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v) }

// Faixa de percentil do paciente (GetGrowthRank do .exe): "50~85 %", "< 3 %", "> 97 %" ou "".
func growthRank(sexo: String, metrica: GrowthMetric, idade: Int, valor: Double) -> String {
    let a = min(max(idade, GrowthPercentiles.idadeMin), GrowthPercentiles.idadeMax)
    guard let vs = GrowthPercentiles.valores(sexo: sexo, metrica: metrica, idade: a) else { return "" }
    let ps = GrowthPercentiles.percentis
    if valor < vs[0] { return "< \(ps[0]) %" }
    for i in 0..<(vs.count - 1) where valor >= vs[i] && valor <= vs[i + 1] {
        return "\(ps[i])~\(ps[i + 1]) %"
    }
    return "> \(ps[ps.count - 1]) %"
}

// Dígito do WC_TBL.ETYPE2 na posição i (0 se ausente). Índices: [0][1][2]=nutricional (prot/min/gord),
// [6]=obesidade, [9][10][11]=balanceamento (sup/inf/sup-inf). 0=Normal/Balanceado, 1=abaixo/pouco, 2=acima/muito.
func etypeIdx(_ etype2: String, _ i: Int) -> Int {
    let a = Array(etype2)
    guard i >= 0, i < a.count, let d = Int(String(a[i])) else { return 0 }
    return d
}

// Análise Músculo-Gordura (DrawMuscleFatAnalysisA): 3 barras Peso/MME/Gordura. Reusada adulto+criança.
func drawMuscleFatSection(_ e: inout FolhaResultado.Elementos, _ s: FolhaResultado, m: Medida, isM: Bool,
                          fL: CGFloat, fT0: CGFloat) {
    let firstW: CGFloat = 19, sw: CGFloat = 32.5, gh: CGFloat = 33, barW: CGFloat = 7, barLen: CGFloat = 370
    let ux: CGFloat = -33, uw: CGFloat = 28, uh: CGFloat = 32, ug: CGFloat = 32
    let ticks = (0...10).map { firstW + sw * CGFloat($0) }
    // Percentuais de posicionamento reais (MFA_TBL.PWT/PSMM/PBFM); derivação só como reserva.
    let idealBMI = isM ? 22.0 : 21.5
    let midSmm = (m.refSmm.lo + m.refSmm.hi) / 2.0
    let midFat = (m.refGordura.lo + m.refGordura.hi) / 2.0
    let pWT = m.pwt > 0 ? m.pwt : m.imc / idealBMI * 100.0
    let pSMM = m.psmm > 0 ? m.psmm : (midSmm > 0 ? m.smm / midSmm * 100.0 : 100.0)
    let pFat = m.pfat > 0 ? m.pfat : (midFat > 0 ? m.gordura / midFat * 100.0 : 100.0)
    let rows: [(scale: [Double], interval: Double, pct: Double, percent: Bool, valor: String)] = [
        (Escala.wt, 15, pWT, true, s.fmt(m.peso, 1)),
        (Escala.smm, 10, pSMM, true, s.fmt(m.smm, 1)),
        (Escala.bfm, 20, pFat, false, s.fmt(m.gordura, 1)),
    ]
    for i in 0..<3 { e.campos.append(gcell(s, "(kg)", fL + ux, fT0 + ug * CGFloat(i), uw, uh, pt: 7, .f)) }
    for (i, row) in rows.enumerated() {
        let fT = fT0 + gh * CGFloat(i)
        drawGrade(&e, s, fL: fL, fT: fT, barLen: barLen, gh: gh, ticks: ticks, labels: row.scale.prefix(11).map { fmtSc($0) }, borderOffset: -3)
        e.campos.append(gpt(s, "%", fL + barLen - 10, fT + 5, pt: 6))
        var num4 = getBarWidth(row.scale[0], row.interval, row.pct, percent: row.percent, sw, Int(barLen) - 50)
        // Estouro de escala (ClsDrawLeftOutput.DrawMuscleFatAnalysisA:1886): trava em
        // BarLength-50, apaga retângulo branco e anota o percentual (fontGraph 6).
        if num4 >= Double(Int(barLen) - 50) {
            num4 = Double(Int(barLen) - 50)
            e.barras.append(Barra(x: fL + barLen - 40, y: fT + 6, w: 25, h: 10, cor: .white))
            e.campos.append(gpt(s, "(\(s.fmt(row.pct, 0)))", fL + barLen - 40, fT + 6, pt: 6))
        }
        let valuePos = firstW + CGFloat(num4) + 2
        let yTop = fT + (gh - barW) / 2 + 12 - barW - 0.5
        fillBar(&e, xLeft: fL, valuePos: valuePos, yTop: yTop, thick: barW + 1,
                midStart: ticks[2], midLen: sw * 2, baseCor: IB.dark, midCor: IB.gray137, ticks: ticks)
        e.campos.append(barValor(s, row.valor, xLeft: fL, num: CGFloat(num4), yTop: fT, dy: 17))
    }
}

// Análise de Obesidade (DrawObesityAnalysisA): barras IMC/PGC. Reusada adulto+criança.
// Porte VERBATIM de ClsScale.GetBMIScale (ramo BR): escala de IMC. Adulto usa a régua WHO;
// MENOR (idade<18, marcado por IBMI<0.1) usa escala por IBMI2/BMI_MAX2, e quando BMI_MAX2=0
// busca a tabela por idade/sexo (BmiAgeTable, gerada do BMI.resx). num=BMI_MIN, num2=BMI_MAX,
// num3=IBMI(->IBMI2 se flag), num4=IBMI2, num5=BMI_MAX2, num6=idade.
func getBMIScale(bmiMin: Double, bmiMax: Double, ibmi: Double, ibmi2: Double,
                 bmiMax2: Double, age: Double, isM: Bool) -> [Double] {
    var arr = [Double](repeating: 0, count: 12)
    var num = bmiMin, num2 = bmiMax, num3 = ibmi
    let num4 = ibmi2; var num5 = bmiMax2; let num6 = age
    var flag = false
    if num3 < 0.1 { num3 = num4; flag = true }
    if num6 < 18.0 {
        if flag {
            if num5 == 0.0 {
                let key = (isM ? "Male" : "Female") + String(Int(num6))   // Math.Truncate(idade)
                if let a = BmiAgeTable.porIdadeSexo[key], a.count >= 4 { num = a[0]; num2 = a[2]; num5 = a[3] }
            }
            for j in 0..<3 { arr[j] = num - Double((2 - j) * 3) }
            arr[3] = num3; arr[4] = num2
            for k in 0..<7 { arr[k + 5] = num5 + Double(2 * k) }
        } else {
            arr[0] = num3 - 9.0; arr[1] = num3 - 6.0; arr[2] = num; arr[3] = num3; arr[4] = num2
            for l in 2..<9 { arr[l + 3] = num3 + Double(l * 3) }
        }
    } else {
        arr = isM ? BmiAgeTable.whoMale : BmiAgeTable.whoFemale
        arr[2] = num; arr[3] = num3; arr[4] = num2
        if flag { arr[5] = num5 }
    }
    return arr
}

func drawObesitySection(_ e: inout FolhaResultado.Elementos, _ s: FolhaResultado, m: Medida, isM: Bool,
                        idade: Double, fL: CGFloat, fT0: CGFloat) {
    let firstW: CGFloat = 19, sw: CGFloat = 32.5, gh: CGFloat = 33, barW: CGFloat = 7, barLen: CGFloat = 370
    let ticks = (0...10).map { firstW + sw * CGFloat($0) }
    // Escala IMC = porte verbatim do GetBMIScale (adulto WHO; menor por idade/IBMI2/BMI_MAX2).
    let bmiScale = getBMIScale(bmiMin: m.bmiMin, bmiMax: m.bmiMax, ibmi: m.ibmiRaw, ibmi2: m.ibmi,
                               bmiMax2: m.bmiMax2, age: idade, isM: isM)
    // Escala PGC: faixa/ideal reais (MFA_TBL.PBF_MIN/IPBF/PBF_MAX) com reserva por sexo.
    let pbfMin = m.pbfMin > 0 ? m.pbfMin : (isM ? 10.0 : 18.0)
    let pbfMax = m.pbfMax > 0 ? m.pbfMax : (isM ? 20.0 : 28.0)
    let ipbf = m.ipbf > 0 ? m.ipbf : (isM ? 15.0 : 23.0)
    let step = pbfMin < 10 ? pbfMin / 2 : 5.0
    var pbfScale: [Double] = []
    for i in 0..<3 { pbfScale.append(pbfMin + Double(i - 2) * step) }
    pbfScale.append(ipbf)
    for j in 0..<8 { pbfScale.append(pbfMax + Double(j) * 5.0) }
    let rows: [(scale: [Double], val: Double, valStr: String)] = [
        (bmiScale, m.imc, s.fmt(m.imc, 1)), (pbfScale, m.pgc, s.fmt(m.pgc, 1)),
    ]
    for (i, row) in rows.enumerated() {
        let fT = fT0 + gh * CGFloat(i)
        drawGrade(&e, s, fL: fL, fT: fT, barLen: barLen, gh: gh, ticks: ticks,
                  labels: (0...10).map { fmtScaleLabel(row.scale[$0], 1) }, borderOffset: -4)   // escala = half-even (ToString)
        var num = getBarWidthBMI(row.scale, sw, row.val, barLen)
        // Estouro (ClsDrawLeftOutput.DrawObesityAnalysisA:2178/2204): o .exe trava o valor
        // saturado em BarLength-50 (nao -46), apaga retangulo branco e anota o valor.
        if num >= Double(Int(barLen) - 50) {
            num = Double(Int(barLen) - 50)
            e.barras.append(Barra(x: fL + barLen - 45, y: fT + 6, w: 35, h: 10, cor: .white))
            e.campos.append(gpt(s, "(\(row.valStr))", fL + barLen - 35, fT + 6, pt: 6))
        }
        let valuePos = firstW + CGFloat(num)
        let yTop = fT + (gh - barW) / 2 + 12 - barW - 0.5
        fillBar(&e, xLeft: fL, valuePos: valuePos, yTop: yTop, thick: barW + 1,
                midStart: ticks[2], midLen: sw * 2, baseCor: IB.dark, midCor: IB.gray137, ticks: ticks)
        e.campos.append(barValor(s, row.valStr, xLeft: fL, num: CGFloat(num), yTop: fT, dy: 16))
    }
}

func shortDt(_ raw: String) -> String {
    let d = String(raw.prefix(10))
    let parts = d.split(separator: "/")
    guard parts.count == 3 else { return d }
    let yy = parts[0].count == 4 ? String(parts[0].suffix(2)) : String(parts[0])
    return "\(yy)/\(parts[1])/\(parts[2])"
}

// Hora "HH:mm" do carimbo "yyyy/MM/dd HH:mm" (2ª linha da data no histórico). "" se ausente.
func shortHora(_ raw: String) -> String {
    let parts = raw.split(separator: " ")
    guard parts.count >= 2 else { return "" }
    return String(parts[1].prefix(5))
}

// Cores da grade do histórico (penRectVertical/penDateVertical do ClsLineGraph).
private let histGrade = Color(red: 214/255, green: 214/255, blue: 214/255)   // D6D6D6
private let histData  = Color(red: 151/255, green: 151/255, blue: 153/255)   // 979799

// Data curta do histórico + hora "HH:mm". Respeita SheetSettings.dateFormat (settings.xml da
// clínica; BR = "dd.MM.yyyy."). yyyy -> yy (linha 1 do rótulo é curta, cabe em ~26px do gráfico).
func histDataLinhas(_ raw: String, _ fmt: String) -> (String, String) {
    let (yy, mm, dd, hh, mi): (String, String, String, String, String) = {
        if !raw.contains("/"), !raw.contains("."), !raw.contains("-"), !raw.contains(" ") {
            let a = Array(raw.filter { $0.isNumber })
            if a.count >= 12 {
                return (String(a[2..<4]), String(a[4..<6]), String(a[6..<8]),
                        String(a[8..<10]), String(a[10..<12]))
            }
        }
        let parts = raw.split(separator: " ", maxSplits: 1)
        let dpart = parts.first.map(String.init) ?? raw
        let comps = dpart.split(whereSeparator: { $0 == "/" || $0 == "." || $0 == "-" }).map(String.init)
        var y = comps.count > 0 ? comps[0] : ""
        let m = comps.count > 1 ? comps[1] : "", d = comps.count > 2 ? comps[2] : ""
        if y.count == 4 { y = String(y.suffix(2)) }
        let hpart = parts.count >= 2 ? String(parts[1]) : ""
        let hcomps = hpart.split(separator: ":").map(String.init)
        let h = hcomps.count > 0 ? String(hcomps[0].prefix(2)) : ""
        let i = hcomps.count > 1 ? String(hcomps[1].prefix(2)) : ""
        return (y, m, d, h, i)
    }()
    // Aplica o dateFormat da clínica (ano completo, 4 dígitos). Fallback: dd.MM.yyyy.
    let padrao = SheetSettings.dateFormat.isEmpty ? "dd.MM.yyyy" : SheetSettings.dateFormat
    let yyyy = "20" + yy
    var linha = padrao
    linha = linha.replacingOccurrences(of: "yyyy", with: yyyy)
    linha = linha.replacingOccurrences(of: "dd", with: dd)
    linha = linha.replacingOccurrences(of: "MM", with: mm)
    linha = linha.replacingOccurrences(of: "yy", with: yy)
    let hora = (hh.isEmpty && mi.isEmpty) ? "" : "\(hh):\(mi)"
    return (linha, hora)
}

// Histórico da Composição (DrawBodyCompostionHistoryD + ClsLineGraph.DrawHistoryGraph, caso RecentGraph).
// PORTE VERBATIM: min/max próprio por série; pontos, linhas de ligação, grade (horizontais + tick à
// esquerda + verticais), rótulos de unidade (sfUnit Far), retângulo de fundo das datas, valor do
// último ponto em caixa mais larga, datas em 2 linhas "yy.MM.dd"+"HH:mm" (sfCC centrado), linha-base.
// `datas`/`series` chegam em ordem CRONOLÓGICA (antigo->recente); o wrapper reverte (recente à ESQUERDA).
func drawHistorico(_ e: inout FolhaResultado.Elementos, _ s: FolhaResultado,
                   fL: CGFloat, fT: CGFloat, graphW: CGFloat, graphH: CGFloat, dateH: CGFloat,
                   datas: [String], series: [(vals: [Double], casas: Int)],
                   maxLen: Int = 8, ellipseSize: CGFloat = 6, dateCenterGap: CGFloat = 4,
                   unitX: CGFloat = -33, unitY: CGFloat = 0, unitW: CGFloat = 31, unitH: CGFloat = 38,
                   unitGap: CGFloat = 39, unitWeight: String = "kg", unitPercent: String = "%",
                   units: [String]? = nil,
                   lineX: CGFloat = -95, lineY: CGFloat = 157, dateFormat: String = "yyyy.MM.dd") {
    let n = datas.count, cols = series.count
    guard n > 0, cols > 0 else { return }
    // Métricas GDI (ClsLineGraph.Initialize + DrawHistoryGraph). topMargin = MeasureString("0",Arial10).
    let topMargin = gpx(10) * 1.16, dataHeight = gpx(10) * 1.16, bottomMargin: CGFloat = 5
    let osw = graphW / CGFloat(maxLen)
    let osh = (graphH - dateH) / CGFloat(cols)
    let pointDrawHeight = osh - (topMargin + bottomMargin + ellipseSize / 2)
    let num19 = osw / 2 - ellipseSize / 2

    // Ordem cronológica normal: antigo à esquerda, recente à direita. Assim o "last" (j==n-1)
    // cai no ponto mais recente, ganhando a caixa maior e Arial 10 (destaque no valor atual).
    let dts = datas
    let ser = series.map { (vals: $0.vals, casas: $0.casas) }

    // --- Rótulos de unidade (bUnitUse): "(kg)","(kg)","(%)" — sfUnit = Far/Center, Arial 7 ---
    let ux = fL.rounded(.towardZero) + unitX, uy = fT.rounded(.towardZero) + unitY
    if let units = units {
        // Pediátrica (DrawBodyCompostionHistoryC verbatim): uma unidade por faixa (cm/kg/kg/%),
        // passo fixo = UnitGap (igual ao adulto D), NÃO osh. Row i em fT+UnitY + UnitGap*i.
        for (i, u) in units.enumerated() where !u.isEmpty {
            e.campos.append(gcell(s, "(\(u))", ux, uy + unitGap * CGFloat(i), unitW, unitH, pt: 7, .f))
        }
    } else {
        // Adulto (DrawBodyCompostionHistoryD verbatim): kg/kg/% nas faixas 0,1,2; AEC sem unidade.
        e.campos.append(gcell(s, "(\(unitWeight))", ux, uy, unitW, unitH, pt: 7, .f))
        e.campos.append(gcell(s, "(\(unitWeight))", ux, uy + unitGap, unitW, unitH, pt: 7, .f))
        e.campos.append(gcell(s, "(\(unitPercent))", ux, uy + unitGap * 2, unitW, unitH, pt: 7, .f))
    }

    // --- Retângulo de fundo das datas (FillRectangle branco) ---
    e.barras.append(Barra(x: fL, y: fT + osh * CGFloat(cols), w: graphW, h: dateH, cor: .white))

    // --- Grade horizontal + tick à esquerda de cada faixa (penRectHorizon, preto) ---
    for i in 1...cols {
        let yTick0 = fT + CGFloat(i - 1) * osh + (cols == 1 ? 0 : osh / 7)
        e.linhas.append(vline(fL, yTick0, fT + CGFloat(i - 1) * osh + osh, .black, 1))
        e.linhas.append(hline(fL, fT + CGFloat(i) * osh, fL + graphW, .black, 1))
    }
    // --- Grade vertical (penRectVertical D6D6D6 na área do gráfico; penDateVertical 979799 na faixa de datas) ---
    for k in 1..<maxLen {
        let vx = fL + CGFloat(k) * osw
        e.linhas.append(vline(vx, fT, fT + graphH - dateH, histGrade, 1.5))
        e.linhas.append(vline(vx, fT + graphH - dateH, fT + graphH, histData, 1.5))
    }

    // --- Pontos, linhas de ligação e rótulos, por série (coluna) ---
    for col in 0..<cols {
        let vals = ser[col].vals, casas = ser[col].casas
        let mn = vals.min() ?? 0, mx = vals.max() ?? 0
        let rng = mx - mn
        func point(_ j: Int) -> (CGFloat, CGFloat) {
            let d = pointDrawHeight / (rng == 0 ? 1 : CGFloat(rng)) * CGFloat(mx - vals[j])
            let num31 = rng == 0 ? (pointDrawHeight - ellipseSize) : d
            let x = fL + CGFloat(j) * osw + num19 + ellipseSize / 2
            let y = fT + topMargin + CGFloat(col) * osh + num31 + ellipseSize / 2
            return (x, y)
        }
        for j in 0..<n {
            let p = point(j)
            let last = (j == n - 1)
            if !last {
                let q = point(j + 1)
                e.linhas.append(Linha(pts: [p, q], cor: .black, w: 1))
            }
            e.pontos.append(Ponto(x: p.0, y: p.1, r: ellipseSize / 2, cor: .black))
            let txt = s.fmt(vals[j], casas)
            if last {   // caixa mais larga (osw+20, deslocada -10), fontLastValue Arial 10
                e.campos.append(gcell(s, txt, p.0 - num19 - ellipseSize / 2 - 10, p.1 - dataHeight - 2,
                                      osw + 20, dataHeight, pt: 10, .c))
            } else {    // caixa normal (osw), fontValue Arial 10
                e.campos.append(gcell(s, txt, p.0 - num19 - ellipseSize / 2, p.1 - topMargin - 2,
                                      osw, topMargin, pt: 10, .c))
            }
        }
    }

    // --- Datas em 2 linhas (sfCC = centro/centro), Arial 6 ---
    let dateRectY = fT + dateCenterGap + osh * CGFloat(cols) - 2
    for j in 0..<n {
        let rectX = fL + CGFloat(j) * osw - 3
        let (dStr, hStr) = histDataLinhas(dts[j], dateFormat)
        e.campos.append(gcell(s, dStr, rectX, dateRectY, osw + 6, dateH / 2, pt: 6, .c))
        if !hStr.isEmpty {
            e.campos.append(gcell(s, hStr, rectX, dateRectY + dateH / 2, osw + 6, dateH / 2, pt: 6, .c))
        }
    }

    // --- Linha-base sob o gráfico (g.DrawLine, preto) ---
    e.linhas.append(hline(fL + lineX, fT + lineY, fL + graphW, .black, 1))
}

// QR (r_re_qr/r_qr) — sem gerador real embutido: desenha um QR-placeholder determinístico do payload
// (3 finders + módulos derivados do payload). Quadrado com padrão mesmo quando payload é vazio.
func drawQR(_ e: inout FolhaResultado.Elementos, x: CGFloat, y: CGFloat, size: CGFloat, payload: String?) {
    let n = 21
    let cell = size / CGFloat(n)
    e.barras.append(Barra(x: x, y: y, w: size, h: size, cor: .white))
    func fill(_ r: Int, _ c: Int) {
        e.barras.append(Barra(x: x + CGFloat(c) * cell, y: y + CGFloat(r) * cell, w: cell + 0.4, h: cell + 0.4, cor: .black))
    }
    func finder(_ r0: Int, _ c0: Int) {
        for r in 0..<7 { for c in 0..<7 {
            let edge = r == 0 || r == 6 || c == 0 || c == 6
            let core = (2...4).contains(r) && (2...4).contains(c)
            if edge || core { fill(r0 + r, c0 + c) }
        }}
    }
    finder(0, 0); finder(0, n - 7); finder(n - 7, 0)
    var seed: UInt32 = Array((payload ?? "InBody770").utf8).reduce(2166136261) { ($0 ^ UInt32($1)) &* 16777619 }
    func bit() -> Bool { seed = seed &* 1103515245 &+ 12345; return (seed >> 16) & 1 == 1 }
    for r in 0..<n { for c in 0..<n {
        let inFinder = (r < 8 && c < 8) || (r < 8 && c >= n - 8) || (r >= n - 8 && c < 8)
        if inFinder { continue }
        if bit() { fill(r, c) }
    }}
    e.linhas.append(Linha(pts: [(x, y), (x + size, y), (x + size, y + size), (x, y + size), (x, y)], cor: IB.gray200, w: 0.6))
}

// Rodapé/cabeçalho comuns às 3 folhas (QA seção G): versão+S/N no canto inf-esq e marcador do modelo.
func rodapeComum(_ e: inout FolhaResultado.Elementos, _ s: FolhaResultado) {
    // DrawProgramInformation (ClsDrawLeftOutput:111): base.Left+25=26, base.Top+1113=1118,
    // Brushes.Black, FontProgram = Arial 6 itálico.
    e.campos.append(gpt(s, "Ver.LookinBody120.5.0.0.0", 26, 1118, pt: 6, .black, box: 420, italic: true))
    // [InBody<equip>] no cabeçalho (ClsDrawHeader.DrawInBody:289-297): retângulo (fLeft+217, fTop+64,
    // 300×20) = (195,48), alinhado à direita (Far), Arial 10 preto. hx/hy = baseLeft-23/baseTop-21.
    e.campos.append(gcell(s, "[InBody770]", 195, 48, 300, 20, pt: 10, .f, .black))
}

// Contorno de elipse como polilinha (não há primitiva de elipse no modelo de render).
func ellipsePoly(cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat,
                 cor: Color = .black, w: CGFloat = 0.8, steps: Int = 48) -> Linha {
    var pts: [(CGFloat, CGFloat)] = []
    for i in 0...steps {
        let a = 2 * Double.pi * Double(i) / Double(steps)
        pts.append((cx + rx * CGFloat(cos(a)), cy + ry * CGFloat(sin(a))))
    }
    return Linha(pts: pts, cor: cor, w: w)
}

func hline(_ x1: CGFloat, _ y: CGFloat, _ x2: CGFloat, _ cor: Color = .black, _ w: CGFloat = 0.7) -> Linha {
    Linha(pts: [(x1, y), (x2, y)], cor: cor, w: w)
}
func vline(_ x: CGFloat, _ y1: CGFloat, _ y2: CGFloat, _ cor: Color = .black, _ w: CGFloat = 0.7) -> Linha {
    Linha(pts: [(x, y1), (x, y2)], cor: cor, w: w)
}

// Barra horizontal preenchida (base) com faixa "normal" cinza por cima, cortada no valor.
// xLeft = origem; valuePos = comprimento visível; yTop/thick = geometria vertical.
// midStart/midLen = faixa normal relativa a xLeft.
// ticks = offsets (relativos a xLeft) onde o .exe desenha separadores brancos de 1px por CIMA
// da barra (g.DrawLine(Pens.White, ...) em cada array[j]). Ordem de render: base → faixa → ticks.
func fillBar(_ e: inout FolhaResultado.Elementos, xLeft: CGFloat, valuePos: CGFloat,
             yTop: CGFloat, thick: CGFloat, midStart: CGFloat, midLen: CGFloat,
             baseCor: Color, midCor: Color, ticks: [CGFloat] = []) {
    guard valuePos > 0 else { return }
    e.barras.append(Barra(x: xLeft, y: yTop, w: valuePos, h: thick, cor: baseCor))
    // A zona de referência (cinza) É desenhada cheia no oráculo, mas uma máscara branca
    // (o próprio marcador de valor) cobre tudo além de onde o valor termina -- então o
    // resultado VISÍVEL da zona cinza é sempre cortada em valuePos, igual à trilha preta.
    // Revertido: o corte por valuePos já estava certo; o bug real era no instrumento
    // (apply_erasers não tratava "apagador cobre o retângulo inteiro").
    if valuePos > midStart {
        let mlen = min(midLen, valuePos - midStart)
        if mlen > 0 { e.barras.append(Barra(x: xLeft + midStart, y: yTop, w: mlen, h: thick, cor: midCor)) }
    }
    // Separadores brancos de tick, só dentro da parte preenchida da barra.
    for t in ticks where t > 0 && t <= valuePos {
        e.barras.append(Barra(x: xLeft + t, y: yTop - 1, w: 1, h: thick + 2, cor: .white))
    }
}

// Número do valor no fim da barra, posicionado pelo canto sup-esq num Y FIXO relativo a fTop
// (como o .exe: g.DrawString(valor, fontValue, XBase+20+num+5, fTop+dy)). Arial 10 preto.
func barValor(_ s: FolhaResultado, _ txt: String, xLeft: CGFloat, num: CGFloat, yTop fT: CGFloat,
              dy: CGFloat, pt: CGFloat = 10) -> Campo {
    gpt(s, txt, xLeft + 25 + num, fT + dy, pt: pt, .black)
}
