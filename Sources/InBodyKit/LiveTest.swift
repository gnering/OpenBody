import Foundation

/// Medição InBody ao vivo: conecta, faz o aperto de mão e conduz a máquina de
/// estados da medição conforme ConBasicUserCon.cs (NewReceiveDataAnalysis).
/// Fluxo: P0/P1 -> sR(zvO) -> poll sR -> sRc/sRi -> vW -> vU(perfil) -> sRn -> vR -> vE.
public enum LiveTest {

    public enum Estado: Sendable {
        case conectando
        case conectado(String)       // modelo
        case perfilEnviado
        case aguardando              // pessoa deve subir na balança
        case concluido([String])     // campos do quadro vR
        case falha(String)
    }

    private static let ESC = "\u{1B}"

    /// Monta o perfil (FncNewProfile2Send): ID sex 0x1C nome altura idade peso grade 0 hp localID.
    public static func perfil(id: String, sexo: String, altura: String, idade: String,
                              peso: String = "", nome: String = "") -> String {
        // Decimais pt-BR usam vírgula; o protocolo exige ponto (CS-SER 2729-2732).
        let alturaP = altura.replacingOccurrences(of: ",", with: ".")
        let idadeP  = idade.replacingOccurrences(of: ",", with: ".")
        let pesoP   = peso.replacingOccurrences(of: ",", with: ".")
        let e = ESC
        return id + e + sexo + e + "\u{1C}" + e + nome + e + alturaP + e
             + idadeP + e + pesoP + e + "" + e + "0" + e + "" + e + "" + e
    }

