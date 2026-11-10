# LembreteAgua 💧

App de Mac que cobre todas as telas de azul até você **beber água na frente da câmera**. Ele não tem botão de pular. Cmd+Option+Esc e Cmd+Tab ficam bloqueados, e a única saída sem beber é desligar o Mac, o que fica registrado no histórico.

## Instalar

1. Baixe esta pasta para o Mac.
2. No Terminal, rode:

```bash
bash ~/Downloads/lembrete-agua/instalar.sh
```

Se o repositório já estiver no GitHub, rode isto no lugar dos dois passos acima:

```bash
curl -fsSL https://raw.githubusercontent.com/USUARIO/REPO/main/instalar.sh | bash -s USUARIO/REPO
```

Na primeira vez, o macOS pede as "Ferramentas de Linha de Comando" (gratuitas, da Apple). Depois de instalar, rode o comando de novo. Quando aparecer o pedido de acesso à câmera, clique em **Permitir**.

Para ver a tela azul na hora:

```bash
touch ~/Library/Application\ Support/LembreteAgua/testar
```

## Como as atualizações funcionam

```
você pede uma melhoria ao Claude
        ↓
Claude altera o código e aumenta o número em VERSION
        ↓
envia (push) para o GitHub (branch main)
        ↓
seu Mac verifica a cada 6 h (ou em Ajustes → Atualizações → Verificar agora)
        ↓
baixa, compila no próprio Mac, troca o app e reinicia sozinho
```

- O histórico e os ajustes ficam em `~/Library/Application Support/LembreteAgua/` e não são tocados.
- Campos novos de configuração entram com valor padrão, sem quebrar os arquivos antigos.
- O app nunca atualiza com a tela azul aberta.
- Se a compilação falhar, o app atual continua funcionando e o erro aparece em Ajustes → Atualizações.
- Depois de cada atualização o macOS pede a permissão da câmera de novo (1 clique). Isso acontece porque o app é assinado localmente.
- Se um dia precisar mudar algo da instalação (por exemplo, o LaunchAgent), coloque um `pos-atualizacao.sh` na raiz do repositório. O atualizador roda esse script automaticamente.

## Estrutura

| Arquivo | O que é |
|---|---|
| `Sources/App.swift` | Agenda, tela azul em todos os monitores, modo quiosque |
| `Sources/TelasLembrete.swift` | Telas: lembrete → quanto → câmera → sucesso |
| `Sources/Camera.swift` | Verificação com Vision (sem salvar nada) e detecção de chamada |
| `Sources/Ajustes.swift` | Janela de Ajustes (7 abas) |
| `Sources/Widget.swift` | Widget da área de trabalho, barra de menus, avisos |
| `Sources/Componentes.swift` | Cores, temas, formas, botões |
| `Sources/Modelo.swift` | Dados, regras, histórico, conquistas, níveis |
| `Sources/Atualizador.swift` | Atualização automática via GitHub |
| `build.sh` | Compila o `.app` |
| `instalar.sh` / `desinstalar.sh` | Instalação e remoção (com 60 s de espera) |
| `VERSION` / `NOVIDADES.md` | Versão atual e notas da versão |
| `prototipo.html` | Protótipo visual |
