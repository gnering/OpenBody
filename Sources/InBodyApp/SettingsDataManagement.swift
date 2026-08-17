import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// C. LookinBody Data Management (manual p.114-121).
/// Auditoria 11/08/2026: Export CSV, Backup, Restauração e Importação LIGADOS de verdade
/// (motor: Banco.exportarCSV / Banco.fazerBackup / Store.importarDe). O resto avisa
/// "não construído" ao clicar (regra do botaoCinza em SettingsComponents.swift).
extension SettingsDetailView {

    // MARK: - Ações reais

    func alertaDados(_ titulo: String, _ texto: String) {
        let a = NSAlert()
        a.messageText = titulo
        a.informativeText = texto
        a.runModal()
    }

    /// Exporta o banco inteiro em CSV (abre no Excel/Numbers).
    func exportarCSVComPainel() {
        let p = NSSavePanel()
        p.nameFieldStringValue = "OpenBody_dados.csv"
        guard p.runModal() == .OK, let url = p.url else { return }
        if Banco.shared.exportarCSV(para: url.path) {
            alertaDados(T("Export complete"), T("CSV spreadsheet (opens in Excel) saved to:") + "\n\(url.path)")
        } else {
            alertaDados(T("Export failed"), T("Could not write") + " \(url.lastPathComponent).")
        }
    }

    /// Cópia completa e consistente do banco (VACUUM INTO) para onde você escolher.
    func backupComPainel() {
        let p = NSSavePanel()
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd_HHmm"
        p.nameFieldStringValue = "OpenBody_backup_\(f.string(from: Date())).sqlite"
        guard p.runModal() == .OK, let url = p.url else { return }
        let snap = Banco.shared.fazerBackup()
        do {
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
            try FileManager.default.copyItem(atPath: snap, toPath: url.path)
            alertaDados(T("Backup complete"), T("Full database copy saved to:") + "\n\(url.path)")
        } catch {
            alertaDados(T("Backup failed"), error.localizedDescription)
        }
    }

    /// Local do backup automático = a pasta de nuvem vinculada (iCloud/Drive/OneDrive).
    /// Mostra a pasta escolhida hoje; "Nenhuma pasta escolhida" se ainda não vinculou.
    var localBackupAuto: String { CloudBackup.pastaVinculada ?? T("No folder chosen") }

    /// "Alterar": escolhe a pasta onde o backup automático será gravado.
    func alterarLocalBackupAuto() {
        let p = NSOpenPanel()
        p.canChooseDirectories = true
        p.canChooseFiles = false
        p.allowsMultipleSelection = false
        p.prompt = T("Use this folder")
        p.message = T("Choose the folder (iCloud Drive, Google Drive, OneDrive, or other) where the automatic backup will be saved.")
        guard p.runModal() == .OK, let url = p.url else { return }
        CloudBackup.pastaVinculada = url.path
        alertaDados(T("Backup location changed"), T("The automatic backup will now be saved to:") + "\n\(url.path)\n\n" + T("Close and reopen this screen to see the new path in the field."))
    }

    /// Restaura/importa de um .mdb do LookinBody ou de um .zip de backup do LookinBody
    /// (os zips da pasta Backup da balança contêm o .MDB). SEMPRE mescla — nunca apaga.
    func restaurarComPainel() {
        let p = NSOpenPanel()
        p.message = T("Choose the balance's LookinBody.mdb file")
        var tipos: [UTType] = [.zip]
        if let mdb = UTType(filenameExtension: "mdb") { tipos.append(mdb) }
        p.allowedContentTypes = tipos
        p.allowsOtherFileTypes = true
        guard p.runModal() == .OK, let url = p.url else { return }
        var mdb = url.path
        if url.pathExtension.lowercased() == "zip" {
            guard let extraido = extrairMDB(deZip: url.path) else {
                alertaDados(T("Invalid backup"), T("No .mdb file found inside") + " \(url.lastPathComponent).")
                return
            }
            mdb = extraido
        }
        // importarDe recarrega a config da pasta do .mdb; se lá não houver settings.xml
        // (zip extraído em pasta temporária), preserva a config atual da clínica.
        let temSettings = FileManager.default.fileExists(
            atPath: (mdb as NSString).deletingLastPathComponent + "/settings.xml")
        let cfgAntes = store.config
        let aviso = store.importarDe(mdb: mdb)
        if !temSettings { store.config = cfgAntes }
        alertaDados(T("Restore complete"), "\(aviso)\n" + T("The data was MERGED with the current data; nothing was deleted."))
    }

