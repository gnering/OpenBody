import Foundation
import SwiftUI

struct Referencia: Hashable { let lo: Double; let hi: Double }

/// Formata QUALQUER data guardada ("20260714170310" ou "2026/07/14 17:03") para "dd.MM.yyyy HH:mm".
/// Data é data em todo lugar do app — use isto em toda exibição de data.
func dataBR(_ raw: String) -> String {
    let a = Array(raw.filter { $0.isNumber })
    guard a.count >= 8 else { return raw }
    let dia = "\(String(a[6..<8])).\(String(a[4..<6])).\(String(a[0..<4]))"
    if a.count >= 12 { return dia + " \(String(a[8..<10])):\(String(a[10..<12]))" }
    return dia
}

/// Binding para campos de data EDITÁVEIS: mostra "dd.MM.yyyy HH:mm" e grava de volta no
/// formato de origem (14 dígitos p/ exame, "yyyy/MM/dd HH:mm" p/ pressão/glicose).
func dataEditBinding(_ b: Binding<String>) -> Binding<String> {
    Binding(
        get: { dataBR(b.wrappedValue) },
        set: { novo in
            let temBarra = b.wrappedValue.contains("/")
            let d = Array(novo.filter { $0.isNumber })
            guard d.count >= 8 else { return }          // dd MM yyyy [HH mm]
            let dd = String(d[0..<2]), mm = String(d[2..<4]), yyyy = String(d[4..<8])
            let hh = d.count >= 10 ? String(d[8..<10]) : "00"
            let mi = d.count >= 12 ? String(d[10..<12]) : "00"
            b.wrappedValue = temBarra ? "\(yyyy)/\(mm)/\(dd) \(hh):\(mi)" : "\(yyyy)\(mm)\(dd)\(hh)\(mi)00"
        })
}

struct Medida: Identifiable, Hashable {
    let id = UUID()
    var data: String   // DATETIMES; editável na grade do gerenciador (E4)
    let peso, tbw, icw, ecw, proteina, mineral, gordura, ffm, slm: Double
    let smm, imc, pgc, rcq, tmb, gv, ecwTbw: Double
    let refTbw, refGordura, refFfm, refSmm: Referencia
    // massa magra por segmento (kg) e % do esperado: braço D/E, tronco, perna D/E
    let seg: [String: Double]
    let segp: [String: Double]

    // ---- Campos estendidos (0/[:] = "ausente"; exame real/DemoData preenchem) ----
    // Faixas adicionais (min~max)
    let refProteina: Referencia   // BCA_TBL.PROTEIN_MIN/_MAX
    let refMineral:  Referencia   // BCA_TBL.MINERAL_MIN/_MAX
    let refSlm:      Referencia   // BCA_TBL.SLM_MIN/_MAX
    let refPeso:     Referencia   // MFA_TBL.WT_MIN/_MAX
    let refIcw:      Referencia   // BCA_TBL.ICW_MIN/_MAX
    let refEcw:      Referencia   // BCA_TBL.ECW_MIN/_MAX
    // Percentuais de posicionamento das barras Músculo-Gordura
    let pwt:  Double   // MFA_TBL.PWT  (% do peso ideal)
    let psmm: Double   // MFA_TBL.PSMM (% da MME ideal)
    let pfat: Double   // MFA_TBL.PBFM (% da gordura ideal)
    // Faixa/ideal de IMC e PGC (barras de Obesidade)
    let bmiMin: Double, bmiMax: Double, ibmi: Double   // MFA_TBL.BMI_MIN/_MAX/IBMI2
    let ibmiRaw: Double   // MFA_TBL.IBMI (cru; <0.1 marca menor -> escala por idade)
    let bmiMax2: Double   // MFA_TBL.BMI_MAX2 (limite p/ a escala de IMC de menores)
    let pbfMin: Double, pbfMax: Double, ipbf: Double   // MFA_TBL.PBF_MIN/_MAX
    // Segmentar adicional (chaves: RA, LA, TR, RL, LL)
    let segAEC:  [String: Double]   // Taxa de AEC por segmento (ED_TBL.WED*)
    let segFat:  [String: Double]   // gordura por segmento em kg (LB_TBL.F*)
    let segFatP: [String: Double]   // gordura por segmento em % (LB_TBL.PF*)
    // Coluna direita (adulto)
    let inbodyScore: Double                             // WC_TBL.FS
    let pesoIdeal: Double, controlePeso: Double         // WC_TBL.TW / WC_TBL.WC
    let controleGordura: Double, controleMuscular: Double // WC_TBL.FC / WC_TBL.MC
    let bcm: Double                                     // WC_TBL.BCM
    let smi: Double                                     // BCA_TBL.BSMI (kg/m²)
    let ingestaoCalorica: Double                        // WC_TBL.RENERGY
    let anguloFase: Double                              // LB_TBL.WBPA50 (φ 50 kHz)
    // Impedância Z(Ω): segmento -> (frequência kHz -> valor). Freqs: 1,5,50,250,500,1000.
    let impedancia: [String: [Int: Double]]            // IMP_TBL.I{RA,LA,T,RL,LL}{freq}
    // Água
    let segWater:  [String: Double]   // água por segmento em L (LB_TBL.WW*)
    let segWaterP: [String: Double]   // água por segmento em %
    let circunferencias: [String: Double]  // cintura/quadril/braco (ED_TBL.ABD/HIP/ACR)
    // Pediátrica
    let grauObesidadeInfantil: Double   // WC_TBL.OBESITY (% do peso ideal infantil)

