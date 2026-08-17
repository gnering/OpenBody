import SwiftUI
import InBodyKit

/// Tela de conexão com a balança, com cada meio SEPARADO (como o LookinBody original):
/// Rede (WiFi/LAN), Bluetooth, USB e Cabo serial — cada um com seus campos e seu botão Conectar.
struct ConexaoView: View {
    @EnvironmentObject var store: Store
    var aoFechar: () -> Void

    @State private var portaSel = ""              // porta serial escolhida (dongle/cabo)
    @State private var portas: [String] = []

    private let marromTitulo = Color(red: 0.40, green: 0.13, blue: 0.13)

    private var estadoCor: Color {
        if store.ocupado { return .orange }
        return store.conectado ? Color(red: 0.16, green: 0.65, blue: 0.30) : .gray
    }
    private var estadoTexto: String {
        if store.ocupado { return T("Searching for the scale…") }
        return store.conectado ? T("Connected") : T("Disconnected")
    }
    private var meioLegivel: String {
        switch store.meioConexao {
        case "network": return "WiFi/LAN"; case "Bluetooth": return "Bluetooth"
        case "USB": return "USB"; case "cable": return T("cable"); default: return store.meioConexao
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(T("Scale connection")).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                Spacer()
                Button { aoFechar() } label: { Image(systemName: "xmark").foregroundStyle(.white) }.buttonStyle(.plain)
            }.padding(.horizontal, 16).padding(.vertical, 10).background(marromTitulo)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    cartaoStatus

                    // ---- Rede (WiFi / LAN) ----
                    cartao(titulo: T("Network — WiFi / LAN"), icone: "wifi") {
                        HStack(spacing: 10) {
                            campoTexto("IP", texto: Binding(get: { store.host }, set: { store.host = $0 }), largura: 190)
                            campoPorta
                            Spacer()
                            botaoConectar { store.conectarRede() }
                        }
                    }

                    // ---- Serial: porta compartilhada + um cartão por tipo ----
                    HStack {
                        Text(T("Serial port (dongle/cable)")).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                        Spacer()
                        Button { recarregarPortas() } label: {
                            HStack(spacing: 3) { Image(systemName: "arrow.clockwise"); Text(T("Refresh")) }
                                .font(.system(size: 11)).foregroundStyle(.blue)
                        }.buttonStyle(.plain)
                    }.padding(.top, 2)
                    if portas.isEmpty {
                        Text(T("No serial port. Plug in the dongle/cable and click Refresh."))
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    } else {
                        Picker("", selection: $portaSel) { ForEach(portas, id: \.self) { Text($0).tag($0) } }
                            .labelsHidden().frame(maxWidth: .infinity, alignment: .leading)
                    }

                    cartaoSerial("Bluetooth", icone: "dot.radiowaves.left.and.right", baud: 115200)
                    cartaoSerial("USB", icone: "cable.connector", baud: 19200)
                    cartaoSerial(T("Serial cable (RS-232)"), icone: "cable.connector.horizontal", baud: 9600)

                    Button { store.conectar() } label: {
                        Text(T("Search automatically (tries all methods)"))
                            .font(.system(size: 12)).foregroundStyle(.blue)
                    }.buttonStyle(.plain).disabled(store.ocupado).padding(.top, 2)
                }
                .padding(20)
            }
        }
        .frame(width: 540, height: 760)
        .background(Color.white).foregroundStyle(.black)
        .environment(\.colorScheme, .light)
        .onAppear(perform: recarregarPortas)
    }

    // MARK: - Blocos

    private var cartaoStatus: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(estadoCor.opacity(0.18)).frame(width: 52, height: 52)
                if store.ocupado { ProgressView().controlSize(.large) }
                else {
                    Image(systemName: store.conectado ? "checkmark.circle.fill" : "antenna.radiowaves.left.and.right.slash")
                        .font(.system(size: 24)).foregroundStyle(estadoCor)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(estadoTexto).font(.system(size: 17, weight: .semibold)).foregroundStyle(estadoCor)
                if store.conectado, let m = store.modeloBalanca {
                    Text("\(m) · \(T("via")) \(meioLegivel)").font(.system(size: 13)).foregroundStyle(.secondary)
                    if let porta = store.portaSerial, store.meioConexao != "network" {
                        Text(porta).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                } else if !store.ocupado {
                    Text(T("No scale connected.")).font(.system(size: 13)).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10).fill(estadoCor.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(estadoCor.opacity(0.25)))
    }

    /// Cartão genérico com título+ícone e conteúdo.
    private func cartao<Conteudo: View>(titulo: String, icone: String, @ViewBuilder _ conteudo: () -> Conteudo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icone).font(.system(size: 13)).foregroundStyle(marromTitulo)
                Text(titulo).font(.system(size: 13, weight: .semibold))
            }
            conteudo()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.18)))
    }

    /// Cartão de um meio serial (Bluetooth/USB/cabo): usa a porta escolhida + sua velocidade.
    private func cartaoSerial(_ titulo: String, icone: String, baud: UInt32) -> some View {
        cartao(titulo: titulo, icone: icone) {
            HStack {
                Text("\(baud) bps").font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                botaoConectar(desativado: portaSel.isEmpty) { store.conectarSerial(dev: portaSel, baud: baud) }
            }
        }
    }

    private func botaoConectar(desativado: Bool = false, _ acao: @escaping () -> Void) -> some View {
        Button(action: acao) {
            Text(store.ocupado ? "…" : T("Connect"))
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 96, height: 32)
                .background(RoundedRectangle(cornerRadius: 6).fill((store.ocupado || desativado) ? Color.gray : marromTitulo))
        }.buttonStyle(.plain).disabled(store.ocupado || desativado)
    }

    private func recarregarPortas() {
        portas = PortTransport.portasSeriais()
        if portaSel.isEmpty || !portas.contains(portaSel) { portaSel = portas.first ?? "" }
    }

    private func campoTexto(_ rotulo: String, texto: Binding<String>, largura: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(rotulo).font(.system(size: 11)).foregroundStyle(.secondary)
            TextField("", text: texto).textFieldStyle(.plain).font(.system(size: 14))
                .padding(.horizontal, 8).frame(width: largura, height: 30)
                .background(RoundedRectangle(cornerRadius: 5).stroke(Color.gray.opacity(0.4)))
        }
    }

    private var campoPorta: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(T("Port")).font(.system(size: 11)).foregroundStyle(.secondary)
            TextField("", value: Binding(get: { Int(store.porta) }, set: { store.porta = UInt16(clamping: $0) }),
                      format: .number.grouping(.never))
                .textFieldStyle(.plain).font(.system(size: 14))
                .padding(.horizontal, 8).frame(width: 80, height: 30)
                .background(RoundedRectangle(cornerRadius: 5).stroke(Color.gray.opacity(0.4)))
        }
    }
}
