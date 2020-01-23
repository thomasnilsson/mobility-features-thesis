# msc-thesis-flutter
Mobility Features as a Flutter package. For my MSc Thesis.

See: https://thomasnilsson.github.io/masters_thesis.html

# MSc Thesis:
# __A Flutter Package for Real-time Mobility Feature Extraction__

__Student:__ Thomas Nilsson

__Supervisor:__ Jakob Bardram

## Abstract
For mental health research, location data, together with a time component, both collected from the user’s smartphone, can be reduced to certain behavioral features pertaining to the user’s mobility. These features can be used to diagnose patients suffering from mental disorders such as depression. Previously, mobility recognition has been done in an off-device fashion where features are extracted after a study was completed. We propose performing mobility feature extracting in real-time on the device itself, as new data comes in a continuous fashion. This trades compute power, i.e. phone battery for bandwidth and storage since the reduced features take up much less space than the raw GPS data, and transforms the very intrusive GPS data to abstract features, which avoids unnecessary logging of sensitive data.

## Features
The mobility features which will be used are derived from GPS location data as described in [Saeb15](https://www.ncbi.nlm.nih.gov/pubmed/26640739).

_Note that ’cluster’ and ’place’ may be used interchangeably when describing features. A cluster is simply the mathematical term for a collection of data points which corresponds to a place with some GPS coordinates in the real world._

### Number of Clusters: 
This feature represents the total number of clusters found by the clustering algorithm.

### Location Variance: 
This feature measures the variability of a participant’s location data from stationary states. LV was computed as the natural logarithm of the sum of the statistical variances of the latitude and the longitude components of the location data.

### Location Entropy (LE): 
A measure of points of interest. High entropy indicates that the participant spent time more uniformly across different location clusters, while lower entropy indicates the participant spent most of the time at some specific clusters.

### Normalized LE: 
Normalized entropy is calculated by dividing the cluster entropy by its maximum value, which is the logarithm of the total number of clusters. Normalized entropy is invariant to the number of clusters and thus solely depends on their visiting distribution. The value of normalized entropy ranges from 0 to 1, where 0 indicates the participant has spent their time at only one location, and 1 indicates that the participant has spent an equal amount of time to visit each location cluster.

### Home Stay: 
The percentage of time the participant has been at the cluster that represents home. We define the home cluster as the cluster, which is mostly visited during the period between 12 am and 6 am.

### Transition Time: 
Transition Time measures the percentage of time the participant has been in the transition state.

### Total Distance: 
This feature measures the total distance the participant has traveled in the transition state.

### Circadian Movement: 
This feature measures to what extent the changes in a participant’s location follow a 24-hour, or circadian, rhythm. To calculate circadian movement, we obtained the distribution of the periodicity of the stationary location data and then calculated the percentage of it that falls in the 24±0.5 hour periodicity.

[Saeb15](https://www.ncbi.nlm.nih.gov/pubmed/26640739) showed that especially 4 features correlate highly with the PHQ9 score, which are Circadian Movement, Location Variance, Normalized Location Entropy and Home Stay.