    // ---- Fase DADOS (auditoria): campos aditivos p/ as folhas lerem valores reais ----
    let altura: Double                 // WC_TBL.HT — altura por exame (série histórica real)
    let segpIdeal: [String: Double]    // LB_TBL.PIL* — % da massa magra IDEAL por segmento (barra kg)
    let etype2: String                 // WC_TBL.ETYPE2 — [0..2]=nutricional [6][7]=obesidade [9..11]=balanceamento
    let totScore: Int                  // WC_TBL.TOT_SCORE — Pontuação de Crescimento (pediátrica)
    let odMin: Double, odMax: Double   // WC_TBL.OD_MIN/OD_MAX — faixa do Grau de Obesidade
    let metabolicAge: Int              // WC_TBL.METABOLIC_AGE — idade metabólica
    let bmc: Double                    // WC_TBL.BMC — conteúdo mineral ósseo (kg)
    let ffmi: Double, bfmi: Double     // BCA_TBL.FFMI/BFMI — índices de massa magra/gorda (kg/m²)
    let fmi: Double                    // Índice de massa gorda (IGC) = BFM/altura²
    let tbwFfm: Double                 // LB_TBL.TBWFFM — água/massa magra (ACT/MLG)
    let wed: Double                    // ED_TBL.WED — AEC/ACT corpo inteiro (ler, não calcular)
    let refBmr: Referencia             // WC_TBL.BMR_MIN/_MAX
    let refRcq: Referencia             // MFA_TBL.WHR_MIN/_MAX
    let refBcm: Referencia             // WC_TBL.BCM_MIN/_MAX
    let refSmi: Referencia             // faixa do SMI (Dados Adicionais)
    let growthPattern: String          // base.Grow — padrão de curva (BR: "WHO2007")
    let segMin: [String: Double]       // LB_TBL.L*_MIN — faixa normal (kg) das barras segmentares
    let segMax: [String: Double]       // LB_TBL.L*_MAX
    let qrPayload: String?             // conteúdo do QR (r_qr 108×108); nil = ausente
    let equip: String                  // BCA_TBL.EQUIP — modelo da balança ("120","270","370S","770"); escolhe a folha
    let etype3: String                 // WC_TBL.ETYPE3 — avaliação por segmento (Acima/Normal/Abaixo) das folhas 120/270/370S
    // Coluna direita: strings de exibição CRUAS (chave→texto) do porte fiel de DrawRightOption.
    // Alimentadas pelo MESMO registro JSON que abastece o oráculo (entrada idêntica dos 2 lados).
    // Vazio = usa a derivação/modelo como reserva.
    var rightRaw: [String: String] = [:]
    // Numéricos extras das folhas ÁGUA/CRIANÇA (ww*, pinw*, ptbw/picw/pecw, icwMinD...):
    // alimentados pelo record JSON do oráculo; vazio no fluxo normal do app.
    var sheetRaw: [String: Double] = [:]

