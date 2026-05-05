import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FakeGpsApp());
}

class FakeGpsApp extends StatelessWidget {
  const FakeGpsApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF256F63);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PinDrift',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F7F4),
        cardTheme: CardTheme(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD9DED8)),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const _channel = MethodChannel('fake_gps/location');
  static const _defaultNaverApiKey = String.fromEnvironment(
    'NAVER_MAPS_CLIENT_ID',
  );

  double _latitude = 37.5665;
  double _longitude = 126.9780;
  String _naverApiKey = '';
  bool _running = false;
  bool _loading = true;
  bool _mockLocationEnabled = false;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshMockLocationStatus();
    }
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _latitude = prefs.getDouble('latitude') ?? _latitude;
      _longitude = prefs.getDouble('longitude') ?? _longitude;
      _naverApiKey = _storedOrDefault(
        prefs.getString('naverApiKey'),
        _defaultNaverApiKey,
      );
      _loading = false;
    });
    await _refreshMockLocationStatus();
  }

  String _storedOrDefault(String? storedValue, String defaultValue) {
    final stored = storedValue?.trim();
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }
    return defaultValue.trim();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('latitude', _latitude);
    await prefs.setDouble('longitude', _longitude);
    await prefs.setString('naverApiKey', _naverApiKey.trim());
  }

  Future<void> _refreshMockLocationStatus() async {
    try {
      final enabled = await _channel.invokeMethod<bool>(
        'isMockLocationEnabled',
      );
      if (mounted) {
        setState(() => _mockLocationEnabled = enabled ?? false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _mockLocationEnabled = false);
      }
    }
  }

  Future<void> _openDeveloperSettings() async {
    try {
      await _channel.invokeMethod('openDeveloperSettings');
    } on PlatformException catch (error) {
      _showMessage(error.message ?? '개발자 옵션을 열 수 없습니다.');
    }
  }

  Future<void> _setPosition(double latitude, double longitude) async {
    await _setPositionInternal(latitude, longitude, updateRunningMock: true);
  }

  Future<void> _setPositionOnly(double latitude, double longitude) async {
    await _setPositionInternal(latitude, longitude, updateRunningMock: false);
  }

  Future<void> _setPositionInternal(
    double latitude,
    double longitude, {
    required bool updateRunningMock,
  }) async {
    setState(() {
      _latitude = latitude;
      _longitude = longitude;
    });
    await _save();
    if (_running && updateRunningMock) {
      await _startMocking();
    }
  }

  Future<void> _startMocking() async {
    await _refreshMockLocationStatus();
    if (!_mockLocationEnabled) {
      await _showMockLocationDialog();
      return;
    }

    try {
      await _channel.invokeMethod('startMockLocation', {
        'latitude': _latitude,
        'longitude': _longitude,
      });
      setState(() => _running = true);
      _showMessage('가상 위치가 적용되었습니다.');
    } on PlatformException catch (error) {
      if (error.code == 'MOCK_LOCATION_DISABLED') {
        await _showMockLocationDialog();
        return;
      }
      _showMessage(error.message ?? '가상 위치를 시작하지 못했습니다.');
    }
  }

  Future<void> _showMockLocationDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('모의 위치 설정 필요'),
          content: const Text(
            'Android 개발자 옵션에서 이 앱을 모의 위치 앱으로 선택해야 시스템 위치를 변경할 수 있습니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('나중에'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                _openDeveloperSettings();
              },
              child: const Text('메뉴로 이동'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _stopMocking() async {
    setState(() => _running = false);
    try {
      await _channel.invokeMethod('stopMockLocation');
      _showMessage('가상 위치를 중지했습니다.');
    } on PlatformException catch (error) {
      setState(() => _running = true);
      _showMessage(error.message ?? '가상 위치를 중지하지 못했습니다.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pages = [
      MapPage(
        latitude: _latitude,
        longitude: _longitude,
        naverApiKey: _naverApiKey,
        running: _running,
        mockLocationEnabled: _mockLocationEnabled,
        onPositionChanged: _setPosition,
        onPositionPreviewChanged: _setPositionOnly,
        onStart: _startMocking,
        onStop: _stopMocking,
        onOpenDeveloperSettings: _openDeveloperSettings,
        onRefreshMockLocationStatus: _refreshMockLocationStatus,
      ),
      SettingsPage(
        naverApiKey: _naverApiKey,
        mockLocationEnabled: _mockLocationEnabled,
        onChanged: (naverKey) async {
          setState(() {
            _naverApiKey = naverKey;
          });
          await _save();
        },
        onOpenDeveloperSettings: _openDeveloperSettings,
        onRefreshMockLocationStatus: _refreshMockLocationStatus,
      ),
      const ApiGuidePage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('PinDrift'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: StatusChip(running: _running),
          ),
        ],
      ),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: '지도',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: '설정',
          ),
          NavigationDestination(
            icon: Icon(Icons.help_outline),
            selectedIcon: Icon(Icons.help),
            label: '도움말',
          ),
        ],
      ),
    );
  }
}

