import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine

@MainActor
final class ModeloAjustes: ObservableObject {
    @Published var aba = "geral"
    @Published var rascunho: Regras
    @Published var mensagem = ""

    init(regras: Regras) { rascunho = regras }
}

/// Ações de teste que os Ajustes podem disparar.
@MainActor
final class AcoesAjustes {
    var testarAgora: @MainActor () -> Void = {}
    var testarPreAviso: @MainActor () -> Void = {}
    var mostrarWidget: @MainActor () -> Void = {}
}

/// Linha com um botão de teste à direita.
private struct LinhaTeste: View {
    let texto: String
    let botao: String
    var ultima = true
    let acao: () -> Void
    var body: some View {
        LinhaAjuste(titulo: texto, ultima: ultima) {
            Button(action: acao) { Label(botao, systemImage: "play.fill") }
                .buttonStyle(BotaoAgua(tipo: .secundario))
        }
    }
}

struct PaginaAjustes: Identifiable {
    let id: String
    let titulo: String
    let icone: String
    let cor: Color

    static let todas: [PaginaAjustes] = [
        PaginaAjustes(id: "geral", titulo: "Geral", icone: "gearshape.fill", cor: Color(hex: "#6B7A90")),
        PaginaAjustes(id: "lembretes", titulo: "Lembretes", icone: "bell.badge.fill", cor: Color(hex: "#F06A6A")),
        PaginaAjustes(id: "chamadas", titulo: "Chamadas", icone: "video.fill", cor: Color(hex: "#2DBE7E")),
        PaginaAjustes(id: "meta", titulo: "Meta e copos", icone: "drop.fill", cor: Color(hex: "#2F8FF0")),
        PaginaAjustes(id: "camera", titulo: "Câmera", icone: "camera.viewfinder", cor: Color(hex: "#8A63E8")),
        PaginaAjustes(id: "aparencia", titulo: "Aparência", icone: "paintpalette.fill", cor: Color(hex: "#EC6FA6")),
        PaginaAjustes(id: "widget", titulo: "Widget", icone: "rectangle.on.rectangle", cor: Color(hex: "#20B2C4")),
        PaginaAjustes(id: "historico", titulo: "Histórico", icone: "chart.bar.fill", cor: Color(hex: "#F59E3B")),
        PaginaAjustes(id: "permissoes", titulo: "Permissões", icone: "lock.shield.fill", cor: Color(hex: "#5468E8")),
        PaginaAjustes(id: "atualizacoes", titulo: "Atualizações", icone: "arrow.down.circle.fill", cor: Color(hex: "#1FA4E8")),
    ]
}

// MARK: - Janela

struct AjustesView: View {
    @ObservedObject var store: Store
    @ObservedObject var modelo: ModeloAjustes
    @ObservedObject var atualizador: Atualizador
    @ObservedObject var permissoes: Permissoes
    let acoes: AcoesAjustes

    var body: some View {
        VStack(spacing: 0) {
            BarraIcones(modelo: modelo, atualizador: atualizador, permissoes: permissoes)
            HStack(alignment: .center) {
                Text(PaginaAjustes.todas.first { $0.id == modelo.aba }?.titulo ?? "")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundColor(Estilo.tinta)
                Spacer()
                Button { acoes.testarAgora() } label: {
                    Label("Testar agora: beber água", systemImage: "drop.fill")
                }
                .buttonStyle(BotaoAgua(tipo: .primario, grande: true))
                .help("Abre a tela de lembrete agora, do começo ao fim (registra o copo se você beber).")
            }
            .padding(.horizontal, 26)
            .padding(.top, 16)
            conteudo
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            BarraAplicar(store: store, modelo: modelo)
        }
        .frame(width: 900, height: 720)
        .background(Marca.fundo)
        .environment(\.colorScheme, .light)
    }

    @ViewBuilder var conteudo: some View {
        switch modelo.aba {
        case "lembretes": AbaLembretes(store: store, modelo: modelo, acoes: acoes)
        case "chamadas": AbaChamadas(modelo: modelo)
        case "meta": AbaMeta(store: store, modelo: modelo)
        case "camera": AbaCamera(modelo: modelo, acoes: acoes)
        case "aparencia": AbaAparencia(store: store, acoes: acoes)
        case "widget": AbaWidget(store: store, acoes: acoes)
        case "historico": AbaHistorico(store: store)
        case "permissoes": PaginaRolavel { PainelPermissoes(permissoes: permissoes) }
        case "atualizacoes": AbaAtualizacoes(store: store, atualizador: atualizador)
        default: AbaGeral(store: store, acoes: acoes)
        }
    }
}

/// Navegação: ícones no topo, no estilo do LembreteAgua.
struct BarraIcones: View {
    @ObservedObject var modelo: ModeloAjustes
    @ObservedObject var atualizador: Atualizador
    @ObservedObject var permissoes: Permissoes

