import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/session/session_controller.dart';
import '../../../../core/session/session_revision.dart';
import '../../domain/models/quality_error.dart';
import '../../domain/models/report_model.dart';
import '../../domain/models/report_motive.dart';
import 'quality_repository_provider.dart';

/// Estado del envío de un reporte de material a Quality Service (Issues #406 / #407).
class MaterialReportSubmissionState {
  final bool isSubmitting;
  final Report? submittedReport;
  final String? errorMessage;
  final String? errorCode;
  final String? errorField;
  final int? statusCode;

  const MaterialReportSubmissionState({
    this.isSubmitting = false,
    this.submittedReport,
    this.errorMessage,
    this.errorCode,
    this.errorField,
    this.statusCode,
  });

  const MaterialReportSubmissionState.idle() : this();

  const MaterialReportSubmissionState.submitting()
    : this(isSubmitting: true);

  const MaterialReportSubmissionState.success(Report report)
    : this(submittedReport: report);

  const MaterialReportSubmissionState.error({
    required String message,
    String? errorCode,
    String? errorField,
    int? statusCode,
  }) : this(
         errorMessage: message,
         errorCode: errorCode,
         errorField: errorField,
         statusCode: statusCode,
       );

  bool get isIdle =>
      !isSubmitting && submittedReport == null && errorMessage == null;
  bool get isSuccess => submittedReport != null && !isSubmitting;
  bool get hasError => errorMessage != null && !isSubmitting;
  bool get requiresReauthentication =>
      hasError && (statusCode == 401 || errorCode == 'UNAUTHENTICATED');
}

/// Traduce errores de API/red durante el envío de un reporte a mensajes claros en español.
String materialReportErrorMessage(Object error) {
  if (error is DioException && error.type == DioExceptionType.cancel) {
    return 'Envío de reporte cancelado.';
  }

  QualityApiException? qualityError;
  ApiException? apiError;

  if (error is QualityApiException) {
    qualityError = error;
    apiError = error;
  } else if (error is DioException && error.error is QualityApiException) {
    qualityError = error.error as QualityApiException;
    apiError = qualityError;
  } else if (error is DioException && error.error is ApiException) {
    apiError = error.error as ApiException;
  } else if (error is ApiException) {
    apiError = error;
  }

  if (apiError == null) {
    return 'No fue posible enviar el reporte. Verifica tu conexión e intenta nuevamente.';
  }

  final serverMessage = apiError.message.trim();
  final code = qualityError?.errorCode;

  switch (apiError.statusCode) {
    case 400:
      return serverMessage.isNotEmpty
          ? serverMessage
          : 'Revisa los datos del reporte antes de enviarlo.';
    case 401:
      return 'Tu sesión expiró o no es válida. Debes iniciar sesión nuevamente para enviar el reporte.';
    case 403:
      return serverMessage.isNotEmpty
          ? serverMessage
          : 'Tu cuenta no tiene permisos para reportar este material.';
    case 404:
      return 'El material que intentas reportar ya no se encuentra disponible.';
    case 409:
      if (code == 'REPORT_ALREADY_OPEN') {
        return serverMessage.isNotEmpty
            ? serverMessage
            : 'Ya tienes un reporte abierto o en revisión para este material.';
      }
      if (code == 'IDEMPOTENCY_CONFLICT') {
        return serverMessage.isNotEmpty
            ? serverMessage
            : 'La clave de envío ya fue utilizada con datos distintos. Intenta nuevamente.';
      }
      return serverMessage.isNotEmpty
          ? serverMessage
          : 'Ya existe un reporte en curso para este material.';
    case 502:
    case 503:
      return 'El servicio de calidad no está disponible en este momento. Tus datos se conservaron para reintentar.';
    default:
      return serverMessage.isNotEmpty
          ? serverMessage
          : 'No fue posible enviar el reporte. Intenta nuevamente.';
  }
}

/// Notifier encargado de enviar reportes reales hacia Quality Service mediante Gateway (#406).
///
/// - Limpia estados previos al cambiar o cerrar sesión sin descartar el error `401`
///   cuando `SessionInterceptor` invalida la credencial durante un envío en vuelo.
/// - Ignora respuestas `401` tardías de una credencial anterior si el usuario ya inició
///   una nueva sesión válida (incluso con la misma cuenta).
/// - Impide reenviar solicitudes sin `Authorization` mientras no exista sesión activa.
class MaterialReportNotifier extends Notifier<MaterialReportSubmissionState> {
  CancelToken? _cancelToken;
  int _activeOperationId = 0;
  int? _inFlightOperationId;
  int? _submittingRevision;

  @override
  MaterialReportSubmissionState build() {
    ref.onDispose(() => _cancelToken?.cancel());

    ref.listen<int>(sessionRevisionProvider, (previous, next) {
      final currentSession = ref.read(sessionControllerProvider).current;
      final inFlightOpId = _inFlightOperationId;

      if (inFlightOpId != null) {
        // Al cambiar de sesión, el envío anterior deja de bloquear el formulario de inmediato.
        if (state.isSubmitting) {
          state = const MaterialReportSubmissionState.idle();
        }
        // Si se completó un nuevo login (incluso si devuelve el mismo JWT) o hubo más de un cambio
        // de generación (p. ej. beginLogin + cancelLogin), invalidamos la operación anterior.
        if (currentSession != null ||
            (_submittingRevision != null && next > _submittingRevision! + 1)) {
          if (_activeOperationId == inFlightOpId) {
            ++_activeOperationId;
          }
          _inFlightOperationId = null;
          _submittingRevision = null;
        }
        return;
      }

      // Si no hay envío en curso y se inicia una sesión válida (por ejemplo, tras reautenticarse
      // luego de un 401), limpiamos el bloqueo/error de sesión para permitir reenviar.
      if (state.isSuccess || currentSession != null) {
        state = const MaterialReportSubmissionState.idle();
      }
    });

    return const MaterialReportSubmissionState.idle();
  }

