import Foundation

/// Configuracao REAL da clinica, lida do settings.xml do LookinBody (E10). O arquivo e
/// uma lista de <entry name="CHAVE">valor</entry>. O app ja lia DATE/TIME_FORMAT p/ as
/// folhas (SheetSettings); aqui le o resto (idioma, pais, unidade, impressora, rodape de
/// assistencia) para o app refletir a clinica, nunca valores chumbados.
struct ConfigClinica {
    var lang = "BR"
    var countryCode = "55"
    var unidadeMetrica = true          // UNIT: 0 = metrico (kg/cm), 1 = imperial
    var dateFormat = "dd.MM.yyyy."
    var timeFormat = "HH:mm:ss"
    var impressora = ""
    var centroServicoNome = ""
    var centroServicoTel = ""
    var centroServicoEndereco = ""
    var centroServicoWeb = ""
    var autoUpdate = true

    /// Todas as entradas cruas (p/ telas de Setup que queiram um valor especifico).
    var entradas: [String: String] = [:]

    /// Le o settings.xml de um diretorio (o mesmo do .mdb). Ausente -> defaults.
    static func carregar(dir: String) -> ConfigClinica {
        let caminho = dir + "/settings.xml"
        guard let xml = try? String(contentsOfFile: caminho, encoding: .utf8) else { return ConfigClinica() }
        return carregar(xml: xml)
    }

    static func carregar(xml: String) -> ConfigClinica {
        var c = ConfigClinica()
        c.entradas = entradasDe(xml)
        func v(_ k: String) -> String? { c.entradas[k] }
        if let x = v("LANG"), !x.isEmpty { c.lang = x }
        if let x = v("COUNTRY_CODE"), !x.isEmpty { c.countryCode = x }
        if let x = v("UNIT") { c.unidadeMetrica = (x.trimmingCharacters(in: .whitespaces) == "0") }
        if let x = v("DATE_FORMAT"), !x.isEmpty { c.dateFormat = x }
        if let x = v("TIME_FORMAT"), !x.isEmpty { c.timeFormat = x }
        if let x = v("PRINTER_NAME") { c.impressora = x }
        if let x = v("SERVICE_CENTER_NAME") { c.centroServicoNome = x }
        if let x = v("SERVICE_CENTER_TEL") { c.centroServicoTel = x }
        if let x = v("SERVICE_CENTER_ADDRESS") { c.centroServicoEndereco = x }
        if let x = v("SERVICE_CENTER_WEB") { c.centroServicoWeb = x }
        if let x = v("AUTO_UPDATE") { c.autoUpdate = (x.uppercased() == "Y") }
        return c
    }

    /// Extrai <entry name="K">V</entry> (V pode ter espacos/quebras; entidades XML basicas).
    static func entradasDe(_ xml: String) -> [String: String] {
        var out: [String: String] = [:]
        let regex = try? NSRegularExpression(
            pattern: "<entry name=\"([^\"]+)\">(.*?)</entry>", options: [.dotMatchesLineSeparators])
        let ns = xml as NSString
        regex?.enumerateMatches(in: xml, range: NSRange(location: 0, length: ns.length)) { m, _, _ in
            guard let m, m.numberOfRanges == 3 else { return }
            let k = ns.substring(with: m.range(at: 1))
            let raw = ns.substring(with: m.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
            out[k] = raw
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
        }
        return out
    }
}