    var body: some View {
        HStack(spacing: 4) {
            ForEach(PaginaAjustes.todas) { p in
                let sel = modelo.aba == p.id
                VStack(spacing: 5) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: p.icone)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(p.cor.gradient))
                            .shadow(color: p.cor.opacity(sel ? 0.45 : 0), radius: 6, y: 3)
                        if temAlerta(p.id) {
                            Circle().fill(Color.red).frame(width: 10, height: 10)
                                .overlay(Circle().stroke(Color.white, lineWidth: 2)).offset(x: 4, y: -4)
                        }
                    }
                    Text(p.titulo)
                        .font(.system(size: 11, weight: sel ? .bold : .medium))
                        .foregroundColor(sel ? Estilo.tinta : Estilo.tinta2)
                        .lineLimit(1)
                        .fixedSize()
                }
                .frame(width: 80, height: 62)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(sel ? Color.white : Color.clear))
                .shadow(color: Color.black.opacity(sel ? 0.06 : 0), radius: 6, y: 2)
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(.easeOut(duration: 0.15)) { modelo.aba = p.id } }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.55))
        .overlay(alignment: .bottom) { Rectangle().fill(Marca.borda).frame(height: 1) }
    }

    func temAlerta(_ id: String) -> Bool {
        switch id {
        case "permissoes": return !permissoes.tudoOk
        case "atualizacoes": return atualizador.disponivel != nil
        default: return false
        }
    }
}

/// Mudanças de regras só valem quando aplicadas — e as que afrouxam, só amanhã.
struct BarraAplicar: View {
    @ObservedObject var store: Store
    @ObservedObject var modelo: ModeloAjustes

