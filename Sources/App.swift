import AppKit
import SwiftUI
import AVFoundation

final class JanelaOverlay: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class Controlador: NSObject, NSApplicationDelegate {
    let store = Store()
    let verificador = Verificador()
    let fluxo = Fluxo()
    let atualizador = Atualizador()
    let bolha = Bolha()
    lazy var widget = WidgetMesa(store: store)
    lazy var barra = BarraMenu(store: store)
    lazy var ajustes = JanelaAjustes(store: store, atualizador: atualizador)

    var janelas: [JanelaOverlay] = []
    var janelaPrincipal: JanelaOverlay?
    var mostrando = false
    var timerImpor: Timer?
    var pausadoAte: Date?
    var preAvisoPara: Date?
    var adiadoDesde: Date?

    override init() { super.init() }

    // Modo quiosque: sem Dock, sem menus, sem Cmd+Tab, sem Cmd+Option+Esc.
    let quiosque: NSApplication.PresentationOptions = [
        .hideDock, .hideMenuBar, .disableAppleMenu, .disableProcessSwitching,
        .disableForceQuit, .disableHideApplication,
    ]

    // MARK: Início

    func applicationDidFinishLaunching(_ notification: Notification) {
        let id = Bundle.main.bundleIdentifier ?? "com.lembrete.agua"
        if NSRunningApplication.runningApplications(withBundleIdentifier: id).contains(where: { $0 != NSRunningApplication.current }) {
            exit(0)
        }
        NSApp.setActivationPolicy(.accessory)
        configurarMenuPrincipal()
        fluxo.sessao = verificador.sessao

        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { _ in }
        }

        verificador.aoAtualizar = { [weak self] s in self?.fluxo.status = s }
        verificador.aoConcluir = { [weak self] in self?.concluiu() }
        verificador.aoFalhar = { [weak self] m in self?.fluxo.tela = .falha(m) }

        fluxo.acaoAbrirCamera = { [weak self] in self?.abrirCamera() }
        fluxo.acaoCancelar = { [weak self] in self?.esconder() }
        fluxo.acaoRecomecar = { [weak self] in self?.verificador.reiniciar() }
        fluxo.acaoAjustesCamera = { [weak self] in self?.abrirAjustesCamera() }

        atualizador.store = store
        atualizador.podeInstalar = { [weak self] in !(self?.mostrando ?? true) }

        barra.aoBeber = { [weak self] in self?.mostrarOverlay(voluntario: true) }
        barra.aoAjustes = { [weak self] aba in self?.ajustes.abrir(aba: aba) }
        ajustes.aoTestar = { [weak self] in
            self?.ajustes.fechar()
            self?.mostrarOverlay(voluntario: true)
        }

        store.aoMudarPrefs = { [weak self] in
            self?.widget.atualizar()
            self?.barra.atualizar()
        }

