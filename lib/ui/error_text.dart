import '../api/models.dart';
import '../l10n/app_localizations.dart';
import '../services/image_service.dart';
import '../services/settings_store.dart';

/// Turns the errors thrown by the API client and services into a translated
/// message. All expected error types are handled explicitly; anything else
/// falls back to [Object.toString].
String errorText(AppLocalizations l10n, Object error) => switch (error) {
  ImageUploadException() => l10n.errorImageUpload(
    error.number,
    error.total,
    errorText(l10n, error.cause),
  ),
  JoomlaApiException() => _apiErrorText(l10n, error),
  ImageProcessingException() => switch (error.kind) {
    ImageErrorKind.unsupportedType => l10n.errorImageUnsupported(
      error.fileName,
    ),
    ImageErrorKind.tooLarge => l10n.errorImageTooLarge(error.fileName),
    ImageErrorKind.unreadable => l10n.errorImageUnreadable(error.fileName),
  },
  TokenStoreException() => l10n.errorKeyring,
  _ => error.toString(),
};

String _apiErrorText(AppLocalizations l10n, JoomlaApiException error) {
  final status = error.statusCode ?? 0;
  final message = switch (error.kind) {
    ApiErrorKind.network => l10n.errorNetwork,
    ApiErrorKind.timeout => l10n.errorTimeout,
    ApiErrorKind.unexpectedResponse => l10n.errorUnexpectedResponse,
    ApiErrorKind.noMediaAdapters => l10n.errorNoMediaAdapters,
    ApiErrorKind.unauthorized => l10n.errorUnauthorized,
    ApiErrorKind.forbidden => l10n.errorForbidden,
    ApiErrorKind.notFound => l10n.errorNotFound,
    ApiErrorKind.conflict => l10n.errorConflict,
    ApiErrorKind.tooLarge => l10n.errorTooLarge,
    ApiErrorKind.serverError => l10n.errorServer(status),
    ApiErrorKind.requestFailed => l10n.errorRequestFailed(status),
  };
  final detail = error.detail;
  return detail == null || detail.isEmpty
      ? message
      : l10n.errorWithDetail(message, detail);
}

String siteUrlErrorText(AppLocalizations l10n, SiteUrlError error) =>
    switch (error) {
      SiteUrlError.empty => l10n.urlEmpty,
      SiteUrlError.notAbsolute => l10n.urlNotAbsolute,
      SiteUrlError.hasExtras => l10n.urlHasExtras,
      SiteUrlError.notHttps => l10n.urlNotHttps,
    };
