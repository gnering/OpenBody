import SwiftUI

// Desenhista GENÉRICO: consome a lista de operações que o oráculo (C# decompilado
// recompilado contra o DrawingShim) emite e monta os MESMOS structs de Elementos que
// o render hand-portado usa. Assim uma folha nova sai correta SEM transcrição: roda o
// driver decompilado dela -> ops JSON -> este conversor -> FolhaResultado (caminho de
// render idêntico ao das 3 folhas já portadas, que servem de controle).
//
// Prova: para as 3 folhas portadas, ops(golden) -> Elementos -> PDF -> extrai ops deve
// bater com o golden, exatamente como o hand-port bate (op-diff = 0).

struct OpDraw: Decodable {
    let op: String
    let text: String?
    let x, y, w, h: CGFloat
    let font: String?
    let size: CGFloat
    let style: String?
    let align: String?
    let valign: String?
    let color: String?
}

enum OpRenderer {
    // Cor a partir do nome/hex que o SolidBrush.ColorName / Pen.Name emitem:
    // "Black"/"White"/"Red"/"DarkRed" ou "#AARRGGBB" (ex.: "#FF898989").
    static func cor(_ nome: String?) -> Color {
        guard let n = nome else { return .black }
        switch n {
        case "Black": return .black
        case "White": return .white
        case "Red":   return .red
        case "DarkRed": return IB.darkRed
        default: break
        }
        if n.hasPrefix("#"), n.count == 9 {
            let hex = n.dropFirst()
            func b(_ lo: Int, _ hi: Int) -> Double {
                let s = hex[hex.index(hex.startIndex, offsetBy: lo)..<hex.index(hex.startIndex, offsetBy: hi)]
                return Double(Int(s, radix: 16) ?? 0) / 255.0
            }
            let a = b(0, 2), r = b(2, 4), g = b(4, 6), bl = b(6, 8)
            return Color(.sRGB, red: r, green: g, blue: bl, opacity: a)
        }
        return .black
    }

    private static func alinhaGA(_ a: String?) -> GA {
        switch a { case "center": return .c; case "far": return .f; default: return .n }
    }

    // pt -> px (96dpi), igual ao gpx interno.
    private static func gpxL(_ pt: CGFloat) -> CGFloat { pt * 96.0 / 72.0 }

