import SwiftUI

/// D. Data Integration (manual p.122-124). Título + "Data integration method" +
/// combo; ao escolher um método aparecem campos dinâmicos específicos.
extension SettingsDetailView {
    // D-01 Order(Member) data integration
    var orderIntegration: some View { integrationScreen(SetupData.integrationMethodsFull) }

    // D-02 InBody data integration
    var inbodyDataIntegration: some View { integrationScreen(SetupData.integrationMethodsFull) }

    // D-03 InBody ResultsSheet integration
    var resultsSheetIntegration: some View { integrationScreen(SetupData.integrationMethodsResultsSheet) }

    private func integrationScreen(_ methods: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(T("Data integration method")).font(.system(size: 13, weight: .semibold))
                comboMenu($integMethod, methods, width: 260)
            }
            integFields
            ajuda("Detailed integration methods are provided in a separate manual. LookinBody120 is a local PC program and does not provide a dedicated server.")
        }
    }

    @ViewBuilder private var integFields: some View {
        switch integMethod {
        case "Oracle Database", "MS-SQL (Microsoft SQL Server)":
            VStack(alignment: .leading, spacing: 4) {
                campo("DSN", "", rotLargura: 130)
                campo("Database Address", "", rotLargura: 130)
                campo("Database ID", "", rotLargura: 130)
                campo("Database Name", "", rotLargura: 130)
                campo("Database Password", "", rotLargura: 130)
                campo("Port", "", rotLargura: 130, largura: 80)
                campo("Option", "", rotLargura: 130)
            }
        case "HL7 (Health Level 7)":
            VStack(alignment: .leading, spacing: 4) {
                campo("Server Address", "", rotLargura: 130)
                campo("Port", "", rotLargura: 130, largura: 80)
                campo("Sending Application", "", rotLargura: 130)
                campo("Receiving Application", "", rotLargura: 130)
            }
        case "GDT (Gerätedatenträger)":
            VStack(alignment: .leading, spacing: 4) {
                campo("Import file path", "", rotLargura: 130)
                campo("Export file path", "", rotLargura: 130)
                ajuda("File extensions: .DAT / .INF / .CLG / .TRG")
            }
        case "DICOM":
            VStack(alignment: .leading, spacing: 4) {
                campo("Called AE title", "", rotLargura: 130)
                campo("Calling AE title", "", rotLargura: 130)
                campo("Accession number", "", rotLargura: 130)
                campo("DICOM export path", "", rotLargura: 130)
                HStack { Text(T("DICOM TLS")).font(.system(size: 13)).frame(width: 130, alignment: .leading); radio("Use", false); radio("Do not use", true) }
                HStack { Text(T("DICOM Encoding")).font(.system(size: 13)).frame(width: 130, alignment: .leading); combo("UTF-8") }
                chk("Generate UID", false)
                HStack { Text(T("Image laterality")).font(.system(size: 13)).frame(width: 130, alignment: .leading); combo("None") }
            }
        case "Milon System":
            VStack(alignment: .leading, spacing: 4) {
                campo("Club ID", "", rotLargura: 130)
                campo("Club Secret", "", rotLargura: 130)
                campo("API Key", "", rotLargura: 130)
            }
        case "Virtuagym System":
            campo("API Key", "", rotLargura: 130)
        case "FTP (File Transfer Protocol)":
            VStack(alignment: .leading, spacing: 4) {
                campo("FTP Address", "", rotLargura: 130)
                campo("FTP ID", "", rotLargura: 130)
                campo("FTP Password", "", rotLargura: 130)
                campo("FTP Port", "", rotLargura: 130, largura: 80)
                HStack { Text(T("FTP Type")).font(.system(size: 13)).frame(width: 130, alignment: .leading); combo("FTP") }
            }
        default:
            EmptyView()
        }
    }
}
