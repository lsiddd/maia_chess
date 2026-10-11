# Validação da auditoria — 11/10/2026

## Alterações e regressões verificadas

- Transições: uma restauração atrasada, inclusive com erro, não substitui uma partida nova; uma resposta Maia após descarte não persiste lances. Os botões de abertura bloqueiam chamadas simultâneas antes do primeiro `await`.
- Biblioteca: duas consultas SELECT para 3, 20 e 1.100 partidas; uma para biblioteca vazia. Antes, três partidas exigiam quatro SELECT. Os testes conferem ordenação dos lances e reprodução da FEN.
- Autosave: histórico inalterado não exclui nem reinsere lances; acréscimo grava somente o novo lance; desfazer substitui apenas o sufixo. Uma falha SQLite provocada por trigger comprova rollback da posição e dos lances. Comparação de datas respeita a precisão configurada do Drift.
- PGN: leitura/decodificação e validação usam isolates em Android. A API síncrona continua disponível. Comentários, variantes, tags, FEN e erros são preservados; uma sequência de 4.000 lances passa pela validação iterativa.
- Estado: `copyWith` reutiliza históricos imutáveis não alterados. Término e repetição são memorizados e invalidados quando posição ou histórico mudam. Entradas públicas continuam copiadas; os testes verificam isolamento de listas mutáveis, seleção, desfazer, repetição e mate.
- Estatísticas: consultas, mapeamento, cálculo e geração dos batches usam `computeWithDatabase` com a conexão existente, inclusive na transação de conclusão/exclusão. Os testes verificam visibilidade de dados ainda não commitados, rollback de conclusão + rating quando a projeção falha e notificações entre conexões, inclusive resultado alterado sem mudar a quantidade de partidas.

## Diagnóstico, causa raiz, prioridade e riscos

| Prioridade / esforço relativo | Causa comprovada e local | Efeito da solução / risco |
|---|---|---|
| P1 / médio | `GameController.restoreActiveGame` aplicava a leitura sem validar a geração após o `await`; aberturas simultâneas podiam disputar o controlador | Respostas antigas são descartadas e aberturas são bloqueadas enquanto pendentes; uma operação superada retorna sem abrir uma tela |
| P2 / baixo | `DriftGameRepository.watchLibrary` hidratava cada partida com uma consulta adicional | Duas consultas no total; a biblioteca ainda materializa todo o histórico, portanto paginação continua relevante para volumes muito maiores |
| P2 / médio | `_replaceSnapshot` excluía e reinseria todos os lances até quando só metadados mudavam | Somente o sufixo modificado é escrito; há uma SELECT adicional para comparar o histórico, preservando a transação |
| P2 / médio | A tela de importação executava parsing, replay SAN e validação de variantes na isolate principal; a validação recursiva crescia por lance | Trabalho movido para workers e travessia iterativa; criação/transporte da isolate têm custo fixo |
| P2 / médio | `GameState.copyWith` copiava cinco históricos e `isGameOver` repetia a varredura de FEN em seleções | Históricos compartilhados apenas quando imutáveis e cache invalidado por posição/histórico; duas flags internas adicionais por estado |
| P2 / baixo | O app e o plugin empacotavam bytes idênticos do Maia 1900 | Duplicata removida, sem alterar motores ou pesos da aplicação; a chave de asset implícita do fork deixa de existir |
| P2 / médio | SQLite já executava em background, mas mapeamento, projeção e montagem de batches de estatísticas permaneciam na isolate principal | Worker compartilha a conexão/transação; menor bloqueio da isolate principal, com custo de comunicação e maior duração total de reconstrução |

MVVM com Riverpod, repositories e Drift foi mantida. Nenhuma dependência, migração de schema ou regra de rating/campanha foi alterada. Layout e temas foram preservados; os controles de abertura ficam temporariamente bloqueados durante a operação. Cada melhoria tem seu próprio commit; a reversão deve considerar os helpers de testes compartilhados.

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

## Estatísticas com históricos maiores

