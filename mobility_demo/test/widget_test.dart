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

void main() {
  testWidgets('File utils', (WidgetTester tester) async {
    List<LocationData> data = [];

    for (int i = 0; i < 20; i++) {
      LocationData d = LocationData.fromMap({'latitude' : 55.1, 'longitude' : 27.2, 'time': DateTime.now().millisecondsSinceEpoch / 1000});
      data.add(d);
    }

    File f = await FileUtil().write(data);
    String content = await FileUtil().read();
    print(content);
  });
}
