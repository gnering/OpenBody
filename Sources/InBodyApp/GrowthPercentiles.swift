import Foundation

/// Curvas de crescimento WHO2007 (padrão brasileiro) usadas pela folha pediátrica.
///
/// Fonte: `.exe-reference/specs/LBPC.InBody.Print.BaseCommon.Properties.ResGrowth.resx`,
/// chaves `{HT|WT}_WHO2007_{M|F}_{idade}`, valores separados por `;`.
/// Cada linha traz 5 percentis, nesta ordem: P3, P15, P50, P85, P97
/// (WHO2007 usa 3/15/50/85/97 — NÃO 10/25/50/75/90).
///
/// Cobertura do recurso original:
/// - Altura (HT): idades 3..18.
/// - Peso (WT): idades 3..10 (WHO2007 não publica peso-para-idade acima de 10 anos;
///   as idades 11..18 vêm zeradas no .resx e são tratadas como ausentes aqui).
enum GrowthMetric: String {
    case height = "HT"
    case weight = "WT"
}

enum GrowthPercentiles {
    /// Percentis representados, na ordem dos 5 valores de cada linha.
    static let percentis: [Int] = [3, 15, 50, 85, 97]

    /// Faixa etária coberta pelas curvas.
    static let idadeMin = 3
    static let idadeMax = 18

    /// Percentis para (sexo "M"/"F", métrica, idade em anos) -> [P3, P15, P50, P85, P97].
    /// Retorna `nil` quando não há dado (idade fora da faixa, ou peso acima de 10 anos).
    static func valores(sexo: String, metrica: GrowthMetric, idade: Int) -> [Double]? {
        let s = sexo.uppercased().hasPrefix("M") ? "M" : "F"
        guard let linha = tabela["\(metrica.rawValue)_\(s)_\(idade)"],
              linha.contains(where: { $0 > 0 }) else { return nil }
        return linha
    }

    /// Tabela completa: chave "HT_F_9" etc. -> 5 percentis (WHO2007).
    /// Montada a partir de 4 blocos p/ não estourar o type-checker do Swift.
    static let tabela: [String: [Double]] = {
        var t: [String: [Double]] = [:]
        for (k, v) in htFeminino { t[k] = v }
        for (k, v) in htMasculino { t[k] = v }
        for (k, v) in wtFeminino { t[k] = v }
        for (k, v) in wtMasculino { t[k] = v }
        return t
    }()

    // ---- Altura (cm) — feminino ----
    private static let htFeminino: [String: [Double]] = [
        "HT_F_3":  [87.9, 91.1, 95.1, 99.0, 102.2],
        "HT_F_4":  [94.6, 98.3, 102.7, 107.2, 110.8],
        "HT_F_5":  [100.5, 104.5, 109.4, 114.4, 118.4],
        "HT_F_6":  [105.5, 109.8, 115.1, 120.4, 124.8],
        "HT_F_7":  [110.5, 115.2, 120.8, 126.5, 131.1],
        "HT_F_8":  [115.7, 120.6, 126.6, 132.6, 137.5],
        "HT_F_9":  [121.0, 126.2, 132.5, 138.8, 144.0],
        "HT_F_10": [126.6, 132.0, 138.6, 145.3, 150.7],
        "HT_F_11": [132.5, 138.1, 145.0, 151.9, 157.5],
        "HT_F_12": [138.4, 144.1, 151.2, 158.3, 164.1],
        "HT_F_13": [143.3, 149.2, 156.4, 163.6, 169.4],
        "HT_F_14": [146.7, 152.6, 159.8, 167.0, 172.9],
        "HT_F_15": [148.7, 154.5, 161.7, 168.8, 174.6],
        "HT_F_16": [149.8, 155.5, 162.5, 169.6, 175.3],
        "HT_F_17": [150.3, 155.9, 162.9, 169.8, 175.4],
        "HT_F_18": [150.6, 156.2, 163.1, 169.9, 175.5],
    ]

