import SwiftUI
import AppKit

/// Unificacao de pacientes de clinicas/balancas diferentes (dois bancos juntados num so).
///
/// Ideia: o InBody guarda cada paciente por USER_ID. Quando dois bancos entram no mesmo
/// acervo, o MESMO paciente aparece duas vezes (dois LOCAL_ID, mesmo USER_ID). Juntar e:
///   1. AUTOMATICO quando o USER_ID bate E nome/nascimento sao compativeis (o caso comum).
///   2. CONFERENCIA humana so quando o mesmo USER_ID aponta para pessoas diferentes
///      (o ID do InBody nasce da data de cadastro e PODE repetir entre clinicas).
///
/// Nome e a chave universal (funciona em qualquer pais); nascimento confirma. Documento
/// (CPF/etc.) fica para uma etapa seguinte como ancora forte por pais.

// MARK: - Normalizacao (funcoes puras, testaveis)

enum FusaoMatch {

    /// Tokens do nome sem acento, minusculos, so letras. "José C. Silva" -> ["jose","c","silva"].
    static func tokens(_ nome: String) -> [String] {
        nome.folding(options: [.diacriticInsensitive, .caseInsensitive],
                     locale: Locale(identifier: "pt_BR"))
            .split { !$0.isLetter }
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    /// Nascimento reduzido a 8 digitos aaaammdd. Aceita "1964/10/21" e "21.10.1964".
    /// "" quando ausente ou ilegivel (nao derruba a comparacao, so deixa de confirmar).
    static func nascimento(_ raw: String) -> String {
        let d = Array(raw.filter { $0.isNumber })
        guard d.count >= 8 else { return "" }
        let a = String(d[0..<4])
        if let ano = Int(a), (1900...2100).contains(ano) {      // ja vem aaaammdd
            return String(d[0..<8])
        }
        // veio ddmmaaaa: reordena
        let yyyy = String(d[4..<8]), mm = String(d[2..<4]), dd = String(d[0..<2])
        return Int(yyyy).map { (1900...2100).contains($0) ? yyyy + mm + dd : "" } ?? ""
    }

    /// Dois nomes sao a mesma pessoa? Primeiro e ultimo token compativeis (igual ou
    /// abreviatura: "s" casa "souza"), e os tokens do meio nao se contradizem.
    static func nomesCompativeis(_ a: String, _ b: String) -> Bool {
        let ta = tokens(a), tb = tokens(b)
        guard let pa = ta.first, let pb = tb.first,
              let ua = ta.last, let ub = tb.last else { return false }
        return tokenCasa(pa, pb) && tokenCasa(ua, ub)
    }

    /// Um token casa com o outro se sao iguais ou um e inicial/prefixo do outro.
    private static func tokenCasa(_ x: String, _ y: String) -> Bool {
        if x == y { return true }
        let (curto, longo) = x.count <= y.count ? (x, y) : (y, x)
        if curto.count == 1 { return longo.hasPrefix(curto) }      // "s" ~ "souza"
        return longo.hasPrefix(curto) && Double(curto.count) / Double(longo.count) >= 0.6
    }

    /// Mesma pessoa: nomes compativeis E nascimento igual (ou ausente em um dos lados).
    static func mesmaPessoa(_ a: Paciente, _ b: Paciente) -> Bool {
        guard nomesCompativeis(a.nome, b.nome) else { return false }
        let na = nascimento(a.nascimento), nb = nascimento(b.nascimento)
        if na.isEmpty || nb.isEmpty { return true }               // sem nascimento: nome decide
        return na == nb
    }
}

// MARK: - Modelos da revisao

/// Um par que precisa de olho humano: mesmo USER_ID, mas parecem pessoas diferentes.
struct ConflitoFusao: Identifiable {
    let id = UUID()
    let a: Paciente
    let b: Paciente
}

/// Resultado de varrer o acervo atras de duplicados.
struct RevisaoFusao {
    /// Grupos que fundem sozinhos: [manter, absorver...]. O primeiro e o que fica.
    var automaticos: [[Paciente]] = []
    /// Pares para conferir (mesmo ID, pessoas aparentemente diferentes).
    var conflitos: [ConflitoFusao] = []

    var totalAbsorvidos: Int { automaticos.reduce(0) { $0 + max(0, $1.count - 1) } }
}

// MARK: - Store: deteccao e fusao

extension Store {

