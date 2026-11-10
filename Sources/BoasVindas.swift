import SwiftUI
import AppKit

/// Apresentação em poucos slides + permissões. Aparece na primeira vez que o app é aberto.
struct BoasVindasView: View {
    @ObservedObject var store: Store
    @ObservedObject var permissoes: Permissoes
    let aoConcluir: @MainActor () -> Void
    @State private var pagina = 0
    @State private var erroMover = ""
    private let total = 6

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch pagina {
                case 0: paginaBemVindo
                case 1: paginaTelaAzul
                case 2: paginaCamera
                case 3: paginaCopos
                case 4: paginaDoSeuJeito
                default: paginaPermissoes
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 48)
            .padding(.top, 30)

            HStack {
                if pagina > 0 {
                    Button("Voltar") { withAnimation { pagina -= 1 } }
                        .buttonStyle(BotaoAgua(tipo: .discreto, grande: true))
                } else {
                    Spacer().frame(width: 80)
                }
                Spacer()
                HStack(spacing: 7) {
                    ForEach(0..<total, id: \.self) { i in
                        Circle().fill(i == pagina ? Estilo.azul : Color.secondary.opacity(0.3)).frame(width: 7, height: 7)
                    }
                }
                Spacer()
                if pagina < total - 1 {
                    Button("Continuar") { withAnimation { pagina += 1 } }
                        .buttonStyle(BotaoAgua(tipo: .primario, grande: true))
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("Começar") { aoConcluir() }
                        .buttonStyle(BotaoAgua(tipo: .primario, grande: true))
                        .keyboardShortcut(.defaultAction)
                        .disabled(!permissoes.tudoOk)
                        .opacity(permissoes.tudoOk ? 1 : 0.45)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
        }
        .frame(width: 780, height: 580)
        .background(Marca.fundo)
        .environment(\.colorScheme, .light)
    }

    // MARK: Slides

    private func titulo(_ t: String, _ sub: String) -> some View {
        VStack(spacing: 8) {
            Text(t).font(.system(size: 28, weight: .heavy)).multilineTextAlignment(.center)
            Text(sub).font(.system(size: 15)).foregroundColor(.secondary).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var paginaBemVindo: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 150, height: 150)
                .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
            titulo("Bem-vindo ao LembreteAgua", "O lembrete de água que você não consegue ignorar.\nLeva 1 minuto para configurar.")
            if !Instalacao.noLugarCerto {
                VStack(spacing: 10) {
                    Label("O app ainda não está na pasta Aplicativos.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 13, weight: .semibold))
                    Text("Para funcionar direitinho (e receber atualizações), ele precisa ficar lá.")
                        .font(.system(size: 12)).foregroundColor(.secondary)
                    Button("Mover para Aplicativos") {
                        Task { erroMover = await Instalacao.moverParaAplicativos() }
                    }
                    .buttonStyle(BotaoAgua(tipo: .primario))
                    if !erroMover.isEmpty {
                        Text(erroMover).font(.system(size: 11)).foregroundColor(.secondary).multilineTextAlignment(.center)
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.orange.opacity(0.1)))
            }
            Spacer(minLength: 0)
        }
    }

