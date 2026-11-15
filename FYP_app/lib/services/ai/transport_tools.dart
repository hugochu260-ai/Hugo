import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

/// Read-only public-data tools: Hong Kong district weather and bus ETA.
///
/// Weather: Open-Meteo at a Hong Kong place coordinate (model/grid data,
/// not HKO station observations).
/// Bus: KMB/LWB, Citybus (CTB) and NLB open data.
class TransportTools {
  static const _kmbBase = 'https://data.etabus.gov.hk/v1/transport/kmb';
  static const _rtBase = 'https://rt.data.gov.hk/v2/transport';

  // District / major-place coordinates (WGS84, approximate centres).
  static const Map<String, List<double>> _places = {
    '香港': [22.3193, 114.1694],
    '威爾斯親王醫院': [22.3798, 114.2016],
    '威爾斯醫院': [22.3798, 114.2016],
    '瑪麗醫院': [22.2704, 114.1312],
    '伊利沙伯醫院': [22.3089, 114.1753],
    '廣華醫院': [22.3149, 114.1723],
    '屯門醫院': [22.4074, 113.9762],
    '基督教聯合醫院': [22.3232, 114.2275],
    '聯合醫院': [22.3232, 114.2275],
    '東區尤德夫人那打素醫院': [22.2693, 114.2363],
    '東區醫院': [22.2693, 114.2363],
    '雅麗氏何妙齡那打素醫院': [22.4587, 114.1748],
    '那打素醫院': [22.4587, 114.1748],
    '北區醫院': [22.4967, 114.1246],
    '瑪嘉烈醫院': [22.3406, 114.1342],
    '明愛醫院': [22.3411, 114.1524],
    '仁濟醫院': [22.3696, 114.1195],
    '將軍澳醫院': [22.3180, 114.2698],
    '天水圍醫院': [22.4585, 113.9958],
    '香港復康會': [22.3079, 114.2314],
    '九龍': [22.3200, 114.1700],
    '新界': [22.4000, 114.1000],
    '中西區': [22.2860, 114.1500],
    '灣仔': [22.2780, 114.1750],
    '東區': [22.2840, 114.2260],
    '南區': [22.2450, 114.1600],
    '油尖旺': [22.3130, 114.1710],    '深水埗': [22.3310, 114.1620],
    '九龍城': [22.3280, 114.1910],
    '黃大仙': [22.3420, 114.1960],
    '觀塘': [22.3120, 114.2260],
    '葵青': [22.3600, 114.1300],
    '荃灣': [22.3710, 114.1140],
    '屯門': [22.3940, 113.9760],
    '元朗': [22.4440, 114.0320],
    '北區': [22.5010, 114.1280],
    '大埔': [22.4500, 114.1690],
    '沙田': [22.3820, 114.1880],
    '西貢': [22.3820, 114.2700],
    '離島': [22.2620, 114.0300],
    '中環': [22.2820, 114.1580],
    '金鐘': [22.2790, 114.1650],
    '銅鑼灣': [22.2800, 114.1850],
    '北角': [22.2910, 114.2000],
    '鰂魚涌': [22.2880, 114.2100],
    '太古城': [22.2870, 114.2170],
    '香港仔': [22.2480, 114.1550],
    '赤柱': [22.2190, 114.2120],
    '淺水灣': [22.2360, 114.1960],
    '山頂': [22.2710, 114.1490],
    '旺角': [22.3190, 114.1690],
    '尖沙咀': [22.2970, 114.1720],
    '佐敦': [22.3050, 114.1710],
    '油麻地': [22.3120, 114.1700],
    '長沙灣': [22.3370, 114.1560],
    '荔枝角': [22.3370, 114.1480],
    '九龍塘': [22.3370, 114.1760],
    '土瓜灣': [22.3170, 114.1870],
    '紅磡': [22.3050, 114.1880],
    '鑽石山': [22.3400, 114.2010],
    '慈雲山': [22.3480, 114.2010],
    '藍田': [22.3090, 114.2360],
    '油塘': [22.2970, 114.2370],
    '將軍澳': [22.3070, 114.2600],
    '葵涌': [22.3630, 114.1360],
    '青衣': [22.3450, 114.1050],
    '天水圍': [22.4590, 114.0040],
    '上水': [22.5020, 114.1280],
    '粉嶺': [22.4920, 114.1420],
    '太和': [22.4510, 114.1610],
    '大圍': [22.3720, 114.1780],
    '火炭': [22.3950, 114.1930],
    '馬鞍山': [22.4250, 114.2310],
    '東涌': [22.2890, 113.9420],
    '機場': [22.3080, 113.9180],
    '迪士尼': [22.3130, 114.0410],
    '長洲': [22.2100, 114.0280],
    '南丫島': [22.2000, 114.1200],
    '大帽山': [22.4100, 114.1240],
    '鳳凰山': [22.2540, 113.9110],
    '昂坪': [22.2550, 113.9120],
    '石澳': [22.2300, 114.2460],
    '跑馬地': [22.2700, 114.1830],
    '何文田': [22.3130, 114.1820],
    '美孚': [22.3380, 114.1380],
    '西貢市': [22.3820, 114.2700],
    '大尾篤': [22.4660, 114.2370],
    '梅窩': [22.2650, 114.0010],
    '大澳': [22.2520, 113.8650],
    '愉景灣': [22.3000, 114.0170],
    '科大': [22.3370, 114.2630],
    '港大': [22.2830, 114.1370],
    '中大': [22.4190, 114.2060],
    '科學園': [22.4270, 114.2110],
    '黃竹坑': [22.2480, 114.1670],
    '赤鱲角': [22.3110, 113.9290],
    '啟德': [22.3300, 114.1990],
    '康城': [22.2950, 114.2700],
    '日出康城': [22.2950, 114.2700],
    '堅尼地城': [22.2820, 114.1280],
    '西營盤': [22.2860, 114.1420],
    '上環': [22.2870, 114.1500],
    '天后': [22.2820, 114.1920],
    '炮台山': [22.2880, 114.1930],
    '西灣河': [22.2820, 114.2220],
    '筲箕灣': [22.2790, 114.2290],
    '柴灣': [22.2640, 114.2370],
    '小西灣': [22.2620, 114.2500],
    '杏花邨': [22.2770, 114.2400],
    '鴨脷洲': [22.2420, 114.1550],
    '海洋公園': [22.2360, 114.1750],
    '大潭': [22.2420, 114.2050],
    '薄扶林': [22.2650, 114.1300],
    '數碼港': [22.2620, 114.1300],
    '田灣': [22.2500, 114.1500],
    '華富': [22.2530, 114.1350],
    '半山': [22.2780, 114.1500],
    '大坑': [22.2760, 114.1900],
    '尖東': [22.2960, 114.1780],
    '大角咀': [22.3200, 114.1600],
    '太子': [22.3250, 114.1680],
    '石硤尾': [22.3320, 114.1680],
    '牛頭角': [22.3230, 114.2140],
    '九龍灣': [22.3250, 114.2120],
    '新蒲崗': [22.3350, 114.1960],
    '樂富': [22.3390, 114.1870],
    '秀茂坪': [22.3200, 114.2300],
    '順利': [22.3320, 114.2270],
    '鯉魚門': [22.2900, 114.2400],
    '石門': [22.3900, 114.2080],
    '大水坑': [22.4050, 114.2220],
    '烏溪沙': [22.4280, 114.2400],
    '第一城': [22.3850, 114.2030],
    '馬料水': [22.4200, 114.2100],
    '白石角': [22.4300, 114.2050],
    '大埔墟': [22.4440, 114.1690],
    '聯和墟': [22.4970, 114.1430],
    '沙頭角': [22.5450, 114.2200],
    '打鼓嶺': [22.5350, 114.1650],
    '羅湖': [22.5280, 114.1130],
    '落馬洲': [22.5150, 114.0750],
    '八鄉': [22.4250, 114.0900],
    '石崗': [22.4300, 114.0800],
    '洪水橋': [22.4300, 113.9950],
    '大棠': [22.4150, 114.0300],
    '濕地公園': [22.4680, 114.0050],
    '兆康': [22.4100, 113.9800],
    '黃金海岸': [22.3650, 113.9850],
    '掃管笏': [22.3750, 113.9900],
    '深井': [22.3700, 114.0600],
    '青龍頭': [22.3650, 114.0450],
    '汀九': [22.3700, 114.0800],
    '葵芳': [22.3570, 114.1300],
    '葵興': [22.3680, 114.1300],
    '荔景': [22.3500, 114.1250],
    '大窩口': [22.3700, 114.1200],
    '馬灣': [22.3500, 114.0600],
    '珀麗灣': [22.3450, 114.0600],
    '欣澳': [22.3200, 114.0300],
    '貝澳': [22.2400, 113.9900],
    '長沙': [22.2350, 113.9500],
    '石壁': [22.2200, 113.9000],
    '坪洲': [22.2850, 114.0300],
    '白沙灣': [22.3600, 114.2700],
    '蠔涌': [22.3650, 114.2500],
    '井欄樹': [22.3550, 114.2350],
    '寶琳': [22.3200, 114.2500],
    '坑口': [22.3150, 114.2650],
    '調景嶺': [22.3050, 114.2500],
    '清水灣': [22.3000, 114.2900],
    '西九文化區': [22.3000, 114.1600],
    '啟德體育園': [22.3200, 114.2000],
  };

