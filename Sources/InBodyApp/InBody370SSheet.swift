import SwiftUI

// Folha do InBody 370S (ResultsSheetInBody370S.DrawResultsSheetA4, ramo InBody370_Body pt-BR).
// LADO ESQUERDO: composição ESCADA (DrawBodyCompositionAnalysisA, como o 770) + músculo-gordura +
// obesidade + DOIS BONECOS (silhueta realista) + histórico. COLUNA DIREITA própria (Tipo de Corpo,
// Controle de Peso, Circunferência Segmentar, Cintura-Quadril, Gordura Visceral, Dados, Impedância 3 freq).
struct InBody370SSheet {
    let s: FolhaResultado
    init(_ s: FolhaResultado) { self.s = s }
    var m: Medida { s.med }
    var p: Paciente { s.pac }
    var isM: Bool { p.sexo == "M" }
    // base.Left/Top: o driver só soma Top+=2 (calibrar visualmente).
    private let L0: CGFloat = 1, T0: CGFloat = 2

    func build() -> E {
        var e = E()
        composicaoEscada(&e)   // DrawBodyCompositionAnalysisA (Left+344, Top+183)
        drawMuscleFatSection(&e, s, m: m, isM: isM, fL: L0 + 117, fT0: T0 + 380)
        drawObesitySection(&e, s, m: m, isM: isM, idade: Double(p.idade), fL: L0 + 117, fT0: T0 + 547)
        bonecos(&e)            // SegmentalLeanD + SegmentalFatA (Left+21 / Left+268)
        historico(&e)          // DrawBodyCompostionHistoryB (Left+119, Top+959)
        colunaDireita(&e)
        InBody120Sheet(s).rodape(&e, marcador: "[InBody370S]", versao: "Ver.LookinBody120.4.0.0.7")
        return e
    }

    // MARK: - Composição ESCADA (DrawBodyCompositionAnalysisA, fLeft=345 fTop=185)
    // params 370S: unit(-254,-4,28,35) valor(-224,1,75,16) faixa(-230,15,85,11) hg=32 wg=76.
    private func composicaoEscada(_ e: inout E) {
        let fL: CGFloat = L0 + 344, fT: CGFloat = T0 + 183
        let ux: CGFloat = -254, uy: CGFloat = -4, uw: CGFloat = 28, uh: CGFloat = 35
        let vx: CGFloat = -224, vy: CGFloat = 1, vw: CGFloat = 75, vh: CGFloat = 16
        let rx: CGFloat = -230, ry: CGFloat = 15, rw: CGFloat = 85, rh: CGFloat = 11
        let hg: CGFloat = 32, wg: CGFloat = 76
        let hgi = CGFloat(Int(hg) / 2)
        func rng(_ r: Referencia, _ c: Int = 1) -> String { "(\(s.fmt(r.lo,c))~\(s.fmt(r.hi,c)))" }

        // Coluna "Valores": TBW, Proteína, Minerais, Gordura (unidade + valor + faixa).
        let col: [(v: Double, r: Referencia, c: Int, u: String)] = [
            (m.tbw, m.refTbw, 1, "L"), (m.proteina, m.refProteina, 1, "kg"),
            (m.mineral, m.refMineral, 2, "kg"), (m.gordura, m.refGordura, 1, "kg"),
        ]
        for (i, c) in col.enumerated() {
            let y = fT + hg * CGFloat(i)
            if c.v != 0 {
                e.campos.append(gcell(s, s.fmt(c.v, c.c), fL+vx, y+vy, vw, vh, pt: 10, .c))
                e.campos.append(gcell(s, "(\(c.u))", fL+ux, y+uy, uw, uh, pt: 7, .f))
            }
            if c.r.lo != 0 { e.campos.append(gcell(s, rng(c.r, c.c), fL+rx, y+ry, rw, rh, pt: 8, .c)) }
        }
        // Escada: Água Corporal Total (TBW), Massa Magra (SLM), Massa Livre de Gordura (FFM), Peso.
        if m.tbw != 0 { e.campos.append(gcell(s, s.fmt(m.tbw,1), fL+vx+wg*1, fT+vy, vw, vh+rh, pt: 10, .c)) }
        if m.slm != 0 { e.campos.append(gcell(s, s.fmt(m.slm,1), fL+vx+wg*2, fT+vy+hgi, vw, vh, pt: 10, .c)) }
        if m.refSlm.lo != 0 { e.campos.append(gcell(s, rng(m.refSlm), fL+rx+wg*2, fT+ry+hgi, rw, rh, pt: 8, .c)) }
        if m.ffm != 0 { e.campos.append(gcell(s, s.fmt(m.ffm,1), fL+vx+wg*3, fT+vy+hgi*2, vw, vh, pt: 10, .c)) }
        if m.refFfm.lo != 0 { e.campos.append(gcell(s, rng(m.refFfm), fL+rx+wg*3, fT+ry+hgi*2, rw, rh, pt: 8, .c)) }
        if m.peso != 0 { e.campos.append(gcell(s, s.fmt(m.peso,1), fL+vx+wg*4, fT+vy+hgi*3, vw, vh, pt: 10, .c)) }
        if m.refPeso.lo != 0 { e.campos.append(gcell(s, rng(m.refPeso), fL+rx+wg*4, fT+ry+hgi*3, rw, rh, pt: 8, .c)) }
    }

