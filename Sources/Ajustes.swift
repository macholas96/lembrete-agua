import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
final class ModeloAjustes: ObservableObject {
    @Published var aba = "lembretes"
    @Published var rascunho: Regras
    @Published var mensagem = ""

    init(regras: Regras) { rascunho = regras }
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

// MARK: - Janela

struct AjustesView: View {
    @ObservedObject var store: Store
    @ObservedObject var modelo: ModeloAjustes
    @ObservedObject var atualizador: Atualizador
    let aoTestar: @MainActor () -> Void

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $modelo.aba) {
                AbaLembretes(store: store, modelo: modelo)
                    .tabItem { Label("Lembretes", systemImage: "bell.badge") }.tag("lembretes")
                AbaMeta(store: store, modelo: modelo)
                    .tabItem { Label("Meta e copos", systemImage: "drop") }.tag("meta")
                AbaVerificacao(modelo: modelo, aoTestar: aoTestar)
                    .tabItem { Label("Verificação", systemImage: "camera.viewfinder") }.tag("verificacao")
                AbaAparencia(store: store, aoTestar: aoTestar)
                    .tabItem { Label("Aparência e som", systemImage: "paintpalette") }.tag("aparencia")
                AbaWidget(store: store)
                    .tabItem { Label("Widget", systemImage: "rectangle.on.rectangle") }.tag("widget")
                AbaHistorico(store: store)
                    .tabItem { Label("Histórico", systemImage: "chart.bar.xaxis") }.tag("historico")
                AbaAtualizacoes(store: store, atualizador: atualizador)
                    .tabItem { Label("Atualizações", systemImage: "arrow.down.circle") }.tag("atualizacoes")
            }
            .padding(.top, 6)
            BarraAplicar(store: store, modelo: modelo)
        }
        .frame(width: 760, height: 640)
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
                    if mudou {
                        Text(frouxa ? "Essas mudanças afrouxam as regras: vão valer a partir de amanhã."
                                    : "Essas mudanças deixam tudo igual ou mais rígido: valem na hora.")
                            .font(.system(size: 12.5, weight: .semibold))
                    } else if let d = store.estado.pendenteAPartirDe, store.estado.pendente != nil {
                        Text("Há mudanças agendadas para \(Formatos.diaCurto.string(from: d)).")
                            .font(.system(size: 12.5, weight: .semibold))
                    } else if !modelo.mensagem.isEmpty {
                        Text(modelo.mensagem).font(.system(size: 12.5, weight: .semibold))
                    } else {
                        Text("Anti-autoengano ativo").font(.system(size: 12.5, weight: .semibold))
                    }
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
}

// MARK: - Lembretes

