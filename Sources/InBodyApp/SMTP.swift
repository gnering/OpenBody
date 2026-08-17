import Foundation


/// Configuração de e-mail (Setup A-05). Espelha os campos do original: Host, User, Name,
/// Password, Port. A senha vai no Keychain, nunca no arquivo de preferências.
struct ConfigEmail: Codable {
    /// Como o original (A-05): a conta que vem com o LookinBody, ou a do próprio médico.
    enum Conta: String, Codable { case inbody, propria }

    /// Padrão = conta PRÓPRIA. A conta embutida da InBody NÃO é mais usada para enviar
    /// (o padrão do app virou o "plano B": abrir o Mail do usuário com o anexo pronto).
    var conta: Conta = .propria
    var host = ""
    var usuario = ""
    var nomeExibicao = ""
    var porta = 465
    /// true = TLS desde a conexão (porta 465, o modo que a maioria dos provedores aceita).
    var tlsDireto = true

    private static let chave = "InBodyMac.email"

    static func carregar() -> ConfigEmail {
        guard let d = UserDefaults.standard.data(forKey: chave),
              let c = try? JSONDecoder().decode(ConfigEmail.self, from: d) else { return ConfigEmail() }
        return c
    }
    func salvar() {
        if let d = try? JSONEncoder().encode(self) { UserDefaults.standard.set(d, forKey: Self.chave) }
    }

    /// Só é "configurado" quando o usuário preencheu o PRÓPRIO servidor (host+usuário+senha).
    /// Sem isso, o envio cai no plano B (abre o Mail com o anexo).
    var configurado: Bool {
        !host.isEmpty && !usuario.isEmpty && Keychain.senhaEmail() != nil
    }

    /// Os dados que o envio realmente usa (host/usuário/senha/porta), já resolvidos.
    func resolvida() -> (host: String, usuario: String, senha: String, nome: String,
                         porta: UInt16, tls: Bool)? {
        guard let s = Keychain.senhaEmail(), !host.isEmpty, !usuario.isEmpty else { return nil }
        return (host, usuario, s, nomeExibicao, UInt16(porta), tlsDireto)
    }
}

/// Conta de e-mail que ACOMPANHA o LookinBody (Setup A-05 "InBody account"): o original
/// guarda servidor/usuário/senha cifrados em Settings.mdb.EMAIL_ACCOUNT_TBL e envia por ela
/// sem pedir nada ao médico. Aqui os valores vêm de ContaInBodyGerada (extraído do MESMO
/// recurso original por tools/extrai_conta_email.sh) e são decifrados com a chave de campo.
enum ContaInBody {
    static var disponivel: Bool { credenciais() != nil }

    static func credenciais() -> (host: String, usuario: String, senha: String, nome: String,
                                  porta: UInt16, tls: Bool)? {
        let host = Cifra.claro(ContaInBodyGerada.hostCifrado)
        let user = Cifra.claro(ContaInBodyGerada.usuarioCifrado)
        let senha = Cifra.claro(ContaInBodyGerada.senhaCifrada)
        guard !host.isEmpty, host.contains("."), !user.isEmpty, !senha.isEmpty else { return nil }
        return (host, user, senha, ContaInBodyGerada.nomeExibicao,
                UInt16(ContaInBodyGerada.porta), ContaInBodyGerada.ssl == 1)
    }
}

/// Senha do e-mail no Keychain do macOS (não fica em texto em lugar nenhum).
enum Keychain {
    private static let servico = "InBodyMac.email"

    static func salvarSenhaEmail(_ senha: String, conta: String) {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: servico,
                                   kSecAttrAccount as String: conta]
        SecItemDelete(base as CFDictionary)
        var novo = base
        novo[kSecValueData as String] = Data(senha.utf8)
        SecItemAdd(novo as CFDictionary, nil)
        UserDefaults.standard.set(conta, forKey: servico + ".conta")
    }

    static func senhaEmail() -> String? {
        guard let conta = UserDefaults.standard.string(forKey: servico + ".conta") else { return nil }
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: servico,
                                kSecAttrAccount as String: conta,
                                kSecReturnData as String: true,
                                kSecMatchLimit as String: kSecMatchLimitOne]
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess,
              let d = item as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    // ----- senha do bloqueio automático (A-08) -----
    private static let servicoLock = "InBodyMac.autolock"
    private static let contaLock = "autolock"

    static func salvarSenhaAutoLock(_ senha: String) {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: servicoLock,
                                   kSecAttrAccount as String: contaLock]
        SecItemDelete(base as CFDictionary)
        var novo = base
        novo[kSecValueData as String] = Data(senha.utf8)
        SecItemAdd(novo as CFDictionary, nil)
    }

    static func senhaAutoLock() -> String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: servicoLock,
                                kSecAttrAccount as String: contaLock,
                                kSecReturnData as String: true,
                                kSecMatchLimit as String: kSecMatchLimitOne]
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess,
              let d = item as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    static func temSenhaAutoLock() -> Bool { senhaAutoLock() != nil }
}

