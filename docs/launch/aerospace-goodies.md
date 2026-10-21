# AeroSpace Goodies

Abrir um pull request em `nikitabobko/AeroSpace` inserindo o trecho abaixo em `docs/goodies.adoc`, imediatamente antes de `[#spacelist]`. O pedido fica aberto. Quem aceita é o mantenedor de lá.

Este arquivo fica em `pedrotmr/aerospace-tabs`. Termina quando o pull request existe e a URL foi guardada.

## Antes de enviar

Pare se qualquer item falhar.

1. https://github.com/pedrotmr/aerospace-tabs/releases/tag/v0.1.1 está publicada, sem o rótulo Draft, com o arquivo `AerospaceTabs.zip`. Esta é a release estável. A tag `v0.1.0` não é uma GitHub Release e não inclui `AerospaceTabs.zip`.
2. Num Mac com macOS 14+ e o AeroSpace já em execução: baixar o ZIP, mover `AerospaceTabs.app` para Aplicativos, abrir, permitir Acessibilidade, recusar Gravação de Tela, abrir duas janelas e ver a faixa no topo. Sair por **Quit Aerospace Tabs**.

## Enviar

Arquivo: https://github.com/nikitabobko/AeroSpace/blob/main/docs/goodies.adoc

Pelo site: lápis, **Fork this repository**, colar o trecho no início da linha `[#spacelist]`, **Commit changes...**, **Propose changes**, **Create pull request**. A base fica `nikitabobko/AeroSpace` / `main`.

Pelo `gh`: fork, branch a partir de `main`, editar o arquivo, abrir o pull request para `nikitabobko/AeroSpace:main`.

O trecho fica nesta ordem, com uma linha em branco antes de `[#spacelist]`:

```adoc
[#aerospace-tabs]
== Aerospace Tabs

https://github.com/pedrotmr/aerospace-tabs[Aerospace Tabs] - macOS 14+ companion app with a window tab strip and a visual overview grouped by AeroSpace workspace. Requires Accessibility; Screen Recording is optional for window previews. Temporarily increases AeroSpace's `gaps.outer.top` while running and restores it on quit.
```

Mensagem de commit e título do pull request:

```text
goodies: Add Aerospace Tabs to the Goodies page

List the released companion with a factual summary of its window views,
permission requirements, and temporary gaps.outer.top adjustment.
```

Corpo:

```text
Add Aerospace Tabs to the Goodies page.

Public release: https://github.com/pedrotmr/aerospace-tabs/releases/tag/v0.1.1
The download file on that page is AerospaceTabs.zip.

The app needs Accessibility permission. Screen Recording is optional and is only used for window previews. While the app is open it temporarily increases AeroSpace's gaps.outer.top and restores the previous value when it quits.
```

Pronto quando a URL é `https://github.com/nikitabobko/AeroSpace/pull/<número>`.

## Próxima release estável

A estável é a última GitHub Release publicada, não prerelease, com `AerospaceTabs.zip`. O Release Please cria essa release como rascunho; publicar é um passo separado.

Quando outra estável existir:

1. Trocar aqui o link e o número da v0.1.1.
2. Repetir o teste do ZIP.
3. Deixar o trecho AsciiDoc como está se continuarem iguais: macOS 14+, Acessibilidade obrigatória, Gravação de Tela opcional, e `gaps.outer.top` aumentado só enquanto o app está aberto.
4. Se um desses fatos mudar, editar o trecho e abrir outro pull request no AeroSpace.
