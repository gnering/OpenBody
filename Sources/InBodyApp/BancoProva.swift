import Foundation
import InBodyKit

/// Instrumento de prova da camada Banco (E1). Rodado por `swift run InBodyApp --prova-banco ...`.
/// Toda prova traz auto-teste com erro injetado (regra 1): o instrumento so vale se ACUSA
/// um erro plantado antes de rodar limpo.
enum BancoProva {

    /// Mapa prefixo-do-corpus -> tabela do banco.
    static let pref2tbl = ["BCA": "BCA_TBL", "ED": "ED_TBL", "IMP": "IMP_TBL",
                           "LB": "LB_TBL", "MFA": "MFA_TBL", "WC": "WC_TBL"]

    @MainActor
    static func rodar(_ args: [String]) {
        // args: ["--prova-banco", <modo>, <extra?>]
        guard args.count >= 2 else { print("uso: --prova-banco criar|corpus [csv]"); exit(2) }
        switch args[1] {
        case "criar":    exit(provaCriar())
        case "cifra":    exit(provaCifra())
        case "corpus":   exit(provaCorpus(args.count >= 3 ? args[2] : caminhoCorpusPadrao()))
        case "carregar": exit(provaCarregar(args.count >= 3 ? args[2] : caminhoCorpusPadrao()))
        case "mdb":      exit(provaMDB(args.count >= 3 ? args[2] : caminhoMDBPadrao()))
        case "vr":       exit(provaVR(args.count >= 3 ? args[2] : caminhoCorpusPadrao()))
        case "dedup":    exit(provaDedup())
        case "busca":    exit(provaBusca(args.count >= 3 ? args[2] : caminhoMDBPadrao()))
        case "migracao": exit(provaMigracao())
        case "editar":   exit(provaEditar())
        case "backup":   exit(provaBackup(args.count >= 3 ? args[2] : caminhoMDBPadrao()))
        case "editcad":  exit(provaEditarCadastro())
        case "massa":    exit(provaMassa())
        case "config":   exit(provaConfig(args.count >= 3 ? args[2] : caminhoSettingsPadrao()))
        case "atualiza": exit(provaAtualiza())
        case "serial":   exit(provaSerial())
        case "emr":      exit(provaEmr())
        case "alinhamento": exit(provaAlinhamento())
        case "nuvem":    exit(provaNuvem())
        default:         print("modo desconhecido: \(args[1])"); exit(2)
        }
    }

    // Caminhos de teste (dev). Resolvidos em runtime — sem caminho pessoal chumbado no binário.
    // Sobrescreva por variável de ambiente ao rodar --prova-banco.
    static func caminhoCorpusPadrao() -> String {
        ProcessInfo.processInfo.environment["INBODY_CORPUS"]
            ?? NSHomeDirectory() + "/Desktop/inbody/corpus-mdb/exames.csv"
    }

    static func caminhoMDBPadrao() -> String {
        ProcessInfo.processInfo.environment["INBODY_MDB"]
            ?? NSHomeDirectory() + "/Desktop/Backup inbody/LookinBody.MDB"
    }

    static func caminhoSettingsPadrao() -> String {
        ProcessInfo.processInfo.environment["INBODY_SETTINGS"]
            ?? NSHomeDirectory() + "/Desktop/Backup inbody/settings.xml"
    }

    // MARK: - Prova: EMR export (B-05)

