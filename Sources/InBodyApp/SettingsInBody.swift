import SwiftUI
import AppKit

/// B. InBody Test Settings (manual p.110-113).
extension SettingsDetailView {

    // MARK: - B-05 EMR export + B-03 restaurar padrão (ações reais)

    /// Abre um seletor de pasta e devolve o caminho escolhido.
    func escolherPasta(_ aoEscolher: @escaping (String) -> Void) {
        let p = NSOpenPanel()
        p.canChooseDirectories = true; p.canChooseFiles = false
        if p.runModal() == .OK, let url = p.url { aoEscolher(url.path) }
    }

    /// Converte o exame do paciente selecionado para PNG ou CSV na pasta de destino do EMR.
    func converterEmr(imagem: Bool) {
        guard let p = store.pacienteAtual, let ex = p.ultimo ?? p.exames.first else {
            avisoSimples("Selecione um paciente com exame."); return
        }
        let pasta = imagem ? setup.emrImagemDir : setup.emrCsvDir
        let dir: String
        if pasta.isEmpty {
            let sp = NSOpenPanel(); sp.canChooseDirectories = true; sp.canChooseFiles = false
            sp.message = T("Choose the destination folder.")
            guard sp.runModal() == .OK, let u = sp.url else { return }
            dir = u.path
        } else { dir = pasta }
        let alvo = imagem
            ? EmrExport.exportarImagem(paciente: p, medida: ex, tipo: store.tipoFolha, pasta: dir)
            : EmrExport.exportarCSVExame(paciente: p, medida: ex, pasta: dir)
        avisoSimples(alvo != nil ? T("Exported:") + "\n\(alvo!)" : T("Export failed."))
    }

    func avisoSimples(_ t: String) { let a = NSAlert(); a.messageText = t; a.runModal() }

    /// B-03 Restore InBody Default: volta as opções de saída ao padrão de fábrica.
    func restaurarOutputsPadrao() {
        let a = NSAlert()
        a.messageText = T("Restore default?")
        a.informativeText = T("Resets output/print options to factory default. Does not touch patients.")
        a.addButton(withTitle: T("Restore")); a.addButton(withTitle: T("Cancel"))
        guard a.runModal() == .alertFirstButtonReturn else { return }
        setup.restaurarPadraoSaida(); setup.salvar()
    }
    // B-01 InBody Model
    var inbodyModel: some View {
        VStack(alignment: .leading, spacing: 8) {
            rot("Select the InBody model.")
            comboMenu($setup.inbodyModelo, SetupData.inbodyModels, width: 320)
            ajuda("The InBody model can be changed.")
            rot("Connect Stadiometer")
            HStack(spacing: 20) {
                radioSelBool("Yes", $setup.estadiometroConectado, true)
                radioSelBool("No", $setup.estadiometroConectado, false)
            }
            Text(T("Model detected on connection: 770."))
                .font(.system(size: 12)).foregroundStyle(.secondary).padding(.top, 6)
        }
    }

    // B-02 Cloud Service
    var cloudService: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(T("Cloud service lets clients check and manage their results from their own smartphone."))
                .font(.system(size: 13))
            ajuda("1. Set up a Cloud Service.  2. After setup, log in to your LookinBody Web account.")
            rot("Do you want to enable the Cloud Service?")
            HStack(spacing: 20) {
                radioSelBool("Yes", $setup.cloudAtivo, true)
                radioSelBool("No", $setup.cloudAtivo, false)
            }

            EmptyView()

