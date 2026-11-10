import SwiftUI
import AppKit
import AVFoundation

// MARK: - Cores e temas

enum Estilo {
    static let tinta = Color(red: 0.06, green: 0.13, blue: 0.21)
    static let tinta2 = Color(red: 0.29, green: 0.36, blue: 0.45)
    static let tinta3 = Color(red: 0.52, green: 0.59, blue: 0.67)
    static let azul = Color(red: 0.18, green: 0.56, blue: 0.94)
    static let verde = Color(red: 0.13, green: 0.77, blue: 0.37)
    static let gradienteAgua = LinearGradient(colors: [Color(red: 0.56, green: 0.86, blue: 1), Color(red: 0.18, green: 0.56, blue: 0.94)],
                                              startPoint: .top, endPoint: .bottom)
    static let gradienteBotao = LinearGradient(colors: [Color(red: 0.27, green: 0.66, blue: 1), Color(red: 0.12, green: 0.48, blue: 0.9)],
                                               startPoint: .top, endPoint: .bottom)
}

struct Tema {
    let id: String
    let nome: String
    let cores: [Color]

    static let todos: [Tema] = [
        Tema(id: "oceano", nome: "Oceano", cores: [Color(red: 0.37, green: 0.78, blue: 1), Color(red: 0.18, green: 0.56, blue: 0.94), Color(red: 0.09, green: 0.40, blue: 0.79)]),
        Tema(id: "lagoa", nome: "Lagoa", cores: [Color(red: 0.40, green: 0.88, blue: 0.82), Color(red: 0.10, green: 0.66, blue: 0.66), Color(red: 0.03, green: 0.45, blue: 0.50)]),
        Tema(id: "lavanda", nome: "Lavanda", cores: [Color(red: 0.72, green: 0.67, blue: 1), Color(red: 0.51, green: 0.43, blue: 0.93), Color(red: 0.33, green: 0.25, blue: 0.76)]),
        Tema(id: "por-do-sol", nome: "Pôr do sol", cores: [Color(red: 1, green: 0.72, blue: 0.55), Color(red: 0.95, green: 0.47, blue: 0.55), Color(red: 0.55, green: 0.30, blue: 0.75)]),
        Tema(id: "noite", nome: "Noite", cores: [Color(red: 0.22, green: 0.32, blue: 0.52), Color(red: 0.11, green: 0.18, blue: 0.34), Color(red: 0.04, green: 0.07, blue: 0.18)]),
    ]

    static func de(_ id: String) -> Tema { todos.first { $0.id == id } ?? todos[0] }
}

// MARK: - Formas

struct Onda: Shape {
    var fase: Double
    var amplitude: Double
    var nivel: Double      // 0 = topo, 1 = base
    var ciclos: Double = 1.5

    func path(in r: CGRect) -> Path {
        var p = Path()
        let y0 = r.height * CGFloat(nivel)
        p.move(to: CGPoint(x: 0, y: y0))
        var x = 0.0
        while x <= Double(r.width) {
            let y = Double(y0) + sin(x / Double(max(1, r.width)) * 2 * .pi * ciclos + fase) * amplitude
            p.addLine(to: CGPoint(x: x, y: y))
            x += 4
        }
        p.addLine(to: CGPoint(x: r.width, y: r.height))
        p.addLine(to: CGPoint(x: 0, y: r.height))
        p.closeSubpath()
        return p
    }
}

/// Desenha numa área 60×60 e escala para o retângulo.
private func escalar(_ p: Path, _ r: CGRect, _ vb: CGSize = CGSize(width: 60, height: 60)) -> Path {
    let s = min(r.width / vb.width, r.height / vb.height)
    let dx = r.minX + (r.width - vb.width * s) / 2
    let dy = r.minY + (r.height - vb.height * s) / 2
    return p.applying(CGAffineTransform(a: s, b: 0, c: 0, d: s, tx: dx, ty: dy))
}

