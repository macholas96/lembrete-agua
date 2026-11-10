import Foundation
import AppKit
import Combine

// MARK: - Caminhos e JSON

enum Caminhos {
    static let home = FileManager.default.homeDirectoryForCurrentUser
    static let dados = home.appendingPathComponent("Library/Application Support/LembreteAgua", isDirectory: true)
    static let regras = dados.appendingPathComponent("regras.json")
    static let prefs = dados.appendingPathComponent("preferencias.json")
    static let estado = dados.appendingPathComponent("estado.json")
    static let historico = dados.appendingPathComponent("historico.json")
    static let testar = dados.appendingPathComponent("testar")
}

enum JSON {
    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    /// Carrega mesclando com os valores padrão: campos novos (de atualizações futuras) não quebram o arquivo antigo.
    static func carregar<T: Codable>(_ url: URL, padrao: T) -> T {
        guard let dados = try? Data(contentsOf: url) else { return padrao }
        if let base = (try? JSONSerialization.jsonObject(with: encoder.encode(padrao))) as? [String: Any],
           let salvo = (try? JSONSerialization.jsonObject(with: dados)) as? [String: Any] {
            let mesclado = base.merging(salvo) { _, novo in novo }
            if let d = try? JSONSerialization.data(withJSONObject: mesclado),
               let v = try? decoder.decode(T.self, from: d) {
                return v
            }
        }
        if let v = try? decoder.decode(T.self, from: dados) { return v }
        // Arquivo ilegível: guarda uma cópia antes de recomeçar.
        let bak = url.appendingPathExtension("bak")
        try? FileManager.default.removeItem(at: bak)
        try? FileManager.default.copyItem(at: url, to: bak)
        return padrao
    }

    static func gravar<T: Encodable>(_ valor: T, em url: URL) {
        try? FileManager.default.createDirectory(at: Caminhos.dados, withIntermediateDirectories: true)
        if let d = try? encoder.encode(valor) { try? d.write(to: url, options: .atomic) }
    }
}

enum Formatos {
    static let hora: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
    static let diaCurto: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "dd/MM"
        return f
    }()
    static let csv: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()
    static let numero: NumberFormatter = {
        let n = NumberFormatter()
        n.numberStyle = .decimal
        n.locale = Locale(identifier: "pt_BR")
        return n
    }()
}

let calendario = Calendar.current

extension Date {
    var minutosDoDia: Int {
        let c = calendario.dateComponents([.hour, .minute], from: self)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
    var inicioDoDia: Date { calendario.startOfDay(for: self) }
}

func horaDoBoot() -> Double {
    var tv = timeval()
    var tamanho = MemoryLayout<timeval>.size
    sysctlbyname("kern.boottime", &tv, &tamanho, nil, 0)
    return Double(tv.tv_sec)
}

// MARK: - Regras (o que afeta o rigor: afrouxar só vale amanhã)

struct Regras: Codable, Equatable {
    var inicioMin = 9 * 60
    var fimMin = 19 * 60
    var dias: [Int] = [2, 3, 4, 5, 6]          // Calendar.weekday: 1 = domingo … 7 = sábado
    var intervaloMin = 45
    var metaML = 2500
    var pausaAlmoco = false
    var almocoInicioMin = 12 * 60
    var almocoFimMin = 13 * 60
    var pararAoBaterMeta = false
    var segundosBebendo = 2.5
    var exigirCopo = true
    var adiarEmChamadas = true
    var adiarMaxMin = 0                // 0 = sem limite: nunca interrompe uma chamada
    var usarMicrofone = true           // microfone em uso também conta como chamada

