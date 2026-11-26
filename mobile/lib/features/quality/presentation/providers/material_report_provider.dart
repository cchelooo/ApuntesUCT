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
/// - Evita solicitudes duplicadas mientras un envío está en curso.
/// - Conserva los errores tipados (`errorCode`, `errorField`, `statusCode`) sin simular éxitos locales.
class MaterialReportNotifier extends Notifier<MaterialReportSubmissionState> {
  CancelToken? _cancelToken;
  String? _submittingUserId;

  @override
  MaterialReportSubmissionState build() {
    ref.onDispose(() => _cancelToken?.cancel());

    ref.listen<int>(sessionRevisionProvider, (previous, next) {
      final currentUserId = ref.read(sessionControllerProvider).current?.user.id;
      if (state.isSubmitting) {
        // Si durante un envío en curso se inicia sesión con otra cuenta distinta,
        // cancelamos la petición anterior y limpiamos el estado.
        // Si currentUserId pasa a null (p. ej. por un 401 interceptado en esta misma petición),
        // permitimos que el bloque catch de submit() procese el error 401 y lo muestre al usuario.
        if (currentUserId != null && currentUserId != _submittingUserId) {
          _cancelToken?.cancel();
          _cancelToken = null;
          state = const MaterialReportSubmissionState.idle();
        }
        return;
      }

      // Si no hay envío en curso y cambia la sesión, limpiamos reportes confirmados
      // o errores previos al iniciar una nueva sesión.
      if (state.isSuccess || currentUserId != null) {
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

    final trimmedDetails = details?.trim();
    if (motive.requiresDetails &&
        (trimmedDetails == null || trimmedDetails.isEmpty)) {
      state = const MaterialReportSubmissionState.error(
        message: 'Debes especificar los detalles cuando seleccionas "Otro motivo".',
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

    final revision = ref.read(sessionRevisionProvider);
    final submittingUserId = ref.read(sessionControllerProvider).current?.user.id;
    _submittingUserId = submittingUserId;
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
      if (!ref.mounted) return null;

      final currentUserId = ref.read(sessionControllerProvider).current?.user.id;
      if (ref.read(sessionRevisionProvider) != revision ||
          currentUserId != submittingUserId) {
        state = const MaterialReportSubmissionState.idle();
        return null;
      }

      state = MaterialReportSubmissionState.success(report);
      return report;
    } catch (error) {
      if (!ref.mounted) return null;

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

      final currentUserId = ref.read(sessionControllerProvider).current?.user.id;
      final isUnauthorizedError = apiErr?.statusCode == 401;

      // Si la sesión cambió a otro usuario distinto, descartamos el resultado tardío.
      // Pero si fue un 401 que limpió la sesión actual (currentUserId == null),
      // conservamos y mostramos el mensaje indicando que debe iniciar sesión nuevamente.
      if (!isUnauthorizedError &&
          (ref.read(sessionRevisionProvider) != revision ||
              currentUserId != submittingUserId)) {
        state = const MaterialReportSubmissionState.idle();
        return null;
      }
      if (isUnauthorizedError &&
          currentUserId != null &&
          currentUserId != submittingUserId) {
        state = const MaterialReportSubmissionState.idle();
        return null;
      }

      state = MaterialReportSubmissionState.error(
        message: materialReportErrorMessage(error),
        errorCode:
            qualityErr?.errorCode ?? (isUnauthorizedError ? 'UNAUTHENTICATED' : null),
        errorField: qualityErr?.field,
        statusCode: apiErr?.statusCode,
      );
      return null;
    } finally {
      if (identical(_cancelToken, cancelToken)) {
        _cancelToken = null;
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
