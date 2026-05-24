import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;

const _defaultBase = 'https://weather.scoo-va.info';

/// Variables you can request via `current` / `hourly` / `daily`. Subset of
/// open-meteo — extend at the call site if you need anything else (the server
/// will accept the raw name even if it's not listed here).
class WeatherVar {
  final String name;
  const WeatherVar(this.name);

  // current / hourly
  static const temperature2m = WeatherVar('temperature_2m');
  static const relativeHumidity2m = WeatherVar('relative_humidity_2m');
  static const apparentTemperature = WeatherVar('apparent_temperature');
  static const precipitation = WeatherVar('precipitation');
  static const rain = WeatherVar('rain');
  static const showers = WeatherVar('showers');
  static const snowfall = WeatherVar('snowfall');
  static const cloudCover = WeatherVar('cloud_cover');
  static const windSpeed10m = WeatherVar('wind_speed_10m');
  static const windDirection10m = WeatherVar('wind_direction_10m');
  static const windGusts10m = WeatherVar('wind_gusts_10m');
  static const weatherCode = WeatherVar('weather_code');
  static const pressureMsl = WeatherVar('pressure_msl');
  static const visibility = WeatherVar('visibility');
  static const uvIndex = WeatherVar('uv_index');
  static const isDay = WeatherVar('is_day');

  // daily
  static const temperature2mMax = WeatherVar('temperature_2m_max');
  static const temperature2mMin = WeatherVar('temperature_2m_min');
  static const precipitationSum = WeatherVar('precipitation_sum');
  static const precipitationHours = WeatherVar('precipitation_hours');
  static const windSpeed10mMax = WeatherVar('wind_speed_10m_max');
  static const sunrise = WeatherVar('sunrise');
  static const sunset = WeatherVar('sunset');
  static const uvIndexMax = WeatherVar('uv_index_max');

  @override
  String toString() => name;
}

enum WindSpeedUnit { kmh, ms, mph, kn }
enum TemperatureUnit { celsius, fahrenheit }
enum PrecipitationUnit { mm, inch }

extension on WindSpeedUnit { String get wire => name; }
extension on TemperatureUnit { String get wire => name; }
extension on PrecipitationUnit { String get wire => name; }

class ForecastResponse {
  final double latitude;
  final double longitude;
  final String timezone;
  final Map<String, dynamic>? current;
  final Map<String, dynamic>? hourly;
  final Map<String, dynamic>? daily;
  final Map<String, dynamic>? currentUnits;
  final Map<String, dynamic>? hourlyUnits;
  final Map<String, dynamic>? dailyUnits;
  final Map<String, dynamic> raw;

  const ForecastResponse({
    required this.latitude,
    required this.longitude,
    required this.timezone,
    required this.current,
    required this.hourly,
    required this.daily,
    required this.currentUnits,
    required this.hourlyUnits,
    required this.dailyUnits,
    required this.raw,
  });

  factory ForecastResponse.fromJson(Map<String, dynamic> j) => ForecastResponse(
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        timezone: (j['timezone'] as String?) ?? 'GMT',
        current: j['current'] as Map<String, dynamic>?,
        hourly: j['hourly'] as Map<String, dynamic>?,
        daily: j['daily'] as Map<String, dynamic>?,
        currentUnits: j['current_units'] as Map<String, dynamic>?,
        hourlyUnits: j['hourly_units'] as Map<String, dynamic>?,
        dailyUnits: j['daily_units'] as Map<String, dynamic>?,
        raw: j,
      );
}

class WeatherException implements Exception {
  final int? statusCode;
  final String message;
  WeatherException(this.message, {this.statusCode});
  @override
  String toString() => 'WeatherException(${statusCode ?? '-'}): $message';
}

/// Open-meteo compatible client for `weather.scoo-va.info`.
///
/// Point [baseUrl] at the gateway (`https://api.scoo-va.info/v1/weather`) and
/// pass [apiKey] for key-enforced calls. Reads `SCOOVA_API_KEY` from
/// `Platform.environment` when [apiKey] is null (on platforms that expose it).
///
/// [locale] sets the default locale (BCP-47 codes — `en`, `en-US`, `fr`,
/// `es`, `de`, `it`, `pt-BR`, `nl`, `ar`, `ar-EG`, `ar-SA`, plus regional
/// variants). Sent as both `?locale=` and `Accept-Language`. Per-call
/// `locale` overrides the client default.
class WeatherClient {
  final String baseUrl;
  final String? _apiKey;
  final String? _locale;
  final http.Client _http;

  WeatherClient({
    String? baseUrl,
    String? apiKey,
    String? locale,
    http.Client? client,
  })  : baseUrl = (baseUrl ?? _defaultBase).replaceAll(RegExp(r'/+$'), ''),
        _apiKey = apiKey ?? _envApiKey(),
        _locale = locale,
        _http = client ?? http.Client();

  static String? _envApiKey() {
    try {
      return Platform.environment['SCOOVA_API_KEY'];
    } catch (_) {
      // Web / sandboxes that throw on Platform.environment access.
      return null;
    }
  }

