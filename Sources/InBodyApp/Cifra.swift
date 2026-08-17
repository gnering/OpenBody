import Foundation
import CommonCrypto

/// Decifra os campos de cadastro que o LookinBody grava cifrados (contrato 3):
/// GENDER, TEL_HOME, TEL_HP, E_MAIL. Algoritmo extraido do ClsAES256Cipher original:
/// AES-256-CBC, IV = 16 zeros, PKCS7, chave = UTF8 de CifraChave.fieldKey (32 bytes).
/// Texto cifrado vem em Base64. O KEY vem de tools/extrai_chave.sh (regra 4).
enum Cifra {

    /// Devolve o texto claro. Se `s` nao for um Base64 decifravel com a chave, devolve `s`
    /// como veio (bancos sem FIELD_ENCRYPTION guardam texto puro — contrato: tratar ambos).
    static func claro(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard t.count >= 24, t.count % 4 == 0,
              let ct = Data(base64Encoded: t),
              ct.count % 16 == 0, !ct.isEmpty else { return s }
        guard let aberto = decifrar(ct) else { return s }
        return aberto
    }

    private static func decifrar(_ ct: Data) -> String? {
        let key = Array(CifraChave.fieldKey.utf8)         // 32 bytes
        guard key.count == kCCKeySizeAES256 else { return nil }
        let iv = [UInt8](repeating: 0, count: kCCBlockSizeAES128)
        var out = [UInt8](repeating: 0, count: ct.count + kCCBlockSizeAES128)
        var movidos = 0
        let status = ct.withUnsafeBytes { ctPtr in
            CCCrypt(CCOperation(kCCDecrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionPKCS7Padding),
                    key, key.count, iv,
                    ctPtr.baseAddress, ct.count,
                    &out, out.count, &movidos)
        }
        guard status == kCCSuccess else { return nil }
        return String(bytes: out.prefix(movidos), encoding: .utf8)
    }
}
