# Especificação Técnica — App de Xadrez Offline com IA Maia
**Documento de referência para agente de desenvolvimento autônomo**
Plataforma: Android · Framework: Flutter/Dart · Distribuição: APK direto (sideload)

---

## 0. Como usar este documento
- Siga as **Fases de Implementação (seção 6)** em ordem. Cada fase tem um critério de aceite; valide-o antes de avançar para a próxima.
- A **Fase 0 é bloqueante**: se o spike técnico falhar, replaneje a arquitetura antes de prosseguir com o resto do documento.
- Decisões de arquitetura já tomadas (seção 2) devem ser seguidas. Qualquer desvio necessário deve ser documentado (ex: em um `ADR.md` no repositório) com a justificativa.
- Onde este documento deixa uma decisão em aberto (seção 9), a IA de implementação pode decidir, desde que registre e justifique a escolha.

---

## 1. Visão Geral do Produto
App de xadrez para jogar **offline** contra uma IA que imita estilos de jogo humano em diferentes faixas de rating, usando os pesos do projeto **Maia Chess** (baseados em Leela Chess Zero/lc0). O nível de dificuldade escolhido determina qual peso é carregado no motor. Uma segunda IA (Stockfish) fornece sugestão de lance objetivamente melhor, para o sistema de dicas.

---

## 2. Decisões de Arquitetura

| Decisão | Escolha | Justificativa |
|---|---|---|
| Padrão de projeto | **Feature-first** | Pragmático, escala bem para um app de médio porte, facilita localizar código por funcionalidade |
| Gerenciamento de estado | **Riverpod** (recomendado) | Testável, boa integração com chamadas assíncronas nativas (FFI em Isolate), menos boilerplate que Bloc, mais estrutura que Provider puro. Pode ser substituído se o agente identificar melhor ajuste — documentar a decisão |
| Persistência | **Drift (SQLite)** | Consultas relacionais/agregações necessárias para estatísticas (vitórias por nível, streaks, evolução de rating) se beneficiam de SQL; suporta streams reativos, integrando bem com Riverpod |
| IA "estilo humano" | **lc0 + pesos Maia**, via FFI, nodes=1 | Uso fiel ao comportamento pretendido do Maia (ver seção 4.1) |
| IA "melhor lance" | **Stockfish**, via FFI | Motor forte já com precedente de builds Android/mobile |
| Regras de xadrez | Biblioteca **Dart pura** (não depende de motor nativo) | Fonte da verdade do estado do tabuleiro; motores nativos só recebem FEN e devolvem lance sugerido |
| Min SDK Android | API 23+ (Android 6.0) — **a confirmar na Fase 0** conforme requisitos de build do NDK/lc0 | |

---

## 3. Estrutura de Pastas (Feature-First)

```
lib/
├── core/
│   ├── theming/
│   ├── di/                      # setup de injeção de dependência / providers globais
│   └── constants/
├── engine_ffi/
│   ├── lc0_engine/
│   │   ├── lc0_binding.dart      # FFI bindings brutos
│   │   └── lc0_service.dart      # API Dart-friendly, roda em Isolate dedicado
│   └── stockfish_engine/
│       ├── stockfish_binding.dart
│       └── stockfish_service.dart
├── features/
│   ├── game/                     # partida em andamento, tabuleiro, interação
│   ├── difficulty/               # seleção de nível, lógica de campanha
│   ├── hints/                    # lógica e UI da dica dupla (Maia + Stockfish)
│   ├── history/                  # biblioteca de partidas salvas
│   ├── stats/                    # estatísticas, rating estimado, gráficos
│   ├── settings/                 # piece sets, tema claro/escuro
│   └── pgn/                      # import/export PGN
└── data/
    ├── local/                    # Drift database, DAOs
    └── repositories/             # abstrações entre features e a camada local

assets/
├── maia_weights/                 # 9 arquivos .pb.gz (1100–1900)
└── native/                       # liblc0.so e libstockfish.so por ABI

android/
└── app/
    └── build.gradle              # configuração de ABI splits, NDK
```

---

## 4. Camada Nativa e Contratos FFI

### 4.1 Motor lc0 (Maia)
- Biblioteca nativa `liblc0_maia.so`, compilada via Android NDK para `arm64-v8a` e `armeabi-v7a`.
- Executada **in-process** (não como subprocess — Android bloqueia execução de binários gravados em runtime desde a API 29).
- Contrato conceitual (assinatura, a refinar na Fase 0):
  ```
  int   lc0_init(const char* weights_path)
  char* lc0_get_best_move(const char* fen, int nodes)   // nodes = 1
  void  lc0_dispose(int handle)
  ```
- `nodes = 1` reproduz o uso pretendido/validado do Maia: uma única passada da rede (avaliação de política), sem busca em árvore — é assim que o Maia foi desenhado para imitar jogadas humanas.
- Encapsular em `lc0_service.dart` expondo API assíncrona (`Future<String> getBestMove(String fen)`), executando a chamada em um **Isolate dedicado** para não bloquear a UI.

### 4.2 Motor Stockfish (dica objetiva)
- Biblioteca nativa `libstockfish.so`, mesmo processo de build (NDK) e mesmo padrão de isolamento em Isolate.
- Contrato conceitual:
  ```
  char* stockfish_get_best_move(const char* fen, int depth_or_time_ms)
  ```