        NotificationCenter.default.addObserver(self, selector: #selector(telasMudaram),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(checar),
                                                          name: NSWorkspace.didWakeNotification, object: nil)
        Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(checar), userInfo: nil, repeats: true)
        Timer.scheduledTimer(timeInterval: 60, target: self, selector: #selector(atualizarVisuais), userInfo: nil, repeats: true)
        Timer.scheduledTimer(timeInterval: 6 * 3600, target: self, selector: #selector(procurarAtualizacao), userInfo: nil, repeats: true)

        widget.atualizar()
        barra.atualizar()

        if store.primeiraVez {
            ajustes.abrir(aba: "lembretes")
            bolha.mostrar("Bem-vindo! Configure do seu jeito — hoje tudo vale na hora.", segundos: 8)
        } else if store.puloNoBoot {
            bolha.mostrar("Você desligou o Mac com a água pendente. Fica registrado no histórico 👀", icone: "power", segundos: 8)
        } else if store.estado.ultimaVersaoVista != atualizador.versaoAtual && !store.estado.ultimaVersaoVista.isEmpty {
            bolha.mostrar("Atualizado para a versão \(atualizador.versaoAtual)! Veja as novidades nos Ajustes.", icone: "sparkles", segundos: 8)
        }
        if store.estado.ultimaVersaoVista != atualizador.versaoAtual {
            store.estado.ultimaVersaoVista = atualizador.versaoAtual
        }

        checar()
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 90_000_000_000)
            self?.procurarAtualizacao()
        }
    }

    func configurarMenuPrincipal() {
        // Só para os atalhos de texto nos Ajustes (copiar/colar). Não existe "Sair".
        let principal = NSMenu()
        let appItem = NSMenuItem()
        principal.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Fechar janela", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        appItem.submenu = appMenu
        let editItem = NSMenuItem()
        principal.addItem(editItem)
        let edit = NSMenu(title: "Editar")
        edit.addItem(withTitle: "Desfazer", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Recortar", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copiar", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Colar", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Selecionar tudo", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        NSApp.mainMenu = principal
    }

    // MARK: Agenda

    @objc func atualizarVisuais() {
        barra.atualizar()
        widget.atualizar()
    }

    @objc func procurarAtualizacao() {
        guard store.prefs.autoAtualizar, !mostrando else { return }
        atualizador.verificar(manual: false)
    }

    @objc func checar() {
        store.aplicarPendentes()
        if FileManager.default.fileExists(atPath: Caminhos.testar.path) {
            try? FileManager.default.removeItem(at: Caminhos.testar)
            mostrarOverlay(voluntario: false)
            return
        }
        guard !mostrando else { return }
        let agora = Date()
        guard store.estaAtivo(agora) else {
            if !store.estado.foraDoHorario { store.estado.foraDoHorario = true }
            adiadoDesde = nil
            return
        }
        let intervalo = TimeInterval(store.regras.intervaloMin * 60)
        if store.estado.foraDoHorario {
            store.estado.foraDoHorario = false
            store.estado.proximo = agora.addingTimeInterval(intervalo)
            barra.atualizar()
        }
        // Editar arquivos para empurrar o lembrete pro futuro não adianta: no máximo 1 intervalo.
        if store.estado.proximo > agora.addingTimeInterval(intervalo) {
            store.estado.proximo = agora.addingTimeInterval(intervalo)
        }
        let falta = store.estado.proximo.timeIntervalSince(agora)

        if store.prefs.preAviso, falta > 0, falta <= Double(store.prefs.preAvisoSeg), preAvisoPara != store.estado.proximo {
            preAvisoPara = store.estado.proximo
            let quando = falta >= 90 ? "\(Int((falta / 60).rounded())) min" : "\(Int(falta.rounded())) s"
            bolha.mostrar("Água em \(quando) — já pega o copo!", segundos: min(falta, 10))
        }
        guard falta <= 0 else { return }

        if store.regras.adiarEmChamadas && cameraEmUsoPorOutroApp() {
            if adiadoDesde == nil {
                adiadoDesde = agora
                bolha.mostrar("Você está numa chamada — a água espera ela acabar (até \(store.regras.adiarMaxMin) min).",
                              icone: "video.fill", segundos: 8)
            }
            if let d = adiadoDesde, agora.timeIntervalSince(d) < Double(store.regras.adiarMaxMin * 60) { return }
        }
        adiadoDesde = nil
        mostrarOverlay(voluntario: false)
    }

    // MARK: Overlay

    func mostrarOverlay(voluntario: Bool) {
        guard !mostrando else { return }
        mostrando = true
        bolha.fechar()
        ajustes.fechar()
        fluxo.preparar(voluntario: voluntario, store: store)
        construirJanelas()
        if store.prefs.somAtivo && !voluntario { Sons.tocar(store.prefs.som, volume: store.prefs.volume) }
        NSApp.activate(ignoringOtherApps: true)
        impor()
        timerImpor = Timer.scheduledTimer(timeInterval: 0.3, target: self, selector: #selector(impor), userInfo: nil, repeats: true)
    }

    @objc func impor() {
        guard mostrando else { return }
        if let p = pausadoAte {
            if p > Date() { return }
            pausadoAte = nil
        }
        if !NSApp.isActive { NSApp.activate(ignoringOtherApps: true) }
        if !fluxo.voluntario && NSApp.presentationOptions != quiosque { NSApp.presentationOptions = quiosque }
        for j in janelas where j != janelaPrincipal || !j.isVisible { j.orderFrontRegardless() }
        if let p = janelaPrincipal, !p.isKeyWindow { p.makeKeyAndOrderFront(nil) }
    }

    func pausar(_ segundos: TimeInterval) {
        pausadoAte = Date().addingTimeInterval(segundos)
        NSApp.presentationOptions = []
        janelas.forEach { $0.orderOut(nil) }
    }

    func retomar() {
        pausadoAte = nil
        impor()
    }

    func esconder() {
        mostrando = false
        timerImpor?.invalidate()
        timerImpor = nil
        pausadoAte = nil
        verificador.parar()
        NSApp.presentationOptions = []
        janelas.forEach { $0.orderOut(nil) }
        janelas = []
        janelaPrincipal = nil
        widget.atualizar()
        barra.atualizar()
        NSApp.hide(nil)
    }

    @objc func telasMudaram() {
        widget.atualizar()
        guard mostrando else { return }
        construirJanelas()
        impor()
    }

    func construirJanelas() {
        janelas.forEach { $0.orderOut(nil) }
        janelas = []
        let principal = NSScreen.main ?? NSScreen.screens.first
        for tela in NSScreen.screens {
            let j = JanelaOverlay(contentRect: tela.frame, styleMask: .borderless, backing: .buffered, defer: false)
            j.setFrame(tela.frame, display: false)
            j.level = .screenSaver
            j.isOpaque = false
            j.backgroundColor = .clear
            j.hasShadow = false
            j.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            j.isReleasedWhenClosed = false
            j.contentView = NSHostingView(rootView: OverlayRaiz(fluxo: fluxo, store: store, principal: tela == principal))
            if tela == principal { janelaPrincipal = j }
            janelas.append(j)
        }
    }

    // MARK: Câmera

    func abrirCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            verificador.configurar(segundos: store.regras.segundosBebendo, exigirCopo: store.regras.exigirCopo)
            fluxo.status = StatusVerificacao()
            fluxo.tela = .camera
            verificador.iniciar()
        case .notDetermined:
            pausar(30)   // deixa o pedido de permissão do macOS aparecer
            AVCaptureDevice.requestAccess(for: .video) { _ in
                Task { @MainActor [weak self] in
                    self?.retomar()
                    self?.abrirCamera()
                }
            }
        default:
            fluxo.tela = .falha("A câmera está bloqueada para o LembreteAgua.\nAjustes do Sistema → Privacidade e Segurança → Câmera → ative LembreteAgua.")
        }
    }

    func abrirAjustesCamera() {
        pausar(45)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
            NSWorkspace.shared.open(url)
        }
    }

    func concluiu() {
        guard mostrando else { return }
        verificador.parar()
        let antes = store.hojeML
        let novas = store.registrar(ml: fluxo.ml, voluntario: fluxo.voluntario)
        fluxo.bateuMetaAgora = antes < store.regras.metaML && store.hojeML >= store.regras.metaML
        fluxo.novasConquistas = novas
        fluxo.tela = .sucesso
        if store.prefs.somAtivo { Sons.tocar("Pop", volume: store.prefs.volume) }
        let espera: UInt64 = novas.isEmpty && !fluxo.bateuMetaAgora ? 3_000_000_000 : 5_000_000_000
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: espera)
            guard let self, self.mostrando, self.fluxo.tela == .sucesso else { return }
            self.esconder()
        }
    }
}

@main
struct LembreteAguaApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let controlador = Controlador()
        app.delegate = controlador
        withExtendedLifetime(controlador) { app.run() }
    }
}
