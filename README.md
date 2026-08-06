# Xadrez Maia

Aplicativo Android de xadrez offline, em Flutter/Dart, contra uma IA que
imita estilos de jogo humano em diferentes faixas de rating usando os pesos
do projeto [Maia Chess](https://github.com/CSSLab/maia-chess) (rodando sobre
o motor lc0). Uma segunda IA (Stockfish) fornece o lance objetivamente
melhor, para o sistema de dicas. Projeto de código aberto, distribuído como
APK direto (sideload), sem dependência de rede em tempo de execução.

Documentação de referência:
- [`docs/requisitos.md`](docs/requisitos.md) — requisitos de produto.
- [`docs/especificacao.md`](docs/especificacao.md) — especificação técnica e
  fases de implementação.
- [`ADR.md`](ADR.md) — decisões de arquitetura e desvios em relação à
  especificação original, com justificativa.

## Status

Fases 0–5 implementadas: motores nativos lc0/Stockfish, partida contra Maia,
dica dupla, persistência Drift, autosave/retomada, biblioteca/replay,
importação/exportação PGN, rating estimado, estatísticas e campanha 2 de 3.
As Fases 6–7 (personalização e empacotamento final) continuam em
desenvolvimento. Ver `ADR.md` para as decisões e validações já realizadas.

## Como rodar

Pré-requisitos: Flutter (gerenciado neste ambiente via `fvm`), Android SDK +
NDK `28.2.13676358` instalado, JDK 17.

```bash
flutter pub get
flutter run          # com um emulador/dispositivo Android conectado
flutter analyze
flutter test
flutter test integration_test/phase_4_android_test.dart -d <device>
```

## Estrutura

Organização feature-first — ver `docs/especificacao.md` seção 3 para o
racional completo:

```
lib/
├── core/            # theming, constantes
├── engine_ffi/       # serviços lc0 (Maia) e Stockfish via FFI
├── features/         # game, difficulty, hints, history, stats, settings, pgn
└── data/             # Drift database, repositórios, providers Riverpod

native/                # dependências nativas vendorizadas (ver ADR-001)
assets/maia_weights/   # pesos .pb.gz do Maia (1100-1900), a partir da Fase 2
```

Não há uma pasta de DI dedicada: os providers Riverpod ficam ao lado de
quem os expõe (`data/providers.dart` para repositórios, e cada
controller/serviço expõe os seus próprios, ex.:
`GameController`/`lc0EngineFactoryProvider`), padrão idiomático do
Riverpod.
