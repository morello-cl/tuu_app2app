/// Información estática del paquete: versión, equipo y changelog.
///
/// Accesible directamente a través de constantes estáticas. Útil para
/// que la app consumidora muestre la versión del plugin en una pantalla
/// de "Acerca de", logs estructurados o reportes de soporte.
///
/// ```dart
/// print(PackageInfo.version);    // '0.1.0'
/// print(PackageInfo.packageName); // 'tuu_app2app'
/// print(PackageInfo.about);
/// for (final entry in PackageInfo.changelog) print(entry);
/// ```
class PackageInfo {
  /// Constructor privado: no debe instanciarse — todos los miembros son
  /// `static`.
  PackageInfo._();

  /// Versión actual del plugin (semver). Mantener sincronizado con
  /// `pubspec.yaml`.
  static const String version = '0.2.0';

  /// Nombre del paquete (matching `name:` de `pubspec.yaml`).
  static const String packageName = 'tuu_app2app';

  /// Información del equipo de desarrollo.
  static const PackageAbout about = PackageAbout._();

  /// Historial de cambios, ordenado del más reciente al más antiguo.
  static const List<ChangelogEntry> changelog = <ChangelogEntry>[
    ChangelogEntry(
      version: '0.2.0',
      date: '2026-05-13',
      changes: <String>[
        'API tipada por nombre TUU: TuuTipPolicy, TuuCashbackPolicy, TuuExtraData, TuuCustomField, TuuDteType',
        'TuuPaymentMethod corregido (askUser=0, credit=1, debit=2) per doc oficial',
        'TuuChargeResponse agrega transactionTip / transactionCashback',
        'TuuException.raw renombrado a rawJson: String? (sin Object? en la API)',
        'Mapeo de errores reescrito según tablas oficiales (errorCode 10/11-21, ICE-XX, HP-5xx legacy)',
        'Plugin Kotlin lee transactionResult con fallback a resultJson',
        'Nuevo docs/GUIA_TECNICA.md con guía completa de integración',
      ],
    ),
    ChangelogEntry(
      version: '0.1.0',
      date: '2026-05-13',
      changes: <String>[
        'Plugin Flutter inicial para integración TUU vía Android Intent',
        'TuuClient.isInstalled(), isInstalledDev(), charge()',
        'Modos: production, debug, mock',
        'TuuMockSimulator opt-in via TuuMode.mock',
        '<queries> para com.haulmer.paymentapp(.dev) en el manifest del plugin',
      ],
    ),
  ];
}

/// Datos del equipo de desarrollo y de la empresa.
///
/// Se accede vía [PackageInfo.about]. Inmutable y `const`-construible.
class PackageAbout {
  /// Constructor privado: usar [PackageInfo.about].
  const PackageAbout._();

  /// Nombre de la empresa que mantiene el plugin.
  String get company => 'MUFIN SpA';

  /// País de origen.
  String get country => 'Chile';

  /// Ubicaciones físicas de la empresa.
  List<String> get locations => const <String>[
        'Villarrica',
        'Yumbel',
        'Santa Bárbara',
        'Laja',
      ];

  /// Equipo de desarrollo del plugin.
  List<Developer> get team => const <Developer>[
        Developer(
          name: 'Marco Antonio',
          role: 'Developer',
          email: 'marco@mufin.cl',
        ),
      ];

  @override
  String toString() {
    final String locs = locations.join(', ');
    final String devs =
        team.map((Developer d) => '  - ${d.name} (${d.role}) <${d.email}>').join('\n');
    return '$company — $country\n'
        'Ubicaciones: $locs\n\n'
        'Equipo:\n$devs';
  }
}

/// Miembro del equipo de desarrollo.
class Developer {
  /// Nombre completo.
  final String name;

  /// Rol en el equipo (ej. `'Developer'`, `'Tech Lead'`).
  final String role;

  /// Email de contacto.
  final String email;

  /// Crea un `Developer` inmutable.
  const Developer({
    required this.name,
    required this.role,
    required this.email,
  });

  @override
  String toString() => '$name ($role) <$email>';
}

/// Entrada del historial de cambios de una versión específica.
class ChangelogEntry {
  /// Versión del paquete (semver, ej. `'0.1.0'`).
  final String version;

  /// Fecha de release (formato `YYYY-MM-DD`).
  final String date;

  /// Lista de cambios incluidos en esta versión, en lenguaje humano.
  final List<String> changes;

  /// Crea una entrada inmutable del changelog.
  const ChangelogEntry({
    required this.version,
    required this.date,
    required this.changes,
  });

  @override
  String toString() {
    final String items = changes.map((String c) => '  - $c').join('\n');
    return '## $version ($date)\n$items';
  }
}
