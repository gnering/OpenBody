import SwiftUI
import InBodyKit

// Converte o quadro vR num exame pela FONTE UNICA de traducao coluna->Medida
// (ImportService.montarMedida — contrato 8). O mapeador manual anterior foi APAGADO:
// divergia do montarMedida (BFM_MIN/MAX errado, ipbf medio, etype2 vazio) e usava o
// FieldMap incompleto (267) — agora o FieldMap tem 645 posicoes do recurso original.
extension Medida {
    /// (Medida, dicionarios crus por tabela) a partir do quadro vR. O cru serve p/ gravar
    /// no banco nas 6 tabelas irmas (E2.T3).
    static func deVR(_ campos: [String]) -> (medida: Medida, cru: [String: [String: String]]) {
        var tabelas: [String: [String: String]] = [:]
        for (i, f) in InBodyFieldMap.map where i < campos.count {
            guard let ponto = f.column.firstIndex(of: ".") else { continue }
            let tbl = String(f.column[..<ponto])
            let col = String(f.column[f.column.index(after: ponto)...])
            tabelas[tbl, default: [:]][col] = campos[i]
        }
        // DATETIMES de 14 digitos do quadro (campos[6]=data, [7]=hora) — contrato 2.
        let dt = InBodyVR.datetimes14(data: campos.count > 6 ? campos[6] : "",
                                      hora: campos.count > 7 ? campos[7] : "")
        for t in ["BCA_TBL", "ED_TBL", "LB_TBL", "IMP_TBL", "MFA_TBL", "WC_TBL"] {
            tabelas[t, default: [:]]["DATETIMES"] = dt
        }
        let alt = Double((tabelas["WC_TBL"]?["HT"] ?? "").replacingOccurrences(of: ",", with: ".")) ?? 0
        // A balança manda o quadro CRU: os valores CALCULADOS vêm zerados. O LookinBody os
        // calcula. SMI (Índice de Massa Muscular Esquelética) = massa magra dos 4 membros /
        // altura². Injeta quando o quadro trouxe BSMI=0 (só no caminho ao vivo; o corpus .mdb
        // já traz BSMI, então montarMedida fica intocado).
        func lb(_ c: String) -> Double {
            Double((tabelas["LB_TBL"]?[c] ?? "").replacingOccurrences(of: ",", with: ".")) ?? 0
        }
        // ETYPE2 (avaliação: nutricional, obesidade e BALANCEAMENTO) não vem num campo só:
        // a balança manda 18 dígitos, UM POR CAMPO, nas posições 184..201. O banco guarda os
        // 18 + "00" no fim (conferido: todo ETYPE2 do corpus termina em "00"). Sem juntar,
        // ficava só o primeiro dígito e as caixas de balanceamento saíam vazias.
        let faixaEtype2 = 184...201
        if campos.count > faixaEtype2.upperBound {
            let digitos = faixaEtype2.map { campos[$0].trimmingCharacters(in: .whitespaces) }
            if digitos.allSatisfy({ $0.count == 1 && $0.allSatisfy(\.isNumber) }) {
                tabelas["WC_TBL", default: [:]]["ETYPE2"] = digitos.joined() + "00"
            }
        }
        let bsmiAtual = Double((tabelas["BCA_TBL"]?["BSMI"] ?? "").replacingOccurrences(of: ",", with: ".")) ?? 0
        if bsmiAtual == 0, alt > 0 {
            let asm = lb("LRA") + lb("LLA") + lb("LRL") + lb("LLL")   // massa magra apendicular
            let altM = alt / 100
            let smi = asm / (altM * altM)
            if smi > 0 { tabelas["BCA_TBL", default: [:]]["BSMI"] = String(format: "%.2f", smi) }
        }
        let medida = ImportService.montarMedida(
            tabelas["BCA_TBL"] ?? [:], tabelas["MFA_TBL"] ?? [:], tabelas["WC_TBL"] ?? [:],
            tabelas["LB_TBL"] ?? [:], tabelas["ED_TBL"] ?? [:], tabelas["IMP_TBL"] ?? [:],
            alturaCadastro: alt)
        return (medida, tabelas)
    }
}