class MapPage extends StatefulWidget {
  const MapPage({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.naverApiKey,
    required this.running,
    required this.mockLocationEnabled,
    required this.onPositionChanged,
    required this.onPositionPreviewChanged,
    required this.onStart,
    required this.onStop,
    required this.onOpenDeveloperSettings,
    required this.onRefreshMockLocationStatus,
  });

  final double latitude;
  final double longitude;
  final String naverApiKey;
  final bool running;
  final bool mockLocationEnabled;
  final Future<void> Function(double latitude, double longitude)
  onPositionChanged;
  final Future<void> Function(double latitude, double longitude)
  onPositionPreviewChanged;
  final Future<void> Function() onStart;
  final Future<void> Function() onStop;
  final Future<void> Function() onOpenDeveloperSettings;
  final Future<void> Function() onRefreshMockLocationStatus;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  static const _channel = MethodChannel('fake_gps/location');

  WebViewController? _controller;

  @override
  void initState() {
    super.initState();
    _configureMap();
  }

  @override
  void didUpdateWidget(covariant MapPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.naverApiKey != widget.naverApiKey) {
      _configureMap();
    }
  }

  void _configureMap() {
    final apiKey = widget.naverApiKey;
    if (apiKey.trim().isEmpty) {
      setState(() => _controller = null);
      return;
    }

    final controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..addJavaScriptChannel(
            'PositionPicker',
            onMessageReceived: (message) {
              final parts = message.message.split(',');
              if (parts.length != 2) return;
              final lat = double.tryParse(parts[0]);
              final lng = double.tryParse(parts[1]);
              if (lat == null || lng == null) return;
              widget.onPositionChanged(lat, lng);
            },
          )
          ..loadHtmlString(
            _mapHtml(apiKey.trim()),
            baseUrl: 'https://pindrift.local/',
          );
    setState(() => _controller = controller);
  }

  String _mapHtml(String apiKey) {
    final lat = widget.latitude.toStringAsFixed(7);
    final lng = widget.longitude.toStringAsFixed(7);
    return '''
<!doctype html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=yes">
  <script src="https://oapi.map.naver.com/openapi/v3/maps.js?ncpKeyId=$apiKey"></script>
  <style>html,body,#map{height:100%;margin:0}</style>
</head>
<body>
  <div id="map"></div>
  <script>
    const center = new naver.maps.LatLng($lat, $lng);
    const map = new naver.maps.Map('map', { center, zoom: 16, zoomControl: false });
    const marker = new naver.maps.Marker({ position: center, map });
    function selectPosition(latlng) {
      marker.setPosition(latlng);
      map.setCenter(latlng);
      PositionPicker.postMessage(latlng.lat() + ',' + latlng.lng());
    }
    function moveTo(lat, lng) {
      selectPosition(new naver.maps.LatLng(lat, lng));
    }
    function zoomIn() {
      map.setZoom(map.getZoom() + 1, true);
    }
    function zoomOut() {
      map.setZoom(map.getZoom() - 1, true);
    }
    naver.maps.Event.addListener(map, 'click', function(e) {
      selectPosition(e.coord);
    });
  </script>
</body>
</html>
''';
  }

  Future<void> _moveMap(double latitude, double longitude) async {
    await _controller?.runJavaScript('moveTo($latitude, $longitude);');
  }

  Future<void> _zoomIn() async {
    await _controller?.runJavaScript('zoomIn();');
  }

  Future<void> _zoomOut() async {
    await _controller?.runJavaScript('zoomOut();');
  }

  Future<void> _goToCurrentLocation() async {
    try {
      final value = await _channel.invokeMapMethod<String, Object?>(
        'getCurrentLocation',
      );
      final lat = value?['latitude'];
      final lng = value?['longitude'];
      if (lat is! num || lng is! num) {
        throw PlatformException(
          code: 'LOCATION_UNAVAILABLE',
          message: '현재 위치를 찾을 수 없습니다.',
        );
      }
      await widget.onPositionPreviewChanged(lat.toDouble(), lng.toDouble());
      await _moveMap(lat.toDouble(), lng.toDouble());
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? '현재 위치를 찾을 수 없습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final apiKey = widget.naverApiKey;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        MockLocationNotice(
          enabled: widget.mockLocationEnabled,
          onOpenSettings: widget.onOpenDeveloperSettings,
          onRefresh: widget.onRefreshMockLocationStatus,
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 360,
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned.fill(
                  child:
                      apiKey.trim().isEmpty || _controller == null
                          ? const EmptyMap()
                          : WebViewWidget(
                            controller: _controller!,
                            gestureRecognizers: LinkedHashSet.of({
                              Factory<OneSequenceGestureRecognizer>(
                                () => EagerGestureRecognizer(),
                              ),
                            }),
                          ),
                ),
                if (apiKey.trim().isNotEmpty && _controller != null)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: MapControlColumn(
                      onCurrentLocation: _goToCurrentLocation,
                      onZoomIn: _zoomIn,
                      onZoomOut: _zoomOut,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('위치 선택', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                const Text('지도를 움직여 탐색하고, 원하는 지점을 한 번 탭해 포인트를 지정하세요.'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: widget.running ? widget.onStop : widget.onStart,
                  icon: Icon(
                    widget.running
                        ? Icons.stop_circle_outlined
                        : Icons.play_circle_outline,
                  ),
                  label: Text(widget.running ? '가상 위치 중지' : '가상 위치 시작'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class MapControlColumn extends StatelessWidget {
  const MapControlColumn({
    super.key,
    required this.onCurrentLocation,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final Future<void> Function() onCurrentLocation;
  final Future<void> Function() onZoomIn;
  final Future<void> Function() onZoomOut;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      elevation: 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '현재 위치',
            onPressed: () => onCurrentLocation(),
            icon: const Icon(Icons.my_location),
          ),
          const Divider(height: 1),
          IconButton(
            tooltip: '확대',
            onPressed: () => onZoomIn(),
            icon: const Icon(Icons.add),
          ),
          const Divider(height: 1),
          IconButton(
            tooltip: '축소',
            onPressed: () => onZoomOut(),
            icon: const Icon(Icons.remove),
          ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.naverApiKey,
    required this.mockLocationEnabled,
    required this.onChanged,
    required this.onOpenDeveloperSettings,
    required this.onRefreshMockLocationStatus,
  });

  final String naverApiKey;
  final bool mockLocationEnabled;
  final Future<void> Function(String naverKey) onChanged;
  final Future<void> Function() onOpenDeveloperSettings;
  final Future<void> Function() onRefreshMockLocationStatus;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _naverController;

  @override
  void initState() {
    super.initState();
    _naverController = TextEditingController(text: widget.naverApiKey);
  }

  @override
  void dispose() {
    _naverController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await widget.onChanged(_naverController.text);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('설정을 저장했습니다.')));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        MockLocationNotice(
          enabled: widget.mockLocationEnabled,
          onOpenSettings: widget.onOpenDeveloperSettings,
          onRefresh: widget.onRefreshMockLocationStatus,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '네이버 지도 설정',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _naverController,
                  decoration: const InputDecoration(
                    labelText: 'Naver Maps ncpKeyId',
                    prefixIcon: Icon(Icons.key_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('저장'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class MockLocationNotice extends StatelessWidget {
  const MockLocationNotice({
    super.key,
    required this.enabled,
    required this.onOpenSettings,
    required this.onRefresh,
  });

  final bool enabled;
  final Future<void> Function() onOpenSettings;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final color =
        enabled ? const Color(0xFF1F7A4D) : Theme.of(context).colorScheme.error;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  enabled ? Icons.check_circle_outline : Icons.error_outline,
                  color: color,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    enabled ? '모의 위치 설정 완료' : '모의 위치 앱 설정 필요',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (!enabled) ...[
              const SizedBox(height: 8),
              const Text('개발자 옵션에서 PinDrift를 모의 위치 앱으로 선택해야 위치 적용이 가능합니다.'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onRefresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('다시 확인'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onOpenSettings,
                      icon: const Icon(Icons.settings_outlined),
                      label: const Text('메뉴로 이동'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ApiGuidePage extends StatelessWidget {
  const ApiGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        GuideCard(
          title: '네이버 지도 ncpKeyId 받기',
          icon: Icons.map_outlined,
          steps: [
            'NAVER Cloud Platform Console에 로그인합니다.',
            'Services > Application Services > Maps > Application으로 이동합니다.',
            'Application을 등록하고 API 선택에서 Dynamic Map을 선택합니다.',
            '서비스 환경 등록의 Web 서비스 URL에 https://pindrift.local 을 추가합니다.',
            'Android 앱 패키지 이름과 iOS Bundle ID는 비워둬도 됩니다.',
            '등록한 Application 상세에서 Client ID를 확인합니다.',
            'Client ID 값을 PinDrift 설정의 Naver Maps ncpKeyId에 붙여 넣습니다.',
            'Dynamic Map 외의 API는 현재 PinDrift 기능에는 필요하지 않습니다.',
          ],
          linkLabel: '공식 문서',
          link:
              'https://navermaps.github.io/maps.js.en/docs/tutorial-1-Getting-Client-ID.html',
        ),
        SizedBox(height: 16),
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'PinDrift는 네이버 지도만 사용합니다. ncpKeyId는 앱 내부에 저장되며 별도 서버로 전송하지 않습니다.',
            ),
          ),
        ),
      ],
    );
  }
}

class GuideCard extends StatelessWidget {
  const GuideCard({
    super.key,
    required this.title,
    required this.icon,
    required this.steps,
    required this.linkLabel,
    required this.link,
  });

  final String title;
  final IconData icon;
  final List<String> steps;
  final String linkLabel;
  final String link;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < steps.length; i++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 26,
                    child: Text(
                      '${i + 1}.',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Expanded(child: Text(steps[i])),
                ],
              ),
              if (i != steps.length - 1) const SizedBox(height: 8),
            ],
            const SizedBox(height: 14),
            Text(
              '$linkLabel: $link',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyMap extends StatelessWidget {
  const EmptyMap({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE8ECE7),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.map_outlined,
                size: 48,
                color: Color(0xFF5C6F68),
              ),
              const SizedBox(height: 12),
              Text(
                '네이버 지도 ncpKeyId를 설정하세요.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.running});

  final bool running;

  @override
  Widget build(BuildContext context) {
    final color = running ? const Color(0xFF1F7A4D) : const Color(0xFF6B7280);
    return Chip(
      avatar: Icon(
        running ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        size: 16,
        color: color,
      ),
      label: Text(running ? '동작 중' : '대기'),
      side: BorderSide(color: color.withValues(alpha: 0.24)),
      backgroundColor: color.withValues(alpha: 0.08),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
    );
  }
}
