import SwiftUI

// MARK: - Catálogo (modelos pesquisados nas lojas e sites das marcas)

struct ModeloGarrafa: Identifiable {
    var id: String { marca + nome }
    let marca: String
    let nome: String
    let ml: Int
    let desenho: String
    let cor: String
    let corTampa: String
}

struct InfoMarca: Identifiable {
    var id: String { nome }
    let nome: String
    let descricao: String
    let exemplo: ModeloGarrafa
}

enum Catalogo {
    static let garrafas: [ModeloGarrafa] = [
        // Stanley
        ModeloGarrafa(marca: "Stanley", nome: "Quencher H2.0 1,18 L", ml: 1180, desenho: "quencher", cor: "#EBB8C3", corTampa: "#F3CDD5"),
        ModeloGarrafa(marca: "Stanley", nome: "Quencher H2.0 887 ml", ml: 887, desenho: "quencher", cor: "#A9C7B6", corTampa: "#C2D9CB"),
        ModeloGarrafa(marca: "Stanley", nome: "Quencher 591 ml", ml: 591, desenho: "quencher", cor: "#EFE3CC", corTampa: "#E2D2B4"),
        ModeloGarrafa(marca: "Stanley", nome: "Quencher 414 ml", ml: 414, desenho: "quencher", cor: "#C9D9F0", corTampa: "#B3C7E6"),
        ModeloGarrafa(marca: "Stanley", nome: "Classic Hydration 750 ml", ml: 750, desenho: "hydration", cor: "#1F2124", corTampa: "#3B3E44"),
        ModeloGarrafa(marca: "Stanley", nome: "Legendary Classic 750 ml", ml: 750, desenho: "classica", cor: "#3E6B48", corTampa: "#2F5537"),
        ModeloGarrafa(marca: "Stanley", nome: "Legendary Classic 1 L", ml: 1000, desenho: "classica", cor: "#3E6B48", corTampa: "#2F5537"),
        ModeloGarrafa(marca: "Stanley", nome: "Quick Flip 710 ml", ml: 710, desenho: "quickflip", cor: "#5E7C99", corTampa: "#2F3A46"),
        ModeloGarrafa(marca: "Stanley", nome: "Go Quick Flip 1,06 L", ml: 1060, desenho: "quickflip", cor: "#2E4A3B", corTampa: "#1E2B24"),
        ModeloGarrafa(marca: "Stanley", nome: "IceFlow Flip Straw 887 ml", ml: 887, desenho: "iceflow", cor: "#33404F", corTampa: "#1F2733"),
        ModeloGarrafa(marca: "Stanley", nome: "IceFlow Flip Straw 650 ml", ml: 650, desenho: "iceflow", cor: "#D9C7E8", corTampa: "#9C86B5"),
        ModeloGarrafa(marca: "Stanley", nome: "AeroLight Fast Flow 710 ml", ml: 710, desenho: "aerolight", cor: "#6C8EBF", corTampa: "#3E5F8F"),
        ModeloGarrafa(marca: "Stanley", nome: "AeroLight Transit 591 ml", ml: 591, desenho: "aerolight", cor: "#E6DDCC", corTampa: "#8C7B63"),
        ModeloGarrafa(marca: "Stanley", nome: "AeroLight Flip Straw 473 ml", ml: 473, desenho: "aerolight", cor: "#F2B5A0", corTampa: "#C9735A"),
        // Owala
        ModeloGarrafa(marca: "Owala", nome: "FreeSip 562 ml (19 oz)", ml: 562, desenho: "owala", cor: "#F4D35E", corTampa: "#3D7DD8"),
        ModeloGarrafa(marca: "Owala", nome: "FreeSip 710 ml (24 oz)", ml: 710, desenho: "owala", cor: "#4FB7B3", corTampa: "#F2A1B8"),
        ModeloGarrafa(marca: "Owala", nome: "FreeSip 946 ml (32 oz)", ml: 946, desenho: "owala", cor: "#1E2F4D", corTampa: "#F4C542"),
        ModeloGarrafa(marca: "Owala", nome: "FreeSip 1,18 L (40 oz)", ml: 1180, desenho: "owala", cor: "#7A5BC7", corTampa: "#B9F0D8"),
        ModeloGarrafa(marca: "Owala", nome: "FreeSip Twist 532 ml (18 oz)", ml: 532, desenho: "twist", cor: "#F6D3C4", corTampa: "#E7836B"),
        ModeloGarrafa(marca: "Owala", nome: "FreeSip Twist 710 ml (24 oz)", ml: 710, desenho: "twist", cor: "#CFE3F7", corTampa: "#7FA7D6"),
        ModeloGarrafa(marca: "Owala", nome: "SmoothSip Slider 355 ml", ml: 355, desenho: "tumbler", cor: "#E9A5C0", corTampa: "#B7517E"),
        // Hydro Flask
        ModeloGarrafa(marca: "Hydro Flask", nome: "Wide Mouth 532 ml (18 oz)", ml: 532, desenho: "hydro", cor: "#7BC6A4", corTampa: "#202225"),
        ModeloGarrafa(marca: "Hydro Flask", nome: "Wide Mouth 710 ml (24 oz)", ml: 710, desenho: "hydro", cor: "#F2C14E", corTampa: "#202225"),
        ModeloGarrafa(marca: "Hydro Flask", nome: "Wide Mouth 946 ml (32 oz)", ml: 946, desenho: "hydro", cor: "#2C6E9B", corTampa: "#202225"),
        ModeloGarrafa(marca: "Hydro Flask", nome: "Wide Mouth 1,18 L (40 oz)", ml: 1180, desenho: "hydro", cor: "#4A4E57", corTampa: "#202225"),
        ModeloGarrafa(marca: "Hydro Flask", nome: "Standard Mouth 621 ml (21 oz)", ml: 621, desenho: "hydro", cor: "#E86F5C", corTampa: "#202225"),
        // Pacco
        ModeloGarrafa(marca: "Pacco", nome: "Hydra V2 500 ml", ml: 500, desenho: "pacco", cor: "#2B2B2E", corTampa: "#45454A"),
        ModeloGarrafa(marca: "Pacco", nome: "Hydra V3 500 ml (cerâmica)", ml: 500, desenho: "pacco", cor: "#E7E3DA", corTampa: "#B9B2A4"),
        ModeloGarrafa(marca: "Pacco", nome: "Hydra V2 1,2 L", ml: 1200, desenho: "pacco", cor: "#3C4A3E", corTampa: "#2B332C"),
        ModeloGarrafa(marca: "Pacco", nome: "Vyta 1,2 L", ml: 1200, desenho: "pacco", cor: "#9DB8D9", corTampa: "#5E7EA8"),
        // Contigo
        ModeloGarrafa(marca: "Contigo", nome: "Byron Snapseal 591 ml", ml: 591, desenho: "tumbler", cor: "#3D4F63", corTampa: "#1E2833"),
    ]

