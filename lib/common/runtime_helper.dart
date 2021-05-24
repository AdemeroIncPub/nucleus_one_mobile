/// Attempt cast to different type, return default value on failure.
/// In Dart [as] throws error on cast failure instead of returning null as in other languages.
T tryCast<T>(dynamic x, T fallback) => x is T ? x : fallback;