    // ---- Altura (cm) — masculino ----
    private static let htMasculino: [String: [Double]] = [
        "HT_M_3":  [89.1, 92.2, 96.1, 99.9, 103.1],
        "HT_M_4":  [95.4, 99.0, 103.3, 107.7, 111.2],
        "HT_M_5":  [101.2, 105.2, 110.0, 114.8, 118.7],
        "HT_M_6":  [106.7, 110.8, 116.0, 121.1, 125.2],
        "HT_M_7":  [111.8, 116.3, 121.7, 127.2, 131.7],
        "HT_M_8":  [116.6, 121.4, 127.3, 133.1, 137.9],
        "HT_M_9":  [121.3, 126.3, 132.6, 138.8, 143.9],
        "HT_M_10": [125.8, 131.2, 137.8, 144.4, 149.8],
        "HT_M_11": [130.5, 136.1, 143.1, 150.1, 155.8],
        "HT_M_12": [135.8, 141.7, 149.1, 156.4, 162.4],
        "HT_M_13": [142.1, 148.3, 156.0, 163.7, 170.0],
        "HT_M_14": [148.7, 155.2, 163.2, 171.2, 177.7],
        "HT_M_15": [154.3, 160.9, 169.0, 177.0, 183.6],
        "HT_M_16": [158.3, 164.8, 172.9, 181.0, 187.5],
        "HT_M_17": [160.8, 167.2, 175.2, 183.1, 189.5],
        "HT_M_18": [162.1, 168.4, 176.2, 183.9, 190.2],
    ]

    // ---- Peso (kg) — feminino (WHO2007 só até 10 anos) ----
    private static let wtFeminino: [String: [Double]] = [
        "WT_F_3":  [11.0, 12.1, 13.9, 15.9, 17.8],
        "WT_F_4":  [12.5, 14.0, 16.1, 18.6, 21.1],
        "WT_F_5":  [14.0, 15.7, 18.2, 21.3, 24.4],
        "WT_F_6":  [15.5, 17.4, 20.2, 23.7, 27.3],
        "WT_F_7":  [17.0, 19.2, 22.4, 26.5, 30.8],
        "WT_F_8":  [18.9, 21.3, 25.0, 29.8, 34.9],
        "WT_F_9":  [21.1, 23.9, 28.2, 33.9, 40.0],
        "WT_F_10": [23.7, 26.9, 31.9, 38.5, 45.7],
        "WT_F_11": [0, 0, 0, 0, 0],
        "WT_F_12": [0, 0, 0, 0, 0],
        "WT_F_13": [0, 0, 0, 0, 0],
        "WT_F_14": [0, 0, 0, 0, 0],
        "WT_F_15": [0, 0, 0, 0, 0],
        "WT_F_16": [0, 0, 0, 0, 0],
        "WT_F_17": [0, 0, 0, 0, 0],
        "WT_F_18": [0, 0, 0, 0, 0],
    ]

    // ---- Peso (kg) — masculino (WHO2007 só até 10 anos) ----
    private static let wtMasculino: [String: [Double]] = [
        "WT_M_3":  [11.4, 12.7, 14.3, 16.3, 18.0],
        "WT_M_4":  [12.9, 14.3, 16.3, 18.7, 20.9],
        "WT_M_5":  [14.3, 16.0, 18.3, 21.1, 23.8],
        "WT_M_6":  [16.1, 17.9, 20.5, 23.6, 26.7],
        "WT_M_7":  [17.9, 19.9, 22.9, 26.5, 30.1],
        "WT_M_8":  [19.8, 22.0, 25.4, 29.7, 34.0],
        "WT_M_9":  [21.6, 24.2, 28.1, 33.2, 38.6],
        "WT_M_10": [23.6, 26.6, 31.2, 37.3, 43.9],
        "WT_M_11": [0, 0, 0, 0, 0],
        "WT_M_12": [0, 0, 0, 0, 0],
        "WT_M_13": [0, 0, 0, 0, 0],
        "WT_M_14": [0, 0, 0, 0, 0],
        "WT_M_15": [0, 0, 0, 0, 0],
        "WT_M_16": [0, 0, 0, 0, 0],
        "WT_M_17": [0, 0, 0, 0, 0],
        "WT_M_18": [0, 0, 0, 0, 0],
    ]
}
