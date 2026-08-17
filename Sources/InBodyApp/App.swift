import SwiftUI
import UniformTypeIdentifiers
import CoreGraphics

@main
struct InBodyMacApp: App {
    @StateObject private var store = Store()

    init() {
        // Modo SERVIDOR: UM processo renderiza a lista inteira (antes reabria o app Swift por
        // exame, custo fixo de startup a cada render). Cada linha do stdin = "<flag>\t<in>\t<out>"
        // (--render-ops ou --export-pdf-json), roda pelo MESMO caminho de render e responde "OK".
        if CommandLine.arguments.contains("--serve") {
            while let line = readLine(strippingNewline: true) {
                if !line.isEmpty {
                    let a = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
                    if a.count >= 3, a[0] == "--render-ops" {
                        renderOpsToPDF(opsJSON: a[1], out: a[2])
                    } else if a.count >= 3, a[0] == "--export-pdf-json" {
                        renderRecordPDFForTrace(inPath: a[1], outPath: a[2])
                    } else {
                        FileHandle.standardError.write("[serve] cmd invalido: \(line)\n".data(using: .utf8)!)
                    }
                }
                print("OK"); fflush(stdout)
            }
            exit(0)
        }
        // Calibração de formatação contra o oráculo: lê "valor casas" por linha,
        // escreve fmtSheet(valor,casas). Mesma função que a folha usa (fonte única).
        if let i = CommandLine.arguments.firstIndex(of: "--fmt"), CommandLine.arguments.count > i + 2 {
            let a = CommandLine.arguments
            let linhas = (try? String(contentsOfFile: a[i+1], encoding: .utf8))?.split(separator: "\n", omittingEmptySubsequences: false) ?? []
            var out: [String] = []
            for ln in linhas {
                let p = ln.split(separator: " ")
                if p.count < 2 { out.append(""); continue }
                out.append(fmtSheet(Double(p[0]) ?? 0, Int(p[1]) ?? 1))
            }
            try? out.joined(separator: "\n").write(toFile: a[i+2], atomically: true, encoding: .utf8)
            exit(0)
        }
        // Calibração da família ESCALA: fmtScaleLabel (half-even), = ToString do ClsScale.
        if let i = CommandLine.arguments.firstIndex(of: "--fmt-scale"), CommandLine.arguments.count > i + 2 {
            let a = CommandLine.arguments
            let linhas = (try? String(contentsOfFile: a[i+1], encoding: .utf8))?.split(separator: "\n", omittingEmptySubsequences: false) ?? []
            var out: [String] = []
            for ln in linhas {
                let p = ln.split(separator: " ")
                if p.count < 2 { out.append(""); continue }
                out.append(fmtScaleLabel(Double(p[0]) ?? 0, Int(p[1]) ?? 1))
            }
            try? out.joined(separator: "\n").write(toFile: a[i+2], atomically: true, encoding: .utf8)
            exit(0)
        }
        if CommandLine.arguments.contains("--render-sheet-300") {
            renderSheetsToDisk(scale: 3, prefix: "render300_")   // 2480x3508 = A4 300 DPI (diff de imagem)
            exit(0)
        }
        // Render de um exame REAL por DATETIMES (mesmo paciente do PDF do aparelho),
        // p/ o region_diff virar mesmo-paciente. Uso:
        //   --render-mdb <mdb> <datetimes> <adulto|agua|ped> <out.png>
        if let i = CommandLine.arguments.firstIndex(of: "--render-mdb"),
           CommandLine.arguments.count > i + 4 {
            let a = CommandLine.arguments
            renderExameReal(mdb: a[i+1], datetimes: a[i+2], tipo: a[i+3], out: a[i+4])
            exit(0)
        }
        if CommandLine.arguments.contains("--render-sheet") {
            renderSheetsToDisk()
            exit(0)
        }
        if CommandLine.arguments.contains("--export-pdf") {
            exportPDFToDiskForTrace()
            exit(0)
        }
        if CommandLine.arguments.contains("--export-pdf-json") {
            renderRecordPDFForTrace()
            exit(0)
        }
        // Prova da camada de leitura do .mdb: roda o import REAL (mesmo mdb-export + montarMedida
        // usados em produção) sobre TODO o banco, sem renderizar nada, e despeja bruto+computado
        // por exame p/ um script externo conferir campo a campo contra o valor cru do banco.
        if let i = CommandLine.arguments.firstIndex(of: "--verify-mdb"),
           CommandLine.arguments.count > i + 2 {
            let a = CommandLine.arguments
            verificarLeituraMDB(mdb: a[i+1], out: a[i+2])
            exit(0)
        }
        // Importa um LookinBody.mdb pela linha de comando — MESMO caminho da tela
        // (Banco.importarMDB, com remapeamento de LOCAL_ID). Respeita INBODY_DB.
        //   --importar-mdb <caminho.mdb>
        if let i = CommandLine.arguments.firstIndex(of: "--importar-mdb"),
           CommandLine.arguments.count > i + 1 {
            let (u, e) = Banco.shared.importarMDB(CommandLine.arguments[i + 1])
            print("Importados \(u) pacientes e \(e) exames.")
            exit(0)
        }
        // Prova da camada Banco (E1): cria/grava/recarrega SQLite e confere ida-e-volta.
        //   --prova-banco criar            (T2: cria banco, checa schema/WAL/versao)
        //   --prova-banco corpus [csv]     (T4: grava os 1.742 e confere campo a campo)
        if let i = CommandLine.arguments.firstIndex(of: "--prova-banco") {
            BancoProva.rodar(Array(CommandLine.arguments[i...]))
            exit(0)
        }
        // Teste de conexão REAL com a balança pela porta serial (dongle/USB/cabo).
        //   --conectar   (varre portas, tenta o aperto de mão, diz qual balança respondeu)
        if let i = CommandLine.arguments.firstIndex(of: "--conectar") {
            let prox = CommandLine.arguments.count > i + 1 ? CommandLine.arguments[i + 1] : ""
            ConectarCLI.rodar(host: prox.contains(".") ? prox : nil)
            exit(0)
        }
        // Prova da conta de e-mail da InBody: decifra EMAIL_ACCOUNT_TBL e mostra o servidor
        // e o usuário (a SENHA nunca é impressa, só o tamanho).
        if CommandLine.arguments.contains("--prova-conta-email") {
            if let c = ContaInBody.credenciais() {
                print("PROVA CONTA INBODY OK")
                print("  servidor: \(c.host):\(c.porta)  TLS: \(c.tls)")
                print("  usuário:  \(c.usuario)   nome: \(c.nome)")
                print("  senha:    \(String(repeating: "*", count: c.senha.count)) (\(c.senha.count) caracteres)")
            } else {
                print("PROVA CONTA INBODY FALHOU: a chave não decifrou EMAIL_ACCOUNT_TBL.")
            }
            exit(0)
        }
        // Prova do cliente SMTP contra um servidor local de mentira (nada sai para a
        // internet): --prova-smtp <host> <porta> <destino>
        if let i = CommandLine.arguments.firstIndex(of: "--prova-smtp"), CommandLine.arguments.count > i + 3 {
            let a = CommandLine.arguments
            var c = ConfigEmail()
            // OBRIGATÓRIO: conta PRÓPRIA. Com .inbody (o padrão) a prova ignoraria o host
            // local e falaria com o servidor REAL da InBody — foi o que aconteceu antes.
            c.conta = .propria
            c.host = a[i+1]; c.porta = Int(a[i+2]) ?? 2525; c.tlsDireto = false
            c.usuario = "clinica@teste.local"; c.nomeExibicao = "Clínica (teste)"
            c.salvar()
            Keychain.salvarSenhaEmail("senha-de-teste", conta: c.usuario)
            let pdfFalso = Data("%PDF-1.4 folha de teste".utf8)
            if let erro = enviarEmailComFolhas(para: a[i+3], assunto: "InBody — Teste ção",
                                               corpo: "Segue a folha em anexo.",
                                               anexos: [("InBody_Teste.pdf", pdfFalso)]) {
                print("PROVA SMTP FALHOU: \(erro)")
            } else {
                print("PROVA SMTP OK: mensagem entregue ao servidor.")
            }
            exit(0)
        }
        // Sondagem crua do dongle Bluetooth (iWRAP): estado do link e config.
        if CommandLine.arguments.contains("--probe-serial") {
            ProbeSerial.rodar()
            exit(0)
        }
        // Exame ao vivo por fora, com log de quadros (INBODY_VERBOSE=1). Diagnóstico do
        // caminho device: --exame <ip> [id sexo altura idade]
        if let i = CommandLine.arguments.firstIndex(of: "--exame"), CommandLine.arguments.count > i + 1 {
            let a = CommandLine.arguments
            let extra = a.count > i + 2 ? Array(a[(i + 2)...]) : []
            ExameCLI.rodar(host: a[i + 1], args: extra)
            exit(0)
        }
        // Desenhista GENÉRICO: le a lista de ops do oráculo (JSON) e renderiza a folha em
        // PDF vetorial, sem transcrição. Prova de fidelidade: extrair de volta esses ops
        // deve bater com o golden (mesmo caminho de render das 3 folhas portadas).
        //   --render-ops <ops.json> <out.pdf>
        if let i = CommandLine.arguments.firstIndex(of: "--render-ops"),
           CommandLine.arguments.count > i + 2 {
            let a = CommandLine.arguments
            renderOpsToPDF(opsJSON: a[i+1], out: a[i+2])
            exit(0)
        }
    }