    static func primeiro(_ nome: String) -> ModeloGarrafa { garrafas.first { $0.nome == nome } ?? garrafas[0] }

    static let marcas: [InfoMarca] = [
        InfoMarca(nome: "Stanley", descricao: "Quencher, Classic, Quick Flip, IceFlow, AeroLight", exemplo: primeiro("Classic Hydration 750 ml")),
        InfoMarca(nome: "Owala", descricao: "FreeSip, Twist, SmoothSip", exemplo: primeiro("FreeSip 710 ml (24 oz)")),
        InfoMarca(nome: "Hydro Flask", descricao: "Wide e Standard Mouth", exemplo: primeiro("Wide Mouth 946 ml (32 oz)")),
        InfoMarca(nome: "Pacco", descricao: "Hydra e Vyta", exemplo: primeiro("Hydra V2 500 ml")),
        InfoMarca(nome: "Contigo", descricao: "Byron", exemplo: primeiro("Byron Snapseal 591 ml")),
    ]

    /// Para quem não sabe o modelo: escolhe o formato e o tamanho (vem escrito embaixo da garrafa).
    static let formatos: [(desenho: String, nome: String, cor: String, corTampa: String)] = [
        ("hydration", "Térmica com alça lateral", "#1F2124", "#3B3E44"),
        ("pacco", "Térmica com argola", "#2F3640", "#4A5260"),
        ("quickflip", "Garrafa de tampa flip", "#5E7C99", "#2F3A46"),
        ("tumbler", "Copo térmico com tampa", "#C9D6E8", "#7C93B5"),
        ("iceflow", "Garrafa com alça", "#5B6B7C", "#2E3946"),
        ("owala", "Garrafa esportiva", "#4FB7B3", "#2E7D7A"),
        ("quencher", "Copão com canudo", "#C9D6E8", "#AFC0D8"),
        ("garrafa", "Garrafa de plástico", "", ""),
        ("copo", "Copo", "", ""),
        ("caneca", "Caneca ou xícara", "", ""),
    ]

