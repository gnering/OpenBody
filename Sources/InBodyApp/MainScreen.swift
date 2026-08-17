import SwiftUI
import AppKit

/// Tela principal do LookinBody120 (manual p.22): três painéis
/// Select Member | Select Test | Manage Results, e barra de status marrom.
struct MainScreen: View {
    @EnvironmentObject var store: Store
    /// Numero de vitrine p/ filmagem (so muda o ROTULO da contagem, nunca os dados).
    /// Ligar:    defaults write com.openbody.app demoTotal -int 4351
    /// Desligar: defaults delete com.openbody.app demoTotal
    private var totalExibido: Int {
        let demo = UserDefaults.standard.integer(forKey: "demoTotal")
        return demo > 0 ? demo : store.filtrados.count
    }
    @State private var mostrarCadastro = false
    @State private var mostrarSetup = false
    @State private var mostrarTeste = false
    @State private var mostrarTestePressao = false
    @State private var mostrarSaude = false
    @State private var mostrarPressao = false
    @State private var mostrarGlicose = false
    @State private var mostrarPrint = false
    @State private var mostrarEmail = false
    @State private var mostrarEdit = false
    @State private var mostrarTroubleshooting = false
    @State private var mostrarConexao = false
    @State private var infoMembro: Paciente.ID?
    @State private var avisoSelecione = false

    private let marrom = Color(red: 0.30, green: 0.16, blue: 0.16)
    private let cabecalhoCinza = Color(red: 0.28, green: 0.29, blue: 0.31)


    var body: some View {
        VStack(spacing: 0) {
            barraTopo
            HStack(alignment: .top, spacing: 0) {
                painelSelectMember.frame(minWidth: 460, maxWidth: .infinity)
                divisor
                painelSelectTest.frame(width: 200)
                divisor
                painelManageResults.frame(width: 250)
            }
            .frame(maxHeight: .infinity)
            statusBar
        }
        .background(Color(red: 0.95, green: 0.95, blue: 0.96))
        .foregroundStyle(.black)
        .sheet(isPresented: $mostrarCadastro) {
            RegisterMemberView { iniciarTeste in
                mostrarCadastro = false
                if iniciarTeste {
                    DispatchQueue.main.async { mostrarTeste = true }
                }
            }
        }
        .sheet(isPresented: $mostrarSetup) { SetupView { mostrarSetup = false } }
        .sheet(isPresented: $mostrarTeste) {
            if let p = store.pacienteAtual {
                InBodyTestView(paciente: p) { mostrarTeste = false }
            }
        }
        .sheet(isPresented: $mostrarTestePressao) {
            if let p = store.pacienteAtual {
                BloodPressureTestView(paciente: p) { mostrarTestePressao = false }
            }
        }
        .sheet(isPresented: $mostrarSaude) {
            if let p = store.pacienteAtual {
                HealthReportView(paciente: p) { mostrarSaude = false }
            }
        }
        .sheet(isPresented: $mostrarPressao) {
            if let p = store.pacienteAtual { BloodPressureReportView(paciente: p) { mostrarPressao = false } }
        }
        .sheet(isPresented: $mostrarGlicose) {
            if let p = store.pacienteAtual { BloodGlucoseReportView(paciente: p) { mostrarGlicose = false } }
        }
        .sheet(isPresented: $mostrarPrint) { PrintView { mostrarPrint = false } }
        .sheet(isPresented: $mostrarEmail) { EmailView { mostrarEmail = false } }
        .sheet(isPresented: $mostrarEdit) { EditView { mostrarEdit = false } }
        .sheet(item: Binding(get: { infoMembro.map { Ident(id: $0) } }, set: { infoMembro = $0?.id })) { it in
            MemberInfoView(memberID: it.id) { infoMembro = nil }
        }
        .alert(T("First, select a member."), isPresented: $avisoSelecione) {
            Button("OK", role: .cancel) {}
        }
        // Login sobreposto: garante que Logout volte ao Login sem depender do shell.
        .overlay {
            if !store.logado {
                LoginView {}.transition(.opacity)
            }
        }
        .sheet(isPresented: $mostrarTroubleshooting) { troubleshootingSheet }
        .sheet(isPresented: $mostrarConexao) { ConexaoView { mostrarConexao = false } }
    }

    private struct Ident: Identifiable { let id: String }