struct FormaRecipiente: Shape {
    let tipo: String
    let agua: Bool

    func path(in r: CGRect) -> Path {
        var p = Path()
        switch (tipo, agua) {
        case ("copoPequeno", false):
            p.move(to: CGPoint(x: 12, y: 8)); p.addLine(to: CGPoint(x: 48, y: 8))
            p.addLine(to: CGPoint(x: 43, y: 56)); p.addLine(to: CGPoint(x: 17, y: 56)); p.closeSubpath()
        case ("copoPequeno", true):
            p.move(to: CGPoint(x: 15, y: 24)); p.addLine(to: CGPoint(x: 45, y: 24))
            p.addLine(to: CGPoint(x: 42.4, y: 53.5)); p.addLine(to: CGPoint(x: 17.6, y: 53.5)); p.closeSubpath()
        case ("caneca", false):
            p.addRoundedRect(in: CGRect(x: 8, y: 8, width: 34, height: 48), cornerSize: CGSize(width: 6, height: 6))
            p.move(to: CGPoint(x: 42, y: 18)); p.addLine(to: CGPoint(x: 48, y: 18))
            p.addCurve(to: CGPoint(x: 48, y: 36), control1: CGPoint(x: 57, y: 18), control2: CGPoint(x: 57, y: 36))
            p.addLine(to: CGPoint(x: 42, y: 36))
        case ("caneca", true):
            p.addRoundedRect(in: CGRect(x: 11, y: 20, width: 28, height: 33), cornerSize: CGSize(width: 4, height: 4))
        case ("garrafa", false):
            p.move(to: CGPoint(x: 24, y: 3)); p.addLine(to: CGPoint(x: 36, y: 3)); p.addLine(to: CGPoint(x: 36, y: 11))
            p.addLine(to: CGPoint(x: 43, y: 20)); p.addLine(to: CGPoint(x: 43, y: 52))
            p.addQuadCurve(to: CGPoint(x: 37, y: 58), control: CGPoint(x: 43, y: 58))
            p.addLine(to: CGPoint(x: 23, y: 58)); p.addQuadCurve(to: CGPoint(x: 17, y: 52), control: CGPoint(x: 17, y: 58))
            p.addLine(to: CGPoint(x: 17, y: 20)); p.addLine(to: CGPoint(x: 24, y: 11)); p.closeSubpath()
        case ("garrafa", true):
            p.move(to: CGPoint(x: 20, y: 28)); p.addLine(to: CGPoint(x: 40, y: 28)); p.addLine(to: CGPoint(x: 40, y: 52))
            p.addQuadCurve(to: CGPoint(x: 37, y: 55), control: CGPoint(x: 40, y: 55))
            p.addLine(to: CGPoint(x: 23, y: 55)); p.addQuadCurve(to: CGPoint(x: 20, y: 52), control: CGPoint(x: 20, y: 55))
            p.closeSubpath()
        case (_, false):  // copo
            p.move(to: CGPoint(x: 10, y: 4)); p.addLine(to: CGPoint(x: 50, y: 4))
            p.addLine(to: CGPoint(x: 45, y: 57)); p.addLine(to: CGPoint(x: 15, y: 57)); p.closeSubpath()
        default:
            p.move(to: CGPoint(x: 13, y: 17)); p.addLine(to: CGPoint(x: 47, y: 17))
            p.addLine(to: CGPoint(x: 43.4, y: 54.5)); p.addLine(to: CGPoint(x: 16.6, y: 54.5)); p.closeSubpath()
        }
        return escalar(p, r)
    }
}

struct IconeRecipiente: View {
    let tipo: String
    var tamanho: CGFloat = 56
    var body: some View {
        ZStack {
            FormaRecipiente(tipo: tipo, agua: true).fill(Estilo.gradienteAgua)
            FormaRecipiente(tipo: tipo, agua: false)
                .stroke(Color(red: 0.09, green: 0.40, blue: 0.79), style: StrokeStyle(lineWidth: max(1.5, tamanho / 24), lineJoin: .round))
        }
        .frame(width: tamanho, height: tamanho)
    }
}