    static let tamanhos = [200, 250, 300, 350, 400, 473, 500, 591, 600, 710, 750, 800, 887, 946, 1000, 1200, 1500, 2000]

    static let nomesDesenhos: [(id: String, nome: String)] = [
        ("copoPequeno", "Copo pequeno"), ("copo", "Copo"), ("caneca", "Caneca"), ("garrafa", "Garrafa de plástico"),
        ("termica", "Garrafa térmica (simples)"), ("copao", "Copão com alça"),
        ("quencher", "Copão estilo Quencher"), ("iceflow", "Garrafa com alça (IceFlow)"), ("aerolight", "Garrafa fina (AeroLight)"),
        ("classica", "Garrafa clássica (Legendary)"), ("owala", "Garrafa esportiva (FreeSip)"), ("twist", "Garrafa Twist"),
        ("hydro", "Garrafa Wide Mouth"), ("pacco", "Garrafa térmica com argola"),
        ("hydration", "Garrafa Classic Hydration"), ("quickflip", "Garrafa Quick Flip"), ("tumbler", "Copo térmico com tampa"),
    ]
}

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let v = UInt64(h, radix: 16) ?? 0x2F8FF0
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}

// MARK: - Desenhos dos produtos (área 60×60)

enum DesenhoProduto {
    static let todos: Set<String> = ["quencher", "iceflow", "aerolight", "classica", "owala", "twist", "hydro", "pacco", "hydration", "quickflip", "tumbler"]

    static func corpo(_ d: String) -> Path {
        var p = Path()
        switch d {
        case "quencher":
            p.move(to: CGPoint(x: 14, y: 14)); p.addLine(to: CGPoint(x: 44, y: 14))
            p.addLine(to: CGPoint(x: 40, y: 57)); p.addLine(to: CGPoint(x: 18, y: 57)); p.closeSubpath()
        case "iceflow": p.addRoundedRect(in: CGRect(x: 17, y: 16, width: 26, height: 42), cornerSize: CGSize(width: 7, height: 7))
        case "aerolight": p.addRoundedRect(in: CGRect(x: 21, y: 14, width: 18, height: 44), cornerSize: CGSize(width: 8, height: 8))
        case "classica":
            p.addRoundedRect(in: CGRect(x: 18, y: 20, width: 24, height: 38), cornerSize: CGSize(width: 5, height: 5))
            p.addRect(CGRect(x: 22, y: 15, width: 16, height: 6))
        case "owala": p.addRoundedRect(in: CGRect(x: 18, y: 19, width: 24, height: 39), cornerSize: CGSize(width: 9, height: 9))
        case "twist": p.addRoundedRect(in: CGRect(x: 19.5, y: 18, width: 21, height: 40), cornerSize: CGSize(width: 9, height: 9))
        case "hydro":
            p.move(to: CGPoint(x: 23, y: 15)); p.addLine(to: CGPoint(x: 37, y: 15))
            p.addQuadCurve(to: CGPoint(x: 42, y: 23), control: CGPoint(x: 42, y: 16))
            p.addLine(to: CGPoint(x: 42, y: 52)); p.addQuadCurve(to: CGPoint(x: 36, y: 58), control: CGPoint(x: 42, y: 58))
            p.addLine(to: CGPoint(x: 24, y: 58)); p.addQuadCurve(to: CGPoint(x: 18, y: 52), control: CGPoint(x: 18, y: 58))
            p.addLine(to: CGPoint(x: 18, y: 23)); p.addQuadCurve(to: CGPoint(x: 23, y: 15), control: CGPoint(x: 18, y: 16))
            p.closeSubpath()
        case "hydration": p.addRoundedRect(in: CGRect(x: 20.5, y: 14, width: 19, height: 44), cornerSize: CGSize(width: 7, height: 7))
        case "quickflip": p.addRoundedRect(in: CGRect(x: 18, y: 17, width: 24, height: 41), cornerSize: CGSize(width: 8, height: 8))
        case "tumbler":
            p.move(to: CGPoint(x: 15, y: 15)); p.addLine(to: CGPoint(x: 45, y: 15))
            p.addLine(to: CGPoint(x: 41, y: 57)); p.addLine(to: CGPoint(x: 19, y: 57)); p.closeSubpath()
        default: // pacco
            p.addRoundedRect(in: CGRect(x: 20, y: 15, width: 20, height: 43), cornerSize: CGSize(width: 9, height: 9))
        }
        return p
    }

