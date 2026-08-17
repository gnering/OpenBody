import SwiftUI

private let marromTitulo = Color(red: 0.40, green: 0.13, blue: 0.13)

private struct TituloPopup: View {
    let t: String; var aoFechar: () -> Void
    var body: some View {
        HStack {
            Text(T(t)).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
            Spacer()
            Button { aoFechar() } label: { Image(systemName: "xmark").font(.system(size: 14)).foregroundStyle(.white) }.buttonStyle(.plain)
        }.padding(.horizontal, 16).padding(.vertical, 11).background(marromTitulo)
    }
}

private struct GuiaPanel: View {
    let linhas: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(T("User's Guide")).font(.system(size: 12, weight: .semibold))
            Divider()
            ForEach(linhas.indices, id: \.self) { i in
                Text(T(linhas[i])).font(.system(size: 11)).foregroundStyle(i == 0 ? .primary : .secondary)
            }
            Spacer()
        }.padding(12).frame(width: 200).background(Color.gray.opacity(0.05))
    }
}

/// Print Results Sheets (manual p.65-66).
struct PrintView: View {
    @EnvironmentObject var store: Store
    var aoFechar: () -> Void
    // Seleção MÚLTIPLA de folhas: pré-marcada com as folhas escolhidas no Setup (A-03).
    @State private var selecionadas: Set<String> = SetupConfig.carregar().folhasImpressao
    @State private var mostrarPreview = false
    // Exames marcados para imprimir (chave = "<chave-do-paciente>@<data>"). Default: o último de cada.
    @State private var exameSel: Set<String> = []

    private func chaveExame(_ p: Paciente, _ e: Medida) -> String { "\(p.chave)@\(e.data)" }

    // Categorias/folhas do original (todas de volta). As que têm renderizador imprimem;
    // as demais (History, Blood Pressure, Blood Glucose) ficam disponíveis para marcar.
    private let categorias: [(String, [String])] = [
        ("InBody Test", ["InBody Result Sheet", "Body Water Result Sheet", "Body Composition\nHistory Result Sheet"]),
        ("Blood Pressure", ["Blood Pressure Results\nSheet"]),
        ("Blood Glucose", ["Blood Glucose Results\nSheet"]),
    ]

    /// Mapeia o nome exibido para o tipo de folha (nil = ainda sem renderizador). O rótulo da
    /// tabela quebra linha ("Body Composition\nHistory..."), então compara sem as quebras.
    private func tipoDe(_ nome: String) -> TipoFolha? {
        let chave = nome.replacingOccurrences(of: "\n", with: " ")
        return TipoFolha.allCases.first { $0.rawValue == chave }
    }

    var body: some View {
        VStack(spacing: 0) {
            TituloPopup(t: "Print", aoFechar: aoFechar)
            HStack(alignment: .top, spacing: 0) {
                VStack(spacing: 0) {
                    subCab("Folhas de resultado")
                    tabelaFolhas
                    subCab("Dados")
                    tabelaDados
                    Divider()
                    HStack {
                        Spacer()
                        botao("Preview") { mostrarPreview = true }
                        botao("Start Print") { imprimir() }
                    }.padding(8)
                    Spacer(minLength: 0)
                }.frame(maxWidth: .infinity)
                Divider()
                GuiaPanel(linhas: [
                    T("1. In \"Results sheets\", click the cells to choose what to print."),
                    "2. Em \"Dados\", marque os exames e clique em Imprimir.",
                    T("* By default, each patient's most recent exam is already checked."),
                ])
            }
        }
        .frame(width: 1080, height: 720).background(Color.white).foregroundStyle(.black)
        .onAppear {
            // Default: marca o exame mais recente de cada paciente listado.
            if exameSel.isEmpty {
                for p in store.membrosAlvo { if let e = p.ultimo { exameSel.insert(chaveExame(p, e)) } }
            }
        }
        .sheet(isPresented: $mostrarPreview) {
            if let p = store.pacienteAtual, let e = p.ultimo {
                // Preview mostra AS FOLHAS MARCADAS (na ordem), não mais uma folha fixa.
                let tipos = TipoFolha.allCases.filter { selecionadas.contains($0.rawValue) }
                VStack(spacing: 0) {
                    HStack { Text(T("Preview")).font(.headline); Spacer()
                        Button(T("Close")) { mostrarPreview = false } }.padding(12)
                    Divider()
                    ScrollView([.horizontal, .vertical]) {
                        VStack(spacing: 24) {
                            ForEach(tipos.isEmpty ? [.adulto] : tipos) { t in
                                FolhaEngineView(paciente: p, e: e, tipo: t).padding(16)
                            }
                        }
                    }
                }.frame(width: 940, height: 880)
            }
        }
    }

