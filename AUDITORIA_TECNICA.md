# Auditoria Técnica: Xadrez Maia (maia_chess)

Auditoria realizada por leitura integral de `lib/` (30 arquivos, 6.177 linhas
sem contar código gerado), `test/`, `integration_test/`, `android/`,
`pubspec.yaml`, `analysis_options.yaml` e execução das ferramentas de
análise estática. Todo achado abaixo cita arquivo e linha; onde a evidência é
saída de comando, o comando e seu resultado estão reproduzidos.

## Resumo executivo

- 🔴 Críticos: 0
- 🟠 Altos: 4
- 🟡 Médios: 5
- 🟢 Baixos: 5
- Informativo (fora do escopo do app): 1
- Cobertura de testes (`flutter test --coverage`, unitários/widget): **50,4%**
  (2.243/4.451 linhas instrumentadas). Os dois arquivos com a lógica mais
  delicada do app, `lc0_service.dart` e `stockfish_service.dart`, estão em
  **0%**: só são exercitados pelos `integration_test/` em dispositivo real.
- Stack detectada: Riverpod (`flutter_riverpod` 2.6.1, `Notifier`/
  `ConsumerWidget`, sem mistura com `setState` cru fora de estado puramente
  visual local), arquitetura feature-first com camada `data/repositories`
  separada da UI (padrão repository + Drift/SQLite), organização consistente
  em todos os módulos. Flutter 3.41.9 (via `fvm`) • Dart 3.11.5 • minSdk 24 /
  targetSdk 36 / compileSdk 36.
- `flutter analyze --no-fatal-infos`: **nenhum problema encontrado**.
- `flutter test`: **50/50 testes passando**.
- O projeto **não está sob controle de versão** (não há diretório `.git`) e
  **não possui pipeline de CI/CD** (ver AUD-001/AUD-002).

A qualidade geral do código é alta para os padrões deste checklist: não há
`print()`, não há `catch` vazio ou que só engole a exceção, os usos de
`context.mounted`/`mounted` após `await` estão corretos em todos os pontos
verificados, não há segredos/chaves hardcoded, o app não solicita permissão
de rede no `AndroidManifest.xml` (condizente com a promessa de app 100%
offline) e o histórico de decisões em `ADR.md` documenta com honestidade
bugs de concorrência já encontrados e corrigidos (race no `dispose()` dos
motores FFI, colisão de `stdin`/`stdout` entre lc0 e Stockfish). Os achados
abaixo são, portanto, majoritariamente de processo (versionamento, CI,
cobertura) e de dívida técnica pontual, não de corretude do domínio de
xadrez em si.

## Top 10 prioridades (ordem de ação recomendada)

1. **AUD-001**: Inicializar o repositório git antes de qualquer outra ação (pré-requisito para os itens seguintes).
2. **AUD-006**: Substituir a assinatura de debug no build de release antes de qualquer distribuição real do APK.
3. **AUD-002**: Adicionar um pipeline mínimo de CI (`flutter analyze`, `dart format --set-exit-if-changed lib test integration_test`, `flutter test --coverage`).
4. **AUD-003**: Cobrir `Lc0Service`/`StockfishService` com testes que exercitem diretamente o handshake, o timeout e a rotina de `dispose()` (não só via `GameController` com fakes).
5. **AUD-009**: Unificar a regra de cálculo de `PlayerGameOutcome`, hoje duplicada em `app_database.dart` e `drift_stats_repository.dart`.
6. **AUD-004**: Escrever testes de widget para `NewGameVsAiScreen` (tela de entrada do modo IA, 2% de cobertura).
7. **AUD-007**: Decidir explicitamente sobre `minifyEnabled`/`shrinkResources` e, se ativados, adicionar `proguard-rules.pro` cobrindo Drift/FFI antes de testar em release.
8. **AUD-010**: Remover ou mover `SpikeScreen` para fora de `lib/` (dívida da Fase 0, sem rota que a alcance).
9. **AUD-011**: Decidir o destino de `clockEnabled`/`whiteTimeMs`/`blackTimeMs`: implementar a contagem de relógio ou remover o campo até a feature ser priorizada.
10. **AUD-014**: Avaliar regras de lint adicionais (ex.: `very_good_analysis` ou regras manuais de `analysis_options.yaml`) além do `flutter_lints` padrão.