/// Utilitarios do quadro vR (formato de data etc.).
enum InBodyVR {
    /// Data+hora do quadro -> "yyyyMMddHHmmss" (14 digitos), tirando '/'/':'/espaco
    /// (FrmConInBody.cs:3288: array6[6]+array6[7] sem separadores). Contrato 2.
    static func datetimes14(data: String, hora: String) -> String {
        let junto = (data + hora).filter { $0.isNumber }
        return String(junto.prefix(14))
    }

    /// Soma 1 segundo a um DATETIMES de 14 digitos (dedup do original, FrmConInBody:3341).
    static func mais1s(_ dt14: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyyMMddHHmmss"
        guard dt14.count == 14, let d = f.date(from: dt14) else { return dt14 }
        return f.string(from: d.addingTimeInterval(1))
    }
}

/// Tela de teste InBody ao vivo (manual p.46-47): painel Select Test vermelho,
/// status de conexão à direita, dados recentes, e popup de conclusão.
struct InBodyTestView: View {
    @EnvironmentObject var store: Store
    let paciente: Paciente
    var aoFechar: () -> Void

    // ANIM_PREVIEW=1: entra direto no estado "medindo" para ver a animação sem balança.
    private static let previewAnim = ProcessInfo.processInfo.environment["ANIM_PREVIEW"] == "1"
    @State private var status = "Connecting to the InBody…"
    @State private var conectado = InBodyTestView.previewAnim
    @State private var concluido = false
    @State private var salvarNoPC = true
    @State private var novaMedida: Medida?
    @State private var novoCru: [String: [String: String]] = [:]   // dicts cros p/ gravar no banco
    @State private var novoRaw = ""                                 // quadro cru (arquival)

    private let vermelho = Color(red: 0.62, green: 0.16, blue: 0.16)

    var body: some View {
        VStack(spacing: 0) {
            // barra título
            HStack {
                Text("\(T("InBody Test")) — \(paciente.nome)").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                Spacer()
                Button { aoFechar() } label: { Image(systemName: "xmark").foregroundStyle(.white) }.buttonStyle(.plain)
            }.padding(.horizontal, 12).padding(.vertical, 8).background(vermelho)

            HStack(alignment: .top, spacing: 0) {
                // painel Select Test vermelho (em teste)
                VStack {
                    VStack(spacing: 8) {
                        Image(systemName: "figure.stand").font(.system(size: 30)).foregroundStyle(.white)
                        Text(T("InBody\nTest")).multilineTextAlignment(.center)
                            .font(.system(size: 13, weight: .medium)).foregroundStyle(.white)
                    }
                    .frame(width: 130, height: 110)
                    .background(RoundedRectangle(cornerRadius: 8).fill(vermelho))
                    .padding(.top, 20)
                    Spacer()
                }
                .frame(width: 200)
                .background(vermelho.opacity(0.12))

                Divider()

                // painel de status (User's Guide)
                VStack(alignment: .leading, spacing: 12) {
                    Text(T("User's Guide")).font(.system(size: 12, weight: .semibold))
                    Divider()
                    if conectado && !concluido {
                        // MEDINDO: animação do boneco escaneado (igual ao LookinBody).
                        VStack(spacing: 10) {
                            ExameAnimacao(ativo: true)
                                .frame(maxWidth: 210, maxHeight: 300)
                                .frame(maxWidth: .infinity)
                            Text(T("Measuring…")).font(.system(size: 14, weight: .bold)).foregroundStyle(vermelho)
                            Text(T("Step barefoot on the InBody and stay still.")).font(.system(size: 11))
                                .foregroundStyle(.secondary).multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Text(T(status))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(conectado ? Color.okc : .red)
                        Text(conectado ? T("* Click 'Troubleshooting' on bottom for help.")
                                       : T("Failed to connect. The InBody Test cannot begin.\n* Click 'Troubleshooting' on bottom for help."))
                            .font(.system(size: 11)).foregroundStyle(.secondary)

                        // dados recentes
                        if let e = paciente.ultimo {
                            Spacer().frame(height: 10)
                            VStack(alignment: .leading, spacing: 3) {
                                Image(systemName: "figure.stand").font(.system(size: 44))
                                    .frame(maxWidth: .infinity).foregroundStyle(.gray.opacity(0.4))
                                Text(T("Recent")).font(.system(size: 10, weight: .bold))
                                Text("\(T("Test Date / Time"))\n\(dataBR(e.data))").font(.system(size: 9)).foregroundStyle(.secondary)
                                Text("Weight  \(String(format: "%.1f", e.peso)) kg").font(.system(size: 10))
                                Text("SMM  \(String(format: "%.1f", e.smm)) kg").font(.system(size: 10))
                                Text("BFM  \(String(format: "%.1f", e.gordura)) kg").font(.system(size: 10))
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 4).stroke(vermelho.opacity(0.5)))
                        }
                    }
                    Spacer()
                }
                .padding(14)
                .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity)
            .background(Color(red: 0.95, green: 0.95, blue: 0.96))
        }
        .frame(width: 560, height: 520)
        .background(Color.white)
        .foregroundStyle(.black)
        .overlay { if concluido { popupConcluido } }
        .onAppear { iniciar() }
    }