    /// Varre os pacientes carregados e separa fusoes automaticas de conflitos.
    /// Agrupa por USER_ID; dentro do grupo, quem e "mesma pessoa" vira um cluster.
    func revisarFusao() -> RevisaoFusao {
        var r = RevisaoFusao()
        let grupos = Dictionary(grouping: pacientes) { $0.id }

        for (_, membros) in grupos where membros.count > 1 {
            // union-find: une quem e a mesma pessoa
            var pai = Array(0..<membros.count)
            func raiz(_ i: Int) -> Int { var i = i; while pai[i] != i { pai[i] = pai[pai[i]]; i = pai[i] }; return i }
            for i in 0..<membros.count {
                for j in (i+1)..<membros.count where FusaoMatch.mesmaPessoa(membros[i], membros[j]) {
                    pai[raiz(i)] = raiz(j)
                }
            }
            var clusters: [Int: [Paciente]] = [:]
            for i in membros.indices { clusters[raiz(i), default: []].append(membros[i]) }
            let listas = Array(clusters.values)

            for c in listas where c.count > 1 {
                r.automaticos.append(ordenarManterPrimeiro(c))
            }
            // mais de um cluster no MESMO id = pessoas diferentes com id colidido -> conferir
            if listas.count > 1 {
                let repres = listas.map { ordenarManterPrimeiro($0).first! }
                for i in 0..<repres.count {
                    for j in (i+1)..<repres.count {
                        r.conflitos.append(ConflitoFusao(a: repres[i], b: repres[j]))
                    }
                }
            }
        }
        return r
    }

    /// Ordena um cluster deixando em primeiro quem deve FICAR: mais exames, empate pelo
    /// cadastro mais antigo (LOCAL_ID menor).
    private func ordenarManterPrimeiro(_ c: [Paciente]) -> [Paciente] {
        c.sorted {
            if $0.exames.count != $1.exames.count { return $0.exames.count > $1.exames.count }
            return (Int($0.localId) ?? .max) < (Int($1.localId) ?? .max)
        }
    }

    /// Aplica todas as fusoes automaticas no banco e na memoria. Devolve quantos sumiram.
    @discardableResult
    func aplicarFusoesAutomaticas() -> Int {
        let auto = revisarFusao().automaticos
        var n = 0
        for grupo in auto {
            guard let manter = grupo.first else { continue }
            for absorver in grupo.dropFirst() { fundir(manter: manter, absorver: absorver); n += 1 }
        }
        return n
    }

    /// Funde `absorver` em `manter`: move exames/leituras no banco e junta em memoria.
    func fundir(manter: Paciente, absorver: Paciente) {
        guard manter.id != absorver.id || manter.localId != absorver.localId else { return }
        if let b = banco, !manter.localId.isEmpty, !absorver.localId.isEmpty {
            b.fundirUsuario(deLocalId: absorver.localId, paraLocalId: manter.localId)
        }
        guard let i = pacientes.firstIndex(where: { $0.chave == manter.chave }) else { return }
        // exames sem repetir data
        let datasAtuais = Set(pacientes[i].exames.map { $0.data })
        pacientes[i].exames.append(contentsOf: absorver.exames.filter { !datasAtuais.contains($0.data) })
        pacientes[i].exames.sort { $0.data > $1.data }
        pacientes[i].pressoes.append(contentsOf: absorver.pressoes)
        pacientes[i].glicoses.append(contentsOf: absorver.glicoses)
        // completa campos vazios do que ficou com o que veio
        if pacientes[i].celular.isEmpty { pacientes[i].celular = absorver.celular }
        if pacientes[i].email.isEmpty { pacientes[i].email = absorver.email }
        if pacientes[i].nascimento.isEmpty { pacientes[i].nascimento = absorver.nascimento }
        if pacientes[i].historico.isEmpty { pacientes[i].historico = absorver.historico }
        pacientes.removeAll { $0.chave == absorver.chave }
        if selecionado == absorver.id { selecionado = pacientes[i].id }
    }

    /// Resolve um conflito como "sao pessoas diferentes": da um USER_ID novo e unico ao
    /// `absorver`, quebrando a colisao para sempre. O cadastro e os exames ficam intactos.
    func manterSeparado(_ conf: ConflitoFusao) {
        guard let b = banco, !conf.b.localId.isEmpty else { return }
        let novo = b.novoUserIdUnico(base: conf.b.id)
        b.atualizarUsuario(["LOCAL_ID": conf.b.localId, "USER_ID": novo])
        if let i = pacientes.firstIndex(where: { $0.chave == conf.b.chave }) {
            var p = pacientes[i]; p.id = novo; pacientes[i] = p
        }
    }

    // MARK: - Fluxo da pasta na nuvem

    /// Envia o backup desta clinica para a pasta compartilhada da nuvem.
    func enviarBackupNuvem() -> String {
        CloudBackup.backupVinculado().erro ?? T("This clinic's backup was sent to the cloud folder.")
    }

