import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const AIChatbotApp());
}

class AIChatbotApp extends StatelessWidget {
  const AIChatbotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Chatbot V2',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
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

  final ScrollController scrollController =
      ScrollController();

  final List<Map<String, String>> messages = [];

  bool isLoading = false;

  // --------------------------------------------------
  // AUTOMATIC SCROLL
  // --------------------------------------------------

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) {
        return;
      }

      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    });
  }

  // --------------------------------------------------
  // SEND MESSAGE
  // --------------------------------------------------

  Future<void> sendMessage() async {
    final message = messageController.text.trim();

    if (message.isEmpty || isLoading) {
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

    scrollToBottom();

    try {
      final url = Uri.parse(
        'http://127.0.0.1:8000/chat?message=${Uri.encodeComponent(message)}',
      );

      final response = await http.get(url);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          messages.add({
            'sender': 'ai',
            'message':
                data['message'] ?? 'No response received.',
          });
        });

        scrollToBottom();
      } else {
        setState(() {
          messages.add({
            'sender': 'ai',
            'message':
                'Server error: ${response.statusCode}',
          });
        });

        scrollToBottom();
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        messages.add({
          'sender': 'ai',
          'message':
              'Could not connect to the backend.\n\n'
              'Please make sure the FastAPI server is running.',
        });
      });

      scrollToBottom();
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });
  }

  // --------------------------------------------------
  // OPEN LINKS
  // --------------------------------------------------

  Future<void> openLink(String text, String? href, String title) async {
    if (href == null) {
      return;
    }

    final Uri? uri = Uri.tryParse(href);

    if (uri == null) {
      return;
    }

    try {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open this link.'),
        ),
      );
    }
  }

  // --------------------------------------------------
  // MESSAGE BUBBLE
  // --------------------------------------------------

  Widget buildMessage(Map<String, String> message) {
    final bool isUser = message['sender'] == 'user';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      child: Row(
        mainAxisAlignment:
            isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI AVATAR
          if (!isUser)
            Container(
              width: 38,
              height: 38,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.indigo.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  '🤖',
                  style: TextStyle(fontSize: 22),
                ),
              ),
            ),

          // MESSAGE
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color:
                    isUser
                        ? Colors.indigo
                        : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft:
                      Radius.circular(
                        isUser ? 18 : 4,
                      ),
                  bottomRight:
                      Radius.circular(
                        isUser ? 4 : 18,
                      ),
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                    color:
                        Colors.black.withValues(
                      alpha: 0.08,
                    ),
                  ),
                ],
              ),

              // USER TEXT / AI MARKDOWN
              child:
                  isUser
                      ? Text(
                          message['message']!,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.4,
                            color: Colors.white,
                          ),
                        )
                      : MarkdownBody(
                          data: message['message']!,
                          selectable: true,

                          onTapLink: openLink,

                          styleSheet:
                              MarkdownStyleSheet(
                            p: const TextStyle(
                              fontSize: 16,
                              height: 1.4,
                              color: Colors.black87,
                            ),

                            h1: const TextStyle(
                              fontSize: 24,
                              fontWeight:
                                  FontWeight.bold,
                              color: Colors.black87,
                            ),

                            h2: const TextStyle(
                              fontSize: 21,
                              fontWeight:
                                  FontWeight.bold,
                              color: Colors.black87,
                            ),

                            h3: const TextStyle(
                              fontSize: 18,
                              fontWeight:
                                  FontWeight.bold,
                              color: Colors.black87,
                            ),

                            strong: const TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                              color: Colors.black87,
                            ),

                            listBullet:
                                const TextStyle(
                              fontSize: 16,
                              color:
                                  Colors.black87,
                            ),

                            code: TextStyle(
                              fontFamily:
                                  'monospace',
                              fontSize: 14,
                              backgroundColor:
                                  Colors.grey.shade200,
                            ),

                            blockquote:
                                TextStyle(
                              color:
                                  Colors.grey.shade700,
                              fontStyle:
                                  FontStyle.italic,
                            ),

                            a: const TextStyle(
                              color: Colors.indigo,
                              decoration:
                                  TextDecoration
                                      .underline,
                            ),
                          ),
                        ),
            ),
          ),

          // USER AVATAR
          if (isUser)
            Container(
              width: 38,
              height: 38,
              margin: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                color: Colors.indigo.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
                size: 22,
              ),
            ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // DISPOSE CONTROLLERS
  // --------------------------------------------------

  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  // --------------------------------------------------
  // BUILD APP
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // APP BAR
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '🤖',
              style: TextStyle(fontSize: 24),
            ),

            SizedBox(width: 8),

            Text(
              'AI Chatbot',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),

        centerTitle: true,

        backgroundColor: Colors.white,

        elevation: 1,
      ),

      // BODY
      body: Column(
        children: [
          // CHAT AREA
          Expanded(
            child:
                messages.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize:
                              MainAxisSize.min,
                          children: [
                            Text(
                              '🤖',
                              style: TextStyle(
                                fontSize: 55,
                              ),
                            ),

                            SizedBox(height: 12),

                            Text(
                              'How can I help you?',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),

                            SizedBox(height: 6),

                            Text(
                              'Ask me anything...',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller:
                            scrollController,

                        padding:
                            const EdgeInsets.only(
                          top: 16,
                          bottom: 10,
                        ),

                        itemCount:
                            messages.length,

                        itemBuilder:
                            (context, index) {
                          return buildMessage(
                            messages[index],
                          );
                        },
                      ),
          ),

          // THINKING INDICATOR
          if (isLoading)
            const Padding(
              padding: EdgeInsets.only(
                left: 20,
                bottom: 8,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '🤖 AI is thinking...',
                  style: TextStyle(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),

          // INPUT AREA
          Container(
            padding:
                const EdgeInsets.fromLTRB(
              12,
              8,
              12,
              12,
            ),

            decoration: BoxDecoration(
              color: Colors.white,

              boxShadow: [
                BoxShadow(
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                  color:
                      Colors.black.withValues(
                    alpha: 0.06,
                  ),
                ),
              ],
            ),

            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.end,
              children: [
                // TEXT FIELD
                Expanded(
                  child: TextField(
                    controller:
                        messageController,

                    minLines: 1,

                    maxLines: 4,

                    textInputAction:
                        TextInputAction.send,

                    onSubmitted: (_) {
                      sendMessage();
                    },

                    decoration:
                        InputDecoration(
                      hintText: 'Message AI...',

                      filled: true,

                      fillColor:
                          Colors.grey.shade100,

                      border:
                          OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                          24,
                        ),
                        borderSide:
                            BorderSide.none,
                      ),

                      contentPadding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // SEND BUTTON
                Container(
                  decoration:
                      const BoxDecoration(
                    color: Colors.indigo,
                    shape: BoxShape.circle,
                  ),

                  child: IconButton(
                    onPressed:
                        isLoading
                            ? null
                            : sendMessage,

                    icon: const Icon(
                      Icons.arrow_upward,
                      color: Colors.white,
                    ),

                    tooltip: 'Send',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}