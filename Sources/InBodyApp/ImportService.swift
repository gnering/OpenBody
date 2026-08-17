import Foundation

/// Importa o banco Access (.mdb) do LookinBody para dentro do app.
/// Roda na máquina do próprio médico: ele escolhe o arquivo, o app lê.
enum ImportService {

    struct Resultado { let pacientes: [Paciente]; let aviso: String? }

    /// Localiza o mdb-export (mdbtools). No app distribuido vem EMBUTIDO em
    /// Contents/Helpers/ (E11); tambem aceita o INBODY_HELPERS do ambiente (bancada) e,
    /// por ultimo, o Homebrew da maquina de dev.
    static func ferramenta(_ nome: String) -> String? {
        var caminhos: [String] = []
        // 1. embutido no bundle do app (.app/Contents/Helpers)
        if let helpers = Bundle.main.bundlePath as String?, helpers.hasSuffix(".app") {
            caminhos.append(helpers + "/Contents/Helpers/")
        }
        // 2. override por ambiente (usado na prova de empacotamento)
        if let env = ProcessInfo.processInfo.environment["INBODY_HELPERS"] { caminhos.append(env + "/") }
        // 3. maquina de dev
        caminhos += ["/opt/homebrew/bin/", "/usr/local/bin/", "/usr/bin/"]
        for c in caminhos where FileManager.default.isExecutableFile(atPath: c + nome) {
            return c + nome
        }
        return nil
    }

    static func disponivel() -> Bool { ferramenta("mdb-export") != nil }

    /// internal (nao private): a prova de banco (T4) le as tabelas cruas do .mdb por aqui.
    static func exporta(_ db: String, _ tabela: String) -> [[String: String]] {
        guard let bin = ferramenta("mdb-export") else { return [] }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: bin)
        p.arguments = [db, tabela]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        do { try p.run() } catch { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard let texto = String(data: data, encoding: .utf8) else { return [] }
        return parseCSV(texto)
    }

    /// CSV simples do mdb-export (campos entre aspas, vírgula separadora).
    private static func parseCSV(_ texto: String) -> [[String: String]] {
        var linhas: [[String]] = []
        var campo = ""
        var linha: [String] = []
        var aspas = false
        var it = texto.makeIterator()
        var pend: Character? = nil
        func proximo() -> Character? { if let p = pend { pend = nil; return p }; return it.next() }
        while let c = proximo() {
            if aspas {
                if c == "\"" {
                    if let n = it.next() { if n == "\"" { campo.append("\"") } else { aspas = false; pend = n } }
                    else { aspas = false }
                } else { campo.append(c) }
            } else {
                switch c {
                case "\"": aspas = true
                case ",": linha.append(campo); campo = ""
                case "\n": linha.append(campo); campo = ""; linhas.append(linha); linha = []
                case "\r": break
                default: campo.append(c)
                }
            }
        }
        if !campo.isEmpty || !linha.isEmpty { linha.append(campo); linhas.append(linha) }
        guard let cab = linhas.first else { return [] }
        return linhas.dropFirst().compactMap { vals in
            guard vals.count == cab.count else { return nil }
            return Dictionary(uniqueKeysWithValues: zip(cab, vals))
        }
    }

