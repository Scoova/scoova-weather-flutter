import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:scoova_weather/scoova_weather.dart';

void main() {
  group('WeatherClient', () {
    test('builds /v1/forecast URL with sane defaults', () async {
      late http.BaseRequest captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'latitude': 30.0625, 'longitude': 31.25,
            'generationtime_ms': 0.1, 'utc_offset_seconds': 7200,
            'timezone': 'Africa/Cairo', 'timezone_abbreviation': 'EET',
            'current': {'time': '2026-05-04T17:00', 'interval': 900, 'temperature_2m': 24.1},
          }),
          200,
          headers: {'Content-Type': 'application/json'},
        );
      });

      final client = WeatherClient(baseUrl: 'https://example.test', client: mock);
      final res = await client.current(30.04, 31.24);

      final url = captured.url;
      expect(url.path, '/v1/forecast');
      expect(url.queryParameters['latitude'], '30.04');
      expect(url.queryParameters['longitude'], '31.24');
      expect(url.queryParameters['current'], contains('temperature_2m'));
      expect(url.queryParameters['timezone'], 'auto');
      expect(captured.headers['X-API-Key'], isNull);
      expect(captured.headers['Accept-Language'], isNull);
      expect(res.timezone, 'Africa/Cairo');
      expect(res.current!['temperature_2m'], 24.1);
    });

    test('forwards forecastDays / units / pastDays', () async {
      late http.BaseRequest captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'latitude': 0.0, 'longitude': 0.0,
            'generationtime_ms': 0.0, 'utc_offset_seconds': 0,
            'timezone': 'GMT', 'timezone_abbreviation': 'GMT',
          }),
          200,
        );
      });

      final client = WeatherClient(baseUrl: 'https://example.test', client: mock);
      await client.forecast(
        lat: 30, lon: 31,
        hourly: const [WeatherVar.temperature2m, WeatherVar.windSpeed10m],
        daily:  const [WeatherVar.temperature2mMax],
        forecastDays: 3, pastDays: 1,
        temperatureUnit: TemperatureUnit.fahrenheit,
        windSpeedUnit: WindSpeedUnit.ms,
      );
      final qp = captured.url.queryParameters;
      expect(qp['hourly'], 'temperature_2m,wind_speed_10m');
      expect(qp['daily'], 'temperature_2m_max');
      expect(qp['forecast_days'], '3');
      expect(qp['past_days'], '1');
      expect(qp['temperature_unit'], 'fahrenheit');
      expect(qp['wind_speed_unit'], 'ms');
    });

    test('throws WeatherException on non-2xx', () async {
      final mock = MockClient((req) async => http.Response('boom', 502));
      final client = WeatherClient(client: mock);
      expect(
        () => client.current(30, 31),
        throwsA(isA<WeatherException>().having((e) => e.statusCode, 'status', 502)),
      );
    });

    test('attaches X-API-Key header and ?locale= when apiKey + locale set', () async {
      late http.BaseRequest captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'latitude': 0.0, 'longitude': 0.0,
            'generationtime_ms': 0.0, 'utc_offset_seconds': 0,
            'timezone': 'GMT', 'timezone_abbreviation': 'GMT',
          }),
          200,
        );
      });

      final client = WeatherClient(
        baseUrl: 'https://api.scoo-va.info/v1/weather',
        apiKey: 'sk_live_abc',
        locale: 'fr',
        client: mock,
      );
      await client.current(30.04, 31.24);

      expect(captured.headers['X-API-Key'], 'sk_live_abc');
      expect(captured.headers['Accept-Language'], 'fr');
      expect(captured.url.queryParameters['locale'], 'fr');
    });

    test('per-call locale overrides client default', () async {
      late http.BaseRequest captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'latitude': 0.0, 'longitude': 0.0,
            'generationtime_ms': 0.0, 'utc_offset_seconds': 0,
            'timezone': 'GMT', 'timezone_abbreviation': 'GMT',
          }),
          200,
        );
      });

      final client = WeatherClient(
        baseUrl: 'https://example.test',
        locale: 'en',
        client: mock,
      );
      await client.current(30.04, 31.24, locale: 'ar-EG');

      expect(captured.headers['Accept-Language'], 'ar-EG');
      expect(captured.url.queryParameters['locale'], 'ar-EG');
    });
  });

  group('decodeWeatherCode', () {
    test('maps WMO codes to broad conditions', () {
      expect(decodeWeatherCode(0), WeatherCondition.clear);
      expect(decodeWeatherCode(2), WeatherCondition.cloudy);
      expect(decodeWeatherCode(45), WeatherCondition.fog);
      expect(decodeWeatherCode(53), WeatherCondition.drizzle);
      expect(decodeWeatherCode(63), WeatherCondition.rain);
      expect(decodeWeatherCode(80), WeatherCondition.rain);
      expect(decodeWeatherCode(73), WeatherCondition.snow);
      expect(decodeWeatherCode(96), WeatherCondition.thunderstorm);
      expect(decodeWeatherCode(null), WeatherCondition.unknown);
      expect(decodeWeatherCode(999), WeatherCondition.unknown);
    });
  });
}
