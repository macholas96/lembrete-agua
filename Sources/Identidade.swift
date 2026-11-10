import SwiftUI
import AppKit

// Identidade visual própria do LembreteAgua: controles desenhados por nós,
// em vez dos controles padrão do macOS.

enum Marca {
    static let fundo = LinearGradient(colors: [Color(red: 0.95, green: 0.97, blue: 1), Color(red: 0.90, green: 0.95, blue: 1)],
                                      startPoint: .top, endPoint: .bottom)
    static let cartao = Color.white
    static let borda = Color(red: 0.86, green: 0.91, blue: 0.97)
    static let azulClaro = Color(red: 0.91, green: 0.95, blue: 1)
    static let trilho = Color(red: 0.86, green: 0.90, blue: 0.95)
}

// MARK: - Cartões e linhas

struct CartaoSecao<Conteudo: View>: View {
    let titulo: String
    var icone: String? = nil
    @ViewBuilder let conteudo: () -> Conteudo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let icone { Image(systemName: icone).font(.system(size: 11, weight: .bold)) }
                Text(titulo.uppercased()).font(.system(size: 11, weight: .bold)).tracking(0.6)
            }
            .foregroundColor(Estilo.azul)
            .padding(.leading, 4)
            VStack(alignment: .leading, spacing: 0) { conteudo() }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Marca.cartao))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Marca.borda, lineWidth: 1))
                .shadow(color: Color(red: 0.1, green: 0.3, blue: 0.6).opacity(0.06), radius: 8, y: 3)
        }
    }
}

struct LinhaAjuste<Controle: View>: View {
    let titulo: String
    var detalhe: String? = nil
    var ultima = false
    @ViewBuilder let controle: () -> Controle

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo).font(.system(size: 13.5, weight: .medium)).foregroundColor(Estilo.tinta)
                if let detalhe {
                    Text(detalhe).font(.system(size: 11.5)).foregroundColor(Estilo.tinta3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            controle()
        }
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) {
            if !ultima { Rectangle().fill(Marca.borda.opacity(0.7)).frame(height: 1) }
        }
    }
}

struct TextoAjuda: View {
    let texto: String
    var body: some View {
        Text(texto).font(.system(size: 11.5)).foregroundColor(Estilo.tinta3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 8)
    }
}

// MARK: - Interruptor

struct InterruptorAgua: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 10) {
            configuration.label
            Spacer(minLength: 0)
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn ? AnyShapeStyle(Estilo.gradienteBotao) : AnyShapeStyle(Marca.trilho))
                    .frame(width: 46, height: 27)
                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
                    .frame(width: 23, height: 23)
                    .overlay {
                        if configuration.isOn {
                            Image(systemName: "drop.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Estilo.azul)
                        }
                    }
                    .padding(2)
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.75), value: configuration.isOn)
            .onTapGesture { configuration.isOn.toggle() }
        }
    }
}

/// Linha com interruptor.
struct LinhaInterruptor: View {
    let titulo: String
    var detalhe: String? = nil
    var ultima = false
    @Binding var ligado: Bool

    var body: some View {
        LinhaAjuste(titulo: titulo, detalhe: detalhe, ultima: ultima) {
            Toggle("", isOn: $ligado).labelsHidden().toggleStyle(InterruptorAgua())
        }
    }
}

// MARK: - Segmentos

struct SegmentosAgua<Valor: Hashable>: View {
    let opcoes: [(valor: Valor, rotulo: String)]
    @Binding var selecao: Valor
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<opcoes.count, id: \.self) { i in
                let op = opcoes[i]
                let sel = op.valor == selecao
                Text(op.rotulo)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(sel ? .white : Estilo.tinta2)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background {
                        if sel {
                            Capsule().fill(Estilo.gradienteBotao).matchedGeometryEffect(id: "sel", in: ns)
                        }
                    }
                    .contentShape(Capsule())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selecao = op.valor }
                    }
            }
        }
        .padding(3)
        .background(Capsule().fill(Marca.azulClaro))
        .fixedSize()
    }
}

// MARK: - Passo (− valor +)

struct PassoAgua: View {
    @Binding var valor: Int
    let faixa: ClosedRange<Int>
    let passo: Int
    let texto: (Int) -> String

