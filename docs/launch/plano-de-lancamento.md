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
I use AeroSpace as my window manager, and I wanted an easier way to see which windows I had open across workspaces. So I built AeroSpaceTabs: it adds a tab strip for focusing windows and an overview grouped by workspace. AeroSpace still handles the tiling.

The current release is v0.2.3: https://github.com/pedrotmr/aerospace-tabs/releases/tag/v0.2.3

It needs macOS 14 or later, AeroSpace running, and Accessibility permission. Screen Recording is optional for window previews. The app adjusts AeroSpace's top gap while it runs and normally restores the old value when it quits. The trackpad gesture uses a private macOS framework, so it may break after a system update.

There's a short demo and install instructions in the README: https://github.com/pedrotmr/aerospace-tabs#readme

I made this for my own setup, and I'm curious whether the strip or overview would be useful in yours. I'll be here to answer questions. I maintain the app when I can, but I don't have a release schedule.
```

O título começa com `Show HN`, e o post leva a um app que o leitor pode instalar e testar. O primeiro parágrafo explica o motivo pessoal do app antes de falar da versão e dos requisitos. As regras dizem que um anúncio de versão, por si só, não é um Show HN. Não pedir votos nem comentários a amigos. Fonte: [regras oficiais do Show HN](https://news.ycombinator.com/showhn.html).

Só publicar quando o autor puder acompanhar o tópico e responder às perguntas. O README ainda tem um placeholder no lugar de uma captura real, conforme o [issue #44](https://github.com/pedrotmr/aerospace-tabs/issues/44); usar o vídeo de demonstração e não chamar o placeholder de screenshot.

## 2. Reddit

### r/macOS

**Título**

```text
I made AeroSpaceTabs because I kept losing track of windows across AeroSpace workspaces
```

**Texto**

```text
Hi, I'm the developer of AeroSpaceTabs. I use AeroSpace every day and wanted a quicker way to see which windows I had open in each workspace.

I made a small tab strip for switching to a window, plus a full-screen overview grouped by workspace. AeroSpace still does the tiling. The current release is v0.2.3: https://github.com/pedrotmr/aerospace-tabs/releases/tag/v0.2.3

It needs macOS 14 or later, AeroSpace running, and Accessibility permission. Screen Recording is optional for window previews. There's a demo in the README: https://github.com/pedrotmr/aerospace-tabs#readme

I built it for my own setup, but I'd like to hear whether it fits yours. I'm the developer and will answer questions here.
```

O texto abre com o motivo pessoal, depois explica o app e só então lista versão e requisitos. A regra atual de [r/macOS](https://www.reddit.com/r/MacOS/comments/1rsxzup/new_policy_introducing_developer_saturday/) permite promoção de apps aos sábados, no horário UTC, com um post promocional por pessoa na semana. Ela pede transparência sobre a relação com o app, contexto em vez de apenas um link, e recomenda uma captura de qualidade e participação nos comentários. Como o README ainda usa um placeholder de screenshot, usar o vídeo demonstrativo e, se possível, esperar uma captura real antes de postar.

### r/MacApps

Não usar o feed principal como primeiro destino. As regras atuais limitam promoções a uma por desenvolvedor a cada 30 dias e exigem pelo menos 10 pontos de karma na comunidade. A moderação descreve um caminho de confiança para projetos com histórico consistente e interesse público; para a megathread, cita um repositório com um ano de histórico ou 100 ou mais estrelas. Este repositório foi [criado em 5 de setembro de 2026](https://api.github.com/repos/pedrotmr/aerospace-tabs) e tem [0 estrelas](https://github.com/pedrotmr/aerospace-tabs), então ainda não alcança esses sinais. Há também um caminho de transparência que exige portfólio público com identidade e contato, além de site com política de privacidade e termos. Se esses requisitos não estiverem atendidos, a própria moderação direciona promoções ao megathread “The App Pile”. Conferir [as regras atuais](https://www.reddit.com/r/macapps/comments/1ryaeex/rmacapps_mods_went_too_far_whats-changing-phase_3/) no dia antes de decidir.

Não copiar e colar o mesmo texto em vários subs. As regras de Reddit podem variar; escolher uma comunidade, ler as regras do momento e adaptar o texto. Os moderadores de r/macOS pedem um post por semana, e r/MacApps limita a promoção a uma vez por 30 dias.

## 3. AeroSpace Goodies

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

## 4. Homebrew oficial

O caminho seria propor o cask em [`Homebrew/homebrew-cask`](https://github.com/Homebrew/homebrew-cask), mantendo o tap pessoal como rota de instalação enquanto isso. O [tap atual](https://github.com/pedrotmr/homebrew-aerospace-tabs) distribui o cask `pedrotmr/aerospace-tabs/pedrotmr-aerospace-tabs`; o [guia do projeto](../HOMEBREW.md) explica sua atualização automática a partir das releases estáveis.

A política geral exige interesse público além do autor. Em uma submissão do dono do repositório, a referência é **225 estrelas**, ou **90 forks** ou **90 watchers** no repositório canônico. O projeto hoje tem 0 estrelas. Os 110 downloads de assets não substituem esses indicadores. A política de casks também exige distribuição verificável e compatibilidade com o macOS atual. Além disso, a política geral exige manutenção ativa; o README promete manutenção best-effort, e os issues #10 e #44 dizem que o desenvolvimento está pausado. Com esse estado, não preparar uma submissão oficial agora. Reavaliar quando houver manutenção ativa e a métrica de notabilidade for atendida; a política prevê exceções, mas elas não garantem aceitação.

Fontes: [Package Acceptance Policy](https://docs.brew.sh/Package-Acceptance-Policy) e [Acceptable Casks](https://docs.brew.sh/Acceptable-Casks).

## Decisão

**Posts públicos primeiro, Goodies depois.** Primeiro, validar a v0.2.3 em uma instalação limpa. Depois, publicar no Show HN quando o autor puder acompanhar a conversa; em seguida, escolher uma única comunidade no Reddit onde o post seja permitido e adaptar o texto às regras locais. Só então propor o snippet ao AeroSpace Goodies. A página atual convida contribuições por issue ou pull request, então não encontrei uma restrição contra esse tipo de entrada; a aceitação continua a critério do mantenedor. Não tentar Homebrew oficial enquanto o projeto estiver pausado e abaixo do critério de notabilidade.