    /// true se `self` for menos rígida que `a` em qualquer ponto.
    func maisFrouxa(que a: Regras) -> Bool {
        if inicioMin > a.inicioMin || fimMin < a.fimMin { return true }
        if !Set(dias).isSuperset(of: Set(a.dias)) { return true }
        if intervaloMin > a.intervaloMin { return true }
        if metaML < a.metaML { return true }
        if pausaAlmoco && (!a.pausaAlmoco || almocoInicioMin < a.almocoInicioMin || almocoFimMin > a.almocoFimMin) { return true }
        if pararAoBaterMeta && !a.pararAoBaterMeta { return true }
        if segundosBebendo < a.segundosBebendo { return true }
        if !exigirCopo && a.exigirCopo { return true }
        let meuMax = adiarMaxMin == 0 ? Int.max : adiarMaxMin
        let maxA = a.adiarMaxMin == 0 ? Int.max : a.adiarMaxMin
        if adiarEmChamadas && (!a.adiarEmChamadas || meuMax > maxA || (usarMicrofone && !a.usarMicrofone)) { return true }
        return false
    }
}

// MARK: - Preferências (visual/conforto: valem na hora)

struct Copo: Codable, Equatable, Identifiable, Hashable {
    var id = UUID()
    var nome: String
    var ml: Int
    var icone: String          // desenho: copo, caneca, garrafa… ou modelos (quencher, owala, pacco…)
    var cor: String = ""       // cor do produto (hex), para garrafas de marca
    var corTampa: String = ""
}

extension Copo {
    /// Tolerante: arquivos de versões antigas (sem cor) continuam abrindo.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        nome = (try? c.decode(String.self, forKey: .nome)) ?? "Copo"
        ml = (try? c.decode(Int.self, forKey: .ml)) ?? 250
        icone = (try? c.decode(String.self, forKey: .icone)) ?? "copo"
        cor = (try? c.decode(String.self, forKey: .cor)) ?? ""
        corTampa = (try? c.decode(String.self, forKey: .corTampa)) ?? ""
    }
}

struct Preferencias: Codable, Equatable {
    var nome = ""
    var unidade = "ml"                 // ml | oz
    var copos: [Copo] = [
        Copo(nome: "Copo pequeno", ml: 150, icone: "copoPequeno"),
        Copo(nome: "Copo", ml: 250, icone: "copo"),
        Copo(nome: "Caneca", ml: 350, icone: "caneca"),
        Copo(nome: "Garrafa", ml: 500, icone: "garrafa"),
    ]
    var copoPadrao = 1
    var somAtivo = true
    var som = "Glass"
    var volume = 0.8
    var preAviso = true
    var preAvisoSeg = 60
    var tema = "oceano"                // oceano | lagoa | lavanda | noite | por-do-sol
    var opacidade = 0.62
    var animacoes = true
    var frases = true
    var widgetAtivo = true
    var widgetPosicao = "infDir"       // supEsq | supDir | infEsq | infDir
    var widgetTamanho = "medio"        // pequeno | medio | grande
    var widgetEstilo = "escuro"        // escuro | claro
    var barraMenu = "ml"               // ml | pct | icone
    var verificarAtualizacoes = true   // só verifica e avisa; instalar é sempre um clique da pessoa
}

// MARK: - Estado e histórico

struct Estado: Codable {
    var proximo = Date()
    var instaladoEm = Date()
    var boot: Double = 0
    var foraDoHorario = true
    var pendente: Regras? = nil
    var pendenteAPartirDe: Date? = nil
    var conquistas: [String: Date] = [:]
    var ultimaVerificacao: Date? = nil
    var ultimaVersaoVista = ""
    var versaoAvisada = ""
    var onboardingConcluido = false
}

struct Registro: Codable, Identifiable {
    var id = UUID()
    var data: Date
    var ml: Int
    var voluntario: Bool
}

struct Pulo: Codable {
    var data: Date
    var motivo: String
}

struct Historico: Codable {
    var registros: [Registro] = []
    var pulos: [Pulo] = []
}

// MARK: - Gamificação

struct Conquista: Identifiable {
    let id: String
    let emoji: String
    let titulo: String
    let descricao: String
}

