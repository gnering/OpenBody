import Foundation
import InBodyKit

/// Sonda o dongle Bluetooth cru (`--probe-serial`). O dongle do InBody costuma ser um módulo
/// Bluegiga/iWRAP: a porta USB fala com o MÓDULO, não com a balança, enquanto o link
/// Bluetooth não estiver de pé. Este probe abre a porta em VÁRIAS velocidades, escuta o
/// banner de boot (o módulo emite "WRAP.../READY." logo após abrir) e manda comandos iWRAP
/// (SET = config, inclui pareamentos guardados). Read-only: não muda nada no dongle.
enum ProbeSerial {
    static func rodar() {
        guard let porta = PortTransport.portasSeriais().filter({ !$0.contains("debug-console") }).first else {
            print("Sem porta serial pra sondar. Dongle plugado?"); return
        }
        print("=== Sondando o dongle em \(porta) ===\n")

        let bauds: [(String, speed_t)] = [
            ("9600",   speed_t(B9600)),
            ("19200",  speed_t(B19200)),
            ("38400",  speed_t(B38400)),
            ("57600",  speed_t(B57600)),
            ("115200", speed_t(B115200)),
        ]

        for (nome, baud) in bauds {
            guard let t = PortTransport(serialDevice: porta, baud: baud) else {
                print("[\(nome)] não abriu a porta."); continue
            }
            func lerPor(_ segundos: Double) -> [UInt8] {
                let fim = Date().addingTimeInterval(segundos)
                var dados: [UInt8] = []
                while Date() < fim {
                    let c = t.readSome(512)
                    if c.isEmpty { usleep(20_000); continue }
                    dados.append(contentsOf: c)
                }
                return dados
            }
            // Abrir a porta faz o Mac alternar DTR: se for iWRAP, ele reinicia e cospe o banner.
            var bytes = lerPor(1.5)
            t.write(Array("\r\nSET\r\n".utf8))          // pede a config (pareamentos, autocall)
            bytes.append(contentsOf: lerPor(1.3))

            let txt = String(decoding: bytes, as: UTF8.self)
            let temTexto = bytes.contains { $0 >= 32 && $0 < 127 }
            print("[\(nome)] \(bytes.count) bytes")
            if !bytes.isEmpty {
                if temTexto { print("  texto: \(txt.replacingOccurrences(of: "\r", with: "\\r").replacingOccurrences(of: "\n", with: "\\n"))") }
                else { print("  (só bytes não-texto: \(bytes.prefix(24).map { String(format: "%02X", $0) }.joined(separator: " ")) ...)") }
            }
        }
        print("\n=== fim da sondagem ===")
    }
}
