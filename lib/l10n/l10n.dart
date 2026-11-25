import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Languages offered in the user settings.
enum AppLanguage {
  en('English'),
  pt('Português');

  const AppLanguage(this.label);

  final String label;
}

/// User-selected language. Starts from the device language.
class LanguageNotifier extends Notifier<AppLanguage> {
  @override
  AppLanguage build() => PlatformDispatcher.instance.locale.languageCode == 'pt'
      ? AppLanguage.pt
      : AppLanguage.en;

  void set(AppLanguage language) => state = language;
}

final languageProvider = NotifierProvider<LanguageNotifier, AppLanguage>(
  LanguageNotifier.new,
);

/// Makes the current language available to [L10nContext.t].
class L10nScope extends InheritedWidget {
  const L10nScope({super.key, required this.language, required super.child});

  final AppLanguage language;

  @override
  bool updateShouldNotify(L10nScope old) => old.language != language;
}

extension L10nContext on BuildContext {
  AppLanguage get language =>
      dependOnInheritedWidgetOfExactType<L10nScope>()?.language ??
      AppLanguage.en;

  /// Translates [english], gettext style: the English text is the key.
  /// `{name}` placeholders are filled from [args].
  String t(String english, [Map<String, Object> args = const {}]) =>
      translate(language, english, args);
}

String translate(
  AppLanguage language,
  String english, [
  Map<String, Object> args = const {},
]) {
  var text = english;
  if (language == AppLanguage.pt) {
    text = _pt[english] ?? _ptDynamic(english) ?? english;
  }
  for (final e in args.entries) {
    text = text.replaceAll('{${e.key}}', '${e.value}');
  }
  return text;
}

/// Messages built by the domain layer with values already interpolated.
String? _ptDynamic(String english) {
  RegExpMatch? m;
  m = RegExp(r'^(\d+) item\(s\) not answered$').firstMatch(english);
  if (m != null) return '${m[1]} item(ns) sem resposta';
  m = RegExp(r'^(\d+) defect\(s\) without a description$').firstMatch(english);
  if (m != null) return '${m[1]} defeito(s) sem descrição';
  m = RegExp(r'^Critical items cannot be N/A: (.*)$').firstMatch(english);
  if (m != null) {
    final labels = m[1]!.split(', ').map((l) => _pt[l] ?? l).join(', ');
    return 'Itens críticos não podem ser N/A: $labels';
  }
  m = RegExp(r'^Odometer cannot be lower than last reading \((\d+) km\)$')
      .firstMatch(english);
  if (m != null) {
    return 'O hodômetro não pode ser menor que a última leitura (${m[1]} km)';
  }
  return null;
}