## Achados detalhados

### CI/CD, versionamento e tooling (seção 6.15)

#### [AUD-001] 🟠 Controle de versão ausente
- **Categoria:** 6.15, CI/CD e tooling
- **Arquivo:** raiz do projeto (`/home/lucas/maia_android`)
- **Evidência:** `ls -la /home/lucas/maia_android/.git` retorna "Arquivo ou
  diretório inexistente"; o ambiente da sessão também reporta
  `Is a git repository: false`. Ao mesmo tempo, `ADR.md` (ADR-001, addendum)
  descreve arquivos gerados que "ficam commitados neste repositório" e o
  `.gitignore` tem regras específicas para não versionar artefatos de build
  nativos, ou seja, o projeto foi desenhado presumindo controle de versão,
  mas não está sob um.
- **Problema:** sem git não há histórico, não há como revisar diffs, reverter
  uma mudança que quebre o build nativo (que já se mostrou frágil, ver os
  três addenda do ADR-001) nem abrir um pull request para o processo de lote
  descrito na seção 2 deste próprio processo de auditoria. Qualquer CI
  também depende de um repositório para existir.
- **Sugestão:** `git init`, primeiro commit abrangendo o estado atual
  (excluindo `build/`, `.dart_tool/` etc., já cobertos pelo `.gitignore`
  existente), e adoção de um fluxo de branch antes da próxima mudança.
- **Esforço estimado:** P

#### [AUD-002] 🟠 Nenhum pipeline de CI/CD configurado
- **Categoria:** 6.15, CI/CD e tooling
- **Arquivo:** N/A. Ausência confirmada em `.github/workflows`,
  `.gitlab-ci.yml`, `codemagic.yaml` e `bitrise.yml` na raiz do projeto. Os
  três `.gitlab-ci.yml` encontrados por `find` pertencem ao Eigen,
  dependência de terceiros vendorizada dentro de
  `native/leela_chess_zero/android/.cxx/.../eigen-src/`, não ao projeto.
- **Evidência:** `find /home/lucas/maia_android -maxdepth 2 -iname "*.yml" -o -iname "*.yaml"` só retorna `analysis_options.yaml` e `pubspec.yaml`.
- **Problema:** o próprio `ADR.md` documenta pelo menos dois bugs de
  concorrência sérios (race de `dispose()` entre motores FFI; colisão de
  `stdin`/`stdout` entre lc0 e Stockfish) que só foram pegos em testes de
  integração manuais em emulador. Sem CI rodando `flutter analyze`,
  `dart format --set-exit-if-changed` e a suíte de testes a cada mudança,
  regressões desse tipo podem voltar silenciosamente.
- **Sugestão:** workflow mínimo (GitHub Actions ou equivalente) com os três
  gates de Fase 1 deste processo de auditoria. Os `integration_test/`
  dependem de emulador Android e podem ficar de fora do gate obrigatório
  inicialmente, mas os testes unitários/widget (50 hoje, todos passando) não
  têm essa restrição.
- **Esforço estimado:** P

### Testes (seção 6.10)

#### [AUD-003] 🟠 0% de cobertura nos serviços de motor FFI
- **Categoria:** 6.10, Testes
- **Arquivo:** `lib/engine_ffi/lc0_engine/lc0_service.dart` (0/138 linhas),
  `lib/engine_ffi/stockfish_engine/stockfish_service.dart` (0/132 linhas)