    var body: some View {
        HStack(spacing: 6) {
            botao("minus") { valor = max(faixa.lowerBound, valor - passo) }
                .disabled(valor <= faixa.lowerBound)
            Text(texto(valor))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(Estilo.tinta)
                .monospacedDigit()
                .frame(minWidth: 74)
            botao("plus") { valor = min(faixa.upperBound, valor + passo) }
                .disabled(valor >= faixa.upperBound)
        }
        .padding(3)
        .background(Capsule().fill(Marca.azulClaro))
    }

    private func botao(_ icone: String, _ acao: @escaping () -> Void) -> some View {
        Button(action: acao) {
            Image(systemName: icone)
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(Estilo.azul)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.white))
                .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }
}

/// Horário em passos de 15 min.
struct HoraAgua: View {
    @Binding var minutos: Int
    var body: some View {
        PassoAgua(valor: $minutos, faixa: 0...(24 * 60 - 15), passo: 15) { m in
            String(format: "%02d:%02d", m / 60, m % 60)
        }
    }
}

// MARK: - Slider

struct SliderAgua: View {
    @Binding var valor: Double
    let faixa: ClosedRange<Double>
    var passo: Double? = nil

    var body: some View {
        GeometryReader { g in
            let largura = max(1, g.size.width - 22)
            let frac = (valor - faixa.lowerBound) / (faixa.upperBound - faixa.lowerBound)
            ZStack(alignment: .leading) {
                Capsule().fill(Marca.trilho).frame(height: 6).padding(.horizontal, 11)
                Capsule().fill(Estilo.gradienteBotao)
                    .frame(width: max(6, largura * CGFloat(frac)), height: 6)
                    .padding(.leading, 11)
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().stroke(Estilo.azul, lineWidth: 2.5))
                    .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                    .frame(width: 22, height: 22)
                    .offset(x: largura * CGFloat(frac))
            }
            .frame(height: g.size.height)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                let f = min(1, max(0, Double((v.location.x - 11) / largura)))
                var novo = faixa.lowerBound + f * (faixa.upperBound - faixa.lowerBound)
                if let passo { novo = (novo / passo).rounded() * passo }
                valor = min(faixa.upperBound, max(faixa.lowerBound, novo))
            })
        }
        .frame(height: 24)
    }
}

// MARK: - Botões

struct BotaoAgua: ButtonStyle {
    enum Tipo { case primario, secundario, discreto }
    var tipo: Tipo = .primario
    var grande = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: grande ? 14.5 : 12.5, weight: .semibold))
            .foregroundColor(tipo == .primario ? .white : Estilo.azul)
            .padding(.vertical, grande ? 10 : 7)
            .padding(.horizontal, grande ? 20 : 14)
            .background(fundo)
            .overlay(
                Capsule().stroke(tipo == .discreto ? Marca.borda : Color.clear, lineWidth: 1)
            )
            .shadow(color: tipo == .primario ? Estilo.azul.opacity(0.28) : .clear, radius: 6, y: 3)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .contentShape(Capsule())
    }

    @ViewBuilder private var fundo: some View {
        switch tipo {
        case .primario: Capsule().fill(Estilo.gradienteBotao)
        case .secundario: Capsule().fill(Marca.azulClaro)
        case .discreto: Capsule().fill(Color.white)
        }
    }
}

// MARK: - Menu e campo de texto

struct MenuAgua<Valor: Hashable>: View {
    let opcoes: [(valor: Valor, rotulo: String)]
    @Binding var selecao: Valor
    var largura: CGFloat? = nil

    var body: some View {
        Menu {
            ForEach(0..<opcoes.count, id: \.self) { i in
                Button(opcoes[i].rotulo) { selecao = opcoes[i].valor }
            }
        } label: {
            HStack(spacing: 6) {
                Text(opcoes.first { $0.valor == selecao }?.rotulo ?? "—")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(Estilo.tinta)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: largura == nil ? nil : CGFloat.infinity, alignment: .leading)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Estilo.azul)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .frame(width: largura)
            .background(Capsule().fill(Marca.azulClaro))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

struct CampoAgua: View {
    let dica: String
    @Binding var texto: String
    var largura: CGFloat? = nil

    var body: some View {
        TextField(dica, text: $texto)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .foregroundColor(Estilo.tinta)
            .padding(.vertical, 7)
            .padding(.horizontal, 12)
            .frame(width: largura)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Marca.azulClaro))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Marca.borda, lineWidth: 1))
    }
}

/// Página de ajustes rolável com o fundo da marca.
struct PaginaRolavel<Conteudo: View>: View {
    @ViewBuilder let conteudo: () -> Conteudo
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) { conteudo() }
                .padding(.horizontal, 26)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
