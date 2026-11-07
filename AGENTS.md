# AGENTS.md

Instruções para agentes de IA (e para humanos) que trabalham neste repositório: um app Android em Dart.

## Princípios

1. Tudo fica versionado no git.
2. O código é bem escrito.
3. O pipeline de CI/CD funciona sempre.
4. A entrega vai para a `main`, e o nightly é verificado depois.

## 1. Versionamento

- Tudo que faz parte do projeto vai para o git: código, testes, configurações, workflows de CI/CD, scripts e documentação.
- Nunca versionar segredos, chaves de assinatura ou arquivos gerados pelo build.
- Commits pequenos e atômicos, com mensagens claras que explicam o que mudou e por quê.
- Ao terminar uma tarefa, não deve sobrar nada fora do git.
- Nunca reescrever o histórico da `main` nem pular as verificações do repositório.

## 2. Qualidade do código

- Seguir as convenções da linguagem e as regras de lint e formatação já configuradas no projeto.
- Nomes claros, funções pequenas, uma responsabilidade por classe ou função.
- Sem código morto, sem código comentado, sem logs de debug esquecidos.
- Tratar erros de forma explícita; não engolir exceções.
- Comentários explicam o porquê, não o quê.
- Comportamento novo vem com teste; correção de bug vem com teste de regressão.
- Seguir a estrutura e os padrões que já existem. Só adicionar dependência nova se for realmente necessária.

## 3. Antes de commitar

Rodar localmente as mesmas verificações que o pipeline roda (formatação, análise estática e testes). Se algo falhar, corrigir a causa antes de seguir. Não commitar com verificações falhando.

## 4. Pipeline CI/CD

- Garantir que o pipeline está funcionando corretamente: ao mexer em código, dependências, versões, assinatura ou no próprio pipeline, confirmar que ele continua válido.
- Nunca desativar etapas, afrouxar regras ou ignorar testes só para o pipeline passar. Corrigir a causa real.
- Segredos só via mecanismo seguro do CI, nunca no repositório.

## 5. Entrega na `main`

1. Verificações locais passando.
2. Commit com mensagem clara.
3. Enviar para a `main`.
4. Acompanhar o pipeline até o fim.
5. Se falhar: ler os logs, corrigir e enviar de novo. A `main` não pode ficar quebrada.
6. Se não for possível corrigir rápido, reverter a mudança e reportar o problema.

## 6. Verificação do nightly

Com a `main` verde, confirmar que o nightly é gerado corretamente:

- O build nightly existe, roda no agendamento esperado e também pode ser disparado manualmente.
- Quando a mudança afetar build, release ou pipeline, disparar o nightly e acompanhar até o fim.
- Conferir que:
  - a execução terminou com sucesso;
  - o artefato do app foi gerado e publicado;
  - a versão identifica claramente que é um nightly;
  - o build saiu do commit mais recente da `main`.
- Se algo estiver errado, tratar como bug: corrigir, enviar e verificar de novo.

## 7. Relatório final

Ao concluir, informar:

- o que foi enviado para a `main`;
- o status do pipeline;
- o status do nightly;
- pendências ou riscos, se houver.
