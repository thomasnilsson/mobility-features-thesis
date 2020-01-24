import 'mobility_features_test_lib.dart';
import 'package:mobility_features/mobility_features_lib.dart';
import 'package:flutter_test/flutter_test.dart';


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

    Features f = Features(data, stops, places, moves);
    print('Number of Clusters: ${f.numberOfClusters}');
    print('Location Variance: ${f.locationVariance}');
    print('Entropy: ${f.entropy}');
    print('Normalized Entropy: ${f.normalizedEntropy}');
    print('Total Distance (meters): ${f.totalDistance}');
  });
}