    var body: some Scene {
        WindowGroup("OpenBody") {
            ContentView().environmentObject(store)
                // Piso onde os 3 painéis + a tabela de pacientes cabem sem cortar. A janela
                // cresce à vontade (conteúdo acompanha) e não encolhe além disso.
                .frame(minWidth: 1200, minHeight: 680)
                // Idioma travado em pt-BR explicitamente: nao depende do locale do Mac.
                .environment(\.locale, Locale(identifier: "pt_BR"))
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentMinSize)   // a janela não encolhe abaixo do conteúdo
        // Atalho sempre visível: menu "Balança" no topo, com Conectar em ⌘K.
        .commands {
            CommandMenu(T("Balance")) {
                Button(store.ocupado ? T("Connecting…") : T("Connect balance")) {
                    store.conectar()
                }
                .keyboardShortcut("k", modifiers: .command)
                .disabled(store.ocupado)
            }
        }
    }
}

@MainActor func renderOpsToPDF(opsJSON: String, out: String) {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: opsJSON)) else {
        FileHandle.standardError.write("nao abriu \(opsJSON)\n".data(using: .utf8)!); return
    }
    // Aceita {"ops":[...]} (payload do oráculo, ignora demais chaves) OU lista [...] direta.
    var ops: [OpDraw] = []
    if let wrap = try? JSONDecoder().decode(OpsPayload.self, from: data) { ops = wrap.ops }
    if ops.isEmpty, let list = try? JSONDecoder().decode([OpDraw].self, from: data) { ops = list }
    // Paciente/Medida dummy só p/ instanciar a View; overrideElementos ignora ambos.
    let dummy = DemoData.ana
    let e = dummy.ultimo ?? DemoData.ana.exames.first!
    let folhaBase = FolhaResultado(paciente: dummy, e: e)
    let el = OpRenderer.elementos(folhaBase, ops)
    let folha = FolhaResultado(paciente: dummy, e: e, overrideElementos: el)
    let renderer = ImageRenderer(content: folha)
    renderer.scale = 1.0
    let url = URL(fileURLWithPath: out)
    renderer.render { size, context in
        var box = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        guard let pdf = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
        pdf.beginPDFPage(nil); context(pdf); pdf.endPDFPage(); pdf.closePDF()
    }
    FileHandle.standardError.write("[render-ops] \(ops.count) ops -> \(url.path)\n".data(using: .utf8)!)
}
private struct OpsPayload: Decodable { let ops: [OpDraw] }

