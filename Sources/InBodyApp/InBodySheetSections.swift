import SwiftUI

// Módulos de seção da folha. Cada um porta um trecho de ClsDrawLeftOutput / ClsDrawRightOutput
// para o espaço lógico (826,67 × 1169,33) sobre o fundo real do InBody.
//
// Âncoras de topo (ResultsSheetInBody770.DrawResultsSheetA4, base.Left=1 base.Top=5):
//   Composição:        (Left+340, Top+161)            = (341, 166)
//   Músculo-Gordura:   (Left+117, Top+212+135)        = (118, 352)
//   Obesidade:         (Left+117, Top+200+194+100)    = (118, 499)
//   Segmentar:         (Left+117, Top+200+194+78+138) = (118, 615)
//   Taxa AEC:          (Left+117, Top+200+194+78+120+256) = (118, 853)
//   Histórico:         (Left+21+96, Top+156+200+194+148+221) = (118, 924)
//   Coluna direita:    (Left+516, Top+146)            = (517, 151)

typealias E = FolhaResultado.Elementos

struct InBodyAdultSheet {
    let s: FolhaResultado
    init(_ s: FolhaResultado) { self.s = s }

    var m: Medida { s.med }
    var p: Paciente { s.pac }
    var isM: Bool { p.sexo == "M" }

    func build() -> E {
        var e = E()
        composicao(&e)          // DrawBodyCompositionAnalysisA
        musculoGordura(&e)      // DrawMuscleFatAnalysisA
        obesidade(&e)           // DrawObesityAnalysisA
        segmentar(&e)           // DrawSegmentalLeanAnalysisA
        taxaAEC(&e)             // DrawECWRatioAnalysisA
        historico(&e)           // DrawBodyCompostionHistoryD
        colunaDireita(&e)       // ClsDrawRightOutput.DrawRightOption
        rodapeComum(&e, s)
        return e
    }

