# OptPaste

App de barra de menus para macOS (Swift/SwiftUI + AppKit) que guarda o histórico da área de transferência e abre com um atalho global (padrão ⌥V).

## Commits

- Pode fazer as alterações e **commitar sem pedir confirmação** assim que cada unidade de trabalho (feat, fix, chore, refactor) estiver concluída.
- Antes de commitar, o projeto precisa compilar sem erros nem warnings:
  `xcodebuild -scheme OptPaste -configuration Debug build`
- Um commit por mudança lógica. Não misture uma feature com um fix sem relação.
- Mensagens no padrão Conventional Commits, em inglês, como no histórico: `feat: ...`, `fix: ...`, `chore: ...`, `refactor: ...`.
- Commite só os arquivos da mudança. Não inclua `xcuserdata/` (ex.: `UserInterfaceState.xcuserstate`).
- Commite na branch atual (normalmente `dev`) e **faça push logo em seguida**, sem pedir confirmação, a cada feat/fix/chore/refactor concluído. Não abra PR sem pedido explícito.

## Releases

- Depois de cada `feat` ou `fix` no app (já commitado e com push), publique uma versão nova com
  `scripts/release.sh <versão>`, sem pedir confirmação.
- Versão: enquanto for beta, incremente o número do beta (`1.0.0-beta.1` → `1.0.0-beta.2`). Depois da versão
  estável, `fix` sobe o patch (`1.0.1`) e `feat` sobe o minor (`1.1.0`). A versão atual é a última tag `v*`.
- O script atualiza a versão, gera o `.dmg` (com `scripts/make-dmg.sh`), publica no site (`../optpaste-site`:
  `public/downloads/OptPaste.dmg`, `public/appcast.xml` e `public/latest.json`), cria a tag e a release no GitHub.
  As notas são os commits `feat`/`fix` desde a tag anterior, então capriche nas mensagens.
- Atualizações automáticas usam o Sparkle (`OptPaste/Updater.swift`). O app lê o `appcast.xml` (`SUFeedURL` no
  `Info.plist`) e só instala o que estiver assinado com a chave EdDSA cuja parte pública é o `SUPublicEDKey`. A
  chave privada fica no Keychain de login; sem ela não dá para publicar atualizações.
- `chore` e `refactor` sozinhos não geram release.
