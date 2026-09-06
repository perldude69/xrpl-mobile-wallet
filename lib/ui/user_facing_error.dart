/// Converts unexpected failures into text safe to show in the UI.
String userFacingError(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  return fallback;
}