    private var tabelaFolhas: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text(T("Result Sheet Category")).frame(width: 160, alignment: .leading)
                Text(T("Select Result Sheet")).frame(maxWidth: .infinity, alignment: .leading)
            }.font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
            .padding(.horizontal, 8).padding(.vertical, 4).background(Color.gray.opacity(0.08))
            ForEach(categorias, id: \.0) { cat, folhas in
                HStack(spacing: 0) {
                    Text(T(cat)).font(.system(size: 12)).frame(width: 160, alignment: .leading)
                    HStack(spacing: 4) {
                        ForEach(folhas, id: \.self) { f in
                            let tipo = tipoDe(f)
                            let sel = tipo.map { selecionadas.contains($0.rawValue) } ?? false
                            Button {
                                guard let t = tipo else {
                                    let a = NSAlert(); a.messageText = T("Sheet not built yet")
                                    a.informativeText = "\(T(f)) " + T("is not printed by the app yet."); a.runModal(); return
                                }
                                if sel { selecionadas.remove(t.rawValue) } else { selecionadas.insert(t.rawValue) }
                            } label: {
                                Text(T(f)).font(.system(size: 11)).multilineTextAlignment(.center)
                                    .frame(width: 120, height: 40)
                                    .background(sel ? marromTitulo : Color.white)
                                    .foregroundStyle(sel ? .white : (tipo == nil ? .secondary : .black))
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(sel ? marromTitulo : Color.gray.opacity(0.35)))
                            }.buttonStyle(.plain)
                        }
                        Spacer()
                    }
                }.padding(.horizontal, 8).padding(.vertical, 4)
                .overlay(Rectangle().fill(Color.gray.opacity(0.12)).frame(height: 1), alignment: .bottom)
            }
        }
    }

    private var tabelaDados: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("").frame(width: 34)
                Text(T("Name")).frame(width: 130, alignment: .leading)
                Text(T("ID")).frame(width: 96, alignment: .leading)
                Text(T("Test Date / Time")).frame(width: 190, alignment: .leading)
                Text(T("Weight")).frame(width: 72)
                Text(T("Skeletal Muscle Mass")).frame(width: 100).multilineTextAlignment(.center)
                Text(T("Body Fat")).frame(width: 84).multilineTextAlignment(.center)
                Spacer(minLength: 0)
            }.font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            .padding(.horizontal, 8).padding(.vertical, 6).background(Color.gray.opacity(0.08))
            ScrollView {
                ForEach(store.membrosAlvo, id: \.chave) { p in
                    ForEach(p.exames) { e in
                        let sel = exameSel.contains(chaveExame(p, e))
                        HStack(spacing: 0) {
                            Button {
                                let k = chaveExame(p, e)
                                if exameSel.contains(k) { exameSel.remove(k) } else { exameSel.insert(k) }
                            } label: {
                                Image(systemName: sel ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 11)).frame(width: 30)
                                    .foregroundStyle(sel ? Color.accentColor : .secondary)
                            }.buttonStyle(.plain).frame(width: 34)
                            Text(p.nome).frame(width: 130, alignment: .leading).lineLimit(1)
                            Text(p.id).frame(width: 96, alignment: .leading).foregroundStyle(.secondary)
                                .lineLimit(1).truncationMode(.tail)
                            Text(dataBR(e.data)).frame(width: 190, alignment: .leading)
                            Text(String(format: "%.1f", e.peso)).frame(width: 72)
                            Text(String(format: "%.1f", e.smm)).frame(width: 100)
                            Text(String(format: "%.1f", e.gordura)).frame(width: 84)
                            Spacer(minLength: 0)
                        }.font(.system(size: 13)).padding(.horizontal, 8).padding(.vertical, 5)
                    }
                }
            }.frame(height: 300).background(Color.white).overlay(Rectangle().stroke(Color.gray.opacity(0.2)))
        }
    }

    private func imprimir() {
        let tipos = Set(selecionadas.compactMap(tipoDe))   // só as folhas que sabemos renderizar
        guard !tipos.isEmpty else { return }
        // Junta TODOS os exames marcados (de todos os pacientes listados) × folhas marcadas.
        var folhas: [FolhaParaImprimir] = []
        for p in store.membrosAlvo {
            for e in p.exames where exameSel.contains(chaveExame(p, e)) {
                folhas += folhasDoExame(p, e, tipos: tipos)
            }
        }
        // Fallback: nada marcado -> imprime o último do paciente destacado (como antes).
        if folhas.isEmpty, let p = store.pacienteAtual, let e = p.ultimo {
            folhas = folhasDoExame(p, e, tipos: tipos)
        }
        guard !folhas.isEmpty else { return }
        imprimirFolhas(folhas)
    }
    private func subCab(_ t: String) -> some View {
        HStack { Text(T(t)).font(.system(size: 12, weight: .semibold)); Spacer() }
            .padding(.horizontal, 8).padding(.vertical, 6).background(Color.gray.opacity(0.12))
    }

    private func botao(_ t: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) { Text(T(t)).font(.system(size: 11)).frame(width: 80, height: 24)
            .background(RoundedRectangle(cornerRadius: 3).stroke(Color.gray.opacity(0.4))) }.buttonStyle(.plain)
    }
}