- **Evidência:** cálculo direto sobre `coverage/lcov.info` gerado por
  `flutter test --coverage`:
  ```
  lib/engine_ffi/lc0_engine/lc0_service.dart          0/138 (0%)
  lib/engine_ffi/stockfish_engine/stockfish_service.dart  0/132 (0%)
  ```
  `test/game_controller_test.dart` testa `GameController` usando fakes
  injetados via `lc0EngineFactoryProvider`/`stockfishEngineFactoryProvider`
  (ver `game_controller.dart:23-28`), por desenho (ADR-008), para não
  depender de FFI em testes unitários. Isso, no entanto, significa que a
  implementação real de `Lc0Service`/`StockfishService` (handshake
  `isready`/`readyok`, timeout de busca com `stop`, e a rotina de
  `_terminateEngine` que evita o `Bad state: Multiple instances are not
  supported` documentado em ADR-001) só é exercitada pelos
  `integration_test/*_android_test.dart`, que exigem emulador/dispositivo
  físico e não rodam em `flutter test`.
- **Problema:** exatamente a lógica que já causou dois bugs de produção
  documentados no próprio `ADR.md` está sem rede de segurança automatizada
  fora de execução manual em dispositivo. Uma regressão nessa área só seria
  percebida jogando manualmente contra a IA.
- **Sugestão:** extrair a lógica de espera de estado (`_waitReadyOk`,
  `_terminateEngine`, tratamento de timeout com `stop`) para que possa ser
  testada com um `Lc0`/`Stockfish` fake que simule as transições de estado
  (`Lc0State`/`StockfishState`) via `ValueNotifier`, sem precisar do FFI
  real. Os pacotes já expõem essas classes como injetáveis.
- **Esforço estimado:** M

#### [AUD-004] 🟡 Tela de novo jogo contra IA praticamente sem testes
- **Categoria:** 6.10, Testes
- **Arquivo:** `lib/features/difficulty/presentation/new_game_vs_ai_screen.dart`
- **Evidência:** `coverage/lcov.info` reporta 1/45 linhas (2%) cobertas para
  este arquivo; não há nenhum teste em `test/` que importe
  `NewGameVsAiScreen`.
- **Problema:** é o ponto de entrada principal do modo "livre contra a IA"
  (seleção de lado e nível, `new_game_vs_ai_screen.dart:24-49`), incluindo o
  caminho de erro quando `startVsAi` falha (linhas 33-41). Nenhum desses
  caminhos tem cobertura de widget test.
- **Sugestão:** um teste de widget cobrindo seleção de lado/nível e o
  SnackBar de erro quando `controller.startVsAi` retorna `false`, no mesmo
  molde de `test/game_screen_responsive_test.dart`.
- **Esforço estimado:** P

#### [AUD-005] 🟡 Diálogos de promoção e dica sem nenhum teste de widget
- **Categoria:** 6.10, Testes
- **Arquivo:** `lib/features/game/presentation/promotion_dialog.dart` (0/11),
  `lib/features/hints/presentation/hint_dialog.dart` (0/41)
- **Evidência:** `coverage/lcov.info` reporta 0% para os dois arquivos.
- **Problema:** `promotion_dialog.dart` é acionado em todo lance de
  promoção (fluxo com testes de regra de xadrez, mas sem teste de UI do
  próprio diálogo); `hint_dialog.dart` cobre os três estados do
  `FutureBuilder` (carregando, erro, sucesso com os dois lances lado a
  lado) sem nenhum teste que force o caminho de erro (`snapshot.hasError`,
  `hint_dialog.dart:36-56`).
- **Sugestão:** testes de widget isolados, com um `Future` controlado
  manualmente (`Completer`) para forçar cada um dos três estados do
  `FutureBuilder`.
- **Esforço estimado:** P

### Específico Android: Gradle/Manifest/build (seção 6.12)

#### [AUD-006] 🟠 Build de release assinado com a chave de debug
- **Categoria:** 6.12, Específico Android
- **Arquivo:** `android/app/build.gradle.kts:40-45`
- **Evidência:**
  ```kotlin
  buildTypes {
      release {
          // TODO: Add your own signing config for the release build.
          // Signing with the debug keys for now, so `flutter run --release` works.
          signingConfig = signingConfigs.getByName("debug")
      }
  }
  ```