    private var popupConcluido: some View {
        ZStack {
            Color.black.opacity(0.3)
            VStack(spacing: 0) {
                HStack {
                    Text(T("InBody Test Completed")).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                    Spacer()
                }.padding(10).background(vermelho)
                VStack(alignment: .leading, spacing: 10) {
                    Text(T("InBody Test completed.")).font(.system(size: 13, weight: .bold))
                    Text(T("* Click [InBody] under Health Report to view detailed results.")).font(.system(size: 11))
                    Text(T("* Click [Print] on top to print Results Sheet(s).")).font(.system(size: 11))
                    Toggle(isOn: $salvarNoPC) { Text(T("Save InBody result into My PC")).font(.system(size: 11)) }
                    Button { salvarEConfirmar() } label: {
                        Text(T("Confirm")).frame(width: 90, height: 26)
                            .background(RoundedRectangle(cornerRadius: 3).stroke(Color.gray.opacity(0.5)))
                    }.buttonStyle(.plain).frame(maxWidth: .infinity)
                }.padding(16).background(Color.white)
            }
            .frame(width: 380)
            .overlay(Rectangle().stroke(vermelho, lineWidth: 1))
        }
    }

    private func iniciar() {
        if Self.previewAnim { return }   // preview: só mostra a animação, não conecta
        let perfil = LiveTest.perfil(id: paciente.id, sexo: paciente.sexo,
                                     altura: String(Int(paciente.altura)), idade: String(paciente.idade))
        let host = store.host, port = store.porta
        let dev = store.portaSerial            // dongle Bluetooth / USB / cabo, se foi por serial
        let baud = speed_t(store.baudSerial)   // velocidade que conectou (115200/19200/9600)
        Task.detached {
            LiveTest.executar(host: host, port: port, serialDevice: dev, baud: baud, perfil: perfil) { estado in
                Task { @MainActor in
                    switch estado {
                    case .conectando: status = "Connecting to the InBody…"
                    case .conectado(let m): conectado = true; status = "\(m) : \(T("Connected"))"
                    case .perfilEnviado: status = "Profile sent"
                    case .aguardando: status = "Step barefoot on the InBody to begin."
                    case .concluido(let campos):
                        let r = Medida.deVR(campos); novaMedida = r.medida; novoCru = r.cru
                        novoRaw = campos.joined(separator: "\u{1B}"); concluido = true
                        // Impressão automática ao concluir (igual ao Windows): as folhas,
                        // cópias e o liga/desliga vêm do Setup (A-03), agora de verdade.
                        let cfg = SetupConfig.carregar()
                        if cfg.imprimirAutomaticamente, !cfg.folhasParaImprimir.isEmpty {
                            imprimirFolhas(folhasDoExame(paciente, r.medida, tipos: cfg.folhasParaImprimir),
                                           dialogo: false, copias: cfg.copias)
                        }
                    case .falha(let msg): conectado = false; status = msg
                    }
                }
            }
        }
    }

    private func salvarEConfirmar() {
        if salvarNoPC, let m = novaMedida {
            // grava nas 6 tabelas + memoria; arquiva o quadro cru (TempMeasureData)
            store.anexarExame(m, cru: novoCru, raw: novoRaw, a: paciente.id)
        }
        aoFechar()
    }
}

