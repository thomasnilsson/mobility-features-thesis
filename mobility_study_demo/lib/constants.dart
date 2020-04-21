part of app;

TextStyle bigText = TextStyle(fontSize: 25, color: Colors.blue);
TextStyle mediumText = TextStyle(fontSize: 20);

Widget box(String text) {
  return Container(
      alignment: Alignment.topLeft,
      height: 80,
      child: Text(text, style: mediumText));
}

Widget infoText = Text(
  '''This app is a part of a Master\'s Thesis study.
                
Your location data will be collected anonymously during 2-4 weeks, then analyzed and lastly deleted permanently.

If you have any questions regarding the study, shoot me an email at tnni@dtu.dk.

Thank you for your participation!
                ''',
  style: mediumText,
);

Widget trackingView = Column(children: [
  box('Location is being tracked 👍'),
  box('Please keep the app running in the background. 📱'),
  box('Remember to fill out your  diary once a day, in the evening. 🌙'),
  box('You do so by clicking the calendar button the in top. 📅'),
  box('You will be reminded daily 🕗'),
  box('Thanks for your participation!'),
]);

Widget notTrackingView = Column(children: [
  box('Location is not tracking 🤨'),
  box('Go into your Settings App > Privacy > Location Services.'),
  box('Find the Runner App, and choose Always allow. '),
  box('Then click the refresh button below 🔄'),
]);
