/// Typed, error-reporting access to decoded JSON objects.
///
/// Every content definition is parsed through this class so a typo in a
/// `game_data/*.json` file produces an error naming the file, the entry and
/// the key instead of a vague cast failure at runtime.
library;

typedef JsonMap = Map<String, Object?>;

class JsonReader {
  JsonReader(this.json, [this.context = '']);

  final JsonMap json;
  final String context;

  bool has(String key) => json.containsKey(key) && json[key] != null;

  FormatException _err(String key, String expected) => FormatException('$context: expected $expected at "$key" but found ${json[key]}');

  String str(String key) {
    final v = json[key];
    if (v is String) return v;
    throw _err(key, 'string');
  }

  String? strOr(String key, [String? fallback]) {
    final v = json[key];
    if (v == null) return fallback;
    if (v is String) return v;
    throw _err(key, 'string');
  }

  double dbl(String key) {
    final v = json[key];
    if (v is num) return v.toDouble();
    throw _err(key, 'number');
  }

  double dblOr(String key, double fallback) {
    final v = json[key];
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    throw _err(key, 'number');
  }

  int integer(String key) {
    final v = json[key];
    if (v is num) return v.toInt();
    throw _err(key, 'integer');
  }

  int intOr(String key, int fallback) {
    final v = json[key];
    if (v == null) return fallback;
    if (v is num) return v.toInt();
    throw _err(key, 'integer');
  }

  bool boolOr(String key, bool fallback) {
    final v = json[key];
    if (v == null) return fallback;
    if (v is bool) return v;
    throw _err(key, 'bool');
  }

  JsonReader obj(String key) {
    final v = json[key];
    if (v is Map) return JsonReader(v.cast<String, Object?>(), '$context.$key');
    throw _err(key, 'object');
  }

  JsonReader? objOr(String key) => has(key) ? obj(key) : null;

  List<JsonReader> objects(String key) {
    final v = json[key];
    if (v == null) return const [];
    if (v is! List) throw _err(key, 'list');
    final out = <JsonReader>[];
    for (var i = 0; i < v.length; i++) {
      final item = v[i];
      if (item is! Map) throw FormatException('$context.$key[$i]: expected object');
      out.add(JsonReader(item.cast<String, Object?>(), '$context.$key[$i]'));
    }
    return out;
  }

  List<String> strings(String key) {
    final v = json[key];
    if (v == null) return const [];
    if (v is List && v.every((e) => e is String)) return v.cast<String>();
    throw _err(key, 'list of strings');
  }

  List<double> doubles(String key) {
    final v = json[key];
    if (v == null) return const [];
    if (v is List && v.every((e) => e is num)) {
      return [for (final e in v) (e as num).toDouble()];
    }
    throw _err(key, 'list of numbers');
  }

  /// A `[min, max]` pair.
  (double, double) range(String key) {
    final values = doubles(key);
    if (values.length != 2) throw _err(key, '[min, max]');
    return (values[0], values[1]);
  }

  (double, double)? rangeOr(String key) => has(key) ? range(key) : null;

  Map<String, double> doubleMap(String key) {
    final v = json[key];
    if (v == null) return const {};
    if (v is Map) {
      final out = <String, double>{};
      for (final e in v.entries) {
        final value = e.value;
        if (value is! num) throw FormatException('$context.$key.${e.key}: expected number');
        out[e.key as String] = value.toDouble();
      }
      return out;
    }
    throw _err(key, 'object of numbers');
  }

  Map<String, String> stringMap(String key) {
    final v = json[key];
    if (v == null) return const {};
    if (v is Map) {
      return {for (final e in v.entries) e.key as String: '${e.value}'};
    }
    throw _err(key, 'object');
  }
}
