import Foundation
import AppKit

/// Gera a folha de resultado InBody rodando o MOTOR ORIGINAL (as DLLs do LookinBody) via Mono.
/// Fidelidade 100% aos 4 modelos (770/120/270/370S) — é o mesmo código que a balança usa.
/// O Swift só monta os dados (das tabelas cruas do .mdb), chama o motor e recebe o PNG pronto,
/// já CENTRALIZADO na folha A4 (2480×3508). Mono é embutido no .app; usuário não instala nada.
enum EngineSheet {

    // Folhas que saem do motor. Adulto = os 4 modelos; água/criança = classes fixas.
    static func suportado(_ equip: String, _ tipo: TipoFolha) -> Bool {
        switch tipo {
        case .agua, .pediatrica: return true
        case .adulto: return ["120", "270", "370S", "770", ""].contains(equip.uppercased())
        default: return false   // histórico e demais: desenho nativo
        }
    }

    // MARK: - Localização do motor (bundle no app empacotado; repo em dev)

    private static let repoDev = "."

    /// mono, render.exe, pasta das DLLs e libs nativas. Procura no bundle primeiro, cai no repo.
    private struct Paths {
        let mono: String, renderExe: String, dllDir: String, libDir: String, gacPrefix: String
    }
    private static func paths() -> Paths? {
        let fm = FileManager.default
        // 1) Empacotado: Contents/Resources/engine/{mono,render.exe,dll,lib}
        if let res = Bundle.main.resourceURL?.appendingPathComponent("engine"),
           fm.fileExists(atPath: res.appendingPathComponent("render.exe").path),
           fm.fileExists(atPath: res.appendingPathComponent("bin/mono").path) {
            return Paths(mono: res.appendingPathComponent("bin/mono").path,
                         renderExe: res.appendingPathComponent("render.exe").path,
                         dllDir: res.appendingPathComponent("dll").path,
                         libDir: res.appendingPathComponent("lib").path,
                         gacPrefix: res.path)
        }
        // 2) Dev: mono do Homebrew + assets no repo.
        let mono = ["/opt/homebrew/bin/mono", "/usr/local/bin/mono"].first { fm.fileExists(atPath: $0) }
        let renderExe = "\(repoDev)/tools/engine/render.exe"
        let dllDir = "\(repoDev)/.exe-reference/lb120-bin"
        if let mono, fm.fileExists(atPath: renderExe), fm.isReadableFile(atPath: dllDir) {
            return Paths(mono: mono, renderExe: renderExe, dllDir: dllDir,
                         libDir: "/opt/homebrew/lib", gacPrefix: "/opt/homebrew")
        }
        return nil
    }

    // MARK: - DLL/classe e lista de blocos por modelo

    private static func alvo(_ equip: String, _ tipo: TipoFolha) -> (dll: String, tipo: String)? {
        switch tipo {
        case .agua:
            return ("LBPC.InBody.Print.ResultsSheetBodyWater.dll", "LBPC.InBody.Print.ResultsSheetBodyWater.ResultsSheetBodyWater770")
        case .pediatrica:
            return ("LBPC.InBody.Print.ResultsSheetInBodyChild.dll", "LBPC.InBody.Print.ResultsSheetInBodyChild.ResultsSheetInBodyChildV2")
        case .adulto:
            switch equip.uppercased() {
            case "120":  return ("LBPC.InBody.Print.ResultsSheetInBody1.dll", "LBPC.InBody.Print.ResultsSheetInBody1.ResultsSheetInBody120")
            case "270":  return ("LBPC.InBody.Print.ResultsSheetInBody2.dll", "LBPC.InBody.Print.ResultsSheetInBody2.ResultsSheetInBody270")
            case "370S": return ("LBPC.InBody.Print.ResultsSheetInBody3.dll", "LBPC.InBody.Print.ResultsSheetInBody3.ResultsSheetInBody370S")
            default:     return ("LBPC.InBody.Print.ResultsSheetInBody7.dll", "LBPC.InBody.Print.ResultsSheetInBody7.ResultsSheetInBody770")
            }
        default: return nil
        }
    }