    // Tabelas CRUAS do .mdb (BCA/MFA/WC/LB/ED/IMP) exatamente como o motor InBody lê.
    // Preenchidas em ImportService.montarMedida; usadas por EngineSheet para gerar a folha
    // pelo motor original. Vazio = exame demo/sem import (cai no desenho nativo).
    var rawTBL: [String: [String: String]] = [:]

    // Init explícito: campos-base obrigatórios; campos estendidos com default "ausente".
    init(data: String, peso: Double, tbw: Double, icw: Double, ecw: Double,
         proteina: Double, mineral: Double, gordura: Double, ffm: Double, slm: Double,
         smm: Double, imc: Double, pgc: Double, rcq: Double, tmb: Double, gv: Double, ecwTbw: Double,
         refTbw: Referencia, refGordura: Referencia, refFfm: Referencia, refSmm: Referencia,
         seg: [String: Double], segp: [String: Double],
         refProteina: Referencia = Referencia(lo: 0, hi: 0),
         refMineral: Referencia = Referencia(lo: 0, hi: 0),
         refSlm: Referencia = Referencia(lo: 0, hi: 0),
         refPeso: Referencia = Referencia(lo: 0, hi: 0),
         refIcw: Referencia = Referencia(lo: 0, hi: 0),
         refEcw: Referencia = Referencia(lo: 0, hi: 0),
         pwt: Double = 0, psmm: Double = 0, pfat: Double = 0,
         bmiMin: Double = 0, bmiMax: Double = 0, ibmi: Double = 0,
         ibmiRaw: Double = 0, bmiMax2: Double = 0,
         pbfMin: Double = 0, pbfMax: Double = 0, ipbf: Double = 0,
         segAEC: [String: Double] = [:], segFat: [String: Double] = [:], segFatP: [String: Double] = [:],
         inbodyScore: Double = 0,
         pesoIdeal: Double = 0, controlePeso: Double = 0,
         controleGordura: Double = 0, controleMuscular: Double = 0,
         bcm: Double = 0, smi: Double = 0, ingestaoCalorica: Double = 0, anguloFase: Double = 0,
         impedancia: [String: [Int: Double]] = [:],
         segWater: [String: Double] = [:], segWaterP: [String: Double] = [:],
         circunferencias: [String: Double] = [:],
         grauObesidadeInfantil: Double = 0,
         altura: Double = 0,
         segpIdeal: [String: Double] = [:],
         etype2: String = "",
         totScore: Int = 0,
         odMin: Double = 0, odMax: Double = 0,
         metabolicAge: Int = 0,
         bmc: Double = 0,
         ffmi: Double = 0, bfmi: Double = 0, fmi: Double = 0,
         tbwFfm: Double = 0, wed: Double = 0,
         refBmr: Referencia = Referencia(lo: 0, hi: 0),
         refRcq: Referencia = Referencia(lo: 0, hi: 0),
         refBcm: Referencia = Referencia(lo: 0, hi: 0),
         refSmi: Referencia = Referencia(lo: 0, hi: 0),
         growthPattern: String = "WHO2007",
         segMin: [String: Double] = [:], segMax: [String: Double] = [:],
         qrPayload: String? = nil,
         equip: String = "", etype3: String = "") {
        self.data = data; self.peso = peso; self.tbw = tbw; self.icw = icw; self.ecw = ecw
        self.proteina = proteina; self.mineral = mineral; self.gordura = gordura; self.ffm = ffm; self.slm = slm
        self.smm = smm; self.imc = imc; self.pgc = pgc; self.rcq = rcq; self.tmb = tmb; self.gv = gv; self.ecwTbw = ecwTbw
        self.refTbw = refTbw; self.refGordura = refGordura; self.refFfm = refFfm; self.refSmm = refSmm
        self.seg = seg; self.segp = segp
        self.refProteina = refProteina; self.refMineral = refMineral; self.refSlm = refSlm
        self.refPeso = refPeso; self.refIcw = refIcw; self.refEcw = refEcw
        self.pwt = pwt; self.psmm = psmm; self.pfat = pfat
        self.bmiMin = bmiMin; self.bmiMax = bmiMax; self.ibmi = ibmi
        self.ibmiRaw = ibmiRaw; self.bmiMax2 = bmiMax2
        self.pbfMin = pbfMin; self.pbfMax = pbfMax; self.ipbf = ipbf
        self.segAEC = segAEC; self.segFat = segFat; self.segFatP = segFatP
        self.inbodyScore = inbodyScore
        self.pesoIdeal = pesoIdeal; self.controlePeso = controlePeso
        self.controleGordura = controleGordura; self.controleMuscular = controleMuscular
        self.bcm = bcm; self.smi = smi; self.ingestaoCalorica = ingestaoCalorica; self.anguloFase = anguloFase
        self.impedancia = impedancia
        self.segWater = segWater; self.segWaterP = segWaterP; self.circunferencias = circunferencias
        self.grauObesidadeInfantil = grauObesidadeInfantil
        self.altura = altura
        self.segpIdeal = segpIdeal; self.etype2 = etype2; self.totScore = totScore
        self.odMin = odMin; self.odMax = odMax; self.metabolicAge = metabolicAge
        self.bmc = bmc; self.ffmi = ffmi; self.bfmi = bfmi; self.fmi = fmi
        self.tbwFfm = tbwFfm; self.wed = wed
        self.refBmr = refBmr; self.refRcq = refRcq; self.refBcm = refBcm; self.refSmi = refSmi
        self.growthPattern = growthPattern
        self.segMin = segMin; self.segMax = segMax
        self.qrPayload = qrPayload
        self.equip = equip; self.etype3 = etype3
    }
}

