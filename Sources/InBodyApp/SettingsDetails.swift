import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Telas de detalhe de cada item do Setup (manual p.76-124), fiéis aos prints.
/// Helpers em SettingsComponents.swift; telas B/C/D nos arquivos Settings*.swift.
/// Mede a altura real do conteúdo da subtela para a janela abraçá-lo.
private struct AlturaConteudoKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

struct SettingsDetailView: View {
    @EnvironmentObject var store: Store
    let item: String
    var aoFechar: () -> Void

    // Config PERSISTENTE do Setup (antes as opções eram cenográficas). Salva ao mudar.
    @State var setup = SetupConfig.carregar()
    @State var autoLockSenha = ""      // A-08: senha do bloqueio (vai pro Keychain)
    // Estado local das telas que ainda não persistem (e-mail tem persistência própria).
    @State var language = Idioma.atual.rawValue
    @State var impressora = ImpressoraEscolhida.carregar() ?? "(system default)"
    // A-05 E-mail: campos reais, salvos (senha no Keychain).
    @State var emailHost = ConfigEmail.carregar().host
    @State var emailUser = ConfigEmail.carregar().usuario
    @State var emailNome = ConfigEmail.carregar().nomeExibicao
    @State var emailPorta = String(ConfigEmail.carregar().porta)
    @State var emailSenha = ""
    @State var emailAviso = ""
    @State var contaEmailSel = ConfigEmail.carregar().conta == .propria ? 1 : 0

    private func salvarEmail() {
        var c = ConfigEmail.carregar()
        c.conta = .propria
        c.host = emailHost.trimmingCharacters(in: .whitespaces)
        c.usuario = emailUser.trimmingCharacters(in: .whitespaces)
        c.nomeExibicao = emailNome
        c.porta = Int(emailPorta) ?? 465
        c.tlsDireto = (c.porta == 465)
        c.salvar()
        if !emailSenha.isEmpty {
            Keychain.salvarSenhaEmail(emailSenha, conta: c.usuario)
            emailSenha = ""
        }
        emailAviso = ConfigEmail.carregar().configurado
            ? T("Server saved. Emails will now go through it.")
            : T("Missing host, user, or password (leave blank to use your Mac Mail).")
    }

    /// Campo de texto EDITÁVEL (os do original eram só ilustrativos).
    @ViewBuilder
    private func campoEditavel(_ rotulo: String, _ valor: Binding<String>,
                               rotLargura: CGFloat = 70, largura: CGFloat = 220,
                               seguro: Bool = false) -> some View {
        HStack {
            Text(T(rotulo)).font(.system(size: 13)).frame(width: rotLargura, alignment: .leading)
            Group {
                if seguro { SecureField("", text: valor) } else { TextField("", text: valor) }
            }
            .textFieldStyle(.plain).font(.system(size: 13))
            .padding(.horizontal, 8).frame(width: largura, height: 28)
            .background(RoundedRectangle(cornerRadius: 3).stroke(Color.gray.opacity(0.4)))
        }
    }
    // secureConn é específico do e-mail (A-05); os demais migraram para `setup`.
    @State var secureConn = 3      // 0 Use · 1 Do not use · 2 TLS 1.0(1.1) · 3 TLS 1.2
    @State var autoBackup = 1      // 0 Yes · 1 No
    @State var backupPeriod = "Every week (Default)"
    @State var integMethod = "None"
    @State var logoCfg = CustomLogoConfig.carregar()   // A-04 Custom Logo (persiste)
    @State var cloudAuto = CloudBackup.autoAtivo       // B-02 backup automático na nuvem
    @State var cloudAviso = ""                          // B-02 último resultado do backup na nuvem
    @State var cloudPastaVinculada = CloudBackup.pastaVinculada ?? ""  // B-02 pasta da nuvem

    /// Título real do popup (diverge do menu em 03, 11 e InBody-04).
    private var tituloPopup: String {
        if item.hasPrefix("03. Results Sheet Types") {
            return "Results Sheet Types/Paper Types/Printing Options/Language for Results Sheet"
        }
        if item.hasPrefix("11. Advanced Security") { return "GDPR Options" }
        if item.hasPrefix("04. Reference Range") { return "Normal Range" }
        return item
    }