    var body: some View {
        let mudou = modelo.rascunho != store.regras && modelo.rascunho != store.estado.pendente
        let frouxa = modelo.rascunho.maisFrouxa(que: store.regras) && !store.diaDaInstalacao
        HStack(spacing: 12) {
            Image(systemName: mudou ? (frouxa ? "clock.badge.exclamationmark" : "checkmark.seal.fill") : "lock.shield.fill")
                .font(.system(size: 18))
                .foregroundColor(mudou ? (frouxa ? .orange : Estilo.azul) : Estilo.tinta3)
            VStack(alignment: .leading, spacing: 2) {
                Text(tituloStatus(mudou: mudou, frouxa: frouxa)).font(.system(size: 12.5, weight: .semibold)).foregroundColor(Estilo.tinta)
                Text(store.diaDaInstalacao ? "Hoje é o dia da instalação: tudo vale na hora para você configurar à vontade."
                                           : "Aparência, som, copos e widget mudam na hora. Horários, meta e rigor que afrouxam só valem amanhã.")
                    .font(.system(size: 11)).foregroundColor(Estilo.tinta3)
            }
            Spacer()
            if store.estado.pendente != nil && !mudou {
                Button("Cancelar agendamento") {
                    store.estado.pendente = nil
                    store.estado.pendenteAPartirDe = nil
                    modelo.rascunho = store.regras
                }
                .buttonStyle(BotaoAgua(tipo: .discreto))
            }
            if mudou {
                Button("Descartar") { modelo.rascunho = store.regras; modelo.mensagem = "" }
                    .buttonStyle(BotaoAgua(tipo: .discreto))
                Button(frouxa ? "Agendar para amanhã" : "Aplicar mudanças") {
                    modelo.mensagem = store.aplicar(modelo.rascunho)
                }
                .buttonStyle(BotaoAgua(tipo: .primario))
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(Color.white)
        .overlay(alignment: .top) { Rectangle().fill(Marca.borda).frame(height: 1) }
    }

    func tituloStatus(mudou: Bool, frouxa: Bool) -> String {
        if mudou {
            return frouxa ? "Essas mudanças afrouxam as regras: vão valer a partir de amanhã."
                          : "Essas mudanças deixam tudo igual ou mais rígido: valem na hora."
        }
        if let d = store.estado.pendenteAPartirDe, store.estado.pendente != nil {
            return "Há mudanças agendadas para \(Formatos.diaCurto.string(from: d))."
        }
        if !modelo.mensagem.isEmpty { return modelo.mensagem }
        return "Anti-autoengano ativo"
    }
}

// MARK: - Geral

struct AbaGeral: View {
    @ObservedObject var store: Store
    let acoes: AcoesAjustes

    var statusAgora: String {
        if store.estaAtivo() {
            return "Lembretes ativos. Próximo às \(Formatos.hora.string(from: store.estado.proximo))."
        }
        if store.regras.pararAoBaterMeta && store.hojeML >= store.regras.metaML { return "Meta de hoje batida — sem mais lembretes hoje." }
        return "Fora do horário de lembretes agora."
    }

    var body: some View {
        PaginaRolavel {
            CartaoSecao(titulo: "Agora", icone: "clock") {
                LinhaAjuste(titulo: "Situação", detalhe: statusAgora) { EmptyView() }
                LinhaAjuste(titulo: "Hoje", detalhe: "\(store.coposHoje) copos registrados") {
                    Text("\(store.fmt(store.hojeML)) de \(store.fmt(store.regras.metaML))")
                        .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(Estilo.azul)
                }
                LinhaTeste(texto: "Veja a experiência completa, do lembrete ao copo registrado.", botao: "Testar") { acoes.testarAgora() }
            }
            CartaoSecao(titulo: "Você", icone: "person.fill") {
                LinhaAjuste(titulo: "Como te chamar", detalhe: "Aparece na tela de lembrete") {
                    CampoAgua(dica: "Seu nome (opcional)", texto: $store.prefs.nome, largura: 220)
                }
                LinhaInterruptor(titulo: "Frases motivacionais", detalhe: "Uma dica diferente a cada lembrete", ligado: $store.prefs.frases)
                LinhaAjuste(titulo: "Unidade", ultima: true) {
                    SegmentosAgua(opcoes: [("ml", "Mililitros"), ("oz", "Onças")], selecao: $store.prefs.unidade)
                }
            }
            CartaoSecao(titulo: "Barra de menus", icone: "menubar.rectangle") {
                LinhaAjuste(titulo: "Ao lado da gotinha", detalhe: "Muda na hora — olhe o canto superior direito", ultima: true) {
                    SegmentosAgua(opcoes: [("ml", "1,5 L"), ("pct", "60%"), ("icone", "Só ícone")], selecao: $store.prefs.barraMenu)
                }
            }
            CartaoSecao(titulo: "Saída de emergência", icone: "exclamationmark.shield") {
                TextoAjuda(texto: "Não existe botão de pular. Cmd+Option+Esc, Cmd+Tab, Dock e menus ficam bloqueados enquanto a tela azul estiver aberta. A única saída sem beber é desligar o Mac — e isso fica registrado no seu histórico.")
            }
        }
    }
}

// MARK: - Lembretes

struct AbaLembretes: View {
    @ObservedObject var store: Store
    @ObservedObject var modelo: ModeloAjustes
    let acoes: AcoesAjustes
    static let ordemDias = [2, 3, 4, 5, 6, 7, 1]
    static let nomesDias = [1: "D", 2: "S", 3: "T", 4: "Q", 5: "Q", 6: "S", 7: "S"]
    static let nomesLongos = [1: "domingo", 2: "segunda", 3: "terça", 4: "quarta", 5: "quinta", 6: "sexta", 7: "sábado"]
    static let intervalos: [(valor: Int, rotulo: String)] = [
        (10, "10 min"), (15, "15 min"), (20, "20 min"), (30, "30 min"), (45, "45 min"),
        (60, "1 hora"), (75, "1h15"), (90, "1h30"), (120, "2 horas"),
    ]

    var body: some View {
        PaginaRolavel {
            CartaoSecao(titulo: "Quando a tela azul pode aparecer", icone: "calendar") {
                LinhaAjuste(titulo: "Começa às") { HoraAgua(minutos: $modelo.rascunho.inicioMin) }
                LinhaAjuste(titulo: "Termina às") { HoraAgua(minutos: $modelo.rascunho.fimMin) }
                LinhaAjuste(titulo: "Dias da semana") {
                    HStack(spacing: 6) {
                        ForEach(AbaLembretes.ordemDias, id: \.self) { d in
                            let on = modelo.rascunho.dias.contains(d)
                            Text(AbaLembretes.nomesDias[d] ?? "?")
                                .font(.system(size: 12, weight: .bold))
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(on ? AnyShapeStyle(Estilo.gradienteBotao) : AnyShapeStyle(Marca.azulClaro)))
                                .foregroundColor(on ? .white : Estilo.tinta3)
                                .contentShape(Circle())
                                .onTapGesture {
                                    if on { modelo.rascunho.dias.removeAll { $0 == d } } else { modelo.rascunho.dias.append(d) }
                                }
                                .help(AbaLembretes.nomesLongos[d] ?? "")
                        }
                    }
                }
                LinhaAjuste(titulo: "Lembrar a cada") {
                    MenuAgua(opcoes: AbaLembretes.intervalos, selecao: $modelo.rascunho.intervaloMin)
                }
                LinhaTeste(texto: "Quer ver como fica? Abre a tela de lembrete agora.", botao: "Testar") { acoes.testarAgora() }
            }

            CartaoSecao(titulo: "Pausas", icone: "pause.circle") {
                LinhaInterruptor(titulo: "Pausa de almoço", ligado: $modelo.rascunho.pausaAlmoco)
                if modelo.rascunho.pausaAlmoco {
                    LinhaAjuste(titulo: "Almoço começa às") { HoraAgua(minutos: $modelo.rascunho.almocoInicioMin) }
                    LinhaAjuste(titulo: "Almoço termina às") { HoraAgua(minutos: $modelo.rascunho.almocoFimMin) }
                }
                LinhaInterruptor(titulo: "Parar depois de bater a meta", detalhe: "Sem lembretes pelo resto do dia", ultima: true,
                                 ligado: $modelo.rascunho.pararAoBaterMeta)
            }

            CartaoSecao(titulo: "Pré-aviso", icone: "bell") {
                LinhaInterruptor(titulo: "Avisar antes da tela azul", detalhe: "Um balãozinho no canto da tela", ligado: $store.prefs.preAviso)
                if store.prefs.preAviso {
                    LinhaAjuste(titulo: "Antecedência") {
                        SegmentosAgua(opcoes: [(30, "30 s"), (60, "1 min"), (120, "2 min"), (300, "5 min")], selecao: $store.prefs.preAvisoSeg)
                    }
                }
                LinhaTeste(texto: "Mostra agora o aviso que aparece no canto da tela.", botao: "Testar pré-aviso") { acoes.testarPreAviso() }
            }
        }
    }
}

// MARK: - Chamadas

struct AbaChamadas: View {
    @ObservedObject var modelo: ModeloAjustes
    @State private var resultado = ""