    static func tampa(_ d: String) -> Path {
        var p = Path()
        switch d {
        case "quencher": p.addRoundedRect(in: CGRect(x: 12, y: 9, width: 34, height: 6), cornerSize: CGSize(width: 2.5, height: 2.5))
        case "iceflow": p.addRoundedRect(in: CGRect(x: 19, y: 9, width: 22, height: 8), cornerSize: CGSize(width: 3, height: 3))
        case "aerolight": p.addRoundedRect(in: CGRect(x: 23.5, y: 6, width: 13, height: 9), cornerSize: CGSize(width: 3, height: 3))
        case "classica": p.addRoundedRect(in: CGRect(x: 19, y: 3, width: 22, height: 13), cornerSize: CGSize(width: 3, height: 3))
        case "owala":
            p.addRoundedRect(in: CGRect(x: 18, y: 9, width: 24, height: 11), cornerSize: CGSize(width: 4, height: 4))
            p.addRoundedRect(in: CGRect(x: 20, y: 6.5, width: 6, height: 3.5), cornerSize: CGSize(width: 1.5, height: 1.5))
        case "twist": p.addRoundedRect(in: CGRect(x: 20.5, y: 8, width: 19, height: 11), cornerSize: CGSize(width: 4, height: 4))
        case "hydro": p.addRoundedRect(in: CGRect(x: 23, y: 6, width: 14, height: 10), cornerSize: CGSize(width: 3, height: 3))
        case "hydration": p.addRoundedRect(in: CGRect(x: 22.5, y: 5, width: 15, height: 10), cornerSize: CGSize(width: 3, height: 3))
        case "quickflip":
            p.addRoundedRect(in: CGRect(x: 18.5, y: 8, width: 23, height: 10), cornerSize: CGSize(width: 4, height: 4))
            p.addRoundedRect(in: CGRect(x: 32, y: 5.5, width: 7, height: 3.5), cornerSize: CGSize(width: 1.5, height: 1.5))
        case "tumbler": p.addRoundedRect(in: CGRect(x: 13, y: 9, width: 34, height: 7), cornerSize: CGSize(width: 3, height: 3))
        default: p.addRoundedRect(in: CGRect(x: 22.5, y: 7, width: 15, height: 9), cornerSize: CGSize(width: 3, height: 3))
        }
        return p
    }