/// Cliente SMTP mínimo (EHLO / AUTH LOGIN / MAIL / RCPT / DATA), com anexo.
/// Bloqueante: o chamador roda fora da thread principal.
enum SMTP {
    enum Falha: LocalizedError {
        case semConfig, conexao(String), protocolo(String)
        var errorDescription: String? {
            switch self {
            case .semConfig:      return T("Set up email in Settings > E-mail Options.")
            case .conexao(let m): return T("Could not reach the email server:") + " \(m)"
            case .protocolo(let m): return T("The email server refused:") + " \(m)"
            }
        }
    }

    /// Envia uma mensagem com 0..n anexos. `paraNome` é só cosmético no cabeçalho.
    static func enviar(para: String, assunto: String, corpo: String,
                       anexos: [(nome: String, dados: Data, mime: String)] = []) throws {
        let cfg = ConfigEmail.carregar()
        guard let c = cfg.resolvida() else { throw Falha.semConfig }

        // 465 = TLS desde a conexão. 587 (Office365, o da conta InBody) = conecta em claro,
        // manda STARTTLS e sobe a criptografia na MESMA conexão.
        let tlsDireto = (c.porta == 465)
        let sessao = try Sessao(host: c.host, porta: c.porta, tlsDireto: tlsDireto)
        defer { sessao.fechar() }

        try sessao.esperar(codigo: "220")
        try sessao.comando("EHLO inbodymac", espera: "250")
        if !tlsDireto && c.tls {
            try sessao.comando("STARTTLS", espera: "220")
            sessao.ligarTLS()
            try sessao.comando("EHLO inbodymac", espera: "250")   // reapresentar após o TLS
        }
        try sessao.comando("AUTH LOGIN", espera: "334")
        try sessao.comando(Data(c.usuario.utf8).base64EncodedString(), espera: "334")
        try sessao.comando(Data(c.senha.utf8).base64EncodedString(), espera: "235")
        try sessao.comando("MAIL FROM:<\(c.usuario)>", espera: "250")
        try sessao.comando("RCPT TO:<\(para)>", espera: "250")
        try sessao.comando("DATA", espera: "354")
        sessao.escrever(mensagem(de: cfg, para: para, assunto: assunto, corpo: corpo, anexos: anexos))
        try sessao.comando(".", espera: "250")
        try? sessao.comando("QUIT", espera: "221")
    }

    /// MIME multipart/mixed: corpo em texto + anexos em base64.
    private static func mensagem(de cfg: ConfigEmail, para: String, assunto: String,
                                 corpo: String,
                                 anexos: [(nome: String, dados: Data, mime: String)]) -> String {
        let c = cfg.resolvida()
        let sep = "----InBodyMac\(UUID().uuidString)"
        let dt = DateFormatter()
        dt.locale = Locale(identifier: "en_US_POSIX")
        dt.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        let nomeEx = c?.nome ?? cfg.nomeExibicao; let usuarioEx = c?.usuario ?? cfg.usuario
        let remetente = nomeEx.isEmpty ? usuarioEx
            : "=?UTF-8?B?\(Data(nomeEx.utf8).base64EncodedString())?= <\(usuarioEx)>"

        var m = ""
        m += "From: \(remetente)\r\n"
        m += "To: <\(para)>\r\n"
        m += "Subject: =?UTF-8?B?\(Data(assunto.utf8).base64EncodedString())?=\r\n"
        m += "Date: \(dt.string(from: Date()))\r\n"
        m += "MIME-Version: 1.0\r\n"
        m += "Content-Type: multipart/mixed; boundary=\"\(sep)\"\r\n\r\n"
        m += "--\(sep)\r\n"
        m += "Content-Type: text/plain; charset=UTF-8\r\n"
        m += "Content-Transfer-Encoding: base64\r\n\r\n"
        m += quebrar(Data(corpo.utf8).base64EncodedString()) + "\r\n"
        for a in anexos {
            m += "--\(sep)\r\n"
            m += "Content-Type: \(a.mime); name=\"\(a.nome)\"\r\n"
            m += "Content-Transfer-Encoding: base64\r\n"
            m += "Content-Disposition: attachment; filename=\"\(a.nome)\"\r\n\r\n"
            m += quebrar(a.dados.base64EncodedString()) + "\r\n"
        }
        m += "--\(sep)--\r\n"
        return m
    }