    var body: some View {
        PaginaRolavel {
            CartaoSecao(titulo: "Durante chamadas e apresentações", icone: "video") {
                LinhaInterruptor(titulo: "Não interromper chamadas", detalhe: "Meet, Zoom, Teams, FaceTime, Slack…", ligado: $modelo.rascunho.adiarEmChamadas)
                if modelo.rascunho.adiarEmChamadas {
                    LinhaAjuste(titulo: "Esperar a chamada acabar") {
                        MenuAgua(opcoes: [(0, "Sempre — nunca interromper"), (15, "No máximo 15 min"), (30, "No máximo 30 min"),
                                          (60, "No máximo 60 min"), (90, "No máximo 90 min")],
                                 selecao: $modelo.rascunho.adiarMaxMin)
                    }
                    LinhaInterruptor(titulo: "Microfone em uso também conta", detalhe: "Pega chamadas só de áudio e apresentações", ultima: true,
                                     ligado: $modelo.rascunho.usarMicrofone)
                }
            }
            CartaoSecao(titulo: "Testar", icone: "play.circle") {
                LinhaAjuste(titulo: "Entre numa chamada (ou abra o FaceTime) e veja o que o app detecta.", ultima: resultado.isEmpty) {
                    Button("Verificar agora") {
                        resultado = Chamada.descricao(usarMicrofone: modelo.rascunho.usarMicrofone)
                    }
                    .buttonStyle(BotaoAgua(tipo: .secundario))
                }
                if !resultado.isEmpty {
                    Text(resultado).font(.system(size: 12.5, weight: .semibold)).foregroundColor(Estilo.tinta).padding(.vertical, 10)
                }
            }
        }
    }
}

// MARK: - Meta e copos

struct AbaMeta: View {
    @ObservedObject var store: Store
    @ObservedObject var modelo: ModeloAjustes
    @State private var peso = 70.0
    @State private var ativo = false
    @State private var calor = false
    @State private var mostrarGaleria = false

    var sugestao: Int {
        let base = peso * 35 + (ativo ? 500 : 0) + (calor ? 500 : 0)
        return Int((base / 100).rounded()) * 100
    }

    /// Liga um campo do copo pelo id (e não pela posição), para apagar sem travar.
    func campoCopo<T>(_ id: UUID, _ k: WritableKeyPath<Copo, T>, _ padrao: T) -> Binding<T> {
        let lista = $store.prefs.copos
        return Binding<T>(
            get: { lista.wrappedValue.first(where: { $0.id == id })?[keyPath: k] ?? padrao },
            set: { v in
                if let i = lista.wrappedValue.firstIndex(where: { $0.id == id }) { lista.wrappedValue[i][keyPath: k] = v }
            })
    }

    var body: some View {
        PaginaRolavel {
            CartaoSecao(titulo: "Meta diária", icone: "target") {
                LinhaAjuste(titulo: "Quanto beber por dia", ultima: true) {
                    HStack(spacing: 14) {
                        SliderAgua(valor: Binding(get: { Double(modelo.rascunho.metaML) },
                                                  set: { modelo.rascunho.metaML = Int(($0 / 100).rounded()) * 100 }),
                                   faixa: 1000...5000, passo: 100)
                            .frame(width: 220)
                        PassoAgua(valor: $modelo.rascunho.metaML, faixa: 500...6000, passo: 100) { store.fmt($0) }
                    }
                }
            }
            CartaoSecao(titulo: "Calculadora de meta", icone: "function") {
                LinhaAjuste(titulo: "Seu peso") {
                    HStack(spacing: 12) {
                        SliderAgua(valor: $peso, faixa: 40...150, passo: 1).frame(width: 220)
                        Text("\(Int(peso)) kg").font(.system(size: 13, weight: .bold, design: .rounded)).monospacedDigit().frame(width: 56)
                    }
                }
                LinhaInterruptor(titulo: "Faço atividade física na maioria dos dias", ligado: $ativo)
                LinhaInterruptor(titulo: "Moro/trabalho num lugar quente", ligado: $calor)
                LinhaAjuste(titulo: "Sugestão: \(store.fmt(sugestao)) por dia",
                            detalhe: "~35 ml por kg, +500 ml para quem treina, +500 ml no calor. Não substitui orientação médica.", ultima: true) {
                    Button("Usar sugestão") { modelo.rascunho.metaML = sugestao }.buttonStyle(BotaoAgua(tipo: .secundario))
                }
            }
            CartaoSecao(titulo: "Seus copos e garrafas", icone: "cup.and.saucer") {
                ForEach(store.prefs.copos) { copo in
                    LinhaCopo(copo: copo, nome: campoCopo(copo.id, \.nome, ""), ml: campoCopo(copo.id, \.ml, 250),
                              desenho: campoCopo(copo.id, \.icone, "copo"), podeApagar: store.prefs.copos.count > 1) {
                        let id = copo.id
                        NSApp.keyWindow?.makeFirstResponder(nil)   // encerra a edição antes de apagar
                        DispatchQueue.main.async {
                            if store.prefs.copos.count > 1 { store.prefs.copos.removeAll { $0.id == id } }
                            if store.prefs.copoPadrao >= store.prefs.copos.count { store.prefs.copoPadrao = 0 }
                        }
                    }
                }
                LinhaAjuste(titulo: "Já vem selecionado na hora de beber", ultima: true) {
                    MenuAgua(opcoes: store.prefs.copos.enumerated().map { (valor: $0.offset, rotulo: "\($0.element.nome) · \($0.element.ml) ml") },
                             selecao: $store.prefs.copoPadrao)
                }
            }
            HStack {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { mostrarGaleria.toggle() }
                } label: {
                    Label(mostrarGaleria ? "Fechar galeria" : "Adicionar garrafa ou copo", systemImage: mostrarGaleria ? "xmark" : "plus")
                }
                .buttonStyle(BotaoAgua(tipo: mostrarGaleria ? .discreto : .primario, grande: true))
                .disabled(store.prefs.copos.count >= 12 && !mostrarGaleria)
                Spacer()
            }
            if mostrarGaleria {
                CartaoSecao(titulo: "Galeria de garrafas", icone: "square.grid.2x2") {
                    GaleriaGarrafas { novo in
                        guard store.prefs.copos.count < 12 else { return }
                        store.prefs.copos.append(novo)
                    }
                    .padding(.vertical, 12)
                }
            }
        }
    }
}

