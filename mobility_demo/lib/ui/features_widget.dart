import 'package:flutter/material.dart';
import '../mobility.dart';
import 'package:intl/intl.dart';

class FeaturesWidget extends StatelessWidget {
  FeaturesAggregate _features;
  List<String> _content;

  String formatDate(DateTime date) => new DateFormat("MMMM d").format(date);

  FeaturesWidget(this._features) {
    _content = [];
    if (_features != null) {
      _content.add('Statistics for today (thus far), ${formatDate(_features.date)} based on ${_features.uniqueDates.length} previous dates.');
      _content.add("You've have stuck ${_features.routineIndexDaily * 100} % to your routine.");
      _content.add("You've stayed home ${_features.homeStayDaily * 100} % of the time.");
      _content.add("You've travelled ${_features.totalDistanceDaily / 1000} km.");
      _content.add("You've visited ${_features.numberOfClustersDaily} significant places.");
      _content.add('Entropy for time spent at significant places is ${_features.normalizedEntropyDaily}');
      _content.add('Total location variance is ${_features.locationVarianceDaily}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _content.isEmpty
        ? Text('No features computed yet!')
        : ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: _content.length,
      itemBuilder: (_, index) => Container(
        height: 50,
        child: Text(_content[index].toString()),
      ),
      separatorBuilder: (BuildContext context, int index) =>
      const Divider(),
    );
  }
}
