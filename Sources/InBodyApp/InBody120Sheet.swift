import SwiftUI

// Folha do InBody 120 (LookinBody: classe ResultsSheetInBody120.DrawResultsSheetA4).
// Difere do 770: composição SIMPLES (DrawBodyCompositionAnalysisB), obesidade em barras
// (DrawObesityAnalysisA, IGUAL ao 770), segmentar em DOIS BONECOS (DrawSegmentalLeanAnalysisD +
// DrawSegmentalFatAnalysisA, silhuetas que já vêm na moldura), histórico B, e SEM seção de AEC.
//
// Âncoras (ResultsSheetInBody120.DrawResultsSheetA4): o driver começa com base.Left+=2, base.Top+=5,
// então base.Left=2, base.Top=5. Coordenada final = base + offset do C#.
//   Fundo:            (Left-22, Top+103)                 = (-20, 108)  [moldura inbody_120]
//   Cabeçalho:        (Left-25, Top-25)                  = (-23, -20)  [DrawInBody, igual estrutura do 770]
//   Composição B:     (Left+338, Top+156)                = (340, 161)
//   Músculo-Gordura:  (Left+115, Top+357)                = (117, 362)  [DrawMuscleFatAnalysisA — reusa 770]
//   Obesidade:        (Left+115, Top+530)                = (117, 535)  [DrawObesityAnalysisA — reusa 770]
//   Segmentar magra:  (Left+20,  Top+657)                = (22, 662)   [boneco esquerdo]
//   Segmentar gordura:(Left+267, Top+657)                = (269, 662)  [boneco direito]
//   Histórico B:      (Left+115, Top+949)                = (117, 954)
//   Coluna direita:   (Left+517, Top+141)                = (519, 146)  [DrawRightOption]
//   Info do programa: (Left+20,  Top+1108)               = (22, 1113)
struct InBody120Sheet {
    let s: FolhaResultado
    init(_ s: FolhaResultado) { self.s = s }

    var m: Medida { s.med }
    var p: Paciente { s.pac }
    var isM: Bool { p.sexo == "M" }

    // base.Left/base.Top da 120 (A4) após o driver somar +2/+5.
    private let L0: CGFloat = 2, T0: CGFloat = 5

    func build() -> E {
        var e = E()
        buildLeft(&e)
        colunaDireita(&e)   // DrawRightOption (conjunto da 120)
        rodape(&e, marcador: "[InBody120]", versao: "Ver.LookinBody120.5.0.0.1")
        return e
    }

    // Lado esquerdo consumer (idêntico entre 120 e 270): composição simples, músculo-gordura,
    // obesidade, os dois bonecos e histórico. A 270 reusa isto e só troca a coluna direita.
    func buildLeft(_ e: inout E) {
        composicao(&e)      // DrawBodyCompositionAnalysisB (simples)
        musculoGordura(&e)  // DrawMuscleFatAnalysisA (reusa 770)
        obesidade(&e)       // DrawObesityAnalysisA (reusa 770)
        segmentarMagra(&e)  // DrawSegmentalLeanAnalysisD (boneco)
        segmentarGordura(&e)// DrawSegmentalFatAnalysisA (boneco)
        historico(&e)       // DrawBodyCompostionHistoryB
    }

    // MARK: - Composição Corporal SIMPLES (DrawBodyCompositionAnalysisB, fLeft=340 fTop=161)
    // 5 linhas (passo HeightGap=26): unidade (X=-43, far), valor (X=0 w60, far), faixa (X=50 w110, centro "( min~max )").
    // Guardas do .exe: valor só se != 0; faixa só se MIN != 0. Unidade: TBW=L (massa), demais=kg (peso).
    private func composicao(_ e: inout E) {
        let fL: CGFloat = L0 + 338, fT: CGFloat = T0 + 156
        let hg: CGFloat = 26
        // (valor, faixa, casas, unidade)
        let linhas: [(v: Double, r: Referencia, casas: Int, unid: String)] = [
            (m.tbw,      m.refTbw,      1, "L"),
            (m.proteina, m.refProteina, 1, "kg"),
            (m.mineral,  m.refMineral,  2, "kg"),
            (m.gordura,  m.refGordura,  1, "kg"),
            (m.peso,     m.refPeso,     1, "kg"),
        ]
        for (i, ln) in linhas.enumerated() {
            let y = fT + hg * CGFloat(i)
            if ln.v != 0 {
                // unidade "(L)"/"(kg)" — far (direita), Arial 7
                e.campos.append(gcell(s, "(\(ln.unid))", fL - 43, y, 40, 24, pt: 7, .f))
                // valor — far (direita), Arial 10
                e.campos.append(gcell(s, s.fmt(ln.v, ln.casas), fL + 0, y, 60, 24, pt: 10, .f))
            }
            if ln.r.lo != 0 {
                // faixa "( min~max )" — centro, Arial 8
                let faixa = "( \(s.fmt(ln.r.lo, ln.casas))~\(s.fmt(ln.r.hi, ln.casas)) )"
                e.campos.append(gcell(s, faixa, fL + 50, y, 110, 24, pt: 8, .c))
            }
        }
    }