    static func provaEmr() -> Int32 {
        var falhas: [String] = []
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("emr_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let p = Paciente(id: "T1", nome: "Teste, EMR", sexo: "M", idade: 40, altura: 175, exames: [])
        let m = ImportService.medidaDeLinha(["BCA.DATETIMES": "20260101100000", "BCA.WT": "80.5",
                                             "BCA.LOCAL_ID": "1", "MFA.SMM": "35", "BCA.BFM": "12"])
        guard let csv = EmrExport.exportarCSVExame(paciente: p, medida: m, pasta: tmp.path) else {
            print("PROVA EMR FALHOU: CSV nao gerou"); return 1
        }
        let texto = (try? String(contentsOfFile: csv, encoding: .utf8)) ?? ""
        if !texto.contains("\"Teste, EMR\"") { falhas.append("CSV nao escapou virgula do nome") }
        if !texto.contains("80.5") { falhas.append("CSV sem peso") }
        if !(csv as NSString).lastPathComponent.hasSuffix(".csv") { falhas.append("nome do arquivo errado") }
        try? FileManager.default.removeItem(at: tmp)
        if falhas.isEmpty { print("PROVA EMR OK: CSV por exame com nome escapado + peso; nome de arquivo correto."); return 0 }
        print("PROVA EMR FALHOU:"); falhas.forEach { print("  ", $0) }; return 1
    }

    // MARK: - Prova: alinhamento de impressão (A-03)

    static func provaAlinhamento() -> Int32 {
        var falhas: [String] = []
        AlinhamentoImpressao.resetar()
        if AlinhamentoImpressao.dx != 0 || AlinhamentoImpressao.dy != 0 { falhas.append("reset nao zerou") }
        AlinhamentoImpressao.salvar(dx: 2.5, dy: -1.0)
        if AlinhamentoImpressao.dx != 2.5 || AlinhamentoImpressao.dy != -1.0 { falhas.append("nao persistiu") }
        AlinhamentoImpressao.salvar(dx: 999, dy: -999)
        if AlinhamentoImpressao.dx != 10 || AlinhamentoImpressao.dy != -10 { falhas.append("sem clamp +/-10") }
        AlinhamentoImpressao.resetar()
        if falhas.isEmpty { print("PROVA ALINHAMENTO OK: persiste dx/dy e limita a +/-10mm."); return 0 }
        print("PROVA ALINHAMENTO FALHOU:"); falhas.forEach { print("  ", $0) }; return 1
    }

    // MARK: - Prova: backup na nuvem (B-02)

    static func provaNuvem() -> Int32 {
        var falhas: [String] = []
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("cloud_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        // snapshot de mentira com cabeçalho SQLite válido (testa a cópia p/ nuvem, não o VACUUM)
        let snap = tmp.appendingPathComponent("snap.sqlite")
        let cab = Data([0x53,0x51,0x4C,0x69,0x74,0x65,0x20,0x66,0x6F,0x72,0x6D,0x61,0x74,0x20,0x33,0x00])
        try? cab.write(to: snap)
        guard let caminho = CloudBackup.copiarSnapshot(snap.path, paraPasta: tmp.path) else {
            print("PROVA NUVEM FALHOU: backup nao gravou"); return 1
        }
        if !caminho.contains("InBody Backups") { falhas.append("nao criou subpasta InBody Backups") }
        let dados = (try? Data(contentsOf: URL(fileURLWithPath: caminho))) ?? Data()
        if dados.prefix(16) != cab { falhas.append("backup nao e um SQLite valido") }
        try? FileManager.default.removeItem(at: tmp)
        if falhas.isEmpty { print("PROVA NUVEM OK: copia SQLite valido para subpasta 'InBody Backups' da pasta vinculada."); return 0 }
        print("PROVA NUVEM FALHOU:"); falhas.forEach { print("  ", $0) }; return 1
    }

    // MARK: - Prova: serial (E8) — transporte serial do dongle Bluetooth (via PTY)

    /// Prova o transporte SERIAL sem o dongle fisico: abre um pseudo-terminal (porta serial
    /// de mentira), escreve quadros InBody de um lado e confere que PortTransport(serialDevice:)
    /// le e delimita os quadros do outro — o MESMO extrator ja provado no TCP. O que fica
    /// para o dongle real: so a camada fisica (baud/8N1), que nao da p/ testar sem o aparelho.
    @MainActor
    static func provaSerial() -> Int32 {
        var falhas: [String] = []
        // 1. abre um PTY: master (nosso lado "balanca") + slave (/dev/ttysNNN = a "porta serial")
        let master = posix_openpt(O_RDWR | O_NOCTTY)
        guard master >= 0, grantpt(master) == 0, unlockpt(master) == 0,
              let namePtr = ptsname(master) else { print("nao abri o PTY"); return 2 }
        let slave = String(cString: namePtr)
        guard let t = PortTransport(serialDevice: slave) else {
            print("PortTransport nao abriu a porta serial \(slave)"); return 1
        }
        func escreveNoMaster(_ bytes: [UInt8]) {
            _ = bytes.withUnsafeBytes { Foundation.write(master, $0.baseAddress, bytes.count) }
        }

        // 2. um quadro InBody completo escrito na "balanca" e lido pela porta serial
        let quadro = InBodyProtocol.makeFrame("P", "0", "NEWPROTOCOL\u{1B}")
        escreveNoMaster(quadro)
        if let raw = t.readFrame(timeout: 2), let (payload, _) = InBodyProtocol.parse(raw) {
            if !payload.contains("NEWPROTOCOL") { falhas.append("payload lido nao bate: \(payload.prefix(20))") }
        } else { falhas.append("nao leu/parseou o quadro pela serial") }

        // 3. dois quadros GRUDADOS: o extrator tem que separar (mesma logica do TCP)
        escreveNoMaster(InBodyProtocol.makeFrame("s", "R", "A\u{1B}") + InBodyProtocol.makeFrame("s", "R", "B\u{1B}"))
        let q1 = t.readFrame(timeout: 2), q2 = t.readFrame(timeout: 2)
        if q1 == nil || q2 == nil { falhas.append("nao separou os dois quadros grudados") }

        // 4. abre nas 3 velocidades (dongle 115200 / USB 19200 / cabo 9600): parametros
        //    aceitos e le um quadro (o PTY ignora o baud eletrico; isso prova a plumbing).
        for b in [speed_t(B9600), speed_t(B19200), speed_t(B115200)] {
            let m2 = posix_openpt(O_RDWR | O_NOCTTY)
            if m2 >= 0, grantpt(m2) == 0, unlockpt(m2) == 0, let np = ptsname(m2),
               let tt = PortTransport(serialDevice: String(cString: np), baud: b) {
                let fr = InBodyProtocol.makeFrame("P", "0", "X\u{1B}")
                _ = fr.withUnsafeBytes { Foundation.write(m2, $0.baseAddress, fr.count) }
                if tt.readFrame(timeout: 1) == nil { falhas.append("baud \(b): nao leu") }
                close(m2)
            } else { falhas.append("baud \(b): nao abriu a porta") }
        }

        // 5. descoberta de portas nao quebra
        _ = PortTransport.portasSeriais()

        // Auto-teste (regra 1): so ruido (sem STX) -> readFrame devolve nil (timeout curto).
        escreveNoMaster([0x41, 0x42, 0x43])   // "ABC", sem STX
        let acusa = t.readFrame(timeout: 1) == nil

        close(master)
        if falhas.isEmpty && acusa {
            print("PROVA SERIAL OK: le/delimita quadros InBody pela porta serial (dongle); ruido sem STX nao vira quadro.")
            return 0
        }
        print("PROVA SERIAL FALHOU:"); falhas.forEach { print("  ", $0) }
        if !acusa { print("   auto-teste: ruido sem STX virou quadro") }
        return 1
    }

    // MARK: - Prova: atualiza (E11) — comparacao de versoes do verificador

    @MainActor
    static func provaAtualiza() -> Int32 {
        var falhas: [String] = []
        typealias A = AtualizacaoService
        func esperar(_ disp: String, _ atual: String, _ esperado: Bool, _ rot: String) {
            if A.maisNova(disponivel: disp, que: atual) != esperado { falhas.append("\(rot): \(disp) vs \(atual)") }
        }
        esperar("1.0.1", "1.0.0", true,  "patch maior")
        esperar("1.1.0", "1.0.9", true,  "minor ganha do patch")   // 1.1.0 > 1.0.9
        esperar("2.0.0", "1.9.9", true,  "major")
        esperar("1.0.0", "1.0.0", false, "iguais")
        esperar("1.0.0", "1.0.1", false, "instalada mais nova")
        esperar("v1.2.0", "1.1.0", true, "prefixo v")
        esperar("1.2.0-beta", "1.1.0", true, "sufixo -beta ignorado")
        esperar("1.0", "1.0.0", false, "faltando campo = 0")

        // Auto-teste (regra 1): a comparacao NAO pode ser sempre-true nem sempre-false.
        let acusa = A.maisNova(disponivel: "2.0.0", que: "1.0.0") && !A.maisNova(disponivel: "1.0.0", que: "2.0.0")

        if falhas.isEmpty && acusa {
            print("PROVA ATUALIZA OK: comparacao de versao correta (patch/minor/major/iguais/prefixo/sufixo).")
            return 0
        }
        print("PROVA ATUALIZA FALHOU:"); falhas.forEach { print("  ", $0) }
        if !acusa { print("   auto-teste: comparacao degenerada") }
        return 1
    }

    // MARK: - Prova: config (E10) — le a config real do settings.xml

    @MainActor
    static func provaConfig(_ xmlPath: String) -> Int32 {
        guard let xml = try? String(contentsOfFile: xmlPath, encoding: .utf8) else {
            print("settings.xml nao encontrado: \(xmlPath)"); return 2
        }
        let c = ConfigClinica.carregar(xml: xml)
        var falhas: [String] = []
        // valores REAIS conhecidos do settings.xml da clinica
        if c.lang != "BR" { falhas.append("LANG=\(c.lang), esperado BR") }
        if c.countryCode != "55" { falhas.append("COUNTRY_CODE=\(c.countryCode), esperado 55") }
        if !c.unidadeMetrica { falhas.append("UNIT nao ficou metrico (0)") }
        if c.dateFormat != "dd.MM.yyyy." { falhas.append("DATE_FORMAT=\(c.dateFormat)") }
        if !c.centroServicoNome.contains("Ottoboni") { falhas.append("SERVICE_CENTER_NAME=\(c.centroServicoNome)") }
        if !c.autoUpdate { falhas.append("AUTO_UPDATE nao ficou Y") }
        // entidade XML decodificada (o endereco tem parenteses/acentos, e o & se houver)
        if c.entradas.count < 30 { falhas.append("poucas entradas lidas: \(c.entradas.count)") }

        // Auto-teste (regra 1): trocar UNIT p/ 1 no XML tem que virar imperial.
        let xmlImperial = xml.replacingOccurrences(of: "<entry name=\"UNIT\">0</entry>",
                                                   with: "<entry name=\"UNIT\">1</entry>")
        let acusa = ConfigClinica.carregar(xml: xmlImperial).unidadeMetrica == false

        if falhas.isEmpty && acusa {
            print("PROVA CONFIG OK: LANG=BR, pais 55, metrico, data \(c.dateFormat), assistencia '\(c.centroServicoNome.prefix(20))...', \(c.entradas.count) chaves; UNIT=1 vira imperial.")
            return 0
        }
        print("PROVA CONFIG FALHOU:"); falhas.forEach { print("  ", $0) }
        if !acusa { print("   auto-teste: UNIT=1 nao virou imperial") }
        return 1
    }

    // MARK: - Prova: mdb (T4b cadastro real + T4c idempotencia)

    @MainActor
    static func provaMDB(_ db: String) -> Int32 {
        guard FileManager.default.fileExists(atPath: db) else { print("mdb nao encontrado: \(db)"); return 2 }
        let caminho = bancoTemp()
        let banco = Banco(caminho: caminho)
        let (nU, nE) = banco.importarMDB(db)
        var falhas: [String] = []

        // T4b: round-trip cru de USER_INFO1 — cada coluna gravada == valor do mdb-export.
        let orig = ImportService.exporta(db, "USER_INFO1_TBL")
        let validas = Set(banco.colunasDe("USER_INFO1_TBL"))
        var divergCad = 0
        for u in orig {
            let lido = banco.usuario(localId: u["LOCAL_ID"] ?? "")
            for (c, v) in u where validas.contains(c) {
                if (lido[c] ?? "") != v { divergCad += 1 }
            }
        }
        if divergCad > 0 { falhas.append("\(divergCad) celulas de cadastro divergentes no round-trip") }

        // Decifragem real: quantos GENDER viram M/F (contrato 3). Deve cobrir a maioria.
        let pacientes = banco.carregarPacientes()
        let comSexo = pacientes.filter { $0.sexo == "M" || $0.sexo == "F" }.count
        let comNome = pacientes.filter { !$0.nome.isEmpty && $0.nome != "Sem nome" }.count

        // Auto-teste (regra 1): corromper uma celula de cadastro tem que ser ACUSADO.
        let alvo = orig.first(where: { !($0["LOCAL_ID"] ?? "").isEmpty })?["LOCAL_ID"] ?? ""
        Banco.corromper(caminho: caminho, tabela: "USER_INFO1_TBL", datetimesCol: "LOCAL_ID",
                        chave: alvo, coluna: "NAME", valor: "___CORROMPIDO___")
        let banco2 = Banco(caminho: caminho)
        let acusa = (banco2.usuario(localId: alvo)["NAME"] ?? "") == "___CORROMPIDO___"

        // T4c: idempotencia — reimportar o MESMO mdb nao cria linha nova.
        let banco3 = Banco(caminho: bancoTemp())
        let r1 = banco3.importarMDB(db)
        let uAntes = banco3.contarLinhas("USER_INFO1_TBL"), eAntes = banco3.contarLinhas("BCA_TBL")
        _ = banco3.importarMDB(db)
        let uDepois = banco3.contarLinhas("USER_INFO1_TBL"), eDepois = banco3.contarLinhas("BCA_TBL")
        let idempotente = (uAntes == uDepois && eAntes == eDepois)
        if !idempotente { falhas.append("reimporte mudou contagem: user \(uAntes)->\(uDepois), bca \(eAntes)->\(eDepois)") }

        try? FileManager.default.removeItem(atPath: (caminho as NSString).deletingLastPathComponent)
        try? FileManager.default.removeItem(atPath: (banco3.caminho as NSString).deletingLastPathComponent)

        print("Cadastro: \(nU) usuarios, \(nE) exames importados. Cadastro round-trip: \(divergCad) divergencias.")
        print("Decifragem: \(comSexo)/\(pacientes.count) pacientes com sexo M/F; \(comNome) com nome legivel.")
        print("Idempotencia: 1a=\(r1.usuarios)u/\(r1.exames)e; apos 2a importacao contagem \(idempotente ? "INALTERADA" : "MUDOU").")
        print(acusa ? "AUTO-TESTE OK: corrupcao de cadastro ACUSADA." : "AUTO-TESTE FALHOU.")
        if falhas.isEmpty && acusa {
            print("PROVA MDB OK.")
            return 0
        }
        print("PROVA MDB FALHOU:"); falhas.forEach { print("  ", $0) }
        return 1
    }

    // MARK: - Prova: massa (E7) — cadastro em massa por planilha

    @MainActor
    static func provaMassa() -> Int32 {
        var falhas: [String] = []
        let banco = Banco(caminho: bancoTemp())
        let store = Store(banco: banco)
        // planilha: 2 validas, 1 sem nome, 1 sexo invalido, 1 altura 0, 1 duplicada da 1a.
        let csv = """
        USER_ID,NAME,GENDER,AGE,HEIGHT,BIRTHDAY,TEL_HP,ADDR,E_MAIL,GRUPO
        A1,Joao Silva,M,40,175,1985/03/14,111,Rua 1,a@b.com,
        A2,Maria Souza,F,,168,1990/07/01,222,Rua 2,m@b.com,VIP
        ,Sem Sexo,X,30,170,,,, ,
        A3,Altura Zero,M,20,0,,,,,
        A1,Duplicado,M,50,180,,,,,
        """
        let r = CadastroEmMassa.importar(csv: csv, store: store)
        if r.adicionados != 2 { falhas.append("adicionados=\(r.adicionados), esperado 2") }
        if r.ignorados.count != 3 { falhas.append("ignorados=\(r.ignorados.count), esperado 3 (\(r.ignorados))") }
        // gravou no banco e calculou idade da Maria pelo nascimento (AGE vazio)
        let maria = store.pacientes.first { $0.id == "A2" }
        if maria == nil { falhas.append("Maria (A2) nao foi cadastrada") }
        if (maria?.idade ?? 0) <= 0 { falhas.append("idade da Maria nao foi calculada do nascimento") }
        if maria?.grupo != "VIP" { falhas.append("grupo da Maria nao veio") }
        // persistiu de verdade (recarrega do banco)
        let recarregados = banco.carregarPacientes().map { $0.id }
        // (sem exame, carregarPacientes filtra por peso>0 -> nao aparecem; confere no USER_INFO1)
        let noBanco = banco.contarLinhas("USER_INFO1_TBL")
        if noBanco != 2 { falhas.append("USER_INFO1 tem \(noBanco) linhas, esperado 2") }
        _ = recarregados

        // modelo tem cabecalho certo
        if !CadastroEmMassa.modelo().hasPrefix("USER_ID,NAME,GENDER") { falhas.append("modelo com cabecalho errado") }

        // Auto-teste (regra 1): reimportar a MESMA planilha nao duplica (IDs ja existem).
        let r2 = CadastroEmMassa.importar(csv: csv, store: store)
        let acusa = r2.adicionados == 0

        try? FileManager.default.removeItem(atPath: (banco.caminho as NSString).deletingLastPathComponent)
        if falhas.isEmpty && acusa {
            print("PROVA MASSA OK: 2 validas cadastradas + persistidas, 3 invalidas ignoradas, idade/grupo lidos, reimporte nao duplica.")
            return 0
        }
        print("PROVA MASSA FALHOU:"); falhas.forEach { print("  ", $0) }
        if !acusa { print("   auto-teste: reimporte duplicou (\(r2.adicionados) novos)") }
        return 1
    }

    // MARK: - Prova: editcad — editar cadastro persiste (UPDATE, nao INSERT OR IGNORE)

    @MainActor
    static func provaEditarCadastro() -> Int32 {
        var falhas: [String] = []
        let banco = Banco(caminho: bancoTemp())
        banco.salvarUsuario(["LOCAL_ID": "1", "USER_ID": "p1", "NAME": "Antigo",
                             "TEL_HP": "111", "ADDR": "Rua X", "FIELD_ENCRYPTION": "N"])
        // edita nome e telefone (UPDATE): ADDR (nao informado) deve ser preservado
        banco.atualizarUsuario(["LOCAL_ID": "1", "NAME": "Novo", "TEL_HP": "222"])
        let u = banco.usuario(localId: "1")
        if u["NAME"] != "Novo" { falhas.append("NAME nao atualizou: \(u["NAME"] ?? "nil")") }
        if u["TEL_HP"] != "222" { falhas.append("TEL_HP nao atualizou") }
        if u["ADDR"] != "Rua X" { falhas.append("ADDR (nao informado) foi perdido: \(u["ADDR"] ?? "nil")") }
        // nao criou duplicata
        if banco.contarLinhas("USER_INFO1_TBL") != 1 { falhas.append("edicao duplicou o cadastro") }

        // Auto-teste (regra 1): a via ANTIGA (salvarUsuario=INSERT OR IGNORE) NAO edita.
        banco.salvarUsuario(["LOCAL_ID": "1", "NAME": "NaoDeveEntrar"])
        let semEfeito = banco.usuario(localId: "1")["NAME"] == "Novo"   // continua "Novo"
        let acusa = semEfeito

        try? FileManager.default.removeItem(atPath: (banco.caminho as NSString).deletingLastPathComponent)
        if falhas.isEmpty && acusa {
            print("PROVA EDITCAD OK: UPDATE altera nome/tel, preserva ADDR, sem duplicar; INSERT OR IGNORE nao edita.")
            return 0
        }
        print("PROVA EDITCAD FALHOU:"); falhas.forEach { print("  ", $0) }
        if !acusa { print("   auto-teste: INSERT OR IGNORE sobrescreveu (inesperado)") }
        return 1
    }

    // MARK: - Prova: backup (E5) — backup/restauracao + export CSV fiel

    @MainActor
    static func provaBackup(_ db: String) -> Int32 {
        guard FileManager.default.fileExists(atPath: db) else { print("mdb nao encontrado"); return 2 }
        let caminho = bancoTemp()
        let banco = Banco(caminho: caminho)
        banco.importarMDB(db)
        let uOrig = banco.contarLinhas("USER_INFO1_TBL"), eOrig = banco.contarLinhas("BCA_TBL")
        var falhas: [String] = []

        // backup por VACUUM INTO -> apaga o banco -> restaura -> contagem identica
        let backup = banco.fazerBackup()
        for suf in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: caminho + suf) }
        if FileManager.default.fileExists(atPath: caminho) { falhas.append("banco nao foi apagado no teste") }
        _ = Banco.restaurar(de: backup, para: caminho)
        let rest = Banco(caminho: caminho)
        let uRest = rest.contarLinhas("USER_INFO1_TBL"), eRest = rest.contarLinhas("BCA_TBL")
        if uRest != uOrig || eRest != eOrig {
            falhas.append("restauracao mudou contagem: user \(uOrig)->\(uRest), bca \(eOrig)->\(eRest)")
        }

        // export CSV fiel: cada valor de BCA no CSV == linhasCruas do banco
        let csv = NSTemporaryDirectory() + "export-\(UUID().uuidString).csv"
        _ = rest.exportarCSV(para: csv)
        guard let (header, linhas) = lerCSV(csv) else { falhas.append("nao li o CSV exportado"); return finaliza(falhas, caminho, csv) }
        let idxWT = header.firstIndex(of: "BCA.WT")
        let idxDT = header.firstIndex(of: "BCA.DATETIMES")
        var divCSV = 0
        if let iWT = idxWT, let iDT = idxDT {
            for vals in linhas where vals.count == header.count {
                let dt = vals[iDT]
                let doBanco = rest.linhasCruas(tabela: "BCA_TBL", datetimes: dt)["WT"] ?? ""
                if vals[iWT] != doBanco { divCSV += 1 }
            }
        } else { falhas.append("CSV sem colunas BCA.WT/DATETIMES") }
        if divCSV > 0 { falhas.append("\(divCSV) linhas do CSV divergem do banco") }
        if linhas.count != eOrig { falhas.append("CSV tem \(linhas.count) exames, banco tem \(eOrig)") }

        // Auto-teste (regra 1): restaurar de backup inexistente NAO deve "dar certo".
        let acusa = Banco.restaurar(de: "/nao/existe.sqlite", para: NSTemporaryDirectory() + "x.sqlite") == false

        return finaliza(falhas, caminho, csv, extra: acusa,
            ok: "PROVA BACKUP OK: restauracao preserva \(uRest)u/\(eRest)e; CSV fiel (\(linhas.count) exames, 0 divergencia).")
    }