            Text(T("LookinBody Website Account Login")).font(.system(size: 13, weight: .semibold)).padding(.top, 6)
            campo("ID", "", rotLargura: 70)
            campo("Password", "", rotLargura: 70)
            HStack { botaoCinza("Login", largura: 90) { avisoNaoConstruido(T("Cloud login (use the cloud backup above)")) }
                     Text(T("You are not logged in.")).font(.system(size: 12)).foregroundStyle(.secondary) }
            ajuda("If you forgot your password, please contact our Customer Service Center.")
            campo("Cloud URL", "https://cloud.lookinbody.com", rotLargura: 70, largura: 260)
        }
    }

    /// Backup na nuvem: você VINCULA a pasta (iCloud Drive, Google Drive, OneDrive…) por um
    /// botão; depois é só "Backup agora". A nuvem sincroniza a pasta sozinha.
    @ViewBuilder var blocoBackupNuvem: some View {
        Text(T("Cloud backup")).font(.system(size: 13, weight: .semibold)).padding(.top, 8)
        ajuda(T("Link your cloud folder (iCloud Drive, Google Drive, or OneDrive). The app writes the copy there and the cloud syncs it on its own."))
        HStack(spacing: 8) {
            Text(cloudPastaVinculada.isEmpty ? T("(no folder linked)") : cloudPastaVinculada)
                .font(.system(size: 12)).foregroundStyle(cloudPastaVinculada.isEmpty ? .secondary : .primary)
                .lineLimit(1).truncationMode(.middle)
                .frame(maxWidth: 260, alignment: .leading)
            botaoCinza(cloudPastaVinculada.isEmpty ? T("Connect") : T("Change folder"), largura: 110) { conectarNuvem() }
        }
        HStack(spacing: 8) {
            botaoCinza(T("Back up now"), largura: 110) { backupNuvem() }.disabled(cloudPastaVinculada.isEmpty)
            Toggle(isOn: Binding(get: { cloudAuto }, set: { cloudAuto = $0; CloudBackup.autoAtivo = $0 })) {
                Text(T("Automatic backup on app launch")).font(.system(size: 12))
            }.toggleStyle(.checkbox).disabled(cloudPastaVinculada.isEmpty)
        }
        if !cloudAviso.isEmpty {
            Text(cloudAviso).font(.system(size: 12)).foregroundStyle(cloudAviso.hasPrefix(T("Cloud backup saved:")) ? Color.okc : .red)
        }
    }

    /// Abre o seletor para você navegar até a pasta da nuvem e vinculá-la.
    func conectarNuvem() {
        let p = NSOpenPanel()
        p.canChooseDirectories = true; p.canChooseFiles = false
        p.message = T("Choose your cloud folder (iCloud Drive, Google Drive, or OneDrive).")
        p.prompt = T("Link")
        guard p.runModal() == .OK, let url = p.url else { return }
        CloudBackup.pastaVinculada = url.path
        cloudPastaVinculada = url.path
        cloudAviso = T("Folder linked. Click Back up now whenever you want.")
    }

    func backupNuvem() {
        let r = CloudBackup.backupVinculado()
        if let c = r.caminho { cloudAviso = T("Cloud backup saved:") + "\n\(c)" }
        else { cloudAviso = r.erro ?? T("Backup failed.") }
    }

    // B-03 Outputs/Interpretations for Results Sheet
    var outputsInterpretations: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(T("Select outputs/interpretations to print on the right side of the InBody Results Sheet, or shown as Body Composition History graphs on the Health Report."))
                .font(.system(size: 13))
            ajuda("Output = a result of the InBody Test. Interpretation = an explanation of the output. Bracketed values [n] show required space.")
            HStack {
                Text(T("Free Space")).font(.system(size: 13, weight: .semibold))
                Text(T("8")).font(.system(size: 13, weight: .bold)).foregroundStyle(Color.accentColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(SetupData.outputItems.enumerated()), id: \.offset) { idx, it in
                    HStack(spacing: 6) {
                        chk("", idx < 6)
                        Text(T(it.0)).font(.system(size: 12))
                        Text("[\(it.1)]").font(.system(size: 12)).foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "arrow.up").font(.system(size: 11)).foregroundStyle(.secondary)
                        Image(systemName: "arrow.down").font(.system(size: 11)).foregroundStyle(.secondary)
                    }.overlay(Rectangle().fill(Color.gray.opacity(0.08)).frame(height: 1), alignment: .bottom)
                }
            }
            ajuda("* You can change the order by clicking the arrow. You can select only 4 outputs on the Evaluation Result Sheet.")
            HStack(spacing: 16) {
                radioSelBool("With Values", $setup.comValores, true)
                radioSelBool("Without Values", $setup.comValores, false)
            }
            HStack { botaoCinza("Preview", largura: 90) { previaFolha(.adulto) }
                     botaoCinza("Restore InBody Default", largura: 170) { restaurarOutputsPadrao() } }

            Text(T("Your personal information is printed on the upper part of the result sheet. Print name and date of birth as well?"))
                .font(.system(size: 13)).padding(.top, 6)
            HStack { Text(T("Name")).font(.system(size: 12)).frame(width: 90, alignment: .leading); radio("No", true); radio("Yes", false) }
            HStack { Text(T("Date of Birth")).font(.system(size: 12)).frame(width: 90, alignment: .leading); radio("No", true); radio("Yes", false) }
        }
    }

    // B-04 Reference Range (popup real: "Normal Range")
    var referenceRange: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(T("Set normal ranges below. The graph will be drawn accordingly.")).font(.system(size: 13, weight: .semibold))
            HStack(spacing: 0) {
                faixaBloco("Under", Color.gray.opacity(0.15))
                faixaBloco("Normal", Color.accentColor.opacity(0.25))
                faixaBloco("Over", Color.gray.opacity(0.15))
            }.overlay(alignment: .center) {
                Text(T("▲ Ideal Value")).font(.system(size: 11)).foregroundStyle(.secondary).offset(y: 14)
            }

            Text(T("• BMI (kg/㎡)")).font(.system(size: 13, weight: .semibold)).padding(.top, 6)
            Text(T("Normal Range")).font(.system(size: 12, weight: .medium))
            HStack { radioSel("Option 1  (18.5 ~ 25.0)", $setup.opcaoIMC, 0); ajuda("* Recommended by WHO.") }
            HStack { radioSel("Option 2  (18.5 ~ 23.0)", $setup.opcaoIMC, 1); ajuda("* Recommended by WHO.") }
            HStack(spacing: 6) {
                radioSel("Option 3   18.5 ~", $setup.opcaoIMC, 2)
                caixaTxt("25.0", largura: 56); ajuda("(Min 23.0 / Max 29.0)")
            }
            ajuda("* Cannot input values less than 23.0.")
            Text(T("Ideal Value")).font(.system(size: 12, weight: .medium))
            radioSel("Option 1   Male 22 / Female 21.5", $setup.opcaoIMCIdeal, 0)
            radioSel("Option 2   Male 22 / Female 21", $setup.opcaoIMCIdeal, 1)
            ajuda("(Ideal BMI value may shift the ideal weight value.)")

            Text(T("• Percent Body Fat (%)")).font(.system(size: 13, weight: .semibold)).padding(.top, 6)
            faixaSexo("Male", "10.0", "20.0", "(Min 5.0 / Max 14.0)", "(Min 16.0 / Max 50.0)")
            faixaSexo("Female", "18.0", "28.0", "(Min 5 / Max 22)", "(Min 24 / Max 50)")
            ajuda("(Ideal values of percent body fat are 15% for male and 23% for female.)")

            Text(T("• Waist-Hip Ratio")).font(.system(size: 13, weight: .semibold)).padding(.top, 6)
            faixaSexo("Male", "0.80", "0.90", "", "")
            faixaSexo("Female", "0.75", "0.85", "(Min 0.50)", "(Max 1.50)")
            ajuda("(Ideal WHR value is the normal range median.)")

            Text(T("• Standard Child Growth Curve")).font(.system(size: 13, weight: .semibold)).padding(.top, 6)
            Text(T("Select the standard child growth curve type.")).font(.system(size: 12))
            HStack(spacing: 16) {
                radioSel("CDC-2000", $setup.curvaCrescimento, 0); radioSel("WHO 2007", $setup.curvaCrescimento, 1)
                radioSel("UK", $setup.curvaCrescimento, 2); radioSel("Switzerland", $setup.curvaCrescimento, 3)
            }
            ajuda("The Korean Pediatric Society 2007/2017 curve is also available depending on country.")
            ajuda("* The normal ranges set will only be applied to adults. For children, a separate set is used and cannot be changed.")
        }
    }

    private func faixaBloco(_ t: String, _ c: Color) -> some View {
        Text(T(t)).font(.system(size: 12)).frame(maxWidth: .infinity).frame(height: 22).background(c)
    }

    private func faixaSexo(_ sexo: String, _ min: String, _ max: String, _ lmin: String, _ lmax: String) -> some View {
        HStack(spacing: 6) {
            Text(T(sexo)).font(.system(size: 12)).frame(width: 60, alignment: .leading)
            caixaTxt(min, largura: 56); Text(T("~")).font(.system(size: 12)); caixaTxt(max, largura: 56)
            ajuda(lmin); ajuda(lmax)
        }
    }

    // B-05 Export Data as CSV/Image Files
    var exportCSVImage: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(T("To export data to EMR you must first specify a destination folder.")).font(.system(size: 13, weight: .semibold))
            ajuda("1. Convert results in LookinBody to image/CSV and save to your destination folder.  2. Results in the folder are available for use in EMR.")
            Text(T("LookinBody  →  Folder  →  EMR")).font(.system(size: 12)).foregroundStyle(.secondary)

            Text(T("Auto Export")).font(.system(size: 13, weight: .semibold)).padding(.top, 4)
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(T("Convert results automatically to an image file after each InBody Test?")).font(.system(size: 12))
                    HStack(spacing: 16) { radio("Yes", false); radio("No", true) }
                    Text(T("Image Destination Folder")).font(.system(size: 12, weight: .medium))
                    HStack { caixaTxt(setup.emrImagemDir.isEmpty ? "(escolher pasta)" : setup.emrImagemDir, largura: 200)
                             botaoCinza("Edit", largura: 56) { escolherPasta { setup.emrImagemDir = $0; setup.salvar() } } }
                    ajuda("* Convert remaining results to image files?")
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(T("Convert results automatically to CSV files after each InBody Test?")).font(.system(size: 12))
                    HStack(spacing: 16) { radio("Yes", false); radio("No", true) }
                    Text(T("CSV Destination Folder")).font(.system(size: 12, weight: .medium))
                    HStack { caixaTxt(setup.emrCsvDir.isEmpty ? "(escolher pasta)" : setup.emrCsvDir, largura: 200)
                             botaoCinza("Edit", largura: 56) { escolherPasta { setup.emrCsvDir = $0; setup.salvar() } } }
                    ajuda("* Convert remaining results to CSV files?")
                }
            }
            Text(T("Order Destination Folder")).font(.system(size: 12, weight: .medium)).padding(.top, 4)
            HStack { caixaTxt(setup.emrOrderDir.isEmpty ? "(escolher pasta)" : setup.emrOrderDir, largura: 200)
                     botaoCinza("Edit", largura: 56) { escolherPasta { setup.emrOrderDir = $0; setup.salvar() } } }

            Text(T("Manual Export")).font(.system(size: 13, weight: .semibold)).padding(.top, 6)
            ajuda("Exporta o exame do paciente selecionado na lista principal.")
            HStack { botaoCinza("Convert to Image File", largura: 160) { converterEmr(imagem: true) }
                     botaoCinza("Convert to CSV File", largura: 160) { converterEmr(imagem: false) } }
        }
    }
}