enum Gamificacao {
    static let conquistas: [Conquista] = [
        Conquista(id: "primeiro", emoji: "💧", titulo: "Primeiro gole", descricao: "Registrou o primeiro copo."),
        Conquista(id: "meta1", emoji: "🎯", titulo: "Na mosca", descricao: "Bateu a meta diária pela primeira vez."),
        Conquista(id: "seq3", emoji: "🔥", titulo: "Pegando ritmo", descricao: "3 dias seguidos batendo a meta."),
        Conquista(id: "seq7", emoji: "🏅", titulo: "Uma semana inteira", descricao: "7 dias seguidos batendo a meta."),
        Conquista(id: "seq14", emoji: "🥈", titulo: "Duas semanas", descricao: "14 dias seguidos batendo a meta."),
        Conquista(id: "seq30", emoji: "🥇", titulo: "Um mês hidratado", descricao: "30 dias seguidos batendo a meta."),
        Conquista(id: "seq100", emoji: "👑", titulo: "Lenda da água", descricao: "100 dias seguidos batendo a meta."),
        Conquista(id: "l10", emoji: "🪣", titulo: "10 litros", descricao: "10 litros no total."),
        Conquista(id: "l50", emoji: "🛁", titulo: "50 litros", descricao: "Uma banheira de água."),
        Conquista(id: "l100", emoji: "🛢️", titulo: "100 litros", descricao: "100 litros no total."),
        Conquista(id: "l500", emoji: "🌊", titulo: "500 litros", descricao: "Meio metro cúbico de água!"),
        Conquista(id: "cedo", emoji: "🌅", titulo: "Madrugador", descricao: "Bebeu água antes das 8h."),
        Conquista(id: "dez", emoji: "🔟", titulo: "Dia dos 10 copos", descricao: "10 copos num único dia."),
        Conquista(id: "dobro", emoji: "🚀", titulo: "Dobrou a meta", descricao: "Bebeu o dobro da meta num dia."),
        Conquista(id: "semPulo", emoji: "🛡️", titulo: "Sem atalhos", descricao: "7 dias sem desligar o Mac para pular."),
    ]

    static let niveis: [(nome: String, litros: Double)] = [
        ("Gota", 0), ("Poça", 10), ("Riacho", 30), ("Lago", 75),
        ("Rio", 150), ("Cachoeira", 300), ("Mar", 600), ("Oceano", 1000),
    ]

    static let frases = [
        "Seu cérebro é ~75% água. Dá um gás nele.",
        "Cansaço no meio da tarde? Muitas vezes é sede.",
        "Um copo agora vale mais que três de uma vez à noite.",
        "Pele, foco e humor agradecem.",
        "Dor de cabeça leve costuma ser desidratação.",
        "Pequenos goles, grandes hábitos.",
        "Hidratação é o upgrade mais barato que existe.",
        "Seu eu do fim do dia vai te agradecer.",
    ]
}

// MARK: - Store

@MainActor
final class Store: ObservableObject {
    @Published var regras: Regras { didSet { JSON.gravar(regras, em: Caminhos.regras) } }
    @Published var prefs: Preferencias { didSet { JSON.gravar(prefs, em: Caminhos.prefs); aoMudarPrefs?() } }
    @Published var estado: Estado { didSet { JSON.gravar(estado, em: Caminhos.estado) } }
    @Published var historico: Historico { didSet { JSON.gravar(historico, em: Caminhos.historico) } }
    var aoMudarPrefs: (@MainActor () -> Void)?
    let primeiraVez: Bool
    private(set) var puloNoBoot = false

    init() {
        primeiraVez = !FileManager.default.fileExists(atPath: Caminhos.regras.path)
        var r = JSON.carregar(Caminhos.regras, padrao: Regras())
        var p = JSON.carregar(Caminhos.prefs, padrao: Preferencias())
        var e = JSON.carregar(Caminhos.estado, padrao: Estado())
        var h = JSON.carregar(Caminhos.historico, padrao: Historico())

        if primeiraVez { e.instaladoEm = Date(); e.foraDoHorario = true }
        if r.dias.isEmpty { r.dias = [2, 3, 4, 5, 6] }
        if p.copos.isEmpty { p.copos = Preferencias().copos }

        // Desligar/reiniciar é o único "atalho": se o lembrete estava vencido, conta como pulo.
        let boot = horaDoBoot()
        if e.boot != 0, abs(e.boot - boot) > 5, !e.foraDoHorario, e.proximo <= Date() {
            h.pulos.append(Pulo(data: Date(), motivo: "Desligou/reiniciou o Mac com o lembrete na tela"))
            e.proximo = Date().addingTimeInterval(TimeInterval(r.intervaloMin * 60))
            puloNoBoot = true
        }
        e.boot = boot

        regras = r; prefs = p; estado = e; historico = h
        JSON.gravar(r, em: Caminhos.regras)
        JSON.gravar(p, em: Caminhos.prefs)
        JSON.gravar(e, em: Caminhos.estado)
        JSON.gravar(h, em: Caminhos.historico)
    }

