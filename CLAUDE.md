# Guia para manutenção (Claude)

- App macOS 13+ em Swift/SwiftUI/AppKit, sem Xcode project: tudo compila com `build.sh` (swiftc direto). Idioma da interface: português do Brasil.
- **Não há compilador neste ambiente.** O GitHub Actions (`.github/workflows/build.yml`) compila a cada push em `main`. Depois de enviar, acompanhe o resultado e corrija até ficar verde:
  - `gh api repos/macholas96/lembrete-agua/actions/runs --jq '.workflow_runs[0] | {status, conclusion, html_url}'`
  - `gh api repos/macholas96/lembrete-agua/actions/runs/<id>/jobs` e os logs do job que falhou.
- **Pensar sempre em escala (N usuários):**
  - nada é instalado sem clique;
  - atualizações saem só por Release, criada quando `VERSION` muda;
  - campos novos de configuração precisam de valor padrão (o `JSON.carregar` mescla com os padrões).
- **Para lançar uma versão:**
  1. Suba o número em `VERSION` e escreva as novidades no topo de `NOVIDADES.md`.
  2. Envie para `main` e espere o build passar.
  3. Pronto: o workflow cria a Release `vX.Y.Z` com DMG e zip sozinho quando o número é novo. Enviar para `main` sem mudar `VERSION` só compila, sem afetar usuários.
- **Regras do produto que não podem ser quebradas:**
  - sem botão de pular;
  - Cmd+Option+Esc bloqueado durante a tela azul;
  - nenhuma foto salva;
  - mudanças que afrouxam regras só valem no dia seguinte;
  - durante chamadas o lembrete espera.
- Commits sem nome de modelo.
