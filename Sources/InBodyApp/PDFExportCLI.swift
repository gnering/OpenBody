import SwiftUI
import AppKit

// Headless PDF export for the fidelity oracle (test-local).
// Reuses the SAME render path as exportarPDF (ImageRenderer -> CGPDFContext),
// so the visual result is unchanged; it only avoids the NSSavePanel and writes
// to a fixed path. Text is emitted as vector glyphs (extractable positions).
@MainActor func exportPDFToDiskForTrace() {
    let p = DemoData.ana
    guard let e = p.ultimo else { return }
    let folha = FolhaResultado(paciente: p, e: e, tipo: .adulto)
    let renderer = ImageRenderer(content: folha)
    renderer.scale = 1.0   // 1 PDF point = 1 logical unit (same frame as the oracle)

    let url = URL(fileURLWithPath: "/tmp/inbody_adulto_trace.pdf")
    renderer.render { size, context in
        var box = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        guard let pdf = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
        pdf.beginPDFPage(nil)
        context(pdf)
        pdf.endPDFPage()
        pdf.closePDF()
    }
    FileHandle.standardError.write(Data("[trace] wrote \(url.path)\n".utf8))
}

// Render an arbitrary composition record (from a JSON file) to a PDF, for the
// fidelity oracle's extreme-record sweep. Same render path as above; only the
// Medida/Paciente values are injected from JSON. Non-composition fields are
// left at defaults (0/empty) — irrelevant to the composition-region diff.
@MainActor func renderRecordPDFForTrace() {
    let a = CommandLine.arguments
    guard let idx = a.firstIndex(of: "--export-pdf-json"), idx+2 < a.count else {
        FileHandle.standardError.write(Data("usage: --export-pdf-json <in.json> <out.pdf>\n".utf8)); return
    }
    renderRecordPDFForTrace(inPath: a[idx+1], outPath: a[idx+2])
}

