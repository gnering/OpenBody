import Foundation
import InBodyKit

// CLI de prova: conecta na balanca por WiFi, faz o aperto de mao,
// e (se houver quadro vR salvo) decodifica um exame.
//
//   swift run inbody 192.168.0.100 2004
//   swift run inbody --decode /caminho/para/frame.txt

let args = Array(CommandLine.arguments.dropFirst())

func decodeFile(_ path: String) {
    guard let text = try? String(contentsOfFile: path, encoding: .isoLatin1) else {
        print("nao consegui ler \(path)"); exit(1)
    }
    guard let i = text.range(of: "vRINBODY") else { print("sem quadro vR no arquivo"); exit(1) }
    let payload = String(text[i.lowerBound...]).trimmingCharacters(in: .newlines)
    let exam = InBodyExam(vRPayload: payload)
    print("=== EXAME DECODIFICADO (nativo Swift) ===")
    print(exam.report())
    print("Campos no quadro: \(exam.raw.count)  |  nomeados: \(exam.named.count)")
}

if args.first == "--decode", args.count > 1 {
    decodeFile(args[1])
    exit(0)
}

let host = args.first ?? "192.168.0.100"
let port = UInt16(args.dropFirst().first ?? "2004") ?? 2004

print("Conectando em \(host):\(port) ...")
guard let session = InBodySession(host: host, port: port) else {
    print("nao consegui abrir a conexao. Balanca ligada? IP certo?"); exit(1)
}
guard let result = session.handshake() else {
    print("aperto de mao falhou."); exit(1)
}
let model = InBodyProtocol.fields(result.deviceInfo).first ?? "?"
print("Aparelho: \(model)")
print("Aperto de mao: \(result.passed ? "PASS — o Mac esta falando com a balanca" : "recusado")")
