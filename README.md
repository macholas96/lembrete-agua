# LembreteAgua 💧

App de Mac que cobre todas as telas de azul até você **beber água na frente da câmera**. Não tem botão de pular, e nenhuma foto é salva.

## Instalar (usuários)

1. Baixe o **LembreteAgua.dmg** da [última versão](https://github.com/macholas96/lembrete-agua/releases/latest).
2. Abra o DMG e arraste o LembreteAgua para **Aplicativos**.
3. Abra o app. As boas-vindas explicam tudo e pedem as permissões (câmera e segundo plano).

> **Primeira abertura.** Enquanto o app não for assinado pela Apple (Developer ID), o macOS mostra um aviso na primeira vez. Para liberar: **Ajustes do Sistema → Privacidade e Segurança → "Abrir Mesmo Assim"**. Isso é preciso só uma vez.

Instalação alternativa pelo Terminal (baixa o app pronto e migra a instalação antiga):

```bash
curl -fsSL https://raw.githubusercontent.com/macholas96/lembrete-agua/main/instalar.sh | bash
```

## Atualizações

- O app verifica as [Releases](https://github.com/macholas96/lembrete-agua/releases) a cada 6 h. Quando há versão nova, ele **avisa** com as novidades e mostra um ponto na gotinha 💧.
- A pessoa decide quando clicar em **Atualizar**. O app baixa a versão pronta, troca a si mesmo e reabre. Histórico e ajustes não são tocados.
- O app **nunca instala sozinho**.

## Publicar uma versão nova (mantenedor)

1. Faça as mudanças em `Sources/` e envie para `main`. O GitHub Actions compila a cada push (aba Actions), e isso não afeta nenhum usuário.
2. Aumente o número em `VERSION` (ex.: `1.2.0`) e escreva as novidades no topo do `NOVIDADES.md`.
3. Crie e envie a tag:

```bash
git tag v1.2.0
```

```bash
git push origin v1.2.0
```

4. O Actions compila (Apple Silicon + Intel), gera o **DMG** e o **zip** e cria a Release. A partir daí, os usuários veem "Nova versão disponível".

## Assinatura e notarização (para abrir sem aviso)

Com uma conta Apple Developer (US$ 99/ano):

- **Assinatura:** o `build.sh` já assina com Developer ID quando a variável `IDENTIDADE_ASSINATURA` existe.
- **Falta adicionar ao workflow:** importar o certificado e rodar `xcrun notarytool submit … --wait` e `xcrun stapler staple` no DMG.

Com isso:

- o aviso da primeira abertura some;
- a permissão da câmera deixa de ser pedida de novo a cada atualização.

## Estrutura

| Arquivo | O que é |
|---|---|
| `Sources/App.swift` | Agenda, tela azul em todos os monitores, modo quiosque, abertura |
| `Sources/BoasVindas.swift` | Slides de boas-vindas + permissões |
| `Sources/TelasLembrete.swift` | Telas: lembrete → quanto → câmera → sucesso |
| `Sources/Camera.swift` | Verificação com Vision (sem salvar nada) e câmera em uso |
| `Sources/Sistema.swift` | Permissões, segundo plano (SMAppService), chamadas (câmera/microfone) |
| `Sources/Ajustes.swift` | Janela de Ajustes (10 páginas, com botões de teste) |
| `Sources/Widget.swift` | Widget da área de trabalho, barra de menus, avisos |
| `Sources/Componentes.swift` | Cores, temas, formas, botões |
| `Sources/Modelo.swift` | Dados, regras, catálogo de garrafas, histórico, conquistas |
| `Sources/Atualizador.swift` | Verifica Releases e instala só com clique |
| `Recursos/` | Ícone, fundo do DMG, agente de segundo plano |
| `build.sh` / `scripts/criar-dmg.sh` | Compila o `.app` / gera o DMG |
| `.github/workflows/build.yml` | Compila a cada push e publica as Releases |
