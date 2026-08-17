import Foundation

/// Verificador de atualizacao (E11). O app e um clone, entao a distribuicao/atualizacao
/// sai por um repositorio (ex.: GitHub Releases): publicar a release e do Giba; aqui fica
/// o CONSUMIDOR, que le a ultima versao publicada e compara com a instalada.
/// A URL do repo e configuravel (definida quando o repo existir). A logica de comparacao
/// e universal e provada offline.
enum AtualizacaoService {

    /// Versao instalada deste app (semver). Sobe a cada release.
    static let versaoApp = "1.0.0"

    /// `disponivel` e mais nova que `atual`? Compara numeros separados por ponto
    /// ("1.2.0" > "1.1.9"); ignora sufixos nao-numericos (ex.: "-beta", "v" no inicio).
    static func maisNova(disponivel: String, que atual: String) -> Bool {
        func partes(_ s: String) -> [Int] {
            s.drop(while: { !$0.isNumber })                 // tira "v" inicial
             .split(whereSeparator: { !$0.isNumber && $0 != "." })
             .first.map(String.init)?                        // pega o nucleo "x.y.z" antes de "-beta"
             .split(separator: ".").map { Int($0) ?? 0 } ?? []
        }
        let a = partes(disponivel), b = partes(atual)
        let n = max(a.count, b.count)
        for i in 0..<n {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false   // iguais -> nao ha novidade
    }

    struct Release { let versao: String; let url: String }

    /// Le a ultima release de um endpoint estilo GitHub Releases (JSON com `tag_name` e
    /// `html_url`). Devolve nil se nao houver update ou em falha de rede.
    static func verificar(endpoint: String) async -> Release? {
        guard let url = URL(string: endpoint),
              let (data, resp) = try? await URLSession.shared.data(from: url),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String else { return nil }
        let link = (json["html_url"] as? String) ?? endpoint
        return maisNova(disponivel: tag, que: versaoApp) ? Release(versao: tag, url: link) : nil
    }
}
