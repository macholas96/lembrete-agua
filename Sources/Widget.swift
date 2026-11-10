import SwiftUI
import AppKit

// MARK: - Widget da área de trabalho

struct WidgetView: View {
    @ObservedObject var store: Store

    var escala: CGFloat {
        switch store.prefs.widgetTamanho {
        case "pequeno": return 0.8
        case "grande": return 1.2
        default: return 1
        }
    }
    var escuro: Bool { store.prefs.widgetEstilo != "claro" }
    var corTexto: Color { escuro ? .white : Estilo.tinta }

    var body: some View {
        let hoje = store.hojeML
        let meta = store.regras.metaML
        let p = Double(hoje) / Double(max(1, meta))
        VStack(alignment: .leading, spacing: 12 * escala) {
            HStack(alignment: .top, spacing: 16 * escala) {
                ZStack {
                    GarrafaProgresso(progresso: p, animar: store.prefs.animacoes,
                                     contorno: escuro ? Color.white.opacity(0.75) : Estilo.azul.opacity(0.8))
                    Text("\(Int((min(p, 9.99)) * 100))%")
                        .font(.system(size: 16 * escala, weight: .heavy, design: .rounded))
                        .foregroundColor(p > 0.45 ? .white : corTexto)
                        .offset(y: 20 * escala)
                }
                .frame(width: 70 * escala, height: 114 * escala)

                VStack(alignment: .leading, spacing: 4 * escala) {
                    Text("ÁGUA HOJE")
                        .font(.system(size: 11 * escala, weight: .semibold))
                        .tracking(0.8)
                        .opacity(0.7)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(store.fmt(hoje, unidade: false)).font(.system(size: 30 * escala, weight: .bold, design: .rounded))
                        Text("/ \(store.fmt(meta))").font(.system(size: 13 * escala, weight: .medium)).opacity(0.75)
                    }
                    VStack(alignment: .leading, spacing: 6 * escala) {
                        chip("🔥 \(store.sequenciaAtual()) dias")
                        chip(textoProximo)
                        chip("🥤 \(store.coposHoje) \(store.coposHoje == 1 ? "copo" : "copos")")
                    }
                    .padding(.top, 6 * escala)
                }
            }
            Divider().overlay(corTexto.opacity(0.2))
            Semana(store: store, escala: escala, corTexto: corTexto)
        }
        .foregroundColor(corTexto)
        .padding(18 * escala)
        .frame(width: 330 * escala)
        .background(
            RoundedRectangle(cornerRadius: 24 * escala, style: .continuous)
                .fill(escuro ? Color(red: 0.08, green: 0.16, blue: 0.27).opacity(0.55) : Color.white.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24 * escala, style: .continuous)
                .stroke(Color.white.opacity(escuro ? 0.18 : 0.6), lineWidth: 1)
        )
    }

    var textoProximo: String {
        if store.estaAtivo() { return "⏱ próximo \(Formatos.hora.string(from: store.estado.proximo))" }
        if store.regras.pararAoBaterMeta && store.hojeML >= store.regras.metaML { return "✅ meta batida" }
        return "🌙 fora do horário"
    }

    func chip(_ t: String) -> some View {
        Text(t)
            .font(.system(size: 12 * escala, weight: .semibold))
            .padding(.vertical, 4 * escala)
            .padding(.horizontal, 9 * escala)
            .background(Capsule().fill(corTexto.opacity(escuro ? 0.16 : 0.08)))
    }
}

struct Semana: View {
    @ObservedObject var store: Store
    let escala: CGFloat
    let corTexto: Color
    static let letras = ["D", "S", "T", "Q", "Q", "S", "S"]

    var body: some View {
        let totais = store.totaisPorDia
        let meta = Double(max(1, store.regras.metaML))
        let hoje = Date().inicioDoDia
        HStack(alignment: .bottom) {
            ForEach((0..<7).reversed(), id: \.self) { atras in
                let dia = calendario.date(byAdding: .day, value: -atras, to: hoje) ?? hoje
                let v = Double(totais[dia] ?? 0)
                let bateu = v >= meta
                let gradiente: LinearGradient = bateu
                    ? LinearGradient(colors: [Color(red: 0.65, green: 0.95, blue: 0.77), Estilo.verde], startPoint: .top, endPoint: .bottom)
                    : Estilo.gradienteAgua
                let alturaBarra: CGFloat = max(5, 36 * escala * CGFloat(min(1, v / meta)))
                VStack(spacing: 4) {
                    Capsule()
                        .fill(gradiente)
                        .frame(width: 14 * escala, height: alturaBarra)
                        .overlay(Capsule().stroke(corTexto.opacity(atras == 0 ? 0.9 : 0), lineWidth: 1.5).padding(-2))
                    Text(atras == 0 ? "Hoje" : Semana.letras[calendario.component(.weekday, from: dia) - 1])
                        .font(.system(size: 10 * escala, weight: .medium))
                        .opacity(0.85)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 54 * escala, alignment: .bottom)
    }
}

@MainActor
final class WidgetMesa {
    private var janela: NSWindow?
    private let store: Store

    init(store: Store) { self.store = store }

    func atualizar() {
        guard store.prefs.widgetAtivo, let tela = NSScreen.screens.first else {
            janela?.orderOut(nil)
            janela = nil
            return
        }
        if janela == nil {
            let j = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 330, height: 200), styleMask: .borderless, backing: .buffered, defer: false)
            j.isOpaque = false
            j.backgroundColor = .clear
            j.hasShadow = false
            j.ignoresMouseEvents = true
            j.isReleasedWhenClosed = false
            j.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
            j.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            j.contentView = NSHostingView(rootView: WidgetView(store: store))
            janela = j
        }
        guard let j = janela, let host = j.contentView else { return }
        let tam = host.fittingSize
        let area = tela.visibleFrame
        let margem: CGFloat = 24
        let x: CGFloat = store.prefs.widgetPosicao.hasSuffix("Esq") ? area.minX + margem : area.maxX - tam.width - margem
        let y: CGFloat = store.prefs.widgetPosicao.hasPrefix("sup") ? area.maxY - tam.height - margem : area.minY + margem
        j.setFrame(NSRect(x: x, y: y, width: tam.width, height: tam.height), display: true)
        j.orderFront(nil)
    }
}

