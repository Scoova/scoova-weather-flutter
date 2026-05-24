# scoova_weather (Flutter / Dart)

Open-meteo compatible Flutter / Dart client for `weather.scoo-va.info`.

## Install

```yaml
dependencies:
  scoova_weather: ^1.1.0
```

```dart
import 'package:scoova_weather/scoova_weather.dart';

// Unauthenticated against the raw subdomain.
final client = WeatherClient();

// Authenticated via the gateway, French copy.
final gateway = WeatherClient(
  baseUrl: 'https://api.scoo-va.info/v1/weather',
  apiKey:  const String.fromEnvironment('SCOOVA_API_KEY', defaultValue: 'demo'),
  locale:  'fr',
);

final now = await gateway.current(30.04, 31.24);
final cond = decodeWeatherCode(now.current?['weather_code'] as num?);

final forecast = await gateway.daily(
  30.04, 31.24,
  vars: const [WeatherVar.temperature2mMax, WeatherVar.precipitationSum],
  days: 5,
);

// Per-call locale overrides the client default.
final arabic = await gateway.current(30.04, 31.24, locale: 'ar-EG');
```

## Locale

`locale` accepts BCP-47 codes: `en`, `en-US`, `en-GB`, `fr`, `es`, `de`, `it`,
`pt-BR`, `nl`, `ar`, `ar-EG`, `ar-SA`, plus regional variants. Sent as both
`?locale=` query string and `Accept-Language` header. Unsupported codes fall
back to `en` server-side.

## Tests

```sh
flutter test
```

## License

Apache-2.0.