struct AbaLembretes: View {
    @ObservedObject var store: Store
    @ObservedObject var modelo: ModeloAjustes
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
                Toggle("Esperar o fim de chamadas de vídeo", isOn: $modelo.rascunho.adiarEmChamadas)
                if modelo.rascunho.adiarEmChamadas {
                    Picker("Esperar no máximo", selection: $modelo.rascunho.adiarMaxMin) {
                        ForEach([10, 15, 30, 45, 60], id: \.self) { Text("\($0) min").tag($0) }
                    }
                    Dica(texto: "Se a câmera estiver em uso por outro app (Meet, Zoom, Teams…), o lembrete espera a chamada acabar — até esse limite.")
                }
            }

            Section("Pré-aviso") {
                Toggle("Avisar um pouco antes da tela azul", isOn: $store.prefs.preAviso)
                if store.prefs.preAviso {
                    Picker("Antecedência", selection: $store.prefs.preAvisoSeg) {
                        ForEach([30, 60, 120, 300], id: \.self) { s in Text(s < 60 ? "\(s) s" : "\(s / 60) min").tag(s) }
                    }
                }
            }

            Section("Saída de emergência") {
                Dica(texto: "Não existe botão de pular. Cmd+Option+Esc, Cmd+Tab, Dock e menus ficam bloqueados enquanto a tela azul estiver aberta. A única saída sem beber é desligar o Mac — e isso fica registrado no seu histórico.")
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
            Section("Seus copos") {
                ForEach(store.prefs.copos) { copo in
                    HStack(spacing: 12) {
                        IconeRecipiente(tipo: copo.icone, tamanho: 28)
                        TextField("Nome", text: campoCopo(copo.id, \.nome, "")).frame(width: 150)
                        Stepper("\(copo.ml) ml", value: campoCopo(copo.id, \.ml, 250), in: 50...2000, step: 10).frame(width: 130)
                        Picker("", selection: campoCopo(copo.id, \.icone, "copo")) {
                            Text("Copo pequeno").tag("copoPequeno")
                            Text("Copo").tag("copo")
                            Text("Caneca").tag("caneca")
                            Text("Garrafa").tag("garrafa")
                        }
                        .labelsHidden()
                        .frame(width: 130)
                        Spacer()
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
                    Button {
                        store.prefs.copos.append(Copo(nome: "Novo copo", ml: 300, icone: "copo"))
                    } label: { Label("Adicionar copo", systemImage: "plus") }
                    .disabled(store.prefs.copos.count >= 8)
                    Spacer()
                    Picker("Já vem selecionado", selection: $store.prefs.copoPadrao) {
                        ForEach(Array(store.prefs.copos.enumerated()), id: \.element.id) { i, c in
                            Text("\(c.nome) · \(c.ml) ml").tag(i)
                        }
                    }
                    .frame(width: 300)
                }
            }
            Section("Unidade") {
                Picker("Mostrar volumes em", selection: $store.prefs.unidade) {
                    Text("Mililitros (ml)").tag("ml")
                    Text("Onças (oz)").tag("oz")
                }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Verificação

struct AbaVerificacao: View {
    @ObservedObject var modelo: ModeloAjustes
    let aoTestar: @MainActor () -> Void

    var body: some View {
        Form {
            Section("Rigor da câmera") {
                HStack {
                    Text("Tempo bebendo exigido")
                    Slider(value: $modelo.rascunho.segundosBebendo, in: 1.5...6, step: 0.5)
                    Text(String(format: "%.1f s", modelo.rascunho.segundosBebendo)).monospacedDigit().frame(width: 50)
                }
                Toggle("Exigir que a câmera reconheça o copo ou a garrafa", isOn: $modelo.rascunho.exigirCopo)
                Dica(texto: "Sem essa opção, basta o rosto + mão na boca pelo tempo exigido. Com ela, o copo também precisa aparecer.")
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
            Section {
                Button("Testar agora (registra um copo se você beber)") { aoTestar() }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Aparência e som

struct AbaAparencia: View {
    @ObservedObject var store: Store
    let aoTestar: @MainActor () -> Void

    var body: some View {
        Form {
            Section("Você") {
                TextField("Como te chamar (opcional)", text: $store.prefs.nome)
                Toggle("Mostrar frases motivacionais", isOn: $store.prefs.frases)
            }
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
                Button("Pré-visualizar a tela de lembrete") { aoTestar() }
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
                    }
                }
            }
            Section("Barra de menus") {
                Picker("Ao lado da gota", selection: $store.prefs.barraMenu) {
                    Text("Quanto bebi (1,5 L)").tag("ml")
                    Text("Porcentagem da meta").tag("pct")
                    Text("Só o ícone").tag("icone")
                }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Widget

struct AbaWidget: View {
    @ObservedObject var store: Store
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
                Dica(texto: "O widget fica atrás de todas as janelas, como os widgets do Mac. Ele aparece no monitor principal.")
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
                        if let p = nivel.proximo {
                            Text(String(format: "faltam %.1f L para %@", nivel.faltaLitros, p)).font(.system(size: 12)).foregroundColor(.secondary)
                        } else {
                            Text("Nível máximo!").font(.system(size: 12)).foregroundColor(.secondary)
                        }
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
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], spacing: 10) {
                    ForEach(Gamificacao.conquistas) { c in
                        let data = store.estado.conquistas[c.id]
                        HStack(spacing: 10) {
                            Text(c.emoji).font(.system(size: 22)).grayscale(data == nil ? 1 : 0).opacity(data == nil ? 0.4 : 1)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(c.titulo).font(.system(size: 12.5, weight: .semibold))
                                Text(data.map { (d: Date) -> String in "Em \(Formatos.diaCurto.string(from: d))" } ?? c.descricao)
                                    .font(.system(size: 11)).foregroundColor(.secondary).lineLimit(2)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(data == nil ? 0.05 : 0.12)))
                    }
                }

                HStack {
                    let pulos = store.historico.pulos.count
                    Text(pulos == 0 ? "🛡️ Você nunca desligou o Mac para pular a água."
                                    : "Vezes que desligou o Mac para pular: \(pulos) (\(store.pulosHoje) hoje)")
                        .font(.system(size: 12.5)).foregroundColor(.secondary)
                    Spacer()
                    Button("Exportar CSV…") { exportar() }
                }
            }
            .padding(20)
        }
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

struct Grafico14Dias: View {
    @ObservedObject var store: Store
    var body: some View {
        let totais = store.totaisPorDia
        let meta = Double(max(1, store.regras.metaML))
        let hoje = Date().inicioDoDia
        let dias = (0..<14).reversed().map { calendario.date(byAdding: .day, value: -$0, to: hoje) ?? hoje }
        let maximo = max(meta * 1.2, Double(dias.map { totais[$0] ?? 0 }.max() ?? 0))
        GeometryReader { g in
            let alturaUtil = g.size.height - 18
            ZStack(alignment: .bottomLeading) {
                Rectangle()
                    .fill(Color.green.opacity(0.6))
                    .frame(height: 1)
                    .offset(y: -(18 + alturaUtil * CGFloat(meta / maximo)))
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(dias, id: \.self) { d in
                        let v = Double(totais[d] ?? 0)
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(v >= meta ? AnyShapeStyle(Estilo.verde) : AnyShapeStyle(Estilo.gradienteAgua))
                                .frame(height: max(3, alturaUtil * CGFloat(v / maximo)))
                            Text(Formatos.diaCurto.string(from: d).prefix(2))
                                .font(.system(size: 9.5)).foregroundColor(.secondary)
                                .frame(height: 14)
                        }
                        .frame(maxWidth: .infinity)
                        .help("\(Formatos.diaCurto.string(from: d)): \(store.fmt(Int(v)))")
                    }
                }
            }
        }
    }
}

// MARK: - Atualizações

struct AbaAtualizacoes: View {
    @ObservedObject var store: Store
    @ObservedObject var atualizador: Atualizador

    var novidades: String {
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
            }
            Section("De onde vêm as atualizações") {
                TextField("usuario/repositorio do GitHub", text: $store.prefs.fonteAtualizacao)
                Toggle("Atualizar sozinho (verifica a cada 6 horas)", isOn: $store.prefs.autoAtualizar)
                HStack {
                    Button(atualizador.ocupado ? "Trabalhando…" : "Verificar agora") { atualizador.verificar(manual: true) }
                        .disabled(atualizador.ocupado)
                    if atualizador.ocupado { ProgressView().controlSize(.small) }
                    Spacer()
                }
                if !atualizador.status.isEmpty {
                    Text(atualizador.status).font(.system(size: 12)).foregroundColor(.secondary).textSelection(.enabled)
                }
                Dica(texto: "O app baixa o código novo do GitHub, compila no seu Mac e se reinicia sozinho. Seu histórico e ajustes ficam intactos. Nunca atualiza com a tela azul aberta.")
            }
            Section("Novidades desta versão") {
                ScrollView {
                    Text(novidades).font(.system(size: 12)).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                }
                .frame(height: 180)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Controlador da janela

@MainActor
final class JanelaAjustes {
    private var janela: NSWindow?
    let modelo: ModeloAjustes
    private let store: Store
    private let atualizador: Atualizador
    var aoTestar: @MainActor () -> Void = {}

    init(store: Store, atualizador: Atualizador) {
        self.store = store
        self.atualizador = atualizador
        self.modelo = ModeloAjustes(regras: store.regras)
    }

    func abrir(aba: String) {
        if janela == nil {
            let j = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 640),
                             styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            j.title = "Ajustes do LembreteAgua"
            j.isReleasedWhenClosed = false
            j.contentView = NSHostingView(rootView: AjustesView(store: store, modelo: modelo, atualizador: atualizador,
                                                                aoTestar: { [weak self] in self?.aoTestar() }))
            j.center()
            janela = j
        }
        if !janela!.isVisible {
            modelo.rascunho = store.estado.pendente ?? store.regras
            modelo.mensagem = ""
        }
        modelo.aba = aba
        NSApp.activate(ignoringOtherApps: true)
        janela?.makeKeyAndOrderFront(nil)
    }

    func fechar() { janela?.orderOut(nil) }
}
