// وظيفة الملف: تطبيق تجريبي رسمي لحزمة Siro Maps SDK
import 'package:flutter/material.dart';
import 'package:siro_map/siro_map.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Siro Maps Example',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  SiroMapController? _controller;

  // Example marker
  final Set<Marker> _markers = {
    const Marker(
      markerId: MarkerId('amman'),
      position: LatLng(31.9539, 35.9106),
      infoWindow: InfoWindow(
        title: 'عمان - الأردن',
        snippet: 'Siro Sovereign Maps Gateway',
      ),
    ),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Siro Maps Demo'),
      ),
      body: SiroMap(
        apiKey: 'YOUR_API_KEY_HERE', // Replace with a valid key
        initialCameraPosition: const CameraPosition(
          target: LatLng(31.9539, 35.9106),
          zoom: 12,
        ),
        markers: _markers,
        onCameraMoveStarted: () {
          debugPrint('Camera movement started');
        },
        onMapCreated: (controller) {
          setState(() {
            _controller = controller;
          });
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _controller?.animateCamera(
            CameraUpdate.newLatLngZoom(const LatLng(31.9539, 35.9106), 14),
          );
        },
        child: const Icon(Icons.location_city),
      ),
    );
  }
}
