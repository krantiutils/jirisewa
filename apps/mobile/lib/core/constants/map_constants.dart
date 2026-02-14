import 'package:latlong2/latlong.dart';

/// OSM tile server URL template
const String mapTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// Required OSM attribution
const String mapAttribution =
    '© OpenStreetMap contributors';

/// Nominatim geocoding API base URL
const String nominatimBaseUrl = 'https://nominatim.openstreetmap.org';

/// OSRM routing API base URL (public demo server)
const String osrmBaseUrl = 'https://router.project-osrm.org';

/// Nepal geographic center — default map center when no user location
final LatLng mapDefaultCenter = LatLng(28.3949, 84.1240);

/// Jiri, Nepal — original launch area (Dolakha district)
final LatLng jiriCenter = LatLng(27.6306, 86.2305);

/// Default zoom level for map views (country-wide view)
const double mapDefaultZoom = 8.0;

/// Nepal bounding box corners for constraining map views
final LatLng nepalSouthWest = LatLng(26.347, 80.058);
final LatLng nepalNorthEast = LatLng(30.447, 88.201);

/// Minimum zoom to prevent zooming out too far
const double mapMinZoom = 7.0;

/// Maximum zoom for street-level detail
const double mapMaxZoom = 18.0;

/// User-Agent header for Nominatim requests (required by usage policy)
const String nominatimUserAgent = 'JiriSewa/1.0 (jirisewa.com)';