/// Leitura de pressão arterial (do monitor ou inserida por Edit). manual p.61-62.
struct LeituraPressao: Identifiable, Hashable {
    let id = UUID()
    var data: String       // "yyyy/MM/dd HH:mm"
    var sistolica: Int
    var diastolica: Int
}

/// Leitura de glicemia (inserida por Edit). manual p.63-64.
struct LeituraGlicose: Identifiable, Hashable {
    let id = UUID()
    var data: String       // "yyyy/MM/dd HH:mm"
    var jejum: Int?        // Fasting Blood Glucose (mg/dL)
    var posPrandial: Int?  // Blood Glucose 2 Hours after a Meal (mg/dL)
}

struct Paciente: Identifiable, Hashable {
    var id: String                 // USER_ID (chave de negocio, visivel); PODE repetir e ser reatribuido na fusao
    var localId: String = ""       // LOCAL_ID do banco (chave interna; "" = ainda nao persistido)

    /// Chave ÚNICA por paciente para lista/seleção. USER_ID pode repetir no banco; LOCAL_ID não.
    var chave: String { localId.isEmpty ? "u:" + id : "l:" + localId }
    var nome: String
    var sexo: String
    var idade: Int
    var altura: Double
    var exames: [Medida]
    // campos usados por busca (Mobile/Medical history/Group) e por Edit
    var celular: String = ""
    var historico: String = ""
    var grupo: String = ""
    var email: String = ""
    var nascimento: String = ""   // "yyyy/MM/dd"
    var registro: String = ""     // Registration Date
    // leituras não-InBody (alimentam os Health Reports de pressão/glicose)
    var pressoes: [LeituraPressao] = []
    var glicoses: [LeituraGlicose] = []

    var ultimo: Medida? { exames.first }
    var ultimaPressao: LeituraPressao? { pressoes.sorted { $0.data > $1.data }.first }
    var ultimaGlicose: LeituraGlicose? { glicoses.sorted { $0.data > $1.data }.first }
    var iniciais: String {
        nome.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }
}

// Pacientes-demo. Cada um é um `static let` separado (e os dicionários pesados são içados)
// para o type-checker do Swift não estourar em uma única expressão gigante.
enum DemoData {

