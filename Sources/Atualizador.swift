import Foundation
import Combine

/// Atualizações: lê VERSION no GitHub; se for maior, baixa o código, compila no próprio Mac,
/// troca o app e se reinicia (o launchd reabre na hora). Histórico e ajustes não são tocados.
@MainActor
final class Atualizador: ObservableObject {
    @Published var status = ""
    @Published var ocupado = false
    let versaoAtual = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0"
    weak var store: Store?
    var podeInstalar: @MainActor () -> Bool = { true }

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

    func verificar(manual: Bool) {
        guard let store, !ocupado else { return }
        let repo = store.prefs.fonteAtualizacao.trimmingCharacters(in: .whitespacesAndNewlines)
        guard repo.range(of: "^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", options: .regularExpression) != nil,
              let url = URL(string: "https://raw.githubusercontent.com/\(repo)/main/VERSION") else {
            if manual { status = "Informe o repositório no formato usuario/repositorio." }
            return
        }
        ocupado = true
        status = "Procurando atualização…"
        Task {
            var req = URLRequest(url: url)
            req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            req.timeoutInterval = 20
            do {
                let (dados, resp) = try await URLSession.shared.data(for: req)
                guard (resp as? HTTPURLResponse)?.statusCode == 200,
                      let remota = String(data: dados, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !remota.isEmpty else {
                    self.status = "Não encontrei o arquivo VERSION nesse repositório."
                    self.ocupado = false
                    return
                }
                store.estado.ultimaVerificacao = Date()
                if Atualizador.maior(remota, que: self.versaoAtual) {
                    if !(manual || store.prefs.autoAtualizar) {
                        self.status = "Versão \(remota) disponível. Clique em Verificar agora para instalar."
                    } else if !self.podeInstalar() {
                        self.status = "Versão \(remota) disponível — instalo assim que a tela azul sair."
                    } else {
                        await self.instalar(repo: repo, versao: remota)
                    }
                } else {
                    self.status = "Você já está na versão mais recente (\(self.versaoAtual))."
                }
            } catch {
                self.status = "Sem conexão com o GitHub agora. Tento de novo mais tarde."
            }
            self.ocupado = false
        }
    }

    private func instalar(repo: String, versao: String) async {
        status = "Baixando e compilando a versão \(versao)… (leva 1–2 min)"
        let app = Caminhos.app.path
        let script = """
        set -euo pipefail
        export PATH=/usr/bin:/bin:/usr/sbin:/sbin
        T="$(mktemp -d)"
        trap 'rm -rf "$T"' EXIT
        curl -fsSL "https://codeload.github.com/\(repo)/tar.gz/refs/heads/main" | tar xz -C "$T"
        D="$(find "$T" -mindepth 1 -maxdepth 1 -type d | head -1)"
        bash "$D/build.sh" "$T/novo.app"
        if [ -f "$D/pos-atualizacao.sh" ]; then bash "$D/pos-atualizacao.sh" || true; fi
        cp "$D/desinstalar.sh" "$HOME/Library/Application Support/LembreteAgua/desinstalar.sh" 2>/dev/null || true
        rm -rf "\(app).antigo"
        mv "\(app)" "\(app).antigo"
        mv "$T/novo.app" "\(app)"
        rm -rf "\(app).antigo"
        tccutil reset Camera com.lembrete.agua >/dev/null 2>&1 || true
        """
        let (codigo, saida) = await Atualizador.rodar(script)
        if codigo == 0 {
            status = "Atualizado para \(versao)! Reiniciando…"
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            exit(0)   // o launchd (KeepAlive) reabre o app já na versão nova
        } else {
            status = "A atualização falhou — o app atual continua funcionando normalmente.\n" + String(saida.suffix(800))
        }
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