O benchmark `integration_test/stats_performance_android_test.dart` usa SQLite em arquivo temporário com `NativeDatabase.createInBackground`, como a aplicação, 1.000/5.000 partidas avaliadas e seis amostras por cenário (primeira descartada). Mesmo SDK, emulador e fixture antes/depois; sem compilação ou outra suíte simultânea. Antes: `675b592`; depois: implementação do worker de estatísticas deste conjunto.

| Partidas / operação | Tempo total antes → depois | Maior intervalo do timer, antes → depois |
|---|---:|---:|
| 1.000 / reconstrução transacional | 101,452 → 143,582 ms | 18,259 → 15,567 ms |
| 1.000 / leitura do snapshot | 32,884 → 30,182 ms | 15,660 → 5,697 ms |
| 5.000 / reconstrução transacional | 118,246 → 135,134 ms | 30,423 → 11,776 ms |
| 5.000 / leitura do snapshot | 92,423 → 93,381 ms | 27,735 → 9,706 ms |

O ganho medido é de responsividade da isolate principal, com maior duração total na reconstrução. Há custo fixo de criar a isolate e comunicar com a conexão compartilhada. O algoritmo de rating, as regras da campanha e a reconstrução integral continuam iguais; não houve migração de schema nem cálculo incremental de Elo. O observador usa uma consulta leve para receber estado inicial e notificações de `games`/`rating_history`, e lê o snapshot no worker.

