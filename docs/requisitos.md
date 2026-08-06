# Requisitos — App de Xadrez Offline com IA Maia
**Plataforma:** Android · **Stack:** Flutter/Dart · **Distribuição:** APK direto (sideload / código aberto)

## 1. Visão Geral
Aplicativo de xadrez para jogar offline contra uma IA que imita estilos de jogo humano em diferentes níveis, usando os pesos do projeto **Maia Chess**. O nível de dificuldade determina qual peso é carregado no motor.

## 2. Arquitetura Técnica
- **UI e lógica de app:** Flutter/Dart.
- **Regras de xadrez:** biblioteca Dart para geração/validação de lances, estado de jogo, FEN/PGN (pacote existente tipo `chess` ou implementação própria).
- **IA "adversário" (estilo humano):** motor **lc0** compilado para Android via NDK (ABIs `arm64-v8a` e `armeabi-v7a`), executado in-process e acessado via **Dart FFI**, falando protocolo UCI internamente. Carrega o peso Maia correspondente ao nível escolhido, rodando com busca mínima (nodes=1), que é o uso pretendido/validado do Maia — não precisa de busca profunda.
- **IA "melhor lance objetivo" (para dicas):** motor **Stockfish** compilado para Android, mesma abordagem via FFI.
- **100% offline:** nenhuma dependência de rede em tempo de execução.

> ⚠️ Rodar um binário nativo como processo externo não é permitido no Android moderno (restrições W^X desde a API 29). lc0 e Stockfish devem ser integrados como bibliotecas nativas (.so) chamadas em processo via FFI — não como subprocessos lançados a partir de um arquivo copiado em runtime.

## 3. Modelo de Dificuldade
- **9 níveis**, um por peso oficial do Maia: 1100, 1200, 1300, ..., 1900 (incrementos de 100).
- Todos os arquivos de peso (`.pb.gz`) **empacotados no APK** desde a instalação.
- Trocar de nível recarrega o peso correspondente no lc0.

## 4. Navegação de Dificuldade
- **Modo Livre:** escolha manual de qualquer nível a qualquer momento.
- **Modo Campanha (opcional):** progressão sequencial 1100 → 1900. Desbloqueia o próximo nível ao vencer **X de Y partidas** no nível atual (ex: 2 de 3 — parametrizável).

## 5. Fluxo de uma Partida
1. Jogador escolhe **lado** (brancas/pretas) antes de cada partida.
2. Escolhe nível (modo livre) ou nível é definido pela campanha.
3. Cronômetro **desativado por padrão**, com opção de ativar tempo (ex: 5/10/30 min).
4. Durante a partida:
   - **Desfazer jogada (undo)** disponível.
   - **Botão de dica:** mostra lado a lado (a) o lance que um jogador daquele nível provavelmente jogaria (via Maia) e (b) o lance objetivamente melhor (via Stockfish).
   - Usar undo ou dica marca a partida como **"não avaliada"**.
5. Ao final: salvar no histórico e/ou exportar PGN.

## 6. Persistência
- **Partida em andamento:** autosave contínuo (fechar e reabrir o app retoma de onde parou).
- **Biblioteca de partidas:** histórico de partidas finalizadas, com reabertura/revisão e exportação PGN individual.
- **Importar PGN:** carregar uma partida externa para revisão.
- Armazenamento local (ex: Hive, Isar ou sqflite). Sem sincronização em nuvem.

## 7. Estatísticas e Rating
- Por nível: vitórias, derrotas, empates.
- Sequências (streaks) atuais e recordes.
- **Estimativa de rating do jogador** a partir do desempenho contra os níveis do Maia (ex: sistema tipo Elo simplificado).
- Gráfico de evolução do rating estimado ao longo do tempo.
- Partidas "não avaliadas" (com undo/dica) aparecem no histórico mas **não** entram no cálculo de rating/streaks.

## 8. UI/UX e Personalização
- Múltiplos **conjuntos de peças** selecionáveis.
- **Modo escuro/claro.**
- Tabuleiro: tema único no MVP (sem múltiplos temas de tabuleiro).
- Idioma: **apenas português** na v1.

## 9. Distribuição
- APK direto (sideload), projeto de código aberto.
- Sem Google Play — logo sem os limites de tamanho da loja, mas o tamanho final do instalável ainda merece atenção.

## 10. Requisitos Não Funcionais
- Funcionalidade 100% offline.
- Tamanho estimado do app: pode passar de 200–300MB (9 pesos do Maia + motor Stockfish). Considerar builds separados por ABI (arm64-v8a / armeabi-v7a) para reduzir o tamanho por dispositivo.
- Desempenho: resposta do Maia (nodes=1) deve ser quase instantânea (<1s); busca do Stockfish para dica configurável (ex: 1–3s).
- Android mínimo sugerido: API 23+ (a confirmar conforme requisitos de build do NDK/lc0).

## 11. Fora do Escopo do MVP
- Multiplayer online.
- Múltiplos idiomas.
- Múltiplos temas de tabuleiro.
- Modo puzzle / treino de aberturas.
- Google Play / monetização.

## 12. Riscos Técnicos Principais
- **Compilar o lc0 para Android e validar a execução via FFI** é o maior risco técnico — recomenda-se um spike técnico isolado validando isso antes de construir o resto do app.
- Confirmar disponibilidade e licença dos pesos oficiais do Maia (repositório `CSSLab/maia-chess`).
- O mesmo trabalho de build/FFI precisa ser replicado para o Stockfish.

## 13. Stack Sugerida (resumo)
| Camada | Tecnologia |
|---|---|
| UI / app | Flutter (Dart) |
| Regras de xadrez | Pacote Dart de regras (geração/validação, FEN/PGN) |
| IA "estilo humano" | lc0 + pesos Maia, via FFI |
| IA "melhor lance" | Stockfish, via FFI |
| Armazenamento | Hive / Isar / sqflite |
