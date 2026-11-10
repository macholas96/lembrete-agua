import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine

@MainActor
final class ModeloAjustes: ObservableObject {
    @Published var aba = "geral"
    @Published var rascunho: Regras
    @Published var mensagem = ""
    @Published var resultadoTeste = ""

    init(regras: Regras) { rascunho = regras }
}

/// Ações de teste que os Ajustes podem disparar.
@MainActor
final class AcoesAjustes {
    var testarAgora: @MainActor () -> Void = {}
    var testarPreAviso: @MainActor () -> Void = {}
    var mostrarWidget: @MainActor () -> Void = {}
}

// MARK: - Ajudantes

func bindingHora(_ b: Binding<Int>) -> Binding<Date> {
    Binding<Date>(
        get: { calendario.date(bySettingHour: b.wrappedValue / 60, minute: b.wrappedValue % 60, second: 0, of: Date()) ?? Date() },
        set: { d in
            let c = calendario.dateComponents([.hour, .minute], from: d)
            b.wrappedValue = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        })
}

private struct Dica: View {
    let texto: String
    var body: some View {
        Text(texto).font(.system(size: 11.5)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
    }
}

/// Linha com um botão de teste à direita.
private struct LinhaTeste: View {
    let texto: String
    let botao: String
    let acao: () -> Void
    var body: some View {
        HStack {
            Text(texto).font(.system(size: 12)).foregroundColor(.secondary)
            Spacer()
            Button(botao, action: acao)
        }
    }
}

struct PaginaAjustes: Identifiable {
    let id: String
    let titulo: String
    let icone: String
    let cor: Color

    static let todas: [PaginaAjustes] = [
        PaginaAjustes(id: "geral", titulo: "Geral", icone: "gearshape.fill", cor: .gray),
        PaginaAjustes(id: "lembretes", titulo: "Lembretes", icone: "bell.badge.fill", cor: .red),
        PaginaAjustes(id: "chamadas", titulo: "Chamadas", icone: "video.fill", cor: .green),
        PaginaAjustes(id: "meta", titulo: "Meta e copos", icone: "drop.fill", cor: .blue),
        PaginaAjustes(id: "camera", titulo: "Câmera", icone: "camera.viewfinder", cor: .purple),
        PaginaAjustes(id: "aparencia", titulo: "Aparência", icone: "paintpalette.fill", cor: .pink),
        PaginaAjustes(id: "widget", titulo: "Widget", icone: "rectangle.on.rectangle", cor: .teal),
        PaginaAjustes(id: "historico", titulo: "Histórico", icone: "chart.bar.fill", cor: .orange),
        PaginaAjustes(id: "permissoes", titulo: "Permissões", icone: "lock.shield.fill", cor: .indigo),
        PaginaAjustes(id: "atualizacoes", titulo: "Atualizações", icone: "arrow.down.circle.fill", cor: .cyan),
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
            Divider()
            HStack {
                Text(PaginaAjustes.todas.first { $0.id == modelo.aba }?.titulo ?? "")
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                Button {
                    acoes.testarAgora()
                } label: {
                    Label("Testar agora: beber água", systemImage: "drop.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .help("Abre a tela de lembrete agora, do começo ao fim (registra o copo se você beber).")
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 2)
            conteudo
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            BarraAplicar(store: store, modelo: modelo)
        }
        .frame(width: 880, height: 700)
    }

    @ViewBuilder var conteudo: some View {
        switch modelo.aba {
        case "lembretes": AbaLembretes(store: store, modelo: modelo, acoes: acoes)
        case "chamadas": AbaChamadas(store: store, modelo: modelo)
        case "meta": AbaMeta(store: store, modelo: modelo)
        case "camera": AbaCamera(modelo: modelo, acoes: acoes)
        case "aparencia": AbaAparencia(store: store, acoes: acoes)
        case "widget": AbaWidget(store: store, acoes: acoes)
        case "historico": AbaHistorico(store: store)
        case "permissoes": Form { PainelPermissoes(permissoes: permissoes) }.formStyle(.grouped)
        case "atualizacoes": AbaAtualizacoes(store: store, atualizador: atualizador)
        default: AbaGeral(store: store, acoes: acoes)
        }
    }
}

/// Navegação no estilo dos Ajustes de apps do Mac: ícones coloridos no topo.
struct BarraIcones: View {
    @ObservedObject var modelo: ModeloAjustes
    @ObservedObject var atualizador: Atualizador
    @ObservedObject var permissoes: Permissoes

