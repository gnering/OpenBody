import Foundation

/// Configuração persistente do Setup (as opções que antes eram só cenográficas).
/// Segue o padrão de ConfigEmail/CustomLogoConfig: struct Codable salva em UserDefaults.
/// Lida em runtime por quem precisa do valor (impressão, bloqueio, login).
struct SetupConfig: Codable, Equatable {
    // A-01 País/Idioma/Unidades/Formato de data
    var pais = "Brazil"
    var unidade = 0            // 0 kg/cm · 1 lb/ft in
    var formatoData = 2        // 0 AMD · 1 MDA · 2 DMA (só vale se formatoDataManual)
    var formatoDataManual = false   // false = segue o idioma; true = o usuário escolheu

    // A-03 Folhas/Papel/Impressão
    var folhasImpressao: Set<String> = [TipoFolha.adulto.rawValue, TipoFolha.agua.rawValue]
    var tipoPapel = 0          // 0 A4 branco · 1 papel InBody
    var copias = 1             // 1 ou 2
    var imprimirAutomaticamente = true

    // A-08 Bloqueio automático
    var autoLockAtivo = false
    var autoLockMin = 5

    // A-09 Dados do suporte (preenchidos pela clínica; sem dados de terceiros)
    var suporteTel = ""
    var suporteNome = "OpenBody"
    var suporteFax = ""
    var suporteEmail = ""
    var suporteSite = ""
    var suporteEndereco = ""

    // A-11 Opções LGPD (persistidas; comportamento ligado: usarLogin)
    var usarLogin = false
    var usarContaUsuario = false
    var usarAutoridade = false
    var trocarSenha3Meses = false
    var verificacaoResponsavel = false
    var termoPrivacidade = false
    var mascaramento1 = false
    var mascaramento2 = false
    var autoID = false
    var termoDados = false
    var logsUsuario = false

    // B-01 Modelo InBody / estadiômetro
    var inbodyModelo = "InBody770"
    var estadiometroConectado = false

    // B-02 Serviço de nuvem
    var cloudAtivo = false

    // B-03 Itens/Interpretações
    var comValores = true      // true = com valores · false = sem valores

    // B-05 Pastas de destino do EMR (vazio = perguntar na hora)
    var emrImagemDir = ""
    var emrCsvDir = ""
    var emrOrderDir = ""

    // B-04 Faixa de referência
    var curvaCrescimento = 0   // 0 CDC-2000 · 1 WHO 2007 · 2 UK · 3 Suíça
    var opcaoIMC = 0           // 0/1/2 (faixa normal de IMC)
    var opcaoIMCIdeal = 0      // 0/1 (valor ideal de IMC)

    // ----- persistência -----
    static let chave = "InBodyMac.setup"

    static func carregar() -> SetupConfig {
        guard let d = UserDefaults.standard.data(forKey: chave),
              let c = try? JSONDecoder().decode(SetupConfig.self, from: d) else { return SetupConfig() }
        return c
    }

    func salvar() {
        if let d = try? JSONEncoder().encode(self) { UserDefaults.standard.set(d, forKey: Self.chave) }
    }

    /// Índice de formato que vale de fato: o manual (se o usuário escolheu) ou o padrão do idioma.
    var formatoDataEfetivo: Int { formatoDataManual ? formatoData : Idioma.padraoFormatoData }

    /// Formato de data no padrão do aparelho (com ponto final, ex.: "16.08.2026.").
    var dateFormatString: String {
        switch formatoDataEfetivo {
        case 1:  return "MM.dd.yyyy."
        case 2:  return "dd.MM.yyyy."
        default: return "yyyy.MM.dd."
        }
    }

    /// Liga a escolha do Setup às datas do app (folhas, histórico, relatório).
    func aplicarFormatoData() {
        SheetSettings.dateFormat = dateFormatString
    }

    /// Folhas escolhidas para impressão, na ordem canônica (só os tipos que o app desenha).
    var folhasParaImprimir: Set<TipoFolha> {
        Set(TipoFolha.allCases.filter { folhasImpressao.contains($0.rawValue) })
    }

    /// Volta as opções de saída/impressão ao padrão de fábrica (B-03 Restore Default).
    /// Não mexe em pacientes nem em dados clínicos.
    mutating func restaurarPadraoSaida() {
        comValores = true
        folhasImpressao = [TipoFolha.adulto.rawValue, TipoFolha.agua.rawValue]
        copias = 1
        tipoPapel = 0
    }
}

/// Dados REAIS da máquina para a tela A-10 (antes eram fixos falsos).
enum InfoMaquina {
    static var versaoApp: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(v) (\(b))"
    }

    static var nomeComputador: String {
        Host.current().localizedName ?? ProcessInfo.processInfo.hostName
    }

    /// IPv4 da interface ativa (en0/en1). "-" se offline.
    static var ipLocal: String {
        var addr = "-"
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return addr }
        defer { freeifaddrs(ifaddr) }
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let p = ptr {
            let flags = Int32(p.pointee.ifa_flags)
            let iface = p.pointee.ifa_addr.pointee
            if (flags & (IFF_UP | IFF_RUNNING)) == (IFF_UP | IFF_RUNNING),
               iface.sa_family == UInt8(AF_INET) {
                let nome = String(cString: p.pointee.ifa_name)
                if nome == "en0" || nome == "en1" {
                    var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(p.pointee.ifa_addr, socklen_t(iface.sa_len),
                                   &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                        addr = String(cString: host)
                    }
                }
            }
            ptr = p.pointee.ifa_next
        }
        return addr
    }
}