func verificarLeituraMDB(mdb: String, out: String) {
    let linhas = ImportService.dumpVerificacao(mdb)
    guard let data = try? JSONSerialization.data(withJSONObject: linhas) else {
        FileHandle.standardError.write("erro ao serializar\n".data(using: .utf8)!); return
    }
    try? data.write(to: URL(fileURLWithPath: out))
    FileHandle.standardError.write("ok: \(linhas.count) exames -> \(out)\n".data(using: .utf8)!)
}

@MainActor func renderExameReal(mdb: String, datetimes: String, tipo tipoStr: String, out: String) {
    SheetSettings.carregar((mdb as NSString).deletingLastPathComponent)   // DATE/TIME_FORMAT da clínica
    let res = ImportService.importar(mdb)
    // Acha o exame EXATO (mesmo DATETIMES do PDF) e o paciente dono dele.
    for p in res.pacientes {
        guard let e = p.exames.first(where: { $0.data == datetimes }) else { continue }
        // Sexo desconhecido -> aborta ALTO. Chutar sairia com escala errada e o diff
        // não acusaria (os dois lados leriam o mesmo registro chutado).
        guard p.sexo == "M" || p.sexo == "F" else {
            FileHandle.standardError.write("ERRO: sexo indefinido (\(p.sexo)) p/ \(p.nome) exame \(datetimes); render abortado\n".data(using: .utf8)!)
            exit(2)
        }
        let tipo: TipoFolha
        switch tipoStr {
        case "agua": tipo = .agua
        case "ped": tipo = .pediatrica
        case "historico", "hist": tipo = .historico
        default: tipo = .adulto
        }
        // Motor original p/ folha adulta (770/120/270/370S); nativo p/ água/criança ou fallback.
        if let png = SheetRender.png(p, e, tipo: tipo) {
            try? png.write(to: URL(fileURLWithPath: out))
            let via = EngineSheet.suportado(e.equip, tipo) ? "motor" : "nativo"
            FileHandle.standardError.write("ok (\(via)): \(p.nome) sexo=\(p.sexo) exame=\(datetimes) -> \(out)\n".data(using: .utf8)!)
        }
        return
    }
    FileHandle.standardError.write("exame \(datetimes) nao encontrado no mdb\n".data(using: .utf8)!)
}

