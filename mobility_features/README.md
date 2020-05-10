# mobility_features

For mental health research, location data, together with a time component, both collected from the user’s smartphone, can be reduced to certain behavioral features pertaining to the user’s mobility. These features can be used to diagnose patients suffering from mental disorders such as depression. Previously, mobility recognition has been done in an off-device fashion where features are extracted after a study was completed. We propose performing mobility feature extracting in real-time on the device itself, as new data comes in a continuous fashion. This trades compute power, i.e. phone battery for bandwidth and storage since the reduced features take up much less space than the raw GPS data, and transforms the very intrusive GPS data to abstract features, which avoids unnecessary logging of sensitive data.

## Intermediate Features
Stops

Places

Moves

## Features
The mobility features which will be used are derived from GPS location data as described in [Saeb15].

Note that ’cluster’ and ’place’ may be used interchangeably when describing features. A cluster is simply the mathematical term for a collection of data points which corresponds to a place with some GPS coordinates in the real world.

**Number of Clusters:** This feature represents the total number of clusters found by the clustering algorithm.

**Location Variance:** This feature measures the variability of a participant’s location data from stationary states. LV was computed as the natural logarithm of the sum of the statistical variances of the latitude and the longitude components of the location data.

**Location Entropy (LE):** A measure of points of interest. High entropy indicates that the participant spent time more uniformly across different location clusters, while lower entropy indicates the participant spent most of the time at some specific clusters.

**Normalized LE:** Normalized entropy is calculated by dividing the cluster entropy by its maximum value, which is the logarithm of the total number of clusters. Normalized entropy is invariant to the number of clusters and thus solely depends on their visiting distribution. The value of normalized entropy ranges from 0 to 1, where 0 indicates the participant has spent their time at only one location, and 1 indicates that the participant has spent an equal amount of time to visit each location cluster.

**Home Stay:** The percentage of time the participant has been at the cluster that represents home. We define the home cluster as the cluster, which is mostly visited during the period between 12 am and 6 am.

**Transition Time:** Transition Time measures the percentage of time the participant has been in the transition state.

**Total Distance:** This feature measures the total distance the participant has traveled in the transition state.

**Routine Index:** This feature measures to what extent the changes in a user's location follows a 24-hour rhythm. To calculate circadian movement, we obtained the distribution of the periodicity of the stationary location data and then calculated the percentage of overlap between a current distribution, ex today, and a historical distribution.

[Saeb15] showed that especially 4 features correlate highly with the PHQ9 score, which are Circadian Movement, Location Variance, Normalized Location Entropy and Home Stay.

## Usage

### Collect data
Data collection is not supported by this package, for this you have to use a location plugin such as `https://pub.dev/packages/geolocator`. 

From here, you can to convert from whichever Data Transfer Object is used by the location plugin to a `SingleLocationPoint`. Below is shown an example where `Position` objects are coming in from the `GeoLocator` plugin.

```dart
_onData(Position d) async {
    SingleLocationPoint(Location(d.latitude, d.longitude), d.timestamp);
    ...
}
```

### Process data
Start processing data with a `Preprocessor` instance which uses a date, for example todays date. 

The `DateTime.midnight` extension provided by this package creates a DateTime object with time `00:00:00` for a given date. This makes it easier to compare dates. 

```dart
DateTime today = DateTime.now().midnight;
DataPreprocessor preprocessor = DataPreprocessor(today);
```

### Preprocess the data
Before features are computed, the data must be preprocessed down to the intermediate features Stops, Places and Moves.

#### Finding Stops
Finding stops is done by feed the preprocessor a list of `SingleLocationPoint`, i.e. given `Serializer<SingleLocationPoint> points`, the stops can be found as:

```dart
List<Stop> stops = preprocessor.findStops(points);
```

The `filter` keyword here indicates whether or not data should be filtered such that only data from the given date is included. 

If the data all comes from the same date then set the keyword to `preprocessor.findStops(points, filter: false);`, since this will speed up the computation considerably.
   
#### Finding Places
Places are derived from the stops we just computed:

```dart
List<Place> places = preprocessor.findPlaces(stops);
```

#### Finding Moves

Once the stops have been computed, the moves can be derived in a similar fashion:

```dart
List<Move> moves = preprocessor.findMoves(points, stops);
```

Similar to finding stops, the filter keyword can be set to false if the data is from the same day already.

### Calculating Features


## (Advanced) Using Historical Data
This provides additional features such as aggregate features and the Routine Index feature.