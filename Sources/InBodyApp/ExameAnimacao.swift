import SwiftUI

/// Animação do exame: o boneco 3D sendo escaneado segmento a segmento, remontada dos
/// 40 quadros ORIGINAIS do LookinBody (extraídos da DLL InBodyTestPopup, Resources/
/// exame_frame_00..39.png). Toca em loop enquanto a balança mede (~90s).
struct ExameAnimacao: View {
    var ativo: Bool

    // Carrega os quadros uma vez (Bundle.module, como as folhas de resultado).
    private static let quadros: [NSImage] = (0..<40).compactMap { i in
        Bundle.module.url(forResource: String(format: "exame_frame_%02d", i), withExtension: "png")
            .flatMap { NSImage(contentsOf: $0) }
    }

    @State private var indice = 0
    private let relogio = Timer.publish(every: 0.09, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if !Self.quadros.isEmpty {
                Image(nsImage: Self.quadros[min(indice, Self.quadros.count - 1)])
                    .resizable().interpolation(.high).scaledToFit()
            } else {
                // Fallback se os quadros não vierem no bundle: silhueta do sistema.
                Image(systemName: "figure.stand").resizable().scaledToFit()
                    .foregroundStyle(.gray.opacity(0.5)).padding(40)
            }
        }
        .onReceive(relogio) { _ in
            guard ativo, Self.quadros.count > 1 else { return }
            indice = (indice + 1) % Self.quadros.count
        }
    }
}