    // MARK: - Bonecos (silhueta realista): quadrantes iguais aos da 120, âncoras da 370S.
    private struct Quad { let key: String; let x: CGFloat; let y: CGFloat; let evalIdx: Int }
    private let quads: [Quad] = [
        Quad(key: "LA", x: 0, y: 20, evalIdx: 0), Quad(key: "RA", x: 114, y: 20, evalIdx: 1),
        Quad(key: "TR", x: 55, y: 80, evalIdx: 2), Quad(key: "LL", x: 0, y: 140, evalIdx: 3),
        Quad(key: "RL", x: 114, y: 140, evalIdx: 4),
    ]
    private func fmtSegKg(_ v: Double) -> String { s.fmt(v, v >= 10 ? 1 : 2) }
    private func avalPT(_ et: String, _ i: Int) -> String {
        guard et.count > i else { return "" }
        switch Array(et)[i] { case "2": return "Acima"; case "1": return "Normal"; case "0": return "Abaixo"; default: return "" }
    }
    private func boneco(_ e: inout E, fL: CGFloat, fT: CGFloat, kg: [String: Double], pct: [String: Double], base: Int) {
        for q in quads {
            let bx = fL + q.x, by = fT + q.y
            e.campos.append(gcell(s, fmtSegKg(kg[q.key] ?? 0) + "kg", bx, by, 110, 20, pt: 9, .c))
            e.campos.append(gcell(s, s.fmt(pct[q.key] ?? 0, 1) + "%", bx, by + 20, 110, 20, pt: 9, .c))
            e.campos.append(gcell(s, avalPT(m.etype3, base + q.evalIdx), bx, by + 40, 110, 20, pt: 8, .c))
            e.linhas.append(hline(bx + 18, by + 18, bx + 91, IB.dark, 0.5))
            e.linhas.append(hline(bx + 18, by + 38, bx + 91, IB.dark, 0.5))
        }
    }
    private func bonecos(_ e: inout E) {
        let fT: CGFloat = T0 + 667
        boneco(&e, fL: L0 + 21, fT: fT, kg: m.seg, pct: m.segpIdeal, base: 0)
        boneco(&e, fL: L0 + 268, fT: fT, kg: m.segFat, pct: m.segFatP, base: 5)
    }

    private func historico(_ e: inout E) {
        let chron = Array(p.exames.reversed())
        drawHistorico(&e, s, fL: L0 + 21 + 94, fT: T0 + 959, graphW: 378, graphH: 138, dateH: 22,
                      datas: chron.map { $0.data },
                      series: [(chron.map { $0.peso }, 1), (chron.map { $0.smm }, 1), (chron.map { $0.pgc }, 1)])
    }

