import Foundation
import AppKit
import Combine

struct InfoVersao: Equatable {
    let versao: String
    let notas: String
    let zip: URL?
    let pagina: URL?
}

/// Atualizações no estilo de app normal:
/// - verifica as Releases do GitHub (versões estáveis publicadas de propósito);
/// - avisa que há versão nova, com as novidades;
/// - só instala quando a pessoa clica em "Atualizar". Nunca instala sozinho.
@MainActor
final class Atualizador: ObservableObject {
    enum Fase: Equatable {
        case parado, verificando, emDia, disponivel, baixando, instalando
        case erro(String)
    }

    @Published var fase: Fase = .parado
    @Published var disponivel: InfoVersao?

    let versaoAtual = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0"
    let repo = (Bundle.main.object(forInfoDictionaryKey: "LembreteAguaRepo") as? String) ?? "macholas96/lembrete-agua"
    weak var store: Store?
    var podeInstalar: @MainActor () -> Bool = { true }
    var aoEncontrar: @MainActor (InfoVersao) -> Void = { _ in }

    var ocupado: Bool { fase == .verificando || fase == .baixando || fase == .instalando }
    var localDoApp: URL { Bundle.main.bundleURL }
    var podeSeSubstituir: Bool {
        !localDoApp.path.contains("/AppTranslocation/")
            && FileManager.default.isWritableFile(atPath: localDoApp.deletingLastPathComponent().path)
    }

    private struct Release: Decodable {
        let tag_name: String
        let body: String?
        let html_url: String?
        let assets: [Asset]
        struct Asset: Decodable {
            let name: String
            let browser_download_url: String
        }
    }

    static func maior(_ a: String, que b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }
        let y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let p = i < x.count ? x[i] : 0
            let q = i < y.count ? y[i] : 0
            if p != q { return p > q }
        }
        return false
    }

    // MARK: Verificar

    func verificar(manual: Bool) {
        guard !ocupado, let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else { return }
        let anterior = fase
        fase = .verificando
        Task {
            var req = URLRequest(url: url)
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            req.setValue("LembreteAgua/\(self.versaoAtual)", forHTTPHeaderField: "User-Agent")
            req.cachePolicy = .reloadIgnoringLocalCacheData
            req.timeoutInterval = 20
            do {
                let (dados, resp) = try await URLSession.shared.data(for: req)
                let codigo = (resp as? HTTPURLResponse)?.statusCode ?? 0
                if codigo == 404 {
                    self.disponivel = nil
                    self.fase = .emDia
                    return
                }
                guard codigo == 200 else { throw URLError(.badServerResponse) }
                let r = try JSONDecoder().decode(Release.self, from: dados)
                let v = r.tag_name.hasPrefix("v") ? String(r.tag_name.dropFirst()) : r.tag_name
                self.store?.estado.ultimaVerificacao = Date()
                if Atualizador.maior(v, que: self.versaoAtual) {
                    let asset = r.assets.first { $0.name == "LembreteAgua.zip" }
                    let info = InfoVersao(versao: v,
                                          notas: r.body ?? "",
                                          zip: asset.flatMap { URL(string: $0.browser_download_url) },
                                          pagina: r.html_url.flatMap { URL(string: $0) })
                    let novidade = self.disponivel != info
                    self.disponivel = info
                    self.fase = .disponivel
                    if novidade { self.aoEncontrar(info) }
                } else {
                    self.disponivel = nil
                    self.fase = .emDia
                }
            } catch {
                if manual {
                    self.fase = .erro("Não consegui falar com o GitHub agora. Tente de novo em instantes.")
                } else {
                    self.fase = self.disponivel != nil ? .disponivel : (anterior == .verificando ? .parado : anterior)
                }
            }
        }
    }

    // MARK: Instalar (só com clique)

    func instalar() {
        guard let info = disponivel, !ocupado else { return }
        guard podeInstalar() else {
            fase = .erro("Termine de beber a água primeiro 😉")
            return
        }
        guard podeSeSubstituir else {
            fase = .erro("Para atualizar, o LembreteAgua precisa estar na pasta Aplicativos. Arraste-o para lá e abra de novo.")
            return
        }
        guard let zip = info.zip else {
            fase = .erro("Essa versão ainda está sendo preparada. Tente de novo em alguns minutos.")
            return
        }
        fase = .baixando
        Task {
            do {
                let (tmp, resp) = try await URLSession.shared.download(from: zip)
                guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
                let destino = FileManager.default.temporaryDirectory.appendingPathComponent("LembreteAgua-\(info.versao).zip")
                try? FileManager.default.removeItem(at: destino)
                try FileManager.default.moveItem(at: tmp, to: destino)
                self.fase = .instalando
                let script = Atualizador.scriptTroca(zip: destino.path, app: self.localDoApp.path, versao: info.versao)
                let (codigo, saida) = await Atualizador.rodar(script)
                if codigo == 0 {
                    // Reabre a versão nova e sai. (Se estiver rodando em segundo plano, o macOS também reabre sozinho.)
                    _ = await Atualizador.rodar("(sleep 2; /usr/bin/open -n \"\(self.localDoApp.path)\" --args --agente) >/dev/null 2>&1 &")
                    exit(0)
                } else {
                    self.fase = .erro("A instalação não deu certo — a versão atual continua funcionando.\n" + String(saida.suffix(500)))
                }
            } catch {
                self.fase = .erro("Não consegui baixar a atualização. Verifique a internet e tente de novo.")
            }
        }
    }

    static func scriptTroca(zip: String, app: String, versao: String) -> String {
        """
        set -euo pipefail
        export PATH=/usr/bin:/bin:/usr/sbin:/sbin
        T="$(mktemp -d)"
        trap 'rm -rf "$T"' EXIT
        ditto -x -k "\(zip)" "$T"
        NOVO="$T/LembreteAgua.app"
        [ -d "$NOVO" ] || { echo "O pacote não contém o app."; exit 1; }
        ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$NOVO/Contents/Info.plist")"
        [ "$ID" = "com.lembrete.agua" ] || { echo "Identificador inesperado: $ID"; exit 1; }
        V="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$NOVO/Contents/Info.plist")"
        [ "$V" = "\(versao)" ] || { echo "Versão inesperada: $V"; exit 1; }
        codesign --verify "$NOVO"
        xattr -dr com.apple.quarantine "$NOVO" 2>/dev/null || true
        APP="\(app)"
        rm -rf "$APP.antigo"
        mv "$APP" "$APP.antigo"
        if ! mv "$NOVO" "$APP"; then mv "$APP.antigo" "$APP"; exit 1; fi
        rm -rf "$APP.antigo" "\(zip)"
        tccutil reset Camera com.lembrete.agua >/dev/null 2>&1 || true
        """
    }

    nonisolated static func rodar(_ script: String) async -> (Int32, String) {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .utility).async {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/bin/bash")
                p.arguments = ["-c", script]
                let pipe = Pipe()
                p.standardOutput = pipe
                p.standardError = pipe
                do { try p.run() } catch {
                    cont.resume(returning: (-1, "\(error)"))
                    return
                }
                let dados = pipe.fileHandleForReading.readDataToEndOfFile()
                p.waitUntilExit()
                cont.resume(returning: (p.terminationStatus, String(data: dados, encoding: .utf8) ?? ""))
            }
        }
    }
}