  /// Envía un reporte para [materialId] con el [motive] y [details] indicados.
  ///
  /// Retorna el [Report] confirmado por el servidor o `null` si fue rechazado o falló la red.
  Future<Report?> submit({
    required String materialId,
    required ReportMotive motive,
    String? details,
    String? idempotencyKey,
  }) async {
    if (state.isSubmitting) return null;

    final currentSession = ref.read(sessionControllerProvider).current;
    if (currentSession == null) {
      state = const MaterialReportSubmissionState.error(
        message:
            'Tu sesión expiró o no es válida. Debes iniciar sesión nuevamente para enviar el reporte.',
        errorCode: 'UNAUTHENTICATED',
        statusCode: 401,
      );
      return null;
    }

    final trimmedDetails = details?.trim();
    if (motive.requiresDetails &&
        (trimmedDetails == null || trimmedDetails.isEmpty)) {
      state = const MaterialReportSubmissionState.error(
        message:
            'Debes especificar los detalles cuando seleccionas "Otro motivo".',
        errorCode: 'VALIDATION_ERROR',
        errorField: 'details',
        statusCode: 400,
      );
      return null;
    }

    if (trimmedDetails != null && trimmedDetails.length > 2000) {
      state = const MaterialReportSubmissionState.error(
        message: 'El detalle no puede superar los 2000 caracteres.',
        errorCode: 'VALIDATION_ERROR',
        errorField: 'details',
        statusCode: 400,
      );
      return null;
    }

    final operationId = ++_activeOperationId;
    final revision = ref.read(sessionRevisionProvider);
    final submittingUserId = currentSession.user.id;
    final submittingToken = currentSession.accessToken;
    _inFlightOperationId = operationId;
    _submittingRevision = revision;
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    state = const MaterialReportSubmissionState.submitting();

    try {
      final repository = ref.read(qualityRepositoryProvider);
      final report = await repository.createReport(
        materialId,
        motive.toReportCreate(trimmedDetails),
        idempotencyKey: idempotencyKey,
        cancelToken: cancelToken,
      );
      if (!ref.mounted || _activeOperationId != operationId) return null;

      final activeSession = ref.read(sessionControllerProvider).current;
      if (ref.read(sessionRevisionProvider) != revision ||
          activeSession?.user.id != submittingUserId ||
          activeSession?.accessToken != submittingToken) {
        return null;
      }

      state = MaterialReportSubmissionState.success(report);
      return report;
    } catch (error) {
      if (!ref.mounted || _activeOperationId != operationId) return null;

      QualityApiException? qualityErr;
      ApiException? apiErr;
      if (error is QualityApiException) {
        qualityErr = error;
        apiErr = error;
      } else if (error is DioException && error.error is QualityApiException) {
        qualityErr = error.error as QualityApiException;
        apiErr = qualityErr;
      } else if (error is DioException && error.error is ApiException) {
        apiErr = error.error as ApiException;
      } else if (error is ApiException) {
        apiErr = error;
      }

      final activeSession = ref.read(sessionControllerProvider).current;
      final currentRevision = ref.read(sessionRevisionProvider);
      final isUnauthorizedError = apiErr?.statusCode == 401;

      if (isUnauthorizedError) {
        // Si ya existe una sesión nueva válida (incluso para la misma cuenta)
        // o hubo un ciclo posterior de login (como un login cancelado), este 401 tardío se ignora.
        if (activeSession != null || currentRevision > revision + 1) {
          return null;
        }
      } else {
        if (currentRevision != revision ||
            activeSession?.user.id != submittingUserId ||
            activeSession?.accessToken != submittingToken) {
          return null;
        }
      }

      state = MaterialReportSubmissionState.error(
        message: materialReportErrorMessage(error),
        errorCode:
            qualityErr?.errorCode ??
            (isUnauthorizedError ? 'UNAUTHENTICATED' : null),
        errorField: qualityErr?.field,
        statusCode: apiErr?.statusCode,
      );
      return null;
    } finally {
      if (identical(_cancelToken, cancelToken)) {
        _cancelToken = null;
      }
      if (_inFlightOperationId == operationId) {
        _inFlightOperationId = null;
      }
      if (_activeOperationId == operationId) {
        _submittingRevision = null;
      }
    }
  }

  void cancel() {
    _cancelToken?.cancel();
  }

  void reset() {
    _cancelToken?.cancel();
    _cancelToken = null;
    state = const MaterialReportSubmissionState.idle();
  }
}

/// Provider aislado por `materialId` para el envío de reportes a Quality Service.
final materialReportProvider =
    NotifierProvider.family<
      MaterialReportNotifier,
      MaterialReportSubmissionState,
      String
    >((_) => MaterialReportNotifier());