/// Blood Pressure Test (manual p.52-54). Guia "Press [Start]…" e popup de conclusão.
/// Sem hardware disponível, a leitura é simulada ao apertar Start.
struct BloodPressureTestView: View {
    @EnvironmentObject var store: Store
    let paciente: Paciente
    var aoFechar: () -> Void

    @State private var status = "Press [Start] on the blood pressure monitor to begin test."
    @State private var concluido = false
    @State private var salvarNoPC = true
    @State private var sistolica = 0
    @State private var diastolica = 0

    private let vermelho = Color(red: 0.62, green: 0.16, blue: 0.16)

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(T("Blood Pressure Test")) — \(paciente.nome)")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                Spacer()
                Button { aoFechar() } label: { Image(systemName: "xmark").foregroundStyle(.white) }.buttonStyle(.plain)
            }.padding(.horizontal, 12).padding(.vertical, 8).background(vermelho)

            HStack(alignment: .top, spacing: 0) {
                VStack {
                    VStack(spacing: 6) {
                        Image(systemName: "heart.fill").font(.system(size: 26)).foregroundStyle(.white)
                        Text(T("Blood Pressure\nTest")).multilineTextAlignment(.center)
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(.white)
                    }
                    .frame(width: 130, height: 100)
                    .background(RoundedRectangle(cornerRadius: 8).fill(vermelho))
                    .padding(.top, 20)
                    Spacer()
                }
                .frame(width: 200).background(vermelho.opacity(0.12))

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text(T("User's Guide")).font(.system(size: 12, weight: .semibold))
                    Divider()
                    Text(T(status)).font(.system(size: 13, weight: .semibold))
                    Text(T("Only the highlighted member's blood pressure test will begin.\n* Click another member to highlight."))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    Button { simular() } label: {
                        Text(T("Start")).font(.system(size: 12)).frame(width: 90, height: 28)
                            .background(RoundedRectangle(cornerRadius: 4).fill(vermelho)).foregroundStyle(.white)
                    }.buttonStyle(.plain).padding(.top, 6)
                    Spacer()
                }
                .padding(14).frame(maxWidth: .infinity)
            }
            .frame(maxHeight: .infinity)
            .background(Color(red: 0.95, green: 0.95, blue: 0.96))
        }
        .frame(width: 560, height: 480).background(Color.white).foregroundStyle(.black)
        .overlay { if concluido { popupConcluido } }
    }

    private var popupConcluido: some View {
        ZStack {
            Color.black.opacity(0.3)
            VStack(spacing: 0) {
                HStack {
                    Text(T("Blood Pressure Test Completed")).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                    Spacer()
                }.padding(10).background(vermelho)
                VStack(alignment: .leading, spacing: 10) {
                    Text(T("Blood pressure test completed.")).font(.system(size: 13, weight: .bold))
                    Text("\(T("Result:")) \(sistolica)/\(diastolica) mmHg").font(.system(size: 12))
                    Text(T("* Click [Blood Pressure] under Health Report to view detailed results.")).font(.system(size: 11))
                    Text(T("* Click [Print] on top to print Results Sheet(s).")).font(.system(size: 11))
                    Toggle(isOn: $salvarNoPC) { Text(T("Save Blood pressure result into My PC")).font(.system(size: 11)) }
                    Button { salvarEConfirmar() } label: {
                        Text(T("Confirm")).frame(width: 90, height: 26)
                            .background(RoundedRectangle(cornerRadius: 3).stroke(Color.gray.opacity(0.5)))
                    }.buttonStyle(.plain).frame(maxWidth: .infinity)
                }.padding(16).background(Color.white)
            }
            .frame(width: 400)
            .overlay(Rectangle().stroke(vermelho, lineWidth: 1))
        }
    }

    private func simular() {
        // leitura simulada (sem hardware): valores plausíveis
        sistolica = Int.random(in: 108...148)
        diastolica = Int.random(in: 68...94)
        status = "Measurement complete."
        concluido = true
    }

    private func salvarEConfirmar() {
        if salvarNoPC, let idx = store.pacientes.firstIndex(where: { $0.id == paciente.id }) {
            let f = DateFormatter(); f.dateFormat = "yyyy/MM/dd HH:mm"
            store.pacientes[idx].pressoes.append(
                LeituraPressao(data: f.string(from: Date()), sistolica: sistolica, diastolica: diastolica))
        }
        aoFechar()
    }
}
