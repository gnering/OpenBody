import SwiftUI

/// Formulário "Register New" replicado do LookinBody120 (manual p.29-30).
/// Barra de título azul, seção Required, Optional (Show/Hide), consentimentos, Register.
struct RegisterMemberView: View {
    @EnvironmentObject var store: Store
    /// Fecha o formulário. `iniciarTeste` = abrir o InBody Test após cadastrar.
    var aoConcluir: (_ iniciarTeste: Bool) -> Void

    @State private var nome = ""
    @State private var id = ""
    @State private var autoID = false            // padrão No (manual p.29)
    @State private var altura = ""
    @State private var sexo = ""
    @State private var ano = ""
    @State private var mes = ""
    @State private var dia = ""
    @State private var mostrarOpcional = false
    // opcionais
    @State private var celular = ""
    @State private var telefone = ""
    @State private var endereco = ""
    @State private var cep = ""
    @State private var email = ""
    @State private var historico = "None"
    @State private var grupo = ""
    // consentimentos
    @State private var aceitoTudo = false
    @State private var aceitoTermos = false
    @State private var aceitoPriv = false
    @State private var aceitoSens = false
    @State private var testarAposCadastro = true
    @State private var erro = ""

    private let azulTitulo = Color(red: 0.20, green: 0.29, blue: 0.48)
    // Histórico médico do original (A-06). Guardado sempre com a chave em inglês (compatível
    // com o banco do LookinBody); a tela mostra traduzido.
    private let historicos = ["None", "Diabetes", "Hypertension", "Hyperlipidemia", "Osteoporosis", "Others"]
    private func nomeHistorico(_ k: String) -> String {
        return T(k)
    }

    private var idadeCalculada: Double? {
        guard let a = Int(ano), let m = Int(mes), let d = Int(dia),
              let nasc = Calendar.current.date(from: DateComponents(year: a, month: m, day: d))
        else { return nil }
        let dias = Calendar.current.dateComponents([.day], from: nasc, to: Date()).day ?? 0
        return Double(dias) / 365.25
    }

