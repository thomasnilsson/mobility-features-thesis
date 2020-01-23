import 'package:flutter_test/flutter_test.dart';

import 'package:mobility_features/mobility_features.dart';
import 'package:mobility_features/dataset.dart';

void main() {

  test('run db scan', () {
//    final c = Cluster();
//    c.runDBSCAN();

    List<LocationData> data = Dataset().data;
    final p = Preprocessor();
    List<Stop> stops = p.findStops(data);
    for (var s in stops) {
      print(s);
    }
//    var places = p.getPlaces(coords);
//    print(places);

  });
}