    /// Relê tudo do disco (usado quando outra instância do app acabou de salvar).
    func recarregar() {
        regras = JSON.carregar(Caminhos.regras, padrao: Regras())
        prefs = JSON.carregar(Caminhos.prefs, padrao: Preferencias())
        estado = JSON.carregar(Caminhos.estado, padrao: Estado())
        historico = JSON.carregar(Caminhos.historico, padrao: Historico())
    }

    // MARK: Regras e agenda

    func estaAtivo(_ d: Date = Date()) -> Bool {
        guard regras.dias.contains(calendario.component(.weekday, from: d)) else { return false }
        let m = d.minutosDoDia
        guard m >= regras.inicioMin && m < regras.fimMin else { return false }
        if regras.pausaAlmoco && m >= regras.almocoInicioMin && m < regras.almocoFimMin { return false }
        if regras.pararAoBaterMeta && hojeML >= regras.metaML { return false }
        return true
    }

    var diaDaInstalacao: Bool { calendario.isDate(estado.instaladoEm, inSameDayAs: Date()) }

    @discardableResult
    func aplicar(_ novas: Regras) -> String {
        if novas == regras {
            estado.pendente = nil; estado.pendenteAPartirDe = nil
            return "Nada mudou."
        }
        if novas.maisFrouxa(que: regras) && !diaDaInstalacao {
            estado.pendente = novas
            estado.pendenteAPartirDe = calendario.date(byAdding: .day, value: 1, to: Date().inicioDoDia)
            return "Algumas mudanças afrouxam as regras, então valem a partir de amanhã."
        }
        regras = novas
        estado.pendente = nil; estado.pendenteAPartirDe = nil
        return "Pronto, mudanças aplicadas."
    }

    func aplicarPendentes() {
        if let p = estado.pendente, let d = estado.pendenteAPartirDe, Date() >= d {
            regras = p
            estado.pendente = nil; estado.pendenteAPartirDe = nil
        }
    }

    // MARK: Números

    var totaisPorDia: [Date: Int] {
        var t: [Date: Int] = [:]
        for r in historico.registros { t[r.data.inicioDoDia, default: 0] += r.ml }
        return t
    }

    func ml(em dia: Date) -> Int {
        historico.registros.filter { calendario.isDate($0.data, inSameDayAs: dia) }.reduce(0) { $0 + $1.ml }
    }

    var hojeML: Int { ml(em: Date()) }
    var coposHoje: Int { historico.registros.filter { calendario.isDateInToday($0.data) }.count }
    var ultimoGole: Date? { historico.registros.last?.data }
    var totalML: Int { historico.registros.reduce(0) { $0 + $1.ml } }
    var pulosHoje: Int { historico.pulos.filter { calendario.isDateInToday($0.data) }.count }

    func sequenciaAtual() -> Int {
        let t = totaisPorDia
        guard let primeiro = historico.registros.first?.data.inicioDoDia else { return 0 }
        var dia = Date().inicioDoDia
        var n = 0
        for _ in 0..<2000 {
            if dia < primeiro { break }
            let ativo = regras.dias.contains(calendario.component(.weekday, from: dia))
            let bateu = (t[dia] ?? 0) >= regras.metaML
            if bateu { n += 1 }
            else if ativo && !calendario.isDateInToday(dia) { break }
            guard let anterior = calendario.date(byAdding: .day, value: -1, to: dia) else { break }
            dia = anterior
        }
        return n
    }