    // Listas de blocos da coluna direita (lidas das folhas reais de cada modelo/tipo).
    private static func listaBlocos(_ equip: String, _ tipo: TipoFolha) -> String {
        switch tipo {
        case .agua:
            return "r_bw_comp_ibw_right;r_seg_bw_anal;r_body_comp_anal;r_mus_fat_anal_ibw;r_obe_anal_ibw;r_rp_bmr;r_rp_whr;r_rp_wc;r_rp_vfa;r_rp_obe_deg;r_rp_bcm;r_rp_ac;r_rp_amc;r_rp_tbw_ffm;r_rp_ffmi;r_rp_fmi;r_wb_pa;r_impedance"
        case .pediatrica:
            return "r_grow_score;r_nut_eval|1;r_obe_eval|1;r_body_bal_eval|1;r_seg_lean_anal_child;r_rp_icw;r_rp_ecw;r_rp_bmr;r_rp_obe_deg_child;r_rp_bmc;r_rp_bcm;r_re_grow_graph;r_re_qr;r_impedance"
        default:
            switch equip.uppercased() {
            case "120":
                return "r_inbody_score;r_wei_con|1;r_rp_bmr;r_rp_whr;r_rp_vfl;r_rp_obe_deg;r_re_body_comp_anal;r_re_mus_fat_anal;r_re_obe_anal;r_re_seg_lean_anal_high;r_re_seg_fat_anal_high;r_re_qr;r_impedance"
            case "270":
                return "r_inbody_score;r_wei_con|1;r_obe_eval|1;r_whr_graph;r_vfl_graph;r_rp_ffm;r_rp_bmr;r_rp_obe_deg;r_rp_smi;r_rp_calorie;r_exe_plan;r_qr;r_impedance"
            case "370S":
                return "r_inbody_score;r_body_type;r_wei_con|1;r_seg_cir;r_whr_graph;r_vfl_graph;r_rp_smm;r_rp_bmr;r_rp_smi;r_rp_calorie;r_impedance"
            default: // 770
                return "r_inbody_score;r_vfa_graph;r_wei_con|1;r_body_bal_eval|1;r_rp_icw;r_rp_ecw;r_rp_bmr;r_rp_whr;r_rp_bcm;r_rp_smi;r_rp_calorie;r_wb_pa;r_seg_fat_anal_high;r_impedance"
            }
        }
    }

    // MARK: - Montagem do arquivo de dados (key=value)