    /// Alças, argolas e canudos (traço).
    static func detalhe(_ d: String) -> Path {
        var p = Path()
        switch d {
        case "quencher":
            p.move(to: CGPoint(x: 33, y: 9)); p.addLine(to: CGPoint(x: 38, y: 1))
            p.move(to: CGPoint(x: 43.5, y: 20)); p.addLine(to: CGPoint(x: 50, y: 20))
            p.addCurve(to: CGPoint(x: 55, y: 27), control1: CGPoint(x: 53, y: 20), control2: CGPoint(x: 55, y: 23))
            p.addLine(to: CGPoint(x: 55, y: 39))
            p.addCurve(to: CGPoint(x: 49, y: 46), control1: CGPoint(x: 55, y: 43), control2: CGPoint(x: 53, y: 46))
            p.addLine(to: CGPoint(x: 41.5, y: 46))
        case "iceflow":
            p.move(to: CGPoint(x: 21, y: 10)); p.addCurve(to: CGPoint(x: 39, y: 10), control1: CGPoint(x: 21, y: -1), control2: CGPoint(x: 39, y: -1))
        case "aerolight":
            p.addEllipse(in: CGRect(x: 27, y: 1, width: 6, height: 5))
        case "classica":
            p.move(to: CGPoint(x: 41, y: 6)); p.addLine(to: CGPoint(x: 45, y: 6)); p.addLine(to: CGPoint(x: 45, y: 13)); p.addLine(to: CGPoint(x: 41, y: 13))
        case "owala":
            p.move(to: CGPoint(x: 28, y: 9)); p.addCurve(to: CGPoint(x: 40, y: 9), control1: CGPoint(x: 28, y: 1), control2: CGPoint(x: 40, y: 1))
        case "twist":
            p.move(to: CGPoint(x: 39.5, y: 10)); p.addCurve(to: CGPoint(x: 39.5, y: 17), control1: CGPoint(x: 46, y: 10), control2: CGPoint(x: 46, y: 17))
        case "hydro":
            p.move(to: CGPoint(x: 37, y: 8)); p.addCurve(to: CGPoint(x: 37, y: 14), control1: CGPoint(x: 44, y: 8), control2: CGPoint(x: 44, y: 14))
        case "hydration":
            p.move(to: CGPoint(x: 37.5, y: 6.5)); p.addCurve(to: CGPoint(x: 37.5, y: 14), control1: CGPoint(x: 47, y: 6.5), control2: CGPoint(x: 47, y: 14))
        case "quickflip":
            p.move(to: CGPoint(x: 20, y: 10)); p.addCurve(to: CGPoint(x: 30, y: 10), control1: CGPoint(x: 20, y: 2), control2: CGPoint(x: 30, y: 2))
        case "tumbler":
            p.move(to: CGPoint(x: 24, y: 12.5)); p.addLine(to: CGPoint(x: 33, y: 12.5))
        default: // pacco: argola no topo
            p.addEllipse(in: CGRect(x: 25.5, y: 1, width: 9, height: 7))
        }
        return p
    }
}

private func escala60(_ p: Path, _ r: CGRect) -> Path {
    let s = min(r.width / 60, r.height / 60)
    let dx = r.minX + (r.width - 60 * s) / 2
    let dy = r.minY + (r.height - 60 * s) / 2
    var t = CGAffineTransform(a: s, b: 0, c: 0, d: s, tx: dx, ty: dy)
    let cg = p.cgPath
    return Path(cg.copy(using: &t) ?? cg)
}

struct FormaProduto: Shape {
    let desenho: String
    let parte: Int   // 0 corpo · 1 tampa · 2 detalhe · 3 brilho
    func path(in r: CGRect) -> Path {
        switch parte {
        case 0: return escala60(DesenhoProduto.corpo(desenho), r)
        case 1: return escala60(DesenhoProduto.tampa(desenho), r)
        case 2: return escala60(DesenhoProduto.detalhe(desenho), r)
        default:
            let c = DesenhoProduto.corpo(desenho).boundingRect
            var p = Path()
            p.addRoundedRect(in: CGRect(x: c.minX + c.width * 0.16, y: c.minY + 5, width: max(2, c.width * 0.13), height: c.height - 12),
                             cornerSize: CGSize(width: 2, height: 2))
            return escala60(p, r)
        }
    }
}