// MARK: - Bolha (pré-aviso e recados rápidos)

struct BolhaView: View {
    let texto: String
    let icone: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icone)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Estilo.gradienteAgua)
            Text(texto)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundColor(Estilo.tinta)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .frame(maxWidth: 380, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.96)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.black.opacity(0.06)))
        .padding(10)
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        .environment(\.colorScheme, .light)
    }
}

@MainActor
final class Bolha {
    private var janela: NSWindow?
    private var tarefa: Task<Void, Never>?

    func mostrar(_ texto: String, icone: String = "drop.fill", segundos: Double = 6) {
        fechar()
        guard let tela = NSScreen.main ?? NSScreen.screens.first else { return }
        let host = NSHostingView(rootView: BolhaView(texto: texto, icone: icone))
        let tam = host.fittingSize
        let area = tela.visibleFrame
        let j = NSWindow(contentRect: NSRect(x: area.maxX - tam.width - 6, y: area.maxY - tam.height - 4, width: tam.width, height: tam.height),
                         styleMask: .borderless, backing: .buffered, defer: false)
        j.isOpaque = false
        j.backgroundColor = .clear
        j.hasShadow = false
        j.ignoresMouseEvents = true
        j.isReleasedWhenClosed = false
        j.level = .statusBar
        j.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        j.contentView = host
        j.alphaValue = 0
        j.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            j.animator().alphaValue = 1
        }
        janela = j
        tarefa = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(max(1, segundos) * 1_000_000_000))
            if !Task.isCancelled { self?.fechar() }
        }
    }

    func fechar() {
        tarefa?.cancel()
        tarefa = nil
        janela?.orderOut(nil)
        janela = nil
    }
}

// MARK: - Barra de menus

@MainActor
final class BarraMenu: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let store: Store
    var aoBeber: @MainActor () -> Void = {}
    var aoAjustes: @MainActor (String) -> Void = { _ in }

    init(store: Store) {
        self.store = store
        super.init()
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        atualizar()
    }

    func atualizar() {
        guard let b = item.button else { return }
        let img = NSImage(systemSymbolName: "drop.fill", accessibilityDescription: "Água")
        img?.isTemplate = true
        b.image = img
        b.imagePosition = .imageLeading
        switch store.prefs.barraMenu {
        case "pct": b.title = " \(Int(Double(store.hojeML) / Double(max(1, store.regras.metaML)) * 100))%"
        case "icone": b.title = ""
        default: b.title = " " + store.fmtCurto(store.hojeML)
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let hoje = store.hojeML, meta = store.regras.metaML
        let cab = NSMenuItem(title: "\(store.fmt(hoje, unidade: false)) de \(store.fmt(meta))  ·  🔥 \(store.sequenciaAtual()) dias", action: nil, keyEquivalent: "")
        cab.isEnabled = false
        menu.addItem(cab)
        let prox: String
        if store.estaAtivo() {
            prox = "Próximo lembrete às \(Formatos.hora.string(from: store.estado.proximo))"
        } else {
            prox = "Fora do horário de lembretes"
        }
        let itemProx = NSMenuItem(title: prox, action: nil, keyEquivalent: "")
        itemProx.isEnabled = false
        menu.addItem(itemProx)
        if let p = store.estado.pendente, let d = store.estado.pendenteAPartirDe, p != store.regras {
            let i = NSMenuItem(title: "Mudanças agendadas para \(Formatos.diaCurto.string(from: d))", action: nil, keyEquivalent: "")
            i.isEnabled = false
            menu.addItem(i)
        }
        menu.addItem(.separator())
        menu.addItem(acao("💧 Beber agora…", #selector(beber), ""))
        menu.addItem(.separator())
        menu.addItem(acao("Histórico e conquistas…", #selector(historico), ""))
        menu.addItem(acao("Ajustes…", #selector(ajustes), ","))
    }

    private func acao(_ t: String, _ s: Selector, _ k: String) -> NSMenuItem {
        let i = NSMenuItem(title: t, action: s, keyEquivalent: k)
        i.target = self
        return i
    }

    @objc private func beber() { aoBeber() }
    @objc private func historico() { aoAjustes("historico") }
    @objc private func ajustes() { aoAjustes("lembretes") }
}
