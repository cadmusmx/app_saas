import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<Position?> getCurrentLocation() async {
    // Verificar si los permisos están habilitados
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('El GPS está deshabilitado.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Permiso de ubicación denegado.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Permiso de ubicación denegado permanentemente, no se puede solicitar.');
    }

    try {
      // LocationServiceDisabledException (The location service on the device is disabled.)
      return await Geolocator.getCurrentPosition(locationSettings: AndroidSettings(accuracy: LocationAccuracy.high));
    } catch (e) {
      return null;
    }
  }
}