/// Send E-mail (manual p.68-69). Envio real exige permissão — apenas monta.
struct EmailView: View {
    @EnvironmentObject var store: Store
    var aoFechar: () -> Void
    @State private var assunto = ""
    @State private var corpo = ""
    @State private var email = ""
    @State private var anexos: [String] = ["InBody Result Sheet"]
    @State private var aviso = ""
    @State private var enviando = false

    /// Envia de verdade pelo servidor configurado (Setup A-05), com a folha em PDF anexa —
    /// como o LookinBody do Windows. Sem servidor configurado, abre o Mail do Mac com o
    /// anexo pronto (aí quem clica em Enviar é você).
    private func enviar() {
        guard let p = store.pacienteAtual, let ex = p.ultimo else {
            aviso = T("Select a patient with an exam."); return
        }
        let destino = email.isEmpty ? p.email : email
        guard !destino.isEmpty, destino.contains("@") else {
            aviso = "Enter the recipient's e-mail."; return
        }
        guard ConfigEmail.carregar().configurado else {
            comporEmailComFolha(paciente: p, medida: ex, para: destino)
            aviso = T("I opened your Mac email with the exam attached. Just click Send.")
            return
        }
        // Mapeia os rótulos da UI (AttachView.folhas) para os TipoFolha implementados.
        let mapa: [String: TipoFolha] = [
            "InBody Result Sheet": .adulto,
            "Body Water Result Sheet": .agua,
            "Body Composition History Result Sheet": .historico,
            "InBody Children's Result Sheet": .pediatrica,
        ]
        let baseNome = p.nome.replacingOccurrences(of: " ", with: "_")
        var pdfs: [(String, Data)] = []
        var ignorados: [String] = []
        for a in anexos {
            guard let tipo = mapa[a] else { ignorados.append(a); continue }
            guard let pdf = pdfDaFolha(paciente: p, medida: ex, tipo: tipo) else {
                aviso = "Could not generate the sheet PDF: \(a)"; return
            }
            let sufixo = tipo == .adulto ? "" : "_\(tipo.rawValue.replacingOccurrences(of: " ", with: "_"))"
            pdfs.append(("InBody_\(baseNome)\(sufixo).pdf", pdf))
        }
        guard !pdfs.isEmpty else {
            aviso = "Selecione ao menos uma folha suportada."; return
        }
        let assuntoFinal = assunto.isEmpty ? "InBody — \(p.nome)" : assunto
        let corpoFinal = corpo.isEmpty ? T("Attached is the body composition exam result.") : corpo
        let avisoIgn = ignorados.isEmpty ? "" : " (sem PDF: \(ignorados.joined(separator: ", ")))"
        enviando = true; aviso = "Enviando…"
        Task.detached {
            let erro = enviarEmailComFolhas(para: destino, assunto: assuntoFinal,
                                            corpo: corpoFinal, anexos: pdfs)
            await MainActor.run {
                enviando = false
                aviso = erro ?? "Enviado para \(destino) — \(pdfs.count) folha(s).\(avisoIgn)"
            }
        }
    }
    @State private var mostrarAttach = false