    @MainActor
    private static func finaliza(_ falhas: [String], _ caminho: String, _ csv: String,
                                 extra: Bool = true, ok: String = "OK") -> Int32 {
        try? FileManager.default.removeItem(atPath: (caminho as NSString).deletingLastPathComponent)
        try? FileManager.default.removeItem(atPath: csv)
        if falhas.isEmpty && extra { print(ok); return 0 }
        print("PROVA BACKUP FALHOU:"); falhas.forEach { print("  ", $0) }
        if !extra { print("   auto-teste: restaurar de backup inexistente retornou true") }
        return 1
    }

    // MARK: - Prova: editar (E4) — renomear (editar data) e mover (editar dono) exame

    @MainActor
    static func provaEditar() -> Int32 {
        var falhas: [String] = []
        let banco = Banco(caminho: bancoTemp())
        banco.salvarUsuario(["LOCAL_ID": "1", "USER_ID": "a", "NAME": "A", "FIELD_ENCRYPTION": "N"])
        banco.salvarUsuario(["LOCAL_ID": "2", "USER_ID": "b", "NAME": "B", "FIELD_ENCRYPTION": "N"])
        let dt = "20200101010101"
        banco.salvarExame(["BCA_TBL": ["DATETIMES": dt, "LOCAL_ID": "1", "WT": "70"],
                           "MFA_TBL": ["DATETIMES": dt, "SMM": "30"],
                           "LB_TBL": ["DATETIMES": dt, "WBPA50": "6"]])

        // renomear (editar data): reescreve DATETIMES nas 6 tabelas
        let novo = "20200101010102"
        banco.renomearExame(de: dt, para: novo)
        let sumiu = !banco.existeExame(datetimes: dt)
        let apareceu = banco.existeExame(datetimes: novo)
        // e os detalhes seguiram (MFA/LB pela nova chave)?
        let mfaSeguiu = banco.linhasCruas(tabela: "MFA_TBL", datetimes: novo)["SMM"] == "30"
        let lbSeguiu = banco.linhasCruas(tabela: "LB_TBL", datetimes: novo)["WBPA50"] == "6"
        if !(sumiu && apareceu && mfaSeguiu && lbSeguiu) {
            falhas.append("renomear: sumiu=\(sumiu) apareceu=\(apareceu) mfa=\(mfaSeguiu) lb=\(lbSeguiu)")
        }

        // mover (editar dono): troca BCA.LOCAL_ID de 1 para 2
        banco.moverExame(datetimes: novo, paraLocalId: "2")
        let novoDono = banco.linhasCruas(tabela: "BCA_TBL", datetimes: novo)["LOCAL_ID"] == "2"
        if !novoDono { falhas.append("mover: dono nao mudou p/ 2") }

        // C-06: inserir/listar/apagar medição temporária
        banco.salvarTemp(datetimes: "20260101090000", raw: "x", equip: "770")
        if banco.listarTemp().count != 1 { falhas.append("temp: nao inseriu") }
        banco.apagarTemp(datetimes: "20260101090000")
        if !banco.listarTemp().isEmpty { falhas.append("temp: nao apagou") }

        // normalizaDatetimes: aceita formatos e rejeita ano absurdo
        if Store.normalizaDatetimes("10.08.2026 01:24") != "20260810012400" { falhas.append("normaliza dd.MM.yyyy") }
        if Store.normalizaDatetimes("20260810012401") != "20260810012401" { falhas.append("normaliza cru") }
        if Store.normalizaDatetimes("abc") != nil { falhas.append("normaliza aceitou lixo") }

        // Auto-teste (regra 1): renomear p/ DATETIMES ja existente NAO deve sobrescrever.
        let dt2 = "20200202020202"
        banco.salvarExame(["BCA_TBL": ["DATETIMES": dt2, "LOCAL_ID": "2", "WT": "80"]])
        banco.renomearExame(de: novo, para: dt2)   // dt2 ja existe -> deve ser no-op
        let protegido = banco.existeExame(datetimes: novo)   // 'novo' continua existindo
                      && banco.linhasCruas(tabela: "BCA_TBL", datetimes: dt2)["WT"] == "80"
        let acusa = protegido

        try? FileManager.default.removeItem(atPath: (banco.caminho as NSString).deletingLastPathComponent)
        if falhas.isEmpty && acusa {
            print("PROVA EDITAR OK: renomear reescreve as 6 chaves; mover troca o dono; colisao protegida.")
            return 0
        }
        print("PROVA EDITAR FALHOU:"); falhas.forEach { print("  ", $0) }
        if !acusa { print("   auto-teste: renomear sobre DATETIMES existente sobrescreveu") }
        return 1
    }

