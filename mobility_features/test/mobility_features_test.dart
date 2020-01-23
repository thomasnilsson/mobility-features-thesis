import 'package:flutter_test/flutter_test.dart';

import 'package:mobility_features/mobility_features.dart';
import 'package:mobility_features/dataset.dart';


void main() {
  test('run db scan', () {
    List<LocationData> data = Dataset().data;
    final p = Preprocessor();

    /// Find stops
    List<Stop> stops = p.findStops(data);
    printList(stops);

    /// Find places
    List<Place> places = p.findPlaces(stops);
    printList(places);

    print(p.findCentroid(stops.map((x) => (x.location)).toList()));
  });
}