    /// Le TODOS os backups .sqlite da pasta da nuvem, importa (remapeando IDs internos) e
    /// roda a fusao. Reune as duas clinicas num acervo unico. Devolve o aviso pra tela.
    func juntarBackupsNuvem() -> String {
        guard let pasta = CloudBackup.pastaVinculada else {
            return T("Link the cloud folder first.")
        }
        let dir = (pasta as NSString).appendingPathComponent("InBody Backups")
        let sqlites = ((try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? [])
            .filter { $0.hasSuffix(".sqlite") }.sorted()
        guard let b = banco else { return T("Database unavailable.") }
        guard !sqlites.isEmpty else { return T("No backup in the folder yet. Ask the other clinic to send theirs.") }
        var u = 0, e = 0
        for f in sqlites {
            let r = b.importarBackupSQLite((dir as NSString).appendingPathComponent(f))
            u += r.usuarios; e += r.exames
        }
        pacientes = b.carregarPacientes()
        let fus = aplicarFusoesAutomaticas()
        return "\(T("Merged")) \(u) \(T("record(s) and")) \(e) \(T("exam(s) from")) \(sqlites.count) \(T("backup(s).")) \(fus) \(T("joined by ID."))"
    }
}

// MARK: - Tela (estilo LookinBody: cabecalho marrom, caixas planas, botoes chapados)

/// Painel de unificacao (Configuracoes > Gerenciamento de dados). Ao abrir, aplica as
/// fusoes obvias por ID e lista so os conflitos que pedem decisao.
struct FusaoPacientesView: View {
    @EnvironmentObject var store: Store
    let onClose: () -> Void

    @State private var fundidosAuto = 0
    @State private var conflitos: [ConflitoFusao] = []
    @State private var carregou = false
    @State private var pastaNuvem = CloudBackup.pastaVinculada ?? ""
    @State private var avisoNuvem = ""

    var body: some View {
        VStack(spacing: 0) {
            // cabecalho marrom padrao das Configuracoes
            HStack {
                Text(T("Unificar pacientes de clínicas diferentes"))
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                Spacer()
                Button { onClose() } label: {
                    Image(systemName: "xmark").font(.system(size: 14)).foregroundStyle(.white)
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 16).padding(.vertical, 11).background(setupMarrom)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    secaoNuvem
                    resumoAutomatico
                    if conflitos.isEmpty {
                        Text(T("Nada para conferir. Tudo unificado."))
                            .font(.system(size: 13)).foregroundStyle(.secondary)
                    } else {
                        Text(T("Conferir (mesmo ID, parecem pessoas diferentes)"))
                            .font(.system(size: 14, weight: .bold))
                        ForEach(conflitos) { cartaoConflito($0) }
                    }
                }
                .padding(20).frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(red: 0.96, green: 0.96, blue: 0.97))
        }
        .frame(width: 760, height: 560)
        .background(Color.white).foregroundStyle(.black)
        .onAppear {
            guard !carregou else { return }
            carregou = true
            fundidosAuto = store.aplicarFusoesAutomaticas()
            conflitos = store.revisarFusao().conflitos
        }
    }

    // Seção da pasta da nuvem: cada clínica envia o seu backup para a MESMA pasta
    // compartilhada; "Juntar" lê os dois e funde. A pasta transporta, o app funde.
    private var secaoNuvem: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(T("Pasta da nuvem (iCloud, Google Drive, OneDrive)"))
                .font(.system(size: 14, weight: .bold))
            HStack(spacing: 8) {
                Text(pastaNuvem.isEmpty ? T("Nenhuma pasta vinculada") : pastaNuvem)
                    .font(.system(size: 12))
                    .foregroundStyle(pastaNuvem.isEmpty ? .secondary : .primary)
                    .lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 8)
                botao(T("Vincular pasta…"), largura: 130) { vincularPasta() }
            }
            HStack(spacing: 8) {
                botao(T("Enviar meu backup"), destaque: true) {
                    avisoNuvem = store.enviarBackupNuvem()
                }
                botao(T("Juntar backups da pasta"), destaque: true) { juntarNuvem() }
            }
            if !avisoNuvem.isEmpty {
                Text(avisoNuvem).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Text(T("Cada clínica envia o seu backup para esta mesma pasta. Depois, 'Juntar' lê os dois e unifica os pacientes."))
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .padding(12).background(Color.white)
        .overlay(Rectangle().stroke(Color.gray.opacity(0.3)))
    }

    private func vincularPasta() {
        let painel = NSOpenPanel()
        painel.canChooseDirectories = true
        painel.canChooseFiles = false
        painel.allowsMultipleSelection = false
        painel.prompt = T("Vincular")
        painel.message = T("Escolha a pasta da sua nuvem (a mesma nas duas clínicas).")
        if painel.runModal() == .OK, let url = painel.url {
            CloudBackup.pastaVinculada = url.path
            pastaNuvem = url.path
            avisoNuvem = T("Pasta vinculada.")
        }
    }

