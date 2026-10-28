# Plano de lançamento do AeroSpaceTabs

Estado verificado em 28 de outubro de 2026. A versão publicada mais recente é [v0.2.3](https://github.com/pedrotmr/aerospace-tabs/releases/tag/v0.2.3). O repositório tem [0 estrelas](https://github.com/pedrotmr/aerospace-tabs). Os contadores dos assets nas releases somam [110 downloads](https://github.com/pedrotmr/aerospace-tabs/releases), incluindo ZIP, DMG e `appcast.xml`. Isso mede downloads de arquivos, não instalações ou pessoas; as contagens também incluem arquivos usados pelo Sparkle e versões antigas.

O README já mostra um vídeo de demonstração e oferece instalação pelo tap pessoal ou download direto. A captura de tela ainda é um placeholder, conforme o [issue #44](https://github.com/pedrotmr/aerospace-tabs/issues/44). O [issue #10](https://github.com/pedrotmr/aerospace-tabs/issues/10) registra uma verificação de instalação da v0.1.2 e ainda não confirma o funcionamento do strip, do overview ou da restauração de gaps. Antes de divulgar a v0.2.3, repetir essa verificação com a release atual em um Mac com AeroSpace.

## 1. Show HN

### Rascunho

**Título**

```text
Show HN: AeroSpaceTabs, a window tab strip and overview for AeroSpace
```

**Texto**

```text
I built AeroSpaceTabs for my AeroSpace setup. AeroSpace handles tiling; this macOS companion adds a tab strip for finding and focusing windows, plus a visual overview grouped by workspace.

It needs macOS 14 or later, AeroSpace running, and Accessibility permission. Screen Recording is optional for window previews. The app temporarily adjusts AeroSpace's top outer gap and normally restores the previous value when it quits. Trackpad swipe uses macOS's private MultitouchSupport framework, so it may break after a macOS update.

Try it: https://github.com/pedrotmr/aerospace-tabs/releases/latest
The README has a demo video and Homebrew instructions: https://github.com/pedrotmr/aerospace-tabs#readme

I would be interested in how the strip and workspace overview fit your AeroSpace workflow. I can answer questions in this thread. Maintenance is best-effort, and future replies or releases are not promised.
```

O título começa com `Show HN`, e o post leva a um app que o leitor pode instalar e testar, não a uma página de cadastro ou anúncio. O texto apresenta o que o autor construiu e como experimentar. Não pedir votos nem comentários a amigos. As regras também dizem que anúncios de versão e atualizações, por si só, não são um Show HN; por isso, apresentar o app e o problema que resolve, não a v0.2.3 como novidade. Fonte: [regras oficiais do Show HN](https://news.ycombinator.com/showhn.html).

Pré-condição: só publicar quando o autor puder acompanhar e responder no tópico. As regras esperam que o autor esteja disponível para conversar. O vídeo do README pode demonstrar o fluxo enquanto a captura real do issue #44 não existe; manter explícito que a imagem do README é placeholder.

## 2. AeroSpace Goodies

O [PR #35](https://github.com/pedrotmr/aerospace-tabs/pull/35) adicionou o trecho abaixo ao arquivo removido depois pelo [PR #46](https://github.com/pedrotmr/aerospace-tabs/pull/46). Reutilizar o snippet sem alterar o texto do produto:

```adoc
[#aerospace-tabs]
== Aerospace Tabs

https://github.com/pedrotmr/aerospace-tabs[Aerospace Tabs] - macOS 14+ companion app with a window tab strip and a visual overview grouped by AeroSpace workspace. Requires Accessibility; Screen Recording is optional for window previews. Temporarily increases AeroSpace's `gaps.outer.top` while running and restores it on quit.
```

Conferi o [arquivo atual `docs/goodies.adoc`](https://github.com/nikitabobko/AeroSpace/blob/main/docs/goodies.adoc): o anchor `[#spacelist]` ainda existe, depois dos exemplos de integrações. Inserir o snippet imediatamente antes dele, deixando uma linha em branco. A descrição continua compatível com o README atual: Acessibilidade é necessária, Gravação de Tela é opcional para previews, e o app ajusta temporariamente `gaps.outer.top`.

**Proposta de título para o PR upstream**

```text
goodies: Add Aerospace Tabs to the Goodies page
```

**Corpo sugerido**

```text
Add Aerospace Tabs to the Goodies page.

Current stable release: https://github.com/pedrotmr/aerospace-tabs/releases/tag/v0.2.3

The app requires Accessibility. Screen Recording is optional for window previews. It temporarily adjusts AeroSpace's gaps.outer.top and restores the previous value when it quits.
```

O documento anterior do PR #35 pedia validar uma instalação limpa antes de enviar. Atualizar essa etapa para a v0.2.3: instalar o ZIP atual, conceder Acessibilidade, confirmar strip e overview, sair e verificar a restauração de `gaps.outer.top`. Não abrir o PR upstream até esse teste estar registrado. A página Goodies convida contribuições por issue ou pull request, mas a decisão de aceitar é do mantenedor do AeroSpace.

## 3. Homebrew oficial

O caminho seria propor o cask em [`Homebrew/homebrew-cask`](https://github.com/Homebrew/homebrew-cask), mantendo o tap pessoal como rota de instalação enquanto isso. O [tap atual](https://github.com/pedrotmr/homebrew-aerospace-tabs) distribui o cask `pedrotmr/aerospace-tabs/pedrotmr-aerospace-tabs`; o [guia do projeto](../HOMEBREW.md) explica sua atualização automática a partir das releases estáveis.

A política geral exige interesse público além do autor. Em uma submissão do dono do repositório, a referência é **225 estrelas**, ou **90 forks** ou **90 watchers** no repositório canônico. O projeto hoje tem 0 estrelas. Os 110 downloads de assets não substituem esses indicadores. A política de casks também exige distribuição verificável e compatibilidade com o macOS atual. Além disso, a política geral exige manutenção ativa; o README promete manutenção best-effort, e os issues #10 e #44 dizem que o desenvolvimento está pausado. Com esse estado, não preparar uma submissão oficial agora. Reavaliar quando houver manutenção ativa e a métrica de notabilidade for atendida; a política prevê exceções, mas elas não garantem aceitação.

Fontes: [Package Acceptance Policy](https://docs.brew.sh/Package-Acceptance-Policy) e [Acceptable Casks](https://docs.brew.sh/Acceptable-Casks).

## Decisão

**Goodies primeiro.** Depois de testar a v0.2.3 em uma instalação limpa, propor o snippet ao AeroSpace. Essa entrada alcança diretamente quem já usa AeroSpace e não exige apresentar um projeto em manutenção ativa a uma audiência ampla. Fazer Show HN numa etapa seguinte, apenas se o autor puder acompanhar a conversa e responder perguntas. Não tentar Homebrew oficial enquanto o projeto estiver pausado e abaixo do critério de notabilidade.