  Future<ForecastResponse> current(
    double lat,
    double lon, {
    List<WeatherVar>? vars,
    String? locale,
  }) {
    return forecast(
      lat: lat, lon: lon,
      current: vars ?? const [
        WeatherVar.temperature2m,
        WeatherVar.relativeHumidity2m,
        WeatherVar.apparentTemperature,
        WeatherVar.precipitation,
        WeatherVar.windSpeed10m,
        WeatherVar.windDirection10m,
        WeatherVar.weatherCode,
        WeatherVar.isDay,
      ],
      forecastDays: 1,
      locale: locale,
    );
  }

  Future<ForecastResponse> hourly(
    double lat,
    double lon, {
    List<WeatherVar>? vars,
    int days = 7,
    String? locale,
  }) {
    return forecast(
      lat: lat, lon: lon,
      hourly: vars ?? const [
        WeatherVar.temperature2m,
        WeatherVar.precipitation,
        WeatherVar.windSpeed10m,
        WeatherVar.weatherCode,
      ],
      forecastDays: days,
      locale: locale,
    );
  }

  Future<ForecastResponse> daily(
    double lat,
    double lon, {
    List<WeatherVar>? vars,
    int days = 7,
    String? locale,
  }) {
    return forecast(
      lat: lat, lon: lon,
      daily: vars ?? const [
        WeatherVar.temperature2mMax,
        WeatherVar.temperature2mMin,
        WeatherVar.precipitationSum,
        WeatherVar.windSpeed10mMax,
        WeatherVar.weatherCode,
        WeatherVar.sunrise,
        WeatherVar.sunset,
      ],
      forecastDays: days,
      locale: locale,
    );
  }

  Future<ForecastResponse> forecast({
    required double lat,
    required double lon,
    List<WeatherVar>? current,
    List<WeatherVar>? hourly,
    List<WeatherVar>? daily,
    String timezone = 'auto',
    int? forecastDays,
    int? pastDays,
    WindSpeedUnit? windSpeedUnit,
    TemperatureUnit? temperatureUnit,
    PrecipitationUnit? precipitationUnit,

    /// Per-call locale override; overrides the client-level `locale`.
    String? locale,
  }) async {
    final effectiveLocale = locale ?? _locale;
    final qp = <String, String>{
      'latitude': lat.toString(),
      'longitude': lon.toString(),
      'timezone': timezone,
    };
    if (current != null && current.isNotEmpty) qp['current'] = current.map((v) => v.name).join(',');
    if (hourly != null && hourly.isNotEmpty) qp['hourly'] = hourly.map((v) => v.name).join(',');
    if (daily != null && daily.isNotEmpty) qp['daily'] = daily.map((v) => v.name).join(',');
    if (forecastDays != null) qp['forecast_days'] = forecastDays.toString();
    if (pastDays != null) qp['past_days'] = pastDays.toString();
    if (windSpeedUnit != null) qp['wind_speed_unit'] = windSpeedUnit.wire;
    if (temperatureUnit != null) qp['temperature_unit'] = temperatureUnit.wire;
    if (precipitationUnit != null) qp['precipitation_unit'] = precipitationUnit.wire;
    if (effectiveLocale != null) qp['locale'] = effectiveLocale;

    final json = await _getJson('/v1/forecast', qp, effectiveLocale);
    return ForecastResponse.fromJson(json);
  }

  Future<Map<String, dynamic>> raw(
    String path, {
    Map<String, String>? params,
    String? locale,
  }) {
    final effectiveLocale = locale ?? _locale;
    final qp = Map<String, String>.from(params ?? const {});
    if (effectiveLocale != null && !qp.containsKey('locale')) {
      qp['locale'] = effectiveLocale;
    }
    return _getJson(path, qp, effectiveLocale);
  }

  Future<Map<String, dynamic>> _getJson(
    String path,
    Map<String, String> qp,
    String? callLocale,
  ) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: qp.isEmpty ? null : qp);
    final headers = <String, String>{'Accept': 'application/json'};
    if (_apiKey != null) headers['X-API-Key'] = _apiKey!;
    if (callLocale != null) headers['Accept-Language'] = callLocale;

    final res = await _http.get(uri, headers: headers);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw WeatherException(res.body, statusCode: res.statusCode);
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  void close() => _http.close();
}

enum WeatherCondition { clear, cloudy, fog, drizzle, rain, snow, thunderstorm, unknown }

/// Map an open-meteo WMO weather code to a coarse-grained condition label.
WeatherCondition decodeWeatherCode(num? code) {
  if (code == null) return WeatherCondition.unknown;
  final c = code.toInt();
  if (c == 0) return WeatherCondition.clear;
  if (c >= 1 && c <= 3) return WeatherCondition.cloudy;
  if (c == 45 || c == 48) return WeatherCondition.fog;
  if (c >= 51 && c <= 57) return WeatherCondition.drizzle;
  if ((c >= 61 && c <= 67) || (c >= 80 && c <= 82)) return WeatherCondition.rain;
  if ((c >= 71 && c <= 77) || c == 85 || c == 86) return WeatherCondition.snow;
  if (c >= 95 && c <= 99) return WeatherCondition.thunderstorm;
  return WeatherCondition.unknown;
}
