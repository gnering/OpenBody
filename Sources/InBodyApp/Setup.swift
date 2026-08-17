import SwiftUI

let setupMarrom = Color(red: 0.40, green: 0.13, blue: 0.13)

/// Menu Setup do LookinBody120 (manual p.75). Cada item abre sua tela de detalhe.
struct SetupView: View {
    var aoFechar: () -> Void
    @State private var itemAberto: String?
    @State private var mostrarFusao = false

    /// Item de menu que abre a unificacao de pacientes de clinicas/balancas diferentes.
    static let itemFusao = "09. Merge patients from different clinics"

    static let secoes: [(String, [String])] = [
        ("General Settings", [
            "01. Country/Language/Units/Date Format/Password",
            "02. Printer",
            "03. Results Sheet Types/Paper Types/Printing Options/Automatic Printing Options",
            "04. Results Sheet Custom Logo",
            "05. E-mail Options",
            "06. Edit Member Information",
            "07. N/A",
            "08. Auto-Lock",
            "09. Customer Service Information",
            "10. Program and Computer Information/Update History",
            "11. Advanced Security",
        ]),
        ("InBody Test Settings", [
            "01. InBody Model", "02. Cloud Service", "03. Outputs/Interpretations for Results Sheet",
            "04. Reference Range", "05. Export Data as CSV/Image Files", "06. N/A", "07. N/A",
        ]),
        ("LookinBody Data Management", [
            "01. Export Data as Excel", "02. Import Group Registration Data as Excel",
            "03. Reinstallation Guide", "04. Data Backup", "05. Data Restoration",
            "06. Temporary Data", "07. Import Data from Previous LookinBody", "08. Data Importation",
            SetupView.itemFusao,
        ]),
        ("Data Integration", [
            "01. Order(Member) data integration", "02. InBody data integration",
            "03. InBody Results Sheet integration",
        ]),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(T("Setup")).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                Spacer()
                Button { aoFechar() } label: { Image(systemName: "xmark").font(.system(size: 14)).foregroundStyle(.white) }.buttonStyle(.plain)
            }.padding(.horizontal, 16).padding(.vertical, 11).background(setupMarrom)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Self.secoes, id: \.0) { titulo, itens in
                        Text(T(titulo)).font(.system(size: 15, weight: .bold))
                            .padding(.top, 18).padding(.bottom, 6).padding(.horizontal, 12)
                        ForEach(itens, id: \.self) { item in
                            let na = item.contains("N/A")
                            Text(T(item)).font(.system(size: 14)).foregroundStyle(na ? .secondary : .primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16).padding(.vertical, 12)
                                .background(Color.white)
                                .overlay(Rectangle().fill(Color.gray.opacity(0.15)).frame(height: 1), alignment: .bottom)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if item == Self.itemFusao { mostrarFusao = true }
                                    else if !na { itemAberto = item }
                                }
                        }
                    }
                }.padding(.bottom, 20)
            }.background(Color(red: 0.96, green: 0.96, blue: 0.97))
        }
        .frame(width: 780, height: 820).background(Color.white).foregroundStyle(.black)
        .sheet(item: Binding(get: { itemAberto.map { Ident(id: $0) } }, set: { itemAberto = $0?.id })) { it in
            SettingsDetailView(item: it.id) { itemAberto = nil }
        }
        .sheet(isPresented: $mostrarFusao) { FusaoPacientesView { mostrarFusao = false } }
    }
    private struct Ident: Identifiable { let id: String }
}