    // MARK: - Composição Corporal (DrawBodyCompositionAnalysisA, fLeft=341 fTop=166)
    private func composicao(_ e: inout E) {
        let fL: CGFloat = 341, fT: CGFloat = 166
        let ux: CGFloat = -253, uy: CGFloat = -4, uw: CGFloat = 28, uh: CGFloat = 26
        let vx: CGFloat = -224, vy: CGFloat = -4, vw: CGFloat = 74, vh: CGFloat = 16
        let rx: CGFloat = -230, ry: CGFloat = 15, rw: CGFloat = 85, rh: CGFloat = 11
        let hg: CGFloat = 35, wg: CGFloat = 75
        let hgi = CGFloat(Int(hg) / 2)   // HeightGap/2 inteiro (=17), como o C#

        func rng(_ r: Referencia) -> String { "(\(s.fmt(r.lo,1))~\(s.fmt(r.hi,1)))" }
        func rng2(_ r: Referencia) -> String { "(\(s.fmt(r.lo,2))~\(s.fmt(r.hi,2)))" }

        // Coluna "Valores": TBW, Proteína, Minerais, Gordura.
        // Guard do .exe (DrawBodyCompositionAnalysisA): valor+unidade só se valor != 0;
        // faixa só se MIN != 0. Campo zerado/ausente = célula EM BRANCO (o aparelho omite, não imprime "0,00").
        if m.tbw != 0 {
            e.campos.append(gcell(s, s.fmt(m.tbw,1),  fL+vx, fT+vy+hg*0, vw, vh, pt: 10, .c))
            e.campos.append(gcell(s, "(L)",           fL+ux, fT+uy+hg*0, uw, uh, pt: 7,  .f))
        }
        if m.refTbw.lo != 0 {
            e.campos.append(gcell(s, rng(m.refTbw),   fL+rx, fT+ry+hg*0, rw, rh, pt: 8,  .c))
        }

        if m.proteina != 0 {
            e.campos.append(gcell(s, s.fmt(m.proteina,1), fL+vx, fT+vy+hg*1, vw, vh, pt: 10, .c))
            e.campos.append(gcell(s, "(kg)",              fL+ux, fT+uy+hg*1, uw, uh, pt: 7,  .f))
        }
        if m.refProteina.lo != 0 {
            e.campos.append(gcell(s, rng(m.refProteina), fL+rx, fT+ry+hg*1, rw, rh, pt: 8, .c))
        }

        if m.mineral != 0 {
            e.campos.append(gcell(s, s.fmt(m.mineral,2),  fL+vx, fT+vy+hg*2, vw, vh, pt: 10, .c))
            e.campos.append(gcell(s, "(kg)",              fL+ux, fT+uy+hg*2, uw, uh, pt: 7,  .f))
        }
        if m.refMineral.lo != 0 {
            e.campos.append(gcell(s, rng2(m.refMineral), fL+rx, fT+ry+hg*2, rw, rh, pt: 8, .c))
        }

        if m.gordura != 0 {
            e.campos.append(gcell(s, s.fmt(m.gordura,1),  fL+vx, fT+vy+hg*3, vw, vh, pt: 10, .c))
            e.campos.append(gcell(s, "(kg)",              fL+ux, fT+uy+hg*3, uw, uh, pt: 7,  .f))
        }
        if m.refGordura.lo != 0 {
            e.campos.append(gcell(s, rng(m.refGordura),   fL+rx, fT+ry+hg*3, rw, rh, pt: 8,  .c))
        }

        // Escada: Água Corporal Total, Massa Magra, Massa Livre de Gordura, Peso (mesmo guard valor != 0 / MIN != 0)
        if m.tbw != 0 {
            e.campos.append(gcell(s, s.fmt(m.tbw,1), fL+vx+wg*1, fT+vy,       vw, vh+rh, pt: 10, .c)) // TBW
        }
        if m.slm != 0 {
            e.campos.append(gcell(s, s.fmt(m.slm,1), fL+vx+wg*2, fT+vy+hgi,   vw, vh,    pt: 10, .c)) // SLM
        }
        if m.refSlm.lo != 0 {
            e.campos.append(gcell(s, rng(m.refSlm), fL+rx+wg*2, fT+ry+hgi*1, rw, rh, pt: 8, .c)) // SLM range
        }
        if m.ffm != 0 {
            e.campos.append(gcell(s, s.fmt(m.ffm,1), fL+vx+wg*3, fT+vy+hgi*2, vw, vh,    pt: 10, .c)) // FFM
        }
        if m.refFfm.lo != 0 {
            e.campos.append(gcell(s, rng(m.refFfm),  fL+rx+wg*3, fT+ry+hgi*2, rw, rh,    pt: 8,  .c)) // FFM range
        }
        if m.peso != 0 {
            e.campos.append(gcell(s, s.fmt(m.peso,1),fL+vx+wg*4, fT+vy+hgi*3, vw, vh,    pt: 10, .c)) // Peso
        }
        if m.refPeso.lo != 0 {
            e.campos.append(gcell(s, rng(m.refPeso), fL+rx+wg*4, fT+ry+hgi*3, rw, rh, pt: 8, .c)) // Peso range
        }
    }

    // MARK: - Análise Músculo-Gordura (DrawMuscleFatAnalysisA, fLeft=118 fTop=352)
    private func musculoGordura(_ e: inout E) {
        drawMuscleFatSection(&e, s, m: m, isM: isM, fL: 118, fT0: 352)
    }

    // MARK: - Análise de Obesidade (DrawObesityAnalysisA, fLeft=118 fTop=499)
    private func obesidade(_ e: inout E) {
        drawObesitySection(&e, s, m: m, isM: isM, idade: Double(p.idade), fL: 118, fT0: 499)
    }

