import Foundation
import InBodyKit

/// Modos de busca do painel Select Member (manual p.34-40).
enum ModoBusca: String, CaseIterable, Identifiable {
    case nomeOuId = "Name or ID"
    case celular = "Mobile No."
    case historico = "Medical history"
    case grupo = "Group"
    case dataTeste = "InBody Test Date"
    var id: String { rawValue }
}

/// Ordenação da lista de membros.
enum Ordenacao: String, CaseIterable, Identifiable {
    case nomeAsc = "Name Ascending"
    case nomeDesc = "Name Descending"
    case idAsc = "ID Ascending"
    case idDesc = "ID Descending"
    var id: String { rawValue }
}

/// Conta de operador do LookinBody (manual p.21-22). Padrão inbody/0000.
struct Conta {
    var id: String
    var senha: String
    var email: String
    var ehPadrao: Bool
}

@MainActor
final class Store: ObservableObject {
    // Vazio no arranque: os dados vem do banco em carregar(), chamado pela UI (nao no
    // init, para o CLI/bancada nunca abrir o banco de producao — App.swift:init roda flags
    // e sai antes da UI). DemoData so alimenta bancada/preview.
    @Published var pacientes: [Paciente] = []
    @Published var config = ConfigClinica()   // config real da clinica (settings.xml)
    var banco: Banco?   // interno: a fusao de pacientes (FusaoPacientes.swift) tambem usa
    @Published var selecionado: Paciente.ID?          // membro destacado
    @Published var selecionados: Set<String> = []     // checkboxes (multi-select)
    @Published var busca: String = ""
    @Published var statusBalanca: String = "Disconnected"
    @Published var conectado: Bool = false
    @Published var ocupado: Bool = false
    @Published var modeloBalanca: String? = nil     // modelo que respondeu ao handshake (ex.: InBody770)
    @Published var meioConexao: String = ""         // "network" / "Bluetooth" / "USB" / "cable"
    @Published var tipoFolha: TipoFolha = .adulto

    // busca / ordenação (manual p.34-40)
    @Published var modoBusca: ModoBusca = .nomeOuId
    @Published var ordenacao: Ordenacao = .nomeAsc
    @Published var dataInicio: Date = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
    @Published var dataFim: Date = Date()
    @Published var usarIntervaloData: Bool = false    // ativado ao buscar por data

    // sessão / conta (manual p.21-27)
    @Published var logado: Bool = true   // sem login obrigatório: entra direto (Logout ainda funciona)
    @Published var conta = Conta(id: "inbody", senha: "0000", email: "", ehPadrao: true)
    @Published var ultimoLogin: String? = nil

    // opções GDPR (Setup > 11). Controlam consentimentos e 2FA (manual p.25, p.30)
    // Desligado por decisão do dono: cadastro NÃO exige aceite de termos/privacidade.
    @Published var gdprPrivacidadeAtiva: Bool = false
    @Published var doisFatoresHabilitado: Bool = false

    /// Imprime a folha automaticamente ao concluir o exame, na impressora padrão,
    /// sem diálogo (igual ao LookinBody do Windows). Setup 03 = Automatic Printing.
    @Published var imprimirAoConcluir: Bool = true

    // conexão do monitor de pressão (manual p.52). Botão/coluna BP só aparecem quando ligado.
    @Published var monitorPressaoConectado: Bool = false

    // IP e porta da balança (editáveis na tela de Conexão; persistidos).
    @Published var host: String = UserDefaults.standard.string(forKey: "InBodyMac.host") ?? "192.168.0.100" {
        didSet { UserDefaults.standard.set(host, forKey: "InBodyMac.host") }
    }
    @Published var porta: UInt16 = {
        let p = UserDefaults.standard.integer(forKey: "InBodyMac.porta"); return p > 0 ? UInt16(p) : 2004
    }() {
        didSet { UserDefaults.standard.set(Int(porta), forKey: "InBodyMac.porta") }
    }

    let versao = "Version 1.0.0"

    // MARK: - Filtro/ordenação

