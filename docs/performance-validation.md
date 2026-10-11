# Validação da auditoria — 11/10/2026

## Alterações e regressões verificadas

- Transições: uma restauração atrasada, inclusive com erro, não substitui uma partida nova; uma resposta Maia após descarte não persiste lances. Os botões de abertura bloqueiam chamadas simultâneas antes do primeiro `await`.
- Biblioteca: duas consultas SELECT para 3, 20 e 1.100 partidas; uma para biblioteca vazia. Antes, três partidas exigiam quatro SELECT. Os testes conferem ordenação dos lances e reprodução da FEN.
- Autosave: histórico inalterado não exclui nem reinsere lances; acréscimo grava somente o novo lance; desfazer substitui apenas o sufixo. Uma falha SQLite provocada por trigger comprova rollback da posição e dos lances. Comparação de datas respeita a precisão configurada do Drift.
- PGN: leitura/decodificação e validação usam isolates em Android. A API síncrona continua disponível. Comentários, variantes, tags, FEN e erros são preservados; uma sequência de 4.000 lances passa pela validação iterativa.
- Estado: `copyWith` reutiliza históricos imutáveis não alterados. Término e repetição são memorizados e invalidados quando posição ou histórico mudam. Entradas públicas continuam copiadas; os testes verificam isolamento de listas mutáveis, seleção, desfazer, repetição e mate.

## Medição comparável em profile

Flutter 3.47.4 / Dart 3.13.3; Android API 36 x86_64, AVD `human_chess_phase0_api36`, renderização SwiftShader. Mesmo emulador, SDK, fixtures determinísticas e modo profile. Seis amostras por operação; a primeira foi descartada. Nenhuma outra suíte ou compilação foi executada simultaneamente às medições.

Referência: código de produção no commit `bed03de`, antes das mudanças de PGN e `GameState`. Depois: `b2941c5` com a alteração de `GameState` deste conjunto. O harness é `integration_test/audit_performance_android_test.dart`; na referência, a chamada era síncrona (`parseImport` sem `await`), como na tela de importação original.

| Medida (mediana de cinco amostras) | Antes | Depois |
|---|---:|---:|
| 500 seleções + `isGameOver`, histórico de 80 lances | 250,529 ms | 1,020 ms |
| Importação/validação PGN, 1.000 lances, duração total | 59,990 ms | 51,372 ms |
| Maior intervalo do timer da isolate principal durante importação | 61,934 ms | 9,781 ms |

O timer tem período de 2 ms e mede intervalos observados, incluindo agendamento, GC e transporte entre isolates; não mede diretamente frames. Os resultados comprovam ganho nestes cenários neste emulador. Não permitem afirmar redução de RAM, bateria, tempo de inicialização ou latência de dispositivos físicos. A criação de uma isolate tem custo fixo; arquivos pequenos podem ter maior latência total.

Dados brutos: [antes](performance/audit-before.json), [depois](performance/audit-after.json).

## Renderização

A medição independente de arraste coletou 253 frames: build médio 0,389 ms, p99 1,913 ms, nenhum acima do orçamento; raster médio 24,973 ms, p99 47,365 ms, 229 acima do orçamento. [Dados brutos](performance/board-profile.json).

O atraso de raster continua presente no emulador com GPU por software. Não há comparação antes/depois de raster neste conjunto e não foi alterada a aparência do tabuleiro. O diagnóstico em aparelho físico permanece pendente.

## Tamanho e empacotamento Android

Dois builds consecutivos com o mesmo SDK, código Dart/nativo, configuração e comando `flutter build apk --release --split-per-abi --target-platform android-arm64`:

| APK ARM64 | Bytes |
|---|---:|
| Antes da remoção da duplicata | 152.001.006 |
| Depois | 150.737.798 |
| Redução | 1.263.208 |

O plugin vendorizado deixou de declarar o asset Maia 1900; o arquivo e sua declaração foram movidos para o exemplo, que agora usa um asset próprio. O bundle do exemplo foi compilado e contém os bytes corretos no caminho declarado. A aplicação continua usando `assets/maia_weights/maia-1900.pb.gz`. Consumidores externos deste fork que usassem a chave implícita `packages/leela_chess_zero/assets/weights/maia-1900.pb.gz` precisam declarar seus próprios pesos, conforme o README do plugin.

Os nove pesos da aplicação e todas as bibliotecas `.so`, inclusive `libapp.so`, são idênticos entre os APKs. A redução resulta da duplicata e dos metadados correspondentes. [Comparação instrumentada](performance/apk-size.json). `libstockfish.so` continua sendo o maior componente; alterar sua NNUE exigiria uma validação separada da qualidade de análise.

`verify_apk.py`, verificação da assinatura com `apksigner`, alinhamento ZIP via `zipalign -c -P 16 4` e inspeção dos segmentos ELF LOAD passaram. Todas as sete bibliotecas ARM64 têm alinhamento ELF de pelo menos 16 KB. Os scripts possuem dez testes passando, incluindo rejeição da duplicata do plugin.

O build local utiliza a chave de debug prevista pela configuração existente, pois não há `android/app/key.properties`. Os APKs servem à validação local; a assinatura de distribuição não foi exercitada. O SDK também emitiu avisos de futura descontinuação de suporte a AGP 8.11.1 e Kotlin 2.2.20; os builds concluíram sem erro.

## Reproduzir

```sh
dart format --output=none --set-exit-if-changed lib test integration_test test_driver
flutter analyze
flutter test --coverage
python3 -m unittest discover -s scripts -p 'test_*.py'
flutter drive --profile --no-dds --driver=test_driver/audit_performance.dart --target=integration_test/audit_performance_android_test.dart -d DEVICE
flutter drive --profile --no-dds --driver=test_driver/performance.dart --target=integration_test/board_performance_test.dart -d DEVICE
flutter test integration_test/android_acceptance_test.dart -d DEVICE
flutter test integration_test/phase_0_3_android_test.dart -d DEVICE
flutter build apk --release --split-per-abi --target-platform android-arm64
python3 scripts/verify_apk.py build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

O driver salva `build/audit_performance.json`. O benchmark só executa em profile e não usa limites de tempo como assertions. Para reproduzir a referência, use um checkout de `bed03de`, copie o harness e o driver, e troque `await ...parseImportAsync` por `...parseImport` no harness. Mantenha os mesmos fixtures, SDK e dispositivo.

Referências oficiais: [Flutter — isolates](https://docs.flutter.dev/perf/isolates) e [compute](https://api.flutter.dev/flutter/foundation/compute.html). As reduções de consultas/escritas são contagens instrumentadas no projeto; os tempos acima são evidência experimental, não uma garantia do framework.
