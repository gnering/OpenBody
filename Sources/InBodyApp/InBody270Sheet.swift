import SwiftUI

// Folha do InBody 270 (ResultsSheetInBody270.DrawResultsSheetA4).
// LADO ESQUERDO IDÊNTICO À 120 (mesma composição B, músculo-gordura, obesidade, bonecos, histórico):
// reusa InBody120Sheet.buildLeft. Só a COLUNA DIREITA muda: Avaliação de Obesidade (checkbox),
// Relação Cintura-Quadril (barra), Nível de Gordura Visceral (barra), Dados adicionais,
// Perdas de calorias do exercício (tabela), QR, Impedância (2 freq).
struct InBody270Sheet {
    let s: FolhaResultado
    init(_ s: FolhaResultado) { self.s = s }

    var m: Medida { s.med }
    var p: Paciente { s.pac }
    private let L0: CGFloat = 2, T0: CGFloat = 5

    func build() -> E {
        var e = E()
        InBody120Sheet(s).buildLeft(&e)     // lado esquerdo compartilhado
        colunaDireita(&e)
        InBody120Sheet(s).rodape(&e, marcador: "[InBody270]", versao: "Ver.LookinBody120.4.0.0.7")
        return e
    }

    // MARK: - Coluna direita da 270 (DrawRightOption, conjunto próprio)
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

        // 1) Pontuação InBody (r_inbody_score) — mesmo bloco.
        do {
            let fTop = fTop0 + cur
            blk("r_inbody_score", 733, 280, at: fTop)
            let sc = rr("fs"); if !sc.isEmpty { e.campos.append(gcell(s, sc, fLeft + 32, RB(fTop) + 29, 80, 30, pt: 20, .f)) }
            cur += 280.0/3.0
        }
        // 2) Controle de Peso (r_wei_con) — mesmo bloco.
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
        func g(_ pt: CGFloat) -> CGFloat { pt * 96.0 / 72.0 }
        func txt(_ t: String, _ x: CGFloat, _ y: CGFloat, pt: CGFloat, bold: Bool = false, _ al: Alignment = .leading, box: CGFloat = 300) {
            e.campos.append(FolhaResultado.Campo(txt: t, x: x, y: y, size: g(pt), fonte: "Arial", cor: .black, alinha: al, boxW: box, bold: bold))
        }
        // barra horizontal simples com fill até 'frac' (0..1) da largura.
        // Régua (linha) que segue o título da seção até a borda direita (como o original).
        func hdrRule(_ afterX: CGFloat, _ y: CGFloat) { e.linhas.append(hline(fLeft + afterX, y + 7, fLeft + 244, IB.dark, 0.7)) }
        // Barra de escala com traços (como o original): trilha fina + ticks + segmento preto no valor.
        func barra(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, frac: CGFloat) {
            e.linhas.append(hline(x, y, x + w, IB.dark, 0.7))
            let n = 10
            for i in 0...n { let tx = x + w * CGFloat(i) / CGFloat(n); e.linhas.append(vline(tx, y - 3, y + 3, IB.dark, 0.6)) }
            e.barras.append(Barra(x: x, y: y - 3, w: max(0, min(1, frac)) * w, h: 6, cor: IB.dark))
        }

