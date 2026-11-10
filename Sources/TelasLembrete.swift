import SwiftUI
import AVFoundation

enum TelaFluxo: Equatable {
    case lembrete, quanto, camera, sucesso
    case falha(String)
}

@MainActor
final class Fluxo: ObservableObject {
    @Published var tela: TelaFluxo = .lembrete
    @Published var ml = 250
    @Published var copoSel = 1
    @Published var status = StatusVerificacao()
    @Published var novasConquistas: [Conquista] = []
    @Published var voluntario = false
    @Published var frase = ""
    @Published var bateuMetaAgora = false
    var sessao = AVCaptureSession()

    var acaoAbrirCamera: @MainActor () -> Void = {}
    var acaoCancelar: @MainActor () -> Void = {}
    var acaoRecomecar: @MainActor () -> Void = {}
    var acaoAjustesCamera: @MainActor () -> Void = {}

    func preparar(voluntario: Bool, store: Store) {
        self.voluntario = voluntario
        tela = .lembrete
        status = StatusVerificacao()
        novasConquistas = []
        bateuMetaAgora = false
        let copos = store.prefs.copos
        copoSel = min(max(0, store.prefs.copoPadrao), max(0, copos.count - 1))
        ml = copos.isEmpty ? 250 : copos[copoSel].ml
        frase = Gamificacao.frases.randomElement() ?? ""
    }
}

// MARK: - Raiz de cada monitor

struct OverlayRaiz: View {
    @ObservedObject var fluxo: Fluxo
    @ObservedObject var store: Store
    let principal: Bool

    var body: some View {
        ZStack {
            FundoAgua(store: store)
            if principal {
                CartaoFluxo(fluxo: fluxo, store: store)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "drop.fill").font(.system(size: 64)).foregroundColor(.white)
                    Text("Hora de beber água").font(.system(size: 44, weight: .heavy)).foregroundColor(.white)
                    Text("Use a outra tela para continuar").font(.system(size: 18, weight: .medium)).foregroundColor(.white.opacity(0.85))
                }
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
            }
        }
    }
}

struct CartaoFluxo: View {
    @ObservedObject var fluxo: Fluxo
    @ObservedObject var store: Store

    var body: some View {
        Group {
            switch fluxo.tela {
            case .lembrete: TelaLembrete(fluxo: fluxo, store: store)
            case .quanto: TelaQuanto(fluxo: fluxo, store: store)
            case .camera: TelaCamera(fluxo: fluxo, store: store)
            case .sucesso: TelaSucesso(fluxo: fluxo, store: store)
            case .falha(let msg): TelaFalha(fluxo: fluxo, mensagem: msg)
            }
        }
        .padding(.horizontal, 40)
        .padding(.top, 34)
        .padding(.bottom, 28)
        .frame(width: 600)
        .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Color.white.opacity(0.94)))
        .shadow(color: Color(red: 0.04, green: 0.2, blue: 0.43).opacity(0.35), radius: 50, y: 20)
        .environment(\.colorScheme, .light)
        .animation(.easeInOut(duration: 0.2), value: fluxo.tela)
    }
}

private struct Rodape: View {
    let texto: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill").font(.system(size: 11))
            Text(texto)
        }
        .font(.system(size: 12.5))
        .foregroundColor(Estilo.tinta3)
        .padding(.top, 14)
    }
}

private struct LinhaStat: View {
    let emoji: String
    let fundo: Color
    let texto: Text
    var body: some View {
        HStack(spacing: 10) {
            Text(emoji).font(.system(size: 15))
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(fundo))
            texto.font(.system(size: 14)).foregroundColor(Estilo.tinta2)
        }
    }
}

// MARK: 1. Lembrete

struct TelaLembrete: View {
    @ObservedObject var fluxo: Fluxo
    @ObservedObject var store: Store

