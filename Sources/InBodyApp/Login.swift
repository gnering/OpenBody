import SwiftUI

/// Tela de login, replicada do LookinBody120 (manual p.21-27).
/// Fundo branco, título cinza claro central, dois campos, barra inferior marrom.
struct LoginView: View {
    @EnvironmentObject var store: Store
    var aoEntrar: () -> Void

    @State private var id = ""
    @State private var senha = ""
    @State private var erro = ""
    @State private var mostrarChangeAccount = false
    @State private var mostrarForgot = false
    @State private var mostrar2FA = false

    private let marrom = Color(red: 0.30, green: 0.16, blue: 0.16)
    private let cinzaTitulo = Color(red: 0.62, green: 0.63, blue: 0.65)

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Text("OpenBody")
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(cinzaTitulo)
                .padding(.bottom, 26)

            VStack(spacing: 8) {
                campo("ID", texto: $id, seguro: false)
                campo("Password", texto: $senha, seguro: true)

                // Instalação inicial: instrução em vermelho (manual p.21-22)
                if store.conta.ehPadrao {
                    Text(T("Initial ID and Password is inbody/0000. If you wish to change your password please go to Setup > Account Management and change your ID and Password"))
                        .font(.system(size: 9)).foregroundStyle(.red.opacity(0.85))
                        .multilineTextAlignment(.center).frame(width: 260)
                }

                if !erro.isEmpty {
                    Text(T(erro)).font(.system(size: 10, weight: .semibold)).foregroundStyle(.red)
                        .frame(width: 260)
                }

                // Two-factor só quando habilitado em Setup > GDPR Options (manual p.25)
                if store.doisFatoresHabilitado {
                    Button(T("Two-factor authentication")) { mostrar2FA = true }.buttonStyle(.plain)
                        .font(.system(size: 11)).foregroundStyle(.red.opacity(0.8))
                        .frame(width: 240).padding(.vertical, 3)
                        .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.gray.opacity(0.3)))
                }

                Button(T("Forgot Password")) { mostrarForgot = true }.buttonStyle(.plain)
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .frame(width: 240, height: 20)
                    .background(RoundedRectangle(cornerRadius: 2).fill(Color.gray.opacity(0.08)))

                Button(action: tentarLogin) {
                    Text(T("Log in")).font(.system(size: 13))
                        .frame(width: 90, height: 26)
                }
                .buttonStyle(.plain)
                .background(RoundedRectangle(cornerRadius: 3).fill(Color.gray.opacity(0.15)))
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.gray.opacity(0.35)))
                .padding(.top, 6)
            }
            Spacer()
            Spacer()

            // barra de status marrom
            HStack {
                Spacer()
                Text("\(T("Last Login:")) \(store.ultimoLogin ?? "-")")
                    .font(.system(size: 10)).foregroundStyle(.white.opacity(0.85))
            }
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(marrom)
        }
        .background(Color.white)
        .foregroundStyle(.black)
        .overlay { if mostrarChangeAccount { changeAccountPopup } }
        .overlay { if mostrarForgot { forgotPopup } }
        .overlay { if mostrar2FA { twoFactorPopup } }
    }

    // MARK: - Ações

    private func tentarLogin() {
        let uid = id.trimmingCharacters(in: .whitespaces)
        guard !uid.isEmpty, !senha.isEmpty else {
            erro = "Enter your ID and Password."
            return
        }
        // Entra direto com a conta configurada (inbody/0000 por padrão). SEM obrigar trocar
        // senha depois (o "Change Account" do original vira opcional, não forçado).
        if store.autenticar(id: uid, senha: senha) {
            erro = ""
            aoEntrar()
        } else {
            erro = "Invalid ID or Password."
        }
    }

    // MARK: - Popups

    private var changeAccountPopup: some View {
        PopupCard(title: "Change Account", cor: Color(red: 0.80, green: 0.35, blue: 0.10)) {
            ChangeAccountForm { novoID, novaSenha, email in
                store.trocarConta(id: novoID, senha: novaSenha, email: email)
                store.registrarLogin()
                mostrarChangeAccount = false
                aoEntrar()
            } aoCancelar: {
                mostrarChangeAccount = false
            }
        }
    }

    private var forgotPopup: some View {
        PopupCard(title: "Forgot Password", cor: Color(red: 0.30, green: 0.16, blue: 0.16)) {
            VStack(alignment: .leading, spacing: 8) {
                Text(T("If password is forgotten, contact Customer Service."))
                    .font(.system(size: 11))
                Text(T("Tel: 1-323-932-6503")).font(.system(size: 11)).foregroundStyle(.secondary)
                linhaInfo("Product Serial Number", "LB120-0000-0000")
                linhaInfo("Recognition Code", "A1B2-C3D4")
                HStack {
                    Text(T("Response Code")).font(.system(size: 10)).frame(width: 120, alignment: .leading)
                    TextField("", text: .constant("")).textFieldStyle(.plain).font(.system(size: 11))
                        .padding(.horizontal, 6).frame(width: 140, height: 22)
                        .background(RoundedRectangle(cornerRadius: 2).stroke(Color.gray.opacity(0.4)))
                }
                HStack { Spacer(); botao("OK") { mostrarForgot = false } }
            }.frame(width: 320)
        }
    }

    private var twoFactorPopup: some View {
        PopupCard(title: "Two-factor authentication", cor: Color(red: 0.30, green: 0.16, blue: 0.16)) {
            TwoFactorForm(email: store.conta.email.isEmpty ? "your@email.com" : store.conta.email) {
                mostrar2FA = false
            }
        }
    }

    private func linhaInfo(_ k: String, _ v: String) -> some View {
        HStack {
            Text(T(k)).font(.system(size: 10)).frame(width: 120, alignment: .leading)
            Text(T(v)).font(.system(size: 11, weight: .medium))
            Spacer()
        }
    }
    private func botao(_ t: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Text(T(t)).font(.system(size: 11)).frame(width: 70, height: 24)
                .background(RoundedRectangle(cornerRadius: 3).stroke(Color.gray.opacity(0.5)))
        }.buttonStyle(.plain)
    }

    private func campo(_ placeholder: String, texto: Binding<String>, seguro: Bool) -> some View {
        Group {
            if seguro { SecureField(placeholder, text: texto) }
            else { TextField(placeholder, text: texto) }
        }
        .textFieldStyle(.plain)
        .font(.system(size: 13))
        .padding(.horizontal, 8).padding(.vertical, 6)
        .frame(width: 240)
        .background(RoundedRectangle(cornerRadius: 2).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.gray.opacity(0.4)))
    }
}

