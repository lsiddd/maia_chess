# Validação de interação — 19/09/2026

## Cobertura

- Promoção por toque e arraste: peão no destino durante a escolha; confirmação, barreira, voltar, inversão, reinício e suspensão do app. Respostas atrasadas não alteram uma partida nova.
- Desfazer: seleção, posição, histórico e camadas de animação sincronizados. Reprodução: início, próximo, anterior e final conferidos contra a FEN salva.
- Encerramento: resultado persistente e motivo do empate; xeque-mate prevalece sobre o contador de 50 lances.
- Dicas: fechar, voltar ou tocar fora aciona cancelamento; respostas atrasadas são descartadas e a interação volta a funcionar. A integração Android também verifica recarga do Maia após cancelar uma dica.
- Arraste: inversão, mudança de posição, suspensão e cancelamento do ponteiro. Roque com rei e torre sincronizados; retorno de lance inválido sem duplicar a peça.
- Rei em xeque: fugas e capturas legais nos quatro cantos, ambas as cores, orientações, toque e arraste.

## Performance

Flutter 3.47.4, modo **profile**, emulador Android 16/API 36 ARM64 (`maia_test`), tabuleiro de 320 pixels lógicos. Benchmark de 180 atualizações de ponteiro; 337 frames coletados pelo `watchPerformance`.

| Medida | Resultado |
|---|---:|
| Reconstruções de casas em 30 atualizações, antes | 1.920 |
| Reconstruções de casas em 30 atualizações, depois | 0 |
| Build médio / p99 / pior | 0,590 / 2,608 / 3,733 ms |
| Frames acima do orçamento de build | 0 |
| Raster médio / p99 / pior | 16,631 / 33,528 / 134,466 ms |
| Frames acima do orçamento de raster | 178 de 337 |

O `ValueNotifier` atualiza apenas as camadas móveis; a grade é reutilizada e tem um `RepaintBoundary`. A contagem de reconstruções é um teste de regressão em modo debug. Os tempos são uma amostra profile separada, depois de estabilizar o arraste.

O raster ainda apresenta atrasos neste emulador. Estes números não comprovam fluidez em aparelho físico; a medição física permanece pendente por falta de aparelho conectado.

## Reproduzir

```sh
flutter test --coverage
flutter analyze --no-fatal-infos
dart format --output=none --set-exit-if-changed lib test integration_test test_driver
python3 -m unittest discover -s scripts -p 'test_*.py'
flutter test integration_test -d DEVICE
flutter drive --profile --no-dds --driver=test_driver/performance.dart --target=integration_test/board_performance_test.dart -d DEVICE
```

O benchmark só executa em profile; a execução comum de integração o ignora. `--no-dds` permite que a coleta de timeline se conecte diretamente ao serviço da VM. O driver salva os dados brutos em `build/board_performance.json`.
