import SwiftUI
import AppKit

enum TipoFolha: String, CaseIterable, Identifiable {
    case adulto = "InBody Result Sheet"
    case agua = "Body Water Result Sheet"
    case pediatrica = "InBody Children's Result Sheet"
    case historico = "Body Composition History Result Sheet"
    var id: String { rawValue }
    /// Nome em português para os seletores da UI (o rawValue é o nome interno/oráculo em inglês).
    var nomePT: String {
        switch self {
        case .adulto: return T("Body Composition Sheet")
        case .agua: return T("Body Water Sheet")
        case .pediatrica: return T("Children's Sheet")
        case .historico: return T("Body Composition History")
        }
    }
    /// A folha de Histórico é PAISAGEM e desenhada só com linhas/texto (o original também
    /// não tem arte de fundo para ela — nenhum recurso de imagem no DLL da folha).
    var paisagem: Bool { self == .historico }
    /// Fundo REAL extraído do .exe (satélite pt-BR), 2480×3125.
    var arquivo: String {
        switch self {
        case .adulto: return "inbody_adulto"
        case .agua: return "inbody_agua"
        case .pediatrica: return "inbody_ped"
        case .historico: return ""
        }
    }
}

/// Folha de resultado fiel ao InBody 770 (LookinBody120).
///
/// FUNDAÇÃO (portada byte a byte do .exe — ResultsSheetInBody770.DrawResultsSheetA4):
/// - Canvas final = 2480×3508 (A4 300dpi); espaço de desenho = esse /3 → 826,67 × 1169,33 lógico.
/// - `base.Left = 1`, `base.Top = 5` (manager zera; o driver soma +1/+5).
/// - Fundo `InBody770_Body` desenhado em (Left-22, Top+106) a 1/3 → (-21, 111), tamanho 826,67 × 1041,67.
/// - Cabeçalho `HeadInBody` em (Left-23+2, Top-21) = (-20, -16), tamanho 826,67 × 127,67.
/// - Logo custom (Setup > Custom Logo) na caixa (Left-23+535, Top-21+37) = (513, 21), até 265×105.
///
/// Fontes do .exe em pt (Arial). Em GDI 96dpi, 1pt = 96/72 px; aqui multiplico por esse fator (`g`).
// Formatação numérica da folha, half-AWAY-from-zero, casando com o oráculo (código
// real do aparelho). Fonte única: f() da folha e o CLI --fmt (calibração) usam esta.
// NSDecimalRound(.plain) = "ties away from zero"; evita o erro de (v*10) em binário.
// Formatos de data/hora do cabeçalho, LIDOS do settings.xml da clínica (nunca chumbados).
// Padrão = os valores do arquivo real (DATE_FORMAT=dd.MM.yyyy., TIME_FORMAT=HH:mm:ss).
enum SheetSettings {
    nonisolated(unsafe) static var dateFormat = "dd.MM.yyyy."
    nonisolated(unsafe) static var timeFormat = "HH:mm:ss"
    // Lê settings.xml de um diretório (o mesmo do .mdb). Formato <entry name="X">valor</entry>.
    static func carregar(_ dir: String) {
        let p = (dir as NSString).appendingPathComponent("settings.xml")
        guard let xml = try? String(contentsOfFile: p, encoding: .utf8) else { return }
        func val(_ name: String) -> String? {
            guard let r = xml.range(of: "name=\"\(name)\">") else { return nil }
            let rest = xml[r.upperBound...]
            guard let end = rest.range(of: "</entry>") else { return nil }
            let v = String(rest[..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            return v.isEmpty ? nil : v
        }
        if let d = val("DATE_FORMAT") { dateFormat = d }
        if let t = val("TIME_FORMAT") { timeFormat = t }
    }
}

// Rótulo de ESCALA (régua computada, ex.: IMC/PGC da obesidade). O ClsScale do original
// usa v.ToString("0.0")/"0.00" (half-even do runtime), NÃO o away dos VALORES. Família de
// arredondamento distinta; a calibração testa este eixo à parte contra o oráculo.
func fmtScaleLabel(_ v: Double, _ casas: Int = 1) -> String {
    // Espelha o .ToString("0.0") do ClsScale (.NET): arredonda a REPRESENTACAO
    // DECIMAL CURTA (nao o binario), half-away-from-zero. "\(v)" do Swift = mesma
    // string curta round-trip que o .NET usa (0.25->0,3 ; 1.15->1,2). Difere de
    // fmtSheet, que arredonda o binario (= Math.Round do aparelho p/ VALORES).
    var dv = Decimal(string: "\(v)") ?? Decimal(v), r = Decimal()
    NSDecimalRound(&r, &dv, casas, .plain)
    return String(format: "%.\(casas)f", NSDecimalNumber(decimal: r).doubleValue)
        .replacingOccurrences(of: ".", with: ",")
}

func fmtSheet(_ v: Double, _ casas: Int = 1) -> String {
    var dv = Decimal(v), r = Decimal()
    NSDecimalRound(&r, &dv, casas, .plain)
    let d = NSDecimalNumber(decimal: r).doubleValue
    var s = String(format: "%.\(casas)f", d)
    // .NET Math.Round(...AwayFromZero).ToString("F") preserva o zero negativo
    // (-0,4 -> "-0"); o Decimal perde o sinal. Recompoe p/ casar com o aparelho.
    if v < 0 && d == 0 && !s.hasPrefix("-") { s = "-" + s }
    return s.replacingOccurrences(of: ".", with: ",")
}

struct FolhaResultado: View {
    let paciente: Paciente
    let e: Medida
    var tipo: TipoFolha = .adulto
    // Logo custom (Setup A-04 > Custom Logo): lido da configuração persistida, nunca chumbado.
    var logo: CustomLogoConfig = CustomLogoConfig.carregar()
    /// Escala global do logo na folha. 0.70 = 30% menor (pedido 11/08/2026, todos os usuários).
    /// Ancorado no canto superior direito, então encolhe sem sair do lugar.
    static let logoEscala: CGFloat = 0.70
    // Elementos prontos vindos do desenhista genérico (OpRenderer): quando presente,
    // desenha SÓ eles em branco -- sem fundo/cabeçalho/computação -- pelo MESMO caminho de
    // render (ForEach sobre campos/barras/linhas/pontos). É a camada texto+forma pura que o
    // op-diff mede; a arte de fundo é assunto à parte (posicionada por nome de asset).
    var overrideElementos: Elementos? = nil

    // Espaço lógico do .exe (2480/3 × 3508/3).
    static let L: CGFloat = 2480.0 / 3.0      // 826,667
    static let H: CGFloat = 3508.0 / 3.0      // 1169,333
    // Paisagem (folha de Histórico): a mesma A4, virada — largura e altura trocadas.
    private var larguraPt: CGFloat { tipo.paisagem ? Self.H : Self.L }
    private var alturaPt: CGFloat { tipo.paisagem ? Self.L : Self.H }

    // base.Left / base.Top após o driver do 770 (A4).
    private let baseLeft: CGFloat = 1
    private let baseTop: CGFloat = 5

    var body: some View {
        if let ov = overrideElementos {
            return AnyView(corpoOps(ov))
        }
        return AnyView(corpoCompleto)
    }

    // Largura do canvas p/ o caminho override: adapta à extensão do conteúdo. Folhas retrato
    // (adulto/água/criança/VF/BodyType, tudo <=826) ficam em 826; a Body History é LARGA
    // (linhas até ~1130), então o canvas cresce p/ não cortar/deslocar (senão .clipped() empurra).
    private func opsLargura(_ el: Elementos) -> CGFloat {
        var mx: CGFloat = Self.L
        for l in el.linhas { for p in l.pts { mx = max(mx, p.0) } }
        for b in el.barras { mx = max(mx, b.x + b.w) }
        for d in el.pontos { mx = max(mx, d.x + d.r) }
        for c in el.campos { mx = max(mx, c.x + c.boxW) }
        return mx + 4
    }

    // Render só dos Elementos do desenhista genérico (mesmo ForEach do corpo completo).
    @ViewBuilder private func corpoOps(_ el: Elementos) -> some View {
        ZStack(alignment: .topLeading) {
            Color.white
            ForEach(Array(el.linhas.enumerated()), id: \.offset) { _, l in
                Path { p in
                    guard let f = l.pts.first else { return }
                    p.move(to: CGPoint(x: f.0, y: f.1))
                    for q in l.pts.dropFirst() { p.addLine(to: CGPoint(x: q.0, y: q.1)) }
                }.stroke(l.cor, lineWidth: l.w)
            }
            ForEach(Array(el.barras.enumerated()), id: \.offset) { _, b in
                Rectangle().fill(b.cor).frame(width: max(0, b.w), height: b.h).offset(x: b.x, y: b.y)
            }
            ForEach(Array(el.pontos.enumerated()), id: \.offset) { _, d in
                Circle().fill(d.cor).frame(width: d.r * 2, height: d.r * 2).offset(x: d.x - d.r, y: d.y - d.r)
            }
            ForEach(Array(el.campos.enumerated()), id: \.offset) { _, cp in
                Text(cp.txt)
                    .font(cp.bold ? .custom(cp.fonte, fixedSize: cp.size).bold() : .custom(cp.fonte, fixedSize: cp.size))
                    .italic(cp.italic).foregroundStyle(cp.cor).fixedSize()
                    .frame(width: cp.boxW, alignment: cp.alinha)
                    .offset(x: cp.x - (cp.alinha == .trailing ? cp.boxW : (cp.alinha == .center ? cp.boxW/2 : 0)), y: cp.y)
            }
        }
        .frame(width: opsLargura(el), height: alturaPt).background(Color.white).clipped()
    }

    private var corpoCompleto: some View {
        ZStack(alignment: .topLeading) {
            Color.white
            // Fundo oficial InBody a 1/3. Escolhido pelo modelo (EQUIP) na folha adulta.
            // Cada modelo tem seu offset de fundo (o .exe posiciona diferente por modelo); ajusta o
            // alinhamento do conteúdo desenhado com os campos impressos na moldura.
            bgImage(fundoArquivo, x: baseLeft - 22 + fundoOffset.dx, y: baseTop + 106 + fundoOffset.dy,
                    w: 2480.0/3.0, h: 3125.0/3.0)
            // Cabeçalho oficial por folha (adulto: HeadInBody; criança: HeadInBodyChild; água: HeadBodyWater).
            switch tipo {
            case .adulto:
                bgImage("inbody_header", x: baseLeft - 23 + 2, y: baseTop - 21, w: 2480.0/3.0, h: 383.0/3.0)
            case .pediatrica:
                bgImage("inbody_header_ped", x: baseLeft - 17, y: baseTop - 17, w: 2480.0/3.0, h: 383.0/3.0)
            case .agua:
                bgImage("inbody_header_agua", x: baseLeft - 14, y: baseTop - 15, w: 2480.0/3.0, h: 383.0/3.0)
            case .historico:
                EmptyView()   // paisagem, sem arte: o cabeçalho é desenhado pela própria folha
            }
            // Sexo: o aparelho desenha uma IMAGEM (r_male_lb/r_female_lb) a 1/3.2 em (fLeft+332, fTop+111),
            // não texto (ClsDrawHeader:345). Por isso o op-diff de texto não tem nada nesta coluna; a
            // fidelidade visual do rótulo é validada pelo diff de imagem da região gráfica.
            if !tipo.paisagem {
                bgImage(paciente.sexo == "F" ? "inbody_r_female_lb" : "inbody_r_male_lb",
                        x: baseLeft - 23 + 332, y: baseTop - 21 + 111, w: 164.0/3.2, h: 44.0/3.2, ext: "png")
            }
            // Logo custom em modo Imagem (caixa 265×105 em (513, 21)).
            // Na folha de Água/Pediátrica o rótulo [InBody770] fica mais à direita e mais
            // baixo que na adulta, encostando no logo. Desloca o logo p/ o canto livre
            // (só o overlay do logo; a folha fiel não é tocada).
            if !tipo.paisagem, let url = logoImagemURL, let img = NSImage(contentsOf: url) {
                let dLogo: (x: CGFloat, y: CGFloat) = {
                    switch tipo {
                    case .agua, .pediatrica: return (26, -6)
                    default: return (0, 0)
                    }
                }()
                Image(nsImage: img).resizable().scaledToFit()
                    .frame(width: 265 * Self.logoEscala, height: 105 * Self.logoEscala, alignment: .topLeading)
                    .offset(x: baseLeft - 23 + 535 + dLogo.x, y: baseTop - 21 + 37 + dLogo.y)
            }
            // Ícones do Histórico (DrawBodyCompostionHistoryD, folha adulto 770): legenda de fundo
            // "r_re_body_comp_history_check" (GIF 288×40, desenhado a Width/3=96×13 em fLeft-93,fTop+163)
            // e o "Check" (PNG 34×48, desenhado 12×12 em fLeft-94,fTop+159). Extraídos do resx
            // LBPC.InBody.Print.BaseCommon; embutidos como asset (igual ao fundo principal).
            if tipo == .adulto {
                bgImage("inbody_hist_bg", x: 25, y: 1087, w: 288.0/3.0, h: 40.0/3.0, ext: "png")
                bgImage("inbody_hist_check", x: 24, y: 1083, w: 12, h: 12, ext: "png")
            }

            // Imagens de bloco (arte embutida do .exe: coluna direita etc.) — atrás dos overlays.
            ForEach(Array(elementos.imgs.enumerated()), id: \.offset) { _, im in
                bgImage(im.nome, x: im.x, y: im.y, w: im.w, h: im.h, ext: im.ext)
            }
            // Linhas (histórico / gráficos)
            ForEach(Array(elementos.linhas.enumerated()), id: \.offset) { _, l in
                Path { p in
                    guard let f = l.pts.first else { return }
                    p.move(to: CGPoint(x: f.0, y: f.1))
                    for q in l.pts.dropFirst() { p.addLine(to: CGPoint(x: q.0, y: q.1)) }
                }.stroke(l.cor, lineWidth: l.w)
            }
            // Barras (retângulos) — posicionadas pelo canto superior-esquerdo.
            ForEach(Array(elementos.barras.enumerated()), id: \.offset) { _, b in
                Rectangle().fill(b.cor)
                    .frame(width: max(0, b.w), height: b.h)
                    .offset(x: b.x, y: b.y)
            }
            // Pontos
            ForEach(Array(elementos.pontos.enumerated()), id: \.offset) { _, d in
                Circle().fill(d.cor).frame(width: d.r * 2, height: d.r * 2)
                    .offset(x: d.x - d.r, y: d.y - d.r)
            }
            // Textos — posicionados pelo canto superior-esquerdo (como GDI DrawString).
            ForEach(Array(elementos.campos.enumerated()), id: \.offset) { _, cp in
                Text(cp.txt)
                    .font(cp.bold ? .custom(cp.fonte, fixedSize: cp.size).bold() : .custom(cp.fonte, fixedSize: cp.size))
                    .italic(cp.italic)
                    .foregroundStyle(cp.cor)
                    .fixedSize()
                    .frame(width: cp.boxW, alignment: cp.alinha)
                    .offset(x: cp.x - (cp.alinha == .trailing ? cp.boxW : (cp.alinha == .center ? cp.boxW/2 : 0)),
                            y: cp.y)
            }
        }
        .frame(width: larguraPt, height: alturaPt)
        .background(Color.white)
        .clipped()
    }

    @ViewBuilder private func bgImage(_ nome: String, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat,
                                      ext: String = "jpg") -> some View {
        // Nome vazio (folha sem arte de fundo, ex. Histórico): NÃO procurar no bundle —
        // `url(forResource: "")` casa com outro recurso e a arte errada era esticada na folha.
        if !nome.isEmpty,
           let url = Bundle.module.url(forResource: nome, withExtension: ext),
           let img = NSImage(contentsOf: url) {
            Image(nsImage: img).resizable().interpolation(.high)
                .frame(width: w, height: h).offset(x: x, y: y)
        }
    }

    // MARK: - modelos de desenho (coordenadas LÓGICAS, canto superior-esquerdo)
    struct Campo { let txt: String; let x, y: CGFloat; let size: CGFloat; let fonte: String; let cor: Color; let alinha: Alignment; let boxW: CGFloat; var bold: Bool = false; var italic: Bool = false }
    struct Barra { let x, y, w, h: CGFloat; let cor: Color }
    struct Ponto { let x, y, r: CGFloat; let cor: Color }
    struct Linha { let pts: [(CGFloat, CGFloat)]; let cor: Color; let w: CGFloat }
    // Imagem de bloco embutida (arte do .exe, ex.: coluna direita). Desenhada a partir do
    // asset PNG em Bundle.module, posicionada pelo canto superior-esquerdo (como g.DrawImage).
    struct Img { let nome: String; let x, y, w, h: CGFloat; var ext: String = "png" }
    struct Elementos { var campos: [Campo] = []; var barras: [Barra] = []; var pontos: [Ponto] = []; var linhas: [Linha] = []; var imgs: [Img] = [] }

    /// GDI pt → px (96dpi).
    private func g(_ pt: CGFloat) -> CGFloat { pt * 96.0 / 72.0 }
    /// Texto alinhado à esquerda (padrão GDI).
    private func txt(_ s: String, _ x: CGFloat, _ y: CGFloat, pt: CGFloat = 10, arial: Bool = true,
                     _ cor: Color = .black, _ al: Alignment = .leading, box: CGFloat = 400) -> Campo {
        Campo(txt: s, x: x, y: y, size: g(pt), fonte: arial ? "Arial" : "Arial", cor: cor, alinha: al, boxW: box)
    }
    // Folha BR usa vírgula decimal (33,1 / 40,0~49,0), não ponto.
    private func f(_ v: Double, _ casas: Int = 1) -> String { fmtSheet(v, casas) }

    // MARK: - dispatch
    private var elementos: Elementos {
        var el = Elementos()
        el.campos += header
        // Seções de valores/barras/histórico: portadas por seção (ClsDrawLeftOutput/RightOutput).
        // TODO(port): ver InBodySheetSections.swift
        let s = secoes()
        el.campos += s.campos; el.barras += s.barras; el.pontos += s.pontos; el.linhas += s.linhas
        el.imgs += s.imgs
        return el
    }

    // Data do cabeçalho no formato do ORIGINAL: ClsDrawHeader desenha
    // strDateFormat + " " + strTimeFormat.Replace(":ss","") → "dd.MM.yyyy." + "HH:mm".
    // A folha real da clínica usa a opção dd.MM.yyyy. (rdoDMY), ex.: "25.05.2026. 13:47".
    private var dataCabecalho: String {
        // e.data pode vir CRU "yyyyMMddHHmmss" (DATETIMES do banco) ou já "yyyy/MM/dd HH:mm".
        let entrada = DateFormatter(); entrada.locale = Locale(identifier: "en_US_POSIX")
        var d: Date? = nil
        for f in ["yyyyMMddHHmmss", "yyyy/MM/dd HH:mm:ss", "yyyy/MM/dd HH:mm"] {
            entrada.dateFormat = f
            if let dd = entrada.date(from: e.data) { d = dd; break }
        }
        guard let dd = d else { return e.data }
        // ClsDrawHeader: DateFormat + " " + TimeFormat.Replace(":ss",""). Ambos vêm do settings.xml.
        let saida = DateFormatter(); saida.locale = Locale(identifier: "pt_BR")
        saida.dateFormat = SheetSettings.dateFormat + " " + SheetSettings.timeFormat.replacingOccurrences(of: ":ss", with: "")
        return saida.string(from: dd)
    }

    // MARK: - CABEÇALHO por folha (ClsDrawHeader.DrawInBody / DrawInBodyChild / DrawBodyWater)
    //   adulto:  origem (Left-23, Top-21) = (-22,-16); rótulos 47/191/277/333/391, valores 46/190/278/392
    //   criança: origem (Left-17, Top-18) = (-16,-12); MESMOS offsets internos do adulto
    //   água:    origem (Left-14, Top-14) = (-13,-10); rótulos 48/189/272/328/386, valores 46/188/274/386
    private var header: [Campo] {
        let hx: CGFloat, hy: CGFloat
        let lb: [CGFloat], vl: [CGFloat]
        switch tipo {
        case .adulto:
            hx = baseLeft - 23; hy = baseTop - 21
            lb = [47, 191, 277, 333, 391]; vl = [46, 190, 278, 392]
        case .pediatrica:
            hx = baseLeft - 17; hy = baseTop - 18 + 1     // driver criança soma Top+=1
            lb = [47, 191, 277, 333, 391]; vl = [46, 190, 278, 392]
        case .agua:
            hx = baseLeft - 14; hy = baseTop - 14 - 1     // driver água soma Top+=-1
            lb = [48, 189, 272, 328, 386]; vl = [46, 188, 274, 386]
        case .historico:
            return []     // a folha de Histórico desenha o proprio cabecalho (paisagem)
        }
        let cinzaLabel = Color(red: 93/255, green: 93/255, blue: 93/255)
        var a: [Campo] = []
        // Rótulos (pt-BR) — fTop+13+80 = +93
        a.append(txt("ID",                    hx + lb[0], hy + 93, pt: 10, cinzaLabel))
        a.append(txt(T("Height"),                hx + lb[1], hy + 93, pt: 10, cinzaLabel))
        a.append(txt(T("Age"),                 hx + lb[2], hy + 93, pt: 10, cinzaLabel))
        a.append(txt(T("Gender"),                  hx + lb[3], hy + 93, pt: 10, cinzaLabel))
        a.append(txt(T("Date / Time"),           hx + lb[4], hy + 93, pt: 10, cinzaLabel))
        // Valores — fTop+110
        a.append(txt(paciente.id,             hx + vl[0], hy + 110, pt: 10))
        if !paciente.nome.isEmpty {
            a.append(txt("(" + paciente.nome + ")", hx + vl[0], hy + 125, pt: 9, Color(white: 0.1)))
        }
        // Altura no formato InBody: 1 casa decimal + "cm" sem espaço (ex.: "155,5cm").
        a.append(txt(fmtSheet(paciente.altura, 1) + "cm", hx + vl[1], hy + 110, pt: 10))
        a.append(txt("\(paciente.idade)",     hx + vl[2], hy + 110, pt: 10))
        // Sexo NÃO é texto: o aparelho desenha r_male_lb/r_female_lb como imagem (ver body).
        a.append(txt(dataCabecalho,           hx + vl[3], hy + 110, pt: 10))
        // Logo custom (caixa 265×105 em fLeft+535, fTop+37) — lido da configuração.
        if logo.modo == .texto {
            let lx = hx + 535, ly = hy + 37
            var yCursor = ly
            for linha in logo.linhas where !linha.texto.isEmpty {
                let tam = CGFloat(linha.tamanho) * Self.logoEscala   // 30% menor (todos os usuários)
                a.append(Campo(txt: linha.texto, x: lx, y: yCursor, size: g(tam),
                               fonte: linha.fonte, cor: Color(white: 0.1), alinha: .leading, boxW: 265,
                               bold: linha.negrito))
                yCursor += g(tam) + 4
            }
        }
        return a
    }

    /// Caminho da imagem do logo, quando o modo é Imagem (desenhada no corpo).
    var logoImagemURL: URL? {
        guard logo.modo == .imagem, !logo.imagemPath.isEmpty else { return nil }
        return URL(fileURLWithPath: logo.imagemPath)
    }

    // Modelo da balança do exame (BCA_TBL.EQUIP). Vazio = trata como 770 (folha adulta padrão).
    var equipModelo: String { e.equip.uppercased() }

    // Offset do fundo por modelo (relativo ao padrão -22/+106 do 770). O .exe posiciona a moldura
    // em Y diferente por modelo; sem isso o conteúdo desenhado fica desalinhado dos campos impressos.
    // Valores EXATOS derivados do .exe: a moldura é desenhada por modelo em posição diferente.
    // dx/dy = quanto mover a moldura (padrão -22/+106) pra bater com onde o .exe põe o conteúdo.
    //   .exe DrawBackground:      120 base.Left-22 / 270 base.Left-19 / 370S base.Left-15, Top+103/103/113
    //   conteúdo (composição):    base.Left+338 (120/270) / base.Left+344 (370S), Top+156/156/183
    //   → offset conteúdo-moldura X = 360 (120) / 357 (270) / 359 (370S); Y = 53/53/70.
    //   app: conteúdo em L0+338 (L0=2) e moldura em baseLeft-22+dx (baseLeft=1) → resolve dx/dy abaixo.
    private var fundoOffset: (dx: CGFloat, dy: CGFloat) {
        switch equipModelo {
        case "120":  return (dx: 1, dy: -3)
        case "270":  return (dx: 4, dy: -3)
        case "370S": return (dx: 7, dy: 4)
        default:     return (dx: 0, dy: 0)
        }
    }

    // Arte de fundo por modelo: a folha adulta escolhe a moldura conforme o EQUIP.
    // 120 tem molde próprio (composição simples, bonecos, sem AEC); demais caem no fundo do 770.
    private var fundoArquivo: String {
        if tipo == .adulto {
            if equipModelo == "120" { return "inbody_120" }
            if equipModelo == "270" { return "inbody_270" }
            if equipModelo == "370S" { return "inbody_370s" }
        }
        return tipo.arquivo
    }

    // MARK: - SEÇÕES (a portar de ClsDrawLeftOutput / ClsDrawRightOutput)
    private func secoes() -> Elementos {
        switch tipo {
        case .adulto:
            // Folha por modelo: 120/270 têm construtor próprio; demais seguem o 770.
            if equipModelo == "120" { return InBody120Sheet(self).build() }
            if equipModelo == "270" { return InBody270Sheet(self).build() }
            if equipModelo == "370S" { return InBody370SSheet(self).build() }
            return InBodyAdultSheet(self).build()
        case .agua: return InBodyWaterSheet(self).build()
        case .pediatrica: return InBodyChildSheet(self).build()
        case .historico: return InBodyHistorySheet(self).build()
        }
    }

    // Acessos usados pelos módulos de seção.
    var med: Medida { e }
    var pac: Paciente { paciente }
    func campo(_ s: String, _ x: CGFloat, _ y: CGFloat, pt: CGFloat = 10, _ cor: Color = .black,
               _ al: Alignment = .leading, box: CGFloat = 400) -> Campo { txt(s, x, y, pt: pt, cor, al, box: box) }
    func fmt(_ v: Double, _ c: Int = 1) -> String { f(v, c) }
    var origemLeft: CGFloat { baseLeft }
    var origemTop: CGFloat { baseTop }
}
