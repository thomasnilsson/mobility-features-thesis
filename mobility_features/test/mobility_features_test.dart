import 'mobility_features_test_lib.dart';
import 'package:mobility_features/mobility_features_lib.dart';
import 'package:flutter_test/flutter_test.dart';


void main() {
  test('run db scan', () async {
    List<LocationData> data = await Dataset().multiDateData;
    final p = Preprocessor(data);

    /// Find stops, stops will have an empty [place] field
    List<Stop> stops = p.findStops(data);

    /// Find places, now stops should have their [place] field set
    List<Place> places = p.findPlaces(stops);

    /// Find moves
    List<Move> moves = p.findMoves(data, stops);

    printList(stops);
    printList(places);
    printList(moves);

    Features f = Features(data, stops, places, moves);
//    print('Number of Clusters: ${f.numberOfClusters}');
//    print('Location Variance: ${f.locationVariance}');
//    print('Entropy: ${f.entropy}');
//    print('Normalized Entropy: ${f.normalizedEntropy}');
//    print('Total Distance (meters): ${f.totalDistance}');

    var m = f.timeSpentAtPlaceAtHour;
    printMatrix(m);
  });
}