    private func juntarNuvem() {
        avisoNuvem = store.juntarBackupsNuvem()
        fundidosAuto = 0
        conflitos = store.revisarFusao().conflitos
    }

    private var resumoAutomatico: some View {
        HStack(spacing: 8) {
            Image(systemName: fundidosAuto > 0 ? "checkmark.circle" : "info.circle")
                .font(.system(size: 13)).foregroundStyle(fundidosAuto > 0 ? Color.okc : .secondary)
            Text(fundidosAuto > 0
                 ? "\(fundidosAuto) \(T("paciente(s) unidos automaticamente pelo ID."))"
                 : T("Nenhum duplicado óbvio pelo ID."))
                .font(.system(size: 13))
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(Color.gray.opacity(0.10))
        .overlay(Rectangle().stroke(Color.gray.opacity(0.2)))
    }

    // Cartao de conferencia: dois registros lado a lado + a decisao (caixas planas).
    private func cartaoConflito(_ c: ConflitoFusao) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(T("ID")) \(c.a.id)").font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(T("Mesmo ID nos dois")).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            HStack(spacing: 0) {
                colunaPaciente(c.a, rotulo: T("Registro A"))
                Rectangle().fill(Color.gray.opacity(0.2)).frame(width: 1)
                colunaPaciente(c.b, rotulo: T("Registro B"))
            }
            .overlay(Rectangle().stroke(Color.gray.opacity(0.25)))
            linhasComparacao(c)
            HStack(spacing: 8) {
                botao(T("É a mesma pessoa, unir"), destaque: true) { fundirConflito(c) }
                botao(T("São diferentes, manter separados")) { separarConflito(c) }
            }
        }
        .padding(12)
        .background(Color.white)
        .overlay(Rectangle().stroke(Color.gray.opacity(0.3)))
    }

    private func colunaPaciente(_ p: Paciente, rotulo: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(rotulo).font(.system(size: 11)).foregroundStyle(.secondary)
            Text(p.nome).font(.system(size: 14, weight: .semibold)).lineLimit(1)
            Text("\(T("Nasc.")) \(p.nascimento.isEmpty ? "—" : dataBR(p.nascimento))")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            Text(p.celular.isEmpty ? T("sem telefone") : p.celular)
                .font(.system(size: 12)).foregroundStyle(.secondary)
            Text("\(p.exames.count) \(T("exame(s)"))").font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10).background(Color.white)
    }

    private func linhasComparacao(_ c: ConflitoFusao) -> some View {
        VStack(spacing: 0) {
            linhaCmp(T("Nome"), FusaoMatch.nomesCompativeis(c.a.nome, c.b.nome))
            Rectangle().fill(Color.gray.opacity(0.15)).frame(height: 1)
            linhaCmp(T("Nascimento"), nascimentoIgual(c.a, c.b))
        }
        .overlay(Rectangle().stroke(Color.gray.opacity(0.2)))
    }

    private func linhaCmp(_ rotulo: String, _ ok: Bool) -> some View {
        HStack {
            Text(rotulo).font(.system(size: 12)).foregroundStyle(.secondary)
            Spacer()
            Text(ok ? T("Compatível") : T("Divergente"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ok ? Color.okc : Color.high)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
    }

    /// Botao chapado no estilo LookinBody (retangulo branco, borda fina). Sem `largura`
    /// ocupa o espaco disponivel; com `largura` fica com tamanho fixo.
    private func botao(_ t: String, destaque: Bool = false, largura: CGFloat? = nil,
                       _ acao: @escaping () -> Void) -> some View {
        Button(action: acao) {
            Text(T(t)).font(.system(size: 12, weight: destaque ? .semibold : .regular))
                .foregroundStyle(.black).lineLimit(1)
                .frame(maxWidth: largura == nil ? .infinity : nil).frame(width: largura, height: 30)
                .background(RoundedRectangle(cornerRadius: 3).fill(destaque ? Color.gray.opacity(0.14) : Color.white))
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.gray.opacity(destaque ? 0.55 : 0.4)))
        }.buttonStyle(.plain)
    }

    private func nascimentoIgual(_ a: Paciente, _ b: Paciente) -> Bool {
        let na = FusaoMatch.nascimento(a.nascimento), nb = FusaoMatch.nascimento(b.nascimento)
        return !na.isEmpty && na == nb
    }

    private func fundirConflito(_ c: ConflitoFusao) {
        let manter = c.a.exames.count >= c.b.exames.count ? c.a : c.b
        let absorver = manter.chave == c.a.chave ? c.b : c.a
        store.fundir(manter: manter, absorver: absorver)
        conflitos.removeAll { $0.id == c.id }
    }

    private func separarConflito(_ c: ConflitoFusao) {
        store.manterSeparado(c)
        conflitos.removeAll { $0.id == c.id }
    }
}