- **Problema:** todo `flutter build apk --release` gerado hoje está assinado
  com a chave de debug (compartilhada entre todo ambiente de desenvolvimento
  Flutter/Android Studio, não rotacionável de forma segura). Isso impede
  publicação em qualquer canal que exija assinatura de release própria e,
  mais grave, um APK assim distribuído por engano teria a chave de
  assinatura previsível/compartilhada.
- **Sugestão:** gerar um keystore de release dedicado, configurar via
  `key.properties` (não commitado) lido no `build.gradle.kts`, conforme o
  próprio TODO já indica. Item já sinalizado pelo time como pendente da Fase
  7 ("empacotamento final"); este achado apenas formaliza a prioridade.
- **Esforço estimado:** P

#### [AUD-007] 🟡 Sem minificação/shrink de recursos nem regras ProGuard/R8 no release
- **Categoria:** 6.12, Específico Android
- **Arquivo:** `android/app/build.gradle.kts:40-46`; nenhum arquivo
  `proguard-rules.pro` encontrado em `android/app/`.
- **Evidência:** bloco `release {}` só define `signingConfig` (ver
  AUD-006); `minifyEnabled`/`shrinkResources` não aparecem em nenhum lugar
  do arquivo, portanto assumem o padrão `false` do Android Gradle Plugin.
  `find android -iname "proguard*"` não retornou nenhum arquivo.
- **Problema:** o APK de release fica maior e sem ofuscação de código Dart
  nativo/Kotlin. Não é urgente para um app open source distribuído por
  sideload (não há segredo comercial a proteger por ofuscação), mas é a
  configuração padrão recomendada e, se for ativada no futuro sem regras de
  ProGuard/R8 para Drift (reflexão via `sqlite3`) e para os plugins FFI
  (`leela_chess_zero`, `stockfish`), o app corre risco real de "funciona em
  debug, quebra em release", o sintoma clássico do item 6.12 deste
  checklist.
- **Sugestão:** decisão explícita registrada em ADR: manter desligado (e
  documentar o porquê) ou ativar com um `proguard-rules.pro` testado contra
  um build de release real em dispositivo, cobrindo os pontos de FFI e
  Drift.
- **Esforço estimado:** P (documentar decisão) / M (se optar por ativar e validar)

#### [AUD-008] 🟢 `android:allowBackup` não definido explicitamente
- **Categoria:** 6.11/6.12, Segurança / Android
- **Arquivo:** `android/app/src/main/AndroidManifest.xml:2-4`
- **Evidência:** a tag `<application>` não declara `android:allowBackup`,
  portanto herda o padrão `true` do Android: o banco `maia_chess.sqlite`
  (partidas, progresso de campanha, configurações) entra no backup
  automático do Android para a conta Google do usuário.
- **Problema:** os dados armazenados não são sensíveis (partidas de xadrez
  locais, sem conta nem dado pessoal), então o risco real é baixo; ainda
  assim, é uma configuração de segurança que hoje é herdada por omissão, não
  por decisão.
- **Sugestão:** decisão explícita entre `android:allowBackup="true"` (mantendo o
  comportamento atual, mas documentado) e `"false"`, conforme a
  preferência do time para a experiência de restauração de aparelho.
- **Esforço estimado:** P

### Qualidade de código, smells e dívida técnica (seção 6.9)