    /// Só o item 10 (somente leitura) usa OK; todos os outros usam Save.
    private var textoBotao: String { item.hasPrefix("10. Program and Computer") ? "OK" : "Save" }

    // A janela abraça o conteúdo: painel curto = janela curta; painel longo = rola até o teto.
    @State private var alturaConteudo: CGFloat = 240
    private let alturaMax: CGFloat = 760

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(T(tituloPopup)).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                Spacer()
                Button { aoFechar() } label: { Image(systemName: "xmark").font(.system(size: 14)).foregroundStyle(.white) }.buttonStyle(.plain)
            }.padding(.horizontal, 16).padding(.vertical, 11).background(setupMarrom)

            ScrollView {
                conteudo.padding(22).frame(maxWidth: .infinity, alignment: .leading)
                    .background(GeometryReader { g in
                        Color.clear.preference(key: AlturaConteudoKey.self, value: g.size.height)
                    })
            }
            .frame(height: min(max(alturaConteudo, 160), alturaMax))
            .onPreferenceChange(AlturaConteudoKey.self) { alturaConteudo = $0 }

            Divider()
            HStack { Spacer()
                Button { aoFechar() } label: {
                    Text(T(textoBotao)).font(.system(size: 14, weight: .medium))
                        .frame(width: 120, height: 34)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.12)))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.4)))
                }.buttonStyle(.plain)
                Spacer()
            }.padding(14)
        }
        .frame(width: 820).background(Color.white).foregroundStyle(.black)
        .onChange(of: setup) { _, novo in novo.salvar(); novo.aplicarFormatoData() }   // toda mudança persiste e passa a valer
    }

    @ViewBuilder private var conteudo: some View {
        // General Settings (A)
        if item.hasPrefix("01. Country") { countryLang }
        else if item.hasPrefix("02. Printer") { printer }
        else if item.hasPrefix("03. Results Sheet Types") { resultSheetTypes }
        else if item.hasPrefix("04. Results Sheet Custom Logo") { customLogo }
        else if item.hasPrefix("05. E-mail Options") { emailOptions }
        else if item.hasPrefix("06. Edit Member Information") { editMemberInfo }
        else if item.hasPrefix("08. Auto-Lock") { autoLock }
        else if item.hasPrefix("09. Customer Service") { customerService }
        else if item.hasPrefix("10. Program and Computer") { programInfo }
        else if item.hasPrefix("11. Advanced Security") { gdprOptions }
        // InBody Test Settings (B)
        else if item.hasPrefix("01. InBody Model") { inbodyModel }
        else if item.hasPrefix("02. Cloud Service") { cloudService }
        else if item.hasPrefix("03. Outputs/Interpretations") { outputsInterpretations }
        else if item.hasPrefix("04. Reference Range") { referenceRange }
        else if item.hasPrefix("05. Export Data as CSV") { exportCSVImage }
        // LookinBody Data Management (C)
        else if item.hasPrefix("01. Export Data as Excel") { exportExcel }
        else if item.hasPrefix("02. Import Group Registration") { importGroupExcel }
        else if item.hasPrefix("03. Reinstallation Guide") { reinstallationGuide }
        else if item.hasPrefix("04. Data Backup") { dataBackup }
        else if item.hasPrefix("05. Data Restoration") { dataRestoration }
        else if item.hasPrefix("06. Temporary Data") { temporaryData }
        else if item.hasPrefix("07. Import Data from Previous") { importPreviousLB }
        else if item.hasPrefix("08. Data Importation") { dataImportation }
        // Data Integration (D)
        else if item.hasPrefix("01. Order(Member) data integration") { orderIntegration }
        else if item.hasPrefix("02. InBody data integration") { inbodyDataIntegration }
        else if item.hasPrefix("03. InBody Results Sheet integration") { resultsSheetIntegration }
        else { generico }
    }

    // ===== A. GENERAL SETTINGS =====

    // A-01
    private var countryLang: some View {
        VStack(alignment: .leading, spacing: 4) {
            rot("Select country."); comboMenu($setup.pais, SetupData.countries)
            // Idioma da interface: salva e passa a valer (antes o combo era só decorativo).
            rot("Select language.")
            comboMenu($language, SetupData.languages)
                .onChange(of: language) { _, novo in
                    if let i = Idioma(rawValue: novo) { Idioma.atual = i }
                    setup.aplicarFormatoData()   // formato de data segue o idioma (se não for manual)
                }
            rot("Select unit.")
            HStack(spacing: 20) { radioSel("kg/cm", $setup.unidade, 0); radioSel("lb/ft in", $setup.unidade, 1) }
            rot("Select date format.")
            // Mostra o formato EFETIVO (padrão do idioma, ou o manual se escolhido);
            // clicar marca como escolha manual.
            let fmtData = Binding<Int>(
                get: { setup.formatoDataEfetivo },
                set: { setup.formatoData = $0; setup.formatoDataManual = true }
            )
            HStack(spacing: 16) {
                radioSel("Year.Month.Day.", fmtData, 0)
                radioSel("Month.Day.Year.", fmtData, 1)
                radioSel("Day.Month.Year.", fmtData, 2)
            }
            rot("Click the button below to set a password.")
            HStack { botaoCinza("Set Password for Setup"); ajuda("Prevent unauthorized access to the Setup.") }
            HStack { botaoCinza("Set Master Password"); ajuda("Enhance data security (required to export/back up).") }
        }
    }

    // A-02
    private var printer: some View {
        // Impressoras REAIS do Mac. A escolhida vira o destino da impressão automática
        // pós-exame (antes ia sempre na padrão do sistema, sem opção).
        let nomes = ["(system default)"] + NSPrinter.printerNames
        return VStack(alignment: .leading, spacing: 6) {
            rot("Select a printer.")
            comboMenu($impressora, nomes)
                .onChange(of: impressora) { _, nova in
                    ImpressoraEscolhida.salvar(nova == "(system default)" ? nil : nova)
                }
            if NSPrinter.printerNames.isEmpty {
                ajuda("No printer installed on this Mac.")
            } else {
                ajuda("The automatic print after the exam uses this printer.")
            }
        }
    }

    // A-03
    private var resultSheetTypes: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(T("Select options below.")).font(.system(size: 13, weight: .semibold))
            passo("1. Select Results Sheet type to print.")
            ajuda("Category · Results Sheet · Example / Setup · Model")
            sheetRow("InBody Test", "InBody Result Sheet",
                     "Shows InBody Test results with graphs.", folha: .adulto)
            sheetRow("InBody Test", "Body Water Result Sheet",
                     "Shows the balance and distribution of body water.", folha: .agua)
            sheetRow("InBody Test", "InBody Children's Result Sheet",
                     "…results with graphs including Child Growth Curve.", folha: .pediatrica, temSetup: true)
            sheetRow("InBody Test", "InBody Result Interpretation",
                     "Explanation of the InBody Test results.")
            sheetRow("InBody Test", "Body Composition History Result Sheet",
                     "Tracks compositional change. Items selectable in Setup.", folha: .historico, temSetup: true)
            sheetRow("InBody Test", "Research Result Sheet", "Shows research data.")
            passo("2. Select the paper type.")
            HStack(spacing: 16) { radioSel("Blank A4 Paper", $setup.tipoPapel, 0); radioSel("InBody Paper", $setup.tipoPapel, 1) }
            ajuda("* To adjust print alignment, click [Printing Alignment].")
            botaoCinza("Printing Alignment", largura: 150) { ajustarAlinhamento() }
            passo("3. Select number of copies to print.")
            HStack(spacing: 16) { radioSel("1 copy", $setup.copias, 1); radioSel("2 copies", $setup.copias, 2) }
            passo("4. Print Results Sheets automatically after each InBody Test.")
            HStack(spacing: 16) {
                radioSelBool("Print automatically", $setup.imprimirAutomaticamente, true)
                radioSelBool("Do not print automatically", $setup.imprimirAutomaticamente, false)
            }
            passo("5. Set language for Results Sheets.")
            HStack {
                Text("InBody770").font(.system(size: 12)).frame(width: 120, alignment: .leading)
                combo(Idioma.atual == .ptBR ? "Portuguese(Brazil)" : "English")
            }
        }
    }

    /// Linha de tipo de folha. Se `folha` != nil, o checkbox liga/desliga a folha na
    /// impressão (setup.folhasImpressao). Interpretation/Research não têm renderizador
    /// no app, então ficam sem checkbox (desabilitadas).
    private func sheetRow(_ cat: String, _ nome: String, _ desc: String, folha: TipoFolha? = nil, temSetup: Bool = false) -> some View {
        let marcada = folha.map { setup.folhasImpressao.contains($0.rawValue) } ?? false
        return HStack(spacing: 6) {
            Image(systemName: marcada ? "checkmark.square.fill" : "square").font(.system(size: 13))
                .foregroundStyle(folha == nil ? Color.secondary.opacity(0.4) : (marcada ? Color.accentColor : .secondary))
                .contentShape(Rectangle())
                .onTapGesture {
                    guard let f = folha else { return }
                    if setup.folhasImpressao.contains(f.rawValue) { setup.folhasImpressao.remove(f.rawValue) }
                    else { setup.folhasImpressao.insert(f.rawValue) }
                }
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(T(cat)).font(.system(size: 11)).foregroundStyle(.secondary).frame(width: 60, alignment: .leading)
                    Text(T(nome)).font(.system(size: 12, weight: .medium))
                }
                Text(T(desc)).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            botaoCinza("Example", largura: 56) { if let f = folha { previaFolha(f) } else { avisoNaoConstruido(T("Example (sheet not ported yet)")) } }
            if temSetup { botaoCinza("Setup", largura: 48) { if let f = folha { previaFolha(f) } } }
        }
        .padding(.vertical, 2)
        .overlay(Rectangle().fill(Color.gray.opacity(0.1)).frame(height: 1), alignment: .bottom)
    }

    // MARK: - Ações A-03 (prévia de folha + alinhamento de impressão)

    /// Abre um PDF de amostra da folha no Preview.app (paciente selecionado, ou um exemplo).
    func previaFolha(_ tipo: TipoFolha) {
        guard let base = store.pacienteAtual, let ex = base.ultimo ?? base.exames.first else {
            let a = NSAlert(); a.messageText = T("No exam to preview")
            a.informativeText = T("Select a patient with an exam in the main list."); a.runModal(); return
        }
        // O exemplo NUNCA mostra identidade real: mesmos números, nome/ID fictícios (privacidade).
        var p = base
        p.nome = T("Example"); p.id = "EXEMPLO"; p.email = ""; p.nascimento = ""; p.celular = ""
        guard let pdf = pdfDaFolha(paciente: p, medida: ex, tipo: tipo) else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("previa_\(tipo.rawValue).pdf")
        try? pdf.write(to: url)
        NSWorkspace.shared.open(url)
    }

    /// Diálogo de alinhamento da impressão: deslocamento horizontal/vertical em mm.
    func ajustarAlinhamento() {
        let stack = NSStackView(frame: NSRect(x: 0, y: 0, width: 240, height: 56))
        stack.orientation = .vertical; stack.spacing = 6
        let cx = NSTextField(string: String(AlinhamentoImpressao.dx))
        let cy = NSTextField(string: String(AlinhamentoImpressao.dy))
        cx.placeholderString = T("Horizontal (mm)"); cy.placeholderString = T("Vertical (mm)")
        stack.addArrangedSubview(cx); stack.addArrangedSubview(cy)
        let a = NSAlert()
        a.messageText = T("Print alignment")
        a.informativeText = T("Offset in mm (max ±10). Positive = right / down.")
        a.accessoryView = stack
        a.addButton(withTitle: T("Save")); a.addButton(withTitle: T("Reset")); a.addButton(withTitle: T("Cancel"))
        switch a.runModal() {
        case .alertFirstButtonReturn:
            AlinhamentoImpressao.salvar(dx: Double(cx.stringValue.replacingOccurrences(of: ",", with: ".")) ?? 0,
                                        dy: Double(cy.stringValue.replacingOccurrences(of: ",", with: ".")) ?? 0)
        case .alertSecondButtonReturn: AlinhamentoImpressao.resetar()
        default: break
        }
    }

    // A-04 — funcional: edita e salva o logo do canto superior direito da folha.
    private var customLogo: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(T("The top-right corner of the sheet is available for a custom logo."))
                .font(.system(size: 13))
            rot("Select the logo option.")
            Picker("", selection: $logoCfg.modo) {
                ForEach(LogoModo.allCases) { m in Text(m.rotulo).tag(m) }
            }.pickerStyle(.radioGroup).labelsHidden()

            if logoCfg.modo == .imagem {
                HStack(spacing: 8) {
                    Button(T("Load image…")) { carregarImagemLogo() }
                    Text(logoCfg.imagemPath.isEmpty ? T("No file") : (logoCfg.imagemPath as NSString).lastPathComponent)
                        .font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                }
            }

            if logoCfg.modo == .texto {
                rot("Text logo configuration")
                ForEach(0..<3, id: \.self) { i in
                    HStack(spacing: 8) {
                        TextField("Linha \(i + 1)", text: $logoCfg.linhas[i].texto)
                            .textFieldStyle(.roundedBorder).frame(width: 210)
                        Picker("", selection: $logoCfg.linhas[i].fonte) {
                            ForEach(CustomLogoConfig.fontesDisponiveis, id: \.self) { Text($0).tag($0) }
                        }.labelsHidden().frame(width: 130)
                        Picker("", selection: $logoCfg.linhas[i].tamanho) {
                            ForEach(CustomLogoConfig.tamanhosDisponiveis, id: \.self) { Text("\($0)").tag($0) }
                        }.labelsHidden().frame(width: 60)
                        Toggle(T("Bold"), isOn: $logoCfg.linhas[i].negrito).toggleStyle(.checkbox)
                    }
                }
            }

            Text(T("Preview")).font(.system(size: 13, weight: .semibold))
            previewLogo
                .frame(width: 300, height: 110, alignment: .topLeading)
                .padding(8).background(Color.gray.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.gray.opacity(0.3)))
        }
        .onChange(of: logoCfg) { _, novo in novo.salvar() }
    }

    @ViewBuilder private var previewLogo: some View {
        switch logoCfg.modo {
        case .nenhum:
            Text(T("(no logo)")).font(.system(size: 13)).foregroundStyle(.secondary)
        case .imagem:
            if !logoCfg.imagemPath.isEmpty, let img = NSImage(contentsOfFile: logoCfg.imagemPath) {
                Image(nsImage: img).resizable().scaledToFit()
            } else {
                Text(T("(image not loaded)")).font(.system(size: 13)).foregroundStyle(.secondary)
            }
        case .texto:
            VStack(alignment: .leading, spacing: 2) {
                ForEach(0..<3, id: \.self) { i in
                    let l = logoCfg.linhas[i]
                    if !l.texto.isEmpty {
                        Text(l.texto)
                            .font(l.negrito ? .custom(l.fonte, size: CGFloat(l.tamanho)).bold()
                                             : .custom(l.fonte, size: CGFloat(l.tamanho)))
                            .foregroundStyle(Color(white: 0.1))
                    }
                }
            }
        }
    }

    private func carregarImagemLogo() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .bmp, .tiff]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            logoCfg.imagemPath = url.path
            logoCfg.salvar()
        }
    }

    // A-05
    private var emailOptions: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(T("Email sending")).font(.system(size: 13, weight: .semibold))
            ajuda(T("By default, OpenBody opens your Mac email app with the exam already attached. Just click Send. Nothing to configure."))
            passo(T("Prefer your own server (SMTP)? Fill in below (optional)."))
            // Campos REAIS: salvam a configuração usada pelo envio (a senha vai no Keychain).
            campoEditavel("Host", $emailHost, rotLargura: 70)
            campoEditavel("User", $emailUser, rotLargura: 70)
            ajuda("* This e-mail address will be shown to your members.")
            campoEditavel("Name", $emailNome, rotLargura: 70)
            ajuda("* This user name will be shown to your members.")
            campoEditavel("Password", $emailSenha, rotLargura: 70, seguro: true)
            campoEditavel("Port", $emailPorta, rotLargura: 70, largura: 80)
            HStack {
                botaoCinza("Save e-mail", largura: 130) { salvarEmail() }
                if !emailAviso.isEmpty {
                    Text(T(emailAviso)).font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            ajuda("Porta 465 = TLS direto (o que a maioria dos provedores aceita).")
            HStack(alignment: .top) {
                Text(T("Secure Connection")).font(.system(size: 13)).frame(width: 70, alignment: .leading)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 14) { radioSel("Use", $secureConn, 0); radioSel("Do not use", $secureConn, 1) }
                    HStack(spacing: 14) { radioSel("TLS 1.0(1.1)", $secureConn, 2); radioSel("TLS 1.2", $secureConn, 3) }
                }
            }
            rot("Select the type of results sheet to attach.")
            combo("InBody Result Sheet")
        }
    }

    // A-06
    private var editMemberInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            ajuda("Check items to edit or delete first. Editing/deleting also changes member information for other members concerned.")
            Text(T("Medical history")).font(.system(size: 13, weight: .semibold))
            ForEach([("Medical history", "Diabetes"), ("Medical history", "Dyslipidemia"),
                     ("Medical history", "Hypertension"), ("Body composition", "PBF over")], id: \.1) { cat, h in
                HStack {
                    chk("", false)
                    Text(T(cat)).font(.system(size: 11)).foregroundStyle(.secondary).frame(width: 90, alignment: .leading)
                    Text(T(h)).font(.system(size: 12)); Spacer()
                }.overlay(Rectangle().fill(Color.gray.opacity(0.1)).frame(height: 1), alignment: .bottom)
            }
            HStack { botaoCinza("Add", largura: 60); botaoCinza("Delete", largura: 60) }
            Text(T("Group")).font(.system(size: 13, weight: .semibold)).padding(.top, 8)
            HStack { chk("", false); Text("2").font(.system(size: 12)); Spacer() }
            HStack { botaoCinza("Add", largura: 60); botaoCinza("Delete", largura: 60) }
        }
    }

    // A-08
    private var autoLock: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Ativar/desativar a tela de login ao abrir o app (aplica no próximo início).
            Text(T("Login screen on app launch")).font(.system(size: 14, weight: .semibold))
            HStack(spacing: 20) {
                radioSelBool(T("Yes"), $setup.usarLogin, true)
                radioSelBool(T("No"), $setup.usarLogin, false)
            }
            .onChange(of: setup.usarLogin) { _, _ in setup.salvar() }
            Text(T("If on, the app asks for login every time it opens. (Takes effect next launch.)"))
                .font(.system(size: 12)).foregroundStyle(.secondary)
            Divider().padding(.vertical, 6)
            Text(T("Setup auto-lock to prevent unauthorized usage.")).font(.system(size: 13))
            ajuda("Screen will auto-lock after a set time. Input password to unlock screen.")
            rot("Setup auto-lock?")
            HStack(spacing: 20) { radioSelBool("No", $setup.autoLockAtivo, false); radioSelBool("Yes", $setup.autoLockAtivo, true) }
            rot("Auto-Lock after.")
            HStack {
                TextField("", value: $setup.autoLockMin, format: .number)
                    .textFieldStyle(.plain).font(.system(size: 14)).frame(width: 60, height: 22)
                    .padding(.horizontal, 6)
                    .background(RoundedRectangle(cornerRadius: 2).stroke(Color.gray.opacity(0.4)))
                Text(T("Min")).font(.system(size: 13))
            }
            rot("Set auto-lock password.")
            HStack {
                Text(T("Input password.")).font(.system(size: 12)).frame(width: 130, alignment: .leading)
                SecureField("", text: $autoLockSenha).textFieldStyle(.plain).font(.system(size: 14))
                    .frame(width: 200, height: 22).padding(.horizontal, 6)
                    .background(RoundedRectangle(cornerRadius: 2).stroke(Color.gray.opacity(0.4)))
                    .onChange(of: autoLockSenha) { _, s in if !s.isEmpty { Keychain.salvarSenhaAutoLock(s) } }
            }
            if Keychain.temSenhaAutoLock() {
                ajuda("Auto-lock password already set (type to change).")
            }
        }
    }

    // A-09
    private var customerService: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(T("Save the customer service provider's information in case of inquiries.")).font(.system(size: 13, weight: .semibold))
            ajuda("* When connected to the InBody, information will automatically save in LookinBody.")
            campoEditavel("Telephone No.", $setup.suporteTel, rotLargura: 100, largura: 300)
            campoEditavel("Name", $setup.suporteNome, rotLargura: 100, largura: 300)
            campoEditavel("Fax No.", $setup.suporteFax, rotLargura: 100, largura: 300)
            campoEditavel("E-mail", $setup.suporteEmail, rotLargura: 100, largura: 300)
            campoEditavel("Website", $setup.suporteSite, rotLargura: 100, largura: 300)
            campoEditavel("Address", $setup.suporteEndereco, rotLargura: 100, largura: 300)
        }
    }

    // A-10 (somente leitura — botão OK)
    private var programInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 40) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(T("Program Information")).font(.system(size: 13, weight: .semibold))
                    Text("OpenBody \(InfoMaquina.versaoApp)").font(.system(size: 12))
                    Text("\(T("Balance")): \(store.statusBalanca)").font(.system(size: 12))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(T("Computer Information")).font(.system(size: 13, weight: .semibold))
                    Text("\(T("Computer name")): \(InfoMaquina.nomeComputador)").font(.system(size: 12))
                }
            }
            Text(T("Update History")).font(.system(size: 13, weight: .semibold)).padding(.top, 8)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(T("Version 1.0.0")).font(.system(size: 13, weight: .semibold))
                    Text(T("· First edition for macOS")).font(.system(size: 13)).foregroundStyle(.secondary)
                }
                Text(T("Body composition app for macOS: live exam, result sheets, printing, email, backup and restore, cloud backup, and scale connection (WiFi, Bluetooth, USB, and serial)."))
                    .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }.padding(10).frame(maxWidth: .infinity, alignment: .leading).background(Color.gray.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            creditoBloco.padding(.top, 12)
        }
    }

    /// Bloco de crédito da tela Sobre (autoria do app).
    private var creditoBloco: some View {
        let marrom = Color(red: 0.40, green: 0.13, blue: 0.13)
        return VStack(spacing: 6) {
            Text("OpenBody").font(.system(size: 15, weight: .semibold)).foregroundStyle(marrom)
            Text(T("Version 1.0.0 · First edition for macOS")).font(.system(size: 13)).foregroundStyle(.secondary)
            Rectangle().fill(marrom.opacity(0.25)).frame(width: 60, height: 1).padding(.vertical, 2)
            Text(T("Concept and development")).font(.system(size: 12)).foregroundStyle(.secondary)
            Text("Dr. Gilberto Nering Junior").font(.system(size: 13, weight: .medium))
            Text(T("Non-profit app.")).font(.system(size: 12)).foregroundStyle(.secondary).padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 10).fill(marrom.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(marrom.opacity(0.2)))
    }

    // A-11 (popup real: "GDPR Options")
    private var gdprOptions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(T("GDPR Option setup")).font(.system(size: 13, weight: .semibold))
            grupo("Account", botao: "Account Management") {
                chkBind("Use Login", $setup.usarLogin)
                chkBind("Use user account", $setup.usarContaUsuario)
                chkBind("Use user authority", $setup.usarAutoridade)
                chkBind("Use change password after 3 months", $setup.trocarSenha3Meses)
            }
            grupo("Privacy policy agreement", botao: "Guardian verification") {
                chkBind("Use guardian verification", $setup.verificacaoResponsavel)
                chkBind("Use Privacy Policy Agreement", $setup.termoPrivacidade)
            }
            grupo("Privacy information masking") {
                chkBind("Use privacy information masking lv.1", $setup.mascaramento1)
                chkBind("Use privacy information masking lv.2", $setup.mascaramento2)
                chkBind("Auto-assign ID", $setup.autoID)
            }
            grupo("Data Save") { chkBind("Use data save agreement", $setup.termoDados) }
            grupo("Logs", botao: "User Logs") { chkBind("Use user logs", $setup.logsUsuario) }
            ajuda("* 'Use Login' will require login the next time the app opens.")
        }
    }

    private func grupo<C: View>(_ t: String, botao: String? = nil, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(T(t)).font(.system(size: 13, weight: .semibold))
                Spacer()
                if let botao { botaoCinza(botao, largura: 150) }
            }
            content()
        }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.2)))
    }

    private var generico: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(T(item)).font(.system(size: 13, weight: .bold))
            Text(T("LookinBody120 configuration screen. Options are saved with the button below."))
                .font(.system(size: 13)).foregroundStyle(.secondary)
        }
    }
}
