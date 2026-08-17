import Foundation

/// Cadastro em massa por planilha (E7). Colunas do original (SetupImportGroupRegistration
/// / InsertUserData): USER_ID, NAME, GENDER, AGE, HEIGHT, BIRTHDAY, TEL_HP, ADDR, E_MAIL.
/// O original entrega um .xls; aqui a planilha e CSV (o Excel abre e salva CSV), sem perder
/// nenhuma coluna do fluxo original. Cada linha valida vira um paciente via store.cadastrar.
enum CadastroEmMassa {

    static let colunas = ["USER_ID", "NAME", "GENDER", "AGE", "HEIGHT", "BIRTHDAY",
                          "TEL_HP", "ADDR", "E_MAIL", "GRUPO"]

    /// Modelo p/ o medico preencher (cabecalho + 1 linha de exemplo).
    static func modelo() -> String {
        let exemplo = ["000001", "Nome do Paciente", "M", "40", "175", "1985/03/14",
                       "(11) 99999-0000", "Rua Exemplo, 100", "email@exemplo.com", ""]
        return colunas.joined(separator: ",") + "\n" + exemplo.joined(separator: ",") + "\n"
    }

    struct Resultado {
        let adicionados: Int
        let ignorados: [String]   // "linha N: motivo"
        var aviso: String {
            ignorados.isEmpty ? "Importados \(adicionados) pacientes."
                              : "Importados \(adicionados); \(ignorados.count) linha(s) ignorada(s)."
        }
    }

    /// Importa um CSV. Valida cada linha (NAME e HEIGHT obrigatorios, GENDER M/F, USER_ID
    /// unico) e cadastra as validas. As invalidas entram em `ignorados` com o motivo.
    @MainActor
    static func importar(csv texto: String, store: Store) -> Resultado {
        let linhas = parseCSV(texto)
        guard let header = linhas.first else { return Resultado(adicionados: 0, ignorados: ["planilha vazia"]) }
        let idx = Dictionary(uniqueKeysWithValues: header.enumerated().map { ($1.uppercased(), $0) })
        func campo(_ vals: [String], _ nome: String) -> String {
            guard let i = idx[nome], i < vals.count else { return "" }
            return vals[i].trimmingCharacters(in: .whitespaces)
        }
        var adicionados = 0
        var ignorados: [String] = []
        var idsVistos = Set(store.pacientes.map { $0.id })
        for (n, vals) in linhas.dropFirst().enumerated() {
            let linhaN = n + 2   // 1-based + cabecalho
            let nome = campo(vals, "NAME")
            let sexo = campo(vals, "GENDER").uppercased()
            let altura = Double(campo(vals, "HEIGHT").replacingOccurrences(of: ",", with: "."))
            guard !nome.isEmpty else { ignorados.append("linha \(linhaN): sem nome"); continue }
            guard sexo == "M" || sexo == "F" else { ignorados.append("linha \(linhaN): sexo invalido"); continue }
            guard let alt = altura, alt > 0 else { ignorados.append("linha \(linhaN): altura invalida"); continue }
            var id = campo(vals, "USER_ID")
            if id.isEmpty { id = "\(linhaN)-\(Int(Date().timeIntervalSince1970))" }
            guard !idsVistos.contains(id) else { ignorados.append("linha \(linhaN): ID \(id) ja existe"); continue }
            idsVistos.insert(id)
            let nasc = campo(vals, "BIRTHDAY")
            var p = Paciente(id: id, nome: nome, sexo: sexo,
                             idade: Int(campo(vals, "AGE")) ?? idadeDe(nasc), altura: alt, exames: [])
            p.celular = campo(vals, "TEL_HP")
            p.email = campo(vals, "E_MAIL")
            p.nascimento = nasc
            p.grupo = campo(vals, "GRUPO")
            store.cadastrar(p)
            adicionados += 1
        }
        return Resultado(adicionados: adicionados, ignorados: ignorados)
    }

    /// Idade a partir de "yyyy/MM/dd" ou "yyyy-MM-dd" (0 se nao der p/ calcular).
    static func idadeDe(_ nasc: String) -> Int {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
        for fmt in ["yyyy/MM/dd", "yyyy-MM-dd", "yyyy/MM", "yyyy"] {
            f.dateFormat = fmt
            if let d = f.date(from: nasc) {
                return Calendar.current.dateComponents([.year], from: d, to: Date()).year ?? 0
            }
        }
        return 0
    }

    /// Parser CSV minimo (aspas, virgula, "" escapado, \r\n/\r/\n).
    static func parseCSV(_ bruto: String) -> [[String]] {
        let texto = bruto.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        var linhas: [[String]] = []
        var campo = "", linha: [String] = [], aspas = false
        var it = texto.makeIterator(); var pend: Character? = nil
        func prox() -> Character? { if let p = pend { pend = nil; return p }; return it.next() }
        while let c = prox() {
            if aspas {
                if c == "\"" {
                    if let nx = it.next() { if nx == "\"" { campo.append("\"") } else { aspas = false; pend = nx } }
                    else { aspas = false }
                } else { campo.append(c) }
            } else {
                switch c {
                case "\"": aspas = true
                case ",": linha.append(campo); campo = ""
                case "\n": linha.append(campo); campo = ""; linhas.append(linha); linha = []
                default: campo.append(c)
                }
            }
        }
        if !campo.isEmpty || !linha.isEmpty { linha.append(campo); linhas.append(linha) }
        return linhas.filter { !($0.count == 1 && $0[0].isEmpty) }
    }
}