    var body: some View {
        VStack(spacing: 0) {
            TituloPopup(t: "E-mail", aoFechar: aoFechar)
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    HStack { Text(T("Member(s)")).font(.system(size: 13, weight: .semibold)); Spacer() }
                        .padding(.horizontal, 12).padding(.vertical, 7).background(Color.gray.opacity(0.12))
                    if let p = store.pacienteAtual {
                        HStack(spacing: 0) {
                            Image(systemName: "checkmark.square.fill").font(.system(size: 15)).frame(width: 34)
                            Text(p.nome).font(.system(size: 14)).frame(width: 180, alignment: .leading)
                            Text(p.id).font(.system(size: 13)).frame(width: 110, alignment: .leading).foregroundStyle(.secondary)
                            TextField(T("Recipient email"), text: $email).textFieldStyle(.plain)
                                .font(.system(size: 13)).padding(.horizontal, 8).frame(height: 28)
                                .background(RoundedRectangle(cornerRadius: 3).stroke(Color.gray.opacity(0.4)))
                        }.padding(12)
                    }
                    Spacer()
                    HStack { Text(T("Compose")).font(.system(size: 13, weight: .semibold)); Spacer() }
                        .padding(.horizontal, 12).padding(.vertical, 7).background(Color.gray.opacity(0.12))
                    HStack { Text(T("Subject")).font(.system(size: 14)).frame(width: 72, alignment: .leading)
                        TextField("", text: $assunto).textFieldStyle(.plain).font(.system(size: 13))
                            .padding(.horizontal, 8).frame(height: 28)
                            .background(RoundedRectangle(cornerRadius: 3).stroke(Color.gray.opacity(0.4))) }.padding(12)
                    TextEditor(text: $corpo).font(.system(size: 13)).frame(height: 160)
                        .foregroundStyle(.black).scrollContentBackground(.hidden).background(Color.white)
                        .overlay(Rectangle().stroke(Color.gray.opacity(0.3))).padding(.horizontal, 12)
                    Divider()
                    HStack { Spacer()
                        if !aviso.isEmpty {
                            Text(T(aviso)).font(.system(size: 13))
                                .foregroundStyle(aviso.hasPrefix("Enviado") ? Color.okc : .red)
                        }
                        Button { enviar() } label: {
                            Text(T("Send")).font(.system(size: 14, weight: .medium)).frame(width: 110, height: 32)
                                .background(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.4)))
                        }.buttonStyle(.plain).padding(12).disabled(enviando) }
                }.frame(maxWidth: .infinity)
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    Text(T("Attach")).font(.system(size: 14, weight: .semibold)); Divider()
                    Text(T("Attachment(s)")).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                    ForEach(anexos, id: \.self) { a in
                        HStack {
                            Button { anexos.removeAll { $0 == a } } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.red).font(.system(size: 14))
                            }.buttonStyle(.plain)
                            Text(T(a)).font(.system(size: 13))
                        }
                    }
                    Button(T("Attach")) { mostrarAttach = true }.buttonStyle(.plain).font(.system(size: 13))
                        .frame(width: 100, height: 30).overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.4)))
                    Spacer()
                }.padding(16).frame(width: 260).background(Color.gray.opacity(0.05))
            }
        }.frame(width: 900, height: 680).background(Color.white).foregroundStyle(.black)
        .environment(\.colorScheme, .light)
        .sheet(isPresented: $mostrarAttach) {
            AttachView(jaAnexados: anexos) { escolhidos in
                for e in escolhidos where !anexos.contains(e) { anexos.append(e) }
                mostrarAttach = false
            } aoCancelar: { mostrarAttach = false }
        }
    }
}

/// Popup Attach (manual p.69-70): mesma seleção de folhas do Print.
struct AttachView: View {
    let jaAnexados: [String]
    var aoAnexar: ([String]) -> Void
    var aoCancelar: () -> Void
    @State private var escolhidos: Set<String> = []

