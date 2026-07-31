import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<Position> getCurrentPosition() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final requested = await Geolocator.requestPermission();
      if (requested == LocationPermission.denied || requested == LocationPermission.deniedForever) {
        throw Exception('location_permission_denied');
      }
    }
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) throw Exception('location_service_disabled');
    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Stream<Position> watchPosition() {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 15),
    );
  }
}
