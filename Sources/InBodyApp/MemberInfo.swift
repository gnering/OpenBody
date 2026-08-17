import SwiftUI

/// Popup "Member Info." (manual p.42-43): mesmo layout do Register, ID já validado,
/// com botões [Delete Member] e [Save]. Caminho A de exclusão.
struct MemberInfoView: View {
    @EnvironmentObject var store: Store
    let memberID: Paciente.ID
    var aoFechar: () -> Void

    @State private var nome = ""
    @State private var altura = ""
    @State private var sexo = ""
    @State private var idade = ""
    @State private var celular = ""
    @State private var email = ""
    @State private var nascimento = ""
    @State private var confirmarExclusao = false

    private let azulTitulo = Color(red: 0.20, green: 0.29, blue: 0.48)

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(T("Member Info.")).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                Spacer()
                Button { aoFechar() } label: { Image(systemName: "xmark").foregroundStyle(.white) }.buttonStyle(.plain)
            }.padding(.horizontal, 12).padding(.vertical, 8).background(azulTitulo)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(T("Required")).font(.system(size: 13, weight: .bold)).padding(.bottom, 8)
                    linha { rotulo("Name"); caixa($nome, largura: 200) }
                    linha {
                        rotulo("ID")
                        HStack(spacing: 4) {
                            Text(T(memberID)).font(.system(size: 12))
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.okc).font(.system(size: 12))
                        }.frame(width: 150, alignment: .leading)
                    }
                    linha { rotulo("Height"); caixa($altura, largura: 60); Text(T("cm")).font(.system(size: 11)) }
                    linha {
                        rotulo("Gender")
                        radio("Male", sexo == "M") { sexo = "M" }
                        radio("Female", sexo == "F") { sexo = "F" }
                    }
                    linha { rotulo("Date of Birth"); caixa($nascimento, largura: 120) }
                    linha { rotulo("Age"); caixa($idade, largura: 60) }
                    Text(T("Optional")).font(.system(size: 13, weight: .bold)).padding(.top, 14).padding(.bottom, 8)
                    linha { rotulo("Mobile No."); caixa($celular, largura: 200) }
                    linha { rotulo("E-mail"); caixa($email, largura: 260) }
                }.padding(16)
            }

            Divider()
            HStack {
                Button { confirmarExclusao = true } label: {
                    Text(T("Delete Member")).font(.system(size: 11)).foregroundStyle(.red)
                        .frame(width: 110, height: 26)
                        .background(RoundedRectangle(cornerRadius: 3).stroke(Color.red.opacity(0.5)))
                }.buttonStyle(.plain)
                Spacer()
                Button { salvar() } label: {
                    Text(T("Save")).font(.system(size: 11)).frame(width: 90, height: 26)
                        .background(RoundedRectangle(cornerRadius: 3).stroke(Color.gray.opacity(0.5)))
                }.buttonStyle(.plain)
            }.padding(12).background(Color.gray.opacity(0.1))
        }
        .frame(width: 560, height: 520).background(Color.white).foregroundStyle(.black)
        .onAppear(perform: carregar)
        .alert(T("Permanently delete?"), isPresented: $confirmarExclusao) {
            Button(T("No"), role: .cancel) {}
            Button(T("Yes"), role: .destructive) { excluir() }
        } message: {
            Text(T("Deleting a member will permanently erase his/her results. If deleted, results cannot be restored."))
        }
    }

    private func carregar() {
        guard let p = store.pacientes.first(where: { $0.id == memberID }) else { return }
        nome = p.nome; altura = p.altura > 0 ? String(Int(p.altura)) : ""
        sexo = p.sexo; idade = p.idade > 0 ? String(p.idade) : ""
        celular = p.celular; email = p.email; nascimento = p.nascimento
    }

    private func salvar() {
        guard var p = store.pacientes.first(where: { $0.id == memberID }) else { aoFechar(); return }
        if !nome.isEmpty { p.nome = nome }
        p.altura = Double(altura) ?? p.altura
        if !sexo.isEmpty { p.sexo = sexo }
        p.idade = Int(idade) ?? p.idade
        p.celular = celular
        p.email = email
        p.nascimento = nascimento
        store.salvarEdicao(p)   // grava no banco + memoria
        aoFechar()
    }

    private func excluir() {
        store.excluir(memberID)   // apaga do banco (cascata) + memoria
        store.selecionados.remove(memberID)
        aoFechar()
    }

    // helpers de UI
    private func linha<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        HStack(spacing: 6) { c() }.padding(.vertical, 2)
    }
    private func rotulo(_ t: String) -> some View {
        Text(T(t)).font(.system(size: 11)).frame(width: 90, alignment: .leading)
            .padding(.vertical, 7).padding(.leading, 8).background(Color.gray.opacity(0.08))
    }
    private func caixa(_ texto: Binding<String>, largura: CGFloat = 150) -> some View {
        TextField("", text: texto).textFieldStyle(.plain).font(.system(size: 12))
            .padding(.horizontal, 6).frame(width: largura, height: 24)
            .background(RoundedRectangle(cornerRadius: 2).stroke(Color.gray.opacity(0.4)))
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
}