    private let folhas = [
        "InBody Result Sheet", "Body Water Result Sheet", "Body Composition History Result Sheet",
        "Blood Pressure Results Sheet", "Blood Glucose Results Sheet",
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(T("Attach")).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                Spacer()
                Button { aoCancelar() } label: { Image(systemName: "xmark").foregroundStyle(.white) }.buttonStyle(.plain)
            }.padding(.horizontal, 12).padding(.vertical, 8).background(Color(red: 0.40, green: 0.13, blue: 0.13))
            VStack(alignment: .leading, spacing: 6) {
                Text(T("Select Result Sheet(s)")).font(.system(size: 11, weight: .semibold))
                ForEach(folhas, id: \.self) { f in
                    Button { toggle(f) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: escolhidos.contains(f) ? "checkmark.square.fill" : "square")
                                .foregroundStyle(escolhidos.contains(f) ? Color.accentColor : .secondary)
                            Text(T(f)).font(.system(size: 11)); Spacer()
                        }
                    }.buttonStyle(.plain)
                }
                Spacer()
                HStack {
                    Spacer()
                    Button(T("Cancel")) { aoCancelar() }.buttonStyle(.plain).font(.system(size: 11))
                        .frame(width: 70, height: 24).overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.gray.opacity(0.4)))
                    Button(T("Attach")) { aoAnexar(Array(escolhidos)) }.buttonStyle(.plain).font(.system(size: 11))
                        .frame(width: 70, height: 24).overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.gray.opacity(0.5)))
                }
            }.padding(16)
        }.frame(width: 380, height: 320).background(Color.white).foregroundStyle(.black)
    }
    private func toggle(_ f: String) {
        if escolhidos.contains(f) { escolhidos.remove(f) } else { escolhidos.insert(f) }
    }
}

/// Edit Data (manual p.72-74). Planilha editável estilo Excel com colunas
/// agrupadas (Member Info / InBody Test / Blood Pressure / Blood Glucose),
/// menu de botão direito (Add), Delete com confirmação e Save que persiste.
enum GrupoColuna: String, CaseIterable, Identifiable {
    case membro = "Member Info."
    case inbody = "InBody Test"
    case pressao = "Blood Pressure"
    case glicose = "Blood Glucose"
    var id: String { rawValue }
}

struct EditView: View {
    @EnvironmentObject var store: Store
    var aoFechar: () -> Void

    @State private var draft: [Paciente] = []
    @State private var escopo: Set<String> = []        // chaves abertas na grade (so elas mudam)
    @State private var grupo: GrupoColuna = .membro
    @State private var selLinhas: Set<String> = []     // chaves de linha marcadas
    @State private var confirmarExclusao = false