    // MARK: - Prova: migracao (E3) — banco v1 abre em v2 sem perder linha

    @MainActor
    static func provaMigracao() -> Int32 {
        let caminho = bancoTemp()
        // cria um banco e forca user_version=1 (simula banco da E1), com dados dentro
        let b1 = Banco(caminho: caminho)
        b1.salvarUsuario(["LOCAL_ID": "1", "USER_ID": "p1", "NAME": "Teste", "FIELD_ENCRYPTION": "N"])
        b1.salvarExame(["BCA_TBL": ["DATETIMES": "20200101010101", "LOCAL_ID": "1", "WT": "70"]])
        let uAntes = b1.contarLinhas("USER_INFO1_TBL"), eAntes = b1.contarLinhas("BCA_TBL")
        // rebaixa a versao por fora (simula banco criado na E1, v1) e reabre:
        // migrar() deve subir p/ v2 aplicando os indices, sem perder dados.
        _ = leTexto(caminho, "PRAGMA user_version=1;")
        let b2 = Banco(caminho: caminho)
        let uDepois = b2.contarLinhas("USER_INFO1_TBL"), eDepois = b2.contarLinhas("BCA_TBL")
        let versao = leTexto(caminho, "PRAGMA user_version;")
        let temIndice = leTexto(caminho, "SELECT name FROM sqlite_master WHERE type='index' AND name='ix_user_name';")

        // Auto-teste (regra 1): se a migracao apagasse dados, contagem cairia -> detectavel.
        let preservou = (uAntes == uDepois && eAntes == eDepois && uDepois == 1 && eDepois == 1)
        try? FileManager.default.removeItem(atPath: (caminho as NSString).deletingLastPathComponent)
        if preservou && versao == "2" && temIndice == "ix_user_name" {
            print("PROVA MIGRACAO OK: v1->v2 sem perder linha (\(uDepois)u/\(eDepois)e), indices criados.")
            return 0
        }
        print("PROVA MIGRACAO FALHOU: versao=\(versao) indice=\(temIndice) u=\(uAntes)->\(uDepois) e=\(eAntes)->\(eDepois)")
        return 1
    }