    private var paginaTelaAzul: some View {
        VStack(spacing: 22) {
            ZStack {
                FundoAgua(store: store)
                VStack(spacing: 6) {
                    Image(systemName: "drop.fill").font(.system(size: 30)).foregroundStyle(Estilo.gradienteAgua)
                    Text("Hora de beber água").font(.system(size: 17, weight: .heavy)).foregroundColor(Estilo.tinta)
                    Text("Beber agora")
                        .font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                        .padding(.vertical, 6).padding(.horizontal, 22)
                        .background(Capsule().fill(Estilo.gradienteBotao))
                }
                .padding(.vertical, 18).padding(.horizontal, 30)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.94)))
            }
            .frame(width: 460, height: 230)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
            titulo("A tela fica azul. De verdade.",
                   "No intervalo que você escolher, todos os monitores ficam azuis. Não dá para fechar — nem com Cmd+Option+Esc. Só libera quando você bebe.")
            Spacer(minLength: 0)
        }
    }

    private var paginaCamera: some View {
        VStack(spacing: 22) {
            HStack(spacing: 18) {
                passo("1", "face.smiling", "Mostre o rosto")
                Image(systemName: "chevron.right").foregroundColor(.secondary)
                passo("2", "cup.and.saucer.fill", "Beba uns segundos")
                Image(systemName: "chevron.right").foregroundColor(.secondary)
                passo("3", "checkmark.circle.fill", "Afaste o copo")
            }
            .padding(.top, 20)
            titulo("Beba na frente da câmera",
                   "A câmera confirma que você bebeu de verdade. Tudo é analisado no seu Mac, na hora — nenhuma foto ou vídeo é salvo.")
            Label("100% privado: nada sai do seu computador", systemImage: "lock.shield.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.green)
            Spacer(minLength: 0)
        }
    }

    private func passo(_ n: String, _ icone: String, _ texto: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icone)
                .font(.system(size: 30))
                .foregroundStyle(Estilo.gradienteAgua)
                .frame(width: 84, height: 84)
                .background(Circle().fill(Estilo.azul.opacity(0.1)))
            Text("\(n). \(texto)").font(.system(size: 13, weight: .semibold))
        }
    }

    private var paginaCopos: some View {
        VStack(spacing: 22) {
            HStack(spacing: 20) {
                IconeRecipiente(tipo: "copo", tamanho: 64)
                IconeRecipiente(tipo: "caneca", tamanho: 64)
                ForEach([0, 7, 3, 14], id: \.self) { i in
                    let g = Catalogo.garrafas[i]
                    IconeProduto(desenho: g.desenho, cor: Color(hex: g.cor), corTampa: Color(hex: g.corTampa), tamanho: 72)
                }
            }
            .padding(.top, 24)
            titulo("Seu copo, sua garrafa",
                   "Escolha quanto bebeu — inclusive garrafas como Stanley, Owala e Pacco. Acompanhe a meta do dia, a sequência de dias, níveis e conquistas.")
            HStack(spacing: 12) {
                selo("🔥", "Sequência")
                selo("🌊", "Níveis")
                selo("🏅", "Conquistas")
                selo("📊", "Widget na mesa")
            }
            Spacer(minLength: 0)
        }
    }

    private func selo(_ e: String, _ t: String) -> some View {
        HStack(spacing: 6) {
            Text(e)
            Text(t).font(.system(size: 12.5, weight: .semibold))
        }
        .padding(.vertical, 7).padding(.horizontal, 12)
        .background(Capsule().fill(Color.secondary.opacity(0.1)))
    }

    private var paginaDoSeuJeito: some View {
        VStack(spacing: 20) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 54))
                .foregroundStyle(Estilo.gradienteAgua)
                .padding(.top, 20)
            titulo("Do seu jeito — sem se enganar",
                   "Horário, dias, intervalo, meta, pausa de almoço e chamadas: tudo nos Ajustes (gotinha 💧 na barra de menus).")
            VStack(alignment: .leading, spacing: 10) {
                Label("Em chamada de vídeo? O lembrete espera ela acabar.", systemImage: "video.fill")
                Label("Mudanças que deixam mais rígido valem na hora.", systemImage: "checkmark.seal.fill")
                Label("Mudanças que afrouxam só valem no dia seguinte.", systemImage: "clock.badge.exclamationmark")
                Label("A única saída sem beber é desligar o Mac — e fica registrado.", systemImage: "power")
            }
            .font(.system(size: 13.5))
            Spacer(minLength: 0)
        }
    }

    private var paginaPermissoes: some View {
        VStack(spacing: 14) {
            titulo("Só falta permitir", "Duas permissões e pronto. Os botões levam direto para o lugar certo.")
            PainelPermissoes(permissoes: permissoes)
                .padding(.horizontal, 20)
            if !permissoes.tudoOk {
                Text("O botão Começar libera assim que as duas estiverem permitidas.")
                    .font(.system(size: 12)).foregroundColor(.secondary)
            } else {
                Label("Tudo certo!", systemImage: "checkmark.circle.fill").foregroundColor(.green).font(.system(size: 14, weight: .semibold))
            }
            Spacer(minLength: 0)
        }
    }
}

@MainActor
final class JanelaBoasVindas {
    private var janela: NSWindow?

    func abrir(store: Store, permissoes: Permissoes, aoConcluir: @escaping @MainActor () -> Void) {
        if janela == nil {
            let j = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 780, height: 580),
                             styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
            j.titlebarAppearsTransparent = true
            j.titleVisibility = .hidden
            j.isReleasedWhenClosed = false
            j.contentView = NSHostingView(rootView: BoasVindasView(store: store, permissoes: permissoes, aoConcluir: aoConcluir))
            j.center()
            janela = j
        }
        NSApp.activate(ignoringOtherApps: true)
        janela?.makeKeyAndOrderFront(nil)
    }

    var visivel: Bool { janela?.isVisible ?? false }
    func fechar() { janela?.orderOut(nil) }
}