    // Impedância Z(Ω) plausível (cresce com a queda de frequência; braços > pernas > tronco).
    private static let anaImp: [String: [Int: Double]] = [
        "RA": [1: 405, 5: 395, 50: 340, 250: 310, 500: 300, 1000: 290],
        "LA": [1: 410, 5: 400, 50: 345, 250: 315, 500: 305, 1000: 295],
        "TR": [1: 26.0, 5: 25.0, 50: 22.0, 250: 20.5, 500: 20.0, 1000: 19.5],
        "RL": [1: 285, 5: 278, 50: 245, 250: 225, 500: 218, 1000: 210],
        "LL": [1: 288, 5: 281, 50: 248, 250: 228, 500: 221, 1000: 213],
    ]
    private static let isisImp: [String: [Int: Double]] = [
        "RA": [1: 470, 5: 458, 50: 398, 250: 362, 500: 350, 1000: 338],
        "LA": [1: 476, 5: 464, 50: 403, 250: 367, 500: 355, 1000: 343],
        "TR": [1: 30.5, 5: 29.2, 50: 25.8, 250: 24.0, 500: 23.4, 1000: 22.8],
        "RL": [1: 335, 5: 327, 50: 288, 250: 265, 500: 257, 1000: 248],
        "LL": [1: 338, 5: 330, 50: 291, 250: 268, 500: 260, 1000: 251],
    ]

    static let ana = Paciente(
        id: "030826-1", nome: "Ana Ribeiro Costa", sexo: "F", idade: 34, altura: 165, exames: [
            Medida(data: "2026/08/03 16:28", peso: 61.4, tbw: 33.1, icw: 20.4, ecw: 12.7,
                   proteina: 8.9, mineral: 3.1, gordura: 16.3, ffm: 45.1, slm: 42.8,
                   smm: 25.2, imc: 22.6, pgc: 26.5, rcq: 0.82, tmb: 1364, gv: 78, ecwTbw: 0.384,
                   refTbw: Referencia(lo: 29.6, hi: 36.2), refGordura: Referencia(lo: 10.9, hi: 17.5),
                   refFfm: Referencia(lo: 40.2, hi: 49.1), refSmm: Referencia(lo: 22.1, hi: 27.0),
                   seg: ["RA": 2.11, "LA": 2.04, "TR": 19.8, "RL": 6.92, "LL": 6.85],
                   segp: ["RA": 98, "LA": 95, "TR": 101, "RL": 99, "LL": 98],
                   refProteina: Referencia(lo: 7.4, hi: 9.0), refMineral: Referencia(lo: 2.61, hi: 3.19),
                   refSlm: Referencia(lo: 38.2, hi: 46.7), refPeso: Referencia(lo: 50.4, hi: 68.2),
                   refIcw: Referencia(lo: 18.3, hi: 22.3), refEcw: Referencia(lo: 11.2, hi: 13.7),
                   pwt: 105, psmm: 103, pfat: 115,
                   bmiMin: 18.5, bmiMax: 25.0, ibmi: 21.5, pbfMin: 18.0, pbfMax: 28.0, ipbf: 22.5,
                   segAEC: ["RA": 0.383, "LA": 0.384, "TR": 0.385, "RL": 0.382, "LL": 0.383],
                   segFat: ["RA": 0.6, "LA": 0.6, "TR": 8.5, "RL": 1.8, "LL": 1.8],
                   segFatP: ["RA": 95, "LA": 97, "TR": 112, "RL": 103, "LL": 102],
                   inbodyScore: 80,
                   pesoIdeal: 59.3, controlePeso: -2.1, controleGordura: -2.1, controleMuscular: 0.0,
                   bcm: 30.8, smi: 6.9, ingestaoCalorica: 2050, anguloFase: 5.8,
                   impedancia: anaImp,
                   segWater: ["RA": 1.90, "LA": 1.85, "TR": 16.8, "RL": 6.30, "LL": 6.25],
                   segWaterP: ["RA": 98, "LA": 96, "TR": 101, "RL": 99, "LL": 98],
                   circunferencias: ["cintura": 74.0, "quadril": 96.0, "braco": 27.0,
                                     "pescoco": 31.0, "torax": 88.0, "coxa": 52.0, "panturrilha": 35.0],
                   grauObesidadeInfantil: 0,
                   altura: 165,
                   segpIdeal: ["RA": 118, "LA": 122, "TR": 130, "RL": 112, "LL": 114],
                   etype2: "000000000000",
                   odMin: 85, odMax: 115,
                   metabolicAge: 30,
                   bmc: 2.55,
                   ffmi: 16.6, bfmi: 6.0, fmi: 6.0,
                   tbwFfm: 0.734, wed: 0.384,
                   refBmr: Referencia(lo: 1320, hi: 1480),
                   refRcq: Referencia(lo: 0.80, hi: 0.90),
                   refBcm: Referencia(lo: 28, hi: 35),
                   refSmi: Referencia(lo: 5.5, hi: 7.5),
                   segMin: ["RA": 1.79, "LA": 1.79, "TR": 16.8, "RL": 5.88, "LL": 5.88],
                   segMax: ["RA": 2.43, "LA": 2.43, "TR": 22.8, "RL": 7.96, "LL": 7.96],
                   qrPayload: "InBody770|030826-1|2026/08/03 16:28"),
            Medida(data: "2026/05/12 09:14", peso: 63.2, tbw: 32.4, icw: 19.8, ecw: 12.6,
                   proteina: 8.6, mineral: 3.0, gordura: 19.2, ffm: 44.0, slm: 41.6,
                   smm: 24.4, imc: 23.2, pgc: 30.4, rcq: 0.85, tmb: 1332, gv: 92, ecwTbw: 0.389,
                   refTbw: Referencia(lo: 29.6, hi: 36.2), refGordura: Referencia(lo: 10.9, hi: 17.5),
                   refFfm: Referencia(lo: 40.2, hi: 49.1), refSmm: Referencia(lo: 22.1, hi: 27.0),
                   seg: ["RA": 2.02, "LA": 1.96, "TR": 19.1, "RL": 6.71, "LL": 6.64],
                   segp: ["RA": 94, "LA": 91, "TR": 97, "RL": 96, "LL": 95], altura: 165),
            Medida(data: "2026/02/20 10:02", peso: 65.1, tbw: 32.0, icw: 19.4, ecw: 12.6,
                   proteina: 8.4, mineral: 2.9, gordura: 21.8, ffm: 43.3, slm: 40.9,
                   smm: 23.9, imc: 23.9, pgc: 33.5, rcq: 0.88, tmb: 1310, gv: 104, ecwTbw: 0.394,
                   refTbw: Referencia(lo: 29.6, hi: 36.2), refGordura: Referencia(lo: 10.9, hi: 17.5),
                   refFfm: Referencia(lo: 40.2, hi: 49.1), refSmm: Referencia(lo: 22.1, hi: 27.0),
                   seg: ["RA": 1.95, "LA": 1.90, "TR": 18.7, "RL": 6.55, "LL": 6.48],
                   segp: ["RA": 91, "LA": 88, "TR": 94, "RL": 93, "LL": 92], altura: 165),
        ], celular: "(11) 99876-1122", email: "ana.rc@email.com", nascimento: "1992/03/14",
        pressoes: [
            LeituraPressao(data: "2026/08/03 16:30", sistolica: 118, diastolica: 76),
            LeituraPressao(data: "2026/05/12 09:16", sistolica: 124, diastolica: 80),
            LeituraPressao(data: "2026/02/20 10:05", sistolica: 129, diastolica: 83),
        ],
        glicoses: [
            LeituraGlicose(data: "2026/08/03 16:30", jejum: 92, posPrandial: 118),
            LeituraGlicose(data: "2026/05/12 09:16", jejum: 97, posPrandial: 131),
        ])