#### [AUD-009] 🟡 Regra de negócio duplicada: cálculo de resultado do jogador
- **Categoria:** 6.9 / 6.1, Smells / lógica duplicada
- **Arquivo:** `lib/data/local/app_database.dart:224-240` (`_evaluatedSummary`) e `lib/data/repositories/drift_stats_repository.dart:72-91` (`_summary` + `playerOutcome`)
- **Evidência:** as duas funções implementam, de forma independente, a
  mesma regra ("vitória se o lado do jogador bate com o resultado, empate se
  `draw`, senão derrota"):
  ```dart
  // app_database.dart:227-232
  final outcome = result == StoredGameResult.draw
      ? PlayerGameOutcome.draw
      : (side == Side.white && result == StoredGameResult.whiteWin) ||
            (side == Side.black && result == StoredGameResult.blackWin)
      ? PlayerGameOutcome.win
      : PlayerGameOutcome.loss;
  ```
  ```dart
  // drift_stats_repository.dart:85-91
  PlayerGameOutcome playerOutcome(StoredGameResult result, Side playerSide) {
    if (result == StoredGameResult.draw) return PlayerGameOutcome.draw;
    final playerWon =
        (playerSide == Side.white && result == StoredGameResult.whiteWin) ||
        (playerSide == Side.black && result == StoredGameResult.blackWin);
    return playerWon ? PlayerGameOutcome.win : PlayerGameOutcome.loss;
  }
  ```
- **Problema:** hoje as duas cópias estão de fato idênticas em
  comportamento, mas nada impede que uma seja alterada (ex: uma nova
  variante de `StoredGameResult`) sem a outra acompanhar, exatamente o
  cenário descrito no item 6.1 do checklist ("fórmulas duplicadas em dois
  lugares com pequenas divergências"). `rebuildDerivedState` (chamada em
  toda finalização/exclusão de partida) e `DriftStatsRepository.watch()`
  (usada pela tela de estatísticas) passam a poder divergir silenciosamente.
- **Sugestão:** mover `playerOutcome` para `player_stats.dart` (onde já
  vivem `PlayerGameOutcome`/`EvaluatedGameSummary`) e usá-la nos dois
  pontos de leitura do banco.
- **Esforço estimado:** P

#### [AUD-010] 🟡 `SpikeScreen` é código morto
- **Categoria:** 6.9, Smells / código morto
- **Arquivo:** `lib/features/spike/spike_screen.dart` (178 linhas)
- **Evidência:** `grep -rn "SpikeScreen" lib/ test/ integration_test/` só
  retorna a própria declaração da classe; nenhuma rota em `main.dart` ou em
  qualquer outro widget a referencia.
- **Problema:** a tela de diagnóstico da Fase 0 (validação inicial de que
  lc0/Stockfish respondiam via FFI) cumpriu seu papel, mas ficou no
  binário: acrescenta ~180 linhas e duas instâncias de `Lc0Service`/
  `StockfishService` ao APK sem uso, além de confundir quem navega a
  árvore de `features/` procurando telas ativas.
- **Sugestão:** mover para `integration_test/` (como um harness manual, se
  ainda for útil para depuração) ou remover; se for mantida como
  ferramenta de diagnóstico deliberada, adicionar uma rota oculta/debug
  explícita e um comentário no `README.md` justificando a permanência.
- **Esforço estimado:** P

#### [AUD-011] 🟢 Relógio de xadrez modelado em 4 camadas sem nenhuma lógica de contagem
- **Categoria:** 6.9 / 6.8, Smells / organização
- **Arquivo:** `lib/features/game/application/game_state.dart:39-42,123-126`;
  `lib/data/repositories/game_repository.dart:54-57,74-77`;
  `lib/data/local/app_database.dart:35-38`;
  `lib/data/repositories/drift_game_repository.dart:158-161,233-236`
- **Evidência:** `clockEnabled`/`initialTimeMs`/`whiteTimeMs`/`blackTimeMs`
  existem em `GameState`, `StoredGame`, na tabela `Games` do Drift e em
  todo o caminho de persistência (busca confirmada com
  `grep -rn "clockEnabled\|whiteTimeMs\|blackTimeMs" lib/`), mas nenhum
  `Timer`/contagem regressiva os decrementa e nenhuma tela exibe um
  relógio: `_StatusBar` em `game_screen.dart` não referencia nenhum desses
  campos.
- **Problema:** não é um bug (o valor fica parado, sem afetar a partida),
  mas é superfície morta em quatro camadas simultaneamente, com custo de
  manutenção para quem lê o schema achando que a feature existe.
- **Sugestão:** se relógio for uma feature planejada para as Fases 6-7
  (README menciona "personalização" em aberto), registrar isso em
  `ADR.md`/`docs/especificacao.md` explicitamente para não parecer
  esquecido; caso contrário, remover os campos até a feature ser
  priorizada.
- **Esforço estimado:** P (documentar) / M (remover ou implementar)

### Arquitetura e organização de pastas (seção 6.8)

#### [AUD-012] 🟢 `core/theming` e `core/di` vazios
- **Categoria:** 6.8, Arquitetura e organização
- **Arquivo:** `lib/core/theming/`, `lib/core/di/`
- **Evidência:** `find lib/core/theming lib/core/di -type f` não retorna
  nenhum arquivo; o tema é definido inline em `main.dart:27-37`
  (`ThemeData`/`darkTheme`) e a injeção de dependência é feita via
  providers Riverpod espalhados em `data/providers.dart` e
  `game_controller.dart`, não em `core/di`.
- **Problema:** as pastas foram criadas pelo scaffolding inicial (README
  as lista na seção "Estrutura") mas nunca receberam conteúdo. Não chega a
  ser um bug, mas indica que a estrutura documentada no README diverge
  levemente da real.
- **Sugestão:** mover o `ThemeData` de `main.dart` para
  `core/theming/app_theme.dart` (consistente com o resto da organização
  feature-first) ou remover as pastas vazias e ajustar o README.
- **Esforço estimado:** P

### Dependências (seção 6.13)

#### [AUD-013] 🟢 Duas dependências diretas com versão major mais nova já resolvível
- **Categoria:** 6.13, Dependências
- **Arquivo:** `pubspec.yaml:11,19`
- **Evidência:** `flutter pub outdated`:
  ```
  flutter_riverpod   *2.6.1    *2.6.1      *3.3.2      3.4.2
  share_plus         *12.0.2   *12.0.2     13.3.0      13.3.0
  ```
- **Problema:** ambas têm uma versão major nova já resolvível com as
  demais dependências do projeto (coluna "Resolvable"), não apenas
  transitiva. Não há indício de vulnerabilidade conhecida nas versões
  atuais, mas o projeto está a uma major inteira de distância em duas
  dependências centrais (state management e compartilhamento de PGN).
- **Sugestão:** avaliar o changelog de `riverpod` 3.x (mudanças de API não
  triviais entre major versions) e de `share_plus` 13.x num momento
  dedicado, fora do fluxo de outras mudanças, com a suíte de testes como
  rede de segurança.
- **Esforço estimado:** M

### Lint e análise estática (seção 6.9 / Fase 1)

#### [AUD-014] 🟢 `analysis_options.yaml` usa somente o conjunto padrão do `flutter_lints`
- **Categoria:** 6.9, Qualidade de código
- **Arquivo:** `analysis_options.yaml:10,30-33`
- **Evidência:**
  ```yaml
  include: package:flutter_lints/flutter.yaml
  ...
  linter:
    rules:
      # avoid_print: false  # Uncomment to disable the `avoid_print` rule
      # prefer_single_quotes: true  # Uncomment to enable the `prefer_single_quotes` rule
  ```
  Nenhuma regra é adicionada além do conjunto padrão; `flutter analyze
  --no-fatal-infos` já roda limpo hoje ("No issues found!"), o que sugere
  que o código passaria também num conjunto mais rígido.
- **Problema:** o padrão `flutter_lints` é propositalmente permissivo. Um
  conjunto mais rígido (`very_good_analysis`, ou regras manuais como
  `public_member_api_docs`, `prefer_final_locals`, `avoid_dynamic_calls`)
  pegaria regressões de estilo antes de chegarem à revisão humana,
  especialmente relevante dado o volume de código gerado autonomamente que
  o `ADR.md` descreve.
- **Sugestão:** experimentar `very_good_analysis` num branch e avaliar o
  volume de ajustes necessário antes de adotar.
- **Esforço estimado:** P

### Informativo (fora do escopo de `lib/`)

#### [AUD-015] ℹ️ `dart format --set-exit-if-changed .` falha por causa do pacote vendorizado
- **Categoria:** Fase 1, Análise estática automatizada
- **Arquivo:** `native/leela_chess_zero/example/lib/main.dart`,
  `native/leela_chess_zero/lib/lc0.dart`,
  `native/leela_chess_zero/lib/src/lc0_state.dart`
- **Evidência:**
  ```
  $ dart format --output=none --set-exit-if-changed .
  Changed native/leela_chess_zero/example/lib/main.dart
  Changed native/leela_chess_zero/lib/lc0.dart
  Changed native/leela_chess_zero/lib/src/lc0_state.dart
  Formatted 49 files (3 changed) in 0.29 seconds.
  ```
  Os três arquivos pertencem ao pacote de terceiros vendorizado (ADR-001),
  já excluído do `flutter analyze` via `analyzer.exclude: [native/**]` em
  `analysis_options.yaml:14-17`, mas `dart format .` não respeita esse
  `exclude` por rodar fora do analyzer.
- **Problema:** não é um problema do código do app; é puramente uma
  consequência de rodar o comando genérico da Fase 1 deste processo sobre
  todo o diretório. Se um gate de CI (AUD-002) adotar
  `dart format --set-exit-if-changed .` ao pé da letra, vai falhar sempre
  por causa do vendorizado, mascarando regressões reais no código do app.
- **Sugestão:** no CI, restringir o comando a `dart format
  --set-exit-if-changed lib test integration_test`, espelhando o mesmo
  `exclude` de `native/**` já usado pelo analyzer.
- **Esforço estimado:** P

## Apêndices

### Comandos executados (Fase 0/1)

```
$ flutter --version
Flutter 3.41.9 • channel stable • Dart 3.11.5 • DevTools 2.54.2

$ flutter analyze --no-fatal-infos
Analyzing maia_android...
No issues found! (ran in 1.6s)

$ flutter test --coverage
00:03 +50: All tests passed!

$ flutter pub outdated
(ver AUD-013 para as linhas relevantes)
```

### Cobertura por arquivo (extraída de `coverage/lcov.info`)

| Arquivo | Cobertura |
|---|---|
| `lc0_service.dart` | 0% (0/138) |
| `stockfish_service.dart` | 0% (0/132) |
| `promotion_dialog.dart` | 0% (0/11) |
| `hint_dialog.dart` | 0% (0/41) |
| `new_game_vs_ai_screen.dart` | 2% (1/45) |
| `app_database.g.dart` (gerado) | 29% (545/1894) |
| `providers.dart` | 33% (8/24) |
| `main.dart` | 51% (42/83) |
| `app_database.dart` | 57% (81/143) |
| `history_screen.dart` | 61% (92/152) |
| `game_replayer.dart` | 69% (24/35) |
| `difficulty_levels.dart` | 71% (5/7) |
| `game_screen.dart` | 73% (160/218) |
| `campaign_screen.dart` | 74% (111/150) |
| `chess_board_widget.dart` | 76% (107/141) |
| `drift_progress_repository.dart` | 79% (15/19) |
| `drift_settings_repository.dart` | 79% (23/29) |
| `game_controller.dart` | 79% (319/403) |
| `pgn_service.dart` | 81% (127/156) |
| `drift_game_repository.dart` | 86% (140/163) |
| `player_stats.dart` | 93% (66/71) |
| `stats_screen.dart` | 93% (195/210) |
| `drift_stats_repository.dart` | 94% (48/51) |
| `game_state.dart` | 99% (80/81) |
| `piece_assets.dart`, `game_repository.dart`, `progress_repository.dart`, `settings_repository.dart`, `chess_piece_widget.dart`, `hint_result.dart` | 100% |

### Ressalva metodológica

Esta auditoria foi feita por leitura estática e execução de ferramentas de
análise; não envolveu instalar o app num dispositivo físico nem medir
desempenho real (uso de CPU/memória do lc0/Stockfish em hardware real), que
o próprio `ADR.md` já sinaliza como pendência da Fase 7 ("Em aberto", ao
final do ADR-001). Os itens de performance do checklist (seção 6.4) não
geraram achados porque a leitura do código não revelou os padrões
buscados (`FutureBuilder` recriando `Future` a cada build, listas grandes
sem `.builder`, ausência de `const` em pontos quentes). O tabuleiro usa
`GridView.builder` com 64 itens fixos e `RepaintBoundary` já está em
`ChessPieceWidget` (`chess_piece_widget.dart:21`).