    var body: some View {
        VStack(spacing: 0) {
            TituloPopup(t: "Edit", aoFechar: aoFechar)
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    HStack {
                        Text("\(T("Date")) (\(draft.count))").font(.system(size: 11, weight: .semibold))
                        Spacer()
                        Text(T("Shortcut:")).font(.system(size: 12)).foregroundStyle(.secondary)
                        Picker("", selection: $grupo) {
                            ForEach(GrupoColuna.allCases) { Text($0.rawValue).tag($0) }
                        }.labelsHidden().frame(width: 150).onChange(of: grupo) { selLinhas.removeAll() }
                    }
                    .padding(.horizontal, 8).padding(.vertical, 5).background(Color.gray.opacity(0.12))

                    // GeometryReader + minWidth/minHeight: com poucas linhas o ScrollView de
                    // 2 eixos CENTRALIZA o conteudo; isso prende a tabela no topo-esquerda.
                    GeometryReader { g in
                        ScrollView([.horizontal, .vertical]) {
                            VStack(spacing: 0) {
                                cabecalho
                                switch grupo {
                                case .membro:  membroRows
                                case .inbody:  inbodyRows
                                case .pressao: pressaoRows
                                case .glicose: glicoseRows
                                }
                            }
                            .frame(minWidth: g.size.width, minHeight: g.size.height, alignment: .topLeading)
                        }
                    }.background(Color.white).overlay(Rectangle().stroke(Color.gray.opacity(0.2)))

                    Divider()
                    HStack {
                        Menu {
                            Button(T("Add Member")) { addMembro() }
                            if let mid = membroContexto {
                                Button(T("Add Blood Pressure")) { addPressao(mid) }
                                Button(T("Add Blood Glucose")) { addGlicose(mid) }
                            }
                        } label: {
                            Text(T("Add ▾")).font(.system(size: 11)).frame(width: 70, height: 24)
                                .background(RoundedRectangle(cornerRadius: 3).stroke(Color.gray.opacity(0.4)))
                        }.menuStyle(.borderlessButton).frame(width: 76)
                        Spacer()
                        Button { confirmarExclusao = true } label: {
                            Text(T("Delete")).font(.system(size: 11)).frame(width: 70, height: 24)
                                .background(RoundedRectangle(cornerRadius: 3).stroke(Color.gray.opacity(0.4)))
                        }.buttonStyle(.plain).disabled(selLinhas.isEmpty)
                        Button { salvar() } label: {
                            Text(T("Save")).font(.system(size: 11)).frame(width: 70, height: 24)
                                .background(RoundedRectangle(cornerRadius: 3).stroke(Color.gray.opacity(0.4)))
                        }.buttonStyle(.plain)
                    }.padding(8)
                }.frame(maxWidth: .infinity)
                Divider()
                GuiaPanel(linhas: [
                    "[How to Edit]",
                    "1. Use the Shortcut dropdown to switch column groups.",
                    "2. Edit cells directly, like an Excel spreadsheet.",
                    "* Member Info: right-click a row → Add Member / Add Blood Pressure / Add Blood Glucose (or use Add).",
                    "* InBody results cannot be added here (only ID and date are editable).",
                    "* Delete: check a row, click Delete (permanent).",
                ])
            }
        }
        .frame(width: 1060, height: 740).background(Color.white).foregroundStyle(.black)
        .onAppear {
            // Abre SO o cadastro do paciente selecionado; a grade com o acervo inteiro
            // dava a impressao (e o poder) de editar todos os pacientes de uma vez.
            // Sem selecao (nao deveria ocorrer: o botao Edit exige uma), mantem todos.
            if let sel = store.selecionado, let p = store.pacientes.first(where: { $0.id == sel }) {
                draft = [p]
            } else {
                draft = store.pacientes
            }
            escopo = Set(draft.map(\.chave))
        }
        .alert(grupo == .membro ? "Delete selected members?" : "Delete selected records?",
               isPresented: $confirmarExclusao) {
            Button(T("No"), role: .cancel) {}
            Button(T("Yes"), role: .destructive) { apagar() }
        } message: {
            Text(T("All results will be permanently deleted and cannot be restored."))
        }
    }

    // membro cujo contexto vale para Add BP/Glucose (destacado ou primeiro marcado)
    private var membroContexto: Paciente.ID? {
        if let k = selLinhas.first, let mid = k.split(separator: "|").first.map(String.init) { return mid }
        return draft.first?.id
    }

    // MARK: - Cabeçalhos

    @ViewBuilder private var cabecalho: some View {
        switch grupo {
        case .membro:
            hstackCab([("", 34), ("Name", 120), ("ID", 90), ("Height", 60), ("Gender", 70),
                       ("Date of Birth", 110), ("Age", 50), ("Mobile", 130)])
        case .inbody:
            hstackCab([("", 34), ("Name", 120), ("ID", 90), ("Test Date / Time", 140),
                       ("Weight", 70), ("Skeletal Muscle Mass", 130), ("Body Fat", 70)])
        case .pressao:
            hstackCab([("", 34), ("Name", 120), ("Date / Time", 140), ("Systolic", 80), ("Diastolic", 80)])
        case .glicose:
            hstackCab([("", 34), ("Name", 120), ("Date / Time", 140), ("Fasting", 80), ("2h After Meal", 90)])
        }
    }

    private func hstackCab(_ cols: [(String, CGFloat)]) -> some View {
        HStack(spacing: 0) {
            ForEach(cols.indices, id: \.self) { i in
                Text(cols[i].0).frame(width: cols[i].1, alignment: .leading)
            }
        }.font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
        .padding(.horizontal, 8).padding(.vertical, 4).background(Color.gray.opacity(0.08))
    }

    // MARK: - Linhas por grupo

    private var membroRows: some View {
        ForEach(draft.indices, id: \.self) { i in
            HStack(spacing: 0) {
                checkbox("\(draft[i].chave)|m")
                editCell($draft[i].nome, 120)
                Text(draft[i].id).frame(width: 90, alignment: .leading).font(.system(size: 12)).foregroundStyle(.secondary)
                editNum($draft[i].altura, 60)
                editCell($draft[i].sexo, 70)
                editCell($draft[i].nascimento, 110)
                editInt($draft[i].idade, 50)
                editCell($draft[i].celular, 130)
            }
            .padding(.horizontal, 8).padding(.vertical, 2)
            .overlay(Rectangle().fill(Color.gray.opacity(0.1)).frame(height: 1), alignment: .bottom)
            .contextMenu {
                Button(T("Add Member")) { addMembro() }
                Button(T("Add Blood Pressure")) { addPressao(draft[i].chave) }
                Button(T("Add Blood Glucose")) { addGlicose(draft[i].chave) }
            }
        }
    }

    private var inbodyRows: some View {
        ForEach(draft.indices, id: \.self) { i in
            ForEach(draft[i].exames.indices, id: \.self) { j in
                HStack(spacing: 0) {
                    checkbox("\(draft[i].chave)|e\(j)")
                    Text(draft[i].nome).frame(width: 120, alignment: .leading).font(.system(size: 12)).lineLimit(1)
                    Text(draft[i].id).frame(width: 90, alignment: .leading).font(.system(size: 12)).foregroundStyle(.secondary)
                    editCell(dataEditBinding($draft[i].exames[j].data), 190)
                    Text(String(format: "%.1f", draft[i].exames[j].peso)).frame(width: 70).font(.system(size: 12))
                    Text(String(format: "%.1f", draft[i].exames[j].smm)).frame(width: 130).font(.system(size: 12))
                    Text(String(format: "%.1f", draft[i].exames[j].gordura)).frame(width: 70).font(.system(size: 12))
                }
                .padding(.horizontal, 8).padding(.vertical, 2)
                .overlay(Rectangle().fill(Color.gray.opacity(0.1)).frame(height: 1), alignment: .bottom)
            }
        }
    }

    private var pressaoRows: some View {
        ForEach(draft.indices, id: \.self) { i in
            ForEach(draft[i].pressoes.indices, id: \.self) { j in
                HStack(spacing: 0) {
                    checkbox("\(draft[i].chave)|p\(draft[i].pressoes[j].id)")
                    Text(draft[i].nome).frame(width: 120, alignment: .leading).font(.system(size: 12)).lineLimit(1)
                    editCell(dataEditBinding($draft[i].pressoes[j].data), 190)
                    editIntCell($draft[i].pressoes[j].sistolica, 80)
                    editIntCell($draft[i].pressoes[j].diastolica, 80)
                }
                .padding(.horizontal, 8).padding(.vertical, 2)
                .overlay(Rectangle().fill(Color.gray.opacity(0.1)).frame(height: 1), alignment: .bottom)
                .contextMenu { Button(T("Add Blood Pressure")) { addPressao(draft[i].chave) } }
            }
        }
    }

    private var glicoseRows: some View {
        ForEach(draft.indices, id: \.self) { i in
            ForEach(draft[i].glicoses.indices, id: \.self) { j in
                HStack(spacing: 0) {
                    checkbox("\(draft[i].chave)|g\(draft[i].glicoses[j].id)")
                    Text(draft[i].nome).frame(width: 120, alignment: .leading).font(.system(size: 12)).lineLimit(1)
                    editCell(dataEditBinding($draft[i].glicoses[j].data), 190)
                    editIntOpt($draft[i].glicoses[j].jejum, 80)
                    editIntOpt($draft[i].glicoses[j].posPrandial, 90)
                }
                .padding(.horizontal, 8).padding(.vertical, 2)
                .overlay(Rectangle().fill(Color.gray.opacity(0.1)).frame(height: 1), alignment: .bottom)
                .contextMenu { Button(T("Add Blood Glucose")) { addGlicose(draft[i].chave) } }
            }
        }
    }

    // MARK: - Células editáveis

    private func checkbox(_ chave: String) -> some View {
        Image(systemName: selLinhas.contains(chave) ? "checkmark.square.fill" : "square")
            .font(.system(size: 12)).frame(width: 34)
            .foregroundStyle(selLinhas.contains(chave) ? Color.accentColor : .secondary)
            .onTapGesture {
                if selLinhas.contains(chave) { selLinhas.remove(chave) } else { selLinhas.insert(chave) }
            }
    }
    private func editCell(_ b: Binding<String>, _ w: CGFloat) -> some View {
        TextField("", text: b).textFieldStyle(.plain).font(.system(size: 12))
            .padding(.horizontal, 4).frame(width: w - 6, height: 20)
            .background(RoundedRectangle(cornerRadius: 2).stroke(Color.gray.opacity(0.25)))
            .frame(width: w)
    }
    private func editNum(_ b: Binding<Double>, _ w: CGFloat) -> some View {
        TextField("", value: b, format: .number).textFieldStyle(.plain).font(.system(size: 12))
            .padding(.horizontal, 4).frame(width: w - 6, height: 20)
            .background(RoundedRectangle(cornerRadius: 2).stroke(Color.gray.opacity(0.25)))
            .frame(width: w)
    }
    private func editInt(_ b: Binding<Int>, _ w: CGFloat) -> some View {
        TextField("", value: b, format: .number).textFieldStyle(.plain).font(.system(size: 12))
            .padding(.horizontal, 4).frame(width: w - 6, height: 20)
            .background(RoundedRectangle(cornerRadius: 2).stroke(Color.gray.opacity(0.25)))
            .frame(width: w)
    }
    private func editIntCell(_ b: Binding<Int>, _ w: CGFloat) -> some View { editInt(b, w) }
    private func editIntOpt(_ b: Binding<Int?>, _ w: CGFloat) -> some View {
        let s = Binding<String>(
            get: { b.wrappedValue.map(String.init) ?? "" },
            set: { b.wrappedValue = Int($0) }
        )
        return TextField("", text: s).textFieldStyle(.plain).font(.system(size: 12))
            .padding(.horizontal, 4).frame(width: w - 6, height: 20)
            .background(RoundedRectangle(cornerRadius: 2).stroke(Color.gray.opacity(0.25)))
            .frame(width: w)
    }

    // MARK: - Ações

    private func addMembro() {
        let f = DateFormatter(); f.dateFormat = "yyMMdd"
        let base = f.string(from: Date())
        var n = 1
        while draft.contains(where: { $0.id == "\(base)-\(n)" }) { n += 1 }
        draft.insert(Paciente(id: "\(base)-\(n)", nome: "", sexo: "", idade: 0, altura: 0, exames: []), at: 0)
        grupo = .membro
    }
    private func addPressao(_ chaveMembro: String) {
        guard let i = draft.firstIndex(where: { $0.chave == chaveMembro }) else { return }
        let f = DateFormatter(); f.dateFormat = "yyyy/MM/dd HH:mm"
        draft[i].pressoes.append(LeituraPressao(data: f.string(from: Date()), sistolica: 120, diastolica: 80))
        grupo = .pressao
    }
    private func addGlicose(_ chaveMembro: String) {
        guard let i = draft.firstIndex(where: { $0.chave == chaveMembro }) else { return }
        let f = DateFormatter(); f.dateFormat = "yyyy/MM/dd HH:mm"
        draft[i].glicoses.append(LeituraGlicose(data: f.string(from: Date()), jejum: 90, posPrandial: nil))
        grupo = .glicose
    }

    private func apagar() {
        for chave in selLinhas {
            // chave = "<chave-do-membro>|<tag>"; a chave do membro contém "l:LOCAL" ou "u:ID".
            guard let sep = chave.lastIndex(of: "|") else { continue }
            let chaveMembro = String(chave[..<sep])
            let tag = String(chave[chave.index(after: sep)...])
            guard let i = draft.firstIndex(where: { $0.chave == chaveMembro }) else { continue }
            if tag == "m" {
                draft.removeAll { $0.chave == chaveMembro }   // chave é única: apaga só este
            } else if tag.hasPrefix("e"), let j = Int(tag.dropFirst()), j < draft[i].exames.count {
                draft[i].exames.remove(at: j)
            } else if tag.hasPrefix("p") {
                let rid = String(tag.dropFirst())
                draft[i].pressoes.removeAll { "\($0.id)" == rid }
            } else if tag.hasPrefix("g") {
                let rid = String(tag.dropFirst())
                draft[i].glicoses.removeAll { "\($0.id)" == rid }
            }
        }
        selLinhas.removeAll()
    }

    private func salvar() {
        // A grade cobre so o ESCOPO aberto (paciente selecionado). O resto do acervo
        // entra INTACTO na reconciliacao: reconciliar apaga do banco quem ficar de
        // fora do draft, entao mandar so o escopo apagaria todos os outros.
        var completo: [Paciente] = []
        for p in store.pacientes {
            if escopo.contains(p.chave) {
                // editado na grade; se foi apagado la, fica de fora (= excluir do banco)
                if let d = draft.first(where: { $0.chave == p.chave }) { completo.append(d) }
            } else {
                completo.append(p)
            }
        }
        let chavesAtuais = Set(completo.map(\.chave))
        completo += draft.filter { !chavesAtuais.contains($0.chave) }   // Add Member
        store.reconciliar(draft: completo)   // persiste exclusoes no banco + adota o draft
        if let sel = store.selecionado, !completo.contains(where: { $0.id == sel }) {
            store.selecionado = completo.first?.id
        }
        store.selecionados = store.selecionados.filter { chave in completo.contains { $0.chave == chave } }
        aoFechar()
    }
}