    // Barra superior estilo toolbar do macOS (Apple HIG): título do app à esquerda,
    // botão nativo "Configurações" à direita, cores semânticas (adaptam claro/escuro),
    // altura de toolbar (44pt) e separador hairline embaixo.
    private var barraTopo: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.title3)
                    .foregroundStyle(.tint)
                Text("OpenBody")
                    .font(.headline)
                    .foregroundStyle(Color(nsColor: .labelColor))
                Spacer()
                Button { mostrarSetup = true } label: {
                    Label(T("Setup"), systemImage: "gearshape")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            Divider()
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var divisor: some View { Rectangle().fill(Color.gray.opacity(0.25)).frame(width: 1) }

    private func cabecalho(_ icone: String, _ titulo: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icone).font(.subheadline)
            Text(T(titulo)).font(.headline)
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(minHeight: 32)
        .background(cabecalhoCinza)
    }

    private func botaoLB(_ t: String, largura: CGFloat = 70) -> some View {
        Text(T(t)).font(.system(size: 11))
            .frame(width: largura, height: 24)
            .background(RoundedRectangle(cornerRadius: 3).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.gray.opacity(0.4)))
    }

    // ----- painel esquerdo: Select Member -----
    private var painelSelectMember: some View {
        VStack(spacing: 0) {
            cabecalho("checkmark", "Select Member")
            VStack(alignment: .leading, spacing: 8) {
                // Busca por modo (manual p.34-40)
                Text(T("Search by Name or ID")).font(.system(size: 11)).foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Picker("", selection: $store.modoBusca) {
                        ForEach(ModoBusca.allCases) { Text(T($0.rawValue)).tag($0) }
                    }.labelsHidden().frame(width: 130)

                    if store.modoBusca == .dataTeste {
                        DatePicker("", selection: $store.dataInicio, displayedComponents: .date)
                            .labelsHidden().datePickerStyle(.field).scaleEffect(0.85)
                        Text(T("~")).font(.system(size: 11))
                        DatePicker("", selection: $store.dataFim, displayedComponents: .date)
                            .labelsHidden().datePickerStyle(.field).scaleEffect(0.85)
                        botaoBusca("Search") { store.usarIntervaloData = true }
                    } else {
                        TextField(placeholderBusca, text: $store.busca).textFieldStyle(.plain)
                            .padding(.horizontal, 6).frame(height: 22)
                            .background(RoundedRectangle(cornerRadius: 2).stroke(Color.gray.opacity(0.4)))
                        botaoBusca("Search") {}
                        botaoBusca("List All") { store.busca = ""; store.usarIntervaloData = false }
                    }
                }

                HStack(spacing: 6) {
                    Button { mostrarCadastro = true } label: { botaoLB("Register New", largura: 100) }
                        .buttonStyle(.plain)
                    Button { importarPlanilha() } label: { botaoLB("Import spreadsheet", largura: 130) }
                        .buttonStyle(.plain)
                }

                // sub-cabeçalho Member(s) + ordenação + contagem
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "person.fill").font(.system(size: 10))
                        Text("\(T("All Members")) (\(totalExibido) \(T("person(s)"))")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    Spacer()
                    Picker("", selection: $store.ordenacao) {
                        ForEach(Ordenacao.allCases) { Text(T($0.rawValue)).tag($0) }
                    }.labelsHidden().frame(width: 150)
                }
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(Color.gray.opacity(0.12))

                TabelaPacientes(
                    onInfo: { infoMembro = $0 },
                    onInBody: { store.selecionado = $0; mostrarSaude = true },
                    onPressao: { store.selecionado = $0; mostrarPressao = true },
                    onGlicose: { store.selecionado = $0; mostrarGlicose = true }
                )
            }
            .padding(12)
        }
        .background(Color(red: 0.95, green: 0.95, blue: 0.96))
    }

    private var placeholderBusca: String {
        switch store.modoBusca {
        case .nomeOuId: return T("Name or ID")
        case .celular: return T("Mobile No.")
        case .historico: return T("Medical history")
        case .grupo: return T("Group")
        case .dataTeste: return ""
        }
    }

    /// Cadastro em massa (E7): abre uma planilha CSV e importa; oferece salvar o modelo.
    private func importarPlanilha() {
        let painel = NSOpenPanel()
        painel.allowedContentTypes = [.commaSeparatedText, .plainText]
        painel.message = "Choose the registration spreadsheet (CSV). Need the template? Cancel and click Save template."
        painel.prompt = T("Import")
        if painel.runModal() == .OK, let url = painel.url,
           let texto = try? String(contentsOf: url, encoding: .utf8) {
            let r = CadastroEmMassa.importar(csv: texto, store: store)
            store.statusBalanca = r.aviso
        } else {
            // sem arquivo: oferece salvar o modelo em branco
            let salvar = NSSavePanel()
            salvar.nameFieldStringValue = "modelo_cadastro.csv"
            salvar.allowedContentTypes = [.commaSeparatedText]
            if salvar.runModal() == .OK, let out = salvar.url {
                try? CadastroEmMassa.modelo().write(to: out, atomically: true, encoding: .utf8)
            }
        }
    }

    private func botaoBusca(_ t: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) { botaoLB(t, largura: 54) }.buttonStyle(.plain)
    }

    // ----- painel central: Select Test -----
    private var painelSelectTest: some View {
        VStack(spacing: 0) {
            cabecalho("square.and.pencil", "Select Test")
            VStack(spacing: 12) {
                Button {
                    if store.selecionado != nil { mostrarTeste = true } else { avisoSelecione = true }
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "figure.stand").font(.system(size: 30))
                        Text(T("InBody\nTest")).multilineTextAlignment(.center).font(.system(size: 13, weight: .medium))
                    }
                    .frame(width: 130, height: 110)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.35)))
                    .opacity(store.selecionado == nil ? 0.5 : 1)
                }
                .buttonStyle(.plain)
                .padding(.top, 24)

                // Botão para abrir a tela de conexão com a balança.
                Button { mostrarConexao = true } label: {
                    HStack(spacing: 6) {
                        Circle().fill(store.conectado ? Color.okc : Color.gray).frame(width: 8, height: 8)
                        Text(store.conectado ? T("Scale connected") : T("Connect scale"))
                            .font(.system(size: 12, weight: .medium))
                    }
                    .frame(width: 130, height: 32)
                    .background(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.35)))
                }.buttonStyle(.plain)

                // Blood Pressure Test só quando o monitor está conectado (manual p.52)
                if store.monitorPressaoConectado {
                    Button {
                        if store.selecionado != nil { mostrarTestePressao = true } else { avisoSelecione = true }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "heart.fill").font(.system(size: 22)).foregroundStyle(.white)
                            Text(T("Blood Pressure\nTest")).multilineTextAlignment(.center)
                                .font(.system(size: 12, weight: .medium)).foregroundStyle(.white)
                        }
                        .frame(width: 130, height: 84)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.62, green: 0.16, blue: 0.16)))
                    }.buttonStyle(.plain)
                }
                Spacer()
            }
        }
        .background(Color(red: 0.95, green: 0.95, blue: 0.96))
    }

    // ----- painel direito: Manage Results -----
    private var painelManageResults: some View {
        VStack(spacing: 0) {
            cabecalho("list.bullet.rectangle", "Manage Results")
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Button { comSelecao { mostrarPrint = true } } label: { botaoLB("Print") }.buttonStyle(.plain)
                    Button { comSelecao { mostrarEmail = true } } label: { botaoLB("E-mail") }.buttonStyle(.plain)
                    Button { comSelecao { mostrarEdit = true } } label: { botaoLB("Edit") }.buttonStyle(.plain)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(T("User's Guide")).font(.system(size: 12, weight: .semibold))
                    Divider()
                    Text(T("First, select a member.")).font(.system(size: 12, weight: .semibold))
                    Text(T("'Select Test' or 'Manage Results' on top after selecting"))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.2)))
                Spacer()
            }
            .padding(12)
        }
        .background(Color(red: 0.95, green: 0.95, blue: 0.96))
    }

    /// Print/E-mail/Edit exigem membro selecionado (manual: "First, select a member.").
    private func comSelecao(_ acao: () -> Void) {
        if store.membrosAlvo.isEmpty { avisoSelecione = true } else { acao() }
    }

    private var statusBar: some View {
        HStack(spacing: 20) {
            Button { mostrarConexao = true } label: {
                HStack(spacing: 7) {
                    Circle().fill(store.conectado ? Color.okc : Color.gray).frame(width: 10, height: 10)
                    Text(T(statusConexao)).font(.system(size: 14)).foregroundStyle(.white.opacity(0.9))
                    Image(systemName: "chevron.right").font(.system(size: 9)).foregroundStyle(.white.opacity(0.6))
                }
            }.buttonStyle(.plain)
            Spacer()
            Button(T("Troubleshooting")) { mostrarTroubleshooting = true }
                .buttonStyle(.plain).font(.system(size: 14, weight: .medium)).foregroundStyle(.white.opacity(0.95))
            Button(T("Logout")) { store.logout() }
                .buttonStyle(.plain).font(.system(size: 14, weight: .medium)).foregroundStyle(.white.opacity(0.95))
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(store.versao).font(.system(size: 13)).foregroundStyle(.white.opacity(0.75))
                Text(T("Developed by") + " Dr. Gilberto Nering Junior")
                    .font(.system(size: 10)).italic().foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 9)
        .background(marrom)
    }

    private var statusConexao: String {
        if !store.conectado { return T("Disconnected") }
        return store.statusBalanca + (store.monitorPressaoConectado ? T(", Blood Pressure Monitor") : "")
    }

    // Ajuda de conexão (link Troubleshooting da barra). Também permite marcar o monitor
    // de pressão como conectado, tornando o fluxo de Blood Pressure Test acessível.
    private var troubleshootingSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(T("Troubleshooting")).font(.system(size: 13, weight: .semibold))
                Spacer()
                Button { mostrarTroubleshooting = false } label: { Image(systemName: "xmark") }.buttonStyle(.plain)
            }
            Divider()
            Text(T("Connection help")).font(.system(size: 12, weight: .semibold))
            Text(T("• Check that the InBody is on the same network and powered on.\n• Confirm the InBody model and interface under Setup.\n• Always connect a Blood Pressure Monitor from InBody."))
                .font(.system(size: 11)).foregroundStyle(.secondary)
            Divider()
            Button { store.conectar() } label: {
                Label(store.ocupado ? T("Connecting…") : T("Connect InBody"), systemImage: "dot.radiowaves.left.and.right")
                    .font(.system(size: 11))
            }.buttonStyle(.plain).disabled(store.ocupado)
            Toggle(isOn: $store.monitorPressaoConectado) {
                Text(T("Blood Pressure Monitor connected")).font(.system(size: 11))
            }
            Spacer()
        }
        .padding(16).frame(width: 380, height: 300).background(Color.white).foregroundStyle(.black)
    }
}
