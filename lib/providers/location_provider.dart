import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../services/location_service.dart';

final geolocatorProvider = Provider<GeolocatorPlatform>(
  (ref) => GeolocatorPlatform.instance,
);
final locationServiceProvider = Provider<LocationService>(
  (ref) => LocationService(platform: ref.watch(geolocatorProvider)),
);
