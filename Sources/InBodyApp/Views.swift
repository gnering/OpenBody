import SwiftUI

// paleta
extension Color {
    static let lean = Color(red: 0.18, green: 0.56, blue: 0.85)
    static let fat = Color(red: 0.91, green: 0.64, blue: 0.24)
    static let water = Color(red: 0.22, green: 0.65, blue: 0.65)
    static let low = Color(red: 0.85, green: 0.51, blue: 0.17)
    static let okc = Color(red: 0.18, green: 0.62, blue: 0.39)
    static let high = Color(red: 0.75, green: 0.33, blue: 0.25)
}

func classifica(_ v: Double, _ r: Referencia) -> Color {
    v < r.lo ? .low : (v > r.hi ? .high : .okc)
}
func rotuloFaixa(_ v: Double, _ r: Referencia) -> String {
    v < r.lo ? "Abaixo" : (v > r.hi ? "Acima" : "Normal")
}

// barra de composição: valor medido com marca do limite inferior da faixa
struct BarraComposicao: View {
    let titulo: String, sub: String, valor: Double, unidade: String
    let ref: Referencia, cor: Color

    var body: some View {
        let maxv = ref.hi * 1.6
        let cls = classifica(valor, ref)
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(T(titulo)).font(.system(size: 13.5, weight: .medium))
                Text(T(sub)).font(.system(size: 11)).foregroundStyle(.secondary)
            }.frame(width: 150, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5).fill(Color.gray.opacity(0.15))
                    RoundedRectangle(cornerRadius: 5)
                        .fill(LinearGradient(colors: [cor, cor.opacity(0.75)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: min(geo.size.width, geo.size.width * valor / maxv))
                    Rectangle().fill(Color.secondary.opacity(0.5)).frame(width: 1)
                        .offset(x: geo.size.width * ref.lo / maxv)
                }
            }.frame(height: 24)

            VStack(alignment: .trailing, spacing: 1) {
                Text(String(format: "%.1f", valor)).font(.system(size: 15, weight: .semibold)).monospacedDigit()
                Text(rotuloFaixa(valor, ref)).font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(cls)
            }.frame(width: 66, alignment: .trailing)
        }
        .padding(.vertical, 6)
    }
}

struct KPI: View {
    let titulo: String, valor: String, unidade: String
    var destaque: Color? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(titulo.uppercased()).font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary).tracking(0.4)
            Text(T(valor)).font(.system(size: 24, weight: .bold)).monospacedDigit()
                .foregroundStyle(destaque ?? .primary)
            Text(T(unidade)).font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color.gray.opacity(0.06)))
    }
}

struct SegmentoCard: View {
    let nome: String, kg: Double, pct: Double
    var body: some View {
        let cls: Color = pct < 95 ? .low : (pct > 115 ? .high : .okc)
        VStack(spacing: 3) {
            Text(T(nome)).font(.system(size: 10.5)).foregroundStyle(.secondary)
            Text(String(format: "%.2f kg", kg)).font(.system(size: 15, weight: .semibold)).monospacedDigit()
            Text("\(Int(pct))%").font(.system(size: 10.5, weight: .bold))
                .padding(.horizontal, 7).padding(.vertical, 1)
                .background(Capsule().fill(cls.opacity(0.16))).foregroundStyle(cls)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color.gray.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.gray.opacity(0.12)))
    }
}

struct Cartao<Conteudo: View>: View {
    let titulo: String, dica: String
    @ViewBuilder var conteudo: Conteudo
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(titulo.uppercased()).font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary).tracking(0.6)
            Text(T(dica)).font(.system(size: 11.5)).foregroundStyle(.secondary)
                .padding(.bottom, 12)
            conteudo
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.12)))
    }
}