    var body: some View {
        HStack(spacing: 2) {
            ForEach(PaginaAjustes.todas) { p in
                let sel = modelo.aba == p.id
                Button { modelo.aba = p.id } label: {
                    VStack(spacing: 5) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: p.icone)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 30, height: 30)
                                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(p.cor.gradient))
                            if temAlerta(p.id) {
                                Circle().fill(Color.red).frame(width: 10, height: 10).offset(x: 4, y: -4)
                            }
                        }
                        Text(p.titulo)
                            .font(.system(size: 11, weight: sel ? .semibold : .regular))
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .frame(width: 80, height: 58)
                    .background(RoundedRectangle(cornerRadius: 8).fill(sel ? Color.primary.opacity(0.09) : Color.clear))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
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
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                Image(systemName: mudou ? (frouxa ? "clock.badge.exclamationmark" : "checkmark.seal") : "lock.shield")
                    .font(.system(size: 18))
                    .foregroundColor(mudou ? (frouxa ? .orange : Estilo.azul) : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tituloStatus(mudou: mudou, frouxa: frouxa)).font(.system(size: 12.5, weight: .semibold))
                    Text(store.diaDaInstalacao ? "Hoje é o dia da instalação: tudo vale na hora para você configurar à vontade."
                                               : "Aparência, som, copos e widget mudam na hora. Horários, meta e rigor que afrouxam só valem amanhã.")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }
                Spacer()
                if store.estado.pendente != nil && !mudou {
                    Button("Cancelar agendamento") {
                        store.estado.pendente = nil
                        store.estado.pendenteAPartirDe = nil
                        modelo.rascunho = store.regras
                    }
                }
                if mudou {
                    Button("Descartar") { modelo.rascunho = store.regras; modelo.mensagem = "" }
                    Button(frouxa ? "Agendar para amanhã" : "Aplicar") {
                        modelo.mensagem = store.aplicar(modelo.rascunho)
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
        .background(Color(nsColor: .windowBackgroundColor))
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
            return "Lembretes ativos agora. Próximo às \(Formatos.hora.string(from: store.estado.proximo))."
        }
        if store.regras.pararAoBaterMeta && store.hojeML >= store.regras.metaML { return "Meta de hoje batida — sem mais lembretes hoje." }
        return "Fora do horário de lembretes agora."
    }

