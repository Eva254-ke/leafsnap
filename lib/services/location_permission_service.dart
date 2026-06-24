import 'package:geolocator/geolocator.dart';

class LocationPermissionService {
  LocationPermissionService._();

  static Future<LocationPermission>? _pendingPermissionRequest;

  static Future<LocationPermission> requestWhenInUse() {
    final pending = _pendingPermissionRequest;
    if (pending != null) {
      return pending;
    }

    final request = Geolocator.requestPermission();
    _pendingPermissionRequest = request;
    return request.whenComplete(() {
      if (identical(_pendingPermissionRequest, request)) {
        _pendingPermissionRequest = null;
      }
    });
  }

  static Future<LocationPermission> checkAndRequestIfNeeded() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      return requestWhenInUse();
    }
    return permission;
  }
}