// Variante por parametros (usada pelo modo --serve, que processa a lista inteira num processo so).
@MainActor func renderRecordPDFForTrace(inPath: String, outPath: String) {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: inPath)),
          let j = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
        FileHandle.standardError.write(Data("bad json: \(inPath)\n".utf8)); return
    }
    func d(_ k: String) -> Double { (j[k] as? NSNumber)?.doubleValue ?? 0 }
    func r(_ k: String) -> Referencia {
        let arr = (j[k] as? [Any]) ?? []
        let lo = (arr.first as? NSNumber)?.doubleValue ?? 0
        let hi = arr.count > 1 ? ((arr[1] as? NSNumber)?.doubleValue ?? 0) : 0
        return Referencia(lo: lo, hi: hi)
    }
    func dic(_ k: String) -> [String: Double] {
        guard let o = j[k] as? [String: Any] else { return [:] }
        var out: [String: Double] = [:]
        for (kk, vv) in o { if let n = vv as? NSNumber { out[kk] = n.doubleValue } }
        return out
    }
    // Aceita valores numéricos OU strings numéricas ("1.1") — usado por segFat/segFatP no boneco da 120.
    func dicNum(_ k: String) -> [String: Double] {
        guard let o = j[k] as? [String: Any] else { return [:] }
        var out: [String: Double] = [:]
        for (kk, vv) in o {
            if let n = vv as? NSNumber { out[kk] = n.doubleValue }
            else if let s = vv as? String, let d = Double(s) { out[kk] = d }
        }
        return out
    }
    if let df = j["dateFormat"] as? String, !df.isEmpty { SheetSettings.dateFormat = df }
    if let tf = j["timeFormat"] as? String, !tf.isEmpty { SheetSettings.timeFormat = tf }
    var med = Medida(data: (j["datetime"] as? String) ?? (j["data"] as? String) ?? "2026/01/01 00:00",
        peso: d("peso"), tbw: d("tbw"), icw: d("icwD"), ecw: d("ecwD"),
        proteina: d("proteina"), mineral: d("mineral"), gordura: d("gordura"),
        ffm: d("ffm"), slm: d("slm"),
        smm: d("smm"), imc: d("imc"), pgc: d("pgc"), rcq: 0, tmb: 0, gv: 0, ecwTbw: d("ecwTbw"),
        refTbw: r("refTbw"), refGordura: r("refGordura"), refFfm: r("refFfm"),
        refSmm: r("refSmm"), seg: dic("seg"), segp: dic("segp"),
        refProteina: r("refProteina"), refMineral: r("refMineral"),
        refSlm: r("refSlm"), refPeso: r("refPeso"),
        pwt: d("pwt"), psmm: d("psmm"), pfat: d("pfat"),
        bmiMin: d("bmiMin"), bmiMax: d("bmiMax"), ibmi: d("ibmi2"),
        ibmiRaw: d("ibmiRaw"), bmiMax2: d("bmiMax2"),
        pbfMin: d("pbfMin"), pbfMax: d("pbfMax"), ipbf: d("ipbf"),
        segAEC: dic("segAEC"), segFat: dicNum("segFat"), segFatP: dicNum("segFatP"),
        altura: d("altura"),
        segpIdeal: dic("segpIdeal"),
        wed: Double((j["wed"] as? String) ?? "") ?? 0,   // AEC usa ED.WED (campo pronto), nao ecw/tbw
        segMin: dic("segMin"), segMax: dic("segMax"),
        equip: (j["equip"] as? String) ?? "", etype3: (j["etype3"] as? String) ?? "")
    // Right-column raw display strings (same JSON as the oracle -> identical input).
    let rightKeys = ["fs","vfa","wed","tw","wc","fc","mc","etype2","bmr","bmrMin","bmrMax",
                     "bcm","bcmMin","bcmMax","icw","icwMin","icwMax","ecw","ecwMin","ecwMax",
                     "whr","whrMin","whrMax","bsmi","recEnergy","wbpa50","obeDeg",
                     "obeImc","obePgc","vfl","ffm","ffmMin","ffmMax","smi",
                     "smiVal","smiMin","smiMax"]
    var right: [String: String] = [:]
    for k in rightKeys { if let v = j[k] as? String, !v.isEmpty { right[k] = v } }
    // Gordura segmentar (kg/%) e impedância Z: objetos de strings achatados em rightRaw.
    func strObj(_ k: String) -> [String: String] {
        guard let o = j[k] as? [String: Any] else { return [:] }
        var out: [String: String] = [:]
        for (kk, vv) in o { if let sv = vv as? String { out[kk] = sv } }
        return out
    }
    for (k, v) in strObj("segFat")  { right["fat"  + k] = v }   // fatRA, fatLA, fatTR, fatRL, fatLL
    for (k, v) in strObj("segFatP") { right["pfat" + k] = v }   // pfatRA, ...
    for (k, v) in strObj("imp")     { right[k] = v }            // IRA1, ILA1, ... ILL1M
    for (k, v) in strObj("circ")    { right["circ_" + k] = v }  // circunferência segmentar (370S)
    med.rightRaw = right
    // Numéricos das folhas água/criança (mesmo JSON do oráculo).
    var sraw: [String: Double] = [:]
    for k in ["ptbw","picw","pecw","icwD","ecwD","icwMinD","ecwMinD","icwMaxD","ecwMaxD","plean",
              "wwRA","wwLA","wwT","wwRL","wwLL","wwRAMin","wwRAMax","wwTMin","wwTMax",
              "wwRLMin","wwRLMax","pinwRA","pinwLA","pinwT","pinwRL","pinwLL",
              "bmc","bmcMin","bmcMax","waistCirc",
              "obesityDeg","odMin","odMax","ac","amc","tbwFfm","ffmi","bfmi",
              "totScore","iwt"] {
        if let n = j[k] as? NSNumber { sraw[k] = n.doubleValue }
    }
    med.sheetRaw = sraw
    // Multi-exam history (single source of truth: the SAME record JSON's "history" array,
    // chronological oldest->recent, that also feeds the oracle). When present it drives the
    // Histórico block; absent -> single-exam behavior (unchanged for the 8 verified blocks).
    var exames: [Medida] = [med]
    if let hist = j["history"] as? [[String: Any]], !hist.isEmpty {
        func hd(_ o: [String: Any], _ k: String) -> Double { (o[k] as? NSNumber)?.doubleValue ?? 0 }
        let z = Referencia(lo: 0, hi: 0)
        let built: [Medida] = hist.map { o in
            Medida(data: (o["data"] as? String) ?? "2026/01/01 00:00",
                   peso: hd(o, "peso"), tbw: hd(o, "tbw"), icw: hd(o, "icw"), ecw: hd(o, "ecw"),
                   proteina: 0, mineral: 0, gordura: hd(o, "gordura"), ffm: 0, slm: hd(o, "slm"),
                   smm: hd(o, "smm"), imc: 0, pgc: hd(o, "pgc"), rcq: 0, tmb: 0, gv: 0, ecwTbw: hd(o, "ecwTbw"),
                   refTbw: z, refGordura: z, refFfm: z, refSmm: z, seg: [:], segp: [:],
                   altura: hd(o, "altura"))   // altura POR EXAME (histórico pediátrico usa a real, não a atual)
        }
        exames = built.reversed()   // Paciente.exames convention = recent first
    }
    let pac = Paciente(id: (j["id"] as? String) ?? "TST",
        nome: (j["nome"] as? String) ?? "Teste",
        sexo: (j["sexo"] as? String) ?? "F",
        idade: Int(d("idade")), altura: d("altura"), exames: exames)
    // Tipo de folha vem do próprio registro ("sheet"): a folha pediátrica é fed pelo MESMO JSON
    // que o oráculo (--hist-ped). Sem "sheet" => adulto (comportamento inalterado p/ os blocos verdes).
    let sheetKey = (j["sheet"] as? String) ?? "adulto"
    let tipo: TipoFolha = (sheetKey == "pediatrica" || sheetKey == "child") ? .pediatrica
        : (sheetKey == "water" || sheetKey == "agua") ? .agua : .adulto
    let folha = FolhaResultado(paciente: pac, e: med, tipo: tipo)
    let renderer = ImageRenderer(content: folha)
    // PNG (visual, alta resolução p/ comparar com a foto) quando a saída termina em .png; senão PDF.
    if outPath.lowercased().hasSuffix(".png") {
        renderer.scale = 3.0   // 826×1169 lógico -> ~2480×3508 px (mesma escala da moldura real)
        if let img = renderer.cgImage {
            let rep = NSBitmapImageRep(cgImage: img)
            if let data = rep.representation(using: .png, properties: [:]) {
                try? data.write(to: URL(fileURLWithPath: outPath))
            }
        }
        FileHandle.standardError.write(Data("[trace] wrote \(outPath)\n".utf8))
        return
    }
    renderer.scale = 1.0
    let url = URL(fileURLWithPath: outPath)
    renderer.render { size, context in
        var box = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        guard let pdf = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
        pdf.beginPDFPage(nil); context(pdf); pdf.endPDFPage(); pdf.closePDF()
    }
    FileHandle.standardError.write(Data("[trace] wrote \(outPath)\n".utf8))
}