    // MARK: - Análise Músculo-Gordura (DrawMuscleFatAnalysisA) — MESMO método do 770
    private func musculoGordura(_ e: inout E) {
        drawMuscleFatSection(&e, s, m: m, isM: isM, fL: L0 + 115, fT0: T0 + 357)
    }

    // MARK: - Análise de Obesidade (DrawObesityAnalysisA) — MESMO método do 770
    private func obesidade(_ e: inout E) {
        drawObesitySection(&e, s, m: m, isM: isM, idade: Double(p.idade), fL: L0 + 115, fT0: T0 + 530)
    }

    // Layout dos 5 quadrantes do boneco (relativo a fLeft,fTop). W=110 H=20, passo 20, centrado.
    // Ordem/índice no ETYPE3: LArm=0 RArm=1 Trunk=2 LLeg=3 RLeg=4 (magra) / +5 (gordura).
    private struct Quad { let key: String; let x: CGFloat; let y: CGFloat; let evalIdx: Int }
    private let quads: [Quad] = [
        Quad(key: "LA", x: 0,   y: 20,  evalIdx: 0),
        Quad(key: "RA", x: 114, y: 20,  evalIdx: 1),
        Quad(key: "TR", x: 55,  y: 80,  evalIdx: 2),
        Quad(key: "LL", x: 0,   y: 140, evalIdx: 3),
        Quad(key: "RL", x: 114, y: 140, evalIdx: 4),
    ]
    private let quadW: CGFloat = 110, quadGap: CGFloat = 20

    // kg do segmentar: >=10 → 1 casa (24,7); <10 → 2 casas (3,21 / 8,01).
    private func fmtSegKg(_ v: Double) -> String { s.fmt(v, v >= 10 ? 1 : 2) }
    // ETYPE3: 2→Acima, 1→Normal, 0→Abaixo (GetResourceString("UP"+digito)).
    private func avalPT(_ etype3: String, _ idx: Int) -> String {
        guard etype3.count > idx else { return "" }
        switch Array(etype3)[idx] {
        case "2": return "Acima"; case "1": return "Normal"; case "0": return "Abaixo"
        default: return ""
        }
    }

    // Desenha um boneco (5 quadrantes): kg, %, avaliação empilhados + linha fina sob kg e %.
    private func desenhaBoneco(_ e: inout E, fL: CGFloat, fT: CGFloat,
                               kg: [String: Double], pct: [String: Double], evalBase: Int) {
        for q in quads {
            let bx = fL + q.x, by = fT + q.y
            let kgv = kg[q.key] ?? 0
            let pv  = pct[q.key] ?? 0
            // linha 1: kg (centro, Arial 9)
            e.campos.append(gcell(s, fmtSegKg(kgv) + "kg", bx, by, quadW, 20, pt: 9, .c))
            // linha 2: % (centro, Arial 9)
            e.campos.append(gcell(s, s.fmt(pv, 1) + "%", bx, by + quadGap, quadW, 20, pt: 9, .c))
            // linha 3: avaliação (centro, Arial 8)
            e.campos.append(gcell(s, avalPT(m.etype3, evalBase + q.evalIdx), bx, by + quadGap*2, quadW, 20, pt: 8, .c))
            // linhas finas sob kg e % (LineX=18, LineW=73, LineY=-2 abaixo da caixa de 20)
            e.linhas.append(hline(bx + 18, by + 18, bx + 18 + 73, IB.dark, 0.5))
            e.linhas.append(hline(bx + 18, by + quadGap + 18, bx + 18 + 73, IB.dark, 0.5))
        }
    }

    // MARK: - Massa Magra Segmentar (DrawSegmentalLeanAnalysisD, fLeft=22 fTop=662) — boneco esquerdo
    private func segmentarMagra(_ e: inout E) {
        desenhaBoneco(&e, fL: L0 + 20, fT: T0 + 657, kg: m.seg, pct: m.segpIdeal, evalBase: 0)
    }

    // MARK: - Gordura Segmentar (DrawSegmentalFatAnalysisA, fLeft=269 fTop=662) — boneco direito
    private func segmentarGordura(_ e: inout E) {
        desenhaBoneco(&e, fL: L0 + 267, fT: T0 + 657, kg: m.segFat, pct: m.segFatP, evalBase: 5)
    }

