import 'package:flutter/services.dart';

/// Tipo de evento sonoro/tátil de um lance, derivado da notação SAN.
///
/// A ordem das constantes é a de prioridade: um lance pode ser captura *e*
/// xeque ao mesmo tempo, e só um feedback é emitido — o mais significativo.
enum MoveFeedbackKind { checkmate, check, promotion, capture, castle, move }

/// Classifica um lance a partir da sua notação SAN.
///
/// O SAN já codifica tudo que interessa aqui — `x` para captura, `+` para
/// xeque, `#` para mate, `O-O` para roque e `=` para promoção — inclusive
/// nos casos em que olhar só as casas de origem/destino enganaria, como a
/// captura en passant (onde a casa de destino estava vazia).
MoveFeedbackKind classifyMoveFeedback(String san) {
  if (san.contains('#')) return MoveFeedbackKind.checkmate;
  if (san.contains('+')) return MoveFeedbackKind.check;
  if (san.contains('=')) return MoveFeedbackKind.promotion;
  if (san.contains('x')) return MoveFeedbackKind.capture;
  if (san.startsWith('O-O')) return MoveFeedbackKind.castle;
  return MoveFeedbackKind.move;
}

/// Emite a vibração correspondente a [kind].
///
/// Mantém a intensidade proporcional ao peso do evento: um lance comum quase
/// não se sente, enquanto mate e xeque são nitidamente distintos. A vibração
/// respeita a configuração de háptica do próprio Android — quando o usuário
/// desliga o retorno tátil do sistema, estas chamadas não fazem nada.
Future<void> playMoveHaptic(MoveFeedbackKind kind) {
  return switch (kind) {
    MoveFeedbackKind.checkmate => HapticFeedback.heavyImpact(),
    MoveFeedbackKind.check => HapticFeedback.mediumImpact(),
    MoveFeedbackKind.promotion => HapticFeedback.mediumImpact(),
    MoveFeedbackKind.capture => HapticFeedback.mediumImpact(),
    MoveFeedbackKind.castle => HapticFeedback.lightImpact(),
    MoveFeedbackKind.move => HapticFeedback.selectionClick(),
  };
}
