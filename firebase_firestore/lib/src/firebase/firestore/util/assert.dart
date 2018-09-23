// File created by
// Lung Razvan <long1eu>
// on 17/09/2018

/// A helper class to provide static runtime assertion helpers.
class Assert {
  /// Triggers a hard assertion. The condition is guaranteed to be checked at runtime. If the
  /// condition is false an AssertionError will be thrown.
  static void hardAssert(bool condition, String message) {
    if (!condition) {
      throw fail(message);
    }
  }

  /// Throws an AssertionError with the provided message. The method returns an
  /// AssertionError so it can be used with a throw statement. However, the
  /// method itself throws an AssertionError so fail will not accidentally be
  /// silent if the throw is forgotten.
  static AssertionError fail(String message, [Error cause]) {
    throw AssertionError('$message ${cause != null ? 'cause: $cause' : ''}');
  }

  static T checkNotNull<T>(T reference, [Object errorMessage]) {
    if (reference == null) {
      throw new ArgumentError.notNull(errorMessage);
    }
    return reference;
  }

  /**
   * Ensures the truth of an expression involving one or more parameters to the calling method.
   *
   * @param expression a boolean expression
   * @param errorMessage the exception message to use if the check fails; will be converted to a
   *     string using {@link String#valueOf(Object)}
   * @throws IllegalArgumentException if {@code expression} is false
   */
  static void checkArgument(bool expression, Object errorMessage) {
    if (!expression) {
      throw new ArgumentError(errorMessage);
    }
  }
}
