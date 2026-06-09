import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class ScanLimitService {
  static const int scanLimit = 3;
  static const String _scanCountKey = 'scan_limit_count';
  static const String _scanDateKey = 'scan_limit_date';

  Future<int> getScanCount() async {
    final prefs = await SharedPreferences.getInstance();
    await _refreshDailyCount(prefs);
    return prefs.getInt(_scanCountKey) ?? 0;
  }

  Future<int> remainingScans() async {
    final count = await getScanCount();
    return max(0, scanLimit - count);
  }

  Future<bool> canScan() async {
    final count = await getScanCount();
    return count < scanLimit;
  }

  Future<int> recordScan() async {
    final prefs = await SharedPreferences.getInstance();
    await _refreshDailyCount(prefs);
    final current = prefs.getInt(_scanCountKey) ?? 0;
    final next = current + 1;
    await prefs.setInt(_scanCountKey, next);
    await prefs.setString(_scanDateKey, _todayKey());
    return next;
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_scanCountKey);
    await prefs.remove(_scanDateKey);
  }

  Future<void> _refreshDailyCount(SharedPreferences prefs) async {
    final today = _todayKey();
    final savedDate = prefs.getString(_scanDateKey);
    if (savedDate == today) {
      return;
    }

    await prefs.setInt(_scanCountKey, 0);
    await prefs.setString(_scanDateKey, today);
  }

  String _todayKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }
}