    var subtitulo: String {
        if let u = store.ultimoGole {
            let min = Int(Date().timeIntervalSince(u) / 60)
            if min < 1 { return "Você acabou de beber — bora mais um?" }
            if min < 120 { return "Já faz \(min) minutos desde o último copo." }
            if calendario.isDateInToday(u) { return "Já faz \(min / 60) h desde o último copo." }
        }
        return "Primeiro copo do dia. Começa bem!"
    }

    var body: some View {
        let hoje = store.hojeML
        let meta = store.regras.metaML
        let seq = store.sequenciaAtual()
        let nivel = store.nivel()
        let palavraDias: String = seq == 1 ? "dia" : "dias"
        let palavraCopos: String = store.coposHoje == 1 ? "copo" : "copos"
        let textoSeq: Text = Text("\(seq) \(palavraDias)").bold().foregroundColor(Estilo.tinta) + Text(" seguidos na meta")
        let textoCopos: Text = Text("\(store.coposHoje) \(palavraCopos)").bold().foregroundColor(Estilo.tinta) + Text(" hoje")
        let textoNivel: Text = Text("Nível ") + Text(nivel.nome).bold().foregroundColor(Estilo.tinta)
        VStack(spacing: 6) {
            Image(systemName: "drop.fill")
                .font(.system(size: 58))
                .foregroundStyle(Estilo.gradienteAgua)
            Text(fluxo.voluntario ? "Registrar um copo" : "Hora de beber água\(store.nomeOuVazio)")
                .font(.system(size: 32, weight: .heavy))
                .foregroundColor(Estilo.tinta)
                .multilineTextAlignment(.center)
            Text(subtitulo).font(.system(size: 15)).foregroundColor(Estilo.tinta2)

            HStack(spacing: 24) {
                Anel(progresso: Double(hoje) / Double(max(1, meta))) {
                    VStack(spacing: 0) {
                        Text(store.fmt(hoje, unidade: false))
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .foregroundColor(Estilo.tinta)
                        Text("de \(store.fmt(meta))").font(.system(size: 12)).foregroundColor(Estilo.tinta2)
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    LinhaStat(emoji: "🔥", fundo: Color(red: 1, green: 0.95, blue: 0.9),
                              texto: textoSeq)
                    LinhaStat(emoji: "🥤", fundo: Color(red: 0.91, green: 0.95, blue: 1),
                              texto: textoCopos)
                    LinhaStat(emoji: "🌊", fundo: Color(red: 0.92, green: 0.98, blue: 0.94),
                              texto: textoNivel)
                }
            }
            .padding(.vertical, 18)

            if store.prefs.frases && !fluxo.frase.isEmpty {
                Text(fluxo.frase)
                    .font(.system(size: 13.5, weight: .medium))
                    .italic()
                    .foregroundColor(Estilo.tinta2)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 14)
            }

            Button("Beber agora") { fluxo.tela = .quanto }
                .buttonStyle(BotaoPrimario())
                .keyboardShortcut(.defaultAction)

            if fluxo.voluntario {
                Button("Cancelar") { fluxo.acaoCancelar() }
                    .buttonStyle(BotaoSecundario())
                    .padding(.top, 8)
            } else {
                Rodape(texto: "A tela só libera quando a câmera te ver bebendo")
            }
        }
    }
}

// MARK: 2. Quanto

struct TelaQuanto: View {
    @ObservedObject var fluxo: Fluxo
    @ObservedObject var store: Store