    func recorde() -> Int {
        let t = totaisPorDia
        guard var dia = historico.registros.first?.data.inicioDoDia else { return 0 }
        let hoje = Date().inicioDoDia
        var atual = 0, melhor = 0
        while dia <= hoje {
            let ativo = regras.dias.contains(calendario.component(.weekday, from: dia))
            if (t[dia] ?? 0) >= regras.metaML { atual += 1; melhor = max(melhor, atual) }
            else if ativo && dia != hoje { atual = 0 }
            guard let prox = calendario.date(byAdding: .day, value: 1, to: dia) else { break }
            dia = prox
        }
        return melhor
    }

    struct InfoNivel {
        let indice: Int
        let nome: String
        let proximo: String?
        let progresso: Double
        let faltaLitros: Double
    }

    func nivel() -> InfoNivel {
        let litros = Double(totalML) / 1000
        let n = Gamificacao.niveis
        var i = 0
        while i + 1 < n.count && litros >= n[i + 1].litros { i += 1 }
        if i + 1 < n.count {
            let ini = n[i].litros, fim = n[i + 1].litros
            return InfoNivel(indice: i, nome: n[i].nome, proximo: n[i + 1].nome,
                             progresso: (litros - ini) / (fim - ini), faltaLitros: fim - litros)
        }
        return InfoNivel(indice: i, nome: n[i].nome, proximo: nil, progresso: 1, faltaLitros: 0)
    }

    // MARK: Registro e conquistas

    func registrar(ml: Int, voluntario: Bool) -> [Conquista] {
        historico.registros.append(Registro(data: Date(), ml: ml, voluntario: voluntario))
        estado.proximo = Date().addingTimeInterval(TimeInterval(regras.intervaloMin * 60))
        return avaliarConquistas()
    }

    private func conquistou(_ id: String) -> Bool {
        let total = Double(totalML) / 1000
        let seq = sequenciaAtual()
        switch id {
        case "primeiro": return !historico.registros.isEmpty
        case "meta1": return totaisPorDia.values.contains { $0 >= regras.metaML }
        case "seq3": return seq >= 3
        case "seq7": return seq >= 7
        case "seq14": return seq >= 14
        case "seq30": return seq >= 30
        case "seq100": return seq >= 100
        case "l10": return total >= 10
        case "l50": return total >= 50
        case "l100": return total >= 100
        case "l500": return total >= 500
        case "cedo": return historico.registros.contains { $0.data.minutosDoDia < 8 * 60 }
        case "dez": return coposHoje >= 10
        case "dobro": return hojeML >= regras.metaML * 2
        case "semPulo":
            let seteDias = Date().addingTimeInterval(-7 * 86400)
            return estado.instaladoEm < seteDias && !historico.pulos.contains { $0.data > seteDias }
        default: return false
        }
    }

    func avaliarConquistas() -> [Conquista] {
        var novas: [Conquista] = []
        for c in Gamificacao.conquistas where estado.conquistas[c.id] == nil && conquistou(c.id) {
            estado.conquistas[c.id] = Date()
            novas.append(c)
        }
        return novas
    }

    // MARK: Formatação

    func fmt(_ ml: Int, unidade: Bool = true) -> String {
        if prefs.unidade == "oz" {
            return String(format: "%.0f", Double(ml) / 29.5735) + (unidade ? " oz" : "")
        }
        let n = Formatos.numero.string(from: NSNumber(value: ml)) ?? "\(ml)"
        return n + (unidade ? " ml" : "")
    }

    func fmtCurto(_ ml: Int) -> String {
        if prefs.unidade == "oz" { return String(format: "%.0f oz", Double(ml) / 29.5735) }
        if ml < 1000 { return "\(ml) ml" }
        return String(format: "%.1f L", Double(ml) / 1000).replacingOccurrences(of: ".", with: ",")
    }

    var nomeOuVazio: String {
        let n = prefs.nome.trimmingCharacters(in: .whitespaces)
        return n.isEmpty ? "" : ", \(n)"
    }

    func exportarCSV() -> String {
        var linhas = ["data,ml,tipo"]
        for r in historico.registros {
            linhas.append("\(Formatos.csv.string(from: r.data)),\(r.ml),\(r.voluntario ? "voluntario" : "lembrete")")
        }
        for p in historico.pulos {
            linhas.append("\(Formatos.csv.string(from: p.data)),0,pulo")
        }
        return linhas.joined(separator: "\n") + "\n"
    }
}
