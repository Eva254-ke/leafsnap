import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

import 'perenual_api.dart';
import 'weather_service.dart';

class CareRecommendation {
  final String category;
  final String title;
  final String instruction;
  final String reasoning;
  final CareUrgency urgency;
  final List<String> actionSteps;
  final String? nextCheckDate;

  const CareRecommendation({
    required this.category,
    required this.title,
    required this.instruction,
    required this.reasoning,
    required this.urgency,
    required this.actionSteps,
    this.nextCheckDate,
  });
}

enum CareUrgency { low, medium, high, urgent }

class SeasonalProfile {
  final bool isGrowingSeason;
  final bool isDormant;
  final double lightHours;
  final TemperatureRange tempRange;
  final String primaryConcerns;

  const SeasonalProfile({
    required this.isGrowingSeason,
    required this.isDormant,
    required this.lightHours,
    required this.tempRange,
    required this.primaryConcerns,
  });
}

class TemperatureRange {
  final double min;
  final double max;
  final String unit;

  const TemperatureRange({
    required this.min,
    required this.max,
    this.unit = 'C',
  });
}

class SmartCareService {
  SmartCareService._();
  static final SmartCareService instance = SmartCareService._();

  /// Generates dynamic care recommendations based on the fetched Perenual API data.
  Future<List<CareRecommendation>> getCareRecommendations({
    required String plantName,
    required String scientificName,
    required List<PerenualCareSection> careGuides, // Pass the real API data here!
    Position? location,
    WeatherSnapshot? weather,
  }) async {
    final now = DateTime.now();
    final season = _getCurrentSeason(now, location?.latitude);
    final seasonalProfile = _getSeasonalProfile(season, now);
    
    final recommendations = <CareRecommendation>[];

    // 1. Weather-based recommendations (General plant stress thresholds)
    if (weather != null && location != null) {
      recommendations.addAll(_getWeatherBasedCare(weather, seasonalProfile));
    }

    // 2. Dynamic Care Recommendations based on the specific plant's API data
    recommendations.addAll(_getDynamicCare(careGuides, seasonalProfile, now));

    // Sort by urgency (Urgent -> High -> Medium -> Low)
    recommendations.sort((a, b) => b.urgency.index.compareTo(a.urgency.index));

    return recommendations.take(6).toList();
  }

  /// Generates recommendations based on extreme weather conditions
  List<CareRecommendation> _getWeatherBasedCare(
    WeatherSnapshot weather,
    SeasonalProfile seasonal,
  ) {
    final recommendations = <CareRecommendation>[];
    final temp = weather.currentTempC;
    final humidity = weather.humidity;

    // Heat stress (Null-safe)
    if (temp != null && temp > 30) {
      recommendations.add(CareRecommendation(
        category: 'Temperature',
        title: 'Heat stress protection needed',
        instruction: 'Move to cooler spot or add shade protection',
        reasoning: 'Current ${temp.round()}°C is very high and may cause heat stress.',
        urgency: temp > 35 ? CareUrgency.urgent : CareUrgency.high,
        actionSteps: [
          'Move plant to shadier location during hottest hours (11am-3pm)',
          'Increase humidity around plant with water tray',
          'Check soil moisture more frequently - may need daily watering',
          'Watch for wilting, leaf scorch, or dropping',
        ],
        nextCheckDate: _formatDate(DateTime.now().add(const Duration(days: 1))),
      ));
    } 
    // Cold stress (Null-safe)
    else if (temp != null && temp < 5) {
      recommendations.add(CareRecommendation(
        category: 'Temperature',
        title: 'Cold protection required',
        instruction: 'Bring indoors or add frost protection',
        reasoning: 'Current ${temp.round()}°C is very low and may cause frost damage.',
        urgency: temp < 0 ? CareUrgency.urgent : CareUrgency.high,
        actionSteps: [
          'Move plant indoors if possible',
          'Cover with frost cloth or blankets overnight',
          'Reduce watering - cold plants need less water',
          'Check for frost damage on leaves and stems',
        ],
        nextCheckDate: _formatDate(DateTime.now().add(const Duration(days: 1))),
      ));
    }

    // Low humidity (Null-safe)
    if (humidity != null && humidity < 30) {
      recommendations.add(CareRecommendation(
        category: 'Humidity',
        title: 'Low humidity detected',
        instruction: 'Increase local humidity around plant',
        reasoning: 'Current ${humidity.round()}% humidity is quite low for most plants.',
        urgency: CareUrgency.medium,
        actionSteps: [
          'Place water-filled pebble tray under pot',
          'Group plants together to create microclimate',
          'Mist air around plant (not leaves) in morning',
          'Consider a small humidifier nearby',
        ],
        nextCheckDate: _formatDate(DateTime.now().add(const Duration(days: 3))),
      ));
    }

    return recommendations;
  }

