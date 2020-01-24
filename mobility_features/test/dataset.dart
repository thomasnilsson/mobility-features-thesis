part of mobility_features_test_lib;

class Dataset {
  List<LocationData> get data =>
      _data.keys.map((k) => LocationData.fromJson(_data[k])).toList();
}

Map<String, dynamic> _data = {
  "0": {
    "user_id": 0,
    "datetime": 1572001564000,
    "longitude": 12.5171537465,
    "latitude": 55.782664095
  },
  "1": {
    "user_id": 0,
    "datetime": 1572001624000,
    "longitude": 12.5171609345,
    "latitude": 55.7826006756
  },
  "2": {
    "user_id": 0,
    "datetime": 1572001684000,
    "longitude": 12.5171147578,
    "latitude": 55.7825879501
  },
  "3": {
    "user_id": 0,
    "datetime": 1572001744000,
    "longitude": 12.5171887204,
    "latitude": 55.7825805095
  },
  "4": {
    "user_id": 0,
    "datetime": 1572001804000,
    "longitude": 12.517164013,
    "latitude": 55.7826830975
  },
  "5": {
    "user_id": 0,
    "datetime": 1572001864000,
    "longitude": 12.5171337671,
    "latitude": 55.7825419554
  },
  "6": {
    "user_id": 0,
    "datetime": 1572001924000,
    "longitude": 12.5171633129,
    "latitude": 55.7826680275
  },
  "7": {
    "user_id": 0,
    "datetime": 1572001984000,
    "longitude": 12.5171701484,
    "latitude": 55.7825915567
  },
  "8": {
    "user_id": 0,
    "datetime": 1572002044000,
    "longitude": 12.5170957432,
    "latitude": 55.7826038739
  },
  "9": {
    "user_id": 0,
    "datetime": 1572002104000,
    "longitude": 12.5170628986,
    "latitude": 55.7826533768
  },
  "10": {
    "user_id": 0,
    "datetime": 1572002164000,
    "longitude": 12.5171031692,
    "latitude": 55.7825429507
  },
  "11": {
    "user_id": 0,
    "datetime": 1572002224000,
    "longitude": 12.5171709559,
    "latitude": 55.7825965192
  },
  "12": {
    "user_id": 0,
    "datetime": 1572002284000,
    "longitude": 12.5170580758,
    "latitude": 55.7826202107
  },
  "13": {
    "user_id": 0,
    "datetime": 1572002344000,
    "longitude": 12.5171267772,
    "latitude": 55.7827042482
  },
  "14": {
    "user_id": 0,
    "datetime": 1572002404000,
    "longitude": 12.5171919414,
    "latitude": 55.7825488914
  },
  "15": {
    "user_id": 0,
    "datetime": 1572002464000,
    "longitude": 12.5171435835,
    "latitude": 55.7825662764
  },
  "16": {
    "user_id": 0,
    "datetime": 1572002524000,
    "longitude": 12.5175640976,
    "latitude": 55.7826789626
  },
  "17": {
    "user_id": 0,
    "datetime": 1572002584000,
    "longitude": 12.5181140231,
    "latitude": 55.7827619248
  },
  "18": {
    "user_id": 0,
    "datetime": 1572002644000,
    "longitude": 12.5184648124,
    "latitude": 55.7828068121
  },
  "19": {
    "user_id": 0,
    "datetime": 1572002704000,
    "longitude": 12.5189651989,
    "latitude": 55.7827519367
  },
  "20": {
    "user_id": 0,
    "datetime": 1572002764000,
    "longitude": 12.5195219337,
    "latitude": 55.7828359639
  },
  "21": {
    "user_id": 0,
    "datetime": 1572002824000,
    "longitude": 12.5199127288,
    "latitude": 55.7828534519
  },
  "22": {
    "user_id": 0,
    "datetime": 1572002884000,
    "longitude": 12.5205079284,
    "latitude": 55.7829827198
  },
  "23": {
    "user_id": 0,
    "datetime": 1572002944000,
    "longitude": 12.52093271,
    "latitude": 55.7829521462
  },
  "24": {
    "user_id": 0,
    "datetime": 1572003004000,
    "longitude": 12.5213183024,
    "latitude": 55.7830364447
  },
  "25": {
    "user_id": 0,
    "datetime": 1572003064000,
    "longitude": 12.5212498127,
    "latitude": 55.7829824823
  },
  "26": {
    "user_id": 0,
    "datetime": 1572003124000,
    "longitude": 12.5213745488,
    "latitude": 55.7831450503
  },
  "27": {
    "user_id": 0,
    "datetime": 1572003184000,
    "longitude": 12.5213539265,
    "latitude": 55.7830342226
  },
  "28": {
    "user_id": 0,
    "datetime": 1572003244000,
    "longitude": 12.5213648735,
    "latitude": 55.7829608592
  },
  "29": {
    "user_id": 0,
    "datetime": 1572003304000,
    "longitude": 12.5212164021,
    "latitude": 55.7829882674
  },
  "30": {
    "user_id": 0,
    "datetime": 1572003364000,
    "longitude": 12.5213540883,
    "latitude": 55.7830530127
  },
  "31": {
    "user_id": 0,
    "datetime": 1572003424000,
    "longitude": 12.5212563444,
    "latitude": 55.7829671086
  },
  "32": {
    "user_id": 0,
    "datetime": 1572003484000,
    "longitude": 12.5213369658,
    "latitude": 55.7831014626
  },
  "33": {
    "user_id": 0,
    "datetime": 1572003544000,
    "longitude": 12.5212946583,
    "latitude": 55.783008969
  },
  "34": {
    "user_id": 0,
    "datetime": 1572003604000,
    "longitude": 12.5213957818,
    "latitude": 55.7830317781
  },
  "35": {
    "user_id": 0,
    "datetime": 1572003664000,
    "longitude": 12.5213499336,
    "latitude": 55.7829835863
  },
  "36": {
    "user_id": 0,
    "datetime": 1572003724000,
    "longitude": 12.5212776021,
    "latitude": 55.7830265611
  },
  "37": {
    "user_id": 0,
    "datetime": 1572003784000,
    "longitude": 12.5213675501,
    "latitude": 55.7829566913
  },
  "38": {
    "user_id": 0,
    "datetime": 1572003844000,
    "longitude": 12.5213581029,
    "latitude": 55.7830080963
  },
  "39": {
    "user_id": 0,
    "datetime": 1572003904000,
    "longitude": 12.5213620382,
    "latitude": 55.7830402089
  },
  "40": {
    "user_id": 0,
    "datetime": 1572003964000,
    "longitude": 12.5213175741,
    "latitude": 55.7830130769
  },
  "41": {
    "user_id": 0,
    "datetime": 1572004024000,
    "longitude": 12.520915144,
    "latitude": 55.7832126584
  },
  "42": {
    "user_id": 0,
    "datetime": 1572004084000,
    "longitude": 12.520412549,
    "latitude": 55.7834118776
  },
  "43": {
    "user_id": 0,
    "datetime": 1572004144000,
    "longitude": 12.5200364993,
    "latitude": 55.7835956944
  },
  "44": {
    "user_id": 0,
    "datetime": 1572004204000,
    "longitude": 12.519743074,
    "latitude": 55.7837454468
  },
  "45": {
    "user_id": 0,
    "datetime": 1572004264000,
    "longitude": 12.5193501312,
    "latitude": 55.7840830718
  },
  "46": {
    "user_id": 0,
    "datetime": 1572004324000,
    "longitude": 12.5189546707,
    "latitude": 55.7841972287
  },
  "47": {
    "user_id": 0,
    "datetime": 1572004384000,
    "longitude": 12.5185027277,
    "latitude": 55.7844655781
  },
  "48": {
    "user_id": 0,
    "datetime": 1572004444000,
    "longitude": 12.5181600981,
    "latitude": 55.7845556898
  },
  "49": {
    "user_id": 0,
    "datetime": 1572004504000,
    "longitude": 12.5177350815,
    "latitude": 55.7847503222
  },
  "50": {
    "user_id": 0,
    "datetime": 1572004564000,
    "longitude": 12.5176973742,
    "latitude": 55.7847283416
  },
  "51": {
    "user_id": 0,
    "datetime": 1572004624000,
    "longitude": 12.5177233508,
    "latitude": 55.784829971
  },
  "52": {
    "user_id": 0,
    "datetime": 1572004684000,
    "longitude": 12.517710075,
    "latitude": 55.7848276561
  },
  "53": {
    "user_id": 0,
    "datetime": 1572004744000,
    "longitude": 12.517707826,
    "latitude": 55.7846941187
  },
  "54": {
    "user_id": 0,
    "datetime": 1572004804000,
    "longitude": 12.517677624,
    "latitude": 55.7846911902
  },
  "55": {
    "user_id": 0,
    "datetime": 1572004864000,
    "longitude": 12.5177476859,
    "latitude": 55.784779175
  },
  "56": {
    "user_id": 0,
    "datetime": 1572004924000,
    "longitude": 12.517733866,
    "latitude": 55.7847445735
  },
  "57": {
    "user_id": 0,
    "datetime": 1572004984000,
    "longitude": 12.5177856746,
    "latitude": 55.7847454971
  },
  "58": {
    "user_id": 0,
    "datetime": 1572005044000,
    "longitude": 12.5177211309,
    "latitude": 55.7848516892
  },
  "59": {
    "user_id": 0,
    "datetime": 1572005104000,
    "longitude": 12.5175967245,
    "latitude": 55.7848030911
  },
  "60": {
    "user_id": 0,
    "datetime": 1572005164000,
    "longitude": 12.517630608,
    "latitude": 55.7846896409
  },
  "61": {
    "user_id": 0,
    "datetime": 1572005224000,
    "longitude": 12.5177607794,
    "latitude": 55.7848084615
  },
  "62": {
    "user_id": 0,
    "datetime": 1572005284000,
    "longitude": 12.517735047,
    "latitude": 55.7848526402
  },
  "63": {
    "user_id": 0,
    "datetime": 1572005344000,
    "longitude": 12.5177042629,
    "latitude": 55.7848631221
  },
  "64": {
    "user_id": 0,
    "datetime": 1572005404000,
    "longitude": 12.5177423039,
    "latitude": 55.7847156847
  },
  "65": {
    "user_id": 0,
    "datetime": 1572005464000,
    "longitude": 12.517667362,
    "latitude": 55.7848423208
  },
  "66": {
    "user_id": 0,
    "datetime": 1572005524000,
    "longitude": 12.5176828725,
    "latitude": 55.7844808703
  },
  "67": {
    "user_id": 0,
    "datetime": 1572005584000,
    "longitude": 12.5176133946,
    "latitude": 55.784365162
  },
  "68": {
    "user_id": 0,
    "datetime": 1572005644000,
    "longitude": 12.5174616842,
    "latitude": 55.7840301648
  },
  "69": {
    "user_id": 0,
    "datetime": 1572005704000,
    "longitude": 12.5174407785,
    "latitude": 55.7837835056
  },
  "70": {
    "user_id": 0,
    "datetime": 1572005764000,
    "longitude": 12.5173865525,
    "latitude": 55.7836118033
  },
  "71": {
    "user_id": 0,
    "datetime": 1572005824000,
    "longitude": 12.5173077437,
    "latitude": 55.7832671514
  },
  "72": {
    "user_id": 0,
    "datetime": 1572005884000,
    "longitude": 12.5172890015,
    "latitude": 55.7830498711
  },
  "73": {
    "user_id": 0,
    "datetime": 1572005944000,
    "longitude": 12.5171726201,
    "latitude": 55.7829752123
  },
  "74": {
    "user_id": 0,
    "datetime": 1572006004000,
    "longitude": 12.5171305352,
    "latitude": 55.7826816209
  },
  "75": {
    "user_id": 0,
    "datetime": 1572006064000,
    "longitude": 12.5171189994,
    "latitude": 55.782657299
  },
  "76": {
    "user_id": 0,
    "datetime": 1572006124000,
    "longitude": 12.5170802662,
    "latitude": 55.7826774068
  },
  "77": {
    "user_id": 0,
    "datetime": 1572006184000,
    "longitude": 12.517165673,
    "latitude": 55.7826255884
  },
  "78": {
    "user_id": 0,
    "datetime": 1572006244000,
    "longitude": 12.5171262053,
    "latitude": 55.7825676407
  },
  "79": {
    "user_id": 0,
    "datetime": 1572006304000,
    "longitude": 12.5170592263,
    "latitude": 55.7825792729
  },
  "80": {
    "user_id": 0,
    "datetime": 1572006364000,
    "longitude": 12.5171244642,
    "latitude": 55.7826063084
  },
  "81": {
    "user_id": 0,
    "datetime": 1572006424000,
    "longitude": 12.5171183334,
    "latitude": 55.7826794341
  },
  "82": {
    "user_id": 0,
    "datetime": 1572006484000,
    "longitude": 12.5171393415,
    "latitude": 55.78262807
  },
  "83": {
    "user_id": 0,
    "datetime": 1572006544000,
    "longitude": 12.5171357987,
    "latitude": 55.7826125303
  },
  "84": {
    "user_id": 0,
    "datetime": 1572006604000,
    "longitude": 12.5170663711,
    "latitude": 55.7825116418
  },
  "85": {
    "user_id": 0,
    "datetime": 1572006664000,
    "longitude": 12.5171094105,
    "latitude": 55.7826392134
  },
  "86": {
    "user_id": 0,
    "datetime": 1572006724000,
    "longitude": 12.517132086,
    "latitude": 55.7826349567
  },
  "87": {
    "user_id": 0,
    "datetime": 1572006784000,
    "longitude": 12.5170673511,
    "latitude": 55.78257716
  },
  "88": {
    "user_id": 0,
    "datetime": 1572006844000,
    "longitude": 12.5171660757,
    "latitude": 55.7825850915
  },
  "89": {
    "user_id": 0,
    "datetime": 1572006904000,
    "longitude": 12.5170603198,
    "latitude": 55.7825914982
  }
};