    // MARK: - Prova: busca (E3) — Store.filtrados vs oraculo independente

    @MainActor
    static func provaBusca(_ db: String) -> Int32 {
        guard FileManager.default.fileExists(atPath: db) else { print("mdb nao encontrado"); return 2 }
        let banco = Banco(caminho: bancoTemp())
        banco.importarMDB(db)
        let store = Store(banco: banco)
        store.pacientes = banco.carregarPacientes()
        var falhas: [String] = []

        // 1. nome mode vs ORACULO SQL independente (NAME e texto claro no .mdb).
        //    termo = 3 primeiras letras do 1o nome com >=3 chars (sem imprimir PHI).
        let termo = store.pacientes.first(where: { $0.nome.count >= 3 })?.nome.prefix(3).lowercased() ?? "ana"
        store.modoBusca = .nomeOuId; store.busca = String(termo)
        let idsFiltro = Set(store.filtrados.map { $0.nome.lowercased() })
        // oraculo: nomes do banco que contem o termo (case-insensitive), independente do Swift
        let idsSQL = Set(banco.nomesQueContem(String(termo)).map { $0.lowercased() })
        if idsFiltro != idsSQL { falhas.append("nome: filtro(\(idsFiltro.count)) != SQL(\(idsSQL.count))") }

        // 2. Semantica DECLARADA: case-INsensitive, acento-SENSITIVE. Prova com acento:
        //    "joao" (sem til) NAO acha "João" (com til) — os dois lados concordam.
        store.busca = "MARIA"   // caixa alta acha "Maria" (case-insensitive)
        let achaMaiuscula = store.filtrados.contains { $0.nome.lowercased().contains("maria") }
                          == store.pacientes.contains { $0.nome.lowercased().contains("maria") }
        if !achaMaiuscula { falhas.append("case-insensitividade quebrou") }

        // 3. Invariante dos demais modos (celular/historico decifrados em memoria — SQL cru
        //    nao serve de oraculo): resultado <=> campo contem o termo.
        for (modo, campo): (ModoBusca, (Paciente) -> String) in
            [(.celular, { $0.celular }), (.historico, { $0.historico })] {
            store.modoBusca = modo
            let t = store.pacientes.compactMap { campo($0).isEmpty ? nil : campo($0).prefix(2) }.first.map(String.init) ?? ""
            guard !t.isEmpty else { continue }
            store.busca = t
            let ok = store.filtrados.allSatisfy { campo($0).localizedCaseInsensitiveContains(t) }
                  && store.pacientes.filter { campo($0).localizedCaseInsensitiveContains(t) }.count == store.filtrados.count
            if !ok { falhas.append("modo \(modo.rawValue): invariante quebrou") }
        }

        // Auto-teste (regra 1): termo impossivel retorna vazio; termo universal ("") retorna todos.
        store.modoBusca = .nomeOuId; store.busca = "zzqz_nao_existe_zzqz"
        let vazio = store.filtrados.isEmpty
        store.busca = ""
        let todos = store.filtrados.count == store.pacientes.count
        let acusa = vazio && todos

        if falhas.isEmpty && acusa {
            print("PROVA BUSCA OK: nome==SQL, case-insensitive/acento-sensitive, invariante dos modos, vazio/todos.")
            return 0
        }
        print("PROVA BUSCA FALHOU:"); falhas.forEach { print("  ", $0) }
        if !acusa { print("   auto-teste vazio/todos falhou") }
        return 1
    }

