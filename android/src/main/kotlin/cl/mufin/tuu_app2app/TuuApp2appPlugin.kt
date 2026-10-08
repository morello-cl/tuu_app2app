package cl.mufin.tuu_app2app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry

/**
 * Plugin nativo de `tuu_app2app`.
 *
 * Implementa la pieza Android del puente Flutter ↔ app TUU. Es el único
 * componente del plugin que toca APIs de Android directamente.
 *
 * ## Métodos expuestos por el `MethodChannel`
 *
 *  - `isInstalled(packageName: String): Boolean` — devuelve `true` si el
 *    package indicado tiene un launch intent disponible. Nunca lanza al
 *    lado Dart.
 *
 *  - `charge(packageName: String, json: String): String?` — lanza un
 *    [Intent.ACTION_SEND] con el `json` como `Intent.EXTRA_TEXT` y
 *    suspende hasta que la app TUU termine. Devuelve el String que TUU
 *    escribió en `Intent.data` (primero intenta el extra
 *    `transactionResult` per doc oficial; cae a `resultJson` para
 *    compatibilidad con versiones antiguas).
 *
 * ## Lifecycle y concurrencia
 *
 *  - Se attachea como [ActivityAware] para poder llamar
 *    `startActivityForResult`. Si se invoca `charge` sin actividad
 *    attach devuelve error `MFN-03`.
 *  - Mantiene un único `pendingResult`: un segundo `charge` mientras hay
 *    uno en curso recibe `MFN-05`.
 *  - Se registra como [PluginRegistry.ActivityResultListener] en cada
 *    attach (incluyendo `onReattachedToActivityForConfigChanges`).
 *
 * ## Códigos de error
 *
 *  - `MFN-01` — `packageName` faltante.
 *  - `MFN-02` — `json` faltante.
 *  - `MFN-03` — plugin sin actividad attach.
 *  - `MFN-04` — app TUU no instalada.
 *  - `MFN-05` — otra carga en curso.
 *  - `MFN-06` — falla al lanzar el Intent.
 */
