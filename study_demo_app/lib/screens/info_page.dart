part of app;

class InfoPage extends StatelessWidget {
  final String uuid;

  InfoPage(this.uuid);

  Widget textBox(String t, [TextStyle style]) {
    return Container(
      padding: EdgeInsets.only(top: 15),
      child: Text(t, style: style),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('*' * 50);
    print('Check');
    print('*' * 50);

    return Scaffold(
      appBar: AppBar(
        title: Text("Info Page"),
      ),
      body: Center(
          child: Container(
            margin: EdgeInsets.all(10),
            child: Column(
              children: [
                textBox('This app is a part of a Master\'s Thesis study.'),
                textBox(
                    'Your location data will be collected anonymously during 2-4 weeks, then analyzed and lastly deleted permanently.'),
                textBox(
                    'If you have any questions regarding the study, shoot me an email at tnni@dtu.dk.'),
                textBox('Thank you for your contribution!'),
                textBox("Your participant ID is:",
                    TextStyle(fontSize: 25, color: Colors.blue)),
                textBox(uuid, TextStyle(fontSize: 14, color: Colors.black38)),
              ],
            ),
          )),
    );
  }
}