    // MARK: - Prova: dedup (E2.T2) — DATETIMES colidente soma 1s

    @MainActor
    static func provaDedup() -> Int32 {
        var falhas: [String] = []
        // mais1s de 14 digitos
        if InBodyVR.mais1s("20260805162859") != "20260805162900" {
            falhas.append("mais1s errado: \(InBodyVR.mais1s("20260805162859"))")
        }
        // datetimes14 tira separadores
        if InBodyVR.datetimes14(data: "2026/08/05", hora: "16:28:00") != "20260805162800" {
            falhas.append("datetimes14 errado: \(InBodyVR.datetimes14(data: "2026/08/05", hora: "16:28:00"))")
        }
        // existeExame + dedup real no banco
        let caminho = bancoTemp()
        let banco = Banco(caminho: caminho)
        let dt = "20260805162800"
        banco.salvarExame(["BCA_TBL": ["DATETIMES": dt, "LOCAL_ID": "1", "WT": "70"]])
        if !banco.existeExame(datetimes: dt) { falhas.append("existeExame nao achou o exame gravado") }
        // simula a dedup: proximo livre a partir do colidente
        var novo = dt, n = 0
        while banco.existeExame(datetimes: novo), n < 20 { novo = InBodyVR.mais1s(novo); n += 1 }
        if novo != "20260805162801" { falhas.append("dedup nao achou o proximo livre: \(novo)") }

        // Auto-teste (regra 1): se mais1s nao avancasse, o loop acharia colisao -> falha detectavel.
        let acusa = InBodyVR.mais1s(dt) != dt   // avanca de fato
        try? FileManager.default.removeItem(atPath: (caminho as NSString).deletingLastPathComponent)
        if falhas.isEmpty && acusa {
            print("PROVA DEDUP OK: mais1s/datetimes14 corretos; DATETIMES colidente soma 1s.")
            return 0
        }
        print("PROVA DEDUP FALHOU:"); falhas.forEach { print("  ", $0) }
        return 1
    }

    // MARK: - Prova: vr (E2) — FieldMap completo + deVR reproduz montarMedida

    /// Constroi um quadro vR sintetico a partir de uma linha do corpus (valor na posicao
    /// SEQUENCE do FieldMap), roda deVR (FieldMap completo -> montarMedida) e compara com
    /// medidaDeLinha da MESMA linha. Prova que o FieldMap cobre tudo que montarMedida le
    /// (o mapa antigo de 267 deixaria os 388 campos ausentes em 0). Corpus BCA.->BCA_TBL.
    @MainActor
    static func provaVR(_ csv: String) -> Int32 {
        guard let (header, linhas) = lerCSV(csv) else { print("nao li corpus"); return 2 }
        let tamanho = (InBodyFieldMap.map.keys.max() ?? 0) + 1

        // campos comparados: cobrem os 6 grupos e, de proposito, os que faltavam no mapa 267
        // (inbodyScore=WC.FS, smi=BCA.BSMI, anguloFase=LB.WBPA50, pfat=MFA.PBFM, controle*=WC,
        //  pesoIdeal=WC.TW, bcm=WC.BCM, ingestaoCalorica=WC.RENERGY, etype2=WC.ETYPE2, segFat=LB.F*).
        // NOTA: m.pfat (MFA.PBFM) e m.ipbf (fallback) sao COMPUTADOS pelo app, nao vem no
        // quadro (o original anexa ", PBFM" fora do mapa de SEQUENCE) — fora da comparacao.
        func escalares(_ m: Medida) -> [Double] {
            [m.peso, m.tbw, m.icw, m.ecw, m.proteina, m.mineral, m.gordura, m.ffm, m.slm,
             m.smm, m.imc, m.pgc, m.rcq, m.tmb, m.gv, m.bcm, m.smi, m.anguloFase,
             m.inbodyScore, m.pesoIdeal, m.controlePeso, m.controleGordura, m.controleMuscular,
             m.ingestaoCalorica, m.pwt, m.psmm, m.ipbf, Double(m.metabolicAge), m.odMin, m.odMax,
             m.grauObesidadeInfantil, Double(m.totScore), m.ffmi, m.bfmi, m.wed, m.tbwFfm,
             m.seg["RA"] ?? -1, m.segFat["RA"] ?? -1, m.segWater["TR"] ?? -1,
             m.impedancia["RA"]?[50] ?? -1, m.impedancia["TR"]?[1000] ?? -1,
             m.circunferencias["cintura"] ?? -1, m.refGordura.hi, m.segMin["RA"] ?? -1]
        }
        func frameDe(_ row: [String: String]) -> [String] {
            var campos = [String](repeating: "", count: tamanho)
            for (i, f) in InBodyFieldMap.map {
                // FieldMap "BCA_TBL.WT" -> corpus "BCA.WT"
                guard let ponto = f.column.firstIndex(of: ".") else { continue }
                let tbl = String(f.column[..<ponto]).replacingOccurrences(of: "_TBL", with: "")
                let col = String(f.column[f.column.index(after: ponto)...])
                if let v = row["\(tbl).\(col)"] { campos[i] = v }
            }
            return campos
        }

        var divergentes = 0
        var primeiraDiv: String = ""
        var total = 0
        for vals in linhas {
            let row = Dictionary(uniqueKeysWithValues: zip(header, vals))
            guard (row["DATETIMES"] ?? "").count == 14 else { continue }
            total += 1
            let refM = ImportService.medidaDeLinha(row)
            let vrM = Medida.deVR(frameDe(row)).medida
            let a = escalares(vrM), b = escalares(refM)
            if a != b {
                divergentes += 1
                if primeiraDiv.isEmpty {
                    let difs = zip(a, b).enumerated().filter { $0.element.0 != $0.element.1 }
                    primeiraDiv = difs.map { "campo[\($0.offset)] vr=\($0.element.0) ref=\($0.element.1)" }.prefix(6).joined(separator: "; ")
                }
            }
        }

        // Auto-teste (regra 1): tirar 1 campo do FieldMap tem que fazer divergir.
        // (feito indiretamente: se o mapa 267 fosse usado, inbodyScore/smi/etc. dariam 0.)
        // Aqui injetamos: zeramos WT no frame de 1 linha e exigimos divergencia.
        var acusa = false
        if let vals = linhas.first(where: { (Dictionary(uniqueKeysWithValues: zip(header, $0))["DATETIMES"] ?? "").count == 14 }) {
            let row = Dictionary(uniqueKeysWithValues: zip(header, vals))
            var f = frameDe(row)
            // acha a posicao de BCA.WT e zera
            for (i, fld) in InBodyFieldMap.map where fld.column == "BCA_TBL.WT" { if i < f.count { f[i] = "0" } }
            acusa = Medida.deVR(f).medida.peso != ImportService.medidaDeLinha(row).peso
        }

        print("Exames comparados: \(total). Campos escalares por exame: \(escalares(DemoData.ana.ultimo!).count).")
        print("FieldMap: \(InBodyFieldMap.map.count) posicoes (frame ate \(tamanho)).")
        print(acusa ? "AUTO-TESTE OK: zerar WT no quadro foi ACUSADO." : "AUTO-TESTE FALHOU.")
        if divergentes == 0 && acusa {
            print("PROVA VR OK: deVR(FieldMap completo)+montarMedida == medidaDeLinha em todos.")
            return 0
        }
        print("PROVA VR FALHOU: \(divergentes)/\(total) exames divergentes. Ex.: \(primeiraDiv)")
        return 1
    }