    // MARK: - Massa Magra Segmentar (DrawSegmentalLeanAnalysisA, fLeft=118 fTop=615)
    private func segmentar(_ e: inout E) {
        let fL: CGFloat = 118, fT0: CGFloat = 615
        let firstW: CGFloat = 19, sw: CGFloat = 32.5, gh: CGFloat = 30
        let barW: CGFloat = 4, barLen: CGFloat = 310, barGap: CGFloat = 11
        let ticks = (0...8).map { firstW + sw * CGFloat($0) }
        let wedX: CGFloat = 292, wedY: CGFloat = 10, wedW: CGFloat = 100, wedH: CGFloat = 25
        let lineX: CGFloat = 22, lineY: CGFloat = 4, lineW: CGFloat = 62

        // Braço/tronco/perna: TODAS por sexo (ClsScale.GetSegmentalLeanArm/Trunk/LegScale(gender),
        // chamadas em ClsDrawLeftOutput.DrawSegmentalLeanAnalysisA:2389). Mulher = braço 40..240.
        let armScale = isM ? Escala.segMaleArm : Escala.segFemaleArm
        let trunkScale = isM ? Escala.segMaleTrunk : Escala.segFemaleTrunk
        let legScale = isM ? Escala.segMaleLeg : Escala.segFemaleLeg
        func interval(_ sc: [Double]) -> Double { abs(sc[0] - sc[1]) }

        // ordem das linhas: BD, BE, Tronco, PD, PE
        let segs: [(key: String, scale: [Double])] = [
            ("RA", armScale), ("LA", armScale), ("TR", trunkScale), ("RL", legScale), ("LL", legScale),
        ]
        for (i, seg) in segs.enumerated() {
            let fT = fT0 + (gh + 7) * CGFloat(i)
            let kg = m.seg[seg.key] ?? 0
            let pS = m.segp[seg.key] ?? 100                       // PL  (barra kg, cf. ClsDrawLeftOutput:2231)
            let pP = m.segpIdeal[seg.key] ?? pS                   // PIL (barra %)
            let iv = interval(seg.scale)

            // eixo + ticks + escala (BarLength real do oráculo, 310 -- a suposição antiga de
            // encurtar pra 282 "pra não invadir a coluna AEC" estava errada: achado pelo
            // instrumento de forma, o golden desenha a linha até 428 mesmo assim).
            drawGrade(&e, s, fL: fL, fT: fT, barLen: barLen, gh: gh, ticks: ticks,
                  labels: (0...8).map { fmtSc(seg.scale[$0]) }, borderOffset: 6)

            // Rótulos por segmento (ClsDrawLeftOutput.DrawSegmentalLeanAnalysisA:2502/2506/2515):
            // "%" no fim da barra + unidades "(kg)"/"(%)" à esquerda. Posições/fontes do golden.
            e.campos.append(gpt(s, "%", fL + barLen - 10, fT + 5, pt: 6))
            e.campos.append(gcell(s, "(kg)", fL - 27, fT + 12, 27, 15, pt: 7, .c))
            e.campos.append(gcell(s, "(%)",  fL - 27, fT + 23, 27, 15, pt: 7, .c))

            // barra kg (S): posicionada por PL (segp), base preta + zona normal cinza137, mostra kg
            let numS = getBarWidth(seg.scale[0], iv, pS, percent: true, sw, Int(barLen) - 50)
            let posS = firstW + CGFloat(numS) + 2
            let yS = fT + (gh - barW) / 2 + 8 - barW - 0.5
            fillBar(&e, xLeft: fL, valuePos: posS, yTop: yS, thick: barW + 1,
                    midStart: ticks[2], midLen: sw * 2, baseCor: IB.dark, midCor: IB.gray137, ticks: ticks)
            // fonte do valor = FontRange (Arial 8), como o driver 770 (fontValue=base.FontRange).
            e.campos.append(barValor(s, s.fmt(kg, 2), xLeft: fL, num: CGFloat(numS), yTop: fT, dy: 14, pt: 8))

            // barra % (P): posicionada por PIL (segpIdeal), base cinza87 + zona normal cinza160, mostra %
            var numP = getBarWidth(seg.scale[0], iv, pP, percent: true, sw, Int(barLen) - 50)
            // Estouro da barra de % (ClsDrawLeftOutput.DrawSegmentalLeanAnalysisA:2560):
            // trava em BarLength-50, apaga retângulo branco e anota o % (fontGraph 6).
            if numP >= Double(Int(barLen) - 50) {
                numP = Double(Int(barLen) - 50)
                e.barras.append(Barra(x: fL + barLen - 45, y: fT + 6, w: 30, h: 9, cor: .white))
                e.campos.append(gpt(s, "(\(s.fmt(pP, 1)))", fL + barLen - 41, fT + 6, pt: 6))
            }
            let posP = firstW + CGFloat(numP) + 2
            let yP = fT + (gh - barW) / 2 + 9 + barGap - barW - 0.5
            fillBar(&e, xLeft: fL, valuePos: posP, yTop: yP, thick: barW + 1,
                    midStart: ticks[2], midLen: sw * 2, baseCor: IB.gray87, midCor: IB.gray160, ticks: ticks)
            e.campos.append(barValor(s, s.fmt(pP, 1), xLeft: fL, num: CGFloat(numP), yTop: fT, dy: 15 + barGap, pt: 8))

            // coluna Taxa de AEC (WED): valor por segmento (ED_TBL.WED*); corpo inteiro como reserva.
            let aecSeg = m.segAEC[seg.key] ?? (m.wed > 0 ? m.wed : m.ecwTbw)
            e.campos.append(gcell(s, s.fmt(aecSeg, 3), fL + wedX, fT + wedY, wedW, wedH, pt: 10, .c))
            // Sublinhado só entre linhas (LineUse=N na última, Perna Esquerda -- achado pelo
            // instrumento de forma: o golden não desenha essa linha depois do último segmento).
            if i < segs.count - 1 {
                e.linhas.append(hline(fL + wedX + lineX, fT + wedY + wedH + lineY, fL + wedX + lineX + lineW))
            }
        }
    }

