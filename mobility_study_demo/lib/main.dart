library app;

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import 'package:path_provider/path_provider.dart';
import 'package:mobility_features/mobility_features.dart';

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:isolate';
import 'package:flutter_picker/flutter_picker.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

part 'package:mobility_study_demo/logic/file_util.dart';

part 'package:mobility_study_demo/logic/app_processor.dart';

part 'package:mobility_study_demo/screens/info_page.dart';

part 'package:mobility_study_demo/screens/diary_page.dart';

part 'package:mobility_study_demo/screens/main_page.dart';

part 'constants.dart';

void main() => runApp(MobilityStudy());

class MobilityStudy extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    /// Set device orientation, i.e. disable landscape mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    return new MaterialApp(
        debugShowCheckedModeBanner: false,
        home: MainPage(title: 'Main Page'),
        theme: ThemeData(
          primaryColor: Colors.blue,
          accentColor: Colors.blue,
        ));
  }
}
