import Foundation
import SQLite3
import InBodyKit

/// Camada de persistencia SQLite do app. Espelha 1:1 o esquema do banco de campo do
/// LookinBody (schema.sql, gerado) + extensoes nossas (schema_ext.sql). Fonte unica de
/// traducao coluna->Medida continua sendo ImportService.montarMedida.
///
/// @MainActor: exigencia do Swift 6 strict concurrency para o singleton mutavel; o Store
/// (que chama o Banco) ja e @MainActor, entao as chamadas ficam sincronas sem await.
@MainActor
final class Banco {
    /// Instancia de producao (banco em Application Support). Testes/provas usam init(caminho:).
    static let shared = Banco()

    /// Versao do esquema. Sobe a cada etapa que altera schema_ext.sql (contrato 4).
    /// v2 (E3): indices de busca. schema_ext e IF NOT EXISTS -> reaplicavel sem perder dados.
    static let versaoAtual: Int32 = 2

    // nonisolated(unsafe): usado so no MainActor; a anotacao libera o deinit nonisolated.
    private nonisolated(unsafe) let db: OpaquePointer?
    let caminho: String
    private var colunasCache: [String: [String]] = [:]
    private var notNullCache: [String: [String]] = [:]

    // sqlite quer saber se deve copiar o buffer do bind. TRANSIENT = copie (seguro p/ String).
    private static let TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    /// Tabelas de exame na ordem transacional do original (Secao 2 da spec): BCA e a cabeca.
    static let tabelasExame = ["BCA_TBL", "ED_TBL", "LB_TBL", "IMP_TBL", "MFA_TBL", "WC_TBL"]

    init(caminho: String = Banco.caminhoPadrao()) {
        self.caminho = caminho
        let dir = (caminho as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        var handle: OpaquePointer?
        if sqlite3_open(caminho, &handle) != SQLITE_OK {
            fatalError("Banco: nao abriu \(caminho): \(String(cString: sqlite3_errmsg(handle)))")
        }
        self.db = handle
        exec("PRAGMA journal_mode=WAL;")
        exec("PRAGMA foreign_keys=ON;")
        migrar()
    }

    static func caminhoPadrao() -> String {
        // Atalho de demo/teste: aponta o app para outro banco sem tocar no de producao.
        if let p = ProcessInfo.processInfo.environment["INBODY_DB"], !p.isEmpty { return p }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("InBodyMac/inbody.sqlite").path
    }

    deinit { if let db { sqlite3_close(db) } }

    // MARK: - Infra

    private func exec(_ sql: String) {
        var err: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &err) != SQLITE_OK, let err {
            FileHandle.standardError.write("[Banco] exec falhou: \(String(cString: err))\n".data(using: .utf8)!)
            sqlite3_free(err)
        }
    }

    private func recurso(_ nome: String) -> String {
        guard let url = Bundle.module.url(forResource: nome, withExtension: "sql"),
              let s = try? String(contentsOf: url, encoding: .utf8) else {
            fatalError("Banco: recurso \(nome).sql ausente no bundle")
        }
        return s
    }

    private func userVersion() -> Int32 {
        var stmt: OpaquePointer?
        var v: Int32 = 0
        if sqlite3_prepare_v2(db, "PRAGMA user_version;", -1, &stmt, nil) == SQLITE_OK,
           sqlite3_step(stmt) == SQLITE_ROW {
            v = sqlite3_column_int(stmt, 0)
        }
        sqlite3_finalize(stmt)
        return v
    }

    /// Colunas reais de uma tabela (cacheadas). Usado para so inserir colunas que existem.
    func colunasDe(_ tabela: String) -> [String] {
        if let c = colunasCache[tabela] { return c }
        carregarInfo(tabela)
        return colunasCache[tabela] ?? []
    }

    /// Colunas NOT NULL (menos a PK DATETIMES) — precisam de valor no INSERT ou a linha
    /// e silenciosamente ignorada. O quadro da balanca nao traz flags como IBSynk.
    private func colunasNotNull(_ tabela: String) -> [String] {
        if let c = notNullCache[tabela] { return c }
        carregarInfo(tabela)
        return notNullCache[tabela] ?? []
    }