/// Ícone colorido de um produto (garrafa/copo de marca).
struct IconeProduto: View {
    let desenho: String
    let cor: Color
    let corTampa: Color
    var tamanho: CGFloat = 56

    var body: some View {
        let traco = max(1.2, tamanho / 30)
        ZStack {
            FormaProduto(desenho: desenho, parte: 2)
                .stroke(corTampa, style: StrokeStyle(lineWidth: traco * 1.6, lineCap: .round, lineJoin: .round))
            FormaProduto(desenho: desenho, parte: 0).fill(cor)
            FormaProduto(desenho: desenho, parte: 0).stroke(Color.black.opacity(0.18), lineWidth: traco * 0.6)
            FormaProduto(desenho: desenho, parte: 3).fill(Color.white.opacity(0.28))
            FormaProduto(desenho: desenho, parte: 1).fill(corTampa)
            FormaProduto(desenho: desenho, parte: 1).stroke(Color.black.opacity(0.18), lineWidth: traco * 0.6)
        }
        .frame(width: tamanho, height: tamanho)
    }
}

/// Mostra o ícone certo para qualquer copo salvo (de marca ou genérico).
struct IconeCopo: View {
    let copo: Copo
    var tamanho: CGFloat = 56
    var body: some View {
        if DesenhoProduto.todos.contains(copo.icone) {
            IconeProduto(desenho: copo.icone,
                         cor: copo.cor.isEmpty ? Color(hex: "#5B7FA6") : Color(hex: copo.cor),
                         corTampa: copo.corTampa.isEmpty ? Color(hex: "#2E3946") : Color(hex: copo.corTampa),
                         tamanho: tamanho)
        } else {
            IconeRecipiente(tipo: copo.icone, tamanho: tamanho)
        }
    }
}

// MARK: - Galeria para adicionar garrafas

