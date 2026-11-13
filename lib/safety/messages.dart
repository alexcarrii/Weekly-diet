// Textos de seguridad y derivación (M1–M7) del documento sprint1/reglas-nutricionales-y-seguridad.md.
// Literales: cualquier cambio de redacción lo valida el dietista-nutricionista colegiado.
// Están aquí juntos para poder revisarlos sin tocar la lógica.

import 'safety_logic.dart';

abstract final class SafetyMessages {
  /// M1 · Menor de 18.
  static const m1Minor = '¡Gracias por tu interés! WEEKLY DIET está pensada para personas adultas. '
      'A tu edad, la alimentación tiene necesidades propias, y lo mejor es que la planifiques con tu '
      'familia y con tu pediatra o médico de familia.';

  /// M2 · Embarazo o lactancia.
  static const m2Pregnancy = '¡Enhorabuena por esta etapa! Ahora tus necesidades cambian y conviene que tu '
      'matrona, tu médico o un dietista-nutricionista te orienten. Puedes seguir usando la app para organizar '
      'la compra y te propondremos menús generales que evitan los alimentos desaconsejados en el embarazo. '
      'Coméntalos con tu profesional.';

  /// M3 · Enfermedad o medicación con implicación dietética.
  static const m3Condition = 'Gracias por contárnoslo. Cuando hay una enfermedad o un tratamiento de por medio, '
      'la alimentación debe ajustarla tu médico o un dietista-nutricionista. Puedes usar la app para planificar '
      'y hacer la compra con menús generales, pero antes de seguirlos, revísalos con tu profesional.';

  /// M4 · Peso bajo o pérdida de peso sin buscarla.
  static const m4Weight = 'Gracias por decírnoslo. Un cambio de peso sin buscarlo merece que lo comentes con tu '
      'médico. Mientras tanto, te propondremos menús equilibrados y variados, sin objetivo de pérdida de peso.';

  /// M5 · Malestar con la comida o señales de TCA.
  static const m5Eating = 'Gracias por compartirlo; no es fácil. Tu bienestar es lo primero, y en esto puede '
      'ayudarte mucho hablar con tu médico de familia o con un profesional de la salud mental. En la app vamos '
      'a centrarnos en organizar comidas variadas y la compra, sin objetivos de peso ni cifras.';

  /// M6 · Petición peligrosa (se usará en el chat del Sprint 2).
  static const m6Dangerous = 'Entendemos que quieras resultados, pero ese enfoque puede perjudicar tu salud y '
      'suele ser difícil de mantener. Te proponemos un plan moderado y sostenible, con comidas que te gusten. '
      'Si quieres un plan más ajustado, un dietista-nutricionista puede hacerlo contigo.';

  /// M7 · Riesgo inmediato (Sprint 2, chat). Revisión adicional por un profesional de salud mental.
  static const m7Crisis = 'Lo que nos cuentas es importante y mereces ayuda ahora. Si estás en peligro, llama al '
      '112. Si tienes pensamientos de hacerte daño, puedes llamar al 024 (gratuito, las 24 horas). También '
      'puedes hablar con alguien de confianza o con tu médico.';

  /// Aviso fijo para dieta vegana.
  static const veganB12 =
      'Si sigues una alimentación vegana, consulta con un profesional sanitario sobre la vitamina B12.';

  /// Tarjeta fija del Inicio en modo general.
  static const generalModeBanner =
      'Estos menús son generales. Antes de seguirlos, coméntalo con tu profesional sanitario.';

  /// Aviso cuando el usuario no da permiso en el cribado.
  static const noConsentGeneral =
      'Sin tu permiso no podemos tener en cuenta tu salud, así que te propondremos menús generales.';

  static String forReferral(ReferralMessage m) => switch (m) {
        ReferralMessage.pregnancy => m2Pregnancy,
        ReferralMessage.condition => m3Condition,
        ReferralMessage.weight => m4Weight,
        ReferralMessage.eating => m5Eating,
      };

  /// Todos los textos que ve el usuario, para la comprobación de tono (SEC-08) en los tests.
  static const all = [
    m1Minor,
    m2Pregnancy,
    m3Condition,
    m4Weight,
    m5Eating,
    m6Dangerous,
    m7Crisis,
    veganB12,
    generalModeBanner,
    noConsentGeneral,
  ];
}