    /// Executa a medição. Bloqueante — o chamador roda em Task.detached.
    /// `progresso` é chamado a cada mudança de estado.
    public static func executar(host: String = "", port: UInt16 = 0,
                                serialDevice: String? = nil, baud: speed_t = speed_t(B115200),
                                perfil: String,
                                timeoutMedicaoSeg: TimeInterval = 180,
                                progresso: @escaping @Sendable (Estado) -> Void) {
        progresso(.conectando)
        // serial (dongle Bluetooth/USB/cabo = /dev/cu.*) OU rede (WiFi/LAN). Mesmo protocolo;
        // no serial so muda a velocidade (dongle 115200, USB 19200, cabo 9600).
        let t: PortTransport?
        if let dev = serialDevice { t = PortTransport(serialDevice: dev, baud: baud) }
        else { t = PortTransport(host: host, port: port) }
        guard let t else {
            progresso(.falha(serialDevice != nil
                ? "Não consegui abrir a porta do dongle. Dongle plugado e pareado?"
                : "Não consegui abrir a conexão. Balança ligada? IP certo?")); return
        }

        // Log de diagnóstico: com INBODY_VERBOSE=1 imprime cada quadro trocado (stderr).
        let verbose = ProcessInfo.processInfo.environment["INBODY_VERBOSE"] != nil
        func esc(_ b: [UInt8]) -> String {
            String(decoding: b, as: UTF8.self)
                .replacingOccurrences(of: "\u{02}", with: "<STX>")
                .replacingOccurrences(of: "\u{03}", with: "<ETX>")
                .replacingOccurrences(of: "\u{1B}", with: "|")
        }
        func logv(_ s: String) {
            if verbose { FileHandle.standardError.write((s + "\n").data(using: .utf8)!) }
        }

        // --- aperto de mão P0/P1 ---
        logv(">> P0 NEWPROTOCOL")
        t.write(InBodyProtocol.makeFrame("P", "0", "NEWPROTOCOL" + ESC))
        guard let raw = t.readFrame(),
              let (payload, crcP0) = InBodyProtocol.parse(raw),
              let code = InBodyProtocol.securityCode(payload) else {
            progresso(.falha("Aperto de mão falhou.")); return
        }
        if !crcP0 { InBodyLog.warn("CRC do P0 nao confere") }
        logv("<< P0: \(String(payload.prefix(70)))")
        let modelo = (InBodyProtocol.fields(payload).first ?? "InBody").replacingOccurrences(of: "P0", with: "")
        progresso(.conectado(modelo))

        let fmt = DateFormatter(); fmt.dateFormat = "yyyyMMddHHmmss"
        usleep(140_000)
        t.write(InBodyProtocol.makeFrame("P", "1", code + ESC + fmt.string(from: Date()) + ESC))
        if let rawP1 = t.readFrame(), let (p1, crcP1) = InBodyProtocol.parse(rawP1) {
            if !crcP1 { InBodyLog.warn("CRC do P1 nao confere") }
            // Sucesso = NÃO contém "FAIL" (CS-SER 1945).
            if p1.uppercased().contains("FAIL") {
                progresso(.falha("Segurança recusada pela balança (P1 FAIL).")); return
            }
        }

        // NOTA AES: por WiFi/TCP a cifra é SEMPRE desligada — o IBNetDllServer força
        // strEncEquip="N" a cada P0, então o perfil vai em claro e o resultado vem em claro.
        // Se um dia falar por SERIAL/USB (onde strEncEquip pode vir "Y"), o payload do vU
        // teria que ser cifrado AQUI em AES-256-CBC (IV = 16 bytes zero, chave = UTF8 dos
        // 32 chars de strCommKEY, PKCS7, Base64), apenas nos campos 0,1,4,5,6
        // (ID,Sexo,Altura,Idade,Peso); e o vR seria decifrado na volta.

        // --- estado da medição ---
        var weightCheckEnd = true       // m_bWeightCheckEnd: primeira fase pede peso
        var perfilJaEnviado = false     // já mandamos o vU nesta medição?

        // watchdog de resposta (TmrResponseCheck, 5000ms; reenvia até MAX_REENVIOS)
        var ultimoComando: [UInt8] = []
        var ultimoEnvio = Date()
        var reenvios = 0
        let RESPONSE_TIMEOUT: TimeInterval = 5
        let MAX_REENVIOS = 2

        func enviar(_ frame: [UInt8]) {
            usleep(140_000)  // Thread.Sleep(140) antes de cada envio (fncNewSendCommand)
            logv(">> \(esc(frame))")
            t.write(frame)
            ultimoComando = frame
            ultimoEnvio = Date()
        }

        // Poll inicial: coloca a balança em modo remoto/self (CS-SER 1965).
        enviar(InBodyProtocol.makeFrame("s", "R", "z" + ESC + "vO" + ESC))
        progresso(.aguardando)

        let idPerfil = InBodyProtocol.fields(perfil).first ?? ""
        let deadline = Date().addingTimeInterval(timeoutMedicaoSeg)

        while Date() < deadline {
            guard let r = t.readFrame(timeout: 1.0) else {
                // sem resposta: reenvia o último comando; desiste após o limite.
                if Date().timeIntervalSince(ultimoEnvio) > RESPONSE_TIMEOUT, !ultimoComando.isEmpty {
                    reenvios += 1
                    if reenvios > MAX_REENVIOS {
                        progresso(.falha("Balança parou de responder.")); return
                    }
                    enviar(ultimoComando)
                }
                continue
            }
            guard let (p, crcOK) = InBodyProtocol.parse(r) else { logv("<< [quadro nao parseou: \(esc(r))]"); continue }
            logv("<< \(String(p.prefix(90)))\(crcOK ? "" : " [CRC BAD]")")
            if !crcOK {
                InBodyLog.warn("CRC de quadro recebido nao confere; descartado")
                continue
            }
            reenvios = 0

            // --- resultado pronto (aceita "vR" e o prefixo processado "[RESULT-DATA]") ---
            if p.hasPrefix("vR") || p.hasPrefix("[RESULT-DATA]") {
                let campos = InBodyProtocol.fields(p)
                progresso(.concluido(campos))
                // DK = campo[6]+campo[7] do vR, sem "/" e ":" (CS-SER 1042), não a hora atual.
                let dk = ((campos.count > 6 ? campos[6] : "") + (campos.count > 7 ? campos[7] : ""))
                    .replacingOccurrences(of: "/", with: "")
                    .replacingOccurrences(of: ":", with: "")
                enviar(InBodyProtocol.makeFrame("v", "E", idPerfil + ESC + dk + ESC))
                return
            }

            // --- peso recebido: manda o perfil se ainda não mandou (CS-SER 2113-2139) ---
            if p.hasPrefix("vW") {
                if !perfilJaEnviado {
                    perfilJaEnviado = true
                    progresso(.perfilEnviado)
                    enviar(InBodyProtocol.makeFrame("v", "U", perfil))
                } else {
                    enviar(InBodyProtocol.makeFrame("s", "R", ""))
                }
                continue
            }

            let cmd = String(p.prefix(3))  // sub-status: sRn, sRc, sRi...
            switch cmd {
            case "sRc", "sRi":
                // medindo: 1) pede peso (vW); 2) depois envia o perfil (vU). CS-SER 2506-2537.
                if weightCheckEnd {
                    weightCheckEnd = false
                    enviar(InBodyProtocol.makeFrame("v", "W", ""))
                } else if !perfilJaEnviado {
                    perfilJaEnviado = true
                    progresso(.perfilEnviado)
                    enviar(InBodyProtocol.makeFrame("v", "U", perfil))
                } else {
                    enviar(InBodyProtocol.makeFrame("s", "R", ""))
                }
            case "sRn":
                // standby/pronto: se há resultado bruto (campo[1] > 0) pede o vR (CS-SER 2473).
                weightCheckEnd = true
                let campos = InBodyProtocol.fields(p)
                let qtd = campos.count > 1 ? campos[1] : "0"
                if !qtd.isEmpty && qtd != "0" {
                    enviar(InBodyProtocol.makeFrame("v", "R", ""))
                } else {
                    enviar(InBodyProtocol.makeFrame("s", "R", ""))
                }
            default:
                // vU aceito, sRp, sRw, sRs, sRz e demais: volta ao poll sR.
                enviar(InBodyProtocol.makeFrame("s", "R", ""))
            }
        }
        progresso(.falha("Tempo esgotado sem receber o resultado."))
    }
}