struct FormaGarrafa: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 30, y: 4)); p.addLine(to: CGPoint(x: 56, y: 4)); p.addLine(to: CGPoint(x: 56, y: 20))
        p.addLine(to: CGPoint(x: 68, y: 36)); p.addLine(to: CGPoint(x: 68, y: 128))
        p.addQuadCurve(to: CGPoint(x: 60, y: 136), control: CGPoint(x: 68, y: 136))
        p.addLine(to: CGPoint(x: 26, y: 136)); p.addQuadCurve(to: CGPoint(x: 18, y: 128), control: CGPoint(x: 18, y: 136))
        p.addLine(to: CGPoint(x: 18, y: 36)); p.addLine(to: CGPoint(x: 30, y: 20)); p.closeSubpath()
        return escalar(p, r, CGSize(width: 86, height: 140))
    }
}

/// Garrafa que enche conforme o progresso (0…1), com onda animada.
struct GarrafaProgresso: View {
    let progresso: Double
    var animar = true
    var contorno: Color = .white.opacity(0.75)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !animar)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let p = min(1, max(0, progresso))
            let nivel = (136 - p * 106) / 140
            ZStack {
                FormaGarrafa().fill(Color.white.opacity(0.10))
                Onda(fase: animar ? t * 2 : 0, amplitude: p > 0.02 ? 3 : 0, nivel: nivel, ciclos: 1.2)
                    .fill(Estilo.gradienteAgua)
                    .clipShape(FormaGarrafa())
                FormaGarrafa().stroke(contorno, style: StrokeStyle(lineWidth: 2.2, lineJoin: .round))
            }
        }
        .aspectRatio(86.0 / 140.0, contentMode: .fit)
    }
}

// MARK: - Anel de progresso

struct Anel<Conteudo: View>: View {
    let progresso: Double
    var tamanho: CGFloat = 132
    var espessura: CGFloat = 12
    var trilho: Color = Color(red: 0.89, green: 0.92, blue: 0.95)
    @ViewBuilder let conteudo: () -> Conteudo

    var body: some View {
        ZStack {
            Circle().stroke(trilho, lineWidth: espessura)
            Circle()
                .trim(from: 0, to: CGFloat(min(1, max(0.001, progresso))))
                .stroke(Estilo.gradienteAgua, style: StrokeStyle(lineWidth: espessura, lineCap: .round))
                .rotationEffect(.degrees(-90))
            conteudo()
        }
        .frame(width: tamanho, height: tamanho)
    }
}

struct BarraProgresso: View {
    let valor: Double
    var altura: CGFloat = 10
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Estilo.tinta.opacity(0.08))
                Capsule()
                    .fill(LinearGradient(colors: [Color(red: 0.37, green: 0.78, blue: 1), Color(red: 0.12, green: 0.48, blue: 0.9)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(altura, g.size.width * CGFloat(min(1, max(0, valor)))))
                    .animation(.easeOut(duration: 0.25), value: valor)
            }
        }
        .frame(height: altura)
    }
}

// MARK: - Botões

struct BotaoPrimario: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
            .frame(minWidth: 260)
            .padding(.vertical, 14)
            .padding(.horizontal, 26)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Estilo.gradienteBotao))
            .shadow(color: Color(red: 0.12, green: 0.48, blue: 0.9).opacity(0.35), radius: 10, y: 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .contentShape(Rectangle())
    }
}

struct BotaoSecundario: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(Estilo.tinta2)
            .padding(.vertical, 9)
            .padding(.horizontal, 16)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Estilo.tinta.opacity(configuration.isPressed ? 0.12 : 0.06)))
            .contentShape(Rectangle())
    }
}