const _pt = <String, String>{
  // Shell, drawer, settings.
  'Fleet Inspection': 'Vistoria de Frota',
  'Fleet': 'Frota',
  'History': 'Histórico',
  'Home': 'Início',
  'Menu': 'Menu',
  'Settings': 'Configurações',
  'Language': 'Idioma',
  'Appearance': 'Aparência',
  'Dark theme': 'Tema escuro',
  'Light theme': 'Tema claro',
  'Sign out': 'Sair',
  'Sign in as': 'Entrar como',
  'Electronic pre-trip checklist · demo with mock data':
      'Checklist eletrônico de pré-viagem · demo com dados fictícios',
  'Failed to load: {error}': 'Falha ao carregar: {error}',
  'Failed to load fleet: {error}': 'Falha ao carregar a frota: {error}',

  // Fleet.
  'Search plate or model': 'Buscar placa ou modelo',
  'All': 'Todos',
  'All ({n})': 'Todas ({n})',
  'Car': 'Carro',
  'SUV': 'SUV',
  'Pickup': 'Picape',
  'No vehicles match the filter.': 'Nenhum veículo corresponde ao filtro.',
  'Never inspected': 'Nunca vistoriado',
  'Inspect ›': 'Vistoriar ›',
  'No inspections yet.': 'Nenhuma vistoria ainda.',

  // Verdicts.
  'Approved': 'Aprovado',
  'Restricted': 'Com restrições',
  'Blocked': 'Bloqueado',
  'Approved with restrictions': 'Aprovado com restrições',
  'Blocked — do not dispatch': 'Bloqueado — não liberar',
  'CRITICAL': 'CRÍTICO',
  'Critical item: a defect blocks the vehicle':
      'Item crítico: um defeito bloqueia o veículo',

  // Dashboard.
  'Inspections today': 'Vistorias hoje',
  'Total inspections': 'Total de vistorias',
  'Vehicles blocked': 'Veículos bloqueados',
  'Fleet status (latest inspection)': 'Situação da frota (última vistoria)',
  'Blocked vehicles': 'Veículos bloqueados',
  'Most frequent defects': 'Defeitos mais frequentes',
  'No defects recorded.': 'Nenhum defeito registrado.',
  'Not inspected': 'Não vistoriado',

  // Wizard.
  'Inspect {plate}': 'Vistoria {plate}',
  'Vehicle': 'Veículo',
  'Body': 'Carroceria',
  'Review': 'Revisão',
  'Step {n} of {total} · {title}': 'Etapa {n} de {total} · {title}',
  'Back': 'Voltar',
  'Next': 'Avançar',
  'No damage, next': 'Sem danos, avançar',
  'Submit inspection': 'Enviar vistoria',
  '{name} · template v{version}': '{name} · modelo v{version}',
  '{done}/{total} answered': '{done}/{total} respondidos',
  '{n} defect(s)': '{n} defeito(s)',
  'All OK': 'Tudo OK',
  'OK': 'OK',
  'Defect': 'Defeito',
  'N/A': 'N/A',
  'Describe the defect': 'Descreva o defeito',
  'Required for defects': 'Obrigatório para defeitos',
  'Readings': 'Leituras',
  'Odometer (km)': 'Hodômetro (km)',
  'Last reading: {km} km': 'Última leitura: {km} km',
  'Use last reading': 'Usar última leitura',
  'Required': 'Obrigatório',
  'Lower than last reading': 'Menor que a última leitura',
  'Fuel level': 'Nível de combustível',
  'Empty': 'Vazio',
  'Full': 'Cheio',
  'Result if submitted now': 'Resultado se enviada agora',
  'None': 'Nenhum',
  '{n} part(s)': '{n} peça(s)',
  'Inspector signature': 'Assinatura do vistoriador',
  'Sign here': 'Assine aqui',
  'Clear': 'Limpar',
  'Inspector signature is required':
      'A assinatura do vistoriador é obrigatória',
  'Odometer reading is required': 'A leitura do hodômetro é obrigatória',
  'Fuel level is required': 'O nível de combustível é obrigatório',

  // Body damage.
  'Body damage': 'Danos na carroceria',
  'No damage': 'Sem danos',
  '{n} part(s) damaged': '{n} peça(s) com dano',
  'Cosmetic': 'Estético',
  'Broken / missing': 'Quebrado / faltando',
  'safety part': 'peça de segurança',
  'Notes (size, position…)': 'Observações (tamanho, posição…)',
  'A broken or missing safety part blocks the vehicle.':
      'Uma peça de segurança quebrada ou faltando bloqueia o veículo.',
  'Remove': 'Remover',
  'Save damage': 'Salvar dano',
  'Drag to rotate': 'Arraste para girar',
  'Drag to rotate · tap a part to record damage':
      'Arraste para girar · toque em uma peça para registrar dano',
  '3/4': '3/4',
  'Front': 'Frente',
  'Left': 'Esquerda',
  'Right': 'Direita',
  'Rear': 'Traseira',
  'Top': 'Topo',
  'Scratch': 'Risco',
  'Dent': 'Amassado',
  'Broken / cracked': 'Quebrado / trincado',
  'Missing': 'Faltando',

  // Car parts.
  'Front bumper': 'Para-choque dianteiro',
  'Hood': 'Capô',
  'Windshield': 'Para-brisa',
  'Roof': 'Teto',
  'Rear window': 'Vidro traseiro',
  'Tailgate': 'Tampa traseira',
  'Cargo bed': 'Caçamba',
  'Rear bumper': 'Para-choque traseiro',
  'Front left fender': 'Para-lama dianteiro esquerdo',
  'Front right fender': 'Para-lama dianteiro direito',
  'Front left door': 'Porta dianteira esquerda',
  'Front right door': 'Porta dianteira direita',
  'Rear left door': 'Porta traseira esquerda',
  'Rear right door': 'Porta traseira direita',
  'Rear left quarter panel': 'Lateral traseira esquerda',
  'Rear right quarter panel': 'Lateral traseira direita',
  'Left side windows': 'Vidros laterais esquerdos',
  'Right side windows': 'Vidros laterais direitos',
  'Front left wheel': 'Roda dianteira esquerda',
  'Front right wheel': 'Roda dianteira direita',
  'Rear left wheel': 'Roda traseira esquerda',
  'Rear right wheel': 'Roda traseira direita',
  'Left headlight': 'Farol esquerdo',
  'Right headlight': 'Farol direito',
  'Left taillight': 'Lanterna esquerda',
  'Right taillight': 'Lanterna direita',
  'Left mirror': 'Retrovisor esquerdo',
  'Right mirror': 'Retrovisor direito',

  // Report.
  'Report {id}': 'Relatório {id}',
  'Inspection not found: {error}': 'Vistoria não encontrada: {error}',
  'Back to fleet': 'Voltar para a frota',
  'Inspector': 'Vistoriador',
  'Depot': 'Base',
  'Submitted': 'Enviada em',
  'Duration': 'Duração',
  'Odometer': 'Hodômetro',
  'Fuel': 'Combustível',
  'Template': 'Modelo',
  '{plate} · {n} defect(s)': '{plate} · {n} defeito(s)',
  'Body damage · none recorded': 'Danos na carroceria · nenhum registrado',
  'Body damage · {n} part(s)': 'Danos na carroceria · {n} peça(s)',
  'Defects': 'Defeitos',
  'All items': 'Todos os itens',
  'Signature': 'Assinatura',

  // Checklist templates (mock data).
  'Light vehicle pre-trip': 'Pré-viagem veículo leve',
  'SUV pre-trip': 'Pré-viagem SUV',
  'Pickup pre-trip': 'Pré-viagem picape',
  'Exterior': 'Exterior',
  'Mirrors intact and adjusted': 'Retrovisores íntegros e ajustados',
  'Windshield without cracks in driver view':
      'Para-brisa sem trincas no campo de visão do motorista',
  'Wipers and washer fluid working': 'Limpadores e esguicho funcionando',
  'License plates readable': 'Placas legíveis',
  'Tires & wheels': 'Pneus e rodas',
  'Tread depth above 1.6 mm': 'Sulco acima de 1,6 mm',
  'Use the TWI wear indicator': 'Use o indicador de desgaste TWI',
  'Pressure visually correct': 'Calibragem visualmente correta',
  'Wheel nuts present and tight': 'Porcas das rodas presentes e apertadas',
  'Spare tire, jack and wrench on board':
      'Estepe, macaco e chave de roda a bordo',
  'Lights & signals': 'Luzes e sinalização',
  'Headlights (low and high beam)': 'Faróis (baixo e alto)',
  'Brake lights': 'Luzes de freio',
  'Turn signals and hazard lights': 'Setas e pisca-alerta',
  'Reverse light and alarm': 'Luz e alarme de ré',
  'No warning lights on dashboard': 'Sem luzes de advertência no painel',
  'Brakes & steering': 'Freios e direção',
  'Service brake firm, no pulling': 'Freio de serviço firme, sem puxar',
  'Parking brake holds on slope': 'Freio de estacionamento segura em rampa',
  'Steering without excessive play': 'Direção sem folga excessiva',
  'Horn working': 'Buzina funcionando',
  'Fluids & engine': 'Fluidos e motor',
  'Engine oil between MIN and MAX': 'Óleo do motor entre MIN e MAX',
  'Coolant level OK': 'Nível do líquido de arrefecimento OK',
  'No leaks under the vehicle': 'Sem vazamentos sob o veículo',
  'Safety & documents': 'Segurança e documentos',
  'Seat belts latch and retract': 'Cintos de segurança travam e retraem',
  'Warning triangle on board': 'Triângulo de sinalização a bordo',
  'Fire extinguisher charged and in date':
      'Extintor carregado e dentro da validade',
  'Vehicle registration (CRLV) on board': 'Documento do veículo (CRLV) a bordo',
};
