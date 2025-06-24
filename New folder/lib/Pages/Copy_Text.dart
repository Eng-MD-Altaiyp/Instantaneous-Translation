import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // لاستيراد Clipboard

class CopyPasteTextPage extends StatefulWidget {
  @override
  _CopyPasteTextPageState createState() => _CopyPasteTextPageState();
}

class _CopyPasteTextPageState extends State<CopyPasteTextPage> {
  // متغير String ثابت
  final String staticText = "هذا نص ثابت سيتم نسخه عند الضغط على الزر.";

  // TextEditingController للتحكم في TextField
  final TextEditingController _textController = TextEditingController();

  // متغير لتخزين النص الملصوق
  String pastedText = "";

  // دالة لنسخ نص من متغير String
  void _copyStaticText() {
    Clipboard.setData(ClipboardData(text: staticText)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم نسخ النص الثابت!')),
      );
    });
  }

  // دالة لنسخ نص من TextEditingController
  void _copyTextFromController() {
    String textToCopy = _textController.text;
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

  // دالة للصق النص في TextEditingController
  void _pasteTextToController() async {
    ClipboardData? clipboardData = await Clipboard.getData('text/plain');
    if (clipboardData != null && clipboardData.text != null) {
      setState(() {
        _textController.text = clipboardData.text!;
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

  // دالة للصق النص في متغير String
  void _pasteTextToString() async {
    ClipboardData? clipboardData = await Clipboard.getData('text/plain');
    if (clipboardData != null && clipboardData.text != null) {
      setState(() {
        pastedText = clipboardData.text!;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم لصق النص في المتغير!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('لا يوجد نص في الحافظة للّصق!')),
      );
    }
  }

  @override
  void dispose() {
    // تأكد من تحرير الـ TextEditingController عند التخلص من الـ Widget
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('نسخ ولصق النص في Flutter'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView( // للتأكد من أن المحتوى قابل للتمرير إذا كان الشاشة صغيرة
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, // لجعل الأزرار ممتدة على العرض
            children: [
              // زر لنسخ النص الثابت
              ElevatedButton(
                onPressed: _copyStaticText,
                child: Text('نسخ نص ثابت'),
              ),
              SizedBox(height: 20),
              // TextField لإدخال النص المراد نسخه
              TextField(
                controller: _textController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'أدخل نص لنسخه',
                ),
              ),
              SizedBox(height: 10),
              // صف يحتوي على زرين: نسخ ولصق النص من TextField
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _copyTextFromController,
                      child: Text('نسخ النص من الحقل'),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _pasteTextToController,
                      child: Text('لصق في الحقل'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 30),
              Divider(),
              SizedBox(height: 20),
              // زر للصق النص في متغير String
              ElevatedButton(
                onPressed: _pasteTextToString,
                child: Text('لصق النص في المتغير'),
              ),
              SizedBox(height: 10),
              // عرض النص الملصوق في المتغير
              if (pastedText.isNotEmpty) ...[
                Text(
                  'النص الملصوق:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 5),
                Text(
                  pastedText,
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