    // Casas decimais de EXIBIÇÃO por campo (o .mdb guarda float32 com ruído: "29.700001").
    // O InBody arredonda por campo antes de desenhar; replicamos aqui. Default = 1 casa.
    private static func casas(_ col: String) -> Int {
        var c = col.uppercased()
        if c.hasSuffix("_MIN") { c = String(c.dropLast(4)) }
        if c.hasSuffix("_MAX") { c = String(c.dropLast(4)) }
        if c.hasPrefix("WED") { return 3 }                              // Taxa de AEC segmentar
        let zero: Set<String> = ["AGE","FS","TOT_SCORE","VFA","VFL","OBESITY","OD","BMR",
                                 "RECOMMANDENERGY","METABOLICAGE","IWT","DM","EVENT_COUNT"]
        let dois: Set<String> = ["MINERAL","WHR","FFMI","BFMI",
                                 "LRA","LLA","LT","LRL","LLL","FRA","FLA","FT","FRL","FLL"]
        if zero.contains(c) { return 0 }
        if dois.contains(c) { return 2 }
        if c == "TBWFFM" { return 3 }
        return 1
    }
    // Unidade imperial (lb/in). A DLL só troca o rótulo e converte a ALTURA (cabeçalho) sozinha; os
    // valores do corpo ela desenha crus. Conjuntos EXTRAÍDOS do próprio LookinBody (ResultsSheetManager
    // -> ClsConvertUnit.ConvertWeight / ConvertHeight), 15/08/2026. HT fica de fora (cabeçalho já faz).
    private static let LB_POR_KG = 2.2046670913696289          // POUND_PER_KG (ClsConvertUnit)
    private static let IN_POR_CM = 0.39370077848434448         // INCH_PER_CM
    private static var imperial: Bool { SetupConfig.carregar().unidade == 1 }
    private static let colunasPeso: Set<String> = [
        "BCM", "BCM_MAX", "BCM_MIN", "BFM", "BFM_MAX", "BFM_MIN", "BMC", "BMC_MAX", "BMC_MIN", "DM", "ECW", "FFM",
        "FFM_MAX", "FFM_MIN", "FLA", "FLL", "FRA", "FRL", "FT", "GripCutOff", "GripHigh", "GripLeft1", "GripLeft2", "GripLow",
        "GripRight1", "GripRight2", "ICW", "ILRA", "ILRL", "ILT", "INDRY_MAX", "INDRY_MIN", "IWT", "LLA", "LLL", "LRA",
        "LRA_MAX", "LRA_MIN", "LRL", "LRL_MAX", "LRL_MIN", "LT", "LT_MAX", "LT_MIN", "MC", "MINERAL", "MINERAL_MAX", "MINERAL_MIN",
        "PBFM_MAX", "PBFM_MIN", "PROTEIN", "PROTEIN_MAX", "PROTEIN_MIN", "SLM", "SLM_MAX", "SLM_MIN", "SMM", "SMM_MAX", "SMM_MIN", "TBW",
        "TBW_MAX", "TBW_MIN", "TW", "WT", "WT_MAX", "WT_MIN",
    ]
    private static let colunasComprimento: Set<String> = [
        "ABD", "ACL", "ACR", "CABD", "CACL", "CACR", "CCHEST", "CHEST", "CTHIGHL", "CTHIGHR", "FABD", "FACL",
        "FACR", "FCHEST", "FTHIGHL", "FTHIGHR", "HIP", "IABD", "IACL", "IACR", "ICABD", "ICACL", "ICACR", "ICCHEST",
        "ICHEST", "ICTHIGHL", "ICTHIGHR", "IFABD", "IFACL", "IFACR", "IFCHEST", "IFTHIGHL", "IFTHIGHR", "IHIP", "INECK", "ITHIGHL",
        "ITHIGHR", "NECK", "THIGHL", "THIGHR", "WAIST",
    ]
    /// Converte kg->lb (peso) ou cm->in (comprimento) quando imperial. Devolve string com PONTO
    /// (o vg arredonda por `casas(col)` depois, igual ao formato do app). Fora do imperial: intacto.
    private static func talvezImperial(_ col: String, _ s: String) -> String {
        guard imperial else { return s }
        let c = col.uppercased()
        let fator: Double? = colunasPeso.contains(c) ? LB_POR_KG : (colunasComprimento.contains(c) ? IN_POR_CM : nil)
        guard let f = fator,
              let v = Double(s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
        else { return s }
        return String(v * f)
    }

    // Separador decimal conforme o idioma: pt-BR usa vírgula; inglês (base das DLLs) usa ponto.
    private static var virgula: Bool { Idioma.atual == .ptBR }
    /// Ajusta uma string de número (gerada sempre com ponto) ao separador do idioma atual.
    private static func loc(_ dotStr: String) -> String {
        virgula ? dotStr.replacingOccurrences(of: ".", with: ",") : dotStr
    }
    // Valor do .mdb -> string arredondada no separador do idioma. Sem ponto = código/inteiro (passa direto).
    /// Logo da clinica (Setup A-04) como arquivo PNG p/ o motor. Modo imagem = o proprio
    /// arquivo; modo texto = rasteriza as 3 linhas num PNG temporario (quadro 265x90 em 3x).
    private static func logoArquivo() -> String? {
        let cfg = CustomLogoConfig.carregar()
        switch cfg.modo {
        case .nenhum:
            return nil
        case .imagem:
            return FileManager.default.fileExists(atPath: cfg.imagemPath) ? cfg.imagemPath : nil
        case .texto:
            let linhas = cfg.linhas.filter { !$0.texto.trimmingCharacters(in: .whitespaces).isEmpty }
            guard !linhas.isEmpty else { return nil }
            let esc: CGFloat = 3
            let quadro = NSSize(width: 265 * esc, height: 90 * esc)
            let img = NSImage(size: quadro)
            img.lockFocus()
            let fm = NSFontManager.shared
            let textos: [NSAttributedString] = linhas.map { l in
                var fonte = NSFont(name: l.fonte, size: CGFloat(l.tamanho) * esc)
                    ?? NSFont.systemFont(ofSize: CGFloat(l.tamanho) * esc)
                if l.negrito { fonte = fm.convert(fonte, toHaveTrait: .boldFontMask) }
                return NSAttributedString(string: l.texto,
                                          attributes: [.font: fonte, .foregroundColor: NSColor.black])
            }
            let alturaTotal = textos.reduce(0) { $0 + $1.size().height }
            var y = (quadro.height + alturaTotal) / 2
            for s in textos {
                let sz = s.size()
                y -= sz.height
                s.draw(at: NSPoint(x: (quadro.width - sz.width) / 2, y: y))
            }
            img.unlockFocus()
            guard let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:]) else { return nil }
            let path = NSTemporaryDirectory() + "openbody_logo_texto.png"
            do { try png.write(to: URL(fileURLWithPath: path)) } catch { return nil }
            return path
        }
    }

    private static func vg(_ col: String, _ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard t.contains("."), let d = Double(t.replacingOccurrences(of: ",", with: ".")) else {
            return loc(t)
        }
        var out = String(format: "%.\(casas(col))f", d)
        if out.contains(".") {                       // tira zeros à direita (ex.: 2.60 -> 2.6)
            while out.hasSuffix("0") { out.removeLast() }
            if out.hasSuffix(".") { out.removeLast() }
        }
        return loc(out)
    }

    private static func dataFile(_ m: Medida, _ p: Paciente, historico: [Medida], tipo: TipoFolha) -> String {
        var out: [String] = []
        // 1) Despejo das tabelas cruas do .mdb (nomes de coluna == campos do motor).
        for sec in ["BCA", "MFA", "WC", "LB", "ED", "IMP"] {
            guard let tbl = m.rawTBL[sec] else { continue }
            for (col, val) in tbl.sorted(by: { $0.key < $1.key }) {
                let v = val.trimmingCharacters(in: .whitespaces)
                if v.isEmpty || col.isEmpty { continue }
                out.append("\(sec).\(col)=\(vg(col, talvezImperial(col, v)))")
            }
        }
        // 2) Cabeçalho / controle (sobrescreve o que precisa de formato próprio).
        let equip = m.equip.uppercased()
        out.append("EQUIP=\(equip.isEmpty ? "770" : equip)")
        out.append("STR.ID=\(p.id)")
        out.append("STR.Name=\(p.nome)")
        // Sexo vem CIFRADO no .mdb; o app já tem decifrado. Sobrescreve o campo cru.
        if p.sexo == "M" || p.sexo == "F" { out.append("WC.SEX=\(p.sexo)") }
        if let dt = m.rawTBL["BCA"]?["DATETIMES"], !dt.isEmpty {
            out.append("STR.DateTimes=\(dt.filter { $0.isNumber })")
        }
        out.append("FLT.OverAge=99")
        // Data de nascimento NÃO sai em nenhuma folha (decisão do Giba, 14-ago).
        out.append("BOOL.UsePrintName=true")
        out.append("STR.ProgramName=LookinBody120")
        out.append("STR.ProgramVersion=4.0.0.7")
        if let sn = m.rawTBL["BCA"]?["EQUIP_SERIAL"], !sn.isEmpty { out.append("STR.EquipSerial=\(sn)") }
        // .mdb chama RENERGY; o motor lê RecommandEnergy (nomes diferentes) -> mapeia à mão.
        if let re = m.rawTBL["WC"]?["RENERGY"], !re.isEmpty { out.append("WC.RecommandEnergy=\(vg("RENERGY", re))") }
        // SMI: muitos exames vêm com BCA.BSMI=0 no banco; o LookinBody calcula dos segmentos.
        // SMI = massa magra apendicular (2 braços + 2 pernas) / altura(m)². Mesmo valor da folha nativa.
        let bsmiRaw = Double((m.rawTBL["BCA"]?["BSMI"] ?? "0").replacingOccurrences(of: ",", with: ".")) ?? 0
        if bsmiRaw < 0.1, m.altura > 0,
           let ra = m.seg["RA"], let la = m.seg["LA"], let rl = m.seg["RL"], let ll = m.seg["LL"], ra + la + rl + ll > 0 {
            let smi = (ra + la + rl + ll) / pow(m.altura / 100.0, 2)
            out.append("BCA.BSMI=" + loc(String(format: "%.1f", smi)))
        }
        out.append("DIALYSIS.AMPUTATE=0")
        // Logo da clinica (Setup A-04): o header do motor desenha no quadro 265x90 do canto direito.
        if let lp = logoArquivo() { out.append("LOGO=\(lp)") }
        // 3) Histórico (mais recente primeiro; SelectedIndex=0). InBody mostra sempre os ÚLTIMOS 8.
        let h = Array(historico.prefix(8))
        if !h.isEmpty {
            out.append("INT.DBCount=\(h.count)")
            out.append("INT.SelectedIndex=0")
            // Datas do histórico: 14 dígitos CRUS ("20220901093751"). O motor (ClsConvertDateTime)
            // insere os separadores sozinho; passar formatado quebra o parse e some com as datas.
            out.append("ARR.DateTime=" + h.map { $0.data.filter { $0.isNumber } }.joined(separator: "|"))
            // massa=true converte kg->lb no imperial (histórico de peso/músculo/gordura/água).
            func arr(_ massa: Bool = false, _ f: (Medida) -> Double) -> String {
                let k = (imperial && massa) ? LB_POR_KG : 1.0
                return h.map { loc(String(format: "%.1f", f($0) * k)) }.joined(separator: "|")
            }
            out.append("ARR.Weight=" + arr(true) { $0.peso })
            out.append("ARR.SMM=" + arr(true) { $0.smm })
            out.append("ARR.SLM=" + arr(true) { $0.smm })
            out.append("ARR.PBF=" + arr { $0.pgc })
            // 770 (DrawBodyCompostionHistoryD) lê ArrECWRatio (linha Taxa de AEC) e ArrEquip
            // SEM checar nulo -> sem eles o histórico inteiro é engolido. Inócuo p/ 270/120/370.
            out.append("ARR.ECWRatio=" + h.map { loc(String(format: "%.3f", $0.ecwTbw)) }.joined(separator: "|"))
            out.append("ARR.Equip=" + h.map { $0.equip.isEmpty ? "770" : $0.equip }.joined(separator: "|"))
            // Histórico da folha de ÁGUA (DrawBodyWaterCompositionHistoryB): ArrTBW/ICW/ECW.
            out.append("ARR.TBW=" + arr(true) { $0.tbw })
            out.append("ARR.ICW=" + arr(true) { $0.icw })
            out.append("ARR.ECW=" + arr(true) { $0.ecw })
            // Histórico da folha de CRIANÇA (DrawBodyCompostionHistoryE): Altura/BFM/BMI.
            out.append("ARR.Height=" + arr { $0.altura })
            out.append("ARR.BFM=" + arr(true) { $0.gordura })
            out.append("ARR.BMI=" + arr { $0.imc })
        }
        // 4) Coluna direita + lista do histórico da criança (5 linhas: Altura/Peso/MME/Gordura/PGC).
        out.append("STR.ResultsSheetBCHOption=r_h_height;r_h_weight;r_h_skemus;r_h_infat;r_h_pbf")
        out.append("RIGHT=\(listaBlocos(equip, tipo))")
        return out.joined(separator: "\n") + "\n"
    }

    // MARK: - Render

    /// Gera a folha pelo motor. `historico` = exames do paciente (mais recente primeiro), do atual p/ trás.
    /// Retorna nil se o motor não estiver disponível (o chamador cai no desenho nativo).
    static func render(_ m: Medida, _ p: Paciente, historico: [Medida], tipo: TipoFolha = .adulto) -> NSImage? {
        guard suportado(m.equip, tipo), let paths = paths(), let alvo = alvo(m.equip, tipo) else { return nil }
        let tmp = FileManager.default.temporaryDirectory
        let dataURL = tmp.appendingPathComponent("inbody_\(UUID().uuidString).txt")
        let outURL = tmp.appendingPathComponent("inbody_\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: dataURL); try? FileManager.default.removeItem(at: outURL) }
        do {
            try dataFile(m, p, historico: historico, tipo: tipo).write(to: dataURL, atomically: true, encoding: .utf8)
        } catch { return nil }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: paths.mono)
        let cultura = Idioma.atual == .enGB ? "en-US" : "pt-BR"
        let unidade = imperial ? "1" : "0"
        proc.arguments = [paths.renderExe, paths.dllDir, alvo.dll, alvo.tipo, outURL.path, dataURL.path, cultura, unidade]
        var env = ProcessInfo.processInfo.environment
        env["MONO_GAC_PREFIX"] = paths.gacPrefix
        env["DYLD_FALLBACK_LIBRARY_PATH"] = paths.libDir
        proc.environment = env
        let errPipe = Pipe(); proc.standardError = errPipe; proc.standardOutput = Pipe()
        do {
            try proc.run(); proc.waitUntilExit()
        } catch {
            NSLog("EngineSheet: falha ao rodar motor: \(error)"); return nil
        }
        // Carrega os BYTES na hora (não NSImage(contentsOf:), que é preguiçoso): o arquivo temporário
        // é apagado no defer ao retornar, e o preview desenha DEPOIS. Com contentsOf a folha saía em
        // branco de forma intermitente (arquivo já sumira na hora de desenhar). NSImage(data:) copia.
        guard proc.terminationStatus == 0,
              let dados = try? Data(contentsOf: outURL), let img = NSImage(data: dados) else {
            let e = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            NSLog("EngineSheet: motor falhou (\(proc.terminationStatus)): \(e.prefix(300))")
            return nil
        }
        return img
    }
}