    /// Descompacta um zip de backup do LookinBody e devolve o caminho do .mdb interno.
    func extrairMDB(deZip zip: String) -> String? {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("inbody_restore_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        proc.arguments = ["-o", zip, "-d", tmp.path]
        do { try proc.run() } catch { return nil }
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else { return nil }
        let achados = (try? FileManager.default.subpathsOfDirectory(atPath: tmp.path)) ?? []
        guard let rel = achados.first(where: { $0.lowercased().hasSuffix(".mdb") }) else { return nil }
        return tmp.appendingPathComponent(rel).path
    }

    // MARK: - C-02 Excel de grupo (motor: CadastroEmMassa, já provado por --prova-banco massa)

    /// Salva o modelo CSV (Excel abre e salva como CSV) para o médico preencher.
    func salvarModeloGrupo() {
        let p = NSSavePanel()
        p.nameFieldStringValue = "LBGroupRegistration.csv"
        p.allowedContentTypes = [.commaSeparatedText]
        guard p.runModal() == .OK, let url = p.url else { return }
        do {
            try CadastroEmMassa.modelo().write(to: url, atomically: true, encoding: .utf8)
            alertaDados(T("Template saved"), T("Fill it in Excel and import with the button below.") + "\n\(url.path)")
        } catch { alertaDados(T("Could not save"), error.localizedDescription) }
    }

    /// Importa a planilha preenchida (CSV). Mescla; nunca apaga.
    func importarGrupo() {
        let p = NSOpenPanel()
        p.allowedContentTypes = [.commaSeparatedText, .plainText]
        guard p.runModal() == .OK, let url = p.url,
              let texto = try? String(contentsOf: url, encoding: .utf8) else { return }
        let r = CadastroEmMassa.importar(csv: texto, store: store)
        alertaDados(T("Group import"), r.aviso
            + (r.ignorados.isEmpty ? "" : "\n\n" + r.ignorados.prefix(10).joined(separator: "\n")))
    }

    // MARK: - C-03 Data Storage (cópia completa para pasta/pen drive)

    func dataStorageComPainel() {
        let p = NSOpenPanel()
        p.canChooseDirectories = true; p.canChooseFiles = false
        p.message = T("Choose the folder (e.g. USB drive) to save the copy.")
        guard p.runModal() == .OK, let dir = p.url else { return }
        let snap = Banco.shared.fazerBackup()
        let destino = dir.appendingPathComponent("LookinBody120_Backup.sqlite")
        do {
            if FileManager.default.fileExists(atPath: destino.path) { try FileManager.default.removeItem(at: destino) }
            try FileManager.default.copyItem(atPath: snap, toPath: destino.path)
            alertaDados(T("Copy saved"), destino.path)
        } catch { alertaDados(T("Failed"), error.localizedDescription) }
    }

    // MARK: - C-06 Apagar medições temporárias (só as não salvas)

    func apagarTemporarias() {
        let itens = Banco.shared.listarTemp()
        guard !itens.isEmpty else { alertaDados(T("Nothing to delete"), T("There are no temporary measurements.")); return }
        let a = NSAlert()
        a.messageText = T("Delete") + " \(itens.count) " + T("temporary measurement(s)?")
        a.informativeText = T("This removes only temporary (unsaved) ones. Saved exams are not affected.")
        a.addButton(withTitle: T("Delete")); a.addButton(withTitle: T("Cancel"))
        guard a.runModal() == .alertFirstButtonReturn else { return }
        for it in itens { Banco.shared.apagarTemp(datetimes: it.datetimes) }
        alertaDados(T("Done"), "\(itens.count) " + T("temporary one(s) removed."))
    }

    /// Data do backup automático mais recente (pasta backups do Application Support).
    var ultimoBackupTexto: String {
        let dir = (Banco.shared.caminho as NSString).deletingLastPathComponent + "/backups"
        let itens = ((try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? [])
            .filter { $0.hasPrefix("inbody-") && $0.hasSuffix(".sqlite") }.sorted()
        guard let mais = itens.last,
              let attrs = try? FileManager.default.attributesOfItem(atPath: "\(dir)/\(mais)"),
              let d = attrs[.modificationDate] as? Date else { return "Last Backup: -" }
        let f = DateFormatter(); f.dateFormat = "dd.MM.yyyy HH:mm"
        return "Last Backup: \(f.string(from: d))"
    }
    // C-01 Export Data as Excel
    var exportExcel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(T("Export data to edit and save as Excel.")).font(.system(size: 13, weight: .semibold))
            HStack(spacing: 16) { radio("Total", true); radio("Select", false); botaoCinza("Edit", largura: 70) }
            campo("Search by Name or ID", "", rotLargura: 150, largura: 200)
            HStack { Text(T("Search by InBody Test Date")).font(.system(size: 12)); combo("All") }
            VStack(spacing: 0) {
                HStack {
                    Text(T("Select")).font(.system(size: 12)).lineLimit(1).frame(width: 72, alignment: .leading)
                    Text(T("Name")).font(.system(size: 12)).lineLimit(1).frame(width: 120, alignment: .leading)
                    Text(T("ID")).font(.system(size: 12)).lineLimit(1).frame(width: 90, alignment: .leading)
                    Text(T("Test Date/Time")).font(.system(size: 12)).lineLimit(1); Spacer()
                }.padding(.vertical, 3).background(Color.gray.opacity(0.08))
            }.overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.gray.opacity(0.2)))
            Text(T("Click the button below to export data.")).font(.system(size: 12)).padding(.top, 4)
            botaoCinza("Export Data as Excel", largura: 180) { exportarCSVComPainel() }
        }
    }

    // C-02 Import Group Registration Data as Excel
    var importGroupExcel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(T("Register a group of members by importing a batched group from the provided LookinBody Excel file."))
                .font(.system(size: 13))
            passo("1. Input data in the provided LookinBody Excel file.")
            botaoCinza("Save LBGroupRegistration.xls on Desktop", largura: 300) { salvarModeloGrupo() }
            ajuda("2) Open the file.  3) Refer to instructions.  4) Save and close.")
            passo("2. Import the completed file.")
            botaoCinza("Import LBGroupRegistration.xls", largura: 260) { importarGrupo() }
            ajuda("Supported on Excel 2003+. Columns — required: Name, ID, Height, Gender (M/F), Date of Birth, Age. Optional: Mobile No., Telephone No., Zip Code, Address.")
        }
    }

    // C-03 Reinstallation Guide
    var reinstallationGuide: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(T("To reinstall LookinBody, the install files and any saved data must be on a USB Thumb Drive. The provided Hardlock Key must also be plugged into the computer."))
                .font(.system(size: 13))
            ForEach([
                "1. Prepare a USB Thumb Drive (≥500MB).",
                "2. Click [Data Storage] to save data to the LookinBody120_Backup folder on the USB.",
                "3. Copy the LookinBody120_download.url file to the USB.",
                "4. Plug the Hardlock Key into the new computer.",
                "5. Run the downloaded installer.",
                "6. Restore the data from the USB backup folder.",
                "7. Confirm the member data and settings.",
            ], id: \.self) { s in Text(T(s)).font(.system(size: 12)).foregroundStyle(.secondary) }
            botaoCinza("Data Storage", largura: 140) { dataStorageComPainel() }.padding(.top, 4)
        }
    }

    // C-04 Data Backup
    var dataBackup: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(T("Data Backup will save all member information, results, and user settings.")).font(.system(size: 13))
            ajuda("Remember to back up data when planning to re-format, transfer data, or remove/reinstall LookinBody.")
            Text(T("Click the button below to backup data.")).font(.system(size: 12))
            botaoCinza("Data Backup", largura: 160) { backupComPainel() }
            rot("Would you like to back up your data and settings automatically?")
            HStack(spacing: 20) { radioSel("Yes", $autoBackup, 0); radioSel("No", $autoBackup, 1) }
            Text(T("Auto backup location")).font(.system(size: 12, weight: .medium))
            HStack { caixaTxt(localBackupAuto, largura: 240); botaoCinza("Change", largura: 70) { alterarLocalBackupAuto() } }
            HStack {
                Text(T("Auto backup period setting")).font(.system(size: 12, weight: .medium))
                comboMenu($backupPeriod, SetupData.backupPeriods, width: 190)
            }
            Text(T(ultimoBackupTexto)).font(.system(size: 12)).foregroundStyle(.secondary)
            ajuda("* Auto backup will be made after this period since the last backup date. You can only backup data with the server computer.")

            Divider().padding(.vertical, 4)
            blocoBackupNuvem
        }
    }

    // C-05 Data Restoration
    var dataRestoration: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(T("Restore data from a previous LookinBody backup file.")).font(.system(size: 13))
            Text(T("* Restore MERGES the backup data with the current data. Nothing is deleted."))
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
            ajuda(T("1) Click [Data Restoration].  2) Choose the .mdb file or a .zip from the scale backup folder."))
            botaoCinza("Data Restoration", largura: 180) { restaurarComPainel() }
        }
    }

    // C-06 Temporary Data
    var temporaryData: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text(T("Temporarily saved test results are shown below.")).font(.system(size: 13, weight: .semibold)); Spacer(); botaoCinza("Delete", largura: 70) { apagarTemporarias() } }
            ajuda("To save: 1. Input ID, height, date of birth (or age), and gender. 2. Check the data on the left, then click [Save].")
            ajuda("* If the InBody Test was taken without age or gender, results cannot be saved — only member information will be saved.")
            VStack(spacing: 0) {
                HStack(spacing: 4) {
                    Text(T("Select")).font(.system(size: 12)).lineLimit(1).frame(width: 72, alignment: .leading)
                    Text(T("Name")).font(.system(size: 12)).lineLimit(1).frame(width: 90, alignment: .leading)
                    Text(T("ID")).font(.system(size: 12)).lineLimit(1).frame(width: 70, alignment: .leading)
                    Text(T("Height")).font(.system(size: 12)).lineLimit(1).frame(width: 60, alignment: .leading)
                    Text(T("DOB or Age")).font(.system(size: 12)).lineLimit(1).frame(width: 96, alignment: .leading)
                    Text(T("Gender")).font(.system(size: 12)).lineLimit(1).frame(width: 56, alignment: .leading)
                    Text(T("Test Date/Time")).font(.system(size: 12)).lineLimit(1); Spacer()
                }.padding(.vertical, 3).background(Color.gray.opacity(0.08))
            }.overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.gray.opacity(0.2)))
        }
    }

    // C-07 Import Data from Previous LookinBody
    var importPreviousLB: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(T("Import Data from past versions of LookinBody to LookinBody120.")).font(.system(size: 13))
            ajuda("Compatible: LookinBody120, Lookin'Body110 (Ver.11+), Lookin'Body Basic (Ver.N07+), Lookin'Body 3.0 (Ver.55+).")
            ajuda("* The restored data from LookinBody will be merged with your current data.")
            botaoCinza("Import Data from Previous LookinBody", largura: 300) { restaurarComPainel() }
            ajuda("Locate the folder with data, then click [OK]. Please use this function on the server computer.")
        }
    }

    // C-08 Data Importation
    var dataImportation: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(T("Import data saved from the InBody by using the USB Thumb Drive.")).font(.system(size: 13))
            ajuda("* The restored data will be merged with your current data.")
            ajuda("1) Click [Data Importation] below.  2) Select the USB used to export data from the InBody. Open the 'inbody' folder, then select the 'lookinbody' folder.")
            botaoCinza("Data Importation", largura: 180) { restaurarComPainel() }
        }
    }
}
