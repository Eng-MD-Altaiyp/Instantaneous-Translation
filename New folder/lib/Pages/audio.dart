import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:math';

class SpeechToTextPage extends StatefulWidget {
  @override
  _SpeechToTextPageState createState() => _SpeechToTextPageState();
}

class _SpeechToTextPageState extends State<SpeechToTextPage> with SingleTickerProviderStateMixin {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = 'اضغط على الزر وابدأ التحدث';
  double _confidence = 1.0;
  late AnimationController _animationController;
  double _currentSoundLevel = 0.0;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
      lowerBound: 0.0,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => _statusListener(val),
        onError: (val) => print('onError: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            if (_text.isEmpty || !_text.endsWith(val.recognizedWords)) {
              _text += ' ' + val.recognizedWords;
            }
            if (val.hasConfidenceRating && val.confidence > 0) {
              _confidence = val.confidence;
            }
          }),
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          onSoundLevelChange: (level) => setState(() {
            _currentSoundLevel = level;
            _animationController.value = min(level / 10, 1.0);
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

  void _statusListener(String status) {
    if (status == 'done') {
      setState(() => _isListening = false);
    }
    print('onStatus: $status');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('دقة التعرف: ${(_confidence * 100.0).toStringAsFixed(1)}%'),
      ),
      body: SingleChildScrollView(
        reverse: true,
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _text,
                style: TextStyle(fontSize: 24.0),
              ),
              SizedBox(height: 40),
              Center(
                child: Container(
                  width: 200,
                  height: 100,
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: SoundLevelPainter(_currentSoundLevel),
                      );
                    },
                  ),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'مستوى الصوت الحالي: ${_currentSoundLevel.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 16.0),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isListening ? _stopListening : _listen,
        child: Icon(_isListening ? Icons.mic : Icons.mic_none),
      ),
    );
  }

  void _stopListening() {
    setState(() => _isListening = false);
    _speech.stop();
  }
}

class SoundLevelPainter extends CustomPainter {
  final double level;

  SoundLevelPainter(this.level);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    double barWidth = size.width / 20;
    double barSpacing = barWidth / 2;

    for (int i = 0; i < 20; i++) {
      double heightFactor = (level / 10) * Random().nextDouble();
      double barHeight = size.height * heightFactor;
      double x = i * (barWidth + barSpacing);
      canvas.drawLine(Offset(x, size.height), Offset(x, size.height - barHeight), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