private struct LinhaCopo: View {
    let copo: Copo
    @Binding var nome: String
    @Binding var ml: Int
    @Binding var desenho: String
    let podeApagar: Bool
    let apagar: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            IconeCopo(copo: copo, tamanho: 40)
            CampoAgua(dica: "Nome", texto: $nome)
            PassoAgua(valor: $ml, faixa: 50...3000, passo: 10) { "\($0) ml" }
            MenuAgua(opcoes: Catalogo.nomesDesenhos.map { (valor: $0.id, rotulo: $0.nome) }, selecao: $desenho)
            Button(action: apagar) {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(podeApagar ? Color(hex: "#E5484D") : Estilo.tinta3)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color(hex: "#FDECEC").opacity(podeApagar ? 1 : 0.4)))
            }
            .buttonStyle(.plain)
            .disabled(!podeApagar)
        }
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) { Rectangle().fill(Marca.borda.opacity(0.7)).frame(height: 1) }
    }
}

// MARK: - Câmera

struct AbaCamera: View {
    @ObservedObject var modelo: ModeloAjustes
    let acoes: AcoesAjustes

    var body: some View {
        PaginaRolavel {
            CartaoSecao(titulo: "Rigor da verificação", icone: "camera.viewfinder") {
                LinhaAjuste(titulo: "Tempo bebendo exigido") {
                    HStack(spacing: 12) {
                        SliderAgua(valor: $modelo.rascunho.segundosBebendo, faixa: 1.5...6, passo: 0.5).frame(width: 200)
                        Text(String(format: "%.1f s", modelo.rascunho.segundosBebendo))
                            .font(.system(size: 13, weight: .bold, design: .rounded)).monospacedDigit().frame(width: 46)
                    }
                }
                LinhaInterruptor(titulo: "Exigir que a câmera reconheça o copo ou a garrafa",
                                 detalhe: "Desligado: basta rosto + mão na boca pelo tempo exigido",
                                 ligado: $modelo.rascunho.exigirCopo)
                LinhaTeste(texto: "Teste a câmera com essas regras (aplique antes, se mudou algo).", botao: "Testar câmera") { acoes.testarAgora() }
            }
            CartaoSecao(titulo: "Como funciona", icone: "list.number") {
                ForEach(Array(AbaCamera.passos.enumerated()), id: \.offset) { i, p in
                    LinhaAjuste(titulo: p.1, ultima: i == AbaCamera.passos.count - 1) {
                        Image(systemName: p.0).foregroundColor(Estilo.azul).font(.system(size: 15, weight: .semibold))
                    }
                }
            }
            CartaoSecao(titulo: "Privacidade", icone: "lock.shield") {
                LinhaAjuste(titulo: "Tudo é analisado no seu Mac, na hora, pelo Vision da Apple.") {
                    Image(systemName: "cpu").foregroundColor(Estilo.verde)
                }
                LinhaAjuste(titulo: "Nenhuma foto ou vídeo é salvo, nem enviado para lugar nenhum.", ultima: true) {
                    Image(systemName: "checkmark.shield.fill").foregroundColor(Estilo.verde)
                }
            }
        }
    }

    static let passos: [(String, String)] = [
        ("1.circle.fill", "Rosto visível e livre por um instante"),
        ("2.circle.fill", "Copo ou garrafa na boca pelo tempo exigido"),
        ("3.circle.fill", "O copo/garrafa é reconhecido (pode mostrar de frente)"),
        ("4.circle.fill", "Afastar da boca — prova que não é uma foto parada"),
        ("video.slash.fill", "Câmeras virtuais (OBS, Snap…) não são aceitas"),
    ]
}

// MARK: - Aparência e som

struct AbaAparencia: View {
    @ObservedObject var store: Store
    let acoes: AcoesAjustes

