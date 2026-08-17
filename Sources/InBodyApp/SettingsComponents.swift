import SwiftUI
import AppKit

/// Componentes reutilizáveis das telas de Setup (barra marrom, combos, radios,
/// checkboxes, caixas de texto, botões cinza) — o visual do LookinBody120.
extension SettingsDetailView {
    // Rótulo de passo (negrito).
    func rot(_ t: String) -> some View {
        Text(T(t)).font(.system(size: 13, weight: .semibold)).padding(.top, 8)
    }

    // Cabeçalho de passo numerado.
    func passo(_ t: String) -> some View {
        Text(T(t)).font(.system(size: 13, weight: .semibold)).padding(.top, 6)
    }

    // Texto de ajuda cinza.
    func ajuda(_ t: String) -> some View {
        Text(T(t)).font(.system(size: 12)).foregroundStyle(.secondary)
    }

    // Combo estático (só exibe um valor; sem lista).
    func combo(_ t: String) -> some View {
        HStack { Text(T(t)).font(.system(size: 13)); Spacer(); Image(systemName: "chevron.down").font(.system(size: 10)) }
            .padding(.horizontal, 10).frame(width: 260, height: 30)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.gray.opacity(0.4)))
    }

    // Combo funcional (dropdown real com lista).
    func comboMenu(_ sel: Binding<String>, _ opts: [String], width: CGFloat = 280) -> some View {
        Menu {
            ForEach(opts, id: \.self) { o in Button(o) { sel.wrappedValue = o } }
        } label: {
            HStack {
                Text(sel.wrappedValue).font(.system(size: 13)).foregroundStyle(.primary).lineLimit(1)
                Spacer(); Image(systemName: "chevron.down").font(.system(size: 10))
            }
            .padding(.horizontal, 10).frame(width: width, height: 30)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.gray.opacity(0.4)))
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width: width)
    }

    // Radio estático.
    func radio(_ t: String, _ on: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: on ? "largecircle.fill.circle" : "circle").font(.system(size: 14))
                .foregroundStyle(on ? Color.accentColor : .secondary)
            Text(T(t)).font(.system(size: 13))
        }
    }

    // Radio funcional (grupo com seleção Int).
    func radioSel(_ t: String, _ sel: Binding<Int>, _ tag: Int) -> some View {
        radio(t, sel.wrappedValue == tag)
            .contentShape(Rectangle())
            .onTapGesture { sel.wrappedValue = tag }
    }

    // Radio funcional para Bool (par Sim/Não, Usar/Não usar).
    func radioSelBool(_ t: String, _ sel: Binding<Bool>, _ tag: Bool) -> some View {
        radio(t, sel.wrappedValue == tag)
            .contentShape(Rectangle())
            .onTapGesture { sel.wrappedValue = tag }
    }

    // Checkbox funcional ligado a um Binding<Bool>.
    func chkBind(_ t: String, _ on: Binding<Bool>) -> some View {
        chk(t, on.wrappedValue)
            .contentShape(Rectangle())
            .onTapGesture { on.wrappedValue.toggle() }
    }

    // Checkbox estático.
    func chk(_ t: String, _ on: Bool = true) -> some View {
        HStack(spacing: 6) {
            Image(systemName: on ? "checkmark.square.fill" : "square").font(.system(size: 14))
                .foregroundStyle(on ? Color.accentColor : .secondary)
            Text(T(t)).font(.system(size: 13))
        }
    }

    // Caixa de texto (exibe valor; vazia mostra placeholder).
    func caixaTxt(_ v: String, largura: CGFloat = 240) -> some View {
        Text(T(v)).font(.system(size: 13)).foregroundStyle(v.isEmpty ? .secondary : .primary)
            .frame(width: largura, height: 26, alignment: .leading).padding(.horizontal, 8)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.gray.opacity(0.4)))
    }

    // Linha rótulo + caixa de texto.
    func campo(_ rotulo: String, _ v: String, rotLargura: CGFloat = 100, largura: CGFloat = 240) -> some View {
        HStack {
            Text(T(rotulo)).font(.system(size: 13)).frame(width: rotLargura, alignment: .leading)
            caixaTxt(v, largura: largura)
        }
    }

    // Botão cinza. REGRA (auditoria 11/08/2026): todo clique responde. Sem `acao`,
    // avisa que a função ainda não foi construída — nunca fica mudo fingindo que fez.
    func botaoCinza(_ t: String, largura: CGFloat = 200, acao: (() -> Void)? = nil) -> some View {
        Button {
            if let acao { acao() } else { avisoNaoConstruido(t) }
        } label: {
            Text(T(t)).font(.system(size: 13)).frame(width: largura, height: 30)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.1)))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.4)))
        }.buttonStyle(.plain)
    }

    // Aviso padrão dos botões ainda não construídos (porte incompleto do LookinBody).
    func avisoNaoConstruido(_ t: String) {
        let a = NSAlert()
        a.messageText = T("Feature not built yet")
        a.informativeText = T("The button") + " \"\(T(t))\" " + T("is not available in OpenBody yet. Nothing was done.")
        a.alertStyle = .informational
        a.runModal()
    }
}