    var filtrados: [Paciente] {
        var r = pacientes
        let termo = busca.trimmingCharacters(in: .whitespaces)

        switch modoBusca {
        case .nomeOuId:
            if !termo.isEmpty {
                r = r.filter { $0.nome.localizedCaseInsensitiveContains(termo)
                    || $0.id.localizedCaseInsensitiveContains(termo) }
            }
        case .celular:
            if !termo.isEmpty { r = r.filter { $0.celular.localizedCaseInsensitiveContains(termo) } }
        case .historico:
            if !termo.isEmpty { r = r.filter { $0.historico.localizedCaseInsensitiveContains(termo) } }
        case .grupo:
            if !termo.isEmpty { r = r.filter { $0.grupo.localizedCaseInsensitiveContains(termo) } }
        case .dataTeste:
            if usarIntervaloData {
                let cal = Calendar.current
                let lo = cal.startOfDay(for: dataInicio)
                let hi = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: dataFim)) ?? dataFim
                r = r.filter { p in
                    p.exames.contains { e in
                        guard let d = Self.parseData(e.data) else { return false }
                        return d >= lo && d < hi
                    }
                }
            }
        }

        switch ordenacao {
        case .nomeAsc:  r.sort { $0.nome.localizedCompare($1.nome) == .orderedAscending }
        case .nomeDesc: r.sort { $0.nome.localizedCompare($1.nome) == .orderedDescending }
        case .idAsc:    r.sort { $0.id.localizedCompare($1.id) == .orderedAscending }
        case .idDesc:   r.sort { $0.id.localizedCompare($1.id) == .orderedDescending }
        }
        return r
    }

    static func parseData(_ s: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        for fmt in ["yyyy/MM/dd HH:mm", "yyyy/MM/dd"] {
            f.dateFormat = fmt
            if let d = f.date(from: String(s.prefix(fmt.count))) { return d }
        }
        return nil
    }

    var pacienteAtual: Paciente? {
        pacientes.first { $0.id == selecionado } ?? pacientes.first
    }

    /// Membros marcados por checkbox; se nenhum, cai no destacado. Usado por Print/E-mail/Edit/lote.
    var membrosAlvo: [Paciente] {
        if !selecionados.isEmpty { return pacientes.filter { selecionados.contains($0.chave) } }
        if let p = pacienteAtual { return [p] }
        return []
    }

    init() {}
    /// Injeta um banco (provas/testes); a UI usa init() + carregar() com Banco.shared.
    init(banco: Banco) { self.banco = banco }

    // MARK: - Persistencia (E1)

    /// Abre o banco e carrega os pacientes. Chamado pela UI ao aparecer (nunca no init).
    /// Faz um backup rotativo na abertura (provisorio ate a E5).
    func carregar() {
        let b = Banco.shared
        banco = b
        b.fazerBackup()
        pacientes = b.carregarPacientes()
        selecionado = pacientes.first?.id
    }

    /// Linha de USER_INFO1 a partir de um Paciente, com valores CLAROS (contrato 3: o
    /// nosso banco nao cifra; FIELD_ENCRYPTION='N').
    private func linhaUsuario(_ p: Paciente, localId: String) -> [String: String] {
        ["LOCAL_ID": localId, "USER_ID": p.id, "NAME": p.nome, "GENDER": p.sexo,
         "AGE": String(p.idade), "HEIGHT": String(Int(p.altura)), "BIRTHDAY": p.nascimento,
         "TEL_HP": p.celular, "E_MAIL": p.email, "MEDICAL_HISTORY": p.historico,
         "USER_REG_DATE": p.registro, "FIELD_ENCRYPTION": "N"]
    }

    /// Cadastra um paciente novo (grava no banco + memoria). LOCAL_ID = autonumber do banco.
    func cadastrar(_ p: Paciente) {
        var novo = p
        if let b = banco {
            let localId = b.proximoLocalId()
            novo.localId = localId
            b.salvarUsuario(linhaUsuario(novo, localId: localId))
        }
        pacientes.insert(novo, at: 0)
        selecionado = novo.id
    }

    /// Salva edicao do cadastro (Member Info / Edit). UPDATE (nao INSERT): a linha existe.
    func salvarEdicao(_ p: Paciente) {
        if let b = banco, !p.localId.isEmpty {
            b.atualizarUsuario(linhaUsuario(p, localId: p.localId))
        }
        if let i = pacientes.firstIndex(where: { $0.id == p.id }) { pacientes[i] = p }
    }

    /// Exclui um paciente (cadastro + todos os exames) do banco e da memoria.
    func excluir(_ id: Paciente.ID) {
        if let b = banco, let p = pacientes.first(where: { $0.id == id }), !p.localId.isEmpty {
            b.apagarUsuario(localId: p.localId)
        }
        pacientes.removeAll { $0.id == id }
        if selecionado == id { selecionado = pacientes.first?.id }
    }

    /// Anexa um exame (vindo da balanca) ao paciente: grava as 6 tabelas + insere a Medida.
    /// Dedup do original (contrato 2): se o DATETIMES ja existe, soma 1s ate achar livre (20x).
    func anexarExame(_ m: Medida, cru: [String: [String: String]], raw: String = "", a id: Paciente.ID) {
        guard let i = pacientes.firstIndex(where: { $0.id == id }) else { return }
        var medida = m
        if let b = banco {
            var tabelas = cru
            tabelas["BCA_TBL", default: [:]]["LOCAL_ID"] = pacientes[i].localId
            var dt = tabelas["BCA_TBL"]?["DATETIMES"] ?? m.data
            var n = 0
            while b.existeExame(datetimes: dt), n < 20 { dt = InBodyVR.mais1s(dt); n += 1 }
            for t in Banco.tabelasExame { tabelas[t, default: [:]]["DATETIMES"] = dt }
            b.salvarExame(tabelas)
            if !raw.isEmpty {   // arquiva o quadro cru (TempMeasureData_TBL do original)
                b.salvarTemp(datetimes: dt, raw: raw, equip: tabelas["BCA_TBL"]?["EQUIP"] ?? "")
            }
            if dt != m.data {   // DATETIMES mudou: reconstroi a Medida p/ a lista bater com o banco
                medida = ImportService.montarMedida(
                    tabelas["BCA_TBL"] ?? [:], tabelas["MFA_TBL"] ?? [:], tabelas["WC_TBL"] ?? [:],
                    tabelas["LB_TBL"] ?? [:], tabelas["ED_TBL"] ?? [:], tabelas["IMP_TBL"] ?? [:],
                    alturaCadastro: pacientes[i].altura)
            }
        }
        pacientes[i].exames.insert(medida, at: 0)
    }

    /// Exclui um exame do paciente (por DATETIMES).
    func excluirExame(datetimes: String, de id: Paciente.ID) {
        banco?.apagarExame(datetimes: datetimes)
        if let i = pacientes.firstIndex(where: { $0.id == id }) {
            pacientes[i].exames.removeAll { $0.data == datetimes }
        }
    }

    /// Aplica ao banco as EXCLUSOES de um draft do gerenciador de resultados (membros e
    /// exames apagados), grava DATAS de exame editadas (renomeia as 6 tabelas — E4) e o
    /// cadastro editado, e adota o draft em memoria. Auditoria 11/08/2026: antes, editar a
    /// data de um exame so mudava na tela e o valor antigo voltava ao reabrir o app.
    func reconciliar(draft: [Paciente]) {
        var draft = draft
        if let b = banco {
            let idsDraft = Set(draft.map { $0.id })
            for p in pacientes where !idsDraft.contains(p.id) && !p.localId.isEmpty {
                b.apagarUsuario(localId: p.localId)
            }
            let origPorId = Dictionary(uniqueKeysWithValues: pacientes.map { ($0.id, $0) })
            for di in draft.indices {
                let d = draft[di]
                guard let orig = origPorId[d.id] else { continue }
                // 1. Data de exame editada -> renomeia no banco. Casa o exame antigo com o
                //    novo pelos valores (peso/MME/gordura), que a grade nao deixa editar.
                let dtsOrig = Set(orig.exames.map { $0.data })
                let dtsDraft = Set(d.exames.map { $0.data })
                var apagados: [Medida] = []
                for e in orig.exames where !dtsDraft.contains(e.data) {
                    if let j = draft[di].exames.firstIndex(where: { !dtsOrig.contains($0.data)
                            && $0.peso == e.peso && $0.smm == e.smm && $0.gordura == e.gordura }) {
                        if let novo = Store.normalizaDatetimes(draft[di].exames[j].data),
                           novo != e.data, !b.existeExame(datetimes: novo) {
                            b.renomearExame(de: e.data, para: novo)
                            draft[di].exames[j].data = novo
                        } else {
                            // data invalida ou ja ocupada: reverte na grade, banco intacto
                            draft[di].exames[j].data = e.data
                        }
                    } else {
                        apagados.append(e)
                    }
                }
                // 2. exames realmente apagados
                for e in apagados { b.apagarExame(datetimes: e.data) }
                // 3. campos de cadastro editados na grade -> persiste (UPDATE)
                if !d.localId.isEmpty && cadastroMudou(orig, d) {
                    b.atualizarUsuario(linhaUsuario(d, localId: d.localId))
                }
            }
        }
        pacientes = draft
    }

    /// Normaliza o que foi digitado na grade para o DATETIMES do banco (yyyyMMddHHmmss).
    /// Aceita "20260810012401", "2026/08/10 01:24" e "10.08.2026 01:24". nil se invalido.
    nonisolated static func normalizaDatetimes(_ s: String) -> String? {
        var dig = s.filter { $0.isNumber }
        guard dig.count == 8 || dig.count == 12 || dig.count == 14 else { return nil }
        if dig.count == 8 { dig += "000000" }   // so a data, sem hora
        if dig.count == 12 { dig += "00" }      // sem segundos
        let a = Array(dig)
        if let ano = Int(String(a[0..<4])), (1900...2100).contains(ano) {
            return dig
        }
        // veio dia-primeiro (dd MM yyyy): reordena
        let dd = String(a[0..<2]), mm = String(a[2..<4]), yyyy = String(a[4..<8])
        guard let ano = Int(yyyy), (1900...2100).contains(ano),
              let mes = Int(mm), (1...12).contains(mes),
              let dia = Int(dd), (1...31).contains(dia) else { return nil }
        return yyyy + mm + dd + String(a[8..<14])
    }

    /// Algum campo persistido do cadastro mudou entre duas versoes do paciente?
    private func cadastroMudou(_ a: Paciente, _ b: Paciente) -> Bool {
        a.nome != b.nome || a.sexo != b.sexo || a.idade != b.idade || a.altura != b.altura
            || a.celular != b.celular || a.email != b.email || a.nascimento != b.nascimento
            || a.historico != b.historico
    }

    /// Importa um .mdb de campo para dentro do banco e recarrega. Devolve o aviso.
    func importarDe(mdb: String) -> String {
        if banco == nil { banco = Banco.shared }
        // carrega a config real da clinica do settings.xml que acompanha o .mdb
        config = ConfigClinica.carregar(dir: (mdb as NSString).deletingLastPathComponent)
        let (u, e) = banco!.importarMDB(mdb)
        pacientes = banco!.carregarPacientes()
        selecionado = pacientes.first?.id
        return "Importados \(u) pacientes e \(e) exames."
    }

    // MARK: - Autenticação (manual p.21-27)

    /// Valida credenciais contra a conta armazenada. Retorna true se OK.
    func autenticar(id: String, senha: String) -> Bool {
        guard id == conta.id, senha == conta.senha else { return false }
        registrarLogin()
        return true
    }

    /// Detecta o primeiro login com a conta padrão inbody/0000.
    func ehLoginPadrao(id: String, senha: String) -> Bool {
        conta.ehPadrao && id == "inbody" && senha == "0000"
    }

    func registrarLogin() {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy.MM.dd. HH:mm:ss"
        ultimoLogin = f.string(from: Date())
        logado = true
    }

    func logout() {
        logado = false
        selecionados.removeAll()
    }

    /// Aplica a troca de conta do popup Change Account (manual p.22).
    func trocarConta(id: String, senha: String, email: String) {
        conta = Conta(id: id, senha: senha, email: email, ehPadrao: false)
    }

    /// Regra de senha (manual p.22): >=8, maiúscula + minúscula + caractere especial.
    static func senhaValida(_ s: String) -> Bool {
        guard s.count >= 8 else { return false }
        let temMaiuscula = s.contains { $0.isUppercase }
        let temMinuscula = s.contains { $0.isLowercase }
        let especiais = CharacterSet(charactersIn: "!@#$%^&*()-_=+[]{};:'\",.<>/?\\|`~")
        let temEspecial = s.unicodeScalars.contains { especiais.contains($0) }
        return temMaiuscula && temMinuscula && temEspecial
    }

    /// Como a balança está conectada (para o exame ao vivo saber o caminho).
    @Published var portaSerial: String? = nil     // /dev/cu.* se conectou por serial (dongle/USB/cabo)
    @Published var baudSerial: UInt32 = 115200     // velocidade que funcionou nessa porta

    /// Velocidades dos meios seriais do original: dongle Bluetooth 115200, USB 19200, cabo 9600.
    nonisolated static let baudsSeriais: [UInt32] = [115200, 19200, 9600]

    /// Testa a comunicação com a balança. Tenta a REDE (WiFi/LAN) e, se não achar, varre
    /// cada porta serial (/dev/cu.*) do dongle Bluetooth / USB / cabo, em cada velocidade —
    /// o mesmo aperto de mão em todas; a certa é a que responde.
    func conectar() {
        ocupado = true
        statusBalanca = T("Connecting…")
        let host = host, porta = porta
        Task.detached {
            var modelo: String? = Self.tentarHandshake { InBodySession(host: host, port: porta) }
            var dev: String? = nil
            var baud: UInt32 = 115200
            var meio = "network"
            if modelo == nil {
                busca: for p in PortTransport.portasSeriais() {
                    for b in Self.baudsSeriais {
                        if let m = Self.tentarHandshake(via: { InBodySession(serialDevice: p, baud: speed_t(b)) }) {
                            modelo = m; dev = p; baud = b
                            meio = b == 115200 ? "Bluetooth" : (b == 19200 ? "USB" : "cable")
                            break busca
                        }
                    }
                }
            }
            let modeloF = modelo, devF = dev, baudF = baud, meioF = meio
            await MainActor.run {
                self.ocupado = false
                self.portaSerial = devF
                self.baudSerial = baudF
                if let m = modeloF {
                    self.conectado = true
                    self.modeloBalanca = m
                    self.meioConexao = meioF
                    self.statusBalanca = "\(m) : \(T("Connected")) (\(T(meioF)))"
                } else {
                    self.conectado = false
                    self.modeloBalanca = nil
                    self.meioConexao = ""
                    self.statusBalanca = T("Disconnected")
                }
            }
        }
    }

    /// Conecta SÓ pela rede (WiFi/LAN), no IP/porta atuais. Sem varrer serial.
    func conectarRede() {
        ocupado = true; statusBalanca = T("Connecting…")
        let host = host, porta = porta
        Task.detached {
            let m = Self.tentarHandshake(via: { InBodySession(host: host, port: porta) })
            await self.aplicarResultado(modelo: m, dev: nil, baud: 115200, meio: "network")
        }
    }

    /// Conecta numa porta serial ESPECÍFICA (Bluetooth/USB/cabo), na velocidade escolhida.
    func conectarSerial(dev: String, baud: UInt32) {
        ocupado = true; statusBalanca = T("Connecting…")
        Task.detached {
            let m = Self.tentarHandshake(via: { InBodySession(serialDevice: dev, baud: speed_t(baud)) })
            let meio = baud == 115200 ? "Bluetooth" : (baud == 19200 ? "USB" : "cable")
            await self.aplicarResultado(modelo: m, dev: dev, baud: baud, meio: meio)
        }
    }

    /// Aplica o resultado de uma tentativa de conexão ao estado observável.
    @MainActor private func aplicarResultado(modelo: String?, dev: String?, baud: UInt32, meio: String) {
        ocupado = false
        portaSerial = dev
        baudSerial = baud
        if let m = modelo {
            conectado = true; modeloBalanca = m; meioConexao = meio
            statusBalanca = "\(m) : \(T("Connected")) (\(T(meio)))"
        } else {
            conectado = false; modeloBalanca = nil; meioConexao = ""
            statusBalanca = T("Disconnected")
        }
    }

    /// Faz o aperto de mão numa sessão e devolve o modelo se passou (nil caso contrário).
    nonisolated private static func tentarHandshake(via criar: () -> InBodySession?) -> String? {
        guard let s = criar(), let r = s.handshake(), r.passed else { return nil }
        let modelo = InBodyProtocol.fields(r.deviceInfo).first ?? "InBody"
        return modelo.replacingOccurrences(of: "P0", with: "")
    }
}