class TuuApp2appPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware,
    PluginRegistry.ActivityResultListener {

    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var pendingResult: Result? = null

    /**
     * Dónde sobrevive un cobro cuando el proceso no.
     *
     * [pendingResult] vive en memoria: si Android mata la app mientras TUU está
     * en pantalla —cosa que pasa seguido en un POS con poca RAM— se pierde, y
     * al reentregarse el resultado no hay a quién dárselo. Antes eso terminaba
     * en un cobro aprobado que la app nunca se enteró de que ocurrió.
     */
    private var prefs: SharedPreferences? = null

    // ── FlutterPlugin ──────────────────────────────────────────────────

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        prefs = binding.applicationContext
            .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    // ── ActivityAware ──────────────────────────────────────────────────

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    // ── MethodCallHandler ──────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            METHOD_IS_INSTALLED -> handleIsInstalled(call, result)
            METHOD_CHARGE -> handleCharge(call, result)
            METHOD_PENDING_CHARGE -> handlePendingCharge(result)
            METHOD_CLEAR_PENDING -> {
                limpiarPendiente()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Devuelve el cobro que quedó sin resolver, o `null` si no hay ninguno.
     *
     * Dos formas de quedar sin resolver, y la App las distingue por si hay
     * `result`:
     *
     *  - **Con `result`**: TUU respondió pero el proceso había muerto, así que
     *    nadie recibió la respuesta. El cobro se hizo y hay que registrarlo.
     *  - **Sin `result`**: se lanzó el Intent y no se supo más. Puede que se
     *    haya cobrado o puede que no; eso lo resuelve quien llama, porque
     *    desde acá no hay forma de preguntarle a TUU.
     */
    private fun handlePendingCharge(result: Result) {
        val p = prefs
        if (p == null) {
            result.success(null)
            return
        }
        val request = p.getString(KEY_REQUEST, null)
        val stored = p.getString(KEY_RESULT, null)
        if (request == null && stored == null) {
            result.success(null)
            return
        }
        result.success(
            mapOf(
                "request" to request,
                "result" to stored,
                "startedAt" to p.getLong(KEY_STARTED_AT, 0L),
            ),
        )
    }

    private fun handleIsInstalled(call: MethodCall, result: Result) {
        val pkg = call.argument<String>("packageName")
        if (pkg.isNullOrEmpty()) {
            result.error(ERR_MISSING_PACKAGE, "packageName required", null)
            return
        }
        result.success(isPackageInstalled(pkg))
    }

    private fun handleCharge(call: MethodCall, result: Result) {
        val pkg = call.argument<String>("packageName")
        val jsonBody = call.argument<String>("json")

        if (pkg.isNullOrEmpty()) {
            result.error(ERR_MISSING_PACKAGE, "packageName required", null)
            return
        }
        if (jsonBody.isNullOrEmpty()) {
            result.error(ERR_MISSING_JSON, "json required", null)
            return
        }
        launchCharge(pkg, jsonBody, result)
    }

    // ── Helpers ────────────────────────────────────────────────────────

    /**
     * `true` si [pkg] tiene un launch intent disponible. Cualquier
     * excepción del [PackageManager] se interpreta como "no disponible".
     */
    private fun isPackageInstalled(pkg: String): Boolean {
        val pm = activity?.packageManager ?: return false
        return try {
            pm.getLaunchIntentForPackage(pkg) != null
        } catch (e: PackageManager.NameNotFoundException) {
            false
        } catch (e: Throwable) {
            false
        }
    }

    /**
     * Lanza el Intent de cobro contra [pkg] con [jsonBody] como
     * `EXTRA_TEXT`. Guarda el [result] en `pendingResult` para completarlo
     * en `onActivityResult`.
     */
    private fun launchCharge(pkg: String, jsonBody: String, result: Result) {
        val act = activity
        if (act == null) {
            result.error(ERR_NO_ACTIVITY, "Plugin not attached to an activity", null)
            return
        }

        if (pendingResult != null) {
            result.error(
                ERR_IN_PROGRESS,
                "Another TUU charge is already in progress",
                null,
            )
            return
        }

        val intent = act.packageManager.getLaunchIntentForPackage(pkg)
        if (intent == null) {
            result.error(ERR_NOT_INSTALLED, "TUU app '$pkg' not installed", null)
            return
        }

        intent.action = Intent.ACTION_SEND
        intent.putExtra(Intent.EXTRA_TEXT, jsonBody)
        intent.type = "text/json"
        intent.flags = 0

        pendingResult = result
        // Se deja anotado ANTES de lanzar: si el proceso muere mientras TUU
        // está en pantalla, esto es lo único que queda para saber que hubo un
        // cobro en vuelo.
        prefs?.edit()
            ?.putString(KEY_REQUEST, jsonBody)
            ?.putLong(KEY_STARTED_AT, System.currentTimeMillis())
            ?.remove(KEY_RESULT)
            ?.apply()
        try {
            act.startActivityForResult(intent, INTENT_RESPONSE_ID)
        } catch (e: Throwable) {
            pendingResult = null
            prefs?.edit()?.remove(KEY_REQUEST)?.remove(KEY_STARTED_AT)?.apply()
            result.error(ERR_LAUNCH_FAILED, e.message ?: "Failed to start TUU app", null)
        }
    }

    // ── ActivityResultListener ─────────────────────────────────────────

    /**
     * Extrae el JSON de la respuesta de TUU.
     *
     * Estrategia (doble lectura por compatibilidad):
     *  1. `EXTRA_TRANSACTION_RESULT` (`transactionResult`) — clave oficial
     *     según la doc actual de TUU en developers.tuu.cl.
     *  2. `EXTRA_RESULT_JSON_LEGACY` (`resultJson`) — clave usada por
     *     versiones antiguas de la app TUU y por la integración legacy
     *     en DTEx.
     *
     * Devuelve `null` si ninguna está presente (gesto back).
     */
    private fun extractResultJson(data: Intent?): String? {
        if (data == null) return null
        return data.getStringExtra(EXTRA_TRANSACTION_RESULT)
            ?: data.getStringExtra(EXTRA_RESULT_JSON_LEGACY)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != INTENT_RESPONSE_ID) return false

        val json = when (resultCode) {
            Activity.RESULT_OK, Activity.RESULT_CANCELED -> extractResultJson(data)
            // Códigos inesperados → tratamos como sin respuesta.
            else -> null
        }

        // Se guarda ANTES de entregarlo y pase lo que pase con `pendingResult`.
        //
        // Acá es donde se perdía el cobro: si Android mató el proceso mientras
        // TUU cobraba, al recrear la actividad reentrega el resultado pero
        // `pendingResult` vale null —vive en memoria—, así que un cobro
        // aprobado se descartaba en silencio y la app nunca se enteraba.
        // Guardarlo primero lo deja disponible para `pendingCharge` cuando
        // Dart vuelva a arrancar.
        if (json != null) {
            prefs?.edit()?.putString(KEY_RESULT, json)?.apply()
        } else {
            // Sin respuesta tampoco hay cobro en vuelo que reportar: fue un
            // back del operador o un código que no entendemos.
            limpiarPendiente()
        }

        val res = pendingResult
        pendingResult = null
        // Sin `pendingResult` el proceso murió y volvió: el resultado ya quedó
        // guardado y lo recoge Dart al arrancar.
        if (res == null) return true

        // Entregado en caliente: ya no hace falta conservarlo.
        limpiarPendiente()
        res.success(json)
        return true
    }

    /** Borra el rastro del cobro: ni en vuelo ni con resultado por entregar. */
    private fun limpiarPendiente() {
        prefs?.edit()
            ?.remove(KEY_REQUEST)
            ?.remove(KEY_STARTED_AT)
            ?.remove(KEY_RESULT)
            ?.apply()
    }

    companion object {
        /** Debe coincidir con [tuuMethodChannelName] en Dart. */
        private const val CHANNEL_NAME = "cl.mufin.tuu_app2app"

        /**
         * Request code para `startActivityForResult`. Conservado desde
         * la integración legacy en DTEx para mantener compatibilidad.
         */
        private const val INTENT_RESPONSE_ID = 9378

        // Métodos.
        private const val METHOD_IS_INSTALLED = "isInstalled"
        private const val METHOD_CHARGE = "charge"
        private const val METHOD_PENDING_CHARGE = "pendingCharge"
        private const val METHOD_CLEAR_PENDING = "clearPending"

        /** Dónde sobrevive un cobro a la muerte del proceso. */
        private const val PREFS_NAME = "cl.mufin.tuu_app2app.pending"
        private const val KEY_REQUEST = "request"
        private const val KEY_STARTED_AT = "startedAt"
        private const val KEY_RESULT = "result"

        // Extras del Intent de respuesta.
        private const val EXTRA_TRANSACTION_RESULT = "transactionResult"
        private const val EXTRA_RESULT_JSON_LEGACY = "resultJson"

        // Códigos de error.
        private const val ERR_MISSING_PACKAGE = "MFN-01"
        private const val ERR_MISSING_JSON = "MFN-02"
        private const val ERR_NO_ACTIVITY = "MFN-03"
        private const val ERR_NOT_INSTALLED = "MFN-04"
        private const val ERR_IN_PROGRESS = "MFN-05"
        private const val ERR_LAUNCH_FAILED = "MFN-06"
    }
}