struct GaleriaGarrafas: View {
    let aoEscolher: (Copo) -> Void
    @State private var marca: String? = nil
    @State private var formato: Int? = nil
    @State private var tamanho = 750
    @State private var adicionado = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                if marca != nil {
                    Button { withAnimation { marca = nil; formato = nil } } label: {
                        Label("Marcas", systemImage: "chevron.left")
                    }
                    .buttonStyle(BotaoAgua(tipo: .secundario))
                }
                Text(tituloAtual).font(.system(size: 14, weight: .bold)).foregroundColor(Estilo.tinta)
                Spacer()
                if !adicionado.isEmpty {
                    Label(adicionado, systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Estilo.verde)
                }
            }
            if let m = marca {
                if m == "naoSei" { paginaNaoSei } else { paginaModelos(m) }
            } else {
                paginaMarcas
            }
        }
    }

    var tituloAtual: String {
        switch marca {
        case nil: return "Qual é a marca da sua garrafa?"
        case "naoSei": return "Escolha o formato e o tamanho"
        default: return "Modelos \(marca ?? "")"
        }
    }

    private var colunas: [GridItem] { [GridItem(.adaptive(minimum: 150), spacing: 12)] }

    private var paginaMarcas: some View {
        LazyVGrid(columns: colunas, spacing: 12) {
            ForEach(Catalogo.marcas) { info in
                Ladrilho(titulo: info.nome, subtitulo: info.descricao) {
                    IconeProduto(desenho: info.exemplo.desenho, cor: Color(hex: info.exemplo.cor), corTampa: Color(hex: info.exemplo.corTampa), tamanho: 64)
                } acao: { withAnimation { marca = info.nome } }
            }
            Ladrilho(titulo: "Não sei / outra", subtitulo: "Escolha pelo formato e tamanho") {
                IconeProduto(desenho: "pacco", cor: Color(hex: "#2F3640"), corTampa: Color(hex: "#4A5260"), tamanho: 64)
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "questionmark.circle.fill").font(.system(size: 18)).foregroundColor(Estilo.azul)
                    }
            } acao: { withAnimation { marca = "naoSei" } }
        }
    }

    private func paginaModelos(_ m: String) -> some View {
        LazyVGrid(columns: colunas, spacing: 12) {
            ForEach(Catalogo.garrafas.filter { $0.marca == m }) { g in
                Ladrilho(titulo: g.nome, subtitulo: "Toque para adicionar") {
                    IconeProduto(desenho: g.desenho, cor: Color(hex: g.cor), corTampa: Color(hex: g.corTampa), tamanho: 72)
                } acao: {
                    aoEscolher(Copo(nome: "\(g.marca) \(g.nome)", ml: g.ml, icone: g.desenho, cor: g.cor, corTampa: g.corTampa))
                    adicionado = "Adicionado: \(g.nome)"
                }
            }
        }
    }

    private var paginaNaoSei: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("1. Qual formato parece mais com a sua?").font(.system(size: 12.5, weight: .semibold)).foregroundColor(Estilo.tinta2)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
                ForEach(0..<Catalogo.formatos.count, id: \.self) { i in
                    let f = Catalogo.formatos[i]
                    Ladrilho(titulo: f.nome, subtitulo: nil, selecionado: formato == i) {
                        iconeFormato(f.desenho, f.cor, f.corTampa, 56)
                    } acao: { formato = i }
                }
            }
            Text("2. Quantos ml? (costuma vir escrito embaixo da garrafa)").font(.system(size: 12.5, weight: .semibold)).foregroundColor(Estilo.tinta2)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 8)], spacing: 8) {
                ForEach(Catalogo.tamanhos, id: \.self) { t in
                    Text(t >= 1000 ? String(format: "%.1f L", Double(t) / 1000).replacingOccurrences(of: ".0", with: "").replacingOccurrences(of: ".", with: ",") : "\(t) ml")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(tamanho == t ? .white : Estilo.tinta)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(tamanho == t ? AnyShapeStyle(Estilo.gradienteBotao) : AnyShapeStyle(Marca.azulClaro)))
                        .contentShape(Capsule())
                        .onTapGesture { tamanho = t }
                }
            }
            HStack {
                Text("Outro valor:").font(.system(size: 12.5)).foregroundColor(Estilo.tinta2)
                PassoAgua(valor: $tamanho, faixa: 50...3000, passo: 10) { "\($0) ml" }
                Spacer()
                Button("Adicionar minha garrafa") {
                    let f = Catalogo.formatos[formato ?? 0]
                    aoEscolher(Copo(nome: "\(f.nome) \(tamanho) ml", ml: tamanho, icone: f.desenho, cor: f.cor, corTampa: f.corTampa))
                    adicionado = "Adicionado: \(f.nome) \(tamanho) ml"
                }
                .buttonStyle(BotaoAgua(tipo: .primario))
                .disabled(formato == nil)
                .opacity(formato == nil ? 0.5 : 1)
            }
        }
    }

    @ViewBuilder private func iconeFormato(_ d: String, _ cor: String, _ tampa: String, _ t: CGFloat) -> some View {
        if DesenhoProduto.todos.contains(d) {
            IconeProduto(desenho: d, cor: Color(hex: cor), corTampa: Color(hex: tampa), tamanho: t)
        } else {
            IconeRecipiente(tipo: d, tamanho: t)
        }
    }
}

/// Ladrilho clicável da galeria.
struct Ladrilho<Icone: View>: View {
    let titulo: String
    let subtitulo: String?
    var selecionado = false
    @ViewBuilder let icone: () -> Icone
    let acao: () -> Void
    @State private var sobre = false

    var body: some View {
        Button(action: acao) {
            VStack(spacing: 8) {
                icone().frame(height: 76)
                Text(titulo)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(Estilo.tinta)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                if let subtitulo {
                    Text(subtitulo).font(.system(size: 10.5)).foregroundColor(Estilo.tinta3).multilineTextAlignment(.center).lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 8)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(selecionado ? Estilo.azul.opacity(0.10) : (sobre ? Marca.azulClaro : Color.white)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(selecionado ? Estilo.azul : Marca.borda, lineWidth: selecionado ? 2 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { sobre = $0 }
    }
}