        // 3) Avaliação de Obesidade (r_obe_eval): checkbox por índice. IMC: 0=Normal 1=Abaixo 2=Lev.acima 3=Acima. PGC: 0=Normal 1=Lev.acima 2=Acima.
        do {
            let fTop = fTop0 + cur
            blk("r_obe_eval", 733, 252, at: fTop)
            let iTop = RB(fTop)
            // posições dos checkbox (estimadas do bloco; afinar por render)
            let imcBox: [(CGFloat, CGFloat)] = [(66, 28), (118, 28), (176, 22), (176, 40)]
            let pgcBox: [(CGFloat, CGFloat)] = [(66, 67), (118, 63), (188, 67)]
            if let i = Int(rr("obeImc")), i < imcBox.count {
                e.campos.append(gcell(s, "✔", fLeft + imcBox[i].0, iTop + imcBox[i].1, 12, 12, pt: 9, .c))
            }
            if let i = Int(rr("obePgc")), i < pgcBox.count {
                e.campos.append(gcell(s, "✔", fLeft + pgcBox[i].0, iTop + pgcBox[i].1, 12, 12, pt: 9, .c))
            }
            cur += 252.0/3.0
        }
        // 4) Relação Cintura-Quadril: título + valor à esq + barra à dir (marcas 0,75 0,85).
        do {
            let y = fTop0 + cur + 4
            txt(T("Waist-Hip Ratio"), fLeft + 0, y, pt: 10, bold: true, box: 200); hdrRule(168, y)
            txt(comma(rr("whr")), fLeft + 20, y + 22, pt: 12, .center, box: 70)
            txt("0,75", fLeft + 120, y + 14, pt: 7, .center, box: 30)
            txt("0,85", fLeft + 160, y + 14, pt: 7, .center, box: 30)
            let whr = Double(rr("whr")) ?? 0
            barra(fLeft + 100, y + 32, 140, frac: CGFloat((whr - 0.65) / 0.35))   // faixa ~0.65..1.0
            cur += 52
        }
        // 5) Nível de Gordura Visceral: título + "Nível N" + barra (Abaixo 10 Acima).
        do {
            let y = fTop0 + cur + 4
            txt(T("Visceral Fat Level"), fLeft + 0, y, pt: 10, bold: true, box: 220); hdrRule(182, y)
            txt(T("Level"), fLeft + 10, y + 22, pt: 8, .leading, box: 40)
            txt(rr("vfl"), fLeft + 52, y + 20, pt: 12, .leading, box: 40)
            txt(T("Below"), fLeft + 104, y + 14, pt: 6, .leading, box: 40)
            txt("10", fLeft + 160, y + 12, pt: 9, .center, box: 24)
            txt(T("Above"), fLeft + 205, y + 14, pt: 6, .leading, box: 40)
            let vfl = Double(rr("vfl")) ?? 0
            barra(fLeft + 100, y + 32, 140, frac: CGFloat(vfl / 30.0))
            cur += 52
        }
        // 6) Dados adicionais (r_rp_title + linhas): FFM, TMB, Grau Obesidade, SMI, Ingestão.
        do {
            struct RP { let art: String; let rotulo: String; let vk: String; let unit: String; let faixa: String }
            let rows: [RP] = [
                RP(art: "", rotulo: T("Fat Free Mass"), vk: "ffm", unit: "kg", faixa: "\(rr("ffmMin"))~\(rr("ffmMax"))"),
                RP(art: "r_rp_bmr",     rotulo: "", vk: "bmr", unit: "kcal",  faixa: "\(rr("bmrMin"))~\(rr("bmrMax"))"),
                RP(art: "r_rp_obe_deg", rotulo: "", vk: "obeDeg", unit: "%",  faixa: "90~110"),
                RP(art: "r_rp_smi",     rotulo: "", vk: "smi", unit: "kg/㎡",  faixa: ""),
                RP(art: "r_rp_calorie", rotulo: "", vk: "recEnergy", unit: "kcal", faixa: ""),
            ]
            var titulo = false
            for r in rows {
                let fTop = fTop0 + cur
                var add: CGFloat = 0
                if !titulo { blk("r_rp_title", 733, 56, at: fTop); add = 56.0/3.0; titulo = true }
                if r.art.isEmpty {
                    // rótulo desenhado (bloco não disponível): Arial, alinhado como os blocos.
                    e.campos.append(gcell(s, r.rotulo, fLeft + 0, RB(fTop) - 3 + CGFloat(Int(add.rounded(.toNearestOrEven))), 150, 19, pt: 7, .n))
                } else {
                    blk(r.art, 733, 56, at: fTop + add)
                }
                let nAdd = CGFloat(Int(add.rounded(.toNearestOrEven)))
                let iTop = RB(fTop)
                let val = rr(r.vk)
                if !val.isEmpty { e.campos.append(gcell(s, comma(val), fLeft + 80, iTop - 3 + nAdd, 65, 19, pt: 10, .f)) }
                if !r.unit.isEmpty { e.campos.append(gcell(s, r.unit, fLeft + 145, iTop - 3 + nAdd, 35, 19, pt: 7, .n)) }
                if !r.faixa.hasPrefix("~") && r.faixa.contains("~") {
                    e.campos.append(gcell(s, comma(r.faixa), fLeft + 174, iTop - 3 + nAdd, 70, 19, pt: 8, .c))
                }
                cur += add + 19
            }
        }
        // 7) Perdas de calorias do exercício (tabela 2 colunas).
        do {
            var y = fTop0 + cur + 6
            txt(T("Calories burned by exercise"), fLeft + 0, y, pt: 10, bold: true, box: 250); hdrRule(218, y); y += 16
            let esq = [(T("Golf"),"120"),(T("Walking"),"136"),(T("Badminton"),"154"),(T("Tennis"),"204"),(T("Boxing"),"204"),
                       (T("Climbing"),"221"),(T("Aerobics"),"238"),(T("Soccer"),"238"),(T("Kendo"),"340"),(T("Squash"),"340")]
            let dir = [(T("Gateball"),"129"),(T("Yoga"),"136"),(T("Table tennis"),"154"),(T("Cycling"),"204"),(T("Basketball"),"204"),
                       (T("Jump rope"),"238"),(T("Jogging"),"238"),(T("Swimming"),"238"),(T("Racquetball"),"340"),(T("Taekwondo"),"340")]
            for i in 0..<esq.count {
                let ry = y + CGFloat(i) * 18
                txt(esq[i].0, fLeft + 0, ry, pt: 7, box: 108)
                txt(esq[i].1, fLeft + 104, ry, pt: 8, .trailing, box: 30)
                txt(dir[i].0, fLeft + 138, ry, pt: 7, box: 100)
                txt(dir[i].1, fLeft + 214, ry, pt: 8, .trailing, box: 30)
            }
            y += CGFloat(esq.count) * 18 + 6
            txt(T("∗Based on your current weight"), fLeft + 0, y, pt: 6.5, box: 240); y += 10
            txt(T("∗Based on 30 minutes duration"), fLeft + 0, y, pt: 6.5, box: 240); y += 14
            cur = (y) - fTop0
            // 8) Código QR (grande, como o original)
            txt(T("QR Code"), fLeft + 0, y, pt: 9, bold: true, box: 120); hdrRule(80, y)
            txt("Scan the QR Code to see", fLeft + 100, y, pt: 7, box: 160)
            txt("results on the website.", fLeft + 100, y + 12, pt: 7, box: 160)
            drawQR(&e, x: fLeft + 0, y: y + 16, size: 92, payload: m.qrPayload)
            cur = (y + 116) - fTop0
        }
        // 9) Impedância (2 freq).
        do {
            let y = fTop0 + cur + 6
            txt(T("Impedance"), fLeft + 0, y, pt: 10, bold: true, box: 160); hdrRule(92, y)
            let segs = ["BD", "BE", "TR", "PD", "PE"]
            let colX: CGFloat = fLeft + 84, colW: CGFloat = 34
            for (i, sg) in segs.enumerated() { txt(sg, colX + colW * CGFloat(i), y + 20, pt: 8, .center, box: colW) }
            txt("Z(Ω)", fLeft + 0, y + 40, pt: 7, bold: true, box: 30)
            let freqs = [("20", "IRA20", "ILA20", "IT20", "IRL20", "ILL20"),
                         ("100", "IRA100", "ILA100", "IT100", "IRL100", "ILL100")]
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