  // HKO rhrread observation-station coordinates (approximate).
  static const Map<String, List<double>> _hkoStations = {
    '香港天文台': [22.302, 114.174],
    '京士柏': [22.312, 114.173],
    '黃竹坑': [22.248, 114.167],
    '打鼓嶺': [22.535, 114.165],
    '流浮山': [22.469, 113.984],
    '大埔': [22.448, 114.170],
    '沙田': [22.383, 114.183],
    '屯門': [22.389, 113.976],
    '將軍澳': [22.318, 114.255],
    '西貢': [22.383, 114.270],
    '長洲': [22.210, 114.028],
    '赤鱲角': [22.309, 113.914],
    '青衣': [22.344, 114.100],
    '荃灣': [22.371, 114.114],
    '荃灣可觀': [22.373, 114.117],
    '荃灣城門谷': [22.379, 114.130],
    '啟德': [22.318, 114.203],
    '啟德跑道公園': [22.305, 114.219],
    '觀塘': [22.318, 114.225],
    '深水埗': [22.335, 114.162],
    '香港公園': [22.278, 114.162],
    '北角': [22.291, 114.200],
    '筲箕灣': [22.279, 114.229],
    '跑馬地': [22.270, 114.183],
    '九龍城': [22.328, 114.191],
    '赤柱': [22.219, 114.212],
    '大美督': [22.466, 114.237],
    '元朗公園': [22.442, 114.020],
    '中環': [22.282, 114.158],
    '山頂': [22.271, 114.149],
    '昂坪': [22.255, 113.912],
    '大老山': [22.358, 114.218],
    '大帽山': [22.410, 114.124],
    '石崗': [22.430, 114.080],
    '濕地公園': [22.468, 114.005],
    '坪洲': [22.285, 114.030],
    '橫瀾島': [22.183, 114.303],
    '石澳': [22.230, 114.246],
  };

  static const List<String> _districts = [
    '中西區',
    '灣仔',
    '東區',
    '南區',
    '油尖旺',
    '深水埗',
    '九龍城',
    '黃大仙',
    '觀塘',
    '葵青',
    '荃灣',
    '屯門',
    '元朗',
    '北區',
    '大埔',
    '沙田',
    '西貢',
    '離島',
  ];

  static const Map<String, String> _districtOverrides = {
    '赤鱲角': '離島',
    '機場': '離島',
    '東涌': '離島',
    '迪士尼': '離島',
    '欣澳': '離島',
    '愉景灣': '離島',
    '大澳': '離島',
    '昂坪': '離島',
    '梅窩': '離島',
    '貝澳': '離島',
    '長沙': '離島',
    '石壁': '離島',
    '坪洲': '離島',
    '長洲': '離島',
    '南丫島': '離島',
    '大嶼山': '離島',
    '康城': '西貢',
    '日出康城': '西貢',
    '將軍澳': '西貢',
    '寶琳': '西貢',
    '坑口': '西貢',
    '調景嶺': '西貢',
    '清水灣': '西貢',
    '西貢市': '西貢',
    '馬灣': '荃灣',
    '珀麗灣': '荃灣',
    '青衣': '葵青',
    '大埔滘': '大埔',
  };

  List<_Variant>? _variants;
  DateTime? _routesAt;
  Map<String, _Stop>? _kmbStops;
  DateTime? _kmbStopsAt;
  final Map<String, _Stop> _ctbStops = {};
  final Map<String, List<_Stop>> _routeStops = {};
  final Map<String, List<_Stop>> _mtrStops = {};

