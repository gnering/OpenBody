import Foundation
import InBodyKit

/// Teste de conexão REAL pela porta serial (dongle Bluetooth / USB / cabo), rodado da
/// linha de comando: `swift run InBodyApp --conectar`. Varre as portas que o Mac enxerga,
/// tenta o aperto de mão em cada velocidade do original (115200 dongle, 19200 USB, 9600 cabo)
/// e diz qual balança respondeu. Serve pra provar a camada física sem depender da tela.
enum ConectarCLI {
    static func rodar(host: String? = nil) {
        // Modo REDE: `--conectar <ip>` fala com a balança por TCP na porta 2004.
        if let host {
            print("=== Teste de conexão por REDE em \(host):2004 ===")
            guard let s = InBodySession(host: host, port: 2004) else {
                print("Não consegui abrir a conexão com \(host):2004."); return
            }
            if let r = s.handshake() {
                print("")
                print("   ✅ CONECTOU. A balança respondeu: \"\(r.deviceInfo)\"")
                print("   segurança: \(r.passed ? "aceita" : "recusada")")
                print("   endereço certo: \(host):2004")
            } else {
                print("   porta abriu, mas não respondeu ao aperto de mão.")
                print("   (a 2004 está aberta, mas ou não é a balança, ou ela está ocupada/em outro modo.)")
            }
            return
        }
        let bauds: [(String, speed_t)] = [
            ("115200 (Bluetooth/dongle)", speed_t(B115200)),
            ("19200 (USB)",              speed_t(B19200)),
            ("9600 (cabo)",              speed_t(B9600)),
        ]

        // Portas candidatas: /dev/cu.* menos as internas do Mac (Bluetooth-Incoming, debug-console).
        let portas = PortTransport.portasSeriais().filter { !$0.contains("debug-console") }

        print("=== Teste de conexão com a balança ===")
        print("Portas vistas pelo Mac: \(portas.isEmpty ? "(nenhuma)" : portas.joined(separator: ", "))")
        if portas.isEmpty {
            print("Nenhum dongle/cabo apareceu. Plugue o dongle na USB e rode de novo.")
            return
        }

        for porta in portas {
            for (nome, baud) in bauds {
                print("→ tentando \(porta)  a  \(nome) ...")
                guard let sessao = InBodySession(serialDevice: porta, baud: baud) else {
                    print("   não consegui abrir a porta.")
                    continue
                }
                if let r = sessao.handshake() {
                    print("")
                    print("   ✅ CONECTOU. A balança respondeu: \"\(r.deviceInfo)\"")
                    print("   segurança: \(r.passed ? "aceita" : "recusada")")
                    print("   porta certa: \(porta)   velocidade: \(nome)")
                    return
                }
                print("   sem resposta nessa velocidade.")
            }
        }

        print("")
        print("Achei a porta, mas a balança não respondeu em nenhuma velocidade.")
        print("Cheque: balança LIGADA? dongle PAREADO com esta balança? antena perto?")
    }
}
