part of app;

class MainPage extends StatefulWidget {
  MainPage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  AppProcessor processor = AppProcessor();
  bool streamingLocation = false;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging();

  /// Firebase Cloud Messaging setup
  Future _initNotificationService() async {
    await _firebaseMessaging.requestNotificationPermissions();
    _firebaseMessaging.configure(onMessage: _onMessage, onResume: _onResume);
  }

  /// Notification when app is in foreground, go to diary page
  Future<dynamic> _onMessage(Map<String, dynamic> message) async {
    print(message);
    goToDiary();
    return message;
  }

  /// Notification when app is in background. On click, go to diary page
  Future<dynamic> _onResume(Map<String, dynamic> message) async {
    print(message);
    goToDiary();
    return message;
  }

  void initialize() async {
    await _initNotificationService();
    await processor.initialize();
    setState(() {
      streamingLocation = processor.streamingLocation;
    });
  }

  void restart() async {
    await processor.restart();
    setState(() {
      streamingLocation = processor.streamingLocation;
    });
  }

  @override
  void initState() {
    super.initState();
    initialize();
  }

  Widget entry(String key, String value, IconData icon) {
    return Container(
        padding: const EdgeInsets.all(2),
        margin: EdgeInsets.all(3),
        child: ListTile(
          leading: Icon(icon),
          title: Text(key),
          trailing: Text(value),
        ));
  }

  void goToPatientPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => InfoPage()),
    );
  }

  void goToDiary() {
    /// Dont await
    processor.saveAndUpload();
    /// Go to next screen
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DiaryPage(processor.uuid)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: <Widget>[
          IconButton(
            onPressed: goToPatientPage,
            icon: Icon(
              Icons.info,
              color: Colors.white,
            ),
          ),
          IconButton(
            onPressed: goToDiary,
            icon: Icon(
              Icons.calendar_today,
              color: Colors.white,
            ),
          )
        ],
      ),
      body: Container(
          padding: EdgeInsets.all(20),
          child: Column(
            children: <Widget>[
              streamingLocation ? trackingView : notTrackingView,
              Text('Participant ID: ${processor.uuid}')
            ],
          )),
      floatingActionButton: streamingLocation
          ? null
          : FloatingActionButton(
              onPressed: restart,
              tooltip: 'Restart',
              child: Icon(Icons.refresh),
            ),
    );
  }
}