    // MARK: - Histórico (DrawBodyCompostionHistoryB, fLeft=117 fTop=954) — Peso/MME/PGC (sem AEC)
    // 3 séries (a 120 não tem a 4ª linha de AEC do 770). graphH=138 (menor que os 177 do 770).
    private func historico(_ e: inout E) {
        let chron = Array(p.exames.reversed())   // exames[0] = mais recente
        drawHistorico(&e, s, fL: L0 + 21 + 94, fT: T0 + 949, graphW: 378, graphH: 138, dateH: 22,
                      datas: chron.map { $0.data },
                      series: [
                        (chron.map { $0.peso }, 1),
                        (chron.map { $0.smm }, 1),
                        (chron.map { $0.pgc }, 1),
                      ])
    }

    // MARK: - Coluna Direita (DrawRightOption, fLeft=519 fTop=146) — conjunto de opções da 120
    // Reusa a arte de bloco pt-BR do 770 (mesmos assets): score, controle de peso, dados adicionais, QR.
    // Interpretação e impedância (2 freq) desenhadas por texto. Empilhamento por altura da arte (imgH/3).
    private func colunaDireita(_ e: inout E) {
        let fLeft: CGFloat = L0 + 517, fTop0: CGFloat = T0 + 141
        var cur: CGFloat = 0
        func RB(_ v: CGFloat) -> CGFloat { CGFloat(Int(v.rounded(.toNearestOrEven))) }
        func blk(_ name: String, _ w: Int, _ h: Int, at top: CGFloat) {
            e.imgs.append(FolhaResultado.Img(nome: "inbody_right_\(name)", x: fLeft, y: top, w: CGFloat(w)/3, h: CGFloat(h)/3))
        }
        func rr(_ k: String) -> String { m.rightRaw[k] ?? "" }
        func comma(_ t: String) -> String { t.replacingOccurrences(of: ".", with: ",") }
        func sinal(_ raw: String) -> String {   // controle: "+ "/"- " conforme sinal
            let t = raw.trimmingCharacters(in: .whitespaces); if t.isEmpty { return t }
            if t.first == "-" { return "- " + t.dropFirst() }
            return (Double(t) ?? 0) != 0 ? "+ " + t : t
        }

        // 1) Pontuação InBody (r_inbody_score 733×280 -> +93,33). Número sobre a arte, Arial 20, far.
        do {
            let fTop = fTop0 + cur
            blk("r_inbody_score", 733, 280, at: fTop)
            let sc = rr("fs"); if !sc.isEmpty { e.campos.append(gcell(s, sc, fLeft + 32, RB(fTop) + 29, 80, 30, pt: 20, .f)) }
            cur += 280.0/3.0
        }
        // 2) Controle de Peso (r_wei_con 733×280 -> +93,33). 4 linhas (passo 17): PesoIdeal/Controle Peso/Gordura/Muscular.
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
        // 3) Dados adicionais (r_rp_title +18,67 uma vez; cada linha +19). Valor X=80 far(10); unidade X=145 near(7); faixa X=174 centro(8).
        do {
            struct RP { let art: String; let rotulo: String; let vk: String; let unit: String; let faixa: String }
            let rows: [RP] = [
                RP(art: "r_rp_bmr",     rotulo: "", vk: "bmr", unit: "kcal", faixa: "\(rr("bmrMin"))~\(rr("bmrMax"))"),
                RP(art: "r_rp_whr",     rotulo: "", vk: "whr", unit: "",     faixa: "\(rr("whrMin"))~\(rr("whrMax"))"),
                RP(art: "", rotulo: T("Visceral Fat Level"), vk: "vfa", unit: "", faixa: "1~9"),
                RP(art: "r_rp_obe_deg", rotulo: "", vk: "obeDeg", unit: "%", faixa: "90~110"),
            ]
            var titulo = false
            for r in rows {
                let fTop = fTop0 + cur
                var add: CGFloat = 0
                if !titulo { blk("r_rp_title", 733, 56, at: fTop); add = 56.0/3.0; titulo = true }
                if r.art.isEmpty {
                    e.campos.append(gcell(s, r.rotulo, fLeft + 0, RB(fTop) - 3 + CGFloat(Int(add.rounded(.toNearestOrEven))), 150, 19, pt: 7, .n))
                } else {
                    blk(r.art, 733, 56, at: fTop + add)
                }
                let nAdd = CGFloat(Int(add.rounded(.toNearestOrEven)))
                let iTop = RB(fTop)
                let val = rr(r.vk)
                if !val.isEmpty { e.campos.append(gcell(s, comma(val), fLeft + 80, iTop - 3 + nAdd, 65, 19, pt: 10, .f)) }
                if !r.unit.isEmpty { e.campos.append(gcell(s, r.unit, fLeft + 145, iTop - 3 + nAdd, 35, 19, pt: 7, .n)) }
                if !rr("\(r.vk)Min").isEmpty || r.faixa.hasPrefix("1~") || r.faixa.hasPrefix("90~") {
                    e.campos.append(gcell(s, comma(r.faixa), fLeft + 174, iTop - 3 + nAdd, 70, 19, pt: 8, .c))
                }
                cur += add + 19
            }
        }
        // Helpers de texto simples (Arial), negrito p/ títulos.
        func g(_ pt: CGFloat) -> CGFloat { pt * 96.0 / 72.0 }
        func txt(_ t: String, _ x: CGFloat, _ y: CGFloat, pt: CGFloat, bold: Bool = false, _ al: Alignment = .leading, box: CGFloat = 300) {
            e.campos.append(FolhaResultado.Campo(txt: t, x: x, y: y, size: g(pt), fonte: "Arial",
                                                 cor: .black, alinha: al, boxW: box, bold: bold))
        }

        // 4) Interpretação de resultados. Cabeçalho negrito + régua; blocos (subtítulo negrito + parágrafo).
        do {
            var y = fTop0 + cur + 10
            let xTit = fLeft + 0, xBody = fLeft + 0
            txt(T("Results interpretation"), xTit, y, pt: 10, bold: true, box: 260); y += 19
            let blocos: [(String, [String])] = [
                (T("Body Composition Analysis"), [
                    T("Body weight is the sum of Total Body Water,"),
                    T("protein, minerals, and body fat mass."),
                    T("Keep a balanced body composition to"),
                    T("stay healthy.")]),
                (T("Muscle-Fat Analysis"), [
                    T("Compare the bar lengths of skeletal muscle"),
                    T("mass and body fat mass. The longer the skeletal"),
                    T("muscle bar is versus the body fat"),
                    T("bar, the stronger the body is.")]),
                (T("Obesity Analysis"), [
                    T("BMI is an index used to determine"),
                    T("obesity, using height and weight."),
                    T("PBF is the percent of body fat relative"),
                    T("to body weight.")]),
                (T("Segmental Lean Analysis"), [
                    T("Assess whether muscle is distributed"),
                    T("properly across all body parts."),
                    T("Compares muscle mass to the ideal weight.")]),
                (T("Segmental Fat Analysis"), [
                    T("Assess whether fat is distributed"),
                    T("properly across all body parts."),
                    T("Compares fat mass to the ideal weight.")]),
            ]
            for (sub, linhas) in blocos {
                txt(sub, xTit, y, pt: 9, bold: true, box: 260); y += 20
                for ln in linhas { txt(ln, xBody, y, pt: 7, box: 280); y += 15 }
                y += 13
            }
            // Código QR da Interpretação de Resultados + QR (grande, como o original).
            y += 6
            txt(T("Results Interpretation QR Code"), xTit, y, pt: 8, bold: true, box: 260); y += 16
            txt(T("Scan the QR code to"), xBody, y, pt: 7, box: 160)
            txt(T("see the interpretation of the"), xBody, y + 12, pt: 7, box: 160)
            txt(T("results in more detail."), xBody, y + 24, pt: 7, box: 160)
            drawQR(&e, x: fLeft + 150, y: y - 2, size: 100, payload: m.qrPayload)
            cur = (y + 96) - fTop0
        }
        // 6) Impedância (2 freq: 20 e 100 kHz). Cabeçalho negrito + grade Z(Ω) 5 seg × 2 freq.
        do {
            let y = fTop0 + cur + 6
            txt(T("Impedance"), fLeft + 0, y, pt: 10, bold: true, box: 160)
            // rótulos de coluna (BD BE TR PD PE) e Z(Ω)
            let segs = ["BD", "BE", "TR", "PD", "PE"]
            let colX: CGFloat = fLeft + 84, colW: CGFloat = 34
            for (i, sg) in segs.enumerated() { txt(sg, colX + colW * CGFloat(i), y + 20, pt: 8, .center, box: colW) }
            // Z(Ω) à esquerda, centrado verticalmente entre as duas linhas de frequência.
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

    // MARK: - Rodapé: versão/serial (inf-esq) + marcador do modelo no topo.
    func rodape(_ e: inout E, marcador: String, versao: String) {
        e.campos.append(gpt(s, versao, L0 + 20, T0 + 1113, pt: 6, .black, box: 420, italic: true))
        e.campos.append(gcell(s, marcador, 195, 48, 300, 20, pt: 10, .f, .black))
    }
}