@MainActor func renderSheetsToDisk(scale: CGFloat = 2, prefix: String = "render_") {
    let adulto = DemoData.ana
    let ped = DemoData.pediatrica
    for tipo in TipoFolha.allCases {
        // Folha pediátrica usa a paciente-criança; adulto e água usam a Ana.
        let p = (tipo == .pediatrica) ? ped : adulto
        guard let e = p.ultimo else { continue }
        let r = ImageRenderer(content: FolhaResultado(paciente: p, e: e, tipo: tipo))
        r.scale = scale
        if let img = r.nsImage, let tiff = img.tiffRepresentation,
           let bmp = NSBitmapImageRep(data: tiff),
           let png = bmp.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: "/tmp/\(prefix)\(tipo.arquivo).png"))
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var store: Store
    // Login na abertura só se o Setup > LGPD > "Usar login" estiver marcado (A-11).
    // Sem isso, entra direto (decisão do dono).
    @State private var logado = !SetupConfig.carregar().usarLogin
    @State private var autoConectou = false
    @State private var bloqueado = false
    // Observa a chave do idioma: trocar no Setup re-renderiza TODA a UI na hora.
    // O .id() reconstrói a árvore, forçando cada T() a reler o idioma novo.
    @AppStorage(Idioma.chaveDefaults) private var idiomaRaw = Idioma.ptBR.rawValue
    // Verifica a inatividade a cada 15s para o bloqueio automático (A-08).
    private let relogioLock = Timer.publish(every: 15, on: .main, in: .common).autoconnect()
    var body: some View {
        Group {
            if logado {
                MainScreen()
            } else {
                LoginView { logado = true }
            }
        }
        .id(idiomaRaw)
        .preferredColorScheme(.light)  // LookinBody original é modo claro apenas
        .overlay { if bloqueado { BloqueioView { bloqueado = false } } }
        .onReceive(relogioLock) { _ in verificarBloqueio() }
        .onAppear {
            SetupConfig.carregar().aplicarFormatoData()   // formato de data escolhido no Setup passa a valer
            store.carregar()             // abre o banco e carrega (nunca no init: CLI/bancada)
            if !autoConectou {           // procura a balança sozinho na abertura (como o Windows)
                autoConectou = true
                store.conectar()
                // Backup automático na nuvem (Setup B-02), se ligado e houver pasta vinculada.
                if CloudBackup.autoAtivo, CloudBackup.pastaVinculada != nil {
                    _ = CloudBackup.backupVinculado()
                }
            }
        }
    }

    /// Bloqueia se: opção ligada, senha definida e o Mac ficou parado além do limite.
    private func verificarBloqueio() {
        guard !bloqueado else { return }
        let cfg = SetupConfig.carregar()
        guard cfg.autoLockAtivo, Keychain.temSenhaAutoLock() else { return }
        let ocioso = CGEventSource.secondsSinceLastEventType(.combinedSessionState,
                                                             eventType: CGEventType(rawValue: ~0)!)
        if ocioso >= Double(max(1, cfg.autoLockMin) * 60) { bloqueado = true }
    }
}