  Future<String> weather({String? date, String? place}) async {
    final d = (date ?? 'current').trim();
    if (d != 'current' && !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(d)) {
      return '日期格式請用 current 或 YYYY-MM-DD。';
    }
    final p = _matchPlace(place);
    var target = p;
    if (target == null && place != null && place.trim().isNotEmpty) {
      try {
        target = await _geocodePlace(place);
      } catch (_) {
        target = null;
      }
      if (target == null) {
        return '找不到「$place」的香港座標。請用地區名，例如：'
            '大埔、沙田、觀塘、荃灣、屯門、元朗、西貢、東涌、大帽山。';
      }
    }
    final targetPlace = target ?? _placeOf('香港');
    if (d == 'current') {
      final hko = await _hkoCurrent(targetPlace);
      if (hko != null) return hko;
    }
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': targetPlace.lat.toString(),
      'longitude': targetPlace.lon.toString(),
      'current':
          'temperature_2m,relative_humidity_2m,precipitation,weather_code,wind_speed_10m',
      'daily':
          'temperature_2m_max,temperature_2m_min,precipitation_probability_max,weather_code',
      'timezone': 'Asia/Hong_Kong',
      'forecast_days': '7',
    });
    final root = await _getJson(uri.toString());
    if (root['error'] == true) {
      return '天氣查詢失敗：${root['reason'] ?? '未知錯誤'}';
    }
    final timezone = '${root['timezone'] ?? 'Asia/Hong_Kong'}';
    final label =
        '${targetPlace.name}天氣（${targetPlace.lat.toStringAsFixed(2)}, ${targetPlace.lon.toStringAsFixed(2)}）';
    if (d == 'current') {
      final c = (root['current'] as Map?)?.cast<String, dynamic>() ?? {};
      final units =
          (root['current_units'] as Map?)?.cast<String, dynamic>() ?? {};
      return '$label\n'
          '${_weatherCode(c['weather_code'])}，氣溫 ${_num(c['temperature_2m'])}${units['temperature_2m'] ?? '°C'}\n'
          '相對濕度 ${_num(c['relative_humidity_2m'])}${units['relative_humidity_2m'] ?? '%'}；'
          '風速 ${_num(c['wind_speed_10m'])} ${units['wind_speed_10m'] ?? 'km/h'}\n'
          '降水量 ${_num(c['precipitation'])} ${units['precipitation'] ?? 'mm'}\n'
          '資料時間：${c['time'] ?? '—'}（$timezone）\n'
          '來源：Open-Meteo；屬座標網格／模型資料，不是天文台測站實測。';
    }
    final daily = (root['daily'] as Map?)?.cast<String, dynamic>() ?? {};
    final times = (daily['time'] as List?)?.cast<String>() ?? const <String>[];
    final i = times.indexOf(d);
    if (i < 0) {
      return 'Open-Meteo 只提供未來 7 日預報，找不到 $d。';
    }
    final min = (daily['temperature_2m_min'] as List?)?[i];
    final max = (daily['temperature_2m_max'] as List?)?[i];
    final rain = (daily['precipitation_probability_max'] as List?)?[i];
    final code = (daily['weather_code'] as List?)?[i];
    final units = (daily['daily_units'] as Map?)?.cast<String, dynamic>() ??
        (root['daily_units'] as Map?)?.cast<String, dynamic>() ??
        {};
    return '$label $d 預報\n'
        '${_weatherCode(code)}，${_num(min)}–${_num(max)}${units['temperature_2m_max'] ?? '°C'}\n'
        '當日最高降雨機率 ${_num(rain)}${units['precipitation_probability_max'] ?? '%'}\n'
        '時區：$timezone\n'
        '來源：Open-Meteo；屬座標網格／模型資料，不是天文台測站實測。';
  }

  /// Current district weather from the Hong Kong Observatory (rhrread).
  Future<String?> _hkoCurrent(_Place p) async {
    try {
      final root = await _getJson(
          'https://data.weather.gov.hk/weatherAPI/opendata/weather.php'
          '?dataType=rhrread&lang=tc');
      final temp = (root['temperature'] as Map?)?.cast<String, dynamic>();
      final tempData = ((temp?['data'] as List?) ?? const [])
          .cast<Map<String, dynamic>>();
      final station = _pickHkoStation(tempData, p);
      if (station == null) return null;
      final value = station['value'];
      if (value is! num) return null;

      final hum = (root['humidity'] as Map?)?.cast<String, dynamic>();
      final humData = ((hum?['data'] as List?) ?? const [])
          .cast<Map<String, dynamic>>();
      final humEntry = humData.isNotEmpty ? humData.first : null;

      final rain = (root['rainfall'] as Map?)?.cast<String, dynamic>();
      final rainData = ((rain?['data'] as List?) ?? const [])
          .cast<Map<String, dynamic>>();
      final district = _districtOverrides[p.name] ?? _districtOf(p.lat, p.lon);
      Map<String, dynamic>? rainEntry;
      final districtKey = district.replaceAll('區', '');
      for (final e in rainData) {
        final name = '${e['place'] ?? ''}'.replaceAll('區', '');
        if (name == districtKey) {
          rainEntry = e;
          break;
        }
      }

      final stationName = '${station['place'] ?? ''}';
      final recordTime = _hkoTime('${temp?['recordTime'] ?? ''}');
      final b = StringBuffer()
        ..writeln('${p.name}天氣（香港天文台分區觀測）')
        ..writeln('氣溫 ${_num(value)}°C（$stationName 站）');
      if (humEntry != null && humEntry['value'] is num) {
        b.writeln('相對濕度 ${_num(humEntry['value'])}%'
            '（${humEntry['place'] ?? '香港天文台'}）');
      }
      if (rainEntry != null) {
        final rv = rainEntry['value'];
        b.writeln('雨量 ${rv is num ? _num(rv) : '0'} mm（$district）');
      }
      if (recordTime.isNotEmpty) b.writeln('觀測時間：$recordTime');
      b.write('來源：香港天文台 rhrread');
      return b.toString();
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _pickHkoStation(
      List<Map<String, dynamic>> data, _Place p) {
    for (final e in data) {
      if ('${e['place'] ?? ''}' == p.name) return e;
    }
    Map<String, dynamic>? nearest;
    var best = double.infinity;
    for (final e in data) {
      final c = _hkoStations['${e['place'] ?? ''}'];
      if (c == null) continue;
      final dx = p.lat - c[0];
      final dy = p.lon - c[1];
      final d = dx * dx + dy * dy;
      if (d < best) {
        best = d;
        nearest = e;
      }
    }
    return nearest;
  }

  String _districtOf(double lat, double lon) {
    var best = '香港';
    var bestDistance = double.infinity;
    for (final name in _districts) {
      final c = _places[name];
      if (c == null) continue;
      final dx = lat - c[0];
      final dy = lon - c[1];
      final d = dx * dx + dy * dy;
      if (d < bestDistance) {
        bestDistance = d;
        best = name;
      }
    }
    return best;
  }

  String _hkoTime(String raw) {
    final s = raw.trim();
    final iso = DateTime.tryParse(s);
    if (iso != null) {
      final hk = iso.toUtc().add(const Duration(hours: 8));
      return '${hk.year}-${_two(hk.month)}-${_two(hk.day)} '
          '${_two(hk.hour)}:${_two(hk.minute)}';
    }
    final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4}) (\d{2}):(\d{2}):(\d{2})$')
        .firstMatch(s);
    if (m == null) return s;
    return '${m[3]}-${m[1]}-${m[2]} ${m[4]}:${m[5]}';
  }

  /// [route] bus route number, e.g. 1A / 5B / 11.
  /// [operator] 九巴/龍運/城巴/嶼巴 (or KMB/LWB/CTB/NLB).
  /// [direction] destination or origin keyword, e.g. 尖沙咀.
  /// [stop] boarding stop name, e.g. 旺角.
  /// Finds nearby bus stops within [radiusM] meters of GPS (lat, lon) and
  /// fetches live upcoming bus arrivals across routes — zero stop-name typing!
  Future<String> nearbyStopsEta({
    required double lat,
    required double lon,
    double radiusM = 450,
  }) async {
    await _ensureKmbStops();
    final stopsMap = _kmbStops ?? const <String, _Stop>{};
    if (stopsMap.isEmpty) {
      return '暫時未能下載香港巴士站座標資料，請檢查網絡連線。';
    }

    final nearby = <(_Stop, double)>[];
    for (final s in stopsMap.values) {
      if (s.lat == null || s.lon == null) continue;
      final d = _haversineM(lat, lon, s.lat!, s.lon!);
      if (d <= radiusM) {
        nearby.add((s, d));
      }
    }
    if (nearby.isEmpty) {
      return '你附近 ${radiusM.round()} 米內暫未找到九巴／龍運巴士站，可改用「路線規劃」搜尋起點及目的地。';
    }
    nearby.sort((a, b) => a.$2.compareTo(b.$2));

    // Group platforms sharing the same clean stop name, take closest 3 clusters
    final clusters = <String, List<(_Stop, double)>>{};
    for (final entry in nearby) {
      final name = _display(entry.$1);
      clusters.putIfAbsent(name, () => []).add(entry);
      if (clusters.length >= 4 && clusters[name]!.length > 2) continue;
    }

    final topNames = clusters.keys.take(3).toList();
    final out = StringBuffer()
      ..writeln('附近無障礙低地台巴士站即時到站（GPS 定位）：');

    for (final name in topNames) {
      final platforms = clusters[name]!;
      final minDist = platforms.first.$2.round();
      out.writeln('\n📍 $name（距離約 $minDist 米）');

      final routeLines = <String, String>{};
      for (final p in platforms.take(3)) {
        try {
          final root = await _getJson('$_kmbBase/stop-eta/${p.$1.id}');
          final list = ((root['data'] as List?) ?? const [])
              .cast<Map<String, dynamic>>();
          for (final e in list) {
            final r = '${e['route'] ?? ''}'.trim();
            final dest = '${e['dest_tc'] ?? ''}'.trim();
            final seq = int.tryParse('${e['eta_seq'] ?? 1}') ?? 1;
            if (r.isEmpty || seq != 1) continue;
            final eta = DateTime.tryParse('${e['eta'] ?? ''}');
            if (eta == null) continue;
            final key = '$r->$dest';
            routeLines.putIfAbsent(
              key,
              () => '  • $r 往$dest：${_etaText(eta)}',
            );
            if (routeLines.length >= 6) break;
          }
        } catch (_) {}
        if (routeLines.length >= 6) break;
      }

      if (routeLines.isEmpty) {
        out.writeln('  • 暫無即將到站班次預報');
      } else {
        for (final line in routeLines.values) {
          out.writeln(line);
        }
      }
    }
    out.write('\n提示：香港專營巴士全線均配備輪椅斜板及低地台輪椅泊位。');
    return out.toString().trim();
  }

  /// Pre-departure Point-to-Point Accessible Bus Route Planner:
  /// Finds direct bus routes from [originText] (or current GPS) to [destinationText],
  /// showing boarding stop, alighting stop, stop count, and live next arrival ETA!
  Future<String> planPointToPoint({
    String? originText,
    required String destinationText,
    double? userLat,
    double? userLon,
  }) async {
    final destQuery = destinationText.trim();
    if (destQuery.isEmpty) {
      return '請輸入或講出你想去嘅目的地（例如：威爾斯親王醫院、沙田、旺角、銅鑼灣）。';
    }

    _Place? originPlace;
    final cleanOrig = (originText ?? '').trim();
    if (cleanOrig.isEmpty ||
        cleanOrig == '目前位置' ||
        cleanOrig == '附近' ||
        cleanOrig == '呢度' ||
        cleanOrig == '這裏') {
      if (userLat != null && userLon != null) {
        originPlace = _Place(name: '目前 GPS 位置', lat: userLat, lon: userLon);
      }
    }
    if (originPlace == null && cleanOrig.isNotEmpty) {
      originPlace = _matchPlace(cleanOrig) ?? await _safeGeocode(cleanOrig);
    }
    if (originPlace == null) {
      if (userLat != null && userLon != null) {
        originPlace = _Place(name: '目前 GPS 位置', lat: userLat, lon: userLon);
      } else {
        return '未能確認出發位置。請允許 GPS 定位，或者輸入出發地區（例如：大埔、荃灣、觀塘）。';
      }
    }

    final destPlace = _matchPlace(destQuery) ?? await _safeGeocode(destQuery);
    if (destPlace == null) {
      return '搵唔到目的地「$destQuery」嘅香港位置，請試下講地區或醫院名稱（例如：沙田、瑪麗醫院、銅鑼灣）。';
    }

    await _ensureRoutes();
    await _ensureKmbStops();
    final stopsMap = _kmbStops ?? const <String, _Stop>{};

    // Collect stops near Origin (<= 650m) and near Destination (<= 650m)
    final origStopDist = <String, double>{};
    final destStopDist = <String, double>{};
    for (final s in stopsMap.values) {
      if (s.lat == null || s.lon == null) continue;
      final dOrig = _haversineM(originPlace.lat, originPlace.lon, s.lat!, s.lon!);
      if (dOrig <= 680) origStopDist[s.id] = dOrig;
      final dDest = _haversineM(destPlace.lat, destPlace.lon, s.lat!, s.lon!);
      if (dDest <= 680) destStopDist[s.id] = dDest;
    }

    // Fetch live route-Data from nearest 5 origin stops to discover candidate routes fast!
    final sortedOrigIds = origStopDist.keys.toList()
      ..sort((a, b) => origStopDist[a]!.compareTo(origStopDist[b]!));
    final candidateRoutes = <String>{};
    for (final stopId in sortedOrigIds.take(5)) {
      try {
        final root = await _getJson('$_kmbBase/stop-eta/$stopId');
        for (final e in ((root['data'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()) {
          final r = '${e['route'] ?? ''}'.trim().toUpperCase();
          if (r.isNotEmpty) candidateRoutes.add(r);
        }
      } catch (_) {}
    }

    // Also include variants matching origin/dest text keywords (covers CTB/NLB too)
    final allVariants = _dedupe(_variants ?? const <_Variant>[]);
    for (final v in allVariants) {
      final textMatch = (v.destTc.contains(destPlace.name) ||
              destQuery.contains(v.destTc)) &&
          (cleanOrig.isEmpty ||
              v.origTc.contains(originPlace.name) ||
              cleanOrig.contains(v.origTc));
      if (textMatch) candidateRoutes.add(v.route);
    }

    final suggestions = <String>[];
    final checkedVariants = allVariants
        .where((v) =>
            (v.operator == 'KMB' && candidateRoutes.contains(v.route)) ||
            (v.destTc.contains(destPlace.name)))
        .take(28)
        .toList();

    for (final v in checkedVariants) {
      try {
        final rStops = await _stopsFor(v);
        if (rStops.length < 2) continue;
        int? boardIdx;
        double bestBoardDist = 99999;
        int? alightIdx;
        double bestAlightDist = 99999;

        for (var i = 0; i < rStops.length; i++) {
          final st = rStops[i];
          final od = origStopDist[st.id];
          if (od != null && od < bestBoardDist) {
            bestBoardDist = od;
            boardIdx = i;
          } else if (v.operator != 'KMB' &&
              cleanOrig.isNotEmpty &&
              st.nameTc.contains(originPlace.name) &&
              boardIdx == null) {
            boardIdx = i;
            bestBoardDist = 0;
          }
        }
        if (boardIdx == null) continue;

        for (var j = boardIdx + 1; j < rStops.length; j++) {
          final st = rStops[j];
          final dd = destStopDist[st.id];
          if (dd != null && dd < bestAlightDist) {
            bestAlightDist = dd;
            alightIdx = j;
          } else if (st.nameTc.contains(destPlace.name) && alightIdx == null) {
            alightIdx = j;
            bestAlightDist = 0;
          }
        }

        if (alightIdx != null && alightIdx > boardIdx) {
          final boardStop = rStops[boardIdx];
          final alightStop = rStops[alightIdx];
          final hopCount = alightIdx - boardIdx;
          final etas = await _etasFor(v, boardStop);
          final nextEta = etas.isNotEmpty ? _etaText(etas.first.eta) : '暫無即時預報';
          final distNote = bestBoardDist < 9000 && bestBoardDist > 0
              ? '（步行約 ${bestBoardDist.round()} 米）'
              : '';
          suggestions.add(
            '🚌 ${_operatorName(v.operator)} ${v.route}（往 ${v.destTc}）\n'
            '   上車：${_display(boardStop)}$distNote\n'
            '   落車：${_display(alightStop)}（途經 $hopCount 個站）\n'
            '   下班車：$nextEta',
          );
          if (suggestions.length >= 4) break;
        }
      } catch (_) {}
    }

    if (suggestions.isEmpty) {
      return '由「${originPlace.name}」前往「${destPlace.name}」暫未搵到 650 米內直達專營巴士線，'
          '建議可分兩段轉乘港鐵或低地台巴士，或試下輸入更具體地標名稱。';
    }

    return '出發前無障礙路線建議（${originPlace.name} → ${destPlace.name}）：\n\n'
        '${suggestions.join('\n\n')}\n\n'
        '提示：輪椅使用者上車前可向車長示意放下斜板。';
  }

  Future<_Place?> _safeGeocode(String q) async {
    try {
      return await _geocodePlace(q);
    } catch (_) {
      return null;
    }
  }

  double _haversineM(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return 2 * r * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  Future<String> busEta({
    required String route,
    String? operator,
    String? direction,
    String? stop,
    double? userLat,
    double? userLon,
  }) async {
    final r = route.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{1,6}$').hasMatch(r)) {
      return '路線格式無效，請提供巴士路線號碼（例如 1A、5B）。';
    }
    await _ensureRoutes();
    var variants =
        (_variants ?? const <_Variant>[]).where((v) => v.route == r).toList();
    if (variants.isEmpty) {
      return '找不到路線 $r（已查九巴／龍運、城巴、嶼巴）。';
    }
    variants = _dedupe(variants);
    final op = _operatorCode(operator);
    if (op != null) {
      variants = variants.where((v) => v.operator == op).toList();
      if (variants.isEmpty) {
        return '路線 $r 不屬於${_operatorName(op)}；請確認營辦商。';
      }
    }

    final dir = (direction ?? '').trim();
    if (dir.isNotEmpty) {
      variants = _preferGeneric(_dedupe(_matchDirection(variants, dir)));
      if (variants.isEmpty) {
        return '路線 $r 找不到方向「$dir」。請確認目的地，或講出營辦商。';
      }
    }
    if (variants.length > 1) {
      final what = op == null ? '多個公司／方向' : '多個方向';
      return '路線 $r 有$what，請問是哪一個？\n'
          '${_variantList(variants)}\n'
          '例如「城巴 5B 往銅鑼灣」或「九巴 1A 往尖沙咀」。';
    }
    final variant = variants.single;

    final stops = await _stopsFor(variant);
    if (stops.isEmpty) {
      return '${_operatorName(variant.operator)} $r 的站表暫時無法取得，請稍後再試。';
    }
    final q = (stop ?? '').trim();
    if (q.isEmpty && userLat != null && userLon != null) {
      _Stop? closest;
      var minD = 999999.0;
      for (final st in stops) {
        final kmb = _kmbStops?[st.id];
        final lat = st.lat ?? kmb?.lat;
        final lon = st.lon ?? kmb?.lon;
        if (lat == null || lon == null) continue;
        final d = _haversineM(userLat, userLon, lat, lon);
        if (d < minD) {
          minD = d;
          closest = st;
        }
      }
      if (closest != null && minD <= 1500) {
        final etas = await _etasFor(variant, closest);
        final b = StringBuffer()
          ..writeln('${_operatorName(variant.operator)} ${variant.route} 往 ${variant.destTc}')
          ..writeln('最近上車站（GPS 約 ${minD.round()} 米）：${_display(closest)}');
        if (etas.isEmpty) {
          b.writeln('暫無可確認的到站預測。');
        } else {
          for (var i = 0; i < etas.length && i < 4; i++) {
            b.writeln('${i + 1}. ${_etaText(etas[i].eta)}');
          }
        }
        return b.toString().trim();
      }
    }
    if (q.isEmpty) {
      final head = stops.take(15).toList();
      return '${_operatorName(variant.operator)} $r 往 ${variant.destTc}，'
          '共 ${stops.length} 站。請講上車站名，例如「旺角」。\n'
          '${head.asMap().entries.map((e) => '${e.key + 1}. ${_display(e.value)}').join('\n')}'
          '${stops.length > head.length ? '\n…其餘 ${stops.length - head.length} 站' : ''}';
    }
    final matched = _matchStops(stops, q);
    if (matched.isEmpty) {
      return '${_operatorName(variant.operator)} $r 往 ${variant.destTc} 的站表'
          '找不到「$q」。\n站表例子：${stops.take(8).map(_display).join('、')}…';
    }
    final groups = <String, List<_Stop>>{};
    for (final s in matched) {
      groups.putIfAbsent(_display(s), () => []).add(s);
    }
    if (groups.length > 1) {
      final entries = groups.entries.take(6).toList();
      return '「$q」有多個符合的站：\n'
          '${entries.asMap().entries.map((e) => '${e.key + 1}. ${e.value.key}').join('\n')}\n'
          '請講是哪一個。';
    }
    final selected = groups.values.first.first;

    final etas = await _etasFor(variant, selected);
    final b = StringBuffer()
      ..writeln('${_operatorName(variant.operator)} ${variant.route} '
          '往 ${variant.destTc}')
      ..writeln('上車站：${_display(selected)}');
    if (etas.isEmpty) {
      b.writeln('暫無可確認的到站預測（不代表停駛）。');
    } else {
      for (var i = 0; i < etas.length && i < 6; i++) {
        b.writeln('${i + 1}. ${_etaText(etas[i].eta)}');
      }
    }
    final remarks = etas
        .map((e) => e.remark.trim())
        .where((s) => s.isNotEmpty)
        .toSet();
    if (remarks.isNotEmpty) b.writeln('備註：${remarks.join('；')}');
    final timestamps = etas
        .map((e) => e.dataTime)
        .whereType<DateTime>()
        .toSet()
        .toList();
    if (timestamps.isNotEmpty) {
      b.writeln('資料時間：${_hkText(timestamps.first)}');
    }
    b.write('來源：${_operatorName(variant.operator)}開放資料；到站時間為估算。');
    return b.toString().trim();
  }

  Future<void> _ensureRoutes() async {
    final now = DateTime.now();
    if (_variants != null &&
        _routesAt != null &&
        now.difference(_routesAt!) < const Duration(hours: 1)) {
      return;
    }
    final results = await Future.wait([
      _getJson('$_kmbBase/route/'),
      _getJson('$_rtBase/citybus/route/CTB'),
      _getJson('$_rtBase/nlb/route.php?action=list'),
    ]);
    final list = <_Variant>[];
    for (final e in ((results[0]['data'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()) {
      list.add(_Variant.fromKmb(e));
    }
    for (final e in ((results[1]['data'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()) {
      final v = _Variant.fromCtb(e);
      list
        ..add(v)
        ..add(v.reversed());
    }
    for (final e in ((results[2]['routes'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()) {
      list.add(_Variant.fromNlb(e));
    }
    try {
      final csv = await _getText(
          'https://opendata.mtr.com.hk/data/mtr_bus_stops.csv');
      _addMtrVariants(csv, list);
    } catch (_) {
      // MTR Bus is optional; keep KMB/CTB/NLB available if its CSV is down.
    }
    final seen = <String>{};
    _variants = list.where((v) => seen.add(v.key)).toList();
    _routesAt = now;
  }

  Future<List<_Stop>> _stopsFor(_Variant v) async {
    final key = '${v.operator}:${v.key}';
    final cached = _routeStops[key];
    if (cached != null) return cached;

    List<_Stop> result;
    if (v.operator == 'KMB') {
      await _ensureKmbStops();
      final bound = v.bound == 'O' ? 'outbound' : 'inbound';
      final root = await _getJson(
          '$_kmbBase/route-stop/${v.route}/$bound/${v.serviceType}');
      final rows = ((root['data'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(_RouteStop.fromJson)
          .toList()
        ..sort((a, b) => a.seq.compareTo(b.seq));
      result = rows
          .map((e) => _kmbStops?[e.stopId])
          .whereType<_Stop>()
          .toList(growable: false);
    } else if (v.operator == 'CTB') {
      final bound = v.bound == 'O' ? 'outbound' : 'inbound';
      final root =
          await _getJson('$_rtBase/citybus/route-stop/CTB/${v.route}/$bound');
      final rows = ((root['data'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .toList()
        ..sort((a, b) =>
            (int.tryParse('${a['seq']}') ?? 0)
                .compareTo(int.tryParse('${b['seq']}') ?? 0));
      final stops = await Future.wait(
          rows.map((e) => _ctbStop('${e['stop']}')));
      result = stops.whereType<_Stop>().toList(growable: false);
    } else if (v.operator == 'NLB') {
      final root = await _getJson(
          '$_rtBase/nlb/stop.php?action=list&routeId=${v.routeId}');
      result = ((root['stops'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(_Stop.fromNlb)
          .toList(growable: false);
    } else {
      result = _mtrStops['${v.route}:${v.bound}'] ?? const [];
    }
    _routeStops[key] = result;
    return result;
  }

  Future<void> _ensureKmbStops() async {
    final now = DateTime.now();
    if (_kmbStops != null &&
        _kmbStopsAt != null &&
        now.difference(_kmbStopsAt!) < const Duration(hours: 1)) {
      return;
    }
    final root = await _getJson('$_kmbBase/stop/');
    _kmbStops = {
      for (final e in ((root['data'] as List?) ?? const [])
          .cast<Map<String, dynamic>>())
        '${e['stop']}': _Stop.fromKmb(e),
    };
    _kmbStopsAt = now;
  }

  Future<_Stop?> _ctbStop(String id) async {
    final cached = _ctbStops[id];
    if (cached != null) return cached;
    try {
      final root = await _getJson('$_rtBase/citybus/stop/$id');
      final data = (root['data'] as Map?)?.cast<String, dynamic>();
      if (data == null) return null;
      final s = _Stop(
        id: id,
        nameTc: '${data['name_tc'] ?? ''}',
        nameEn: '${data['name_en'] ?? ''}',
        lat: double.tryParse('${data['lat'] ?? ''}'),
        lon: double.tryParse('${data['long'] ?? ''}'),
      );
      _ctbStops[id] = s;
      return s;
    } catch (_) {
      return null;
    }
  }

  Future<List<_Eta>> _etasFor(_Variant v, _Stop stop) async {
    final list = <_Eta>[];
    if (v.operator == 'KMB') {
      final root = await _getJson('$_kmbBase/stop-eta/${stop.id}');
      for (final e in ((root['data'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()) {
        if ('${e['route']}'.toUpperCase() != v.route) continue;
        if ('${e['dir']}'.toUpperCase() != v.bound) continue;
        if ((int.tryParse('${e['service_type']}') ?? 1) != v.serviceType) {
          continue;
        }
        list.add(_Eta(
          dest: '${e['dest_tc'] ?? v.destTc}',
          eta: DateTime.tryParse('${e['eta'] ?? ''}'),
          remark: '${e['rmk_tc'] ?? ''}',
          dataTime: DateTime.tryParse('${e['data_timestamp'] ?? ''}'),
        ));
      }
    } else if (v.operator == 'CTB') {
      final root =
          await _getJson('$_rtBase/citybus/eta/CTB/${stop.id}/${v.route}');
      for (final e in ((root['data'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()) {
        if ('${e['dir']}'.toUpperCase() != v.bound) continue;
        list.add(_Eta(
          dest: '${e['dest_tc'] ?? v.destTc}',
          eta: DateTime.tryParse('${e['eta'] ?? ''}'),
          remark: '${e['rmk_tc'] ?? ''}',
          dataTime: DateTime.tryParse('${e['data_timestamp'] ?? ''}'),
        ));
      }
    } else if (v.operator == 'MTR') {
      final root = await _postJson(
          'https://rt.data.gov.hk/v1/transport/mtr/bus/getSchedule',
          {'language': 'zh', 'routeName': v.route});
      final stops = ((root['busStop'] as List?) ?? const [])
          .cast<Map<String, dynamic>>();
      final dataTime = _parseTime('${root['routeStatusTime'] ?? ''}');
      for (final entry in stops) {
        if ('${entry['busStopId']}' != stop.id) continue;
        for (final bus in ((entry['bus'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()) {
          final seconds = _mtrSeconds(bus);
          if (seconds == null) continue;
          list.add(_Eta(
            dest: v.destTc,
            eta: DateTime.now().add(Duration(seconds: seconds)),
            remark: '${bus['isDelayed']}' == '1' ? '延誤' : '',
            dataTime: dataTime,
          ));
        }
      }
    } else {
      final root = await _getJson(
          '$_rtBase/nlb/stop.php?action=estimatedArrivals'
          '&routeId=${v.routeId}&stopId=${stop.id}&language=zh');
      for (final e in ((root['estimatedArrivals'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()) {
        list.add(_Eta(
          dest: '${e['routeVariantName'] ?? v.destTc}',
          eta: DateTime.tryParse('${e['estimatedArrivalTime'] ?? ''}'),
          remark: '',
          dataTime: DateTime.tryParse('${e['generateTime'] ?? ''}'),
        ));
      }
    }
    list.sort((a, b) {
      final x = a.eta;
      final y = b.eta;
      if (x == null && y == null) return 0;
      if (x == null) return 1;
      if (y == null) return -1;
      return x.compareTo(y);
    });
    return list.where((e) => e.eta != null).toList(growable: false);
  }

  Future<Map<String, dynamic>> _getJson(String url) async {
    final res = await http
        .get(Uri.parse(url), headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 25));
    if (res.statusCode != 200) {
      throw StateError('HTTP ${res.statusCode}');
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _postJson(
      String url, Map<String, dynamic> body) async {
    final res = await http
        .post(
          Uri.parse(url),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 25));
    if (res.statusCode != 200) {
      throw StateError('HTTP ${res.statusCode}');
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  Future<String> _getText(String url) async {
    final res = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 25));
    if (res.statusCode != 200) {
      throw StateError('HTTP ${res.statusCode}');
    }
    return utf8.decode(res.bodyBytes);
  }

  void _addMtrVariants(String csv, List<_Variant> out) {
    final rows = _parseCsv(csv);
    if (rows.isEmpty) return;
    final header = rows.first
        .map((e) => e.replaceFirst('\uFEFF', '').trim())
        .toList();
    int col(String name) => header.indexOf(name);
    final ri = col('ROUTE_ID');
    final di = col('DIRECTION');
    final si = col('STATION_SEQNO');
    final ii = col('STATION_ID');
    final ci = col('STATION_NAME_CHI');
    final ei = col('STATION_NAME_ENG');
    if (ri < 0 || di < 0 || si < 0 || ii < 0) return;

    final groups = <String, List<List<String>>>{};
    for (final row in rows.skip(1)) {
      if (row.length <= ri ||
          row.length <= di ||
          row.length <= si ||
          row.length <= ii) {
        continue;
      }
      final route = row[ri].trim().toUpperCase();
      final direction = row[di].trim().toUpperCase();
      if (route.isEmpty || direction.isEmpty) continue;
      groups.putIfAbsent('$route:$direction', () => []).add(row);
    }
    groups.forEach((key, list) {
      list.sort((a, b) => (int.tryParse(a[si]) ?? 0)
          .compareTo(int.tryParse(b[si]) ?? 0));
      final stops = list
          .map((r) => _Stop(
                id: r[ii].trim(),
                nameTc: ci >= 0 ? r[ci].trim() : '',
                nameEn: ei >= 0 ? r[ei].trim() : '',
              ))
          .toList(growable: false);
      if (stops.isEmpty) return;
      final parts = key.split(':');
      _mtrStops[key] = stops;
      out.add(_Variant(
        operator: 'MTR',
        route: parts[0],
        bound: parts[1],
        serviceType: 1,
        origTc: stops.first.nameTc,
        destTc: stops.last.nameTc,
        origEn: stops.first.nameEn,
        destEn: stops.last.nameEn,
        routeId: key,
      ));
    });
  }

  List<List<String>> _parseCsv(String input) {
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var quoted = false;
    for (var i = 0; i < input.length; i++) {
      final c = input[i];
      if (quoted) {
        if (c == '"') {
          if (i + 1 < input.length && input[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            quoted = false;
          }
        } else {
          field.write(c);
        }
      } else if (c == '"') {
        quoted = true;
      } else if (c == ',') {
        row.add(field.toString());
        field.clear();
      } else if (c == '\n') {
        row.add(field.toString());
        field.clear();
        if (row.isNotEmpty) rows.add(row);
        row = <String>[];
      } else if (c != '\r') {
        field.write(c);
      }
    }
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      rows.add(row);
    }
    return rows;
  }

  DateTime? _parseTime(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s.replaceAll('/', '-'));
  }

  int? _mtrSeconds(Map<String, dynamic> bus) {    final values = [
      int.tryParse('${bus['arrivalTimeInSecond'] ?? ''}') ?? 0,
      int.tryParse('${bus['departureTimeInSecond'] ?? ''}') ?? 0,
    ].where((v) => v > 0 && v < 86400).toList()
      ..sort();
    return values.isEmpty ? null : values.first;
  }

  List<_Variant> _preferGeneric(List<_Variant> list) {
    final groups = <String, List<_Variant>>{};
    for (final v in list) {
      groups
          .putIfAbsent('${v.operator}:${v.route}:${v.destTc}', () => [])
          .add(v);
    }
    final out = <_Variant>[];
    for (final group in groups.values) {
      if (group.length == 1) {
        out.add(group.first);
        continue;
      }
      final generic = group
          .where((v) => group.every(
              (o) => o.origTc == v.origTc || o.origTc.startsWith(v.origTc)))
          .toList();
      if (generic.isEmpty) {
        out.addAll(group);
      } else {
        generic.sort((a, b) => a.origTc.length.compareTo(b.origTc.length));
        out.add(generic.first);
      }
    }
    return out;
  }

  List<_Variant> _dedupe(List<_Variant> list) {
    final map = <String, _Variant>{};
    for (final v in list) {
      final key =
          '${v.operator}:${v.route}:${v.bound}:${v.origTc}:${v.destTc}';
      final existing = map[key];
      if (existing == null ||
          (existing.serviceType != 1 && v.serviceType == 1)) {
        map[key] = v;
      }
    }
    return map.values.toList(growable: false);
  }

  List<_Variant> _matchDirection(List<_Variant> list, String query) {
    final n = _norm(query);
    if (n == 'o' || n == 'outbound' || n.contains('去程')) {
      return list.where((v) => v.bound == 'O').toList();
    }
    if (n == 'i' || n == 'inbound' || n.contains('回程')) {
      return list.where((v) => v.bound == 'I').toList();
    }
    bool hit(String s) {
      final t = _norm(s);
      return t.isNotEmpty && (t.contains(n) || n.contains(t));
    }

    final fromOnly =
        n.startsWith('由') || n.startsWith('從') || n.startsWith('from');
    final destinations =
        list.where((v) => hit(v.destTc) || hit(v.destEn)).toList();
    final origins = list.where((v) => hit(v.origTc) || hit(v.origEn)).toList();
    if (fromOnly) return origins.isNotEmpty ? origins : destinations;
    return destinations.isNotEmpty ? destinations : origins;
  }

  List<_Stop> _matchStops(List<_Stop> pool, String query) {
    final q = _norm(query);
    if (q.isEmpty) return const [];
    final exact = pool
        .where((s) => _norm(s.nameTc) == q || _norm(s.nameEn) == q)
        .toList();
    if (exact.isNotEmpty) return exact;
    return pool
        .where((s) =>
            _norm(s.nameTc).contains(q) ||
            _norm(s.nameEn).contains(q) ||
            _norm(_display(s)).contains(q) ||
            q.contains(_norm(_display(s))))
        .toList();
  }

  String _variantList(List<_Variant> variants) => variants
      .take(8)
      .toList()
      .asMap()
      .entries
      .map((e) => '${e.key + 1}. ${_operatorName(e.value.operator)} '
          '${e.value.route}：${e.value.origTc} → ${e.value.destTc}')
      .join('\n');

  String? _operatorCode(String? raw) {
    final s = (raw ?? '').trim().toLowerCase();
    if (s.isEmpty) return null;
    if (s.contains('九巴') ||
        s.contains('kmb') ||
        s.contains('龍運') ||
        s.contains('lwb')) {
      return 'KMB';
    }
    if (s.contains('城巴') ||
        s.contains('ctb') ||
        s.contains('新巴') ||
        s.contains('citybus')) {
      return 'CTB';
    }
    if (s.contains('嶼巴') || s.contains('nlb') || s.contains('大嶼山')) {
      return 'NLB';
    }
    if (s.contains('港鐵') ||
        s.contains('港铁') ||
        s.contains('mtr') ||
        s.contains('輕鐵') ||
        s.contains('轻铁')) {
      return 'MTR';
    }
    return null;
  }

  String _operatorName(String op) => switch (op) {
        'CTB' => '城巴',
        'NLB' => '嶼巴',
        'MTR' => '港鐵巴士',
        _ => '九巴／龍運',
      };

  String _cleanPlaceQuery(String raw) {
    var q = raw.trim().toLowerCase();
    for (final w in const [
      '天氣',
      '幾多度',
      '幾度',
      '溫度',
      '預報',
      '今日',
      '今天',
      '明天',
      '現在',
      '而家',
      '點',
      '呀',
      '？',
      '?',
    ]) {
      q = q.replaceAll(w, '');
    }
    return q.replaceAll(RegExp(r'\s+'), '');
  }

  _Place? _matchPlace(String? raw) {
    if (raw == null) return null;
    final q = _cleanPlaceQuery(raw);
    if (q.isEmpty) return null;
    String? best;
    for (final name in _places.keys) {
      final n = name.toLowerCase();
      if (q == n) return _placeOf(name);
      if (q.contains(n) || n.contains(q)) {
        if (best == null || name.length > best.length) best = name;
      }
    }
    return best == null ? null : _placeOf(best);
  }

  Future<_Place?> _geocodePlace(String raw) async {
    final q = _cleanPlaceQuery(raw);
    if (q.isEmpty) return null;
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': q,
      'format': 'jsonv2',
      'limit': '5',
      'accept-language': 'zh-Hant',
    });
    final res = await http.get(
      uri,
      headers: const {'User-Agent': 'FYP-EyeTracking/1.0 (weather lookup)'},
    ).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) return null;
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as List?;
    if (data == null) return null;
    for (final e in data.cast<Map<String, dynamic>>()) {
      final lat = double.tryParse('${e['lat']}');
      final lon = double.tryParse('${e['lon']}');
      if (lat == null || lon == null) continue;
      // Restrict to Hong Kong's bounding box.
      if (lat < 22.1 || lat > 22.6 || lon < 113.8 || lon > 114.5) continue;
      return _Place(name: q, lat: lat, lon: lon);
    }
    return null;
  }

  _Place _placeOf(String name) {
    final c = _places[name] ?? _places['香港']!;
    return _Place(name: name, lat: c[0], lon: c[1]);
  }

  String _display(_Stop s) {
    final n =
        s.nameTc.replaceAll(RegExp(r'\s*[（(][^）)]*[）)]\s*'), '').trim();
    return n.isEmpty ? s.nameTc : n;
  }

  String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[（(][^）)]*[）)]'), '')
      .replaceAll(RegExp(r'\s+'), '')
      .trim();

  String _etaText(DateTime? t) {
    if (t == null) return '時間未知';
    final seconds = t.difference(DateTime.now()).inSeconds;
    final minutes = seconds <= 30 ? 0 : (seconds / 60).round();
    final hhmm = _hhmm(t);
    return minutes <= 0 ? '即將到站（$hhmm）' : '約 $minutes 分鐘（$hhmm）';
  }

  String _hkText(DateTime t) {
    final hk = t.toUtc().add(const Duration(hours: 8));
    return '${hk.year}-${_two(hk.month)}-${_two(hk.day)} ${_hhmm(t)}';
  }

  String _hhmm(DateTime t) {
    final hk = t.toUtc().add(const Duration(hours: 8));
    return '${_two(hk.hour)}:${_two(hk.minute)}';
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  String _num(dynamic v) {
    if (v is num) {
      return v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1);
    }
    return '—';
  }

  String _weatherCode(dynamic raw) {
    final code = raw is num ? raw.toInt() : int.tryParse('$raw') ?? -1;
    return switch (code) {
      0 => '晴朗',
      1 => '大致晴朗',
      2 => '局部多雲',
      3 => '陰天',
      45 || 48 => '有霧',
      51 || 53 || 55 => '毛毛雨',
      56 || 57 => '凍毛毛雨',
      61 || 63 || 65 => '有雨',
      66 || 67 => '凍雨',
      71 || 73 || 75 || 77 => '有雪',
      80 || 81 || 82 => '驟雨',
      85 || 86 => '驟雪',
      95 => '雷暴',
      96 || 99 => '雷暴伴冰雹',
      _ => '天氣代碼 $code（未知描述）',
    };
  }
}

class _Variant {
  const _Variant({
    required this.operator,
    required this.route,
    required this.bound,
    required this.serviceType,
    required this.origTc,
    required this.destTc,
    required this.origEn,
    required this.destEn,
    this.routeId,
  });

  final String operator;
  final String route;
  final String bound;
  final int serviceType;
  final String origTc;
  final String destTc;
  final String origEn;
  final String destEn;
  final String? routeId;

  String get key =>
      '$operator:$route:${bound.isEmpty ? routeId : bound}:$serviceType';

  _Variant reversed() => _Variant(
        operator: operator,
        route: route,
        bound: 'I',
        serviceType: serviceType,
        origTc: destTc,
        destTc: origTc,
        origEn: destEn,
        destEn: origEn,
      );

  factory _Variant.fromKmb(Map<String, dynamic> j) => _Variant(
        operator: 'KMB',
        route: '${j['route'] ?? ''}'.trim().toUpperCase(),
        bound: '${j['bound'] ?? ''}'.trim().toUpperCase(),
        serviceType: int.tryParse('${j['service_type'] ?? 1}') ?? 1,
        origTc: '${j['orig_tc'] ?? ''}',
        destTc: '${j['dest_tc'] ?? ''}',
        origEn: '${j['orig_en'] ?? ''}',
        destEn: '${j['dest_en'] ?? ''}',
      );

  factory _Variant.fromCtb(Map<String, dynamic> j) => _Variant(
        operator: 'CTB',
        route: '${j['route'] ?? ''}'.trim().toUpperCase(),
        bound: 'O',
        serviceType: 1,
        origTc: '${j['orig_tc'] ?? ''}',
        destTc: '${j['dest_tc'] ?? ''}',
        origEn: '${j['orig_en'] ?? ''}',
        destEn: '${j['dest_en'] ?? ''}',
      );

  factory _Variant.fromNlb(Map<String, dynamic> j) {
    final name = '${j['routeName_c'] ?? ''}';
    final parts = name.split('>');
    return _Variant(
      operator: 'NLB',
      route: '${j['routeNo'] ?? ''}'.trim().toUpperCase(),
      bound: '',
      serviceType: 1,
      origTc: parts.isNotEmpty ? parts.first.trim() : '',
      destTc: parts.length > 1 ? parts.sublist(1).join('>').trim() : name,
      origEn: '',
      destEn: '',
      routeId: '${j['routeId'] ?? ''}',
    );
  }
}

class _Stop {
  const _Stop({
    required this.id,
    required this.nameTc,
    required this.nameEn,
    this.lat,
    this.lon,
  });

  final String id;
  final String nameTc;
  final String nameEn;
  final double? lat;
  final double? lon;

  factory _Stop.fromKmb(Map<String, dynamic> j) => _Stop(
        id: '${j['stop'] ?? ''}',
        nameTc: '${j['name_tc'] ?? ''}',
        nameEn: '${j['name_en'] ?? ''}',
        lat: double.tryParse('${j['lat'] ?? ''}'),
        lon: double.tryParse('${j['long'] ?? ''}'),
      );

  factory _Stop.fromNlb(Map<String, dynamic> j) => _Stop(
        id: '${j['stopId'] ?? ''}',
        nameTc: '${j['stopName_c'] ?? ''}',
        nameEn: '${j['stopName_e'] ?? ''}',
      );
}

class _RouteStop {
  const _RouteStop({required this.seq, required this.stopId});

  final int seq;
  final String stopId;

  factory _RouteStop.fromJson(Map<String, dynamic> j) => _RouteStop(
        seq: int.tryParse('${j['seq'] ?? 0}') ?? 0,
        stopId: '${j['stop'] ?? ''}',
      );
}

class _Eta {
  const _Eta({
    required this.dest,
    required this.eta,
    required this.remark,
    required this.dataTime,
  });

  final String dest;
  final DateTime? eta;
  final String remark;
  final DateTime? dataTime;
}

class _Place {
  const _Place({required this.name, required this.lat, required this.lon});

  final String name;
  final double lat;
  final double lon;
}