    var body: some View {
        PaginaRolavel {
            CartaoSecao(titulo: "Tela de lembrete", icone: "paintpalette") {
                LinhaAjuste(titulo: "Tema") {
                    HStack(spacing: 14) {
                        ForEach(Tema.todos, id: \.id) { t in
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(LinearGradient(colors: t.cores, startPoint: .top, endPoint: .bottom))
                                    .frame(width: 34, height: 34)
                                    .overlay(Circle().stroke(store.prefs.tema == t.id ? Estilo.azul : Color.clear, lineWidth: 3).padding(-4))
                                Text(t.nome).font(.system(size: 10.5, weight: .medium)).foregroundColor(Estilo.tinta2)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { store.prefs.tema = t.id }
                        }
                    }
                }
                LinhaAjuste(titulo: "Intensidade da cor") {
                    HStack(spacing: 12) {
                        SliderAgua(valor: $store.prefs.opacidade, faixa: 0.3...0.9).frame(width: 200)
                        Text("\(Int(store.prefs.opacidade * 100))%").font(.system(size: 13, weight: .bold, design: .rounded)).monospacedDigit().frame(width: 44)
                    }
                }
                LinhaInterruptor(titulo: "Ondas e bolhas animadas", ligado: $store.prefs.animacoes)
                LinhaTeste(texto: "Veja o tema e a intensidade na tela de verdade.", botao: "Pré-visualizar") { acoes.testarAgora() }
            }
            CartaoSecao(titulo: "Som", icone: "speaker.wave.2") {
                LinhaInterruptor(titulo: "Tocar som quando a tela aparecer", ultima: !store.prefs.somAtivo, ligado: $store.prefs.somAtivo)
                if store.prefs.somAtivo {
                    LinhaAjuste(titulo: "Som") {
                        HStack(spacing: 8) {
                            MenuAgua(opcoes: Sons.disponiveis.map { (valor: $0, rotulo: $0) }, selecao: $store.prefs.som)
                            Button { Sons.tocar(store.prefs.som, volume: store.prefs.volume) } label: { Label("Ouvir", systemImage: "play.fill") }
                                .buttonStyle(BotaoAgua(tipo: .secundario))
                        }
                    }
                    LinhaAjuste(titulo: "Volume", ultima: true) {
                        HStack(spacing: 8) {
                            SliderAgua(valor: $store.prefs.volume, faixa: 0.1...1).frame(width: 200)
                            Button { Sons.tocar(store.prefs.som, volume: store.prefs.volume) } label: { Image(systemName: "play.fill") }
                                .buttonStyle(BotaoAgua(tipo: .secundario))
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Widget

struct AbaWidget: View {
    @ObservedObject var store: Store
    let acoes: AcoesAjustes

    var body: some View {
        PaginaRolavel {
            CartaoSecao(titulo: "Widget na área de trabalho", icone: "rectangle.on.rectangle") {
                LinhaInterruptor(titulo: "Mostrar widget", detalhe: "Fica atrás das janelas, no monitor principal", ligado: $store.prefs.widgetAtivo)
                LinhaAjuste(titulo: "Posição") {
                    MenuAgua(opcoes: [("supEsq", "Superior esquerdo"), ("supDir", "Superior direito"),
                                      ("infEsq", "Inferior esquerdo"), ("infDir", "Inferior direito")],
                             selecao: $store.prefs.widgetPosicao)
                }
                LinhaAjuste(titulo: "Tamanho") {
                    SegmentosAgua(opcoes: [("pequeno", "Pequeno"), ("medio", "Médio"), ("grande", "Grande")], selecao: $store.prefs.widgetTamanho)
                }
                LinhaAjuste(titulo: "Estilo") {
                    SegmentosAgua(opcoes: [("escuro", "Escuro"), ("claro", "Claro")], selecao: $store.prefs.widgetEstilo)
                }
                LinhaTeste(texto: "Esconde os Ajustes para você ver o widget na mesa.", botao: "Ver na área de trabalho") { acoes.mostrarWidget() }
            }
            CartaoSecao(titulo: "Prévia", icone: "eye") {
                HStack {
                    Spacer()
                    WidgetView(store: store)
                        .padding(22)
                        .background(RoundedRectangle(cornerRadius: 16).fill(
                            LinearGradient(colors: [Color(red: 0.42, green: 0.36, blue: 0.84), Color(red: 0.85, green: 0.56, blue: 0.72)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)))
                    Spacer()
                }
                .padding(.vertical, 12)
            }
        }
    }
}

// MARK: - Histórico

struct AbaHistorico: View {
    @ObservedObject var store: Store

    var body: some View {
        let nivel = store.nivel()
        PaginaRolavel {
            HStack(spacing: 12) {
                cartaoNumero("Hoje", store.fmt(store.hojeML), "\(store.coposHoje) copos")
                cartaoNumero("Sequência", "🔥 \(store.sequenciaAtual())", "dias na meta")
                cartaoNumero("Recorde", "🏆 \(store.recorde())", "dias seguidos")
                cartaoNumero("Total", String(format: "%.1f L", Double(store.totalML) / 1000).replacingOccurrences(of: ".", with: ","), "desde o início")
            }
            CartaoSecao(titulo: "Nível", icone: "water.waves") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Nível \(nivel.indice + 1): \(nivel.nome)").font(.system(size: 15, weight: .bold)).foregroundColor(Estilo.tinta)
                        Spacer()
                        Text(textoNivel(nivel)).font(.system(size: 12)).foregroundColor(Estilo.tinta3)
                    }
                    BarraProgresso(valor: nivel.progresso)
                }
                .padding(.vertical, 12)
            }
            CartaoSecao(titulo: "Últimos 14 dias", icone: "chart.bar") {
                Grafico14Dias(store: store).frame(height: 150).padding(.vertical, 12)
            }
            CartaoSecao(titulo: "Conquistas (\(store.estado.conquistas.count)/\(Gamificacao.conquistas.count))", icone: "rosette") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 10)], spacing: 10) {
                    ForEach(Gamificacao.conquistas) { c in
                        CartaoConquista(conquista: c, data: store.estado.conquistas[c.id])
                    }
                }
                .padding(.vertical, 12)
            }
            HStack {
                Text(textoPulos).font(.system(size: 12.5)).foregroundColor(Estilo.tinta3)
                Spacer()
                Button { exportar() } label: { Label("Exportar CSV", systemImage: "square.and.arrow.up") }
                    .buttonStyle(BotaoAgua(tipo: .secundario))
            }
        }
    }

    func textoNivel(_ n: Store.InfoNivel) -> String {
        guard let p = n.proximo else { return "Nível máximo!" }
        return String(format: "faltam %.1f L para %@", n.faltaLitros, p)
    }

    var textoPulos: String {
        let pulos = store.historico.pulos.count
        if pulos == 0 { return "🛡️ Você nunca desligou o Mac para pular a água." }
        return "Vezes que desligou o Mac para pular: \(pulos) (\(store.pulosHoje) hoje)"
    }

    func cartaoNumero(_ titulo: String, _ valor: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(titulo.uppercased()).font(.system(size: 10.5, weight: .bold)).tracking(0.5).foregroundColor(Estilo.azul)
            Text(valor).font(.system(size: 22, weight: .heavy, design: .rounded)).foregroundColor(Estilo.tinta).lineLimit(1).minimumScaleFactor(0.6)
            Text(sub).font(.system(size: 11)).foregroundColor(Estilo.tinta3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Marca.borda, lineWidth: 1))
    }