// MARK: - Formulário Change Account (manual p.22)

private struct ChangeAccountForm: View {
    var aoTrocar: (_ id: String, _ senha: String, _ email: String) -> Void
    var aoCancelar: () -> Void

    @State private var novoID = ""
    @State private var novaSenha = ""
    @State private var confirma = ""
    @State private var email = ""
    @State private var erro = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(T("Initial ID and Password is inbody/0000. Please change your ID and Password"))
                .font(.system(size: 11)).foregroundStyle(.secondary).frame(width: 320)
            linha("New ID", $novoID, seguro: false)
            linha("New Password", $novaSenha, seguro: true)
            linha("New Password", $confirma, seguro: true)
            linha("*Optional E-mail", $email, seguro: false)
            Text(T("Password: at least 8 characters incl. upper/lowercase letters and special characters."))
                .font(.system(size: 9)).foregroundStyle(.secondary).frame(width: 320)
            if !erro.isEmpty {
                Text(T(erro)).font(.system(size: 10, weight: .semibold)).foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button(T("Cancel")) { aoCancelar() }.buttonStyle(.plain).font(.system(size: 11))
                    .frame(width: 70, height: 24)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.gray.opacity(0.4)))
                Button(T("Change")) { validar() }.buttonStyle(.plain).font(.system(size: 11))
                    .frame(width: 70, height: 24)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.gray.opacity(0.5)))
            }
        }.frame(width: 320)
    }

    private func validar() {
        let uid = novoID.trimmingCharacters(in: .whitespaces)
        guard !uid.isEmpty else { erro = "Enter a new ID."; return }
        guard novaSenha == confirma else { erro = "Passwords do not match."; return }
        guard Store.senhaValida(novaSenha) else {
            erro = "Password must be 8+ chars with upper/lowercase and a special character."
            return
        }
        aoTrocar(uid, novaSenha, email.trimmingCharacters(in: .whitespaces))
    }

    private func linha(_ t: String, _ b: Binding<String>, seguro: Bool) -> some View {
        HStack {
            Text(T(t)).font(.system(size: 10)).frame(width: 120, alignment: .leading)
            Group {
                if seguro { SecureField("", text: b) } else { TextField("", text: b) }
            }
            .textFieldStyle(.plain).font(.system(size: 11))
            .padding(.horizontal, 6).frame(width: 180, height: 22)
            .background(RoundedRectangle(cornerRadius: 2).stroke(Color.gray.opacity(0.4)))
        }
    }
}

// MARK: - Formulário 2FA (manual p.25-27)

private struct TwoFactorForm: View {
    let email: String
    var aoFechar: () -> Void
    @State private var enviado = false
    @State private var codigo = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(T("A verification number will be sent to the email address below."))
                .font(.system(size: 11)).frame(width: 300)
            HStack {
                Text(T(email)).font(.system(size: 11, weight: .medium))
                Spacer()
                Button(T("Send")) { enviado = true }.buttonStyle(.plain).font(.system(size: 11))
                    .frame(width: 60, height: 22)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.gray.opacity(0.4)))
            }
            if enviado {
                Text(T("Verification number sent.")).font(.system(size: 9)).foregroundStyle(Color.okc)
                HStack {
                    Text(T("Verification Number")).font(.system(size: 10)).frame(width: 130, alignment: .leading)
                    TextField("", text: $codigo).textFieldStyle(.plain).font(.system(size: 11))
                        .padding(.horizontal, 6).frame(width: 120, height: 22)
                        .background(RoundedRectangle(cornerRadius: 2).stroke(Color.gray.opacity(0.4)))
                }
            }
            HStack { Spacer()
                Button("OK") { aoFechar() }.buttonStyle(.plain).font(.system(size: 11))
                    .frame(width: 70, height: 24)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.gray.opacity(0.5)))
            }
        }.frame(width: 300)
    }
}

/// Cartão modal reutilizável com barra de título colorida.
struct PopupCard<Conteudo: View>: View {
    let title: String
    let cor: Color
    @ViewBuilder var conteudo: Conteudo
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
            VStack(spacing: 0) {
                HStack {
                    Text(T(title)).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                    Spacer()
                }.padding(10).background(cor)
                conteudo.padding(16).background(Color.white)
            }
            .fixedSize()
            .overlay(Rectangle().stroke(cor, lineWidth: 1))
        }
    }
}