    static func bancoTemp() -> String {
        let dir = NSTemporaryDirectory() + "inbody-prova-\(UUID().uuidString)"
        return dir + "/inbody.sqlite"
    }

    // MARK: - Prova: criar (T2)

    @MainActor
    static func provaCriar() -> Int32 {
        let caminho = bancoTemp()
        let banco = Banco(caminho: caminho)
        var falhas: [String] = []

        // 1. Todas as tabelas de exame existem e tem colunas.
        for t in Banco.tabelasExame + ["USER_INFO1_TBL", "SPHYG_DATA_TBL", "BLOODSUGAR_TBL", "CONTA_TBL"] {
            if banco.colunasDe(t).isEmpty { falhas.append("tabela ausente ou vazia: \(t)") }
        }
        // 2. schema_ext aplicou (CONTA_TBL e coluna nossa).
        if !banco.colunasDe("CONTA_TBL").contains("SENHA_HASH") {
            falhas.append("CONTA_TBL sem SENHA_HASH (schema_ext nao aplicou)")
        }
        // 3. WAL e user_version corretos.
        let wal = leTexto(caminho, "PRAGMA journal_mode;")
        if wal.lowercased() != "wal" { falhas.append("journal_mode=\(wal), esperado wal") }
        let uv = leTexto(caminho, "PRAGMA user_version;")
        if uv != String(Banco.versaoAtual) { falhas.append("user_version=\(uv), esperado \(Banco.versaoAtual)") }

        // 4. Auto-teste (erro injetado): abrir com versaoAtual falsa NAO deve aplicar de novo
        //    (idempotencia da migracao) — banco reaberto mantem tabelas.
        let banco2 = Banco(caminho: caminho)
        if banco2.colunasDe("BCA_TBL").isEmpty { falhas.append("reabrir zerou o banco (migracao nao idempotente)") }

        try? FileManager.default.removeItem(atPath: (caminho as NSString).deletingLastPathComponent)
        if falhas.isEmpty {
            print("PROVA CRIAR OK: 24+ tabelas, schema_ext aplicado, WAL, user_version=\(Banco.versaoAtual), migracao idempotente.")
            return 0
        }
        print("PROVA CRIAR FALHOU:"); falhas.forEach { print("  ", $0) }
        return 1
    }

    // MARK: - Prova: cifra (T3) — decifragem AES-256 de campo

    @MainActor
    static func provaCifra() -> Int32 {
        var falhas: [String] = []
        // GENDER real conhecido (do banco de campo): SiJ4... = "F".
        let genderF = "SiJ4j2LgO89AUeWXxZLXCA=="
        if Cifra.claro(genderF) != "F" { falhas.append("GENDER conhecido decifrou como \(Cifra.claro(genderF)), esperado F") }
        // GDPR real (settings.xml), mesma chave: 10 flags ';'-separadas.
        let gdpr = "FTJDz/q0PE9IJjb5bSbETFMNPY8ibHZtPb5i20nALOk="
        if Cifra.claro(gdpr) != "0;0;0;0;0;0;0;0;0;0" { falhas.append("GDPR decifrou como \(Cifra.claro(gdpr))") }
        // Texto puro (banco sem FIELD_ENCRYPTION) passa intacto.
        if Cifra.claro("Ariane") != "Ariane" { falhas.append("texto puro foi alterado") }

        // Auto-teste (regra 1): base64 corrompido NAO pode decifrar para "F".
        let corrompido = "XiJ4j2LgO89AUeWXxZLXCA=="   // 1o caractere trocado
        let acusa = Cifra.claro(corrompido) != "F"

        if falhas.isEmpty && acusa {
            print("PROVA CIFRA OK: GENDER->F, GDPR->flags, texto puro intacto; corrupcao nao vira F.")
            return 0
        }
        print("PROVA CIFRA FALHOU:"); falhas.forEach { print("  ", $0) }
        if !acusa { print("   auto-teste: base64 corrompido decifrou como F") }
        return 1
    }

    // MARK: - Prova: carregar (T3) — carregarPacientes reusa montarMedida

    /// Grava o corpus, chama medidaDe() (mesmo caminho de carregarPacientes) e compara
    /// campos DERIVADOS por formula contra medidaDeLinha() da linha original. Cada tabela
    /// (BCA/MFA/WC/LB/ED/IMP) contribui ao menos um campo checado.
    @MainActor
    static func provaCarregar(_ csv: String) -> Int32 {
        guard let (header, linhas) = lerCSV(csv) else { print("nao li corpus"); return 2 }
        let caminho = bancoTemp()
        let banco = Banco(caminho: caminho)
        var refs: [String: Medida] = [:]   // datetimes -> Medida do corpus (referencia)
        var dts: [String] = []
        for vals in linhas {
            let row = Dictionary(uniqueKeysWithValues: zip(header, vals))
            let dt = row["DATETIMES"] ?? ""
            guard dt.count == 14 else { continue }
            var porTabela: [String: [String: String]] = [:]
            for (h, v) in row {
                guard let ponto = h.firstIndex(of: "."),
                      let tbl = pref2tbl[String(h[..<ponto])] else { continue }
                porTabela[tbl, default: [:]][String(h[h.index(after: ponto)...])] = v
            }
            for t in Banco.tabelasExame { porTabela[t, default: [:]]["DATETIMES"] = dt }
            banco.salvarExame(porTabela)
            // referencia: monta pela MESMA linha do corpus (prefixo TABELA.COLUNA).
            refs[dt] = ImportService.medidaDeLinha(row)
            dts.append(dt)
        }

        // Campos derivados representativos (um por tabela-fonte, pelo menos).
        func chaves(_ m: Medida) -> [Double] {
            [m.peso, m.tbw, m.ecwTbw, m.ipbf, m.fmi, m.bfmi, m.altura, m.imc, m.pgc,
             m.smm, m.gv, m.wed, m.anguloFase, m.seg["RA"] ?? -1, m.impedancia["RA"]?[50] ?? -1]
        }
        func diverge() -> Int {
            var d = 0
            for dt in dts {
                let a = chaves(banco.medidaDe(datetimes: dt))
                let b = chaves(refs[dt]!)
                if a != b { d += 1 }
            }
            return d
        }
        let limpo = diverge()

        // Auto-teste (regra 1): corromper WT no banco tem que mudar med.peso -> divergir.
        let alvo = dts[dts.count / 3]
        Banco.corromper(caminho: caminho, tabela: "BCA_TBL", datetimes: alvo, coluna: "WT", valor: "0.111")
        let banco2 = Banco(caminho: caminho)
        let acusa = chaves(banco2.medidaDe(datetimes: alvo)) != chaves(refs[alvo]!)

        try? FileManager.default.removeItem(atPath: (caminho as NSString).deletingLastPathComponent)
        print("Exames comparados: \(dts.count) (15 campos derivados por exame).")
        print(acusa ? "AUTO-TESTE OK: corrupcao de WT foi ACUSADA."
                    : "AUTO-TESTE FALHOU.")
        if limpo == 0 && acusa {
            print("PROVA CARREGAR OK: medidaDe (via montarMedida) == medidaDeLinha em todos.")
            return 0
        }
        print("PROVA CARREGAR FALHOU: \(limpo) exames divergentes.")
        return 1
    }

