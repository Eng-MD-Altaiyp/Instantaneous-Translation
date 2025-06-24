import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:instantaneous_translation/Connect/message_widget.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final GenerativeModel _model;
  late final ChatSession _chatSession;
  TextEditingController _textController = TextEditingController();
  bool _loading = false;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _textFieldFocus = FocusNode();


  // @override
  // void initState() {
  //   super.initState();
  //   // _model = GenerativeModel(model: 'gemini-1.5-pro', apiKey: const String.fromEnvironment('"GEMINI_API_KEY"'),);
  //   // _chatSession = _model.startChat();
  // }

  @override
  void initState() async{
    super.initState();
    WidgetsFlutterBinding.ensureInitialized(); // لضمان تحميل الأصول قبل الاستخدام

    final apiKey = await loadApiKey();

    final _model = GenerativeModel(
      model: 'gemini-1.5-pro',
      apiKey: apiKey,
    );

    final _chatSession = _model.startChat();
  }
  Future<String> loadApiKey() async {
    try {
      final String response = await rootBundle.loadString('assets/env.json');
      final Map<String, dynamic> data = json.decode(response);
      if (data.containsKey('GEMINI_API_KEY')) {
        return data['GEMINI_API_KEY'];
      } else {
        throw Exception('GEMINI_API_KEY not found in env.json');
      }
    } catch (e) {
      throw Exception('Error loading env.json: $e');
    }
  }

  // Future<void> _initModel() async {
  //   final apiKey = Platform.environment['GEMINI_API_KEY'];
  //   if (apiKey == null) {
  //     print(r'No $GEMINI_API_KEY environment variable');
  //     return;
  //   }
  //   _model = GenerativeModel(
  //     model: 'gemini-1.5-flash',
  //     apiKey: apiKey,
  //     generationConfig: GenerationConfig(
  //       temperature: 1,
  //       topK: 40,
  //       topP: 0.95,
  //       maxOutputTokens: 8192,
  //       responseMimeType: 'text/plain',
  //     ),
  //   );
  // }
  //
  // Future<void> _sendMessage() async {
  //   if (_formKey.currentState!.validate()) {
  //     // إضافة رسالة المستخدم إلى قائمة الدردشة
  //     setState(() {
  //       _chatMessages.add(ChatMessage(
  //         message: _messageController.text,
  //         sender: 'user',
  //       ));
  //       _messageController.clear();
  //     });
  //
  //     // إرسال الرسالة إلى Gemini API
  //     final chat = _model.startChat(history: _chatMessages.map((message) => Content.text(message.message)).toList()); // تعديل
  //     final response = await chat.sendMessage(Content.text(_messageController.text));
  //
  //     // إضافة رد Gemini إلى قائمة الدردشة
  //     setState(() {
  //       _chatMessages.add(ChatMessage(
  //         message: response.toString(), // تعديل
  //         sender: 'ai',
  //       ));
  //     });
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Translation with Gemini'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: _chatSession.history.length,
                controller: _scrollController,
                itemBuilder: (context, index) {
                  final Content content = _chatSession.history.toList()[index];
                  final text = content.parts.whereType<TextPart>().map<String>((e)=>e.text).join('');
                  return MessageWidget(text: text, isFromUser: content.role=='user',);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 25.0,horizontal: 15),
              child: Row(
                children: [

                  Expanded(
                    child: TextField(
                      autocorrect: true,
                      focusNode: _textFieldFocus,
                      controller: _textController,
                      decoration: textFieldDecoration(),
                      onSubmitted: _sendChatMessage,

                    ),
                  ),
                  const SizedBox(height: 15,),

                  IconButton(
                    onPressed: () {
                      _sendChatMessage(_textController.text.toString());
                    },
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  InputDecoration textFieldDecoration()
  {
    return InputDecoration(
      contentPadding: const EdgeInsets.all(15),
      hintText: 'Enter a promt...',
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.secondary,),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.secondary),
      )

    );
  }

  Future<void> _sendChatMessage(String message)async
  {
    setState(() {
      _loading = true;
    });
    try{
      final response = await _chatSession.sendMessage(Content.text(""+message),);
      final text = response.text;
      if(text == null)
        {
          _showError('No response from API');
          return;
        }
      else{
        setState(() {
          _loading = false;
          _scrollDown();
        });
      }
    }
    catch(e)
    {
      _showError(e.toString());
      setState(() {
        _loading = false;
      });
    }
    finally{
      _textController.clear();
      setState(() {
        _loading = false;
      });
      _textFieldFocus.requestFocus();
    }
  }
  void _showError(String message)
  {
    showDialog(context: context, builder: (context)
    {
      return AlertDialog(
        title: Text('Something went wrong'),
        content: SingleChildScrollView(
          child: SelectableText(message),
        ),
        actions: [
          TextButton(onPressed: ()
              {
                Navigator.of(context).pop();
              },
              child: Text("OK"),
          )
        ],
      );
    }
    );
  }
  void _scrollDown()
  {
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
      duration: Duration(milliseconds: 750,),
      curve: Curves.easeOutCirc,),
    );
  }
}
