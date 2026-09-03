import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const AIChatbotApp());
}

class AIChatbotApp extends StatelessWidget {
  const AIChatbotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Chatbot',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController messageController =
      TextEditingController();

  final List<Map<String, String>> messages = [];

  bool isLoading = false;

  Future<void> sendMessage() async {
    final message = messageController.text.trim();

    if (message.isEmpty) {
      return;
    }

    setState(() {
      messages.add({
        'sender': 'user',
        'message': message,
      });

      isLoading = true;
    });

    messageController.clear();

    try {
      final url = Uri.parse(
        'http://127.0.0.1:8000/chat?message=${Uri.encodeComponent(message)}',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          messages.add({
            'sender': 'ai',
            'message': data['message'] ?? 'No response received.',
          });
        });
      } else {
        setState(() {
          messages.add({
            'sender': 'ai',
            'message': 'Server error: ${response.statusCode}',
          });
        });
      }
    } catch (e) {
      setState(() {
        messages.add({
          'sender': 'ai',
          'message': 'Could not connect to the backend.',
        });
      });
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🤖 AI Chatbot'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];

                final bool isUser =
                    message['sender'] == 'user';

                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(
                      maxWidth: 300,
                    ),
                    decoration: BoxDecoration(
                      color: isUser
                          ? Colors.blue
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      message['message']!,
                      style: TextStyle(
                        color: isUser
                            ? Colors.white
                            : Colors.black,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(),
            ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type your message...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => sendMessage(),
                  ),
                ),

                const SizedBox(width: 8),

                IconButton(
                  onPressed:
                      isLoading ? null : sendMessage,
                  icon: const Icon(Icons.send),
                  iconSize: 30,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}