    private static func num(_ r: [String: String], _ k: String, _ d: Int = 1) -> Double {
        Double((r[k] ?? "").replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    /// Texto cru de uma coluna (p/ ETYPE2 etc.), sem conversão numérica.
    private static func str(_ r: [String: String], _ k: String) -> String {
        (r[k] ?? "").trimmingCharacters(in: .whitespaces)
    }

    /// GENDER no LookinBody vem CIFRADO (mesma cifra do WC.SEX): dois valores fixos.
    /// Mapeados pela faixa de gordura (PBF_MIN 10=M, 18=F): uskM…=M, SiJ4…=F.
    /// Retorna nil p/ valor DESCONHECIDO/vazio: nunca chuta um sexo. Chutar sairia
    /// com a escala errada e o diff não acusaria (os dois lados leem o mesmo registro).
    static func sexoDecodificado(_ g: String) -> String? {
        let t = g.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("uskM") { return "M" }
        if t.hasPrefix("SiJ4") { return "F" }
        let inicial = String(t.prefix(1)).uppercased()   // bancos com GENDER em texto
        return (inicial == "M" || inicial == "F") ? inicial : nil
    }

    static func importar(_ db: String) -> Resultado {
        guard disponivel() else {
            return Resultado(pacientes: [], aviso: T("Access reader tool not found."))
        }
        let users = Dictionary(exporta(db, "USER_INFO1_TBL").map { ($0["LOCAL_ID"] ?? "", $0) },
                               uniquingKeysWith: { a, _ in a })
        func porData(_ t: String) -> [String: [String: String]] {
            Dictionary(exporta(db, t).map { ($0["DATETIMES"] ?? "", $0) }, uniquingKeysWith: { a, _ in a })
        }
        let bca = exporta(db, "BCA_TBL")
        let mfa = porData("MFA_TBL"); let wc = porData("WC_TBL"); let lb = porData("LB_TBL")
        let ed = porData("ED_TBL"); let imp = porData("IMP_TBL")

        var mapa: [String: Paciente] = [:]
        for b in bca {
            let dt = b["DATETIMES"] ?? ""
            guard let u = users[b["LOCAL_ID"] ?? ""] else { continue }
            let m = mfa[dt] ?? [:]; let w = wc[dt] ?? [:]; let l = lb[dt] ?? [:]
            let d = ed[dt] ?? [:]; let ip = imp[dt] ?? [:]
            let med = Self.montarMedida(b, m, w, l, d, ip, alturaCadastro: num(u, "HEIGHT"))
            guard med.peso > 0 else { continue }
            let pid = b["LOCAL_ID"] ?? UUID().uuidString
            if mapa[pid] == nil {
                mapa[pid] = Paciente(
                    id: u["USER_ID"].flatMap { $0.isEmpty ? nil : $0 } ?? pid,
                    nome: (u["NAME"] ?? "Sem nome").trimmingCharacters(in: .whitespaces),
                    sexo: sexoDecodificado(u["GENDER"] ?? "") ?? "?",   // "?" visível, nunca chuta
                    idade: Int(num(u, "AGE", 0)), altura: num(u, "HEIGHT"), exames: [],
                    celular: str(u, "TEL_HP"), historico: str(u, "MEDICAL_HISTORY"),
                    email: str(u, "E_MAIL"), nascimento: str(u, "BIRTHDAY"),
                    registro: str(u, "USER_REG_DATE"))
            }
            mapa[pid]?.exames.append(med)
        }
        var lista = Array(mapa.values)
        for i in lista.indices { lista[i].exames.sort { $0.data > $1.data } }
        lista.sort { ($0.exames.first?.data ?? "") > ($1.exames.first?.data ?? "") }
        let total = lista.reduce(0) { $0 + $1.exames.count }
        return Resultado(pacientes: lista,
                         aviso: lista.isEmpty ? T("No exam found in the file.") :
                            "\(T("Imported")) \(lista.count) \(T("patients and")) \(total) \(T("exams."))")
    }

    /// Constrói um Medida a partir dos 6 dicionários de tabela do exame (BCA/MFA/WC/LB/ED/IMP).
    /// Fonte ÚNICA do mapeamento coluna→Medida: usado tanto pelo import .mdb quanto pelo corpus.
    static func montarMedida(_ b: [String: String], _ m: [String: String], _ w: [String: String],
                             _ l: [String: String], _ d: [String: String], _ ip: [String: String],
                             alturaCadastro: Double) -> Medida {
            let dt = b["DATETIMES"] ?? ""
            let tbw = num(b, "TBW"); let ecw = num(b, "ECW")
            // Impedância Z(Ω): IMP_TBL.I{seg}{freq}. Trunk = "IT"; 1000 kHz = sufixo "1M".
            let impPrefix: [String: String] = ["RA": "IRA", "LA": "ILA", "TR": "IT", "RL": "IRL", "LL": "ILL"]
            let freqSuffix: [(Int, String)] = [(1, "1"), (5, "5"), (50, "50"), (250, "250"), (500, "500"), (1000, "1M")]
            var impMap: [String: [Int: Double]] = [:]
            for (seg, pre) in impPrefix {
                var linha: [Int: Double] = [:]
                for (khz, sfx) in freqSuffix { linha[khz] = num(ip, "\(pre)\(sfx)") }
                impMap[seg] = linha
            }
            let pbfLo = num(m, "PBF_MIN"), pbfHi = num(m, "PBF_MAX")
            // Dicionários/faixas içados para tipos explícitos (evita estouro do type-checker).
            let segMap: [String: Double] = ["RA": num(l, "LRA", 2), "LA": num(l, "LLA", 2), "TR": num(l, "LT", 2),
                                            "RL": num(l, "LRL", 2), "LL": num(l, "LLL", 2)]
            let segpMap: [String: Double] = ["RA": num(l, "PLRA"), "LA": num(l, "PLLA"), "TR": num(l, "PLT"),
                                             "RL": num(l, "PLRL"), "LL": num(l, "PLLL")]
            let segAECMap: [String: Double] = ["RA": num(d, "WEDRA", 3), "LA": num(d, "WEDLA", 3), "TR": num(d, "WEDT", 3),
                                               "RL": num(d, "WEDRL", 3), "LL": num(d, "WEDLL", 3)]
            let segFatMap: [String: Double] = ["RA": num(l, "FRA", 2), "LA": num(l, "FLA", 2), "TR": num(l, "FT", 2),
                                               "RL": num(l, "FRL", 2), "LL": num(l, "FLL", 2)]
            let segFatPMap: [String: Double] = ["RA": num(l, "PFRA"), "LA": num(l, "PFLA"), "TR": num(l, "PFT"),
                                                "RL": num(l, "PFRL"), "LL": num(l, "PFLL")]
            let segWaterMap: [String: Double] = ["RA": num(l, "WWRA", 2), "LA": num(l, "WWLA", 2), "TR": num(l, "WWT", 2),
                                                 "RL": num(l, "WWRL", 2), "LL": num(l, "WWLL", 2)]
            // Circunferências completas (ED_TBL): cintura=ABD, quadril=HIP, braço=ACR,
            // pescoço=NECK, tórax=CHEST, coxa=THIGHR, panturrilha=CIRCALF.
            let circMap: [String: Double] = ["cintura": num(d, "ABD"), "quadril": num(d, "HIP"),
                                             "braco": num(d, "ACR"), "pescoco": num(d, "NECK"),
                                             "torax": num(d, "CHEST"), "coxa": num(d, "THIGHR"),
                                             "panturrilha": num(d, "CIRCALF")]
            // % da massa magra IDEAL por segmento (LB_TBL.PIL*) — barra kg do segmentar usa ISSO, não PL*.
            let segpIdealMap: [String: Double] = ["RA": num(l, "PILRA"), "LA": num(l, "PILLA"), "TR": num(l, "PILT"),
                                                  "RL": num(l, "PILRL"), "LL": num(l, "PILLL")]
            // % de água segmentar (LB_TBL.PINW*) — coluna real, não reusar PL*.
            let segWaterPMap: [String: Double] = ["RA": num(l, "PINWRA"), "LA": num(l, "PINWLA"), "TR": num(l, "PINWT"),
                                                  "RL": num(l, "PINWRL"), "LL": num(l, "PINWLL")]
            // Faixa normal (kg) das barras segmentares (LB_TBL.L*_MIN/MAX). Só RA/TR/RL no schema;
            // braço/perna esquerdos espelham o direito.
            let lraMin = num(l, "LRA_MIN", 2), lraMax = num(l, "LRA_MAX", 2)
            let lrlMin = num(l, "LRL_MIN", 2), lrlMax = num(l, "LRL_MAX", 2)
            let segMinMap: [String: Double] = ["RA": lraMin, "LA": lraMin, "TR": num(l, "LT_MIN", 2),
                                               "RL": lrlMin, "LL": lrlMin]
            let segMaxMap: [String: Double] = ["RA": lraMax, "LA": lraMax, "TR": num(l, "LT_MAX", 2),
                                               "RL": lrlMax, "LL": lrlMax]
            // IPBF real (ponto ideal de PGC). Fallback = ponto médio da faixa quando ausente.
            let ipbfReal = num(m, "IPBF")
            // Altura por exame (WC_TBL.HT); fallback = altura do cadastro.
            let alturaExame = num(w, "HT") > 0 ? num(w, "HT") : alturaCadastro
            let bfmiReal = num(b, "BFMI", 2)
            let alturaM = alturaExame / 100.0
            let fmiReal = bfmiReal > 0 ? bfmiReal : (alturaM > 0 ? num(b, "BFM") / (alturaM * alturaM) : 0)
            let rTbw = Referencia(lo: num(b, "TBW_MIN"), hi: num(b, "TBW_MAX"))
            // Faixa da Massa de Gordura na tabela de Composição vem de MFA.PBFM_MIN/MAX,
            // NÃO de BCA.BFM_MIN/MAX (ResultsSheetInBody770.cs:89 passa strFat_MIN=PBFM_MIN).
            // ATENÇÃO: o schema do .mdb tem o typo "PBFM_MAx" (x minúsculo); o corpus
            // normaliza p/ "PBFM_MAX". Lê os dois p/ funcionar nas duas origens.
            let pbfmMax = num(m, "PBFM_MAx")
            let rGord = Referencia(lo: num(m, "PBFM_MIN"), hi: pbfmMax != 0 ? pbfmMax : num(m, "PBFM_MAX"))
            let rFfm = Referencia(lo: num(b, "FFM_MIN"), hi: num(b, "FFM_MAX"))
            let rSmm = Referencia(lo: num(m, "SMM_MIN"), hi: num(m, "SMM_MAX"))
            let rProt = Referencia(lo: num(b, "PROTEIN_MIN"), hi: num(b, "PROTEIN_MAX"))
            let rMin = Referencia(lo: num(b, "MINERAL_MIN", 2), hi: num(b, "MINERAL_MAX", 2))
            let rSlm = Referencia(lo: num(b, "SLM_MIN"), hi: num(b, "SLM_MAX"))
            let rPeso = Referencia(lo: num(m, "WT_MIN"), hi: num(m, "WT_MAX"))
            let rIcw = Referencia(lo: num(b, "ICW_MIN"), hi: num(b, "ICW_MAX"))
            let rEcw = Referencia(lo: num(b, "ECW_MIN"), hi: num(b, "ECW_MAX"))
            // Faixas dos Dados Adicionais (todas bRangeUse no .exe). SMI não tem MIN/MAX no schema → 0.
            let rBmr = Referencia(lo: num(w, "BMR_MIN", 0), hi: num(w, "BMR_MAX", 0))
            let rRcq = Referencia(lo: num(m, "WHR_MIN", 2), hi: num(m, "WHR_MAX", 2))
            let rBcm = Referencia(lo: num(w, "BCM_MIN"), hi: num(w, "BCM_MAX"))
            let med = Medida(
                data: dt, peso: num(b, "WT"), tbw: tbw, icw: num(b, "ICW"), ecw: ecw,
                proteina: num(b, "PROTEIN"), mineral: num(b, "MINERAL", 2),
                gordura: num(b, "BFM"), ffm: num(b, "FFM"), slm: num(b, "SLM"),
                smm: num(m, "SMM"), imc: num(m, "BMI"), pgc: num(m, "PBF"), rcq: num(m, "WHR", 2),
                tmb: num(w, "BMR", 0), gv: num(w, "VFA"),
                ecwTbw: tbw > 0 ? (ecw / tbw) : 0,
                refTbw: rTbw, refGordura: rGord, refFfm: rFfm, refSmm: rSmm,
                seg: segMap, segp: segpMap,
                refProteina: rProt, refMineral: rMin, refSlm: rSlm,
                refPeso: rPeso, refIcw: rIcw, refEcw: rEcw,
                pwt: num(m, "PWT"), psmm: num(m, "PSMM"), pfat: num(m, "PBFM"),
                bmiMin: num(m, "BMI_MIN"), bmiMax: num(m, "BMI_MAX"), ibmi: num(m, "IBMI2"),
                ibmiRaw: num(m, "IBMI"), bmiMax2: num(m, "BMI_MAX2"),
                pbfMin: pbfLo, pbfMax: pbfHi, ipbf: ipbfReal > 0 ? ipbfReal : (pbfLo + pbfHi) / 2,
                segAEC: segAECMap, segFat: segFatMap, segFatP: segFatPMap,
                inbodyScore: num(w, "FS", 0),
                pesoIdeal: num(w, "TW"), controlePeso: num(w, "WC"),
                controleGordura: num(w, "FC"), controleMuscular: num(w, "MC"),
                bcm: num(w, "BCM"), smi: num(b, "BSMI", 2), ingestaoCalorica: num(w, "RENERGY", 0),
                anguloFase: num(l, "WBPA50", 1),
                impedancia: impMap,
                segWater: segWaterMap,
                segWaterP: segWaterPMap,
                circunferencias: circMap,
                grauObesidadeInfantil: num(w, "OBESITY"),
                altura: alturaExame,
                segpIdeal: segpIdealMap,
                etype2: str(w, "ETYPE2"),
                totScore: Int(num(w, "TOT_SCORE", 0)),
                odMin: num(w, "OD_MIN"), odMax: num(w, "OD_MAX"),
                metabolicAge: Int(num(w, "METABOLIC_AGE", 0)),
                bmc: num(w, "BMC", 2),
                ffmi: num(b, "FFMI", 2), bfmi: bfmiReal, fmi: fmiReal,
                tbwFfm: num(l, "TBWFFM", 3), wed: num(d, "WED", 3),
                refBmr: rBmr, refRcq: rRcq, refBcm: rBcm,
                segMin: segMinMap, segMax: segMaxMap,
                equip: str(b, "EQUIP"), etype3: str(w, "ETYPE3"))
            // Valores das folhas Água/Criança + coluna direita: antes só o PDFExportCLI
            // (via oráculo) preenchia isto, então na TELA a folha de água vinha zerada.
            // Aqui popula das MESMAS colunas do banco, p/ a tela e o exame ao vivo encherem.
            // No caminho de prova o PDFExportCLI sobrescreve com o oráculo (corpus intacto).
            var comSheet = med
            var sr: [String: Double] = [:]
            sr["ptbw"] = num(m, "PTBW"); sr["picw"] = num(m, "PICW"); sr["pecw"] = num(m, "PECW")
            sr["icwD"] = num(b, "ICW"); sr["ecwD"] = num(b, "ECW")
            sr["icwMinD"] = num(b, "ICW_MIN"); sr["icwMaxD"] = num(b, "ICW_MAX")
            sr["ecwMinD"] = num(b, "ECW_MIN"); sr["ecwMaxD"] = num(b, "ECW_MAX")
            sr["wwRA"] = num(l, "WWRA", 2); sr["wwLA"] = num(l, "WWLA", 2); sr["wwT"] = num(l, "WWT", 2)
            sr["wwRL"] = num(l, "WWRL", 2); sr["wwLL"] = num(l, "WWLL", 2)
            sr["pinwRA"] = num(l, "PINWRA"); sr["pinwLA"] = num(l, "PINWLA"); sr["pinwT"] = num(l, "PINWT")
            sr["pinwRL"] = num(l, "PINWRL"); sr["pinwLL"] = num(l, "PINWLL")
            sr["wwRAMin"] = num(l, "WWRA_MIN", 2); sr["wwRAMax"] = num(l, "WWRA_MAX", 2)
            sr["wwTMin"] = num(l, "WWT_MIN", 2); sr["wwTMax"] = num(l, "WWT_MAX", 2)
            sr["wwRLMin"] = num(l, "WWRL_MIN", 2); sr["wwRLMax"] = num(l, "WWRL_MAX", 2)
            sr["bmc"] = num(w, "BMC", 2); sr["bmcMin"] = num(w, "BMC_MIN", 2); sr["bmcMax"] = num(w, "BMC_MAX", 2)
            sr["totScore"] = num(w, "TOT_SCORE", 0); sr["iwt"] = num(m, "IWT")
            sr["tbwFfm"] = num(l, "TBWFFM", 3); sr["ffmi"] = num(b, "FFMI", 2); sr["bfmi"] = num(b, "BFMI", 2)
            sr["waistCirc"] = num(d, "ABD", 1); sr["obesityDeg"] = num(w, "OBESITY")
            sr["odMin"] = num(w, "OD_MIN"); sr["odMax"] = num(w, "OD_MAX")
            sr["ac"] = num(d, "ACR", 1); sr["amc"] = num(d, "AMC", 1)
            comSheet.sheetRaw = sr
            // rightRaw (strings pré-formatadas): a coluna direita da folha de Água lê BMR, WHR,
            // VFA, BCM, ângulo de fase e a tabela de Impedância daqui. Também só o PDFExportCLI
            // preenchia; sem isto, esses campos vinham zerados na tela.
            var rr: [String: String] = [:]
            rr["bmr"] = w["BMR"]; rr["bmrMin"] = w["BMR_MIN"]; rr["bmrMax"] = w["BMR_MAX"]
            rr["whr"] = m["WHR"]; rr["whrMin"] = m["WHR_MIN"]; rr["whrMax"] = m["WHR_MAX"]
            rr["vfa"] = w["VFA"]
            rr["bcm"] = w["BCM"]; rr["bcmMin"] = w["BCM_MIN"]; rr["bcmMax"] = w["BCM_MAX"]
            rr["wbpa50"] = l["WBPA50"]
            // Impedâncias I{seg}{freq} (IRA1, IT50, IRA1M...): a coluna crua vem com casas
            // demais (411.89999); a folha não arredonda, então embola. Formata em 1 casa.
            for (k, v) in ip where k.hasPrefix("I") {
                if let d = Double(v.replacingOccurrences(of: ",", with: ".")) {
                    rr[k] = String(format: "%.1f", d)
                } else { rr[k] = v }
            }
            comSheet.rightRaw = rr
            // Tabelas cruas do .mdb p/ o motor InBody (EngineSheet). Nomes de coluna == campos do motor.
            comSheet.rawTBL = ["BCA": b, "MFA": m, "WC": w, "LB": l, "ED": d, "IMP": ip]
            return comSheet
    }

    /// Prova a camada de leitura: roda o MESMO caminho de import de produção (mdb-export +
    /// montarMedida) sobre TODO o banco e devolve, por exame, o bruto (colunas de cada tabela)
    /// + o computado (campos do Medida), sem renderizar nada. Computação pura.
    static func dumpVerificacao(_ db: String) -> [[String: Any]] {
        guard disponivel() else { return [] }
        let users = Dictionary(exporta(db, "USER_INFO1_TBL").map { ($0["LOCAL_ID"] ?? "", $0) },
                               uniquingKeysWith: { a, _ in a })
        func porData(_ t: String) -> [String: [String: String]] {
            Dictionary(exporta(db, t).map { ($0["DATETIMES"] ?? "", $0) }, uniquingKeysWith: { a, _ in a })
        }
        let bca = exporta(db, "BCA_TBL")
        let mfa = porData("MFA_TBL"); let wc = porData("WC_TBL"); let lb = porData("LB_TBL")
        let ed = porData("ED_TBL"); let imp = porData("IMP_TBL")
        var out: [[String: Any]] = []
        for b in bca {
            let dt = b["DATETIMES"] ?? ""
            guard let u = users[b["LOCAL_ID"] ?? ""] else { out.append(["datetimes": dt, "erro": "sem USER_INFO1_TBL (LOCAL_ID orfao)"]); continue }
            let m = mfa[dt] ?? [:]; let w = wc[dt] ?? [:]; let l = lb[dt] ?? [:]
            let d = ed[dt] ?? [:]; let ip = imp[dt] ?? [:]
            let med = Self.montarMedida(b, m, w, l, d, ip, alturaCadastro: num(u, "HEIGHT"))
            var row: [String: Any] = [
                "datetimes": dt, "sexo_cru": u["GENDER"] ?? "", "sexo": sexoDecodificado(u["GENDER"] ?? "") ?? "?",
                // bruto (so os campos usados por montarMedida, pra comparar 1:1)
                "raw_BCA_WT": b["WT"] ?? "", "raw_BCA_TBW": b["TBW"] ?? "", "raw_BCA_ICW": b["ICW"] ?? "",
                "raw_BCA_ECW": b["ECW"] ?? "", "raw_BCA_PROTEIN": b["PROTEIN"] ?? "", "raw_BCA_MINERAL": b["MINERAL"] ?? "",
                "raw_BCA_BFM": b["BFM"] ?? "", "raw_BCA_FFM": b["FFM"] ?? "", "raw_BCA_SLM": b["SLM"] ?? "",
                "raw_BCA_BSMI": b["BSMI"] ?? "", "raw_BCA_FFMI": b["FFMI"] ?? "", "raw_BCA_BFMI": b["BFMI"] ?? "",
                "raw_MFA_SMM": m["SMM"] ?? "", "raw_MFA_BMI": m["BMI"] ?? "", "raw_MFA_PBF": m["PBF"] ?? "",
                "raw_MFA_WHR": m["WHR"] ?? "", "raw_MFA_IPBF": m["IPBF"] ?? "",
                "raw_MFA_PBF_MIN": m["PBF_MIN"] ?? "", "raw_MFA_PBF_MAX": m["PBF_MAX"] ?? "",
                "raw_WC_BMR": w["BMR"] ?? "", "raw_WC_VFA": w["VFA"] ?? "", "raw_WC_FS": w["FS"] ?? "",
                "raw_WC_HT": w["HT"] ?? "", "raw_WC_ETYPE2": w["ETYPE2"] ?? "", "raw_WC_TOT_SCORE": w["TOT_SCORE"] ?? "",
                "raw_WC_OBESITY": w["OBESITY"] ?? "", "raw_WC_OD_MIN": w["OD_MIN"] ?? "", "raw_WC_OD_MAX": w["OD_MAX"] ?? "",
                "raw_WC_BCM": w["BCM"] ?? "", "raw_WC_RENERGY": w["RENERGY"] ?? "",
                "raw_LB_LRA": l["LRA"] ?? "", "raw_LB_WBPA50": l["WBPA50"] ?? "", "raw_LB_TBWFFM": l["TBWFFM"] ?? "",
                "raw_ED_WED": d["WED"] ?? "", "raw_ED_ABD": d["ABD"] ?? "",
                "raw_IMP_IRA1": ip["IRA1"] ?? "", "raw_IMP_IT1": ip["IT1"] ?? "",
                "raw_USER_HEIGHT": u["HEIGHT"] ?? "", "raw_USER_AGE": u["AGE"] ?? "",
                // computado (Medida, so os campos derivados por FORMULA, nao passagem direta)
                "med_peso": med.peso, "med_tbw": med.tbw, "med_icw": med.icw, "med_ecw": med.ecw,
                "med_ecwTbw": med.ecwTbw, "med_ipbf": med.ipbf, "med_fmi": med.fmi, "med_bfmi": med.bfmi,
                "med_altura": med.altura, "med_smm": med.smm, "med_imc": med.imc, "med_pgc": med.pgc,
                "med_tmb": med.tmb, "med_gv": med.gv, "med_bmc": med.bmc, "med_etype2": med.etype2,
                "med_totScore": med.totScore, "med_odMin": med.odMin, "med_odMax": med.odMax,
                "med_grauObesidadeInfantil": med.grauObesidadeInfantil,
                "med_refGordura_lo": med.refGordura.lo, "med_refGordura_hi": med.refGordura.hi,
                "med_segMin_RA": med.segMin["RA"] ?? -999, "med_segMin_LA": med.segMin["LA"] ?? -999,
                "med_segMax_RA": med.segMax["RA"] ?? -999, "med_segMax_LA": med.segMax["LA"] ?? -999,
                "med_seg_RA": med.seg["RA"] ?? -999,
            ]
            row["raw_MFA_PBFM_MIN"] = m["PBFM_MIN"] ?? ""
            row["raw_MFA_PBFM_MAX"] = m["PBFM_MAX"] ?? (m["PBFM_MAx"] ?? "")
            out.append(row)
        }
        return out
    }

    /// Constrói um Medida a partir de UMA linha do corpus (colunas com prefixo de
    /// tabela: BCA./MFA./WC./LB./ED./IMP.). Reusa o MESMO mapeamento do import .mdb.
    static func medidaDeLinha(_ row: [String: String]) -> Medida {
        func sub(_ pref: String) -> [String: String] {
            var out: [String: String] = [:]
            for (k, v) in row where k.hasPrefix(pref) { out[String(k.dropFirst(pref.count))] = v }
            return out
        }
        return montarMedida(sub("BCA."), sub("MFA."), sub("WC."), sub("LB."), sub("ED."), sub("IMP."),
                            alturaCadastro: 0)
    }
}
