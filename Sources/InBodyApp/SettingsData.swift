import Foundation

/// Dados estáticos das telas de Setup, fiéis às listas reais do LookinBody120
/// (extraídas do código descompilado e do manual). Ver specs/settings_audit.md.
enum SetupData {
    /// A-01: 54 países (a UI mostra o nome; o código guarda um `[nn]` interno).
    static let countries = [
        "USA", "UK", "Argentina", "Australia", "Brazil", "Bulgaria", "Chile",
        "China", "Colombia", "Costa Rica", "Cuba", "Czech Republic", "Denmark",
        "Ecuador", "Egypt", "Finland", "France", "Germany", "Greece", "Hong Kong",
        "Hungary", "India", "Indonesia", "Iran", "Israel", "Italy", "Japan",
        "Lebanon", "Malaysia", "Mexico", "Netherlands", "Norway", "Peru", "Poland",
        "Portugal", "Puerto Rico", "Republic of Korea", "South Africa", "Romania",
        "Russia/Kazakhstan", "Saudi Arabia", "Serbia", "Singapore", "Spain",
        "Sweden", "Switzerland", "Taiwan", "Thailand", "Turkey", "UAE", "Ukraine",
        "Venezuela", "Vietnam", "WHO",
    ]

    /// A-01: 26 idiomas com código `[XX]`.
    static let languages = [
        "English [GB]", "Arabic [AE]", "Bulgarian [BG]", "Chinese [CN]",
        "Czech [CZ]", "Finnish [FI]", "French [FR]", "German [DE]", "Greek [GR]",
        "Italian [IT]", "Japanese [JP]", "Korean [KR]", "Dutch [NL]", "Polish [PL]",
        "Portuguese [PT]", "Portuguese(Brazil) [BR]", "Romanian [RO]",
        "Russian [RU]", "Slovak [SK]", "Spanish [ES]", "Chinese(Traditional) [TW]",
        "Thai [TH]", "Turkish [TR]", "Spanish(Mexico) [MX]", "Vietnamese [VN]",
        "Ukrainian [UA]",
    ]

    /// B-01: 18 modelos de InBody, com as interfaces suportadas (strings do código).
    static let inbodyModels = [
        "InBody120 (Bluetooth)",
        "InBody230 (Serial, USB)",
        "InBody260 (Serial, LAN, USB, Bluetooth, Wi-Fi)",
        "InBody270 (Serial, LAN, USB, Bluetooth, Wi-Fi)",
        "InBody360S (Serial, LAN, USB, Bluetooth, Wi-Fi)",
        "InBody370 (Serial, USB)",
        "InBody370S (Serial, LAN, USB, Bluetooth, Wi-Fi)",
        "InBody380 (Serial, LAN, Bluetooth, Wi-Fi)",
        "InBody430 (Serial, USB)",
        "InBody470 (Serial, LAN, USB, Bluetooth, Wi-Fi)",
        "InBody520 (Serial, LAN)",
        "InBody560 (Serial, LAN, USB, Bluetooth, Wi-Fi)",
        "InBody570 (Serial, LAN, USB, Bluetooth, Wi-Fi)",
        "InBody580 (Serial, LAN, Bluetooth, Wi-Fi)",
        "InBody720 (Serial)",
        "InBody760 (Serial, LAN, USB, Bluetooth, Wi-Fi)",
        "InBody770 (Serial, LAN, USB, Bluetooth, Wi-Fi)",
        "InBody970 (Serial, LAN, USB, Bluetooth, Wi-Fi)",
    ]
    static let inbodyModelDefault = "InBody770 (Serial, LAN, USB, Bluetooth, Wi-Fi)"

    /// C-04: períodos de auto-backup.
    static let backupPeriods = [
        "Everyday", "Every 3 days", "Every 5 days", "Every week (Default)",
        "Every 15 days", "Every month", "Every 2 months", "Every 3 months",
    ]

    /// D-01/D-02: métodos de integração de dados (Order / InBody).
    static let integrationMethodsFull = [
        "None", "Oracle Database", "MS-SQL (Microsoft SQL Server)",
        "HL7 (Health Level 7)", "GDT (Gerätedatenträger)", "Milon System",
        "Virtuagym System", "DICOM",
    ]
    /// D-03: integração da folha de resultado (só FTP).
    static let integrationMethodsResultsSheet = ["None", "FTP (File Transfer Protocol)"]

    /// B-03: itens de output/interpretação com o espaço `[n]` que consomem do Free Space.
    static let outputItems: [(String, Int)] = [
        ("InBody Score Output", 10),
        ("Body Composition Analysis Output", 21),
        ("Obesity Analysis Output", 10),
        ("Obesity Evaluation Output", 10),
        ("Skeletal Muscle Mass Output", 10),
        ("SMI Output (History)", 10),
        ("Visceral Fat Area (Graph) Output", 21),
        ("Visceral Fat Level Output", 10),
        ("Body Type Output", 30),
        ("Weight Control Output", 10),
        ("Whole Body Phase Angle (History)", 10),
        ("Segmental Phase Angle Output", 21),
        ("Extracellular Water Ratio Output", 10),
        ("Waist-Hip Ratio Output", 10),
        ("Fat Free Mass Output", 10),
        ("Basal Metabolic Rate Output", 10),
        ("Bone Mineral Content Output", 10),
        ("Segmental Lean Analysis Output", 21),
        ("Research Item", 10),
    ]
}