  /// Generates recommendations dynamically from the Perenual API care guides
  List<CareRecommendation> _getDynamicCare(
    List<PerenualCareSection> careGuides,
    SeasonalProfile seasonal,
    DateTime now,
  ) {
    final recommendations = <CareRecommendation>[];

    for (final guide in careGuides) {
      final type = guide.type.toLowerCase();
      final description = guide.description;
      
      if (description.trim().isEmpty) continue;

      if (type.contains('water')) {
        recommendations.add(CareRecommendation(
          category: 'Watering',
          title: 'Watering Guidelines',
          instruction: _extractInstruction(description),
          reasoning: description,
          urgency: seasonal.isDormant ? CareUrgency.medium : CareUrgency.high,
          actionSteps: _extractActionSteps(description),
          nextCheckDate: _formatDate(now.add(const Duration(days: 7))),
        ));
      } else if (type.contains('sun') || type.contains('light')) {
        recommendations.add(CareRecommendation(
          category: 'Light',
          title: 'Light Requirements',
          instruction: _extractInstruction(description),
          reasoning: description,
          urgency: CareUrgency.medium,
          actionSteps: _extractActionSteps(description),
          nextCheckDate: _formatDate(now.add(const Duration(days: 14))),
        ));
      } else if (type.contains('fertil')) {
        recommendations.add(CareRecommendation(
          category: 'Fertilizing',
          title: 'Feeding Schedule',
          instruction: _extractInstruction(description),
          reasoning: description,
          urgency: seasonal.isGrowingSeason ? CareUrgency.medium : CareUrgency.low,
          actionSteps: _extractActionSteps(description),
          nextCheckDate: _formatDate(now.add(const Duration(days: 30))),
        ));
      }
    }

    // Fallback if the API didn't return any care guides for this plant
    if (careGuides.isEmpty) {
      recommendations.add(CareRecommendation(
        category: 'General Care',
        title: 'Standard Care Routine',
        instruction: 'Water when the top inch of soil is dry and provide bright, indirect light.',
        reasoning: 'Specific care data is unavailable, so follow general plant care practices.',
        urgency: CareUrgency.medium,
        actionSteps: [
          'Check soil moisture before watering',
          'Ensure proper drainage',
          'Rotate plant for even growth',
        ],
        nextCheckDate: _formatDate(now.add(const Duration(days: 7))),
      ));
    }

    return recommendations;
  }

  /// Extracts the first sentence as the main instruction
  String _extractInstruction(String description) {
    final sentences = description.split(RegExp(r'(?<=[.!?])\s+'));
    if (sentences.isNotEmpty && sentences.first.isNotEmpty) {
      return sentences.first.length > 100 ? '${sentences.first.substring(0, 100)}...' : sentences.first;
    }
    return description.length > 100 ? '${description.substring(0, 100)}...' : description;
  }

  /// Breaks down the description paragraph into actionable bullet points
  List<String> _extractActionSteps(String description) {
    final steps = description
        .split(RegExp(r'(?<=[.!?])\s+|\n'))
        .where((s) => s.trim().isNotEmpty)
        .map((s) => s.trim())
        .toList();
    
    // If it's just one long block, try splitting by commas
    if (steps.length == 1 && steps.first.contains(',')) {
      return steps.first.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }
    
    return steps.isNotEmpty ? steps.take(4).toList() : ['Follow the provided care guidelines.'];
  }

  Season _getCurrentSeason(DateTime date, double? latitude) {
    final month = date.month;
    final isNorthern = latitude == null || latitude >= 0;

    if (isNorthern) {
      if (month >= 3 && month <= 5) return Season.spring;
      if (month >= 6 && month <= 8) return Season.summer;
      if (month >= 9 && month <= 11) return Season.fall;
      return Season.winter;
    } else {
      if (month >= 3 && month <= 5) return Season.fall;
      if (month >= 6 && month <= 8) return Season.winter;
      if (month >= 9 && month <= 11) return Season.spring;
      return Season.summer;
    }
  }

  SeasonalProfile _getSeasonalProfile(Season season, DateTime now) {
    final isGrowingSeason = season == Season.spring || season == Season.summer;
    final isDormant = season == Season.winter;
    final lightHours = _getDayLightHours(season, now);

    return SeasonalProfile(
      isGrowingSeason: isGrowingSeason,
      isDormant: isDormant,
      lightHours: lightHours,
      tempRange: _getSeasonalTempRange(season),
      primaryConcerns: _getSeasonalConcerns(season),
    );
  }

  double _getDayLightHours(Season season, DateTime now) {
    switch (season) {
      case Season.spring:
        return 11.0 + (now.month - 3) * 0.5;
      case Season.summer:
        return 14.0 + math.sin((now.day / 30) * math.pi) * 0.5;
      case Season.fall:
        return 13.0 - (now.month - 9) * 0.8;
      case Season.winter:
        return 9.0 + math.sin((now.day / 30) * math.pi) * 0.3;
    }
  }

  TemperatureRange _getSeasonalTempRange(Season season) {
    switch (season) {
      case Season.spring:
        return const TemperatureRange(min: 10, max: 20);
      case Season.summer:
        return const TemperatureRange(min: 18, max: 30);
      case Season.fall:
        return const TemperatureRange(min: 8, max: 18);
      case Season.winter:
        return const TemperatureRange(min: 2, max: 12);
    }
  }

  String _getSeasonalConcerns(Season season) {
    switch (season) {
      case Season.spring:
        return 'New growth, repotting, increased feeding';
      case Season.summer:
        return 'Heat stress, frequent watering, pest monitoring';
      case Season.fall:
        return 'Preparing for dormancy, reducing care';
      case Season.winter:
        return 'Minimal water, cold protection, low light adaptation';
    }
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }
}

enum Season { spring, summer, fall, winter }