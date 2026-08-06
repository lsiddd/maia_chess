# Registro de Decisões de Arquitetura (ADR)

Este documento registra desvios em relação à especificação técnica original
(`docs/especificacao.md`, seção 2 e seção 9) e outras decisões relevantes
tomadas durante a implementação autônoma do projeto.

---

## ADR-001 — Reutilização de pacotes pub.dev para lc0 e Stockfish em vez de build NDK próprio

**Status:** aceito
**Contexto:** a especificação original (seção 12) identifica compilar o lc0 para
Android via NDK e validar a execução via FFI como o maior risco técnico do
projeto, recomendando um spike isolado antes de prosseguir.

**Decisão:** em vez de compilar o lc0 e o Stockfish do zero (checkout do
código-fonte, configuração de toolchain NDK, meson/CMake, backends de
inferência, etc.), o projeto reutiliza dois pacotes Flutter de código aberto
já publicados no pub.dev, ambos sob licença GPL-3.0 (compatível com a
distribuição open source deste projeto):

- [`leela_chess_zero`](https://pub.dev/packages/leela_chess_zero) (v1.0.0) —
  compila o lc0 a partir do código-fonte vendorizado via CMake/NDK durante o
  próprio build do Gradle, expõe `lc0_init`, `lc0_main`, `lc0_stdin_write`,
  `lc0_stdout_read` via Dart FFI (`DynamicLibrary.open('liblc0.so')`), roda o
  laço UCI do lc0 em um Isolate dedicado, com stdin/stdout redirecionados via
  pipes Unix. Já inclui o peso Maia-1900 como asset (`assets/weights/maia-1900.pb.gz`)
  e aceita pesos customizados via `setoption name WeightsFile value <caminho>`.
  Backend de inferência: BLAS (via implementação CBLAS própria sobre Eigen
  header-only), já que o Android não possui uma libblas de sistema.
- [`stockfish`](https://pub.dev/packages/stockfish) (v1.8.1) — mesmo padrão
  arquitetural (FFI in-process, sem subprocess, Isolate dedicado), aplicado ao
  motor Stockfish.

**Justificativa:**
1. Ambos os pacotes já implementam exatamente o contrato exigido pela seção
   4.1/4.2 do documento técnico: execução **in-process** via FFI, sem
   subprocess (respeitando a restrição W^X do Android desde a API 29).
2. Evita redescobrir, por tentativa e erro, um processo de cross-compilação
   C++ inteiro (proto headers do lc0, Eigen, abseil, backends CPU) que duas
   equipes de código aberto já resolveram e mantêm publicamente.
3. Reduz drasticamente a superfície de risco técnico da Fase 0, permitindo
   que o tempo de desenvolvimento seja investido no restante do app.

**Consequência:** o projeto depende da manutenção contínua desses pacotes de
terceiros. Caso se tornem obsoletos ou incompatíveis com versões futuras do
Flutter/AGP/NDK, a alternativa é vendorizar uma cópia própria (fork) dentro de
`android/` do próprio app, ou retornar ao plano original de build manual.
Os fontes de ambos os pacotes já estão vendorizados dentro de cada pacote
(sem submódulos git), o que facilita esse fork se necessário.

**Addendum (Fase 0, execução do spike):** o pacote `leela_chess_zero` 1.0.0
publicado no pub.dev **não builda out-of-the-box**. O build Android falha
com `fatal error: 'proto/net.pb.h' file not found`. Causa: o
`architecture.md` do próprio pacote documenta que os headers `.pb.h`
pré-gerados do sistema de mensagens do lc0 (`net.proto`, `onnx.proto`,
`hlo.proto`) deveriam estar commitados em `ios/lc0/build/proto/`, mas essa
pasta não veio no tarball publicado — quase certamente porque `build/` está
no `.gitignore` do autor e `dart pub publish` empacota respeitando
`.gitignore` por padrão.

Correção aplicada: o pacote foi vendorizado em `native/leela_chess_zero/`
(cópia integral do pacote 1.0.0) e os headers faltantes foram regenerados
localmente a partir dos `.proto` fonte (que **estão** presentes no pacote),
usando o script já existente do próprio lc0:

```bash
cd native/leela_chess_zero/ios/lc0
uv run --no-project python3 scripts/compile_proto.py --proto_path=proto --cpp_out=build proto/net.proto
uv run --no-project python3 scripts/compile_proto.py --proto_path=proto --cpp_out=build proto/onnx.proto
uv run --no-project python3 scripts/compile_proto.py --proto_path=proto --cpp_out=build proto/hlo.proto
mkdir -p build/proto && mv build/*.pb.h build/proto/
```
(`--no-project` evita que o `uv` tente sincronizar/buildar o projeto meson
completo do lc0, que tem um `pyproject.toml` próprio e não builda no desktop
com as modificações mobile-specific da fonte vendorizada — só precisamos do
script Python standalone, sem dependências de terceiros.)

**Addendum (Fase 2, bug de corrida no dispose):** ao trocar de nível numa
partida contra a IA sem sair do app (ex: jogar contra o Maia 1900 e, na
sequência, iniciar uma nova partida contra o Maia 1100), o app lançava
`Bad state: Multiple instances are not supported, yet.`. Causa: tanto
`Lc0.dispose()` quanto `Stockfish.dispose()` (pacotes subjacentes) só
mandam `"quit"` pelo stdin — a limpeza de fato (que zera o singleton
estático `_instance` do pacote) só acontece depois, quando o isolate do
motor termina de processar o `"quit"` e sai, de forma assíncrona. O
`Lc0Service.dispose()`/`StockfishService.dispose()` originais não esperavam
por isso: retornavam assim que enviavam `"quit"`, então um `init()` logo
em seguida tentava construir uma nova instância enquanto a antiga ainda
não tinha liberado o singleton do pacote. Corrigido fazendo `dispose()`
escutar `state` até virar `disposed`/`error` (com timeout de 5s de
segurança) antes de retornar. Validado corrigindo exatamente o cenário que
reproduzia o bug (troca de nível 1900 → 1100 na mesma sessão).

**Addendum (Fase 3, `Lc0State.ready`/`StockfishState.ready` não significam
"pronto para jogar"):** implementando o botão de dica, `getBestMove` do lc0
e do Stockfish começaram a estourar timeout de forma aparentemente
aleatória, mesmo com os dois motores já em estado `ready`. O logcat expôs a
causa: entre o motor imprimir `Search algorithm: classic` e `Loading
weights file from: ...` (lc0), passaram **23,6 segundos** — e o parsing do
peso em si, uma vez iniciado, levou só ~21ms. Ou seja, `Lc0State.ready` (e,
por construção idêntica do pacote `stockfish`, `StockfishState.ready`) só
indica que os Isolates nativos subiram (`Isolate.spawn` retornou), **não**
que o motor terminou de carregar peso/rede e está pronto para processar
`go`. Um `go` enviado nesse intervalo fica na fila atrás do carregamento
ainda em andamento, e nosso timeout do lado Dart (que não sabe disso)
estourava achando que o motor tinha travado.

Corrigido em `Lc0Service.init`/`StockfishService.init`: depois do estado
virar `ready`, mandamos o handshake padrão UCI `isready` e só consideramos
o motor de fato pronto (`isReady`) quando chega `readyok` — que só responde
depois que o motor processa tudo que veio antes na fila de stdin,
garantindo que o carregamento já terminou. Timeout desse handshake: 60s.

**Em aberto:** não está confirmado se os ~24-38s de carregamento são
específicos deste ambiente de desenvolvimento ou algo a esperar também em
hardware real. Indício forte de que é específico deste ambiente: o host
onde este projeto está sendo desenvolvido roda a própria sessão do agente
dentro de uma VM (QEMU), e o emulador Android é *outra* camada de QEMU por
cima disso — virtualização aninhada, conhecida por penalizar pesadamente
operações de CPU intensas (`ps aux` mostrou o processo do emulador e uma
segunda VM concorrendo por CPU junto com daemons do Gradle/Kotlin,
`uptime` com load average >5 numa consulta feita durante um desses
timeouts). Carregar/verificar pesos de rede neural via BLAS é exatamente o
tipo de carga que sofre mais nesse cenário. Por isso o timeout do
handshake foi para 120s (era 60s) só para viabilizar validar a Fase 3
neste sandbox — **não deve ser lido como estimativa de tempo real em
dispositivo físico**. Vale medir num aparelho de verdade antes da Fase 7;
se mesmo lá for lento, considerar pré-carregar o peso do próximo nível
mais provável em background, ou tornar o timeout configurável.

`pubspec.yaml` aponta para essa cópia local via `path:` em vez da versão
hospedada:
```yaml
leela_chess_zero:
  path: native/leela_chess_zero
```

**Consequência adicional:** os 3 arquivos `.pb.h` gerados (poucos KB cada)
ficam commitados dentro de `native/leela_chess_zero/ios/lc0/build/proto/`
neste repositório. Caso o mantenedor do pacote publique uma versão corrigida
no pub.dev, reavaliar a volta para a dependência hospedada.

**Resultado do spike (validado em APK real, emulador x86_64, API 36):**
`liblc0.so` e `libstockfish.so` compilam e linkam para `arm64-v8a` e
`x86_64`; instalado o APK de debug, a tela de diagnóstico confirmou
ponta a ponta: carregar o peso Maia-1900 → enviar FEN inicial → `go nodes 1`
→ receber `bestmove e2e4` via FFI (lc0), e o mesmo fluxo com Stockfish
(`go movetime 1000` → `bestmove e2e4`). **O maior risco técnico do projeto
(seção 12 dos requisitos) está mitigado.**

**Observação de robustez (não bloqueante, revisitar na Fase 3):** na primeira
chamada ao Stockfish nesta sessão de teste, a busca não respondeu dentro de
9s (timeout) e deixou o singleton do pacote `stockfish` preso (`Bad state:
Multiple instances are not supported, yet.` em tentativas seguintes, exigindo
reiniciar o app). Em execuções subsequentes (processo novo), respondeu
rapidamente. Causa provável: custo de inicialização a frio dos dois arquivos
NNUE embutidos (`nn-c288c895ea92.nnue` grande + `nn-37f18f62d772.nnue`
pequeno) somado à carga residual do build nativo pesado que tinha acabado de
rodar no mesmo host. Recomendações para a Fase 3 (`stockfish_service.dart`):
(a) enviar `uci`/`isready` e aguardar `uciok`/`readyok` antes do primeiro
`position`/`go`, hoje ausente tanto no `Lc0Service` quanto no
`StockfishService`; (b) aumentar a margem de timeout ou torná-la
configurável; (c) se o timeout ocorrer, expor um caminho de recuperação
(reiniciar o isolate/engine) em vez de deixar o singleton preso.

**Addendum (Fase 3, causa raiz do bloqueio Stockfish + lc0):** a espera de
mais de 400 segundos com consumo praticamente nulo de CPU não era custo da
NNUE nem falta de escalonamento do host. Os bridges FFI dos dois pacotes
executavam `dup2()` sobre os descritores 0/1 do **mesmo processo** e seus
loops UCI bloqueavam em `std::getline(std::cin)`. `stdin`, `stdout`,
`std::cin` e `std::cout` são globais ao processo/runtime C++, não privados
por Isolate. Como o lc0 continuava vivo durante toda a partida, seu loop
ficava bloqueado esperando o próximo comando e o Stockfish podia dormir
indefinidamente disputando o mesmo stream. Esse comportamento explica
diretamente a ausência de CPU observada.

Correção: o bridge vendorizado do lc0 não chama mais `dup2()` nem usa
`std::cin/std::cout` no protocolo UCI. `engine_loop.cc` lê diretamente do
pipe privado do lc0 e `StdoutUciResponder` escreve diretamente no pipe de
saída, com serialização e tratamento de `EINTR`. Isso deixa o Stockfish livre
para usar o transporte legado do pacote sem contenção entre motores.

Defesas adicionais no Dart:

- handshake do Stockfish limitado a 60s (lc0: 120s);
- fim/erro do stream conclui os `Future`s com erro, em vez de aguardar apenas
  o timer;
- busca atrasada recebe `stop`, tem 2s de tolerância e, se continuar presa, o
  motor é descartado;
- a operação completa de dica tem limite de 120s e sempre sai do spinner com
  resultado ou erro;
- solicitar dica marca a partida como não avaliada imediatamente, antes dos
  motores, e o cálculo é iniciado pelo callback do botão (fora do ciclo de
  build do Riverpod).

Validação ao vivo (emulador x86_64, API 36): Maia 1100 e Stockfish retornaram
`e4` para a posição inicial em menos de 10s; em seguida, depois de o Stockfish
já estar ativo, o lance humano `1.e4` recebeu normalmente `...e5` do mesmo
lc0. Uma segunda dica na nova posição retornou `Nf3` pelos dois motores. Isso
confirma tanto a dica quanto a coexistência e o reuso dos dois engines.

---

## ADR-002 — Conjunto de ABIs Android: `arm64-v8a` + `x86_64` (em vez de `arm64-v8a` + `armeabi-v7a`)

**Status:** aceito
**Contexto:** a especificação sugere ABI splits para `arm64-v8a` e
`armeabi-v7a` (seção 10, seção 7).

**Decisão:** o `build.gradle.kts` do app usa `abiFilters "arm64-v8a", "x86_64"`.

**Justificativa:** o pacote `leela_chess_zero` (motor lc0) só compila, hoje,
para `arm64-v8a` e `x86_64` upstream (ver `android/build.gradle` do pacote).
`armeabi-v7a` (ARM 32-bit) está cada vez mais restrito a aparelhos anteriores
a ~2016, hoje uma fração residual do parque Android. Como o app depende do
lc0 para sua funcionalidade central (IA estilo humano), não faz sentido
manter uma ABI para a qual o motor principal não compila. `x86_64` foi
mantido por viabilizar teste em emulador (usado neste próprio spike) e cobrir
os poucos dispositivos x86 físicos existentes.
O pacote `stockfish` compila para as três ABIs (`arm64-v8a`, `armeabi-v7a`,
`x86_64`); a limitação efetiva vem do lc0.

**Consequência:** dispositivos ARM de 32 bits (raros, antigos) não conseguem
rodar o app. Reavaliar se o `leela_chess_zero` ganhar suporte a
`armeabi-v7a` upstream.

---

## ADR-003 — `minSdk` 24 (em vez de 23)

**Status:** aceito
**Contexto:** a especificação (seção 2, seção 10) sugere API 23+ "a confirmar
conforme requisitos de build do NDK/lc0".

**Decisão:** `minSdk = 24` no `android/app/build.gradle.kts`.

**Justificativa:** o pacote `leela_chess_zero` declara `minSdk 24` como
requisito explícito. A confirmação pedida pela especificação foi feita: **API
23 não é suficiente**, API 24 (Android 7.0) é o mínimo real.

---

## ADR-004 — Biblioteca de regras de xadrez: `dartchess` (em vez de `chess`)

**Status:** aceito
**Contexto:** a especificação (seção 4.3, seção 13) cita o pacote `chess` do
pub.dev como exemplo, mas deixa a escolha final em aberto.

**Decisão:** usar [`dartchess`](https://pub.dev/packages/dartchess)
(mantido pela organização Lichess), não o pacote `chess`.

**Justificativa:** `dartchess` é ativamente mantido por uma organização com
histórico sólido em engines de xadrez open source (lichess.org), tem API
imutável (`Position` imutável, `play()` retorna nova posição — favorece uso
com Riverpod/state management declarativo), suporta geração de lances
legais, FEN, SAN/PGN, detecção de xeque-mate/afogamento/material
insuficiente nativamente, e parsing de UCI via `Move.parse()` (necessário
para interpretar a saída `bestmove` do lc0/Stockfish).

---

## ADR-005 — Gerenciamento de estado: Riverpod (conforme recomendado)

**Status:** aceito, sem desvio.
Mantida a recomendação original da seção 2/9: Riverpod (`flutter_riverpod`).

---

## ADR-006 — JDK para build: OpenJDK 17 via `flutter config --jdk-dir`

**Status:** aceito
**Contexto:** o ambiente de desenvolvimento tinha OpenJDK 26 como JDK padrão
do sistema, incompatível com a versão do Gradle usada pelo template Flutter
(faixa compatível: JDK 17 ≤ x < 25).

**Decisão:** configurado `flutter config --jdk-dir=/usr/lib/jvm/java-17-openjdk`
(JDK 17 disponível no sistema via `archlinux-java`), em vez de alterar a
versão do Gradle Wrapper.

**Justificativa:** minimiza mudanças na configuração padrão gerada pelo
`flutter create`, evitando arrastar uma versão de Gradle não testada pelo
time do Flutter para este template.

---

## ADR-007 — Licença e origem dos pesos Maia

**Status:** aceito
**Contexto:** a especificação (seção 9) deixa como pendência confirmar
disponibilidade e licença dos pesos oficiais antes de embuti-los no APK.

**Decisão:** os 9 pesos (`maia-1100.pb.gz` a `maia-1900.pb.gz`) foram
baixados diretamente da release oficial do repositório
[`CSSLab/maia-chess`](https://github.com/CSSLab/maia-chess), tag `v1.0`
(`github.com/CSSLab/maia-chess/releases/download/v1.0/maia-<rating>.pb.gz`),
e ficam em `assets/maia_weights/`.

**Sobre a licença:** o repositório `CSSLab/maia-chess` é licenciado como
GPL-3.0. O README não separa explicitamente a licença do código da licença
dos pesos treinados, mas trata ambos como parte do mesmo projeto distribuído
sob essa licença (o próprio README aponta tanto a pasta local
`maia_weights/` quanto os releases do GitHub como formas equivalentes de
obter os pesos). Este projeto (`maia_chess`, também open source) redistribui
os pesos sem modificação, com atribuição de origem registrada aqui e em
`assets/maia_weights/NOTICE.md`. Se o CSSLab publicar uma licença específica
e mais restritiva para os pesos no futuro, esta decisão deve ser revisitada.

**Justificativa:** os pesos são o elemento central do produto (a IA "estilo
humano" não existe sem eles) e estão publicados oficialmente para uso
externo, com mais de 13 mil downloads registrados só no arquivo de 1100 no
momento da consulta — uso amplamente esperado pelos mantenedores.

---

## ADR-008 — Serialização, snapshot e recuperação das operações de motor

**Status:** aceito

**Contexto:** uma dica envolve duas operações nativas sequenciais sobre a
mesma posição. Fechar o diálogo não cancela automaticamente o `Future`, e um
timeout de `Future.timeout` também não interrompe por si só o cálculo nativo.
Além disso, iniciar outra partida enquanto o Maia respondia poderia deixar
duas buscas UCI concorrendo no mesmo singleton lc0.

**Decisão:**

- `GameController.getHint()` é *single-flight*: chamadas repetidas enquanto
  uma dica está em andamento recebem a mesma operação, sem novos comandos
  UCI;
- FEN e objeto `Chess` são capturados juntos no início; a conversão UCI →
  SAN usa exclusivamente esse snapshot;
- enquanto a dica calcula, toque, arraste, undo e reset pela UI ficam
  bloqueados. Fechar o diálogo apenas oculta o progresso; a operação única
  continua e o estado mostra “Calculando dica...”;
- timeout, erro nativo, saída UCI inválida, mudança de partida ou shutdown
  invalidam a geração da operação e descartam os motores envolvidos antes
  da próxima tentativa;
- respostas atrasadas da IA carregam uma geração e a FEN de origem. Uma
  resposta só é aplicada se ambas ainda coincidirem com a partida atual;
- iniciar/reiniciar uma partida durante uma busca descarta o lc0 anterior
  antes de criar outro, evitando comandos simultâneos;
- os motores entram no controller por interfaces/factories Riverpod, o que
  permite testar timeout, erro, descarte e recuperação sem carregar FFI em
  testes unitários.

**Validação:** a suíte cobre single-flight, bloqueio de movimento, timeout
com tentativa posterior, erro de inicialização, UCI inválido, troca repetida
1100 → 1900 → 1100 e resposta atrasada após mudança de partida. Um teste de
integração no emulador Android x86_64/API 36 executa motores reais na
sequência 1100 → dica → lance humano/resposta Maia → 1900 → dica e encerra
os dois singletons explicitamente.

---

## Addendum ao ADR-004 — Regras dependentes do histórico e roque na UI

`dartchess` encerra partidas por mate, afogamento e material insuficiente,
mas não adjudica repetição nem regra dos 50 lances porque essas regras
dependem do histórico da partida. `GameState` passou a:

- identificar repetição pelas quatro primeiras partes da FEN (peças, lado,
  direitos de roque e en passant legal), declarando empate na terceira
  ocorrência;
- declarar empate quando o relógio de meio-lances chega a 100;
- manter os históricos em listas não modificáveis;
- traduzir a codificação interna de roque do `dartchess` (rei → torre,
  necessária para Chess960) para os destinos clássicos g/c usados pela UI.

Esses casos, somados a en passant e às quatro promoções legais, têm testes de
regressão dedicados.

---

## ADR-009 — Persistência relacional, autosave e importação PGN

**Status:** aceito

**Contexto:** a Fase 4 exige que uma partida sobreviva ao encerramento do
processo, que a finalização/campanha seja idempotente e transacional e que a
importação PGN nunca deixe registros parciais. Estatísticas agregadas em JSON
duplicariam dados que podem ser calculados a partir das partidas.

**Decisão:**

- Drift/SQLite é a fonte durável, com tabelas relacionais `games`,
  `game_moves`, `difficulty_progress`, `rating_history` e `app_settings`;
- há no máximo um autosave em andamento. A UI pede confirmação antes de
  substituí-lo, e o repositório faz a troca em uma única transação;
- o controller grava somente depois de um lance validado pelo `dartchess`.
  Undo substitui o snapshot e remove os lances desfeitos;
- a conclusão substitui o snapshot, salva resultado/PGN e reconstrói as
  projeções de rating/campanha na mesma transação. Uma segunda conclusão do
  mesmo ID não contabiliza a partida novamente;
- na retomada, todos os UCIs são reaplicados a partir da FEN inicial. SAN,
  FEN intermediárias e FEN final precisam coincidir com o banco antes de o
  estado ser aceito;
- uma posição retomada só solicita o Maia quando realmente for a vez da IA;
  o primeiro lance automático já persistido nunca é reaplicado;
- a importação valida em memória o cabeçalho, a posição inicial, todos os
  lances da linha principal e das variantes. A contagem dos tokens originais
  também precisa coincidir com a árvore do parser, evitando aceitar texto que
  um parser permissivo tenha ignorado;
- importações são arquivadas como não avaliadas e não alteram campanha ou
  rating. A gravação ocorre somente depois da validação integral;
- arquivos são escolhidos pelo Storage Access Framework e exportados pela
  folha de compartilhamento do Android, sem permissões amplas de
  armazenamento.

**Validação:** testes com SQLite temporário cobrem criação do schema, versão,
defaults, chaves estrangeiras/cascade, substituição de snapshot, uma única
partida ativa, finalização idempotente, exclusão de vitórias não avaliadas,
configurações e round-trip PGN. No emulador Android x86_64/API 36 foi
confirmado ao vivo o fluxo e4/e5 → undo → `evaluated=false` → encerramento
forçado do processo → novo processo → retomada em e4, sem perder o estado.
Também foram confirmados biblioteca/replay, abertura da folha nativa de
compartilhamento e importação por DocumentsUI de um PGN com quatro lances.

---

## ADR-010 — Rating estimado, streaks e progressão da campanha

**Status:** aceito

**Contexto:** a Fase 5 precisa produzir estatísticas determinísticas a partir
do histórico, excluir partidas com dica/undo e permitir reconstruir todos os
dados derivados depois da exclusão de uma partida. Também era necessário
definir precisamente o significado de "rating estimado", "streak" e
"X vitórias em Y partidas".

**Decisão — partidas elegíveis:** estatísticas e rating consideram somente
partidas finalizadas contra o Maia que tenham nível, lado do jogador e
resultado conhecidos e `evaluated=true`. Partidas locais, importadas,
inacabadas ou marcadas como não avaliadas não entram nos cálculos e também
não interrompem streaks. A campanha acrescenta o requisito
`campaignMode=true`.

**Decisão — rating:**

- rating inicial: **1500**;
- rating do adversário: o nível Maia selecionado (1100–1900);
- resultado do jogador: vitória = 1, empate = 0,5, derrota = 0;
- expectativa Elo: `E = 1 / (1 + 10 ^ ((R_maia - R_jogador) / 400))`;
- atualização: `R_novo = R_atual + 32 * (resultado - E)`;
- limites defensivos: 600–2400;
- ordem: instante de término da partida em UTC e, em empate, ID da partida.

Cada partida elegível gera exatamente um ponto em `rating_history`. A linha do
tempo inteira é reconstruída dentro da mesma transação que conclui ou exclui
uma partida, evitando acumuladores irreversíveis e mantendo a operação
idempotente.

**Decisão — streaks:** "streak" significa sequência de **vitórias
consecutivas** nas partidas elegíveis, em ordem cronológica. Empate ou derrota
zera a sequência atual. `streakRecorde` é o maior valor já alcançado.

**Decisão — campanha:** cada nível declara `winsRequired=2` e
`windowSize=3`. O nível seguinte é desbloqueado permanentemente quando, em
qualquer janela móvel de até três partidas elegíveis de campanha no nível
atual, o jogador alcança duas vitórias. Uma vez atingida dentro do histórico
existente, partidas posteriores não revogam o desbloqueio. Como o progresso é
materializado a partir das partidas retidas, excluir a partida que sustentava
a conquista pode recalcular e bloquear novamente níveis dependentes. A UI
avisa sobre esse efeito antes da exclusão.

**Consequência:** `difficulty_progress` e `rating_history` são projeções
reconstruíveis; `games` continua sendo a fonte de verdade. A migração v2
acrescenta a contagem de partidas da janela de campanha e refaz essas
projeções para bancos existentes.

---

## ADR-011: minificação e shrink de recursos desligados no build de release

**Status:** aceito

**Contexto:** a auditoria técnica registrada em `AUDITORIA_TECNICA.md`
(AUD-007) constatou que `android/app/build.gradle.kts` não define
`minifyEnabled`/`shrinkResources` no bloco `release`, portanto assumem o
padrão `false` do Android Gradle Plugin: o APK de release sai maior e sem
ofuscação de código Dart/Kotlin.

**Decisão:** manter desligado por ora, decisão explícita em vez de omissão.

**Justificativa:** o projeto é open source, distribuído por sideload
(ver README), sem segredo comercial que a ofuscação protegeria. Ativar a
minificação exigiria regras de ProGuard/R8 testadas contra um build de
release real cobrindo Drift (reflexão via `sqlite3`) e os plugins FFI
(`leela_chess_zero`, `stockfish`), e o ambiente de build usado no
desenvolvimento já se mostrou pesado para builds nativos (ver ADR-001,
observação de robustez sobre virtualização aninhada). Não há ganho
imediato que justifique esse risco agora.

**Consequência:** o APK fica maior e sem ofuscação enquanto esta decisão
valer. Revisitar antes de publicar em um canal que cobre por tamanho de
download, ou se o volume de código Dart/Kotlin crescer o suficiente para
pesar de forma perceptível.

---

## ADR-012: campos de relógio de xadrez são scaffolding para fase futura

**Status:** aceito, pendência registrada

**Contexto:** `GameState`, `StoredGame`, a tabela `games` (Drift) e todo o
caminho de persistência já carregam `clockEnabled`/`initialTimeMs`/
`whiteTimeMs`/`blackTimeMs` (ver `AUDITORIA_TECNICA.md`, AUD-011), mas
nenhum `Timer`/contagem regressiva os decrementa e nenhuma tela exibe um
relógio.

**Decisão:** manter os campos como estão, sem removê-los agora. Este ADR
documenta que fazem parte do desenho de uma feature de relógio ainda não
implementada, provavelmente junto da personalização citada no README como
pendência das Fases 6-7.

**Justificativa:** os campos já persistem e migram corretamente
(`schemaVersion` 2 em `AppDatabase`); removê-los agora exigiria uma nova
migração de banco sem ganho real, e a estrutura de dados já reflete o
desenho pretendido para quando a feature for priorizada.

**Consequência:** até a feature ser implementada (ou os campos removidos,
se for descartada), um leitor do schema pode presumir que o relógio já
funciona. Este ADR existe justamente para deixar isso explícito.
