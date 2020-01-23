import 'package:flutter_test/flutter_test.dart';

import 'package:mobility_features/mobility_features.dart';
import 'package:mobility_features/dataset.dart';


void main() {
  test('run db scan', () {
    List<LocationData> data = Dataset().data;
    final p = Preprocessor();

    /// Find stops, stops will have an empty [place] field
    List<Stop> stops = p.findStops(data);
    printList(stops);

    /// Find places, now stops should have their [place] field set
    List<Place> places = p.findPlaces(stops);
    printList(stops);
    printList(places);

    /// Find moves
    List<Move> moves = p.findMoves(data, stops);
    printList(moves);

  });
}