// MARK: - Fundo de água (overlay)

struct Bolhas: View {
    let tempo: Double
    private static let specs: [(x: Double, r: Double, v: Double, o: Double)] = [
        (0.08, 7, 60, 0), (0.18, 4, 90, 200), (0.76, 9, 50, 400), (0.88, 5, 80, 100),
        (0.64, 3.5, 110, 300), (0.35, 5, 70, 500), (0.5, 3, 95, 250), (0.95, 6, 65, 650),
    ]
    var body: some View {
        GeometryReader { g in
            ForEach(0..<Bolhas.specs.count, id: \.self) { i in
                let s = Bolhas.specs[i]
                let h = Double(g.size.height) + 40
                let y = h - (tempo * s.v + s.o).truncatingRemainder(dividingBy: h) - 20
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .overlay(Circle().stroke(Color.white.opacity(0.55), lineWidth: 1.5))
                    .frame(width: s.r * 2, height: s.r * 2)
                    .position(x: Double(g.size.width) * s.x, y: y)
            }
        }
    }
}

struct FundoAgua: View {
    @ObservedObject var store: Store
    var body: some View {
        let tema = Tema.de(store.prefs.tema)
        let o = store.prefs.opacidade
        ZStack {
            LinearGradient(colors: [tema.cores[0].opacity(o * 0.9), tema.cores[1].opacity(o), tema.cores[2].opacity(min(1, o * 1.2))],
                           startPoint: .top, endPoint: .bottom)
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !store.prefs.animacoes)) { ctx in
                let t = store.prefs.animacoes ? ctx.date.timeIntervalSinceReferenceDate : 0
                ZStack {
                    Onda(fase: t * 0.7, amplitude: 24, nivel: 0.86, ciclos: 1.2).fill(Color.white.opacity(0.20))
                    Onda(fase: -t * 1.1, amplitude: 16, nivel: 0.91, ciclos: 1.8).fill(Color.white.opacity(0.16))
                    if store.prefs.animacoes { Bolhas(tempo: t) }
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Prévia da câmera

final class PreviewNSView: NSView {
    let camada: AVCaptureVideoPreviewLayer
    init(sessao: AVCaptureSession) {
        camada = AVCaptureVideoPreviewLayer(session: sessao)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        camada.videoGravity = .resizeAspectFill
        camada.setAffineTransform(CGAffineTransform(scaleX: -1, y: 1)) // espelho
        layer?.addSublayer(camada)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layout() {
        super.layout()
        camada.bounds = bounds
        camada.position = CGPoint(x: bounds.midX, y: bounds.midY)
    }
}

struct PreviewCamera: NSViewRepresentable {
    let sessao: AVCaptureSession
    func makeNSView(context: Context) -> PreviewNSView { PreviewNSView(sessao: sessao) }
    func updateNSView(_ nsView: PreviewNSView, context: Context) {}
}

/// Converte um retângulo do Vision (normalizado, origem embaixo) para a prévia espelhada em aspectFill.
func mapearRetangulo(_ r: CGRect, em tam: CGSize, aspecto: CGFloat) -> CGRect {
    let dispH = max(tam.width / aspecto, tam.height)
    let dispW = dispH * aspecto
    let ox = (tam.width - dispW) / 2
    let oy = (tam.height - dispH) / 2
    return CGRect(x: (1 - r.maxX) * dispW + ox, y: (1 - r.maxY) * dispH + oy,
                  width: r.width * dispW, height: r.height * dispH)
}

// MARK: - Sons

enum Sons {
    static let disponiveis = ["Glass", "Submarine", "Ping", "Pop", "Purr", "Hero", "Bottle", "Blow", "Funk", "Tink", "Frog", "Morse"]
    static func tocar(_ nome: String, volume: Double) {
        guard let s = NSSound(named: nome)?.copy() as? NSSound else { return }
        s.volume = Float(volume)
        s.play()
    }
}
