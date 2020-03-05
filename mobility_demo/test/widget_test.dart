// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobility_demo/mobility.dart';

import 'package:mobility_demo/main.dart';


void printList(List l) {
  for (int i = 0; i < l.length; i++) {
    print('[$i] ${l[i]}');
  }

  print('-' * 50);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  test('Serialization', () async {
    SingleLocationPoint p =
        SingleLocationPoint(Location(12.345, 98.765), DateTime.now());
    Stop s = Stop([p, p, p], placeId: 2);
    List<Stop> stops = [s, s, s];

    List jsonStops = stops.map((s) => s.toJson()).toList();

    FileManager fm = FileManager('stops.json');
    await fm.writeStops(stops);
    List<Stop> stopsFromFile = await fm.readStops();
    printList(stopsFromFile);
  });
}
