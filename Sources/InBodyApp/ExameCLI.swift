import Foundation
import InBodyKit

/// Conduz um exame ao vivo pela linha de comando (`--exame <ip> [id sexo altura idade]`),
/// pelo MESMO caminho de produção (LiveTest.executar). Com `INBODY_VERBOSE=1` na frente,
/// imprime cada quadro trocado com a balança — é assim que a gente vê onde o exame quebra
/// contra o aparelho real, sem depender da tela.
enum ExameCLI {
    static func rodar(host: String, args: [String]) {
        let id    = args.count > 0 ? args[0] : "TESTE"
        let sexo  = args.count > 1 ? args[1] : "M"
        let alt   = args.count > 2 ? args[2] : "175"
        let idade = args.count > 3 ? args[3] : "30"
        let perfil = LiveTest.perfil(id: id, sexo: sexo, altura: alt, idade: idade)

        print("=== Exame ao vivo em \(host):2004 ===")
        print("perfil: id=\(id) sexo=\(sexo) altura=\(alt) idade=\(idade)")
        print("(dica: rode com INBODY_VERBOSE=1 na frente pra ver cada quadro)\n")

        let seg = TimeInterval(ProcessInfo.processInfo.environment["INBODY_EXAME_SEG"].flatMap { Int($0) } ?? 60)
        LiveTest.executar(host: host, port: 2004, perfil: perfil, timeoutMedicaoSeg: seg) { estado in
            switch estado {
            case .conectando:        print("• conectando…")
            case .conectado(let m):  print("• conectado: \(m)")
            case .perfilEnviado:     print("• perfil enviado à balança")
            case .aguardando:        print("• aguardando pessoa subir na balança…")
            case .concluido(let c):
                print("\n✅ RESULTADO recebido: \(c.count) campos")
                print("   primeiros 15: \(c.prefix(15).joined(separator: " | "))")
            case .falha(let msg):    print("\n✗ falha: \(msg)")
            }
        }
        print("=== fim do exame ===")
    }
}