    var body: some View {
        Form {
            Section("Agora") {
                LabeledContent("Situação", value: statusAgora)
                LabeledContent("Hoje", value: "\(store.fmt(store.hojeML)) de \(store.fmt(store.regras.metaML)) · \(store.coposHoje) copos")
                LinhaTeste(texto: "Veja a experiência completa, do lembrete ao copo registrado.",
                           botao: "Testar tela de lembrete") { acoes.testarAgora() }
            }
            Section("Você") {
                TextField("Como te chamar (opcional)", text: $store.prefs.nome)
                Toggle("Mostrar frases motivacionais", isOn: $store.prefs.frases)
                Picker("Mostrar volumes em", selection: $store.prefs.unidade) {
                    Text("Mililitros (ml)").tag("ml")
                    Text("Onças (oz)").tag("oz")
                }
                .pickerStyle(.segmented)
            }
            Section("Barra de menus") {
                Picker("Ao lado da gota", selection: $store.prefs.barraMenu) {
                    Text("Quanto bebi (1,5 L)").tag("ml")
                    Text("Porcentagem da meta").tag("pct")
                    Text("Só o ícone").tag("icone")
                }
                .pickerStyle(.segmented)
                Dica(texto: "Muda na hora — olhe a gotinha 💧 no canto superior direito da tela.")
            }
            Section("Saída de emergência") {
                Dica(texto: "Não existe botão de pular. Cmd+Option+Esc, Cmd+Tab, Dock e menus ficam bloqueados enquanto a tela azul estiver aberta. A única saída sem beber é desligar o Mac — e isso fica registrado no seu histórico.")
            }
        }
        .formStyle(.grouped)
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

    var body: some View {
        Form {
            Section("Quando a tela azul pode aparecer") {
                HStack {
                    Text("Horário ativo")
                    Spacer()
                    DatePicker("", selection: bindingHora($modelo.rascunho.inicioMin), displayedComponents: .hourAndMinute)
                        .labelsHidden().frame(width: 90)
                    Text("até")
                    DatePicker("", selection: bindingHora($modelo.rascunho.fimMin), displayedComponents: .hourAndMinute)
                        .labelsHidden().frame(width: 90)
                }
                HStack {
                    Text("Dias da semana")
                    Spacer()
                    ForEach(AbaLembretes.ordemDias, id: \.self) { d in
                        let on = modelo.rascunho.dias.contains(d)
                        Button {
                            if on { modelo.rascunho.dias.removeAll { $0 == d } } else { modelo.rascunho.dias.append(d) }
                        } label: {
                            Text(AbaLembretes.nomesDias[d] ?? "?")
                                .font(.system(size: 12, weight: .bold))
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(on ? Estilo.azul : Color.secondary.opacity(0.15)))
                                .foregroundColor(on ? .white : .secondary)
                        }
                        .buttonStyle(.plain)
                        .help(AbaLembretes.nomesLongos[d] ?? "")
                    }
                }
                Picker("Lembrar a cada", selection: $modelo.rascunho.intervaloMin) {
                    ForEach([10, 15, 20, 30, 45, 60, 75, 90, 120], id: \.self) { m in
                        Text(m < 60 || m % 60 != 0 ? "\(m) min" : "\(m / 60) h").tag(m)
                    }
                }
                LinhaTeste(texto: "Quer ver como fica? Abre a tela de lembrete agora.", botao: "Testar") { acoes.testarAgora() }
            }

            Section("Pausas") {
                Toggle("Pausa de almoço", isOn: $modelo.rascunho.pausaAlmoco)
                if modelo.rascunho.pausaAlmoco {
                    HStack {
                        Text("Sem lembretes das")
                        Spacer()
                        DatePicker("", selection: bindingHora($modelo.rascunho.almocoInicioMin), displayedComponents: .hourAndMinute)
                            .labelsHidden().frame(width: 90)
                        Text("às")
                        DatePicker("", selection: bindingHora($modelo.rascunho.almocoFimMin), displayedComponents: .hourAndMinute)
                            .labelsHidden().frame(width: 90)
                    }
                }
                Toggle("Parar de lembrar depois de bater a meta do dia", isOn: $modelo.rascunho.pararAoBaterMeta)
            }

            Section("Pré-aviso") {
                Toggle("Avisar um pouco antes da tela azul", isOn: $store.prefs.preAviso)
                if store.prefs.preAviso {
                    Picker("Antecedência", selection: $store.prefs.preAvisoSeg) {
                        ForEach([30, 60, 120, 300], id: \.self) { s in Text(s < 60 ? "\(s) s" : "\(s / 60) min").tag(s) }
                    }
                }
                LinhaTeste(texto: "Mostra agora o aviso que aparece no canto da tela.", botao: "Testar pré-aviso") { acoes.testarPreAviso() }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Chamadas

struct AbaChamadas: View {
    @ObservedObject var store: Store
    @ObservedObject var modelo: ModeloAjustes
    @State private var resultado = ""

    var body: some View {
        Form {
            Section("Durante chamadas e apresentações") {
                Toggle("Não interromper chamadas de vídeo", isOn: $modelo.rascunho.adiarEmChamadas)
                if modelo.rascunho.adiarEmChamadas {
                    Picker("Esperar a chamada acabar", selection: $modelo.rascunho.adiarMaxMin) {
                        Text("Sempre — nunca interromper").tag(0)
                        Text("No máximo 15 min").tag(15)
                        Text("No máximo 30 min").tag(30)
                        Text("No máximo 60 min").tag(60)
                        Text("No máximo 90 min").tag(90)
                    }
                    Toggle("Contar microfone em uso como chamada (pega chamadas só de áudio)", isOn: $modelo.rascunho.usarMicrofone)
                    Dica(texto: "Quando a câmera (ou o microfone) estiver sendo usado por outro app — Meet, Zoom, Teams, FaceTime, Slack — o lembrete fica esperando e aparece assim que a chamada terminar.")
                }
            }
            Section("Testar") {
                HStack {
                    Text("Entre numa chamada (ou abra o FaceTime) e clique para ver o que o app detecta.")
                        .font(.system(size: 12)).foregroundColor(.secondary)
                    Spacer()
                    Button("Verificar agora") {
                        resultado = Chamada.descricao(usarMicrofone: modelo.rascunho.usarMicrofone)
                    }
                }
                if !resultado.isEmpty {
                    Text(resultado).font(.system(size: 12.5, weight: .medium))
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Meta e copos

struct AbaMeta: View {
    @ObservedObject var store: Store
    @ObservedObject var modelo: ModeloAjustes
    @State private var peso = 70.0
    @State private var ativo = false
    @State private var calor = false

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

    func adicionar(_ m: ModeloGarrafa) {
        guard store.prefs.copos.count < 12 else { return }
        let nome = m.marca == "Comum" ? m.nome : "\(m.marca) \(m.nome)"
        store.prefs.copos.append(Copo(nome: nome, ml: m.ml, icone: m.icone))
    }

    var body: some View {
        Form {
            Section("Meta diária") {
                HStack {
                    Slider(value: Binding(get: { Double(modelo.rascunho.metaML) },
                                          set: { modelo.rascunho.metaML = Int(($0 / 100).rounded()) * 100 }),
                           in: 1000...5000)
                    Stepper(store.fmt(modelo.rascunho.metaML), value: $modelo.rascunho.metaML, in: 500...6000, step: 100)
                        .frame(width: 150)
                }
            }
            Section("Calculadora de meta") {
                HStack {
                    Text("Seu peso")
                    Slider(value: $peso, in: 40...150, step: 1)
                    Text("\(Int(peso)) kg").monospacedDigit().frame(width: 60, alignment: .trailing)
                }
                Toggle("Faço atividade física na maioria dos dias", isOn: $ativo)
                Toggle("Moro/trabalho num lugar quente", isOn: $calor)
                HStack {
                    Dica(texto: "Regra comum: ~35 ml por kg, +500 ml para quem treina e +500 ml no calor. Não substitui orientação médica.")
                    Spacer()
                    Button("Usar \(store.fmt(sugestao))") { modelo.rascunho.metaML = sugestao }
                }
            }
            Section("Seus copos e garrafas") {
                ForEach(store.prefs.copos) { copo in
                    HStack(spacing: 12) {
                        IconeRecipiente(tipo: copo.icone, tamanho: 28)
                        TextField("Nome", text: campoCopo(copo.id, \.nome, "")).frame(minWidth: 180)
                        Stepper("\(copo.ml) ml", value: campoCopo(copo.id, \.ml, 250), in: 50...3000, step: 10).frame(width: 130)
                        Picker("", selection: campoCopo(copo.id, \.icone, "copo")) {
                            ForEach(Catalogo.icones, id: \.id) { Text($0.nome).tag($0.id) }
                        }
                        .labelsHidden()
                        .frame(width: 150)
                        Button {
                            let id = copo.id
                            NSApp.keyWindow?.makeFirstResponder(nil)   // encerra a edição antes de apagar
                            DispatchQueue.main.async {
                                if store.prefs.copos.count > 1 { store.prefs.copos.removeAll { $0.id == id } }
                                if store.prefs.copoPadrao >= store.prefs.copos.count { store.prefs.copoPadrao = 0 }
                            }
                        } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless)
                        .disabled(store.prefs.copos.count <= 1)
                    }
                }
                HStack {
                    Menu {
                        ForEach(Catalogo.marcas, id: \.self) { marca in
                            Menu(marca) {
                                ForEach(Catalogo.garrafas.filter { $0.marca == marca }) { m in
                                    Button("\(m.nome)") { adicionar(m) }
                                }
                            }
                        }
                        Divider()
                        Button("Personalizado…") {
                            store.prefs.copos.append(Copo(nome: "Minha garrafa", ml: 600, icone: "termica"))
                        }
                    } label: {
                        Label("Adicionar garrafa ou copo", systemImage: "plus")
                    }
                    .fixedSize()
                    .disabled(store.prefs.copos.count >= 12)
                    Spacer()
                    Picker("Já vem selecionado", selection: $store.prefs.copoPadrao) {
                        ForEach(Array(store.prefs.copos.enumerated()), id: \.element.id) { i, c in
                            Text("\(c.nome) · \(c.ml) ml").tag(i)
                        }
                    }
                    .frame(width: 340)
                }
                Dica(texto: "Stanley, Owala, Hydro Flask, Pacco e mais. Os volumes são os oficiais de cada modelo — ajuste se a sua for diferente. Em garrafas grandes, na hora de beber você escolhe se tomou ¼, ½, ¾ ou a garrafa inteira.")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Câmera

struct AbaCamera: View {
    @ObservedObject var modelo: ModeloAjustes
    let acoes: AcoesAjustes

    var body: some View {
        Form {
            Section("Rigor da verificação") {
                HStack {
                    Text("Tempo bebendo exigido")
                    Slider(value: $modelo.rascunho.segundosBebendo, in: 1.5...6, step: 0.5)
                    Text(String(format: "%.1f s", modelo.rascunho.segundosBebendo)).monospacedDigit().frame(width: 50)
                }
                Toggle("Exigir que a câmera reconheça o copo ou a garrafa", isOn: $modelo.rascunho.exigirCopo)
                Dica(texto: "Sem essa opção, basta rosto + mão na boca pelo tempo exigido. Com ela, o copo também precisa aparecer.")
                LinhaTeste(texto: "Teste a câmera com essas regras (aplique antes, se mudou algo).", botao: "Testar câmera") { acoes.testarAgora() }
            }
            Section("Como funciona") {
                Label("Rosto visível e livre por um instante", systemImage: "1.circle")
                Label("Copo na boca pelo tempo exigido", systemImage: "2.circle")
                Label("Afastar o copo (prova que não é uma foto parada)", systemImage: "3.circle")
                Label("Câmeras virtuais (OBS, Snap…) não são aceitas", systemImage: "video.slash")
            }
            Section("Privacidade") {
                Label("Tudo é analisado no seu Mac, na hora, pelo Vision da Apple.", systemImage: "cpu")
                Label("Nenhuma foto ou vídeo é salvo, nem enviado para lugar nenhum.", systemImage: "lock.shield")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Aparência e som

struct AbaAparencia: View {
    @ObservedObject var store: Store
    let acoes: AcoesAjustes

    var body: some View {
        Form {
            Section("Tela de lembrete") {
                HStack(spacing: 14) {
                    Text("Tema")
                    Spacer()
                    ForEach(Tema.todos, id: \.id) { t in
                        Button { store.prefs.tema = t.id } label: {
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(LinearGradient(colors: t.cores, startPoint: .top, endPoint: .bottom))
                                    .frame(width: 34, height: 34)
                                    .overlay(Circle().stroke(store.prefs.tema == t.id ? Estilo.azul : Color.clear, lineWidth: 3).padding(-4))
                                Text(t.nome).font(.system(size: 10.5))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                HStack {
                    Text("Intensidade do azul")
                    Slider(value: $store.prefs.opacidade, in: 0.3...0.9)
                    Text("\(Int(store.prefs.opacidade * 100))%").monospacedDigit().frame(width: 44)
                }
                Toggle("Ondas e bolhas animadas", isOn: $store.prefs.animacoes)
                LinhaTeste(texto: "Veja o tema e a intensidade na tela de verdade.", botao: "Pré-visualizar") { acoes.testarAgora() }
            }
            Section("Som") {
                Toggle("Tocar som quando a tela aparecer", isOn: $store.prefs.somAtivo)
                if store.prefs.somAtivo {
                    HStack {
                        Picker("Som", selection: $store.prefs.som) {
                            ForEach(Sons.disponiveis, id: \.self) { Text($0).tag($0) }
                        }
                        Button("Ouvir") { Sons.tocar(store.prefs.som, volume: store.prefs.volume) }
                    }
                    HStack {
                        Text("Volume")
                        Slider(value: $store.prefs.volume, in: 0.1...1)
                        Button("Ouvir") { Sons.tocar(store.prefs.som, volume: store.prefs.volume) }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Widget

struct AbaWidget: View {
    @ObservedObject var store: Store
    let acoes: AcoesAjustes

    var body: some View {
        Form {
            Section("Widget na área de trabalho") {
                Toggle("Mostrar widget", isOn: $store.prefs.widgetAtivo)
                Picker("Posição", selection: $store.prefs.widgetPosicao) {
                    Text("Superior esquerdo").tag("supEsq")
                    Text("Superior direito").tag("supDir")
                    Text("Inferior esquerdo").tag("infEsq")
                    Text("Inferior direito").tag("infDir")
                }
                Picker("Tamanho", selection: $store.prefs.widgetTamanho) {
                    Text("Pequeno").tag("pequeno")
                    Text("Médio").tag("medio")
                    Text("Grande").tag("grande")
                }
                .pickerStyle(.segmented)
                Picker("Estilo", selection: $store.prefs.widgetEstilo) {
                    Text("Escuro translúcido").tag("escuro")
                    Text("Claro").tag("claro")
                }
                .pickerStyle(.segmented)
                LinhaTeste(texto: "O widget fica atrás das janelas, no monitor principal.", botao: "Mostrar a área de trabalho") { acoes.mostrarWidget() }
            }
            Section("Prévia") {
                HStack {
                    Spacer()
                    WidgetView(store: store)
                        .padding(20)
                        .background(RoundedRectangle(cornerRadius: 16).fill(
                            LinearGradient(colors: [Color(red: 0.42, green: 0.36, blue: 0.84), Color(red: 0.85, green: 0.56, blue: 0.72)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)))
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Histórico

struct AbaHistorico: View {
    @ObservedObject var store: Store

    var body: some View {
        let nivel = store.nivel()
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    cartaoNumero("Hoje", store.fmt(store.hojeML), "\(store.coposHoje) copos")
                    cartaoNumero("Sequência", "🔥 \(store.sequenciaAtual())", "dias na meta")
                    cartaoNumero("Recorde", "🏆 \(store.recorde())", "dias seguidos")
                    cartaoNumero("Total", String(format: "%.1f L", Double(store.totalML) / 1000).replacingOccurrences(of: ".", with: ","), "desde o início")
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Nível \(nivel.indice + 1): \(nivel.nome)").font(.system(size: 15, weight: .bold))
                        Spacer()
                        Text(textoNivel(nivel)).font(.system(size: 12)).foregroundColor(.secondary)
                    }
                    BarraProgresso(valor: nivel.progresso)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.08)))

                Text("Últimos 14 dias").font(.system(size: 15, weight: .bold))
                Grafico14Dias(store: store)
                    .frame(height: 150)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.08)))

                Text("Conquistas (\(store.estado.conquistas.count)/\(Gamificacao.conquistas.count))").font(.system(size: 15, weight: .bold))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 10)], spacing: 10) {
                    ForEach(Gamificacao.conquistas) { c in
                        CartaoConquista(conquista: c, data: store.estado.conquistas[c.id])
                    }
                }

                HStack {
                    Text(textoPulos).font(.system(size: 12.5)).foregroundColor(.secondary)
                    Spacer()
                    Button("Exportar CSV…") { exportar() }
                }
            }
            .padding(24)
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
            Text(titulo.uppercased()).font(.system(size: 10.5, weight: .semibold)).foregroundColor(.secondary)
            Text(valor).font(.system(size: 22, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.6)
            Text(sub).font(.system(size: 11)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.08)))
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
                Text(conquista.titulo).font(.system(size: 12.5, weight: .semibold))
                Text(detalhe).font(.system(size: 11)).foregroundColor(.secondary).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(data == nil ? 0.05 : 0.12)))
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
                .font(.system(size: 9.5)).foregroundColor(.secondary)
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
        Section {
            LinhaPermissao(icone: "camera.fill", cor: .purple,
                           titulo: "Câmera",
                           descricao: "Para confirmar, ao vivo, que você bebeu. Nenhuma imagem é salva.",
                           ok: permissoes.cameraOk,
                           textoBotao: permissoes.textoBotaoCamera) { permissoes.pedirCamera() }
            LinhaPermissao(icone: "power", cor: .green,
                           titulo: "Abrir com o Mac e ficar ativo",
                           descricao: "Mantém os lembretes funcionando em segundo plano. Se o macOS pedir, aprove em Itens de Início.",
                           ok: permissoes.segundoPlanoOk,
                           textoBotao: permissoes.textoBotaoSegundoPlano) { permissoes.ativarSegundoPlano() }
            if !permissoes.erroSegundoPlano.isEmpty {
                Dica(texto: permissoes.erroSegundoPlano)
            }
        } footer: {
            Dica(texto: "Os botões levam direto para o lugar certo nos Ajustes do Sistema. Esta tela se atualiza sozinha quando você permite.")
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
    let acao: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icone)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(cor.gradient))
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo).font(.system(size: 13.5, weight: .semibold))
                Text(descricao).font(.system(size: 11.5)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if ok {
                Label("Permitido", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(.green)
            } else {
                Button(textoBotao, action: acao).buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 4)
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
        Form {
            Section("Versão") {
                LabeledContent("Instalada", value: atualizador.versaoAtual)
                if let d = store.estado.ultimaVerificacao {
                    LabeledContent("Última verificação", value: "\(Formatos.diaCurto.string(from: d)) às \(Formatos.hora.string(from: d))")
                }
                HStack {
                    Text(textoFase).font(.system(size: 12.5)).foregroundColor(.secondary).textSelection(.enabled)
                    Spacer()
                    if atualizador.ocupado { ProgressView().controlSize(.small) }
                    Button("Procurar atualizações") { atualizador.verificar(manual: true) }
                        .disabled(atualizador.ocupado)
                }
                Toggle("Verificar automaticamente e me avisar (nunca instala sozinho)", isOn: $store.prefs.verificarAtualizacoes)
            }
            if let info = atualizador.disponivel {
                Section("Nova versão \(info.versao) disponível") {
                    ScrollView {
                        Text(info.notas.isEmpty ? "Melhorias e correções." : info.notas)
                            .font(.system(size: 12))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 160)
                    HStack {
                        Spacer()
                        Button("Atualizar agora") { atualizador.instalar() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(atualizador.ocupado)
                    }
                }
            }
            Section("Novidades da versão instalada") {
                ScrollView {
                    Text(novidadesInstaladas).font(.system(size: 12)).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                }
                .frame(height: 150)
            }
        }
        .formStyle(.grouped)
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
            let j = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 880, height: 700),
                             styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            j.title = "Ajustes do LembreteAgua"
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
