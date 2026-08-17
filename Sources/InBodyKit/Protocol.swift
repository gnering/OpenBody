import Foundation

/// Protocolo de comunicacao da balanca InBody, portado do LookinBody120 v5.0.0.1
/// (ConBasicUserCon.cs / IBNetDllServer.cs). Validado contra o aparelho real.
public enum InBodyProtocol {
    public static let STX: UInt8 = 0x02
    public static let ETX: UInt8 = 0x03
    public static let ESC: UInt8 = 0x1B  // separador de campos
    public static let EQU: UInt8 = 0x7A  // "z"  EQU_ID_LB

    public static let escChar = Character(UnicodeScalar(ESC))

    /// fncMakeCrc: soma dos bytes, 6 bits baixos, deslocada de 10.
    public static func crc(_ body: [UInt8]) -> UInt8 {
        UInt8((body.reduce(0) { $0 + Int($1) } & 0x3F) + 10)
    }

    /// fncMakeCMD: STX + id + tam_lo + tam_hi + cmd1 + cmd2 + dados + crc + ETX.
    public static func makeFrame(_ c1: Character, _ c2: Character, _ data: String = "") -> [UInt8] {
        let dataB = data.unicodeScalars.map { UInt8($0.value & 0xFF) }  // latin-1
        let n = dataB.count + 2  // fncCntBod
        let lenLo = UInt8((n & 0x3F) + 10)
        let lenHi = UInt8(((n & 0xFC0) >> 6) + 10)
        var body: [UInt8] = [EQU, lenLo, lenHi, c1.asciiValue!, c2.asciiValue!]
        body.append(contentsOf: dataB)
        return [STX] + body + [crc(body), ETX]
    }

    /// fncCheckCmd. Devolve carga e se a verificacao confere.
    public static func parse(_ frame: [UInt8]) -> (payload: String, crcOK: Bool)? {
        guard frame.count >= 7, frame.first == STX, frame.last == ETX else { return nil }
        let body = Array(frame[1..<(frame.count - 2)])
        let crcOK = crc(body) == frame[frame.count - 2]
        let payload = String(bytes: frame[4..<(frame.count - 2)], encoding: .isoLatin1) ?? ""
        return (payload, crcOK)
    }

    /// SecurityCheck: soma de 32 palavras de 4 caracteres do campo 5, em hex.
    public static func securityCode(_ payload: String) -> String? {
        let fields = payload.split(separator: escChar, omittingEmptySubsequences: false)
        guard fields.count > 5 else { return nil }
        let key = Array(String(fields[5]).unicodeScalars)
        guard key.count >= 128 else { return nil }
        var total: UInt64 = 0
        for i in 0..<32 {
            var v = UInt64(key[i * 4].value & 0xFF)
            v |= UInt64(key[i * 4 + 1].value & 0xFF) << 8
            v |= UInt64(key[i * 4 + 2].value & 0xFF) << 16
            v |= UInt64((key[i * 4 + 3].value & 0xF) << 4) << 24
            total &+= v
        }
        return String(format: "%08x", UInt32(total & 0xFFFFFFFF))
    }

    /// Campos de uma carga, separados por ESC.
    public static func fields(_ payload: String) -> [String] {
        payload.split(separator: escChar, omittingEmptySubsequences: false).map(String.init)
    }
}