    static func elementos(_ s: FolhaResultado, _ ops: [OpDraw]) -> FolhaResultado.Elementos {
        var e = FolhaResultado.Elementos()
        for o in ops {
            switch o.op {
            case "DrawString":
                guard let txt = o.text, !txt.isEmpty else { continue }
                let bold = (o.style ?? "").contains("Bold")
                let italic = (o.style ?? "").contains("Italic")
                // Discriminador rect-draw vs point-draw: o shim grava h = FontSize*1.16 no
                // DrawString(x,y[,sf]) (por ponto, canto sup-esq, SEM centrar vertical) e
                // h = altura do retângulo no DrawString(rect,sf) (centrado vertical, GDI
                // LineAlignment=Center). Mesma escolha que o hand-port faz entre gpt e gcell.
                let pointDraw = abs(o.h - o.size * 1.16) < 0.05
                // Data do ClsLineGraph vem numa op só com "\n" (2 linhas empilhadas no mesmo
                // rect). O GDI desenha as duas no rect; espelho o split_multiline do op-diff:
                // fatia o rect em n partes iguais e centra cada linha na sua fatia.
                let linhas = txt.contains("\n")
                    ? txt.split(separator: "\n", omittingEmptySubsequences: false)
                          .map { $0.replacingOccurrences(of: "\r", with: "").trimmingCharacters(in: .whitespaces) }
                          .filter { !$0.isEmpty }
                    : [txt]
                let n = max(linhas.count, 1)
                for (i, ln) in linhas.enumerated() {
                    let sy = o.y + (n > 1 ? o.h / CGFloat(n) * CGFloat(i) : 0)
                    let sh = n > 1 ? o.h / CGFloat(n) : o.h
                    if pointDraw && n == 1 {
                        e.campos.append(gptCor(s, ln, o.x, o.y, pt: o.size, cor: cor(o.color),
                                               bold: bold, italic: italic, box: max(o.w, 1), alinhaGA(o.align)))
                    } else {
                        e.campos.append(gcellCor(s, ln, o.x, sy, o.w, sh, pt: o.size,
                                                 alinhaGA(o.align), cor: cor(o.color), bold: bold,
                                                 valign: n > 1 ? "center" : (o.valign ?? "center")))
                    }
                }
            case "FillRectangle":
                e.barras.append(FolhaResultado.Barra(x: o.x, y: o.y, w: o.w, h: o.h, cor: cor(o.color)))
            case "DrawRectangle":
                // Retângulo contornado: 4 linhas de 0,7pt (o .exe só usa isso p/ debug vermelho,
                // que fica bRectangleUse=false e nem sai; incluído por completude).
                let c = cor(o.color)
                e.linhas.append(hline(o.x, o.y, o.x + o.w, c, 0.7))
                e.linhas.append(hline(o.x, o.y + o.h, o.x + o.w, c, 0.7))
                e.linhas.append(vline(o.x, o.y, o.y + o.h, c, 0.7))
                e.linhas.append(vline(o.x + o.w, o.y, o.y + o.h, c, 0.7))
            case "DrawLine":
                // shim grava x,y = ponto1 ; w,h = ponto2. Largura da caneta não vem no op;
                // 0,7pt é a espessura padrão de todas as linhas de grade/eixo do aparelho.
                e.linhas.append(FolhaResultado.Linha(pts: [(o.x, o.y), (o.w, o.h)], cor: cor(o.color), w: 0.7))
            case "FillEllipse":
                // marcador de ponto: centro = (x+w/2, y+h/2), raio = w/2.
                e.pontos.append(FolhaResultado.Ponto(x: o.x + o.w/2, y: o.y + o.h/2, r: o.w/2, cor: cor(o.color)))
            case "DrawImage":
                // O op de imagem é anônimo (o shim não carrega o nome do recurso), então a
                // ARTE de fundo/bloco não é posicionável só pela lista de ops -- ela é a camada
                // estática, colocada por nome de asset (como o hand-port já faz com bgImage),
                // fora do op-diff de texto+forma. Ignorada aqui de propósito.
                continue
            default:
                continue
            }
        }
        return e
    }
}

// Variantes de gcell/gpt que aceitam cor e estilo explícitos vindos do op (os helpers
// originais fixam Arial/preto/near em alguns caminhos). Mesma matemática de posição.
func gcellCor(_ s: FolhaResultado, _ txt: String, _ rx: CGFloat, _ ry: CGFloat, _ rw: CGFloat, _ rh: CGFloat,
              pt: CGFloat, _ align: GA, cor: Color, bold: Bool, valign: String = "center") -> FolhaResultado.Campo {
    let emPx = pt * 96.0 / 72.0
    // Alinhamento vertical do GDI+ (LineAlignment): near=topo (default sem StringFormat), center, far=base.
    // Antes centrava SEMPRE; DrawString(rect) sem formato (ex.: rotulos de exercicio da Nutrition) e' topo,
    // e centrar jogava o texto pra fora da pagina (sumia). Agora respeita o valign gravado no op.
    let yTop: CGFloat = valign == "near" ? ry
                      : valign == "far" ? ry + (rh - emPx * 1.16)
                      : ry + (rh - emPx * 1.16) / 2.0
    let x: CGFloat = (align == .c) ? rx + rw/2 : (align == .f ? rx + rw : rx)
    return FolhaResultado.Campo(txt: txt, x: x, y: yTop, size: emPx, fonte: "Arial", cor: cor,
                                alinha: align == .c ? .center : (align == .f ? .trailing : .leading),
                                boxW: rw, bold: bold)
}

func gptCor(_ s: FolhaResultado, _ txt: String, _ x: CGFloat, _ y: CGFloat,
            pt: CGFloat, cor: Color, bold: Bool, italic: Bool, box: CGFloat, _ align: GA) -> FolhaResultado.Campo {
    FolhaResultado.Campo(txt: txt, x: x, y: y, size: pt * 96.0 / 72.0, fonte: "Arial", cor: cor,
                         alinha: align == .c ? .center : (align == .f ? .trailing : .leading),
                         boxW: box, bold: bold, italic: italic)
}