    static let carlos = Paciente(
        id: "030826-2", nome: "Carlos Meneghetti", sexo: "M", idade: 47, altura: 178, exames: [
            Medida(data: "2026/08/03 14:51", peso: 88.2, tbw: 47.9, icw: 29.8, ecw: 18.1,
                   proteina: 12.9, mineral: 4.4, gordura: 23.0, ffm: 65.2, slm: 61.5,
                   smm: 37.6, imc: 27.8, pgc: 26.1, rcq: 0.94, tmb: 1764, gv: 112, ecwTbw: 0.378,
                   refTbw: Referencia(lo: 44.3, hi: 54.1), refGordura: Referencia(lo: 10.6, hi: 17.0),
                   refFfm: Referencia(lo: 60.1, hi: 73.4), refSmm: Referencia(lo: 34.9, hi: 42.6),
                   seg: ["RA": 3.62, "LA": 3.55, "TR": 28.4, "RL": 10.2, "LL": 10.1],
                   segp: ["RA": 103, "LA": 101, "TR": 99, "RL": 97, "LL": 96]),
        ], celular: "(11) 98123-4567", email: "carlos.m@email.com", nascimento: "1979/06/02",
        pressoes: [LeituraPressao(data: "2026/08/03 14:53", sistolica: 142, diastolica: 91)],
        glicoses: [LeituraGlicose(data: "2026/08/03 14:53", jejum: 108, posPrandial: 152)])

