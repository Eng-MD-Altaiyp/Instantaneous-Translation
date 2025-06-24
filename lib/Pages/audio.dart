import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:ui' as ui;


class TextToAudio extends StatefulWidget {
  @override
  _TextToAudioState createState() => _TextToAudioState();
}

enum TtsState { playing, stopped, paused, continued }

class _TextToAudioState extends State<TextToAudio> {
  late FlutterTts _flutterTts;
  String _text = '';
  List<dynamic> _ttsLanguages = [];
  late String _ttsLanguage;
  TtsState ttsState = TtsState.stopped;

  TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _flutterTts = FlutterTts();
    _initTts();
  }


  void _initTts() async {
    _ttsLanguages = await _flutterTts.getLanguages;

    String systemLanguage = ui.window.locale.toString();

    // التحقق مما إذا كانت لغة النظام متاحة في قائمة لغات TTS
    if (_ttsLanguages.contains(systemLanguage)) {
      _ttsLanguage = systemLanguage;
    } else if (_ttsLanguages.contains('ar-SA')) {
      _ttsLanguage = 'ar-SA'; // تعيين اللغة العربية إذا كانت متاحة
    } else {
      _ttsLanguage = _ttsLanguages.first;
    }

    setState(() {
      _ttsLanguage = _ttsLanguage;
    });

    _flutterTts.setStartHandler(() {
      setState(() {
        ttsState = TtsState.playing;
      });
    });

    _flutterTts.setCompletionHandler(() {
      setState(() {
        ttsState = TtsState.stopped;
      });
    });

    _flutterTts.setErrorHandler((msg) {
      setState(() {
        ttsState = TtsState.stopped;
      });
    });
  }

  Future _speak() async {
    if (_text.isNotEmpty) {
      await _flutterTts.setLanguage(_ttsLanguage);
      await _flutterTts.speak(_text);
    }
  }

  Future _stop() async {
    await _flutterTts.stop();
    setState(() {
      ttsState = TtsState.stopped;
    });
  }

  Widget _buildTtsLanguageDropdown() {
    return DropdownButton<String>(
      value: _ttsLanguage,
      items: _ttsLanguages
          .map<DropdownMenuItem<String>>(
            (lang) => DropdownMenuItem<String>(
          child: Text(lang),
          value: lang,
        ),
      )
          .toList(),
      onChanged: (selectedLang) {
        setState(() {
          _ttsLanguage = selectedLang!;
        });
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
    _flutterTts.stop();
    _textController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('قراءة النص بصوت عالٍ'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Text('اختر اللغة: '),
                Expanded(child: _buildTtsLanguageDropdown()),
              ],
            ),
            SizedBox(height: 20),
            Expanded(
              child: TextField(
                controller: _textController,
                maxLines: null,
                expands: true,
                decoration: InputDecoration(
                  hintText: 'أدخل النص هنا...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _text = value;
                  });
                },
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: ttsState == TtsState.playing ? _stop : _speak,
              icon: Icon(
                ttsState == TtsState.playing ? Icons.stop : Icons.volume_up,
                size: 24,
              ),
              label: Text(
                ttsState == TtsState.playing ? 'إيقاف' : 'استماع',
                style: TextStyle(fontSize: 18),
              ),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12), backgroundColor: Colors.indigo,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
