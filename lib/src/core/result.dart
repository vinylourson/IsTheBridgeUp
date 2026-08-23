/// Minimal success-or-failure wrapper, so the data layer can report problems
/// without every caller wrapping things in try/catch.
sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok<T>;
  const factory Result.failed(Object error) = Failed<T>;

  T? get valueOrNull => switch (this) {
    Ok<T>(:final T value) => value,
    Failed<T>() => null,
  };

  bool get isOk => this is Ok<T>;
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Failed<T> extends Result<T> {
  const Failed(this.error);
  final Object error;
}

/// Something went wrong talking to the open-data API.
class ChabanApiException implements Exception {
  const ChabanApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => statusCode == null
      ? 'ChabanApiException: $message'
      : 'ChabanApiException($statusCode): $message';
}