### 4.3 Regras de Xadrez (Dart puro)
- Geração/validação de lances legais, detecção de xeque/xeque-mate/afogamento/empate, conversão FEN ↔ PGN.
- Usar pacote Dart existente (ex: `chess` no pub.dev) ou implementação própria caso o pacote não cubra tudo.
- Esta camada é a única responsável pelo estado real do tabuleiro. Os motores nativos apenas recebem um FEN e devolvem uma sugestão de lance em notação UCI — a validação final do lance ainda passa pela camada de regras Dart.

---

## 5. Modelos de Dados (contratos)

### `GameRecord`
| Campo | Tipo | Observação |
|---|---|---|
| id | String/int | |
| dataInicio, dataFim | DateTime | |
| nivelDificuldade | int | 1100–1900 |
| ladoJogador | enum | brancas / pretas |
| resultado | enum | vitória / derrota / empate |
| avaliada | bool | `false` se undo ou dica foram usados |
| pgn | String | notação completa da partida |
| modoCampanha | bool | |
| tempoUsado | Duration? | se cronômetro ativo |

### `DifficultyLevel`
| Campo | Tipo | Observação |
|---|---|---|
| rating | int | 1100–1900 |
| pesoAssetPath | String | caminho do `.pb.gz` |
| vitoriasNecessarias | int | ex: 2 (de Y) para desbloquear o próximo, campanha |
| vitoriasAtuais | int | progresso atual na campanha |

### `PlayerStats`
| Campo | Tipo | Observação |
|---|---|---|
| ratingEstimado | double | Elo simplificado, calculado a partir dos resultados avaliados |
| historicoRating | List\<{data, valor}\> | para o gráfico de evolução |
| resultadosPorNivel | Map\<int, {vitorias, derrotas, empates}\> | |
| streakAtual, streakRecorde | int | |

### `AppSettings`
| Campo | Tipo | Observação |
|---|---|---|
| pieceSet | enum | conjunto de peças selecionado |
| themeMode | enum | claro / escuro |
| cronometroPadraoAtivo | bool | default `false` |
| tempoPadraoMinutos | int | usado se cronômetro ativado |

---

## 6. Fases de Implementação

### Fase 0 — Spike Técnico (bloqueante)
**Objetivo:** validar viabilidade de rodar lc0 e Stockfish nativos no Android via FFI.
**Critério de aceite:** app mínimo com um botão que carrega um peso Maia, envia um FEN fixo e recebe um lance via FFI, exibido em texto. Repetir para Stockfish.
**Se falhar:** replanejar a camada de IA antes de prosseguir (ver seção 9).

### Fase 1 — Motor de Regras e Tabuleiro Básico
- Regras de xadrez em Dart + UI de tabuleiro (mover peças por toque/arrastar), sem IA ainda.
- **Critério de aceite:** partida completa jogável localmente (dois jogadores humanos no mesmo dispositivo), com xeque-mate/afogamento detectados corretamente.

### Fase 2 — Integração da IA Maia
- Conectar `lc0_service` ao fluxo de partida; seleção de nível carrega o peso correspondente.
- **Critério de aceite:** partida completa jogável contra a IA em pelo menos 2 níveis de dificuldade diferentes.

### Fase 3 — Dicas com Stockfish
- Integrar `stockfish_service` e o botão de dica dupla (Maia-estilo + Stockfish-objetivo, lado a lado).
- Implementar marcação "não avaliada" quando dica ou undo forem usados.

### Fase 4 — Persistência
- Schema Drift (tabelas para `GameRecord`, `DifficultyLevel`, `PlayerStats`), migrations.
- Autosave da partida em andamento; biblioteca de partidas; import/export PGN.

### Fase 5 — Estatísticas e Modo Campanha
- Cálculo de rating estimado, streaks, gráfico de evolução.
- Lógica de desbloqueio de níveis na campanha (X de Y vitórias).

### Fase 6 — Personalização e Polimento
- Múltiplos piece sets, modo escuro/claro, cronômetro opcional, sons/animações básicas.

### Fase 7 — Empacotamento Final
- ABI splits (`arm64-v8a` / `armeabi-v7a`) para reduzir tamanho por dispositivo.
- Build de release assinado para distribuição direta (sideload).

---

## 7. Requisitos Não Funcionais
- Resposta do Maia (nodes=1): meta de p95 < 1s em dispositivo de referência de gama média (definir modelo específico na Fase 0).
- Resposta do Stockfish para dica: configurável, padrão ~1–2s de busca.
- App 100% funcional em modo avião.
- Tamanho por ABI: medir após Fase 0 e Fase 7; 9 pesos do Maia + motor Stockfish provavelmente somam 200–300MB+ antes dos splits.

---

## 8. Fora de Escopo do MVP
- Multiplayer online.
- Múltiplos idiomas (apenas português na v1).
- Múltiplos temas de tabuleiro (só piece sets variam).
- Modo puzzle / treino de aberturas.
- Google Play / monetização.

---

## 9. Ambiguidades Conhecidas / Decisões Abertas
- **Licença dos pesos Maia:** confirmar termos de uso/redistribuição no repositório oficial (`CSSLab/maia-chess`) antes de embutir os `.pb.gz` no APK.
- **Viabilidade do FFI in-process para lc0:** se a Fase 0 mostrar que compilar/rodar lc0 completo é inviável no prazo, alternativa de fallback é converter os pesos para TensorFlow Lite e implementar só a inferência da rede (sem o motor de busca completo) — ver a ressalva já registrada sobre risco de divergência de comportamento.
- **Riverpod vs. Bloc:** Riverpod é a recomendação; o agente pode trocar se a prototipagem mostrar melhor ajuste, desde que documente.
- **Drift vs. outra solução local:** Drift é a recomendação por causa das agregações de estatísticas; reavaliar apenas se a Fase 4 revelar atrito significativo.
