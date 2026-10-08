import 'package:flutter/services.dart';

/// Nombre del [MethodChannel] que expone el plugin nativo Kotlin.
///
/// Debe coincidir exactamente con `CHANNEL_NAME` en `TuuApp2appPlugin.kt`.
/// Lo exponemos como constante para que tests / consumidores avanzados
/// puedan inyectar un `MethodChannel` con el mismo nombre.
const String tuuMethodChannelName = 'cl.mufin.tuu_app2app';

/// Wrapper Dart del [MethodChannel] del plugin nativo.
///
/// Encapsula los dos métodos expuestos por la capa Kotlin: `isInstalled`
/// y `charge`. Es deliberadamente "tonto" — no hace logging, no mapea
/// errores a [TuuException] y no parsea JSON. Toda esa lógica vive en
/// [TuuClient]; este wrapper sólo:
///
///  - Encapsula los nombres de método y de argumento.
///  - Permite inyectar un [MethodChannel] en tests (pasándolo al
///    constructor) sin modificar el código de producción.
///  - Atrapa [PlatformException] en `isInstalled` para devolver `false`,
///    porque ese método nunca debe lanzar al consumidor: una app no
///    instalada no es un error.
class TuuMethodChannel {
  /// `MethodChannel` subyacente. Si el constructor no recibe uno, se crea
  /// con [tuuMethodChannelName].
  final MethodChannel _channel;

  /// Crea un wrapper. Pasar [channel] para inyectar un mock en tests.
  TuuMethodChannel({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(tuuMethodChannelName);

  /// Verifica si [packageName] tiene un launch intent disponible en este
  /// dispositivo (es decir, si la app TUU correspondiente está instalada).
  ///
  /// Atrapa [PlatformException] internamente y devuelve `false` — el caso
  /// "no instalada" es información, no un error. Si la app está instalada
  /// devuelve `true`.
  Future<bool> isInstalled(String packageName) async {
    try {
      final bool? result = await _channel.invokeMethod<bool>(
        'isInstalled',
        <String, Object?>{'packageName': packageName},
      );
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Dispara el Intent de cobro contra [packageName] con el [jsonBody]
  /// serializado y suspende hasta que la app TUU responda.
  ///
  /// Devuelve el String que TUU dejó en `Intent.data.resultJson` (JSON
  /// crudo de éxito o error), o `null` si el usuario canceló sin que la
  /// app devolviera nada (gesto back con `RESULT_CANCELED` y `data == null`).
  ///
  /// Propaga [PlatformException] tal cual para errores duros: app no
  /// instalada, otra carga en curso, fallo al lanzar el Intent, etc.
  /// [TuuClient] es responsable de mapear estos códigos a [TuuException].
  /// Pide el cobro que quedó sin resolver tras la muerte del proceso.
  ///
  /// Devuelve `null` si no hay ninguno.
  Future<Map<dynamic, dynamic>?> pendingCharge() async {
    return await _channel.invokeMethod<Map<dynamic, dynamic>>('pendingCharge');
  }

  /// Da por resuelto el cobro pendiente y borra su rastro.
  Future<void> clearPending() async {
    await _channel.invokeMethod<void>('clearPending');
  }

  Future<String?> charge({
    required String packageName,
    required String jsonBody,
  }) async {
    return await _channel.invokeMethod<String>(
      'charge',
      <String, Object?>{
        'packageName': packageName,
        'json': jsonBody,
      },
    );
  }
}