[Dados antes](performance/stats-before.json) / [depois](performance/stats-after.json). O timer também observa GC/agendamento, inclusive durante a breve espera após a operação; não é uma medição de frames. A ligação de banco entre isolates segue a [API oficial do Drift](https://drift.simonbinder.eu/isolates/#simple-sharing), confirmada no código instalado da versão 2.34.3. A atomicidade foi verificada no projeto com uma falha SQLite induzida no worker.

## Renderização

A medição independente de arraste coletou 253 frames: build médio 0,389 ms, p99 1,913 ms, nenhum acima do orçamento; raster médio 24,973 ms, p99 47,365 ms, 229 acima do orçamento. [Dados brutos](performance/board-profile.json).

O atraso de raster continua presente no emulador com GPU por software. Não há comparação antes/depois de raster neste conjunto e não foi alterada a aparência do tabuleiro. O diagnóstico em aparelho físico permanece pendente.

## Tamanho e empacotamento Android

No estágio de remoção da duplicata (`5a5392e` → `675b592`), dois builds consecutivos com o mesmo SDK, código Dart/nativo, configuração e comando `flutter build apk --release --split-per-abi --target-platform android-arm64`:

| APK ARM64 | Bytes |
|---|---:|
| Antes da remoção da duplicata | 152.001.006 |
| Depois | 150.737.798 |
| Redução | 1.263.208 |

O plugin vendorizado deixou de declarar o asset Maia 1900; o arquivo e sua declaração foram movidos para o exemplo, que agora usa um asset próprio. O bundle do exemplo foi compilado e contém os bytes corretos no caminho declarado. A aplicação continua usando `assets/maia_weights/maia-1900.pb.gz`. Consumidores externos deste fork que usassem a chave implícita `packages/leela_chess_zero/assets/weights/maia-1900.pb.gz` precisam declarar seus próprios pesos, conforme o README do plugin.

Os nove pesos da aplicação e todas as bibliotecas `.so`, inclusive `libapp.so`, são idênticos entre os APKs. A redução resulta da duplicata e dos metadados correspondentes. [Comparação instrumentada](performance/apk-size.json). `libstockfish.so` continua sendo o maior componente; alterar sua NNUE exigiria uma validação separada da qualidade de análise.

`verify_apk.py`, verificação da assinatura com `apksigner`, alinhamento ZIP via `zipalign -c -P 16 4` e inspeção dos segmentos ELF LOAD passaram. Todas as sete bibliotecas ARM64 têm alinhamento ELF de pelo menos 16 KB. Os scripts possuem dez testes passando, incluindo rejeição da duplicata do plugin.

O build local utiliza a chave de debug prevista pela configuração existente, pois não há `android/app/key.properties`. Os APKs servem à validação local; a assinatura de distribuição não foi exercitada. O SDK também emitiu avisos de futura descontinuação de suporte a AGP 8.11.1 e Kotlin 2.2.20; os builds concluíram sem erro.

## Validação final do conjunto

- `dart format --output=none --set-exit-if-changed lib test integration_test test_driver`: 96 arquivos, nenhuma alteração necessária.
- `flutter analyze`: nenhuma ocorrência. `flutter test --coverage`: 239 testes passando. Os três testes do worker foram repetidos após o ajuste final de lint e passaram.
- Scripts Python: dez testes passando.
- Android API 36: 75 testes da suíte consolidada passaram novamente após o worker de estatísticas. Mais dois testes nativos passaram: troca Maia 1100 → 1900 com dicas/cancelamento e recuperação do lc0 após peso inválido.
- Os benchmarks de seleção/PGN, estatísticas e arraste executaram em profile; as medições e limitações estão registradas acima.
- Build release final com `--split-per-abi --target-platform android-arm64,android-x64`: ARM64 com 150.737.806 bytes e x86_64 com 152.463.137 bytes. Os nove pesos são idênticos aos fontes; duplicata ausente e segmentos ELF alinhados a pelo menos 16 KB em ambas as ABIs. APK ARM64 também passou em `verify_apk.py`, `zipalign` e `apksigner`. [Tamanhos, hashes e alinhamentos finais](performance/final-release.json).
- Release x86_64 instalado no emulador: tela de estatísticas exibiu rating inicial 1500 e zero partidas avaliadas; Maia 1900 iniciou pelas brancas e respondeu a `e7e5`; histórico observado `1. e4 e5 · 2. Nf3`; Stockfish destacou o cavalo preto de b8. Labels e histórico foram conferidos por assertions sobre a árvore de acessibilidade do UIAutomator. [Evidência do smoke test](performance/release-smoke.json). Isto não substitui toda a suíte de integração em release nem valida ARM64 em hardware físico.

Uma tentativa adicional de build release x86_64 em paralelo à integração falhou por disputa de `GeneratedPluginRegistrant.java`: o arquivo gerado passou a referenciar `integration_test`, ausente daquela compilação de produção. A repetição sequencial passou, assim como o build final das duas ABIs. Não foi necessário alterar os fontes Android.

## Reproduzir

```sh
dart format --output=none --set-exit-if-changed lib test integration_test test_driver
flutter analyze
flutter test --coverage
python3 -m unittest discover -s scripts -p 'test_*.py'
flutter drive --profile --no-dds --driver=test_driver/audit_performance.dart --target=integration_test/audit_performance_android_test.dart -d DEVICE
flutter drive --profile --no-dds --driver=test_driver/audit_performance.dart --target=integration_test/stats_performance_android_test.dart -d DEVICE
flutter drive --profile --no-dds --driver=test_driver/performance.dart --target=integration_test/board_performance_test.dart -d DEVICE
flutter test integration_test/android_acceptance_test.dart -d DEVICE
flutter test integration_test/phase_0_3_android_test.dart -d DEVICE
flutter build apk --release --split-per-abi --target-platform android-arm64
python3 scripts/verify_apk.py build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

O driver salva `build/audit_performance.json`. O benchmark só executa em profile e não usa limites de tempo como assertions. Para reproduzir a referência, use um checkout de `bed03de`, copie o harness e o driver, e troque `await ...parseImportAsync` por `...parseImport` no harness. Mantenha os mesmos fixtures, SDK e dispositivo.

O benchmark de estatísticas usa o mesmo driver e sobrescreve o arquivo temporário; copie cada saída antes de executar outro alvo. Para sua referência, use `675b592` com o harness de estatísticas e o driver deste conjunto, sem alterar o harness.

Referências oficiais: [Flutter — isolates](https://docs.flutter.dev/perf/isolates) e [compute](https://api.flutter.dev/flutter/foundation/compute.html). As reduções de consultas/escritas são contagens instrumentadas no projeto; os tempos acima são evidência experimental, não uma garantia do framework.
