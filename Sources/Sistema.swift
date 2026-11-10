import Foundation
import AppKit
import AVFoundation
import CoreAudio
import ServiceManagement
import Combine

// MARK: - Como o app foi aberto

enum ModoInicio {
    /// Agente de segundo plano embutido no app (aparece em Ajustes do Sistema → Itens de Início).
    static let agente = SMAppService.agent(plistName: "com.lembrete.agua.agente.plist")

    /// Instalações antigas (via Terminal) usam este LaunchAgent.
    static let plistAntigo = Caminhos.home.appendingPathComponent("Library/LaunchAgents/com.lembrete.agua.plist")
    static var temAgenteAntigo: Bool { FileManager.default.fileExists(atPath: plistAntigo.path) }

    /// true quando quem abriu foi o macOS (segundo plano), e não a pessoa.
    static var ehAgente: Bool {
        if CommandLine.arguments.contains("--agente") { return true }
        return (ProcessInfo.processInfo.environment["XPC_SERVICE_NAME"] ?? "").hasPrefix("com.lembrete.agua")
    }

    static let avisoAbrir = Notification.Name("com.lembrete.agua.abrir")
}

// MARK: - Chamadas

enum Chamada {
    /// Microfone padrão em uso por algum app (Meet, Zoom, Teams, FaceTime…).
    static func microfoneEmUso() -> Bool {
        var endereco = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var dispositivo = AudioDeviceID(0)
        var tamanho = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &endereco, 0, nil, &tamanho, &dispositivo) == noErr,
              dispositivo != 0 else { return false }
        var end2 = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var rodando: UInt32 = 0
        var tam2 = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(dispositivo, &end2, 0, nil, &tam2, &rodando) == noErr else { return false }
        return rodando != 0
    }

    static func emChamada(usarMicrofone: Bool) -> Bool {
        cameraEmUsoPorOutroApp() || (usarMicrofone && microfoneEmUso())
    }

    static func descricao(usarMicrofone: Bool) -> String {
        let cam = cameraEmUsoPorOutroApp()
        let mic = microfoneEmUso()
        let partes = "Câmera: \(cam ? "em uso" : "livre") · Microfone: \(mic ? "em uso" : "livre")"
        let esperaria = cam || (usarMicrofone && mic)
        return partes + (esperaria ? " → agora o lembrete ESPERARIA." : " → agora o lembrete apareceria normalmente.")
    }
}

// MARK: - Permissões

@MainActor
final class Permissoes: ObservableObject {
    @Published var camera: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published var agente: SMAppService.Status = ModoInicio.agente.status
    @Published var itemDeLogin: SMAppService.Status = SMAppService.mainApp.status
    @Published var erroSegundoPlano = ""
    private var timer: Timer?

    var cameraOk: Bool { camera == .authorized }
    var segundoPlanoOk: Bool { agente == .enabled || itemDeLogin == .enabled || ModoInicio.temAgenteAntigo }
    var tudoOk: Bool { cameraOk && segundoPlanoOk }

    func atualizar() {
        camera = AVCaptureDevice.authorizationStatus(for: .video)
        agente = ModoInicio.agente.status
        itemDeLogin = SMAppService.mainApp.status
    }

    func monitorar(_ ligar: Bool) {
        timer?.invalidate()
        timer = nil
        guard ligar else { return }
        atualizar()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.atualizar() }
        }
    }

    var textoBotaoCamera: String {
        camera == .notDetermined ? "Permitir câmera" : "Abrir Ajustes da Câmera"
    }

    func pedirCamera() {
        if camera == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { _ in
                Task { @MainActor in self.atualizar() }
            }
        } else {
            Permissoes.abrirAjustesCamera()
        }
    }

    static func abrirAjustesCamera() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
            NSWorkspace.shared.open(url)
        }
    }

    var textoBotaoSegundoPlano: String {
        agente == .requiresApproval ? "Aprovar nos Ajustes" : "Ativar"
    }

    func ativarSegundoPlano() {
        erroSegundoPlano = ""
        if agente == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
            return
        }
        do {
            try ModoInicio.agente.register()
        } catch {
            // Plano B: item de início simples (abre com o Mac).
            do { try SMAppService.mainApp.register() } catch {
                erroSegundoPlano = "O macOS não deixou ativar: \(error.localizedDescription)"
            }
        }
        atualizar()
        if agente == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
    }
}

// MARK: - Instalação no lugar certo

enum Instalacao {
    static var noLugarCerto: Bool {
        let p = Bundle.main.bundlePath
        return p.hasPrefix("/Applications/") || p.hasPrefix(Caminhos.home.path + "/Applications/")
    }

    /// Copia o app para /Applications, abre a cópia e fecha este.
    static func moverParaAplicativos() async -> String {
        let origem = Bundle.main.bundlePath
        let script = """
        set -euo pipefail
        DEST="/Applications/LembreteAgua.app"
        rm -rf "$DEST"
        ditto "\(origem)" "$DEST"
        xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
        (sleep 1; /usr/bin/open -n "$DEST") >/dev/null 2>&1 &
        """
        let (codigo, saida) = await Atualizador.rodar(script)
        if codigo == 0 { exit(0) }
        return "Não consegui mover sozinho. Arraste o LembreteAgua para a pasta Aplicativos e abra de lá.\n" + String(saida.suffix(200))
    }
}