/// Tela de bloqueio (A-08): cobre o app até a senha certa ser digitada.
struct BloqueioView: View {
    var aoDesbloquear: () -> Void
    @State private var senha = ""
    @State private var erro = false
    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "lock.fill").font(.system(size: 44)).foregroundStyle(.white)
                Text(T("Screen locked")).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                SecureField(T("Input password."), text: $senha)
                    .textFieldStyle(.roundedBorder).frame(width: 220)
                    .onSubmit(tentar)
                if erro { Text(T("Wrong password.")).font(.system(size: 11)).foregroundStyle(.red) }
                Button(T("Unlock"), action: tentar).keyboardShortcut(.defaultAction)
            }
            .padding(28)
        }
    }
    private func tentar() {
        if senha == Keychain.senhaAutoLock() { aoDesbloquear() }
        else { erro = true; senha = "" }
    }
}

struct BotaoConectar: View {
    @EnvironmentObject var store: Store
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(store.conectado ? Color.okc : Color.secondary).frame(width: 8, height: 8)
            Text(store.statusBalanca).font(.system(size: 12)).foregroundStyle(.secondary)
            Button { store.conectar() } label: {
                Text(store.ocupado ? "…" : T("Connect scale"))
            }.disabled(store.ocupado)
        }
    }
}

struct BotaoImportar: View {
    @EnvironmentObject var store: Store
    var body: some View {
        Button {
            let painel = NSOpenPanel()
            painel.allowedContentTypes = [UTType(filenameExtension: "mdb") ?? .data]
            painel.allowsOtherFileTypes = true
            painel.message = T("Choose the balance's LookinBody.mdb file")
            if painel.runModal() == .OK, let url = painel.url {
                store.ocupado = true
                let caminho = url.path
                Task { @MainActor in
                    // Grava no banco (persistente) e recarrega. Idempotente: reimportar nao duplica.
                    let aviso = store.importarDe(mdb: caminho)
                    store.ocupado = false
                    store.statusBalanca = aviso
                }
            }
        } label: {
            Label(T("Import backup"), systemImage: "square.and.arrow.down")
        }
    }
}

struct Sidebar: View {
    @EnvironmentObject var store: Store
    var body: some View {
        VStack(spacing: 0) {
            TextField(T("Search patient"), text: $store.busca)
                .textFieldStyle(.roundedBorder).padding(10)
            List(selection: $store.selecionado) {
                ForEach(store.filtrados) { p in
                    HStack(spacing: 10) {
                        Text(p.iniciais).font(.system(size: 11, weight: .bold))
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.accentColor.opacity(0.18)))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(p.nome).font(.system(size: 13, weight: .medium)).lineLimit(1)
                            Text("\(p.idade) \(T("yrs")) · \(p.exames.count) \(p.exames.count > 1 ? T("exams") : T("exam"))")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }.tag(p.id)
                }
            }
        }
        .frame(minWidth: 240)
    }
}