    // MARK: - Análise da Taxa de AEC (DrawECWRatioAnalysisA, fLeft=118 fTop=853)
    private func taxaAEC(_ e: inout E) {
        let fL: CGFloat = 118, fT: CGFloat = 853
        let firstW: CGFloat = 19, sw: CGFloat = 32.5, gh: CGFloat = 30
        let barW: CGFloat = 7, barLen: CGFloat = 370
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
        // Estouro (ClsDrawLeftOutput.DrawECWRatioAnalysisA:8313): quando a barra satura (>= BarLength-50)
        // o original trava em BarLength-52 (constante PRÓPRIA, não -50), apaga retângulo branco e
        // anota o edema entre parênteses (fontGraph 6). Sem isso a barra sai da folha em paciente edemaciado.
        if bw >= Double(Int(barLen) - 50) {
            bw = Double(Int(barLen) - 52)
            e.barras.append(Barra(x: fL + barLen - 45, y: fT + 6, w: 30, h: 9, cor: .white))
            e.campos.append(gpt(s, "(\(s.fmt(edema, 3)))", fL + barLen - 41, fT + 6, pt: 6))
        }
        let valuePos = firstW + CGFloat(bw) + 2
        let yTop = fT + (gh - barW) / 2 + 18 - barW - 0.5
        fillBar(&e, xLeft: fL, valuePos: valuePos, yTop: yTop, thick: barW + 1,
                midStart: ticks[2], midLen: sw * 2, baseCor: IB.dark, midCor: IB.gray137, ticks: ticks)
        e.campos.append(gbar(s, s.fmt(edema, 3), x: fL + 25 + CGFloat(bw), barTop: yTop, thick: barW + 1, pt: 10))
    }

    // MARK: - Histórico da Composição Corporal (DrawBodyCompostionHistoryD, fLeft=118 fTop=924)
    // Aproximação do ClsLineGraph: 4 faixas (Peso/MME/PGC/AEC), escala própria por série.
    private func historico(_ e: inout E) {
        let chron = Array(p.exames.reversed())   // exames[0] é o mais recente
        drawHistorico(&e, s, fL: 118, fT: 924, graphW: 378, graphH: 177, dateH: 22,
                      datas: chron.map { $0.data },
                      series: [
                        (chron.map { $0.peso }, 1),
                        (chron.map { $0.smm }, 1),
                        (chron.map { $0.pgc }, 1),
                        (chron.map { $0.ecwTbw }, 3),
                      ])
    }

