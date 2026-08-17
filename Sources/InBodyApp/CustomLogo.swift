import SwiftUI
import AppKit

/// Logo personalizado do canto superior direito da folha (Setup A-04 > Custom Logo).
/// Fiel ao .exe (SetupResultsSheetCustomLogo): 3 modos e, no modo Texto, 3 linhas,
/// cada uma com fonte, tamanho e negrito. No modo Imagem, carrega um arquivo.
/// Persistido em UserDefaults para valer no app inteiro e no render da folha.

enum LogoModo: Int, Codable, CaseIterable, Identifiable {
    case nenhum = 0      // rdbNotUse
    case texto = 1       // rdbCreate
    case imagem = 2      // rdbLoad
    var id: Int { rawValue }
    var rotulo: String {
        switch self {
        case .nenhum: return "Sem logo"
        case .texto: return "Logo em texto"
        case .imagem: return "Carregar imagem"
        }
    }
}

struct LogoLinha: Codable, Equatable {
    var texto: String = ""
    var fonte: String = "Arial"
    var tamanho: Int = 14
    var negrito: Bool = false
}

struct CustomLogoConfig: Codable, Equatable {
    // Padrão de fábrica = SEM logo (igual ao .exe: rdbNotUse). O usuário configura o seu em Setup A-04.
    var modo: LogoModo = .nenhum
    var linhas: [LogoLinha] = [LogoLinha(), LogoLinha(), LogoLinha()]
    var imagemPath: String = ""

    static let chave = "customLogoConfig"

    static func carregar() -> CustomLogoConfig {
        guard let d = UserDefaults.standard.data(forKey: chave),
              let c = try? JSONDecoder().decode(CustomLogoConfig.self, from: d) else {
            return CustomLogoConfig()
        }
        return c
    }

    func salvar() {
        if let d = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(d, forKey: Self.chave)
        }
    }

    /// Fontes disponíveis (as mais comuns do LookinBody).
    static let fontesDisponiveis = ["Arial", "Arial Black", "Verdana", "Tahoma", "Times New Roman", "Georgia", "Calibri"]
    static let tamanhosDisponiveis = [8, 9, 10, 11, 12, 14, 16, 18, 20, 22, 24]
}
