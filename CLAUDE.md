# OptPaste

App de barra de menus para macOS (Swift/SwiftUI + AppKit) que guarda o histórico da área de transferência e abre com um atalho global (padrão ⌥V).

## Commits

- Pode fazer as alterações e **commitar sem pedir confirmação** assim que cada unidade de trabalho (feat, fix, chore, refactor) estiver concluída.
- Antes de commitar, o projeto precisa compilar sem erros nem warnings:
  `xcodebuild -scheme OptPaste -configuration Debug build`
- Um commit por mudança lógica. Não misture uma feature com um fix sem relação.
- Mensagens no padrão Conventional Commits, em inglês, como no histórico: `feat: ...`, `fix: ...`, `chore: ...`, `refactor: ...`.
- Commite só os arquivos da mudança. Não inclua `xcuserdata/` (ex.: `UserInterfaceState.xcuserstate`).
- Commite na branch atual (normalmente `dev`). **Não faça push** nem abra PR sem pedido explícito.
