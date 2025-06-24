import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class Translation_Page extends StatefulWidget {
  const Translation_Page({super.key});

  @override
  State<Translation_Page> createState() => _Translation_PageState();
}

class _Translation_PageState extends State<Translation_Page> {
  TextEditingController Befor_Translate = TextEditingController();
  int Befor_Counter_Text = 0;
  int After_Counter_Text = 0;
  String After_Translate = "";
  final ScrollController _scrollController = ScrollController();
  late final GenerativeModel _model;
  late final ChatSession _chatSession;
  bool _loading = false;
  final FocusNode _textFieldFocus = FocusNode();
  late stt.SpeechToText _speech;
  bool _isListening = false;
  // String _text = 'اضغط الزر للتحدث';
  double _confidence = 1.0;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _requestPermissions();
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: const String.fromEnvironment('GEMINI_API_KEY'),
    );
    _chatSession = _model.startChat();
  }

  Future<void> _requestPermissions() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      await Permission.microphone.request();
    }

    var speechStatus = await Permission.speech.status;
    if (!speechStatus.isGranted) {
      await Permission.speech.request();
    }
  }


  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => print('Status: $val'),
        onError: (val) => print('Error: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            Befor_Translate.text = val.recognizedWords;
            After_Translate = "";
            Befor_Counter_Text = Befor_Translate.text.length;
            if (val.hasConfidenceRating && val.confidence > 0) {
              _confidence = val.confidence;
              Befor_Counter_Text = Befor_Translate.text.length;
            }
          }),
        );
      } else {
        setState(() => _isListening = false);
        _speech.stop();
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }



  Future<String> _sendChatMessage(String message, String Language) async {
    setState(() {
      _loading = true;
    });
    try {
      final response = await _chatSession.sendMessage(
        Content.text("ترجم الى اللغة ال ${Language} لا تكتب شيىء اخر غير الترجمه هذا هو النص   " + message),
      );
      final text = response.text;
      After_Translate = response.text.toString();
      if (text == null) {
        _showError('No response from API');
        return "Error";
      } else {
        setState(() {
          _loading = false;
          _scrollDown();
        });
      }
    } catch (e) {
      _showError(e.toString());
      setState(() {
        _loading = false;
      });
    } finally {
      // Befor_Translate.clear();
      setState(() {
        _loading = false;
      });
      _textFieldFocus.requestFocus();
    }
    After_Counter_Text = After_Translate.length;
    return After_Translate;
  }



  void _showError(String message) {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Something went wrong'),
            content: SingleChildScrollView(
              child: SelectableText(message),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text("OK"),
              )
            ],
          );
        });
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(
          milliseconds: 750,
        ),
        curve: Curves.easeOutCirc,
      ),
    );
  }



  final FlutterTts _flutterTts = FlutterTts();
  final LanguageIdentifier _languageIdentifier = LanguageIdentifier(confidenceThreshold: 0.5);

  bool _isProcessing = false;

  @override
  void dispose() {
    Befor_Translate.dispose();
    // After_Translate.dispose();
    _flutterTts.stop();
    _languageIdentifier.close();
    super.dispose();
  }


  Future<void> _speak(String TextEdite) async {
    String text = TextEdite.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('الرجاء إدخال نص للقراءة')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // التعرف على لغة النص
      String? languageCode = await _languageIdentifier.identifyLanguage(text);
      print('لغة النص المكتشفة: $languageCode');

      // تعيين اللغة في flutter_tts
      if (languageCode != null && languageCode != 'und') {
        // تحقق مما إذا كانت اللغة المدعومة من flutter_tts
        bool isLanguageAvailable = await _flutterTts.isLanguageAvailable(languageCode);
        if (isLanguageAvailable) {
          await _flutterTts.setLanguage(languageCode);
        } else {
          // إذا كانت اللغة غير مدعومة، يمكن تعيين لغة افتراضية أو إعلام المستخدم
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('اللغة المكتشفة ($languageCode) غير مدعومة')),
          );
          setState(() {
            _isProcessing = false;
          });
          return;
        }
      } else {
        // إذا لم يتم التعرف على اللغة
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر التعرف على لغة النص')),
        );
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      // إعداد خصائص TTS
      await _flutterTts.setSpeechRate(0.5); // سرعة الكلام (0.0 - 1.0)
      await _flutterTts.setVolume(1.0); // مستوى الصوت (0.0 - 1.0)
      await _flutterTts.setPitch(1.0); // درجة الصوت (0.5 - 2.0)

      // قراءة النص بصوت مسموع
      var result = await _flutterTts.speak(text);
      if (result == 1) {
        print("تم البدء في الكلام");
      } else {
        print("فشل في بدء الكلام");
      }
    } catch (e) {
      print('خطأ أثناء عملية القراءة الصوتية: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء القراءة الصوتية')),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }


  void _copyTextFromController(TextEditingController TextEdite) {
    String textToCopy = TextEdite.text;
    if (textToCopy.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: textToCopy)).then((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم نسخ النص من الحقل!')),
        );
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('لا يوجد نص لنسخه!')),
      );
    }
  }

  void _copyStaticText() {
    Clipboard.setData(ClipboardData(text: After_Translate)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم نسخ النص الثابت!')),
      );
    });
  }

  void _pasteTextToController(TextEditingController TextEdite) async {
    ClipboardData? clipboardData = await Clipboard.getData('text/plain');
    if (clipboardData != null && clipboardData.text != null) {
      setState(() {
        TextEdite.text = clipboardData.text!;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم لصق النص في الحقل!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('لا يوجد نص في الحافظة للّصق!')),
      );
    }
  }






  final List<String> languages_1 = [
    'Arabic',
    'English',
    'Spanish',
    'French',
    'German',
    'Chinese',
    'Japanese',
    'Portuguese',
    'Russian',
    'Hindi',
    'Italian',
    'Korean',
    'Turkish',
    'Dutch',
    'Swedish',
  ];
  final List<String> countryFlags_1 = [
    'assets/flags/flag-for-saudi-arabia-svgrepo-com.svg',
    'assets/flags/united-kingdom-uk-svgrepo-com.svg',
    'assets/flags/flag-for-spain-svgrepo-com.svg',
    'assets/flags/flag-for-france-svgrepo-com.svg',
    'assets/flags/flag-for-germany-svgrepo-com.svg',
    'assets/flags/flag-for-china-svgrepo-com.svg',
    'assets/flags/japan-svgrepo-com.svg',
    'assets/flags/flag-for-portugal-svgrepo-com.svg',
    'assets/flags/flag-for-russia-svgrepo-com.svg',
    'assets/flags/india-svgrepo-com.svg',
    'assets/flags/flag-for-italy-svgrepo-com.svg',
    'assets/flags/flag-for-south-korea-svgrepo-com.svg',
    'assets/flags/turkey-svgrepo-com.svg',
    'assets/flags/netherlands-holland-svgrepo-com.svg',
    'assets/flags/flag-for-sweden-svgrepo-com.svg',
  ];

  String selectedLanguage_1 = "Arabic";
  String selectedFlag_1 = "assets/flags/flag-for-saudi-arabia-svgrepo-com.svg";



  final List<String> languages_2 = [
    'English',
    'Spanish',
    'French',
    'German',
    'Chinese',
    'Japanese',
    'Arabic',
    'Portuguese',
    'Russian',
    'Hindi',
    'Italian',
    'Korean',
    'Turkish',
    'Dutch',
    'Swedish',
  ];
  final List<String> countryFlags_2 = [
    'assets/flags/united-kingdom-uk-svgrepo-com.svg',
    'assets/flags/flag-for-spain-svgrepo-com.svg',
    'assets/flags/flag-for-france-svgrepo-com.svg',
    'assets/flags/flag-for-germany-svgrepo-com.svg',
    'assets/flags/flag-for-china-svgrepo-com.svg',
    'assets/flags/japan-svgrepo-com.svg',
    'assets/flags/flag-for-saudi-arabia-svgrepo-com.svg',
    'assets/flags/flag-for-portugal-svgrepo-com.svg',
    'assets/flags/flag-for-russia-svgrepo-com.svg',
    'assets/flags/india-svgrepo-com.svg',
    'assets/flags/flag-for-italy-svgrepo-com.svg',
    'assets/flags/flag-for-south-korea-svgrepo-com.svg',
    'assets/flags/turkey-svgrepo-com.svg',
    'assets/flags/netherlands-holland-svgrepo-com.svg',
    'assets/flags/flag-for-sweden-svgrepo-com.svg',
  ];

  String selectedLanguage_2 = "English";
  String selectedFlag_2 = "assets/flags/united-kingdom-uk-svgrepo-com.svg";


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Translate"),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        // color: Colors.red,
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.only(
                top: 10,
                bottom: 10,
                right: 10,
                left: 10
              ),
              child: Container(
                width: 300,
                child:  Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0,vertical: 5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      DropdownButton<String>(
                        hint: Row(
                          children: [
                            SvgPicture.asset(
                              selectedFlag_1,
                              width: 24,
                              height: 24,
                            ),
                            SizedBox(width: 8),
                            Text(selectedLanguage_1),
                          ],
                        ),
                        value: selectedLanguage_1,
                        icon: Icon(Icons.arrow_drop_down),
                        iconSize: 24,
                        elevation: 16,
                        style: TextStyle(color: Colors.black, fontSize: 16),
                        underline: Container(
                          height: 0,
                          color: Colors.transparent,
                        ),
                        onChanged: (String? newValue) {
                          setState(() {
                            int index = languages_1.indexOf(newValue!);
                            selectedLanguage_1 = newValue;
                            selectedFlag_1 = countryFlags_1[index];
                          });
                        },
                        items: languages_1.asMap().entries.map<DropdownMenuItem<String>>((entry) {
                          int index = entry.key;
                          String language = entry.value;

                          return DropdownMenuItem<String>(
                            value: language,
                            child: Row(
                              children: [
                                SvgPicture.asset(
                                  countryFlags_1[index],
                                  width: 24,
                                  height: 24,
                                ),
                                SizedBox(width: 8),
                                Text(language),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      DropdownButton<String>(
                        hint: Row(
                          children: [
                            SvgPicture.asset(
                              selectedFlag_2,
                              width: 24,
                              height: 24,
                            ),
                            SizedBox(width: 8),
                            Text(selectedLanguage_2),
                          ],
                        ),
                        value: selectedLanguage_2,
                        icon: Icon(Icons.arrow_drop_down),
                        iconSize: 24,
                        elevation: 16,
                        style: TextStyle(color: Colors.black, fontSize: 16),
                        underline: Container(
                          height: 0,
                          color: Colors.transparent,
                        ),
                        onChanged: (String? newValue) {
                          setState(() {
                            int index = languages_2.indexOf(newValue!);
                            selectedLanguage_2 = newValue;
                            selectedFlag_2 = countryFlags_2[index];
                          });
                        },
                        items: languages_2.asMap().entries.map<DropdownMenuItem<String>>((entry) {
                          int index = entry.key;
                          String language = entry.value;

                          return DropdownMenuItem<String>(
                            value: language,
                            child: Row(
                              children: [
                                SvgPicture.asset(
                                  countryFlags_2[index],
                                  width: 24,
                                  height: 24,
                                ),
                                SizedBox(width: 8),
                                Text(language),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: Colors.grey.shade300,width: 2),
                ),
              ),
            ),
            Container(
              // color: Colors.green,
              child: Padding(
                padding:
                const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                child: Container(
                  height: 270,
                  child: Column(
                    children: [
                      Expanded(
                        flex: 8,
                        child: Container(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: TextField(
                              controller: Befor_Translate,
                              focusNode: _textFieldFocus,
                              maxLines: null,
                              onSubmitted: (value)
                              {
                                _sendChatMessage(value,selectedLanguage_1);
                              },
                              onChanged: (value) {
                                setState(() {
                                  Befor_Counter_Text = value.length;
                                  After_Translate = "";
                                  After_Counter_Text = After_Translate.length;
                                });
                              },
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                hintText: "...أدخل النص هنا",
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade300,
                                ),
                                contentPadding: EdgeInsets.zero,
                              ),
                              textAlign: TextAlign.end,
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                      Divider(
                        color: Colors.grey.shade300,
                        height: 2,
                        indent: 20,
                        endIndent: 20,
                      ),
                      Expanded(
                        flex: 2,
                        child: Container(
                          child: Padding(
                            padding:
                            const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                              children: [
                                Text("${Befor_Counter_Text} / 5.000"),
                                Container(
                                  // width: 100,
                                  child: Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                    children: [
                                      IconButton(
                                        icon: SvgPicture.asset(
                                          'assets/trash.svg',
                                          color: Colors.red,
                                        ),

                                        onPressed: ()
                                        {
                                          setState(() {
                                            _isListening = false;
                                            Befor_Translate.clear();
                                            Befor_Counter_Text = Befor_Translate.text.length;
                                          });
                                        },
                                      ),
                                      IconButton(
                                        icon: _isProcessing
                                            ? CircularProgressIndicator(
                                          valueColor:
                                          AlwaysStoppedAnimation<Color>(Colors.white),
                                        )
                                            : SvgPicture.asset(
                                          'assets/speaker-2-svgrepo-com.svg',
                                        ),
                                        color: Colors.black,
                                        onPressed: ()
                                        {
                                          setState(() {
                                            _isProcessing ? null : _speak(Befor_Translate.text);
                                          });
                                        },
                                      ),
                                      IconButton(
                                        icon: Icon(_isListening ? Icons.multitrack_audio_sharp : Icons.mic_none),
                                        color: Colors.black,
                                        onPressed: _listen,
                                      ),
                                      IconButton(
                                        icon: SvgPicture.asset(
                                          'assets/copy-svgrepo-com.svg',
                                        ),
                                        color: Colors.black,
                                        onPressed: ()
                                        {
                                          setState(() {
                                            _copyTextFromController(Befor_Translate);
                                          });
                                        },
                                      ),
                                      IconButton(
                                        icon: SvgPicture.asset(
                                          'assets/paste-svgrepo-com.svg',width: 25,
                                        ),
                                        color: Colors.blueAccent,
                                        onPressed: ()
                                        {
                                          setState(() {
                                            _pasteTextToController(Befor_Translate);
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ],
                  ),
                  decoration: BoxDecoration(
                    // color: Colors.red,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.grey.shade300,width: 2)),
                ),
              ),
            ),
            Container(

              // color: Colors.green,
              child: Padding(
                padding:
                const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                child: Container(
                  height: 270,
                  child: Column(
                    children: [
                      Expanded(
                        flex: 8,
                        child: Container(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: SelectableText(
                              '${After_Translate}',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.center,
                              onTap: () {
                                print('Text tapped!');
                              },
                              showCursor: true,
                              cursorColor: Colors.blue,
                              cursorWidth: 2,
                            ),
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                      Divider(
                        color: Colors.grey.shade300,
                        height: 2,
                        indent: 20,
                        endIndent: 20,
                      ),
                      Expanded(
                        flex: 2,
                        child: Container(
                          child: Padding(
                            padding:
                            const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                              children: [
                                Text("${After_Counter_Text} / 5.000"),
                                Container(
                                  width: 100,
                                  child: Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                    children: [
                                      IconButton(
                                        icon: _isProcessing
                                            ? CircularProgressIndicator(
                                          valueColor:
                                          AlwaysStoppedAnimation<Color>(Colors.white),
                                        )
                                            : SvgPicture.asset(
                                          'assets/speaker-2-svgrepo-com.svg',
                                        ),
                                        color: Colors.black,
                                        onPressed: ()
                                        {
                                          setState(() {
                                            _isProcessing ? null : _speak(After_Translate);
                                          });
                                        },
                                      ),
                                      IconButton(
                                        icon: SvgPicture.asset(
                                          'assets/copy-svgrepo-com.svg',
                                        ),
                                        color: Colors.black,
                                        onPressed:_copyStaticText,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ],
                  ),
                  decoration: BoxDecoration(
                    // color: Colors.red,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.grey.shade300,width: 2),),
                ),
              ),
            ),
            Padding(
              padding:
              const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _isListening = false;
                    _sendChatMessage(Befor_Translate.text,selectedLanguage_1);
                  });
                },
                child: Container(
                  height: 80,
                  child: Center(
                    child: Text(
                      'Translate',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