    static let juliana = Paciente(
        id: "020826-4", nome: "Juliana Prado", sexo: "F", idade: 29, altura: 171, exames: [
            Medida(data: "2026/08/02 08:33", peso: 58.9, tbw: 33.8, icw: 21.1, ecw: 12.7,
                   proteina: 9.1, mineral: 3.2, gordura: 12.8, ffm: 46.1, slm: 43.6,
                   smm: 26.3, imc: 20.1, pgc: 21.7, rcq: 0.78, tmb: 1402, gv: 54, ecwTbw: 0.376,
                   refTbw: Referencia(lo: 31.4, hi: 38.4), refGordura: Referencia(lo: 11.6, hi: 18.6),
                   refFfm: Referencia(lo: 42.7, hi: 52.2), refSmm: Referencia(lo: 23.5, hi: 28.7),
                   seg: ["RA": 2.28, "LA": 2.25, "TR": 20.4, "RL": 7.31, "LL": 7.28],
                   segp: ["RA": 106, "LA": 105, "TR": 104, "RL": 103, "LL": 103]),
        ])

    static let roberto = Paciente(
        id: "300726-7", nome: "Roberto Sanches", sexo: "M", idade: 62, altura: 172, exames: [
            Medida(data: "2026/07/30 16:05", peso: 79.4, tbw: 41.2, icw: 25.1, ecw: 16.1,
                   proteina: 11.0, mineral: 3.8, gordura: 23.4, ffm: 56.0, slm: 52.9,
                   smm: 31.8, imc: 26.8, pgc: 29.5, rcq: 0.98, tmb: 1583, gv: 118, ecwTbw: 0.391,
                   refTbw: Referencia(lo: 40.1, hi: 49.1), refGordura: Referencia(lo: 9.5, hi: 15.3),
                   refFfm: Referencia(lo: 54.4, hi: 66.5), refSmm: Referencia(lo: 31.0, hi: 37.9),
                   seg: ["RA": 2.94, "LA": 2.88, "TR": 24.6, "RL": 8.51, "LL": 8.44],
                   segp: ["RA": 92, "LA": 90, "TR": 95, "RL": 89, "LL": 88]),
        ])