    func exportar() {
        let painel = NSSavePanel()
        painel.allowedContentTypes = [.commaSeparatedText]
        painel.nameFieldStringValue = "historico-agua.csv"
        if painel.runModal() == .OK, let url = painel.url {
            try? store.exportarCSV().write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

private struct CartaoConquista: View {
    let conquista: Conquista
    let data: Date?
    var body: some View {
        let detalhe: String = data.map { (d: Date) -> String in "Conquistada em \(Formatos.diaCurto.string(from: d))" } ?? conquista.descricao
        HStack(spacing: 10) {
            Text(conquista.emoji).font(.system(size: 22)).grayscale(data == nil ? 1 : 0).opacity(data == nil ? 0.4 : 1)
            VStack(alignment: .leading, spacing: 1) {
                Text(conquista.titulo).font(.system(size: 12.5, weight: .semibold)).foregroundColor(Estilo.tinta)
                Text(detalhe).font(.system(size: 11)).foregroundColor(Estilo.tinta3).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(data == nil ? Marca.azulClaro.opacity(0.5) : Color(hex: "#FFF4E2")))
    }
}

struct Grafico14Dias: View {
    @ObservedObject var store: Store
    var body: some View {
        let totais = store.totaisPorDia
        let meta = Double(max(1, store.regras.metaML))
        let hoje = Date().inicioDoDia
        let dias: [Date] = (0..<14).reversed().map { calendario.date(byAdding: .day, value: -$0, to: hoje) ?? hoje }
        let maiorDia = Double(dias.map { totais[$0] ?? 0 }.max() ?? 0)
        let maximo = max(meta * 1.2, maiorDia)
        GeometryReader { g in
            let alturaUtil: CGFloat = g.size.height - 18
            ZStack(alignment: .bottomLeading) {
                Rectangle()
                    .fill(Color.green.opacity(0.6))
                    .frame(height: 1)
                    .offset(y: -(18 + alturaUtil * CGFloat(meta / maximo)))
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(dias, id: \.self) { d in
                        BarraDia(valor: Double(totais[d] ?? 0), meta: meta, maximo: maximo, alturaUtil: alturaUtil, dia: d, rotulo: store.fmt(totais[d] ?? 0))
                    }
                }
            }
        }
    }
}

private struct BarraDia: View {
    let valor: Double
    let meta: Double
    let maximo: Double
    let alturaUtil: CGFloat
    let dia: Date
    let rotulo: String
    var body: some View {
        let altura: CGFloat = max(3, alturaUtil * CGFloat(valor / maximo))
        let estilo: AnyShapeStyle = valor >= meta ? AnyShapeStyle(Estilo.verde) : AnyShapeStyle(Estilo.gradienteAgua)
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 4).fill(estilo).frame(height: altura)
            Text(String(Formatos.diaCurto.string(from: dia).prefix(2)))
                .font(.system(size: 9.5)).foregroundColor(Estilo.tinta3)
                .frame(height: 14)
        }
        .frame(maxWidth: .infinity)
        .help("\(Formatos.diaCurto.string(from: dia)): \(rotulo)")
    }
}

// MARK: - Permissões

struct PainelPermissoes: View {
    @ObservedObject var permissoes: Permissoes

    var body: some View {
        CartaoSecao(titulo: "Permissões necessárias", icone: "lock.shield") {
            LinhaPermissao(icone: "camera.fill", cor: Color(hex: "#8A63E8"),
                           titulo: "Câmera",
                           descricao: "Para confirmar, ao vivo, que você bebeu. Nenhuma imagem é salva.",
                           ok: permissoes.cameraOk,
                           textoBotao: permissoes.textoBotaoCamera) { permissoes.pedirCamera() }
            LinhaPermissao(icone: "power", cor: Color(hex: "#2DBE7E"),
                           titulo: "Abrir com o Mac e ficar ativo",
                           descricao: "Mantém os lembretes funcionando. Se o macOS pedir, aprove em Itens de Início.",
                           ok: permissoes.segundoPlanoOk,
                           textoBotao: permissoes.textoBotaoSegundoPlano,
                           ultima: true) { permissoes.ativarSegundoPlano() }
            if !permissoes.erroSegundoPlano.isEmpty {
                TextoAjuda(texto: permissoes.erroSegundoPlano)
            }
        }
        .onAppear { permissoes.monitorar(true) }
        .onDisappear { permissoes.monitorar(false) }
    }
}

struct LinhaPermissao: View {
    let icone: String
    let cor: Color
    let titulo: String
    let descricao: String
    let ok: Bool
    let textoBotao: String
    var ultima = false
    let acao: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icone)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 38, height: 38)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(cor.gradient))
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo).font(.system(size: 13.5, weight: .semibold)).foregroundColor(Estilo.tinta)
                Text(descricao).font(.system(size: 11.5)).foregroundColor(Estilo.tinta3).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if ok {
                Label("Permitido", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundColor(Estilo.verde)
                    .padding(.vertical, 6).padding(.horizontal, 12)
                    .background(Capsule().fill(Estilo.verde.opacity(0.12)))
            } else {
                Button(textoBotao, action: acao).buttonStyle(BotaoAgua(tipo: .primario))
            }
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            if !ultima { Rectangle().fill(Marca.borda.opacity(0.7)).frame(height: 1) }
        }
    }
}