    // MARK: - Coluna Direita (ClsDrawRightOutput.DrawRightOption, fLeft=517 fTop=151)
    // Fundo direito é 100% desenhado por código (imagens de bloco embutidas no .exe, indisponíveis).
    // Recriação estrutural com os valores reais do modelo; campos ausentes ver relatório.
    // Porte FIEL de ClsDrawRightOutput.DrawRightOption (fLeft=517, fTop=151) para o
    // conjunto padrão BR-adulto 770: r_inbody_score; r_vfa_graph; r_wei_con|1;
    // r_body_bal_eval|1; r_rp_icw/ecw/bmr/whr/bcm/smi/calorie (Dados Adicionais); r_wb_pa.
    // Empilhamento vertical por altura da arte de bloco (imgH/3), igual ao .exe. As artes
    // são assets PNG extraídos do resx (inbody_right_*). Convert.ToInt16/ToInt32 = arredonda
    // (metade-par); replicado por RB(). Falta portar: r_seg_fat_anal_high e r_impedance.
    private func colunaDireita(_ e: inout E) {
        let fLeft: CGFloat = 517, fTop0: CGFloat = 151
        var fSzie: CGFloat = 0
        // Convert.ToInt16/ToInt32(double) = arredondamento para o par mais próximo.
        func RB(_ v: CGFloat) -> CGFloat { CGFloat(Int(v.rounded(.toNearestOrEven))) }
        // rightRaw = override do oráculo (entrada de teste). Vazio => cai no campo tipado do Medida,
        // que é o que a demo e o import do .mdb preenchem (senão a coluna direita sairia vazia p/ paciente real).
        func vv(_ k: String, _ fb: String = "") -> String {
            let s0 = m.rightRaw[k] ?? ""
            if !s0.isEmpty { return s0 }
            let t = tf(k)
            return t.isEmpty ? fb : t
        }
        func tf(_ k: String) -> String {
            func f1(_ v: Double) -> String { v != 0 ? String(format: "%.1f", v) : "" }
            func f2(_ v: Double) -> String { v != 0 ? String(format: "%.2f", v) : "" }
            func iv(_ v: Double) -> String { v != 0 ? String(Int(v.rounded())) : "" }
            switch k {
            case "fs":  return m.inbodyScore > 0 ? String(Int(m.inbodyScore.rounded())) : ""
            case "vfa": return f1(m.gv)
            case "wed": return m.ecwTbw > 0 ? String(format: "%.3f", m.ecwTbw) : ""
            case "age": return "\(p.idade)"
            case "etype2": return m.etype2
            case "tw":  return f1(m.pesoIdeal)
            case "wc":  return m.pesoIdeal > 0 ? String(format: "%.1f", m.controlePeso) : ""
            case "fc":  return m.pesoIdeal > 0 ? String(format: "%.1f", m.controleGordura) : ""
            case "mc":  return m.pesoIdeal > 0 ? String(format: "%.1f", m.controleMuscular) : ""
            case "icw": return f1(m.icw)
            case "ecw": return f1(m.ecw)
            case "bmr": return iv(m.tmb)
            case "whr": return f2(m.rcq)
            case "bcm": return f1(m.bcm)
            case "bsmi":
                // SMI: se o exame veio com 0 (a balança manda o quadro cru), calcula na hora
                // = massa magra apendicular (4 membros) / altura². Vale p/ exames já salvos.
                let asm = (m.seg["RA"] ?? 0) + (m.seg["LA"] ?? 0) + (m.seg["RL"] ?? 0) + (m.seg["LL"] ?? 0)
                let smiEff = m.smi > 0 ? m.smi
                    : (m.altura > 0 && asm > 0 ? asm / ((m.altura / 100) * (m.altura / 100)) : 0)
                return f1(smiEff)
            case "recEnergy": return iv(m.ingestaoCalorica)
            case "wbpa50": return f1(m.anguloFase)
            case "icwMin": return f1(m.refIcw.lo); case "icwMax": return f1(m.refIcw.hi)
            case "ecwMin": return f1(m.refEcw.lo); case "ecwMax": return f1(m.refEcw.hi)
            case "bmrMin": return iv(m.refBmr.lo);  case "bmrMax": return iv(m.refBmr.hi)
            case "whrMin": return f2(m.refRcq.lo);  case "whrMax": return f2(m.refRcq.hi)
            case "bcmMin": return f1(m.refBcm.lo);  case "bcmMax": return f1(m.refBcm.hi)
            default: break
            }
            if k.hasPrefix("pfat") { return f1(m.segFatP[String(k.dropFirst(4))] ?? 0) }
            if k.hasPrefix("fat")  { return f1(m.segFat[String(k.dropFirst(3))] ?? 0) }
            if k.hasPrefix("I") {
                let body = String(k.dropFirst())   // {seg}{freq}: T->TR, 1M->1000
                for (fk, fv) in [("1M", 1000), ("500", 500), ("250", 250), ("50", 50), ("5", 5), ("1", 1)]
                where body.hasSuffix(fk) {
                    var sg = String(body.dropLast(fk.count)); if sg == "T" { sg = "TR" }
                    guard let z = m.impedancia[sg]?[fv] else { return "" }
                    return z == z.rounded() ? String(Int(z)) : String(format: "%.1f", z)
                }
            }
            return ""
        }
        func comma(_ t: String) -> String { t.replacingOccurrences(of: ".", with: ",") }
        func blockImg(_ name: String, _ w: Int, _ h: Int, at top: CGFloat) {
            e.imgs.append(FolhaResultado.Img(nome: "inbody_right_\(name)", x: fLeft, y: top, w: CGFloat(w)/3, h: CGFloat(h)/3))
        }

        // 1) r_inbody_score (imgH 280 -> +93,33). Valor sobre a arte, sfFF (far), Arial 20.
        do {
            let fTop = fTop0 + fSzie
            let edema = Double(vv("wed", "0")) ?? 0
            if edema < 0.4 {
                blockImg("r_inbody_score", 733, 280, at: fTop)
                var sc = Int(vv("fs", "1")) ?? 1; if sc < 1 { sc = 1 }
                e.campos.append(gcell(s, "\(sc)", fLeft + 32, RB(fTop) + 29, 80, 30, pt: 20, .f))
            } else {
                // Retenção elevada: o .exe troca a arte pelo aviso (r_inbody_score_edema), sem número.
                blockImg("r_inbody_score_edema", 733, 280, at: fTop)
            }
            fSzie += 280.0/3.0
        }
        // 2) r_vfa_graph (imgH 588 -> +196). Ponto (elipse+cruz) + rótulo VFA (float, Arial 10).
        do {
            let fTop = fTop0 + fSzie
            blockImg("r_vfa_graph", 733, 588, at: fTop)
            let vfaS = vv("vfa"); let ageS = vv("age", "\(p.idade)")
            if let vfa = Double(vfaS), vfa > 0, let ageD = Double(ageS) {
                var age = ageD; if age < 0 { age = 0 } else if age > 90 && age < 101 { age = 90 } else if age > 100 { age = 80 }
                let num2 = CGFloat(age) * 1.89
                let num4 = CGFloat(min(vfa, 200)) / 1.53
                let cx = fLeft + num2 + 39, cy = fTop - num4 + 179
                e.pontos.append(Ponto(x: cx, y: cy, r: 4, cor: .black))                       // FillEllipse 8
                e.linhas.append(hline(cx - 10, cy, cx + 10, .black, 2))                        // cruz
                e.linhas.append(vline(cx, cy - 10, cy + 10, .black, 2))
                e.campos.append(gpt(s, comma(vfaS), fLeft + num2 + 47, fTop - num4 + 159, pt: 10))
            }
            fSzie += 588.0/3.0
        }
        // 3) r_wei_con|1 -> r_wei_con_a4 (imgH 280 -> +93,33). 4 linhas (ValueGap=17):
        //    Peso Ideal (sem sinal) / Controle Peso / Gordura / Massa Magra (sinal "+ "/"- ").
        do {
            let fTop = fTop0 + fSzie
            blockImg("r_wei_con", 733, 280, at: fTop)
            let iTop = RB(fTop)
            func weiSign(_ raw: String) -> String {
                if raw.isEmpty { return raw }
                let t = raw.trimmingCharacters(in: .whitespaces)
                if t.first == "-" { return "- " + t.replacingOccurrences(of: "-", with: "") }
                if (Double(t) ?? 0) != 0 { return "+ " + raw }
                return raw
            }
            let vals = [vv("tw"), weiSign(vv("wc")), weiSign(vv("fc")), weiSign(vv("mc"))]
            for row in 0..<4 {
                let uy = iTop + 22 + 17 * CGFloat(row)
                e.campos.append(gcell(s, "kg", fLeft + 146, uy, 40, 20, pt: 7, .n))              // unit sfNF
                if !vals[row].isEmpty {
                    e.campos.append(gcell(s, comma(vals[row]), fLeft + 53, uy, 90, 20, pt: 9, .f)) // value sfFF, FontWeightControl 9
                }
            }
            fSzie += 280.0/3.0
        }
        // 4) r_body_bal_eval|1 (imgH 252 -> +84). Check (12×12) por etype2[9][10][11]; col=widthGap.
        do {
            let fTop = fTop0 + fSzie
            blockImg("r_body_bal_eval", 733, 252, at: fTop)
            let et = vv("etype2", m.etype2)
            if et.count >= 12 {
                let a = Array(et)
                let widthGap: CGFloat = 52, widthOver: CGFloat = 64, heightGap: CGFloat = 21
                for (row, idx) in [9, 10, 11].enumerated() {
                    let d = Int(String(a[idx])) ?? 0
                    let addW: CGFloat = d == 0 ? 0 : widthGap
                    let addWover: CGFloat = d == 2 ? widthOver : 0
                    let cx = fLeft + 67 + addW + addWover
                    let cy = fTop + 21 + heightGap * CGFloat(row)
                    e.imgs.append(FolhaResultado.Img(nome: "inbody_right_Check", x: cx, y: cy, w: 12, h: 12))
                }
            }
            fSzie += 252.0/3.0
        }
        // 5) r_seg_fat_anal_high (imgH 392 -> +130,67). 5 barras BFM não-lineares por segmento;
        //    "%" (float, Arial 7) X = XBase + num3(GetBarWidth3) + 2 + num2; "(kg)" (RectangleF far, Arial 9).
        do {
            let fTop = fTop0 + fSzie
            blockImg("r_seg_fat_anal_high", 733, 392, at: fTop)
            let xBase = fLeft + 0 + 127                 // fLeft + xBase(0) + GraphX(127)
            var ftRow = fTop + 35                        // fTop += GraphY(35)
            let bfmBase = 40.0, bfmInterval = 20.0, sw = 14.0, barLen = 110
            // ordem i=0..4: RA, LA, TR, RL, LL. RA usa limiar "<=120" (as demais "<120").
            let segs: [(kg: String, p: String, ra: Bool)] = [
                (vv("fatRA"), vv("pfatRA"), true),  (vv("fatLA"), vv("pfatLA"), false),
                (vv("fatTR"), vv("pfatTR"), false), (vv("fatRL"), vv("pfatRL"), false),
                (vv("fatLL"), vv("pfatLL"), false),
            ]
            for seg in segs {
                if !seg.kg.isEmpty, !seg.p.isEmpty, let pv = Double(seg.p) {
                    var num3 = getBarWidth3(bfmBase, bfmInterval, pv, percent: false, sw, barLen)
                    if num3 >= Double(barLen) - 10 { num3 = Double(barLen) - 10 } else if num3 < 0 { num3 = 0 }
                    let num2: CGFloat = seg.ra ? (pv <= 120 ? 2 : 0) : (pv < 120 ? 2 : 0)
                    // Trilha preta fixa por baixo (colorBarBase=Black, colorBarMiddle=Black), achada
                    // pelo instrumento de forma -- faltava por completo (só a barra branca de valor
                    // existia). r_seg_fat_anal_high: DrawBar(xBase, thick4, BarLength=110) +
                    // DrawBar(xBase+array[2]=28, thick4, ScaleWidth*2=28). Y calibrado no golden real
                    // (não bate com a fórmula (GraphHeight-BarWidth)/2+7 lida no decompilado -- fica
                    // registrado como incerteza; y=ftRow+7 é o que os 1.742 exames confirmam).
                    // A barra branca de valor apaga o rabo da trilha preta a partir de onde ela
                    // começa (mesmo xBase+num3+num2) -- por isso a trilha visível pára ali, não em 110.
                    let baseW = min(CGFloat(barLen), CGFloat(num3) + num2)
                    e.barras.append(Barra(x: xBase, y: ftRow + 7, w: baseW, h: 4, cor: .black))
                    e.barras.append(Barra(x: xBase + 28, y: ftRow + 7, w: 28, h: 4, cor: .black))
                    // Barra de valor = BRANCO por cima da barra tracejada da imgBG (colorBarDraw=White).
                    // Apaga o rabo, deixa preto só até num3; o número vem logo depois. Original
                    // r_seg_fat_anal_high linha 3129 (DrawBar type 1): x=XBase+num3+num2,
                    // y=ftRow+(GraphHeight-BarWidth)/2+8-BarHeight-1=ftRow+6, w=BarLength+num3, h=BarWidth+2=7.
                    e.barras.append(Barra(x: xBase + CGFloat(num3) + num2, y: ftRow + 6,
                                          w: CGFloat(barLen) + CGFloat(num3), h: 7, cor: .white))
                    e.campos.append(gpt(s, comma(seg.p) + "%", xBase + CGFloat(num3) + 2 + num2, ftRow + 4, pt: 7))
                    e.campos.append(gcell(s, "(" + comma(seg.kg) + " kg)", RB(xBase) - 72, RB(ftRow) - 2, 70, 20, pt: 9, .f))
                }
                ftRow += 11 + 7
            }
            fSzie += 392.0/3.0
        }
        // 6) Dados Adicionais — caixa de parâmetros de pesquisa (r_rp_*). Título (r_rp_title, +18,67)
        //    uma vez; cada linha soma fBackSize=19. Value X=80 sfFF(10); Unit X=145 sfNF(7); Range X=174 sfCF(8).
        do {
            struct RP { let name: String; let vk: String; let unit: String; let rangeKeys: (String,String)? }
            let rows: [RP] = [
                RP(name: "r_rp_icw", vk: "icw", unit: "L",     rangeKeys: ("icwMin","icwMax")),
                RP(name: "r_rp_ecw", vk: "ecw", unit: "L",     rangeKeys: ("ecwMin","ecwMax")),
                RP(name: "r_rp_bmr", vk: "bmr", unit: "kcal",  rangeKeys: ("bmrMin","bmrMax")),
                RP(name: "r_rp_whr", vk: "whr", unit: "",      rangeKeys: ("whrMin","whrMax")),
                RP(name: "r_rp_bcm", vk: "bcm", unit: "kg",    rangeKeys: ("bcmMin","bcmMax")),
                RP(name: "r_rp_smi", vk: "bsmi", unit: "kg/㎡", rangeKeys: nil),
                RP(name: "r_rp_calorie", vk: "recEnergy", unit: "kcal", rangeKeys: nil),
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
                let nAdd = CGFloat(Int(add.rounded(.toNearestOrEven)))   // Convert.ToInt32(fTitleSize)
                let iTop = RB(fTop)
                let backH: CGFloat = 19
                // value (X=80, Y=-3, W=65) sfFF Arial 10
                let val = vv(r.vk)
                if !val.isEmpty {
                    e.campos.append(gcell(s, comma(val), fLeft + 80, iTop - 3 + nAdd, 65, backH, pt: 10, .f))
                }
                // unit (X=145, Y=-3, W=35) sfNF Arial 7
                if !r.unit.isEmpty {
                    e.campos.append(gcell(s, r.unit, fLeft + 145, iTop - 3 + nAdd, 35, backH, pt: 7, .n))
                }
                // range (X=174, Y=-3, W=70) sfCF Arial 8 — "min~max"
                if let rk = r.rangeKeys {
                    let lo = vv(rk.0), hi = vv(rk.1)
                    if !lo.isEmpty {
                        e.campos.append(gcell(s, comma("\(lo)~\(hi)"), fLeft + 174, iTop - 3 + nAdd, 70, backH, pt: 8, .c))
                    }
                }
                fSzie += add + backH
            }
        }
        // 7) r_wb_pa (imgH 140 -> +46,67). Ângulo de fase 50kHz: unit (X=138,Y=22) sfCF(7);
        //    value (X=50,Y=25) sfFF(10). Sem faixa (bRangeUse=false).
        do {
            let fTop = fTop0 + fSzie
            blockImg("r_wb_pa", 733, 140, at: fTop)
            let iTop = RB(fTop)
            e.campos.append(gcell(s, "˚", fLeft + 138, iTop + 22, 30, 20, pt: 7, .c))              // Unit_Degree
            let wb = vv("wbpa50")
            if !wb.isEmpty { e.campos.append(gcell(s, comma(wb), fLeft + 50, iTop + 25, 100, 20, pt: 10, .f)) }
            fSzie += 140.0/3.0
        }
        // 8) r_impedance -> r_impedance_770 (imgH 364 -> +121,33). Grade Z(Ω) 6 freq × 5 seg,
        //    DrawDataTableMatrix: célula (ValueX=62,ValueY=33,W=35,H=15,WidthGap=35,HeightGap=14) sfCF Arial 8.
        do {
            let fTop = fTop0 + fSzie
            blockImg("r_impedance_770", 733, 364, at: fTop)
            let iTop = RB(fTop)
            let freqs = ["1", "5", "50", "250", "500", "1M"]
            let segs = ["RA", "LA", "T", "RL", "LL"]
            for (row, f) in freqs.enumerated() {
                for (col, sg) in segs.enumerated() {
                    let z = vv("I\(sg)\(f)")
                    if !z.isEmpty {
                        e.campos.append(gcell(s, comma(z), fLeft + 62 + 35 * CGFloat(col),
                                              iTop + 33 + 14 * CGFloat(row), 35, 15, pt: 8, .c))
                    }
                }
            }
            fSzie += 364.0/3.0
        }
    }
}
