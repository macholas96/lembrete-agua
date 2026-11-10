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
    var copoConfirmado = false          // copo/garrafa já reconhecido nesta verificação
    var diagnostico = ""                // o que a câmera está reconhecendo (para ajudar quando falha)
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
    private var vistasCopo = 0
    private var diagnostico = ""
    private var acumAfastar = 0.0

    static let palavrasCopo: Set<String> = [
        "cup", "cups", "mug", "bottle", "bottles", "glass", "wineglass", "beverage", "drink",
        "drinks", "tumbler", "flask", "thermos", "teacup", "jug", "straw", "water", "canteen",
        "drinkware", "jar", "pitcher", "carafe", "vacuum", "can", "beer", "soda", "coffee", "tea",
    ]
    static let camerasProibidas = ["virtual", "obs", "snap", "manycam", "xsplit", "mmhmm",
                                   "camtwist", "ndi", "vcam", "screen", "syphon"]

    static func temRecipiente(_ resultados: [VNClassificationObservation], minimo: Float) -> Bool {
        for c in resultados where c.confidence > minimo {
            let tokens = c.identifier.lowercased().split(whereSeparator: { $0 == "_" || $0 == " " }).map(String.init)
            if tokens.contains(where: { palavrasCopo.contains($0) }) { return true }
        }
        return false
    }

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
        quadrosBebendo = 0; quadrosComCopo = 0; acumAfastar = 0; vistasCopo = 0; diagnostico = ""
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

        // Copo / garrafa: olha a imagem inteira e, principalmente, um recorte em volta da mão
        // (garrafas escuras ou pequenas na imagem quase nunca aparecem na classificação da imagem inteira).
        if classificar {
            var achou = Verificador.temRecipiente(reqClasse.results ?? [], minimo: 0.1)
            var melhores = reqClasse.results ?? []
            if let m = maoRect {
                let lado = max(m.width * aspecto, m.height) * 3.2
                let w = min(1, lado / aspecto), h = min(1, lado)
                let x = min(max(0, m.midX - w / 2), 1 - w)
                let y = min(max(0, m.midY - h * 0.45), 1 - h)
                let reqRecorte = VNClassifyImageRequest()
                reqRecorte.regionOfInterest = CGRect(x: x, y: y, width: w, height: h)
                if (try? VNImageRequestHandler(cvPixelBuffer: pb, orientation: .up, options: [:]).perform([reqRecorte])) != nil {
                    let r = reqRecorte.results ?? []
                    if Verificador.temRecipiente(r, minimo: 0.06) { achou = true }
                    melhores = r
                }
            }
            if achou {
                tempoUltimoCopo = agora
                vistasCopo += 1
            }
            diagnostico = melhores.sorted(by: { $0.confidence > $1.confidence }).prefix(4).map { "\($0.identifier.replacingOccurrences(of: "_", with: " ")) \(Int($0.confidence * 100))%" }
                .joined(separator: " · ")
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
            // O recipiente pode ser reconhecido em qualquer momento da verificação (não só colado na boca).
            let copoOk = !exigirCopo || vistasCopo >= 2
            if acumBebendo >= segundosNecessarios && copoOk { etapa = 2 }
            if acumBebendo >= segundosNecessarios && !copoOk {
                msg = "Bebeu! Agora mostre o copo/garrafa de frente para a câmera, perto do rosto."
            } else if acumBebendo > 0.3 {
                msg = "Isso! Continue bebendo…"
            } else {
                msg = "Leve o copo ou a garrafa à boca e beba."
            }
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
        s.copoConfirmado = vistasCopo >= 2
        s.diagnostico = diagnostico
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