// MARK: - Atualizações

struct AbaAtualizacoes: View {
    @ObservedObject var store: Store
    @ObservedObject var atualizador: Atualizador

    var novidadesInstaladas: String {
        guard let url = Bundle.main.url(forResource: "NOVIDADES", withExtension: "md"),
              let t = try? String(contentsOf: url, encoding: .utf8) else { return "Sem notas desta versão." }
        return t
    }

    var body: some View {
        PaginaRolavel {
            if let info = atualizador.disponivel {
                CartaoSecao(titulo: "Nova versão \(info.versao) disponível", icone: "sparkles") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(info.notas.isEmpty ? "Melhorias e correções." : info.notas)
                            .font(.system(size: 12.5)).foregroundColor(Estilo.tinta)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                        HStack {
                            Spacer()
                            Button { atualizador.instalar() } label: { Label("Atualizar agora", systemImage: "arrow.down.circle.fill") }
                                .buttonStyle(BotaoAgua(tipo: .primario, grande: true))
                                .disabled(atualizador.ocupado)
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
            CartaoSecao(titulo: "Versão", icone: "info.circle") {
                LinhaAjuste(titulo: "Instalada") {
                    Text(atualizador.versaoAtual).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(Estilo.azul)
                }
                if let d = store.estado.ultimaVerificacao {
                    LinhaAjuste(titulo: "Última verificação") {
                        Text("\(Formatos.diaCurto.string(from: d)) às \(Formatos.hora.string(from: d))").font(.system(size: 12.5)).foregroundColor(Estilo.tinta2)
                    }
                }
                LinhaAjuste(titulo: textoFase) {
                    HStack(spacing: 8) {
                        if atualizador.ocupado { ProgressView().controlSize(.small) }
                        Button("Procurar atualizações") { atualizador.verificar(manual: true) }
                            .buttonStyle(BotaoAgua(tipo: .secundario))
                            .disabled(atualizador.ocupado)
                    }
                }
                LinhaInterruptor(titulo: "Verificar sozinho e me avisar", detalhe: "Nunca instala sem você clicar em Atualizar", ultima: true,
                                 ligado: $store.prefs.verificarAtualizacoes)
            }
            CartaoSecao(titulo: "Novidades da versão instalada", icone: "doc.text") {
                Text(novidadesInstaladas).font(.system(size: 12)).foregroundColor(Estilo.tinta2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(.vertical, 12)
            }
        }
    }

    var textoFase: String {
        switch atualizador.fase {
        case .parado: return "Clique para procurar uma versão nova."
        case .verificando: return "Procurando…"
        case .emDia: return "Você está na versão mais recente."
        case .disponivel: return "Há uma versão nova esperando por você."
        case .baixando: return "Baixando a versão nova…"
        case .instalando: return "Instalando… o app vai reabrir sozinho."
        case .erro(let m): return m
        }
    }
}

// MARK: - Controlador da janela

@MainActor
final class JanelaAjustes {
    private var janela: NSWindow?
    let modelo: ModeloAjustes
    let acoes = AcoesAjustes()
    private let store: Store
    private let atualizador: Atualizador
    private let permissoes: Permissoes

    init(store: Store, atualizador: Atualizador, permissoes: Permissoes) {
        self.store = store
        self.atualizador = atualizador
        self.permissoes = permissoes
        self.modelo = ModeloAjustes(regras: store.regras)
    }

    var visivel: Bool { janela?.isVisible ?? false }

    func abrir(aba: String) {
        if janela == nil {
            let j = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 720),
                             styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            j.title = "Ajustes do LembreteAgua"
            j.appearance = NSAppearance(named: .aqua)
            j.isReleasedWhenClosed = false
            j.contentView = NSHostingView(rootView: AjustesView(store: store, modelo: modelo, atualizador: atualizador,
                                                                permissoes: permissoes, acoes: acoes))
            j.center()
            janela = j
        }
        if !(janela?.isVisible ?? false) {
            modelo.rascunho = store.estado.pendente ?? store.regras
            modelo.mensagem = ""
        }
        modelo.aba = aba
        NSApp.activate(ignoringOtherApps: true)
        janela?.makeKeyAndOrderFront(nil)
    }

    func fechar() { janela?.orderOut(nil) }
    func esconderTemporariamente() { janela?.orderOut(nil) }
    func reexibir() {
        guard janela != nil else { return }
        NSApp.activate(ignoringOtherApps: true)
        janela?.makeKeyAndOrderFront(nil)
    }
}
