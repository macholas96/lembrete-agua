import Foundation
import AVFoundation
import Vision
import CoreMediaIO
import QuartzCore

// MARK: - Status publicado para a interface

struct StatusVerificacao {
    var rosto = false
    var naBoca = false
    var copo = false
    var etapa = 0                 // 0 rosto livre · 1 bebendo · 2 afastar · 3 confirmado
    var segundos = 0.0
    var progresso = 0.0
    var mensagem = "Olhe para a câmera."
    var rostoRect: CGRect? = nil  // normalizado (Vision: origem embaixo à esquerda)
    var maoRect: CGRect? = nil
    var aspecto: CGFloat = 4.0 / 3.0
}

// MARK: - Verificador (Vision, 100% local; nenhum quadro é guardado)

final class Verificador: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let sessao = AVCaptureSession()
    private let fila = DispatchQueue(label: "agua.camera")

    var aoAtualizar: (@MainActor (StatusVerificacao) -> Void)?
    var aoConcluir: (@MainActor () -> Void)?
    var aoFalhar: (@MainActor (String) -> Void)?

    private var segundosNecessarios = 2.5
    private var exigirCopo = true

    private var configurada = false
    private var ativo = false
    private var ultimaAmostra: CFTimeInterval = 0
    private var contador = 0
    private var ultimoRosto: CGRect?
    private var tempoUltimoRosto: CFTimeInterval = 0
    private var tempoUltimoCopo: CFTimeInterval = -100
    private var etapa = 0
    private var acumPreparo = 0.0
    private var acumBebendo = 0.0
    private var quadrosBebendo = 0
    private var quadrosComCopo = 0
    private var acumAfastar = 0.0

    static let palavrasCopo: Set<String> = [
        "cup", "cups", "mug", "bottle", "bottles", "glass", "wineglass", "beverage", "drink",
        "drinks", "tumbler", "flask", "thermos", "teacup", "jug", "straw", "water", "canteen",
    ]
    static let camerasProibidas = ["virtual", "obs", "snap", "manycam", "xsplit", "mmhmm",
                                   "camtwist", "ndi", "vcam", "screen", "syphon"]

    static func escolherCamera() -> AVCaptureDevice? {
        var tipos: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
        if #available(macOS 14.0, *) {
            tipos += [.continuityCamera, .external]
        } else {
            tipos.append(.externalUnknown)
        }
        let devs = AVCaptureDevice.DiscoverySession(deviceTypes: tipos, mediaType: .video, position: .unspecified).devices
        let validas = devs.filter { d in
            let n = d.localizedName.lowercased()
            return !camerasProibidas.contains { n.contains($0) }
        }
        return validas.first { $0.deviceType == .builtInWideAngleCamera } ?? validas.first
    }

    func configurar(segundos: Double, exigirCopo: Bool) {
        fila.async {
            self.segundosNecessarios = max(1, segundos)
            self.exigirCopo = exigirCopo
        }
    }

    func iniciar() {
        fila.async {
            if !self.configurada {
                var erro: String?
                if let dispositivo = Verificador.escolherCamera(),
                   let entrada = try? AVCaptureDeviceInput(device: dispositivo) {
                    self.sessao.beginConfiguration()
                    if self.sessao.canSetSessionPreset(.vga640x480) { self.sessao.sessionPreset = .vga640x480 }
                    let saida = AVCaptureVideoDataOutput()
                    saida.alwaysDiscardsLateVideoFrames = true
                    saida.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                    saida.setSampleBufferDelegate(self, queue: self.fila)
                    if self.sessao.canAddInput(entrada) && self.sessao.canAddOutput(saida) {
                        self.sessao.addInput(entrada)
                        self.sessao.addOutput(saida)
                    } else {
                        erro = "Não consegui abrir a câmera."
                    }
                    self.sessao.commitConfiguration()
                } else {
                    erro = "Nenhuma câmera física encontrada (câmeras virtuais não valem)."
                }
                if let e = erro {
                    let cb = self.aoFalhar
                    Task { @MainActor in cb?(e) }
                    return
                }
                self.configurada = true
            }
            self.resetar()
            self.ativo = true
            if !self.sessao.isRunning { self.sessao.startRunning() }
        }
    }

    func reiniciar() { fila.async { self.resetar(); self.ativo = true } }

    func parar() {
        fila.async {
            self.ativo = false
            if self.sessao.isRunning { self.sessao.stopRunning() }
        }
    }

    private func resetar() {
        ultimaAmostra = 0; contador = 0; ultimoRosto = nil; tempoUltimoRosto = 0
        tempoUltimoCopo = -100; etapa = 0; acumPreparo = 0; acumBebendo = 0
        quadrosBebendo = 0; quadrosComCopo = 0; acumAfastar = 0
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard ativo, etapa < 3 else { return }
        let agora = CACurrentMediaTime()
        guard agora - ultimaAmostra >= 0.15 else { return }
        let dt = ultimaAmostra == 0 ? 0 : min(agora - ultimaAmostra, 0.3)
        ultimaAmostra = agora
        guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let aspecto = CGFloat(CVPixelBufferGetWidth(pb)) / CGFloat(max(1, CVPixelBufferGetHeight(pb)))

        let reqRosto = VNDetectFaceRectanglesRequest()
        let reqMao = VNDetectHumanHandPoseRequest()
        reqMao.maximumHandCount = 2
        let reqClasse = VNClassifyImageRequest()
        contador += 1
        let classificar = contador % 2 == 0
        var reqs: [VNRequest] = [reqRosto, reqMao]
        if classificar { reqs.append(reqClasse) }
        do {
            try VNImageRequestHandler(cvPixelBuffer: pb, orientation: .up, options: [:]).perform(reqs)
        } catch { return }
        // A partir daqui o quadro não é mais usado: nada é gravado em disco.

        // Rosto
        let rostoAgora = (reqRosto.results ?? [])
            .max { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height }?.boundingBox
        if let r = rostoAgora { ultimoRosto = r; tempoUltimoRosto = agora }
        let memoria = etapa == 1 ? 1.5 : 0.8
        let temRosto = ultimoRosto != nil && agora - tempoUltimoRosto < memoria

        // Mão perto da boca
        var naBoca = false
        var maoRect: CGRect?
        for obs in reqMao.results ?? [] {
            guard let pontos = try? obs.recognizedPoints(.all) else { continue }
            let bons = pontos.values.filter { $0.confidence > 0.3 }
            guard !bons.isEmpty else { continue }
            let xs = bons.map { $0.location.x }, ys = bons.map { $0.location.y }
            let caixa = CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
            if maoRect == nil { maoRect = caixa }
            if temRosto, let r = ultimoRosto {
                let boca = CGPoint(x: r.midX * aspecto, y: r.minY + r.height * 0.25)
                let limite = r.width * aspecto * 1.1
                if bons.contains(where: { hypot($0.location.x * aspecto - boca.x, $0.location.y - boca.y) < limite }) {
                    naBoca = true
                    maoRect = caixa
                }
            }
        }

        // Copo / garrafa
        if classificar {
            for c in reqClasse.results ?? [] where c.confidence > 0.1 {
                let tokens = c.identifier.lowercased().split(whereSeparator: { $0 == "_" || $0 == " " }).map(String.init)
                if tokens.contains(where: { Verificador.palavrasCopo.contains($0) }) { tempoUltimoCopo = agora; break }
            }
        }
        let temCopo = agora - tempoUltimoCopo < 1.0

        // Sequência obrigatória (impede foto parada): rosto livre → bebendo → afastar
        var msg = ""
        switch etapa {
        case 0:
            if rostoAgora != nil && !naBoca { acumPreparo += dt } else { acumPreparo = 0 }
            if acumPreparo >= 0.7 { etapa = 1 }
            msg = rostoAgora == nil ? "Não estou vendo seu rosto — olhe para a câmera." : "Ótimo! Mantenha o rosto livre por um instante…"
        case 1:
            if temRosto && naBoca {
                acumBebendo += dt
                quadrosBebendo += 1
                if temCopo { quadrosComCopo += 1 }
            }
            let copoOk = !exigirCopo || quadrosComCopo >= max(3, quadrosBebendo / 5)
            if acumBebendo >= segundosNecessarios && copoOk { etapa = 2 }
            if temRosto && naBoca && exigirCopo && !temCopo { msg = "Não estou vendo o copo — deixe-o bem visível." }
            else if acumBebendo >= segundosNecessarios { msg = "Continue, preciso ver o copo mais um pouco…" }
            else if acumBebendo > 0.3 { msg = "Isso! Continue bebendo…" }
            else { msg = "Leve o copo à boca e beba." }
        case 2:
            if rostoAgora != nil && !naBoca { acumAfastar += dt } else { acumAfastar = 0 }
            if acumAfastar >= 0.7 { etapa = 3 }
            msg = "Boa! Agora afaste o copo da boca."
        default:
            msg = "Confirmado! 💧"
        }

        var s = StatusVerificacao()
        s.rosto = temRosto; s.naBoca = naBoca; s.copo = temCopo; s.mensagem = msg
        s.etapa = etapa; s.segundos = acumBebendo
        s.rostoRect = temRosto ? ultimoRosto : nil
        s.maoRect = maoRect
        s.aspecto = aspecto
        switch etapa {
        case 0: s.progresso = 0.15 * min(1, acumPreparo / 0.7)
        case 1: s.progresso = 0.15 + 0.7 * min(1, acumBebendo / segundosNecessarios)
        case 2: s.progresso = 0.85 + 0.15 * min(1, acumAfastar / 0.7)
        default: s.progresso = 1
        }
        let cbStatus = aoAtualizar
        Task { @MainActor in cbStatus?(s) }

        if etapa == 3 {
            ativo = false
            let cb = aoConcluir
            Task { @MainActor in cb?() }
        }
    }
}

// MARK: - Câmera em uso por outro app (chamada de vídeo)

func cameraEmUsoPorOutroApp() -> Bool {
    let sistema = CMIOObjectID(kCMIOObjectSystemObject)
    var endereco = CMIOObjectPropertyAddress(
        mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
        mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
        mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
    var tamanho: UInt32 = 0
    guard CMIOObjectGetPropertyDataSize(sistema, &endereco, 0, nil, &tamanho) == 0, tamanho > 0 else { return false }
    let quantos = Int(tamanho) / MemoryLayout<CMIOObjectID>.size
    var ids = [CMIOObjectID](repeating: 0, count: quantos)
    var usado: UInt32 = 0
    guard CMIOObjectGetPropertyData(sistema, &endereco, 0, nil, tamanho, &usado, &ids) == 0 else { return false }
    for id in ids {
        var end = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
        var rodando: UInt32 = 0
        var u: UInt32 = 0
        if CMIOObjectGetPropertyData(id, &end, 0, nil, UInt32(MemoryLayout<UInt32>.size), &u, &rodando) == 0, rodando != 0 {
            return true
        }
    }
    return false
}
