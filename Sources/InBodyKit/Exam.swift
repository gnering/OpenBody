import Foundation

/// Um exame InBody decodificado a partir do quadro vR.
public struct InBodyExam: Sendable {
    public let raw: [String]                 // 488 campos crus
    public let named: [(column: String, label: String, value: String)]

    public var patientID: String { raw.count > 1 ? raw[1] : "" }
    public var sex: String { raw.count > 2 ? raw[2] : "" }
    public var height: String { raw.count > 3 ? raw[3] : "" }
    public var age: String { raw.count > 4 ? raw[4] : "" }
    public var weight: String { raw.count > 5 ? raw[5] : "" }
    public var date: String { raw.count > 6 ? raw[6] : "" }
    public var time: String { raw.count > 7 ? raw[7] : "" }
    public var valid: String { raw.count > 8 ? raw[8] : "" }
    public var serial: String { raw.count > 11 ? raw[11] : "" }

    /// Decodifica uma carga vR (o texto apos "vR") em exame nomeado.
    public init(vRPayload: String) {
        // campos separados por ESC; raw[0]="vR"+modelo, raw[1]=ID, raw[6]=data, raw[7]=hora
        self.raw = InBodyProtocol.fields(vRPayload)
        var out: [(String, String, String)] = []
        for i in 0..<raw.count {
            if let f = InBodyFieldMap.map[i] {
                out.append((f.column, f.label, raw[i]))
            }
        }
        self.named = out
    }

    /// Laudo legivel em texto.
    public func report() -> String {
        var s = ""
        s += "Paciente \(patientID)  |  \(sex), \(age) anos, \(height) cm, \(weight) kg\n"
        s += "\(date) \(time)  |  validade: \(valid)  |  InBody serie \(serial)\n"
        s += String(repeating: "-", count: 56) + "\n"
        for (_, label, value) in named where !label.isEmpty {
            s += "  \(label.padding(toLength: 34, withPad: " ", startingAt: 0)) \(value)\n"
        }
        return s
    }
}
