// lib/utils/api_rate_limiter.dart
// Simple token bucket rate limiter for API calls.

class ApiRateLimiter {
  final int maxCallsPerMinute;
  final List<DateTime> _callTimestamps = [];

  ApiRateLimiter({this.maxCallsPerMinute = 30});

  bool tryAcquire() {
    final now = DateTime.now();
    // Remove timestamps older than a minute.
    _callTimestamps.removeWhere((t) => now.difference(t).inSeconds >= 60);
    if (_callTimestamps.length < maxCallsPerMinute) {
      _callTimestamps.add(now);
      return true;
    }
    return false;
  }

  // Await until a token is available.
  Future<void> acquire() async {
    while (!tryAcquire()) {
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }
}