    private func carregarInfo(_ tabela: String) {
        var cols: [String] = []
        var nn: [String] = []
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "PRAGMA table_info(\"\(tabela)\");", -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let nome = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
                cols.append(nome)
                if sqlite3_column_int(stmt, 3) == 1 && nome.uppercased() != "DATETIMES" { nn.append(nome) }
            }
        }
        sqlite3_finalize(stmt)
        colunasCache[tabela] = cols
        notNullCache[tabela] = nn
    }

    // MARK: - Migracao (contrato 4)

    /// Aplica schema+schema_ext em transacao e marca user_version. Idempotente: so aplica
    /// o que falta. O banco criado na E1 nunca e recriado; etapas futuras adicionam ramos.
    func migrar() {
        let v = userVersion()
        guard v < Banco.versaoAtual else { return }
        exec("BEGIN;")
        if v < 1 { exec(recurso("schema")) }
        // schema_ext e IF NOT EXISTS: reaplica com seguranca a cada subida de versao
        // (v2 acrescentou os indices de busca da E3, sem tocar nos dados existentes).
        exec(recurso("schema_ext"))
        exec("PRAGMA user_version=\(Banco.versaoAtual);")
        exec("COMMIT;")
    }

    // MARK: - Escrita

    /// INSERT dinamico: so as colunas presentes na linha E existentes na tabela. Bind tudo
    /// como TEXT (contrato 6). INSERT OR IGNORE torna o reimporte idempotente (contrato 7).
    private func inserir(_ tabela: String, _ linha: [String: String]) {
        let validas = Set(colunasDe(tabela))
        var completa = linha
        // preenche NOT NULL ausentes com "0" (booleanos = falso), senao INSERT OR IGNORE
        // descarta a linha em silencio (o quadro da balanca nao traz IBSynk/ViewHealthReport).
        for c in colunasNotNull(tabela) where completa[c] == nil { completa[c] = "0" }
        let itens = completa.filter { validas.contains($0.key) }.map { ($0.key, $0.value) }
        guard !itens.isEmpty else { return }
        let cols = itens.map { "\"\($0.0)\"" }.joined(separator: ",")
        let ph = itens.map { _ in "?" }.joined(separator: ",")
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "INSERT OR IGNORE INTO \"\(tabela)\" (\(cols)) VALUES (\(ph));", -1, &stmt, nil) == SQLITE_OK {
            for (i, item) in itens.enumerated() {
                sqlite3_bind_text(stmt, Int32(i + 1), item.1, -1, Banco.TRANSIENT)
            }
            if sqlite3_step(stmt) != SQLITE_DONE {
                FileHandle.standardError.write("[Banco] insert \(tabela) falhou: \(String(cString: sqlite3_errmsg(db)))\n".data(using: .utf8)!)
            }
        }
        sqlite3_finalize(stmt)
    }

    /// Proximo LOCAL_ID (imita o autonumber do Access): max numerico existente + 1.
    func proximoLocalId() -> String {
        var stmt: OpaquePointer?
        var mx = 0
        if sqlite3_prepare_v2(db, "SELECT MAX(CAST(LOCAL_ID AS INTEGER)) FROM USER_INFO1_TBL;", -1, &stmt, nil) == SQLITE_OK,
           sqlite3_step(stmt) == SQLITE_ROW {
            mx = Int(sqlite3_column_int(stmt, 0))
        }
        sqlite3_finalize(stmt)
        return String(mx + 1)
    }

    func salvarUsuario(_ linha: [String: String]) { inserir("USER_INFO1_TBL", linha) }

    /// Atualiza um cadastro existente (UPDATE por LOCAL_ID). So as colunas informadas —
    /// preserva as demais (ADDR/MEMO etc.). salvarUsuario e INSERT OR IGNORE e nao serviria
    /// para editar (a linha ja existe -> ignorada).
    func atualizarUsuario(_ linha: [String: String]) {
        guard let localId = linha["LOCAL_ID"], !localId.isEmpty else { return }
        let validas = Set(colunasDe("USER_INFO1_TBL"))
        let itens = linha.filter { validas.contains($0.key) && $0.key != "LOCAL_ID" }.map { ($0.key, $0.value) }
        guard !itens.isEmpty else { return }
        let sets = itens.map { "\"\($0.0)\"=?" }.joined(separator: ", ")
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "UPDATE USER_INFO1_TBL SET \(sets) WHERE LOCAL_ID=?;", -1, &stmt, nil) == SQLITE_OK {
            var i: Int32 = 1
            for item in itens { sqlite3_bind_text(stmt, i, item.1, -1, Banco.TRANSIENT); i += 1 }
            sqlite3_bind_text(stmt, i, localId, -1, Banco.TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }
    func salvarPressao(_ linha: [String: String]) { inserir("SPHYG_DATA_TBL", linha) }
    func salvarGlicose(_ linha: [String: String]) { inserir("BLOODSUGAR_TBL", linha) }

    /// Le um .mdb de campo inteiro para dentro do banco (mesmo desenho de
    /// ImportService.importar). O LOCAL_ID (autonumber do Access) de bancos de origens
    /// diferentes COLIDE, entao ele e REMAPEADO como no importarBackupSQLite: paciente
    /// ja presente (mesmo USER_ID+NAME+nascimento) reusa o cadastro; novo recebe
    /// proximoLocalId(). Exames/pressao/glicose seguem o mapa. Idempotente: exame com
    /// DATETIMES ja existente e ignorado. Devolve (cadastros novos, exames novos).
    @discardableResult
    func importarMDB(_ db: String) -> (usuarios: Int, exames: Int) {
        func chave(_ u: [String: String]) -> String {
            (u["USER_ID"] ?? "") + "|" + (u["NAME"] ?? "") + "|" + (u["BIRTHDAY"] ?? "")
        }
        // cadastros ja presentes localmente, por identidade
        var existentes: [String: String] = [:]
        for u in consultar("SELECT LOCAL_ID, USER_ID, NAME, BIRTHDAY FROM USER_INFO1_TBL") {
            existentes[chave(u)] = u["LOCAL_ID"]
        }
        var mapa: [String: String] = [:]   // LOCAL_ID do .mdb -> LOCAL_ID daqui
        var nU = 0
        for u in ImportService.exporta(db, "USER_INFO1_TBL") {
            let old = u["LOCAL_ID"] ?? ""
            let k = chave(u)
            if let ex = existentes[k] { mapa[old] = ex; continue }
            let novo = proximoLocalId()
            var linha = u; linha["LOCAL_ID"] = novo
            salvarUsuario(linha)
            existentes[k] = novo; mapa[old] = novo; nU += 1
        }
        func porData(_ t: String) -> [String: [String: String]] {
            Dictionary(ImportService.exporta(db, t).map { ($0["DATETIMES"] ?? "", $0) }, uniquingKeysWith: { a, _ in a })
        }
        let bca = ImportService.exporta(db, "BCA_TBL")
        let mfa = porData("MFA_TBL"), wc = porData("WC_TBL"), lb = porData("LB_TBL")
        let ed = porData("ED_TBL"), imp = porData("IMP_TBL")
        var nEx = 0
        for b in bca {
            let dt = b["DATETIMES"] ?? ""
            guard !dt.isEmpty, !existeExame(datetimes: dt) else { continue }
            var linha = b; linha["LOCAL_ID"] = mapa[b["LOCAL_ID"] ?? ""] ?? (b["LOCAL_ID"] ?? "")
            salvarExame(["BCA_TBL": linha, "MFA_TBL": mfa[dt] ?? [:], "WC_TBL": wc[dt] ?? [:],
                         "LB_TBL": lb[dt] ?? [:], "ED_TBL": ed[dt] ?? [:], "IMP_TBL": imp[dt] ?? [:]])
            nEx += 1
        }
        for s in ImportService.exporta(db, "SPHYG_DATA_TBL") {
            var r = s; r["LOCAL_ID"] = mapa[s["LOCAL_ID"] ?? ""] ?? (s["LOCAL_ID"] ?? ""); salvarPressao(r)
        }
        for g in ImportService.exporta(db, "BLOODSUGAR_TBL") {
            var r = g; r["LOCAL_ID"] = mapa[g["LOCAL_ID"] ?? ""] ?? (g["LOCAL_ID"] ?? ""); salvarGlicose(r)
        }
        return (nU, nEx)
    }

    /// Roda uma consulta e devolve TODAS as linhas como [coluna: valor] (NULL -> "").
    /// Usado pela importacao de backups da nuvem (le de um banco anexado com ATTACH).
    private func consultar(_ sql: String) -> [[String: String]] {
        var out: [[String: String]] = []
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            let n = sqlite3_column_count(stmt)
            while sqlite3_step(stmt) == SQLITE_ROW {
                var row: [String: String] = [:]
                for i in 0..<n {
                    let nome = String(cString: sqlite3_column_name(stmt, i))
                    row[nome] = sqlite3_column_text(stmt, i).map { String(cString: $0) } ?? ""
                }
                out.append(row)
            }
        }
        sqlite3_finalize(stmt)
        return out
    }

    /// Importa um backup .sqlite de OUTRA clinica para dentro do acervo unificado.
    /// O LOCAL_ID (autonumber interno) das duas clinicas colide, entao aqui ele e REMAPEADO
    /// para IDs novos; o USER_ID (a chave que a fusao usa) e preservado. Idempotente: paciente
    /// ja presente (mesmo USER_ID+NAME+nascimento) reusa o cadastro, e exame ja existente
    /// (mesmo DATETIMES) e ignorado. Devolve (cadastros novos, exames novos).
    @discardableResult
    func importarBackupSQLite(_ caminho: String) -> (usuarios: Int, exames: Int) {
        guard FileManager.default.fileExists(atPath: caminho), caminho != self.caminho else { return (0, 0) }
        let esc = caminho.replacingOccurrences(of: "'", with: "''")
        exec("ATTACH DATABASE '\(esc)' AS src;")
        defer { exec("DETACH DATABASE src;") }

        func chave(_ u: [String: String]) -> String {
            (u["USER_ID"] ?? "") + "|" + (u["NAME"] ?? "") + "|" + (u["BIRTHDAY"] ?? "")
        }
        // cadastros ja presentes localmente, por identidade
        var existentes: [String: String] = [:]
        for u in consultar("SELECT LOCAL_ID, USER_ID, NAME, BIRTHDAY FROM USER_INFO1_TBL") {
            existentes[chave(u)] = u["LOCAL_ID"]
        }
        var mapa: [String: String] = [:]   // LOCAL_ID do backup -> LOCAL_ID novo aqui
        var nU = 0
        for u in consultar("SELECT * FROM src.USER_INFO1_TBL") {
            let old = u["LOCAL_ID"] ?? ""
            let k = chave(u)
            if let ex = existentes[k] { mapa[old] = ex; continue }
            let novo = proximoLocalId()
            var linha = u; linha["LOCAL_ID"] = novo
            salvarUsuario(linha)
            existentes[k] = novo; mapa[old] = novo; nU += 1
        }
        var nE = 0
        for bca in consultar("SELECT * FROM src.BCA_TBL") {
            let dt = bca["DATETIMES"] ?? ""
            guard !dt.isEmpty, !existeExame(datetimes: dt) else { continue }
            var b = bca; b["LOCAL_ID"] = mapa[bca["LOCAL_ID"] ?? ""] ?? (bca["LOCAL_ID"] ?? "")
            var tabelas: [String: [String: String]] = ["BCA_TBL": b]
            for t in ["ED_TBL", "LB_TBL", "IMP_TBL", "MFA_TBL", "WC_TBL"] {
                if let r = consultar("SELECT * FROM src.\(t) WHERE DATETIMES='\(dt)'").first { tabelas[t] = r }
            }
            salvarExame(tabelas); nE += 1
        }
        for s in consultar("SELECT * FROM src.SPHYG_DATA_TBL") {
            var r = s; r["LOCAL_ID"] = mapa[s["LOCAL_ID"] ?? ""] ?? (s["LOCAL_ID"] ?? ""); salvarPressao(r)
        }
        for g in consultar("SELECT * FROM src.BLOODSUGAR_TBL") {
            var r = g; r["LOCAL_ID"] = mapa[g["LOCAL_ID"] ?? ""] ?? (g["LOCAL_ID"] ?? ""); salvarGlicose(r)
        }
        return (nU, nE)
    }

    /// Grava um exame nas 6 tabelas irmas, na ordem do original, tudo numa transacao
    /// (all-or-nothing, Secao 2 da spec). `tabelas` = {"BCA_TBL": {col:val}, ...}.
    func salvarExame(_ tabelas: [String: [String: String]]) {
        exec("BEGIN;")
        for t in Banco.tabelasExame {
            if let linha = tabelas[t] { inserir(t, linha) }
        }
        exec("COMMIT;")
    }

    // MARK: - Exclusao

    private func execBind(_ sql: String, _ valor: String) {
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, valor, -1, Banco.TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    /// Apaga um exame: BCA por DATETIMES + as 5 tabelas de detalhe por DATETIMES.
    func apagarExame(datetimes dt: String) {
        exec("BEGIN;")
        for t in Banco.tabelasExame { execBind("DELETE FROM \"\(t)\" WHERE DATETIMES=?;", dt) }
        exec("COMMIT;")
    }

    /// Renomeia um exame (edita data): reescreve DATETIMES nas 6 tabelas (a chave). E4.
    func renomearExame(de: String, para: String) {
        guard de != para, !existeExame(datetimes: para) else { return }
        exec("BEGIN;")
        for t in Banco.tabelasExame {
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, "UPDATE \"\(t)\" SET DATETIMES=? WHERE DATETIMES=?;", -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, para, -1, Banco.TRANSIENT)
                sqlite3_bind_text(stmt, 2, de, -1, Banco.TRANSIENT)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
        exec("COMMIT;")
    }

    /// Funde dois cadastros num so: move TODOS os exames e leituras de um LOCAL_ID para
    /// outro e apaga o cadastro antigo. Usado pela unificacao de pacientes de clinicas/
    /// balancas diferentes (FusaoPacientes.swift). UPDATE OR IGNORE pula colisoes (mesmo
    /// DATETIMES nos dois); o que sobrar sob o LOCAL_ID antigo cai no apagarUsuario final.
    func fundirUsuario(deLocalId de: String, paraLocalId para: String) {
        guard de != para, !de.isEmpty, !para.isEmpty else { return }
        exec("BEGIN;")
        for t in ["BCA_TBL", "SPHYG_DATA_TBL", "BLOODSUGAR_TBL", "USER_GROUP_TBL", "USER_SICK_TBL"] {
            guard colunasDe(t).contains("LOCAL_ID") else { continue }
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, "UPDATE OR IGNORE \"\(t)\" SET LOCAL_ID=? WHERE LOCAL_ID=?;", -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, para, -1, Banco.TRANSIENT)
                sqlite3_bind_text(stmt, 2, de, -1, Banco.TRANSIENT)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
        exec("COMMIT;")
        apagarUsuario(localId: de)   // remove duplicatas que sobraram + o cadastro antigo
    }

    /// Gera um USER_ID novo que ainda nao existe, derivado de uma base ("010221-1" -> "010221-1-2").
    /// Usado ao decidir que dois cadastros com o mesmo ID sao pessoas DIFERENTES.
    func novoUserIdUnico(base: String) -> String {
        var existentes = Set<String>()
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT USER_ID FROM USER_INFO1_TBL;", -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let v = sqlite3_column_text(stmt, 0) { existentes.insert(String(cString: v)) }
            }
        }
        sqlite3_finalize(stmt)
        var n = 2
        while existentes.contains("\(base)-\(n)") { n += 1 }
        return "\(base)-\(n)"
    }

    /// Move um exame para outro dono (edita o ID do paciente): troca BCA.LOCAL_ID. E4.
    func moverExame(datetimes: String, paraLocalId: String) {
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "UPDATE BCA_TBL SET LOCAL_ID=? WHERE DATETIMES=?;", -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, paraLocalId, -1, Banco.TRANSIENT)
            sqlite3_bind_text(stmt, 2, datetimes, -1, Banco.TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    /// Leituras de pressao NAO-ZERO por paciente (SPHYG1=sistolica, SPHYG2=diastolica).
    /// So carrega leituras reais (a clinica sem monitor gera linhas zeradas). E4.
    func pressoesPorLocalId() -> [String: [LeituraPressao]] {
        var out: [String: [LeituraPressao]] = [:]
        var stmt: OpaquePointer?
        let sql = "SELECT LOCAL_ID, DATETIMES, SPHYG1, SPHYG2 FROM SPHYG_DATA_TBL;"
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let lid = sqlite3_column_text(stmt, 0).map { String(cString: $0) } ?? ""
                let dt = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
                let sys = Int(Double(sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? "0") ?? 0)
                let dia = Int(Double(sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? "0") ?? 0)
                guard sys > 0 || dia > 0 else { continue }
                out[lid, default: []].append(LeituraPressao(data: dt, sistolica: sys, diastolica: dia))
            }
        }
        sqlite3_finalize(stmt)
        return out
    }

    /// Apaga um paciente em cascata (contrato: detalhes NAO tem LOCAL_ID, so DATETIMES).
    /// 2 fases: acha os DATETIMES do paciente em BCA, apaga detalhes por eles, depois
    /// BCA/pressao/glicose/N:N por LOCAL_ID e por fim o cadastro.
    func apagarUsuario(localId: String) {
        // fase 1: DATETIMES dos exames do paciente
        var dts: [String] = []
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT DATETIMES FROM BCA_TBL WHERE LOCAL_ID=?;", -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, localId, -1, Banco.TRANSIENT)
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let v = sqlite3_column_text(stmt, 0) { dts.append(String(cString: v)) }
            }
        }
        sqlite3_finalize(stmt)
        exec("BEGIN;")
        for dt in dts {
            for t in ["ED_TBL", "LB_TBL", "IMP_TBL", "MFA_TBL", "WC_TBL"] {
                execBind("DELETE FROM \"\(t)\" WHERE DATETIMES=?;", dt)
            }
        }
        for t in ["BCA_TBL", "SPHYG_DATA_TBL", "BLOODSUGAR_TBL", "USER_GROUP_TBL", "USER_SICK_TBL"] {
            execBind("DELETE FROM \"\(t)\" WHERE LOCAL_ID=?;", localId)
        }
        execBind("DELETE FROM USER_INFO1_TBL WHERE LOCAL_ID=?;", localId)
        exec("COMMIT;")
    }

    // MARK: - Leitura crua (p/ prova de ida-e-volta e export fiel da E5)

    /// Uma linha de uma tabela por DATETIMES, como [coluna: valor]. NULL vira "" (contrato:
    /// no banco novo "vazio" nunca e IS NULL). Devolve [:] se nao existe.
    func linhasCruas(tabela: String, datetimes: String) -> [String: String] {
        var out: [String: String] = [:]
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT * FROM \"\(tabela)\" WHERE DATETIMES=? LIMIT 1;", -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, datetimes, -1, Banco.TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_ROW {
                let n = sqlite3_column_count(stmt)
                for i in 0..<n {
                    let nome = String(cString: sqlite3_column_name(stmt, i))
                    if let v = sqlite3_column_text(stmt, i) {
                        out[nome] = String(cString: v)
                    } else {
                        out[nome] = ""   // NULL -> ""
                    }
                }
            }
        }
        sqlite3_finalize(stmt)
        return out
    }

    /// Oraculo independente p/ a prova de busca por nome: NAMEs do banco que contem o
    /// termo (case-insensitive). NAME e texto claro no .mdb (nao cifrado).
    func nomesQueContem(_ termo: String) -> [String] {
        var out: [String] = []
        var stmt: OpaquePointer?
        let sql = "SELECT NAME FROM USER_INFO1_TBL WHERE NAME LIKE '%' || ? || '%' COLLATE NOCASE;"
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, termo, -1, Banco.TRANSIENT)
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let v = sqlite3_column_text(stmt, 0) { out.append(String(cString: v)) }
            }
        }
        sqlite3_finalize(stmt)
        return out
    }

    /// Existe exame com esse DATETIMES em BCA_TBL?
    func existeExame(datetimes: String) -> Bool {
        var stmt: OpaquePointer?
        var existe = false
        if sqlite3_prepare_v2(db, "SELECT 1 FROM BCA_TBL WHERE DATETIMES=? LIMIT 1;", -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, datetimes, -1, Banco.TRANSIENT)
            existe = sqlite3_step(stmt) == SQLITE_ROW
        }
        sqlite3_finalize(stmt)
        return existe
    }

    /// Grava o quadro cru na tabela de medicao temporaria do original (TempMeasureData_TBL).
    func salvarTemp(datetimes: String, raw: String, equip: String) {
        inserir("TempMeasureData_TBL", ["Datetimes": datetimes, "RawData": raw, "EQUIP": equip])
    }

    /// Lista as medições temporárias (C-06): datetimes + equipamento, mais recentes primeiro.
    func listarTemp() -> [(datetimes: String, equip: String)] {
        var out: [(String, String)] = []
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT Datetimes, EQUIP FROM TempMeasureData_TBL ORDER BY Datetimes DESC;", -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let dt = sqlite3_column_text(stmt, 0).map { String(cString: $0) } ?? ""
                let eq = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
                out.append((dt, eq))
            }
        }
        sqlite3_finalize(stmt)
        return out
    }

    /// Apaga UMA medição temporária por datetimes (C-06). Não toca em exames salvos.
    func apagarTemp(datetimes dt: String) { execBind("DELETE FROM TempMeasureData_TBL WHERE Datetimes=?;", dt) }

    /// Todos os DATETIMES de BCA_TBL (ordem cronologica). Chave da iteracao de exames.
    func todosDatetimes() -> [String] {
        var out: [String] = []
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT DATETIMES FROM BCA_TBL ORDER BY DATETIMES;", -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let v = sqlite3_column_text(stmt, 0) { out.append(String(cString: v)) }
            }
        }
        sqlite3_finalize(stmt)
        return out
    }

    /// Linha de USER_INFO1_TBL por LOCAL_ID (cadastro do paciente). [:] se ausente.
    func usuario(localId: String) -> [String: String] {
        var out: [String: String] = [:]
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT * FROM USER_INFO1_TBL WHERE LOCAL_ID=? LIMIT 1;", -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, localId, -1, Banco.TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_ROW {
                for i in 0..<sqlite3_column_count(stmt) {
                    let nome = String(cString: sqlite3_column_name(stmt, i))
                    out[nome] = sqlite3_column_text(stmt, i).map { String(cString: $0) } ?? ""
                }
            }
        }
        sqlite3_finalize(stmt)
        return out
    }

    /// Monta a Medida de UM exame lendo as 6 tabelas por DATETIMES. Reusa a fonte unica
    /// ImportService.montarMedida (contrato 8). alturaCadastro vem do USER (HEIGHT).
    func medidaDe(datetimes dt: String) -> Medida {
        let b = linhasCruas(tabela: "BCA_TBL", datetimes: dt)
        let m = linhasCruas(tabela: "MFA_TBL", datetimes: dt)
        let w = linhasCruas(tabela: "WC_TBL", datetimes: dt)
        let l = linhasCruas(tabela: "LB_TBL", datetimes: dt)
        let d = linhasCruas(tabela: "ED_TBL", datetimes: dt)
        let ip = linhasCruas(tabela: "IMP_TBL", datetimes: dt)
        let u = usuario(localId: b["LOCAL_ID"] ?? "")
        let alt = Double((u["HEIGHT"] ?? "").replacingOccurrences(of: ",", with: ".")) ?? 0
        return ImportService.montarMedida(b, m, w, l, d, ip, alturaCadastro: alt)
    }

    /// Grupos por paciente (LOCAL_ID -> "GrupoA, GrupoB"), das tabelas N:N do original
    /// (USER_GROUP_TBL x GROUP_TBL). Vazio quando a clinica nao usa grupos.
    func gruposPorLocalId() -> [String: String] {
        var nomes: [String: String] = [:]   // GROUP_TBL.SN -> nome
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT SN, GROUP_NAME FROM GROUP_TBL;", -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let sn = sqlite3_column_text(stmt, 0).map { String(cString: $0) } ?? ""
                nomes[sn] = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
            }
        }
        sqlite3_finalize(stmt)
        var out: [String: [String]] = [:]
        stmt = nil
        if sqlite3_prepare_v2(db, "SELECT LOCAL_ID, GROUP_SN FROM USER_GROUP_TBL;", -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let lid = sqlite3_column_text(stmt, 0).map { String(cString: $0) } ?? ""
                let gsn = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
                if let nome = nomes[gsn], !nome.isEmpty { out[lid, default: []].append(nome) }
            }
        }
        sqlite3_finalize(stmt)
        return out.mapValues { $0.joined(separator: ", ") }
    }

    /// Carrega todos os pacientes do banco (via montarMedida), agrupando exames por
    /// LOCAL_ID. Campos cifrados do cadastro sao decifrados na leitura (contrato 3).
    func carregarPacientes() -> [Paciente] {
        var mapa: [String: Paciente] = [:]   // LOCAL_ID -> Paciente
        let grupos = gruposPorLocalId()
        for dt in todosDatetimes() {
            let b = linhasCruas(tabela: "BCA_TBL", datetimes: dt)
            let localId = b["LOCAL_ID"] ?? ""
            let med = medidaDe(datetimes: dt)
            guard med.peso > 0 else { continue }
            if mapa[localId] == nil {
                let u = usuario(localId: localId)
                let idNegocio = (u["USER_ID"]?.isEmpty == false) ? u["USER_ID"]! : localId
                let nome = Cifra.claro(u["NAME"] ?? "").trimmingCharacters(in: .whitespaces)
                mapa[localId] = Paciente(
                    id: idNegocio,
                    localId: localId,
                    nome: nome.isEmpty ? "Sem nome" : nome,
                    sexo: ImportService.sexoDecodificado(u["GENDER"] ?? "") ?? "?",
                    idade: Int(Double((u["AGE"] ?? "").replacingOccurrences(of: ",", with: ".")) ?? 0),
                    altura: Double((u["HEIGHT"] ?? "").replacingOccurrences(of: ",", with: ".")) ?? 0,
                    exames: [],
                    celular: Cifra.claro(u["TEL_HP"] ?? ""),
                    historico: (u["MEDICAL_HISTORY"] ?? "").trimmingCharacters(in: .whitespaces),
                    grupo: grupos[localId] ?? "",
                    email: Cifra.claro(u["E_MAIL"] ?? ""),
                    nascimento: (u["BIRTHDAY"] ?? "").trimmingCharacters(in: .whitespaces),
                    registro: (u["USER_REG_DATE"] ?? "").trimmingCharacters(in: .whitespaces))
            }
            mapa[localId]?.exames.append(med)
        }
        // leituras de pressao nao-zero (E4); glicose fica p/ quando houver dado real.
        let pressoes = pressoesPorLocalId()
        var lista = Array(mapa.values)
        for i in lista.indices {
            lista[i].exames.sort { $0.data > $1.data }
            lista[i].pressoes = pressoes[lista[i].localId] ?? []
        }
        lista.sort { ($0.exames.first?.data ?? "") > ($1.exames.first?.data ?? "") }
        return lista
    }

    // MARK: - Export (E5)

    /// Exporta os exames em CSV fiel ao banco: USER_INFO1 (cadastro decifrado) + as 6
    /// tabelas por DATETIMES, uma linha por exame. Cabecalho = TABELA.COLUNA (como o corpus).
    /// Devolve o caminho gravado, ou nil em falha.
    @discardableResult
    func exportarCSV(para destino: String) -> Bool {
        let colsUser = ["USER_ID", "NAME", "GENDER", "AGE", "HEIGHT", "TEL_HP", "E_MAIL"]
        let ordem = Banco.tabelasExame   // BCA,ED,LB,IMP,MFA,WC
        var colsPorTabela: [(String, [String])] = ordem.map { ($0, colunasDe($0)) }
        // cabecalho
        var header = colsUser.map { "USER.\($0)" }
        for (t, cs) in colsPorTabela { header += cs.map { "\(t.replacingOccurrences(of: "_TBL", with: "")).\($0)" } }
        func esc(_ s: String) -> String {
            (s.contains(",") || s.contains("\"") || s.contains("\n"))
                ? "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\"" : s
        }
        var linhas = [header.map(esc).joined(separator: ",")]
        for dt in todosDatetimes() {
            let bca = linhasCruas(tabela: "BCA_TBL", datetimes: dt)
            let u = usuario(localId: bca["LOCAL_ID"] ?? "")
            var campos: [String] = colsUser.map { c in
                let v = u[c] ?? ""
                return ["NAME", "GENDER", "TEL_HP", "E_MAIL"].contains(c) ? Cifra.claro(v) : v
            }
            for (t, cs) in colsPorTabela {
                let linha = linhasCruas(tabela: t, datetimes: dt)
                campos += cs.map { linha[$0] ?? "" }
            }
            linhas.append(campos.map(esc).joined(separator: ","))
        }
        _ = colsPorTabela   // (silencia aviso de mutabilidade)
        return (try? linhas.joined(separator: "\n").write(toFile: destino, atomically: true, encoding: .utf8)) != nil
    }

    /// Restaura o banco a partir de um arquivo de backup (.sqlite gerado por VACUUM INTO):
    /// substitui o arquivo atual e reabre. Feito por copia (backups sao snapshots consistentes).
    static func restaurar(de backup: String, para destino: String) -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: backup) else { return false }
        // remove WAL/SHM antigos p/ nao mesclar estado velho
        for suf in ["", "-wal", "-shm"] { try? fm.removeItem(atPath: destino + suf) }
        return (try? fm.copyItem(atPath: backup, toPath: destino)) != nil
    }

    // MARK: - Backup (VACUUM INTO)

    /// Copia consistente do banco por VACUUM INTO (nunca copia do arquivo quente), com
    /// rotacao dos N mais recentes. Chamado na abertura do app.
    @discardableResult
    func fazerBackup(manter: Int = 5) -> String {
        let dir = (caminho as NSString).deletingLastPathComponent + "/backups"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyyMMdd-HHmmss-SSS"
        let destino = "\(dir)/inbody-\(f.string(from: Date())).sqlite"
        if !FileManager.default.fileExists(atPath: destino) {
            exec("VACUUM INTO '\(destino)';")
        }
        if let itens = try? FileManager.default.contentsOfDirectory(atPath: dir)
            .filter({ $0.hasPrefix("inbody-") && $0.hasSuffix(".sqlite") }).sorted() {
            for velho in itens.dropLast(manter) { try? FileManager.default.removeItem(atPath: "\(dir)/\(velho)") }
        }
        return destino
    }

    func contarLinhas(_ tabela: String) -> Int {
        var stmt: OpaquePointer?
        var n = 0
        if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM \"\(tabela)\";", -1, &stmt, nil) == SQLITE_OK,
           sqlite3_step(stmt) == SQLITE_ROW {
            n = Int(sqlite3_column_int(stmt, 0))
        }
        sqlite3_finalize(stmt)
        return n
    }
}
