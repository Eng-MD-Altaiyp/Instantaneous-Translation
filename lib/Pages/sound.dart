import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;



class Sound extends StatefulWidget {
  @override
  _SoundState createState() => _SoundState();
}

class _SoundState extends State<Sound> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = '';
  double _confidence = 1.0;

  List<stt.LocaleName> _localeNames = [];
  late String _currentLocaleId;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();
  }

  void _initSpeech() async {
    bool available = await _speech.initialize(
      onStatus: (val) => setState(() {
        if (val == 'done') {
          _isListening = false;
        }
      }),
      onError: (val) => print('Error: $val'),
    );
    if (available) {
      _localeNames = await _speech.locales();

      var systemLocale = await _speech.systemLocale();
      setState(() {
        _currentLocaleId = systemLocale!.localeId;
      });
    } else {
      print('التعرف على الكلام غير متاح');
    }
  }

  void _startListening() async {
    await _speech.listen(
      onResult: (val) => setState(() {
        _text = val.recognizedWords;
        if (val.hasConfidenceRating && val.confidence > 0) {
          _confidence = val.confidence;
        }
      }),
      localeId: _currentLocaleId,
    );
    setState(() {
      _isListening = true;
    });
  }

  void _stopListening() async {
    await _speech.stop();
    setState(() {
      _isListening = false;
    });
  }

  Widget _buildLocaleDropdown() {
    return DropdownButton<String>(
      value: _currentLocaleId,
      items: _localeNames
          .map(
            (locale) => DropdownMenuItem(
          child: Text(locale.name),
          value: locale.localeId,
        ),
      )
          .toList(),
      onChanged: (selectedLocale) {
        setState(() {
          _currentLocaleId = selectedLocale!;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('تحويل الصوت إلى نص'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildLocaleDropdown(),
            SizedBox(height: 20),
            Expanded(
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.indigo[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  reverse: true,
                  child: Text(
                    _text.isEmpty ? 'اضغط على الميكروفون وابدأ بالتحدث...' : _text,
                    style: TextStyle(fontSize: 24.0, color: Colors.black87),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            FloatingActionButton(
              backgroundColor: Colors.indigo,
              onPressed: _isListening ? _stopListening : _startListening,
              child: Icon(_isListening ? Icons.mic : Icons.mic_none, size: 36),
            ),
            SizedBox(height: 20),
            Text(
              'مستوى الثقة: ${(_confidence * 100.0).toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 18.0, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }
}