    var body: some View {
        let copos = store.prefs.copos
        let colunas = Array(repeating: GridItem(.flexible(), spacing: 12), count: min(4, max(1, copos.count)))
        VStack(spacing: 6) {
            Text("Quanto você vai beber?").font(.system(size: 32, weight: .heavy)).foregroundColor(Estilo.tinta)
            Text("Escolha o recipiente e ajuste se precisar.").font(.system(size: 15)).foregroundColor(Estilo.tinta2)

            LazyVGrid(columns: colunas, spacing: 12) {
                ForEach(Array(copos.enumerated()), id: \.element.id) { i, copo in
                    Button {
                        fluxo.copoSel = i
                        fluxo.ml = copo.ml
                    } label: {
                        VStack(spacing: 4) {
                            IconeCopo(copo: copo, tamanho: 56)
                            Text(store.fmt(copo.ml)).font(.system(size: 17, weight: .bold)).foregroundColor(Estilo.tinta)
                            Text(copo.nome).font(.system(size: 12)).foregroundColor(Estilo.tinta2).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(fluxo.copoSel == i ? Estilo.azul.opacity(0.10) : Estilo.tinta.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(fluxo.copoSel == i ? Estilo.azul : Color.clear, lineWidth: 2)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 18)

            if fluxo.copoSel < copos.count && copos[fluxo.copoSel].ml >= 500 {
                SeletorFracao(fluxo: fluxo, total: copos[fluxo.copoSel].ml)
                    .padding(.bottom, 14)
            }

            HStack(spacing: 16) {
                Button { fluxo.ml = max(50, fluxo.ml - 50) } label: {
                    Image(systemName: "minus").font(.system(size: 15, weight: .bold)).frame(width: 36, height: 36)
                        .background(Circle().fill(Estilo.tinta.opacity(0.07)))
                }.buttonStyle(.plain)
                Text(store.fmt(fluxo.ml))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(Estilo.tinta)
                    .frame(minWidth: 110)
                Button { fluxo.ml = min(2000, fluxo.ml + 50) } label: {
                    Image(systemName: "plus").font(.system(size: 15, weight: .bold)).frame(width: 36, height: 36)
                        .background(Circle().fill(Estilo.tinta.opacity(0.07)))
                }.buttonStyle(.plain)
            }
            .foregroundColor(Estilo.tinta)
            .padding(.bottom, 20)

            Button("Abrir câmera") { fluxo.acaoAbrirCamera() }
                .buttonStyle(BotaoPrimario())
                .keyboardShortcut(.defaultAction)
            Button("Voltar") { fluxo.tela = .lembrete }
                .buttonStyle(BotaoSecundario())
                .padding(.top, 8)
        }
    }
}

/// Para garrafas grandes: quanto da garrafa você bebeu agora.
private struct SeletorFracao: View {
    @ObservedObject var fluxo: Fluxo
    let total: Int
    static let opcoes: [(rotulo: String, f: Double)] = [("¼", 0.25), ("½", 0.5), ("¾", 0.75), ("Inteira", 1)]

    var body: some View {
        HStack(spacing: 8) {
            Text("Quanto da garrafa?").font(.system(size: 13, weight: .medium)).foregroundColor(Estilo.tinta2)
            ForEach(0..<SeletorFracao.opcoes.count, id: \.self) { i in
                let op = SeletorFracao.opcoes[i]
                let valor = Int((Double(total) * op.f / 10).rounded()) * 10
                let sel = fluxo.ml == valor
                Button { fluxo.ml = valor } label: {
                    Text(op.rotulo)
                        .font(.system(size: 13, weight: .bold))
                        .padding(.vertical, 6).padding(.horizontal, 12)
                        .foregroundColor(sel ? .white : Estilo.tinta)
                        .background(Capsule().fill(sel ? Estilo.azul : Estilo.tinta.opacity(0.07)))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: 3. Câmera

private struct Pilula: View {
    let texto: String
    let estado: Int  // 0 pendente · 1 em andamento · 2 ok
    var body: some View {
        HStack(spacing: 5) {
            if estado == 2 { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)) }
            if estado == 1 { Circle().frame(width: 7, height: 7) }
            Text(texto)
        }
        .font(.system(size: 12, weight: .semibold))
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .foregroundColor(estado == 2 ? Color(red: 0.08, green: 0.5, blue: 0.24) : (estado == 1 ? Color(red: 0.09, green: 0.4, blue: 0.79) : Estilo.tinta2))
        .background(Capsule().fill(estado == 2 ? Estilo.verde.opacity(0.14) : (estado == 1 ? Estilo.azul.opacity(0.14) : Estilo.tinta.opacity(0.06))))
    }
}

private struct CaixaDeteccao: View {
    let rotulo: String
    let cor: Color
    let rect: CGRect
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(cor, lineWidth: 2.5)
            .frame(width: rect.width, height: rect.height)
            .overlay(alignment: .topLeading) {
                Text(rotulo)
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.vertical, 3).padding(.horizontal, 8)
                    .background(RoundedRectangle(cornerRadius: 7).fill(cor))
                    .offset(x: -1, y: -24)
            }
            .position(x: rect.midX, y: rect.midY)
    }
}

struct TelaCamera: View {
    @ObservedObject var fluxo: Fluxo
    @ObservedObject var store: Store

    var body: some View {
        let s = fluxo.status
        VStack(spacing: 0) {
            Text("Beba na frente da câmera").font(.system(size: 26, weight: .heavy)).foregroundColor(Estilo.tinta)
            ZStack(alignment: .topLeading) {
                PreviewCamera(sessao: fluxo.sessao)
                GeometryReader { g in
                    if let r = s.rostoRect {
                        CaixaDeteccao(rotulo: "Rosto", cor: Estilo.verde, rect: mapearRetangulo(r, em: g.size, aspecto: s.aspecto))
                    }
                    if let m = s.maoRect {
                        CaixaDeteccao(rotulo: s.copo ? "Copo" : "Mão", cor: Estilo.azul, rect: mapearRetangulo(m, em: g.size, aspecto: s.aspecto))
                    }
                }
                HStack(spacing: 6) {
                    Circle().fill(Color(red: 1, green: 0.3, blue: 0.3)).frame(width: 7, height: 7)
                    Text("AO VIVO · nada é gravado")
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .padding(.vertical, 4).padding(.horizontal, 9)
                .background(Capsule().fill(Color.black.opacity(0.45)))
                .padding(12)
            }
            .frame(width: 500, height: 320)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.top, 16).padding(.bottom, 14)

            HStack(spacing: 8) {
                Pilula(texto: "Rosto", estado: s.etapa >= 1 ? 2 : (s.rosto ? 1 : 0))
                Pilula(texto: "Na boca", estado: s.etapa >= 2 ? 2 : (s.naBoca ? 1 : 0))
                Pilula(texto: s.etapa == 1 ? String(format: "Bebendo %.1f s", s.segundos) : "Bebendo",
                       estado: s.etapa >= 2 ? 2 : (s.etapa == 1 && s.naBoca ? 1 : 0))
                Pilula(texto: "Copo/garrafa", estado: s.copoConfirmado ? 2 : (s.copo ? 1 : 0))
                Pilula(texto: "Afastar", estado: s.etapa >= 3 ? 2 : (s.etapa == 2 ? 1 : 0))
            }
            .padding(.bottom, 12)

            BarraProgresso(valor: s.progresso).padding(.horizontal, 10)

            Text(s.mensagem)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Estilo.tinta)
                .padding(.top, 14)

            if s.etapa >= 1 && !s.copoConfirmado && s.segundos >= 2 && !s.diagnostico.isEmpty {
                Text("A câmera está vendo: \(s.diagnostico)")
                    .font(.system(size: 11))
                    .foregroundColor(Estilo.tinta3)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.top, 4)
            }

            HStack(spacing: 10) {
                Button("Recomeçar") { fluxo.acaoRecomecar() }.buttonStyle(BotaoSecundario())
                if fluxo.voluntario {
                    Button("Cancelar") { fluxo.acaoCancelar() }.buttonStyle(BotaoSecundario())
                }
            }
            .padding(.top, 12)

            Rodape(texto: "Analisado no seu Mac e descartado na hora — nenhuma foto é salva")
        }
    }
}

// MARK: 4. Sucesso

struct TelaSucesso: View {
    @ObservedObject var fluxo: Fluxo
    @ObservedObject var store: Store
    @State private var encher = 0.0

    var body: some View {
        let hoje = store.hojeML
        let meta = store.regras.metaML
        let inicio: LocalizedStringKey = fluxo.bateuMetaAgora ? "🎉 Meta do dia batida! " : "Boa! Agora são "
        let resumo: Text = Text(inicio)
            + Text("\(store.fmt(hoje, unidade: false)) de \(store.fmt(meta))").bold().foregroundColor(Estilo.tinta)
            + Text(" hoje.")
        VStack(spacing: 6) {
            ZStack {
                IconeCopo(copo: copoAtual, tamanho: 110)
                    .mask(
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            Rectangle().frame(height: 110 * encher)
                        }
                        .frame(height: 110)
                    )
                IconeCopo(copo: copoAtual, tamanho: 110).opacity(0.18)
            }
            Text("+\(store.fmt(fluxo.ml))")
                .font(.system(size: 54, weight: .heavy, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [Color(red: 0.27, green: 0.66, blue: 1), Color(red: 0.09, green: 0.40, blue: 0.79)],
                                                startPoint: .top, endPoint: .bottom))
            resumo
                .font(.system(size: 16))
                .foregroundColor(Estilo.tinta2)
            BarraProgresso(valor: Double(hoje) / Double(max(1, meta))).padding(.horizontal, 40).padding(.top, 10)

            ForEach(fluxo.novasConquistas.prefix(2)) { c in
                HStack(spacing: 14) {
                    Text(c.emoji).font(.system(size: 22))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(LinearGradient(colors: [Color(red: 1, green: 0.82, blue: 0.48), Color(red: 1, green: 0.6, blue: 0.18)],
                                                                 startPoint: .top, endPoint: .bottom)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Conquista desbloqueada: \(c.titulo)").font(.system(size: 14, weight: .bold)).foregroundColor(Estilo.tinta)
                        Text(c.descricao).font(.system(size: 12.5)).foregroundColor(Estilo.tinta2)
                    }
                }
                .padding(.vertical, 12).padding(.horizontal, 16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.orange.opacity(0.12)))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange.opacity(0.3), lineWidth: 1))
                .padding(.top, 12)
            }

            Text(rodape).font(.system(size: 13.5)).foregroundColor(Estilo.tinta3).padding(.top, 14)
        }
        .onAppear { withAnimation(.easeOut(duration: 1.1)) { encher = 1 } }
    }

    var copoAtual: Copo {
        let copos = store.prefs.copos
        return fluxo.copoSel < copos.count ? copos[fluxo.copoSel] : Copo(nome: "Copo", ml: 250, icone: "copo")
    }

    var rodape: String {
        if store.estaAtivo() {
            return "Próximo lembrete às \(Formatos.hora.string(from: store.estado.proximo))"
        }
        return "Sem mais lembretes por agora"
    }
}

// MARK: Falha

struct TelaFalha: View {
    @ObservedObject var fluxo: Fluxo
    let mensagem: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 48)).foregroundColor(.orange)
            Text(mensagem).font(.system(size: 16)).foregroundColor(Estilo.tinta).multilineTextAlignment(.center)
            Button("Tentar de novo") { fluxo.acaoAbrirCamera() }
                .buttonStyle(BotaoPrimario())
                .keyboardShortcut(.defaultAction)
                .padding(.top, 8)
            Button("Abrir Ajustes da Câmera (libera a tela por 45 s)") { fluxo.acaoAjustesCamera() }
                .buttonStyle(BotaoSecundario())
            if fluxo.voluntario {
                Button("Cancelar") { fluxo.acaoCancelar() }.buttonStyle(BotaoSecundario())
            }
        }
    }
}
