import 'dart:developer' as developer;

/// Receives SDK log records in place of `dart:developer` logging.
///
/// [level] is one of `debug`, `info`, `warn` or `error`; [error] is the
/// associated error, if any.
typedef LoggerSink = void Function(String level, String message, Object? error);

class AdPlugaLogger {
  AdPlugaLogger._();
  bool enabled = false;
  LoggerSink? sink;

  void debug(String message) {
    if (!enabled) return;
    _emit('debug', message, null);
  }

  void info(String message) {
    if (!enabled) return;
    _emit('info', message, null);
  }

  void warn(String message, [Object? error]) {
    if (!enabled) return;
    _emit('warn', message, error);
  }

  void error(String message, [Object? error]) {
    _emit('error', message, error);
  }

  void _emit(String level, String message, Object? error) {
    final s = sink;
    if (s != null) {
      s(level, message, error);
      return;
    }
    developer.log('[adpluga] $message',
        level: _levelValue(level), error: error);
  }

  int _levelValue(String level) {
    switch (level) {
      case 'debug':
        return 500;
      case 'info':
        return 800;
      case 'warn':
        return 900;
      case 'error':
        return 1000;
      default:
        return 800;
    }
  }
}

final AdPlugaLogger logger = AdPlugaLogger._();

/// Turns debug, info and warning logs on or off. Errors are always logged.
/// Logging is off by default.
void setLoggerEnabled(bool value) {
  logger.enabled = value;
}

/// Routes SDK logs to [value] instead of `dart:developer`. Pass null to
/// restore the default.
void setLoggerSink(LoggerSink? value) {
  logger.sink = value;
}
