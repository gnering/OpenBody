import Foundation

/// Ajuste fino de posição da impressão (A-03), em milímetros, para papel que sai torto.
/// Limitado a +/-10mm em cada eixo (além disso o conteúdo sairia da página).
/// Aplicado em PrintService.FolhasPrintView.draw. 1mm = 2.834645 pt.
enum AlinhamentoImpressao {
    private static let kx = "InBodyMac.print.dx", ky = "InBodyMac.print.dy"
    static let limite = 10.0
    static let mmParaPt = 2.834645

    static var dx: Double { UserDefaults.standard.double(forKey: kx) }
    static var dy: Double { UserDefaults.standard.double(forKey: ky) }
    static var dxPt: Double { dx * mmParaPt }
    static var dyPt: Double { dy * mmParaPt }

    static func salvar(dx: Double, dy: Double) {
        UserDefaults.standard.set(clamp(dx), forKey: kx)
        UserDefaults.standard.set(clamp(dy), forKey: ky)
    }
    static func resetar() {
        UserDefaults.standard.removeObject(forKey: kx)
        UserDefaults.standard.removeObject(forKey: ky)
    }
    private static func clamp(_ v: Double) -> Double { max(-limite, min(limite, v)) }
}