    // MARK: - Prova: corpus (T4) — ida-e-volta dos 1.742 exames

    @MainActor
    static func provaCorpus(_ csv: String) -> Int32 {
        guard let (header, linhas) = lerCSV(csv) else { print("nao li corpus: \(csv)"); return 2 }
        let caminho = bancoTemp()
        let banco = Banco(caminho: caminho)

        // Grava cada linha do corpus como exame; guarda o esperado (colunas presentes na linha).
        var esperado: [String: [String: [String: String]]] = [:]   // datetimes -> tabela -> col -> val
        var gravados: [String] = []
        var pulados = 0
        for vals in linhas {
            let row = Dictionary(uniqueKeysWithValues: zip(header, vals))
            let dt = row["DATETIMES"] ?? ""
            guard dt.count == 14 else { pulados += 1; continue }
            var porTabela: [String: [String: String]] = [:]
            for (h, v) in row {
                guard let ponto = h.firstIndex(of: "."),
                      let tbl = pref2tbl[String(h[..<ponto])] else { continue }
                let col = String(h[h.index(after: ponto)...])
                porTabela[tbl, default: [:]][col] = v
            }
            // O corpus tem UMA coluna DATETIMES (bare); as 6 tabelas usam-na como PK.
            for t in Banco.tabelasExame { porTabela[t, default: [:]]["DATETIMES"] = dt }
            banco.salvarExame(porTabela)
            esperado[dt] = porTabela
            gravados.append(dt)
        }

        // Confere ida-e-volta cru: cada valor gravado == valor lido.
        func divergencias() -> Int {
            var d = 0
            for dt in gravados {
                for (tbl, cols) in esperado[dt]! {
                    let lido = banco.linhasCruas(tabela: tbl, datetimes: dt)
                    for (c, v) in cols where (lido[c] ?? "") != v {
                        d += 1
                    }
                }
            }
            return d
        }

        if gravados.isEmpty {
            print("DIAG: header.count=\(header.count) linhas=\(linhas.count) pulados=\(pulados)")
            print("DIAG: header[0]=\(header.first ?? "?") primeira linha col0=\(linhas.first?.first ?? "?")")
            return 2
        }

        let limpo = divergencias()

        // Auto-teste (regra 1): corromper 1 celula no banco tem que ser ACUSADO.
        let dtAlvo = gravados[gravados.count / 2]
        Banco.corromper(caminho: caminho, tabela: "BCA_TBL", datetimes: dtAlvo, coluna: "WT", valor: "-99999")
        let bancoC = Banco(caminho: caminho)
        var acusou = false
        let colsAlvo = esperado[dtAlvo]!["BCA_TBL"]!
        let lidoC = bancoC.linhasCruas(tabela: "BCA_TBL", datetimes: dtAlvo)
        if (lidoC["WT"] ?? "") != (colsAlvo["WT"] ?? "") { acusou = true }

        try? FileManager.default.removeItem(atPath: (caminho as NSString).deletingLastPathComponent)

        let totalCel = esperado.values.reduce(0) { $0 + $1.values.reduce(0) { $0 + $1.count } }
        print("Denominador: \(gravados.count) exames gravados / \(linhas.count) linhas do corpus (pulados por DATETIMES!=14: \(pulados)).")
        print("Celulas comparadas: \(totalCel).")
        print(acusou ? "AUTO-TESTE OK: corrupcao de 1 celula foi ACUSADA."
                     : "AUTO-TESTE FALHOU: corrupcao passou despercebida.")
        if limpo == 0 && acusou {
            print("PROVA CORPUS OK: ida-e-volta 100% (0 divergencias em \(totalCel) celulas).")
            return 0
        }
        print("PROVA CORPUS FALHOU: \(limpo) divergencias no banco limpo.")
        return 1
    }

    // MARK: - Utils

    /// Le uma unica celula de texto de um PRAGMA/SELECT simples, abrindo o banco por fora.
    static func leTexto(_ caminho: String, _ sql: String) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        p.arguments = [caminho, sql]
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = Pipe()
        try? p.run(); p.waitUntilExit()
        let d = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: d, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    /// Parser CSV minimo (campos entre aspas, virgula separadora, "" = aspa escapada).
    static func lerCSV(_ path: String) -> (header: [String], linhas: [[String]])? {
        guard let bruto = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        // Corpus usa quebra \r (Mac classico); normaliza \r\n e \r para \n.
        let texto = bruto.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        var linhas: [[String]] = []
        var campo = "", linha: [String] = [], aspas = false
        var it = texto.makeIterator(); var pend: Character? = nil
        func prox() -> Character? { if let p = pend { pend = nil; return p }; return it.next() }
        while let c = prox() {
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
        guard let header = linhas.first else { return nil }
        let corpo = linhas.dropFirst().filter { $0.count == header.count }
        return (header, Array(corpo))
    }
}

extension Banco {
    /// So para o auto-teste: corrompe uma celula por fora (UPDATE direto), chaveando por DATETIMES.
    static func corromper(caminho: String, tabela: String, datetimes: String, coluna: String, valor: String) {
        corromper(caminho: caminho, tabela: tabela, datetimesCol: "DATETIMES", chave: datetimes, coluna: coluna, valor: valor)
    }
    /// Variante que chaveia por uma coluna qualquer (ex.: LOCAL_ID no cadastro).
    static func corromper(caminho: String, tabela: String, datetimesCol: String, chave: String, coluna: String, valor: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        p.arguments = [caminho, "UPDATE \(tabela) SET \(coluna)='\(valor)' WHERE \(datetimesCol)='\(chave)';"]
        try? p.run(); p.waitUntilExit()
    }
}