    // MARK: - Coluna direita da 370S.
    private func colunaDireita(_ e: inout E) {
        let fLeft: CGFloat = L0 + 517, fTop0: CGFloat = T0 + 141
        var cur: CGFloat = 0
        func RB(_ v: CGFloat) -> CGFloat { CGFloat(Int(v.rounded(.toNearestOrEven))) }
        func blk(_ name: String, _ w: Int, _ h: Int, at top: CGFloat) {
            e.imgs.append(FolhaResultado.Img(nome: "inbody_right_\(name)", x: fLeft, y: top, w: CGFloat(w)/3, h: CGFloat(h)/3))
        }
        func rr(_ k: String) -> String { m.rightRaw[k] ?? "" }
        func comma(_ t: String) -> String { t.replacingOccurrences(of: ".", with: ",") }
        func sinal(_ raw: String) -> String {
            let t = raw.trimmingCharacters(in: .whitespaces); if t.isEmpty { return t }
            if t.first == "-" { return "- " + t.dropFirst() }
            return (Double(t) ?? 0) != 0 ? "+ " + t : t
        }
        func g(_ pt: CGFloat) -> CGFloat { pt * 96.0 / 72.0 }
        func txt(_ t: String, _ x: CGFloat, _ y: CGFloat, pt: CGFloat, bold: Bool = false, _ al: Alignment = .leading, box: CGFloat = 300) {
            e.campos.append(FolhaResultado.Campo(txt: t, x: x, y: y, size: g(pt), fonte: "Arial", cor: .black, alinha: al, boxW: box, bold: bold))
        }
        func barra(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, frac: CGFloat) {
            e.linhas.append(hline(x, y, x + w, IB.gray160, 0.6))
            e.barras.append(Barra(x: x, y: y - 3, w: max(0, min(1, frac)) * w, h: 6, cor: IB.dark))
        }

        // 1) Pontuação InBody
        do {
            let fTop = fTop0 + cur
            blk("r_inbody_score", 733, 280, at: fTop)
            let sc = rr("fs"); if !sc.isEmpty { e.campos.append(gcell(s, sc, fLeft + 32, RB(fTop) + 29, 80, 30, pt: 20, .f)) }
            cur += 280.0/3.0
        }
        // 2) Tipo de Corpo (grade 2D IMC × PGC): borda + divisórias + rótulos de região + eixos + marcador.
        do {
            let y0 = fTop0 + cur + 4
            txt(T("Body Type"), fLeft + 0, y0, pt: 10, bold: true, box: 160)
            let gx = fLeft + 30, gy = y0 + 30, gw: CGFloat = 212, gh: CGFloat = 250
            // borda
            e.linhas.append(hline(gx, gy, gx + gw, IB.dark, 0.8)); e.linhas.append(hline(gx, gy + gh, gx + gw, IB.dark, 0.8))
            e.linhas.append(vline(gx, gy, gy + gh, IB.dark, 0.8)); e.linhas.append(vline(gx + gw, gy, gy + gh, IB.dark, 0.8))
            // divisórias (pontilhado aproximado por linha fina)
            for c in 1...2 { e.linhas.append(vline(gx + gw * CGFloat(c)/3, gy, gy + gh, IB.gray160, 0.4)) }
            for r in 1...3 { e.linhas.append(hline(gx, gy + gh * CGFloat(r)/4, gx + gw, IB.gray160, 0.4)) }
            // rótulos de região (3 col × 4 linhas)
            let reg: [[String]] = [
                [T("Athletic"), T("Muscular\nform"), T("Obese")],
                [T("Muscular"), T("Average"), T("Slightly\nObese")],
                [T("Lean\nmuscular"), T("Lean"), T("Sarcopenic\nObesity")],
                [T("Very\nlean"), T("Slightly lean"), ""],
            ]
            for r in 0..<4 { for c in 0..<3 {
                let parts = reg[r][c].split(separator: "\n").map(String.init)
                for (k, ln) in parts.enumerated() {
                    txt(ln, gx + gw * CGFloat(c)/3 + 4, gy + gh * CGFloat(r)/4 + 4 + CGFloat(k)*9, pt: 6.5, box: 68)
                }
            }}
            // eixos
            txt("I M C", gx - 28, gy - 6, pt: 6.5, box: 30); txt("(kg/m²)", gx - 30, gy + 2, pt: 5.5, box: 32)
            txt("25,0", gx - 28, gy + gh/4 - 4, pt: 6.5, .trailing, box: 26)
            txt("18,5", gx - 28, gy + gh*3/4 - 4, pt: 6.5, .trailing, box: 26)
            txt("10,0", gx + gw/3 - 14, gy + gh + 3, pt: 6.5, .center, box: 28)
            txt("20,0", gx + gw*2/3 - 14, gy + gh + 3, pt: 6.5, .center, box: 28)
            txt(T("Percent Body Fat"), gx + 60, gy + gh + 12, pt: 6, box: 130)
            txt("(%)", gx + gw - 14, gy + gh + 12, pt: 5.5, box: 20)
            // marcador (+) na posição (PGC, IMC). PGC eixo: 10→gx+gw/3, 20→gx+gw*2/3. IMC: 25→gy+gh/4, 18.5→gy+gh*3/4.
            let pgc = Double(rr("")) ?? m.pgc, imc = m.imc
            let mx = gx + gw/3 + gw/3 * CGFloat((m.pgc - 10) / 10)
            let my = gy + gh/4 + gh/2 * CGFloat((25 - imc) / 6.5)
            _ = pgc
            e.linhas.append(hline(mx - 6, my, mx + 6, .black, 1.5)); e.linhas.append(vline(mx, my - 6, my + 6, .black, 1.5))
            cur = (gy + gh + 26) - fTop0
        }
        // 3) Controle de Peso
        do {
            let fTop = fTop0 + cur
            blk("r_wei_con", 733, 280, at: fTop)
            let iTop = RB(fTop)
            let vals = [rr("tw"), sinal(rr("wc")), sinal(rr("fc")), sinal(rr("mc"))]
            for row in 0..<4 {
                let uy = iTop + 22 + 17 * CGFloat(row)
                e.campos.append(gcell(s, "kg", fLeft + 146, uy, 40, 20, pt: 7, .n))
                if !vals[row].isEmpty { e.campos.append(gcell(s, comma(vals[row]), fLeft + 53, uy, 90, 20, pt: 9, .f)) }
            }
            cur += 280.0/3.0
        }
        // 4) Circunferência Segmentar (rótulo + valor + cm).
        do {
            var y = fTop0 + cur + 4
            txt(T("Segmental Circumference"), fLeft + 0, y, pt: 10, bold: true, box: 230); y += 18
            let rows: [(String, String)] = [
                (T("Neck"), "circ_pescoco"), (T("Chest"), "circ_peito"), (T("Abdomen"), "circ_abdomen"),
                (T("Hip"), "circ_quadril"), (T("Right Arm"), "circ_bracoD"), (T("Left Arm"), "circ_bracoE"),
                (T("Right Thigh"), "circ_coxaD"), (T("Left Thigh"), "circ_coxaE"),
            ]
            for (rot, k) in rows {
                txt(rot, fLeft + 0, y, pt: 8, box: 130)
                let v = rr(k)
                if !v.isEmpty { e.campos.append(gcell(s, comma(v), fLeft + 96, y - 2, 60, 18, pt: 9, .f)); txt("cm", fLeft + 160, y, pt: 6.5, box: 20) }
                y += 16
            }
            cur = (y + 2) - fTop0
        }
        // 5) Relação Cintura-Quadril
        do {
            let y = fTop0 + cur + 2
            txt(T("Waist-Hip Ratio"), fLeft + 0, y, pt: 9, bold: true, box: 200)
            txt(comma(rr("whr")), fLeft + 20, y + 20, pt: 11, .center, box: 60)
            txt("0,80", fLeft + 130, y + 12, pt: 7, .center, box: 30); txt("0,90", fLeft + 168, y + 12, pt: 7, .center, box: 30)
            let whr = Double(rr("whr")) ?? 0
            barra(fLeft + 110, y + 28, 130, frac: CGFloat((whr - 0.7) / 0.35))
            cur += 44
        }
        // 6) Nível de Gordura Visceral
        do {
            let y = fTop0 + cur + 2
            txt(T("Visceral Fat Level"), fLeft + 0, y, pt: 9, bold: true, box: 220)
            txt(T("Level"), fLeft + 10, y + 20, pt: 8, box: 40); txt(rr("vfl"), fLeft + 50, y + 18, pt: 11, box: 40)
            txt(T("Below"), fLeft + 112, y + 12, pt: 6, box: 34); txt("10", fLeft + 165, y + 10, pt: 9, .center, box: 22); txt(T("Above"), fLeft + 208, y + 12, pt: 6, box: 34)
            let vfl = Double(rr("vfl")) ?? 0
            barra(fLeft + 110, y + 28, 130, frac: CGFloat(vfl / 20.0))
            cur += 44
        }
        // 7) Dados adicionais (MME, TMB, SMI, Ingestão) — rótulos desenhados.
        do {
            var y = fTop0 + cur + 2
            txt(T("Additional data"), fLeft + 0, y, pt: 9, bold: true, box: 160); y += 16
            let rows: [(String, String, String, String)] = [
                (T("Skeletal Muscle Mass"), rr("smiVal"), "kg", "\(rr("smiMin"))~\(rr("smiMax"))"),
                (T("Basal Metabolic Rate"), rr("bmr"), "kcal", "\(rr("bmrMin"))~\(rr("bmrMax"))"),
                ("SMI", rr("smi"), "kg/㎡", ""),
                (T("Recommended calorie intake"), rr("recEnergy"), "kcal", ""),
            ]
            for (rot, val, unit, faixa) in rows {
                txt(rot, fLeft + 0, y, pt: 6, box: 104)
                if !val.isEmpty { e.campos.append(gcell(s, comma(val), fLeft + 102, y - 2, 36, 18, pt: 8, .f)) }
                if !unit.isEmpty { txt(unit, fLeft + 140, y + 1, pt: 5.5, box: 22) }
                if faixa.contains("~") && !faixa.hasPrefix("~") { txt("(" + comma(faixa) + ")", fLeft + 170, y, pt: 6, .center, box: 68) }
                y += 15
            }
            cur = (y + 2) - fTop0
        }
        // 8) Impedância 3 freq (5/50/250 kHz).
        do {
            let y = fTop0 + cur + 4
            txt(T("Impedance"), fLeft + 0, y, pt: 10, bold: true, box: 160)
            let segs = ["BD", "BE", "TR", "PD", "PE"]
            let colX: CGFloat = fLeft + 86, colW: CGFloat = 32
            for (i, sg) in segs.enumerated() { txt(sg, colX + colW * CGFloat(i), y + 20, pt: 8, .center, box: colW) }
            txt("Z(Ω)", fLeft + 0, y + 49, pt: 7, bold: true, box: 30)
            let freqs = [("5", "IRA5", "ILA5", "IT5", "IRL5", "ILL5"),
                         ("50", "IRA50", "ILA50", "IT50", "IRL50", "ILL50"),
                         ("250", "IRA250", "ILA250", "IT250", "IRL250", "ILL250")]
            for (row, f) in freqs.enumerated() {
                let ry = y + 33 + CGFloat(row) * 16
                txt("\(f.0) kHz", fLeft + 34, ry, pt: 6.5, .trailing, box: 48)
                let keys = [f.1, f.2, f.3, f.4, f.5]
                for (i, k) in keys.enumerated() {
                    let v = rr(k)
                    if !v.isEmpty { txt(comma(v), colX + colW * CGFloat(i), ry, pt: 8, .center, box: colW) }
                }
            }
        }
    }
}