    // Paciente PEDIÁTRICA (menina 9 anos) — alimenta a folha InBody Children.
    static let isis = Paciente(
        id: "010826-9", nome: "Isis Almeida Prado", sexo: "F", idade: 9, altura: 138, exames: [
            Medida(data: "2026/07/28 10:12", peso: 32.0, tbw: 18.0, icw: 11.2, ecw: 6.8,
                   proteina: 4.9, mineral: 1.55, gordura: 7.4, ffm: 24.6, slm: 23.1,
                   smm: 11.8, imc: 16.8, pgc: 23.1, rcq: 0.80, tmb: 1048, gv: 30, ecwTbw: 0.378,
                   refTbw: Referencia(lo: 16.3, hi: 19.9), refGordura: Referencia(lo: 4.9, hi: 8.6),
                   refFfm: Referencia(lo: 22.3, hi: 27.3), refSmm: Referencia(lo: 10.4, hi: 12.7),
                   seg: ["RA": 0.72, "LA": 0.70, "TR": 10.1, "RL": 3.55, "LL": 3.50],
                   segp: ["RA": 101, "LA": 99, "TR": 102, "RL": 100, "LL": 99],
                   refProteina: Referencia(lo: 4.2, hi: 5.2), refMineral: Referencia(lo: 1.30, hi: 1.60),
                   refSlm: Referencia(lo: 20.6, hi: 25.2), refPeso: Referencia(lo: 27.5, hi: 37.2),
                   refIcw: Referencia(lo: 10.0, hi: 12.2), refEcw: Referencia(lo: 6.0, hi: 7.4),
                   pwt: 99, psmm: 102, pfat: 108,
                   bmiMin: 14.2, bmiMax: 18.5, ibmi: 16.0, pbfMin: 16.0, pbfMax: 26.0, ipbf: 20.5,
                   segAEC: ["RA": 0.377, "LA": 0.378, "TR": 0.379, "RL": 0.376, "LL": 0.377],
                   segFat: ["RA": 0.30, "LA": 0.32, "TR": 3.9, "RL": 1.05, "LL": 1.08],
                   segFatP: ["RA": 105, "LA": 108, "TR": 112, "RL": 100, "LL": 101],
                   inbodyScore: 88,
                   pesoIdeal: 31.2, controlePeso: -0.8, controleGordura: -0.8, controleMuscular: 0.0,
                   bcm: 15.9, smi: 4.6, ingestaoCalorica: 1570, anguloFase: 5.1,
                   impedancia: isisImp,
                   segWater: ["RA": 0.55, "LA": 0.53, "TR": 9.1, "RL": 3.42, "LL": 3.40],
                   segWaterP: ["RA": 101, "LA": 99, "TR": 102, "RL": 100, "LL": 99],
                   circunferencias: ["cintura": 58.0, "quadril": 68.0, "braco": 18.5,
                                     "pescoco": 27.0, "torax": 62.0, "coxa": 36.0, "panturrilha": 27.0],
                   grauObesidadeInfantil: 105,
                   altura: 138,
                   segpIdeal: ["RA": 108, "LA": 110, "TR": 118, "RL": 104, "LL": 105],
                   etype2: "000000000000",
                   totScore: 88,
                   odMin: 90, odMax: 110,
                   metabolicAge: 9,
                   bmc: 1.20,
                   ffmi: 12.9, bfmi: 3.9, fmi: 3.9,
                   tbwFfm: 0.732, wed: 0.378,
                   refBmr: Referencia(lo: 1000, hi: 1120),
                   refRcq: Referencia(lo: 0.75, hi: 0.85),
                   refBcm: Referencia(lo: 14, hi: 18),
                   refSmi: Referencia(lo: 3.8, hi: 5.2),
                   segMin: ["RA": 0.61, "LA": 0.61, "TR": 8.6, "RL": 3.02, "LL": 3.02],
                   segMax: ["RA": 0.83, "LA": 0.83, "TR": 11.6, "RL": 4.08, "LL": 4.08],
                   qrPayload: "InBody770|010826-9|2026/07/28 10:12"),
            Medida(data: "2025/09/15 09:40", peso: 29.8, tbw: 16.9, icw: 10.5, ecw: 6.4,
                   proteina: 4.6, mineral: 1.45, gordura: 6.9, ffm: 22.9, slm: 21.6,
                   smm: 11.0, imc: 16.6, pgc: 23.2, rcq: 0.80, tmb: 995, gv: 28, ecwTbw: 0.379,
                   refTbw: Referencia(lo: 15.5, hi: 18.9), refGordura: Referencia(lo: 4.6, hi: 8.1),
                   refFfm: Referencia(lo: 21.1, hi: 25.8), refSmm: Referencia(lo: 9.7, hi: 11.9),
                   seg: ["RA": 0.66, "LA": 0.65, "TR": 9.5, "RL": 3.31, "LL": 3.27],
                   segp: ["RA": 99, "LA": 98, "TR": 100, "RL": 99, "LL": 98], altura: 135),
            Medida(data: "2025/02/10 11:05", peso: 27.5, tbw: 15.7, icw: 9.7, ecw: 6.0,
                   proteina: 4.3, mineral: 1.36, gordura: 6.2, ffm: 21.3, slm: 20.1,
                   smm: 10.1, imc: 16.3, pgc: 22.5, rcq: 0.80, tmb: 942, gv: 26, ecwTbw: 0.382,
                   refTbw: Referencia(lo: 14.6, hi: 17.8), refGordura: Referencia(lo: 4.3, hi: 7.6),
                   refFfm: Referencia(lo: 19.8, hi: 24.2), refSmm: Referencia(lo: 9.0, hi: 11.0),
                   seg: ["RA": 0.60, "LA": 0.59, "TR": 8.9, "RL": 3.08, "LL": 3.05],
                   segp: ["RA": 98, "LA": 97, "TR": 99, "RL": 98, "LL": 97], altura: 132),
        ], celular: "(11) 99123-0099", email: "isis@email.com", nascimento: "2016/10/20")

    static let pacientes: [Paciente] = [ana, carlos, juliana, roberto, isis]
    /// Paciente pediátrica-referência (folha InBody Children).
    static let pediatrica: Paciente = isis
}