    var body: some View {
        VStack(spacing: 0) {
            barraTitulo
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    secaoRequired
                    secaoOpcional
                }.padding(16)
            }
            rodape
        }
        .frame(width: 640, height: 580)
        .background(Color.white)
        .foregroundStyle(.black)
    }

    private var barraTitulo: some View {
        HStack {
            Text(T("Register New")).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
            Spacer()
            Button { aoConcluir(false) } label: {
                Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(azulTitulo)
    }

    private func rotulo(_ t: String) -> some View {
        Text(T(t)).font(.system(size: 11)).frame(width: 90, alignment: .leading)
            .padding(.vertical, 7).padding(.leading, 8)
            .background(Color.gray.opacity(0.08))
    }
    private func caixa(_ texto: Binding<String>, largura: CGFloat = 150) -> some View {
        TextField("", text: texto).textFieldStyle(.plain).font(.system(size: 12))
            .padding(.horizontal, 6).frame(width: largura, height: 24)
            .background(RoundedRectangle(cornerRadius: 2).stroke(Color.gray.opacity(0.4)))
    }

    private var secaoRequired: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(T("Required")).font(.system(size: 13, weight: .bold))
                    Spacer()
                    botao("Print Form", largura: 90) { imprimirFormulario() }
                }.padding(.bottom, 8)

                linha { rotulo("Name"); caixa($nome, largura: 200) }
                linha {
                    rotulo("ID")
                    caixa($id, largura: 150).disabled(autoID).opacity(autoID ? 0.5 : 1)
                    Text(T("* Auto-assign ID?")).font(.system(size: 10, weight: .semibold)).padding(.leading, 8)
                    radio("Yes", autoID) { autoID = true }
                    radio("No", !autoID) { autoID = false }
                }
                Text(T("* Lowercase alphabets and numbers, -, _ only (1-14 characters)"))
                    .font(.system(size: 9)).foregroundStyle(.secondary).padding(.leading, 98).padding(.bottom, 2)
                linha { rotulo("Height"); caixa($altura, largura: 60); Text(T("cm")).font(.system(size: 11)) }
                linha {
                    rotulo("Gender")
                    radio("Male", sexo == "M") { sexo = "M" }
                    radio("Female", sexo == "F") { sexo = "F" }
                }
                linha {
                    rotulo("Date of Birth")
                    caixa($ano, largura: 46); Text(T("Yr.")).font(.system(size: 10))
                    caixa($mes, largura: 36); Text(T("Mo.")).font(.system(size: 10))
                    caixa($dia, largura: 36); Text(T("Day")).font(.system(size: 10))
                }
                Text(T("For children under 18, input date of birth to determine the exact age."))
                    .font(.system(size: 9)).foregroundStyle(.secondary).padding(.leading, 98)
                linha {
                    rotulo("Age")
                    Text(idadeCalculada.map { $0 < 18 ? String(format: "%.1f", $0) : "\(Int($0))" } ?? "-")
                        .font(.system(size: 12)).frame(width: 60, height: 24, alignment: .leading)
                        .padding(.horizontal, 6)
                        .background(RoundedRectangle(cornerRadius: 2).fill(Color.gray.opacity(0.08)))
                    if let a = idadeCalculada, a < 16 {
                        botao("Verification", largura: 90) {}
                    }
                }
            }
            // Placeholder de foto à direita (manual p.29)
            VStack {
                Image(systemName: "person.crop.square").font(.system(size: 60)).foregroundStyle(.gray.opacity(0.35))
                    .frame(width: 96, height: 110)
                    .background(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.3)))
            }.padding(.top, 24)
        }
    }

    private var secaoOpcional: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(T("Optional")).font(.system(size: 13, weight: .bold))
                Spacer()
                Text(T("* Medical history(s) and group(s) can be modified in Setup."))
                    .font(.system(size: 9)).foregroundStyle(.secondary)
                botao(mostrarOpcional ? "Hide" : "Show", largura: 54) { mostrarOpcional.toggle() }
            }.padding(.top, 14).padding(.bottom, 8)

            if mostrarOpcional {
                linha { rotulo("Mobile No."); caixa($celular, largura: 200) }
                linha {
                    rotulo("Medical history")
                    Picker("", selection: $historico) {
                        ForEach(historicos, id: \.self) { Text(nomeHistorico($0)).tag($0) }
                    }.labelsHidden().frame(width: 200)
                }
                linha {
                    rotulo("Group"); caixa($grupo, largura: 150)
                    botao("Add", largura: 44) {}
                }
                linha { rotulo("Telephone No."); caixa($telefone, largura: 200) }
                linha { rotulo("Address"); Text(T("Zip Code")).font(.system(size: 10)); caixa($cep, largura: 100) }
                linha { rotulo("Address"); caixa($endereco, largura: 260) }
                linha { rotulo("E-mail"); caixa($email, largura: 260) }
                linha {
                    rotulo("Registration Date")
                    Text(hoje()).font(.system(size: 12)).frame(width: 120, height: 24, alignment: .leading)
                        .padding(.horizontal, 6)
                        .background(RoundedRectangle(cornerRadius: 2).fill(Color.gray.opacity(0.08)))
                }
            }
        }
    }

    private var rodape: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
            if !erro.isEmpty {
                Text(T(erro)).font(.system(size: 10, weight: .semibold)).foregroundStyle(.red)
                    .padding(.horizontal, 12).padding(.top, 6)
            }
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    // Consentimentos só quando GDPR ativo (manual p.30). Senão, só "Start test".
                    if store.gdprPrivacidadeAtiva {
                        check("I agree to the Terms of Use, Privacy Policy, and Sensitive Information.", $aceitoTudo) {
                            aceitoTermos = aceitoTudo; aceitoPriv = aceitoTudo; aceitoSens = aceitoTudo
                        }
                        check("Accept terms and conditions", $aceitoTermos)
                        check("Accept Privacy Policy", $aceitoPriv)
                        check("Sensitive information offer agreement", $aceitoSens)
                    }
                    check("Start the InBody Test immediately after registration.", $testarAposCadastro)
                }
                Spacer()
                botao("Register", largura: 90) { registrar() }
            }
            .padding(12)
            .background(Color.gray.opacity(0.1))
        }
    }

    // MARK: - Ações

    private func registrar() {
        guard !nome.trimmingCharacters(in: .whitespaces).isEmpty else { erro = "Enter the member's name."; return }
        guard let alturaNum = Double(altura), alturaNum > 0 else { erro = "Enter a valid height."; return }
        guard !sexo.isEmpty else { erro = "Select a gender."; return }
        guard let idadeD = idadeCalculada else { erro = "Enter a valid date of birth."; return }

        let idFinal: String
        if autoID {
            idFinal = gerarID()
        } else {
            let candidato = id.trimmingCharacters(in: .whitespaces)
            guard idValido(candidato) else {
                erro = "ID: lowercase letters, numbers, - and _ only (1-14 characters)."; return
            }
            guard !store.pacientes.contains(where: { $0.id == candidato }) else {
                erro = "This ID already exists."; return
            }
            idFinal = candidato
        }
        if store.gdprPrivacidadeAtiva && !(aceitoTudo || (aceitoTermos && aceitoPriv && aceitoSens)) {
            erro = "Accept the agreements to register."; return
        }

        var novo = Paciente(id: idFinal, nome: nome, sexo: sexo,
                            idade: Int(idadeD), altura: alturaNum, exames: [])
        novo.celular = celular
        novo.historico = historico == "None" ? "" : historico
        novo.grupo = grupo
        novo.email = email
        novo.nascimento = "\(ano)/\(mes)/\(dia)"
        novo.registro = hoje()

        store.cadastrar(novo)   // grava no banco + memoria (persistente)
        erro = ""
        aoConcluir(testarAposCadastro)
    }

    private func idValido(_ s: String) -> Bool {
        guard (1...14).contains(s.count) else { return false }
        let permitido = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-_")
        return s.unicodeScalars.allSatisfy { permitido.contains($0) }
    }

    private func gerarID() -> String {
        let f = DateFormatter(); f.dateFormat = "yyMMdd"
        let base = f.string(from: Date())
        var n = 1
        while store.pacientes.contains(where: { $0.id == "\(base)-\(n)" }) { n += 1 }
        return "\(base)-\(n)"
    }

    private func hoje() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy/MM/dd"; return f.string(from: Date())
    }

    /// Print Form: imprime um formulário em branco para o membro preencher (manual p.29).
    private func imprimirFormulario() {
        let texto = """
        LookinBody120 — Member Registration Form

        Name: ______________________________
        ID:   ______________________________
        Height: __________ cm    Gender: ( ) Male  ( ) Female
        Date of Birth: ______ / ____ / ____
        Mobile No.: ________________________
        E-mail: ____________________________
        """
        let view = NSTextView(frame: NSRect(x: 0, y: 0, width: 540, height: 720))
        view.string = texto
        view.font = NSFont.systemFont(ofSize: 13)
        let op = NSPrintOperation(view: view)
        op.showsPrintPanel = true
        op.run()
    }

    // helpers de UI
    private func linha<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        HStack(spacing: 6) { c() }.padding(.vertical, 2)
    }
    private func radio(_ t: String, _ on: Bool, _ acao: @escaping () -> Void) -> some View {
        Button(action: acao) {
            HStack(spacing: 4) {
                Image(systemName: on ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 11)).foregroundStyle(on ? Color.accentColor : .secondary)
                Text(T(t)).font(.system(size: 11)).foregroundStyle(.black)
            }
        }.buttonStyle(.plain)
    }
    private func check(_ t: String, _ on: Binding<Bool>, _ acao: (() -> Void)? = nil) -> some View {
        Button { on.wrappedValue.toggle(); acao?() } label: {
            HStack(spacing: 5) {
                Image(systemName: on.wrappedValue ? "checkmark.square.fill" : "square")
                    .font(.system(size: 11)).foregroundStyle(on.wrappedValue ? Color.accentColor : .secondary)
                Text(T(t)).font(.system(size: 10)).foregroundStyle(.black)
            }
        }.buttonStyle(.plain)
    }
    private func botao(_ t: String, largura: CGFloat, _ acao: @escaping () -> Void = {}) -> some View {
        Button(action: acao) {
            Text(T(t)).font(.system(size: 11)).frame(width: largura, height: 24)
                .background(RoundedRectangle(cornerRadius: 3).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.gray.opacity(0.4)))
        }.buttonStyle(.plain)
    }
}