    /// base64 em linhas de 76 (limite do SMTP).
    private static func quebrar(_ s: String) -> String {
        stride(from: 0, to: s.count, by: 76).map { i -> String in
            let a = s.index(s.startIndex, offsetBy: i)
            let b = s.index(a, offsetBy: min(76, s.count - i))
            return String(s[a..<b])
        }.joined(separator: "\r\n")
    }

    /// Conexão TCP (com ou sem TLS) falando linhas SMTP.
    /// Transporte por par de streams do CoreFoundation. É o único jeito no macOS de subir
    /// TLS numa conexão JÁ ABERTA (STARTTLS): o Network.framework não faz upgrade no meio,
    /// e a conta da InBody é Office365 na 587, que exige exatamente isso.
    private final class Sessao {
        private var entrada: InputStream!
        private var saida: OutputStream!
        private var buffer = Data()

        init(host: String, porta: UInt16, tlsDireto: Bool) throws {
            var i: InputStream?; var o: OutputStream?
            Stream.getStreamsToHost(withName: host, port: Int(porta), inputStream: &i, outputStream: &o)
            guard let i, let o else { throw Falha.conexao("não abri conexão com \(host):\(porta)") }
            entrada = i; saida = o
            if tlsDireto {
                entrada.setProperty(StreamSocketSecurityLevel.negotiatedSSL, forKey: .socketSecurityLevelKey)
                saida.setProperty(StreamSocketSecurityLevel.negotiatedSSL, forKey: .socketSecurityLevelKey)
            }
            entrada.open(); saida.open()
            let limite = Date().addingTimeInterval(20)
            while Date() < limite {
                if saida.streamStatus == .open || saida.streamStatus == .writing { return }
                if saida.streamStatus == .error || entrada.streamStatus == .error {
                    throw Falha.conexao(saida.streamError?.localizedDescription ?? "erro de conexão")
                }
                usleep(20_000)
            }
            throw Falha.conexao("tempo esgotado abrindo a conexão")
        }

        /// STARTTLS: sobe a criptografia na MESMA conexão, depois do 220 do servidor.
        func ligarTLS() {
            entrada.setProperty(StreamSocketSecurityLevel.negotiatedSSL, forKey: .socketSecurityLevelKey)
            saida.setProperty(StreamSocketSecurityLevel.negotiatedSSL, forKey: .socketSecurityLevelKey)
            usleep(150_000)   // deixa o handshake acontecer antes do próximo comando
        }

        func escrever(_ s: String) {
            let bytes = [UInt8](s.utf8)
            var enviados = 0
            let limite = Date().addingTimeInterval(30)
            while enviados < bytes.count, Date() < limite {
                if !saida.hasSpaceAvailable { usleep(10_000); continue }
                let n = bytes[enviados...].withUnsafeBufferPointer {
                    saida.write($0.baseAddress!, maxLength: bytes.count - enviados)
                }
                if n <= 0 { break }
                enviados += n
            }
        }

        /// Lê uma resposta SMTP completa (última linha sem '-' depois do código).
        func lerResposta() throws -> String {
            let limite = Date().addingTimeInterval(30)
            var buf = [UInt8](repeating: 0, count: 65536)
            while Date() < limite {
                if let r = respostaCompleta() { return r }
                if entrada.streamStatus == .error {
                    throw Falha.conexao(entrada.streamError?.localizedDescription ?? "erro de leitura")
                }
                if !entrada.hasBytesAvailable { usleep(20_000); continue }
                let n = entrada.read(&buf, maxLength: buf.count)
                if n > 0 { buffer.append(contentsOf: buf[0..<n]) }
                else if n < 0 { throw Falha.conexao("conexão caiu") }
            }
            throw Falha.conexao("tempo esgotado esperando o servidor")
        }

        private func respostaCompleta() -> String? {
            guard let txt = String(data: buffer, encoding: .utf8) else { return nil }
            let linhas = txt.components(separatedBy: "\r\n").filter { !$0.isEmpty }
            guard let ultima = linhas.last, ultima.count >= 4 else { return nil }
            let i = ultima.index(ultima.startIndex, offsetBy: 3)
            guard ultima[i] == " " else { return nil }   // "250-" = tem continuação
            buffer.removeAll()
            return txt
        }

        func esperar(codigo: String) throws {
            let r = try lerResposta()
            guard r.hasPrefix(codigo) else { throw Falha.protocolo(r.trimmingCharacters(in: .whitespacesAndNewlines)) }
        }

        func comando(_ c: String, espera: String) throws {
            escrever(c + "\r\n")
            try esperar(codigo: espera)
        }

        func fechar() { entrada?.close(); saida?.close() }
    }
}
