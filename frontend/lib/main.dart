import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'login_page.dart';

void main() {
  runApp(const NexaApp());
}

// ============================================================
// NEXA APP
// ============================================================

class NexaApp extends StatelessWidget {
  const NexaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NEXA AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.dark,
      ),
      home: const AuthGate(),
    );
  }
}

// ============================================================
// AUTH GATE
// ============================================================

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checking = true;
  bool _loggedIn = false;
  bool _guestMode = false;

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final loggedIn = await AuthService.isLoggedIn();

    if (!mounted) return;

    setState(() {
      _loggedIn = loggedIn;
      _checking = false;
    });
  }

  void _loginSuccess() {
    setState(() {
      _loggedIn = true;
      _guestMode = false;
    });
  }

  void _continueAsGuest() {
    setState(() {
      _loggedIn = false;
      _guestMode = true;
    });
  }

  Future<void> _logout() async {
    await AuthService.logout();

    if (!mounted) return;

    setState(() {
      _loggedIn = false;
      _guestMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Logged-in user OR guest
    if (_loggedIn || _guestMode) {
      return NexaHome(
        isGuest: _guestMode,
        onLogout: _logout,
      );
    }

    // Login screen
    return LoginPage(
      onLoginSuccess: _loginSuccess,
      onGuestMode: _continueAsGuest,
    );
  }
}

// ============================================================
// CHAT MESSAGE
// ============================================================

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? time,
  }) : time = time ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'isUser': isUser,
      'time': time.toIso8601String(),
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['text']?.toString() ?? '',
      isUser: json['isUser'] == true,
      time: DateTime.tryParse(
            json['time']?.toString() ?? '',
          ) ??
          DateTime.now(),
    );
  }
}

// ============================================================
// CONVERSATION
// ============================================================

class ChatConversation {
  final String id;
  String title;
  DateTime updatedAt;
  List<ChatMessage> messages;

  ChatConversation({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.messages,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'updatedAt': updatedAt.toIso8601String(),
      'messages': messages.map((e) => e.toJson()).toList(),
    };
  }

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    final messages = json['messages'];

    return ChatConversation(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'New Chat',
      updatedAt: DateTime.tryParse(
            json['updatedAt']?.toString() ?? '',
          ) ??
          DateTime.now(),
      messages: messages is List
          ? messages
              .whereType<Map>()
              .map(
                (e) => ChatMessage.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList()
          : [],
    );
  }
}

// ============================================================
// NEXA HOME
// ============================================================

class NexaHome extends StatefulWidget {
  final bool isGuest;
  final VoidCallback onLogout;

  const NexaHome({
    super.key,
    required this.isGuest,
    required this.onLogout,
  });

  @override
  State<NexaHome> createState() => _NexaHomeState();
}

class _NexaHomeState extends State<NexaHome> {
  int _selectedPage = 0;

  bool _darkMode = true;
  int _wallpaper = 0;

  String _userName = 'User';
  String _userEmail = '';
  String? _profileImageBase64;
  int _avatar = 0;

  bool _loading = true;

  List<ChatConversation> _conversations = [];

  List<ChatMessage> _currentMessages = [];

  String? _currentConversationId;

  static const List<String> wallpaperNames = [
    'Default',
    'Aurora',
    'Ocean',
    'Sunset',
    'Forest',
    'Midnight',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ==========================================================
  // LOAD DATA
  // ==========================================================

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    final savedName = await AuthService.getUserName();
    final savedEmail = await AuthService.getUserEmail();

    final savedProfileImage = prefs.getString('nexa_profile_image');
    final savedAvatar = prefs.getInt('nexa_avatar') ?? 0;

    final historyJson =
        prefs.getString('nexa_conversations');

    final currentMessagesJson =
        prefs.getString('nexa_current_messages');

    List<ChatConversation> conversations = [];

    if (historyJson != null) {
      try {
        final decoded = jsonDecode(historyJson);

        if (decoded is List) {
          conversations = decoded
              .whereType<Map>()
              .map(
                (item) => ChatConversation.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList();
        }
      } catch (_) {}
    }

    List<ChatMessage> messages = [];

    if (currentMessagesJson != null) {
      try {
        final decoded = jsonDecode(currentMessagesJson);

        if (decoded is List) {
          messages = decoded
              .whereType<Map>()
              .map(
                (item) => ChatMessage.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList();
        }
      } catch (_) {}
    }

    if (!mounted) return;

    setState(() {
      _userName = widget.isGuest
          ? 'Guest'
          : (savedName ?? 'User');

      _userEmail = widget.isGuest
          ? ''
          : (savedEmail ?? '');

      _profileImageBase64 = widget.isGuest ? null : savedProfileImage;
      _avatar = widget.isGuest ? 0 : savedAvatar.clamp(0, 5);

      _darkMode =
          prefs.getBool('nexa_dark_mode') ?? true;

      _wallpaper =
          prefs.getInt('nexa_wallpaper') ?? 0;

      _conversations = conversations;

      _currentMessages = messages;

      _loading = false;
    });
  }

  // ==========================================================
  // SAVE DATA
  // ==========================================================

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(
      'nexa_dark_mode',
      _darkMode,
    );

    await prefs.setInt(
      'nexa_wallpaper',
      _wallpaper,
    );

    await prefs.setInt(
      'nexa_avatar',
      _avatar,
    );

    if (_profileImageBase64 != null && _profileImageBase64!.isNotEmpty) {
      await prefs.setString(
        'nexa_profile_image',
        _profileImageBase64!,
      );
    } else {
      await prefs.remove('nexa_profile_image');
    }

    await prefs.setString(
      'nexa_conversations',
      jsonEncode(
        _conversations
            .map((e) => e.toJson())
            .toList(),
      ),
    );

    await prefs.setString(
      'nexa_current_messages',
      jsonEncode(
        _currentMessages
            .map((e) => e.toJson())
            .toList(),
      ),
    );
  }

  // ==========================================================
  // SAVE CURRENT CHAT
  // ==========================================================

  Future<void> _saveCurrentConversation() async {
    if (_currentMessages.isEmpty) {
      await _saveData();
      return;
    }

    final id =
        _currentConversationId ??
        DateTime.now()
            .microsecondsSinceEpoch
            .toString();

    String title = 'New Chat';

    final userMessages = _currentMessages
        .where((message) => message.isUser)
        .toList();

    if (userMessages.isNotEmpty) {
      title = userMessages.first.text.trim();

      if (title.length > 40) {
        title = '${title.substring(0, 40)}...';
      }
    }

    final conversation = ChatConversation(
      id: id,
      title: title,
      updatedAt: DateTime.now(),
      messages: List.from(_currentMessages),
    );

    final index = _conversations
        .indexWhere((item) => item.id == id);

    setState(() {
      _currentConversationId = id;

      if (index >= 0) {
        _conversations[index] = conversation;
      } else {
        _conversations.insert(
          0,
          conversation,
        );
      }
    });

    await _saveData();
  }

  // ==========================================================
  // NEW CHAT
  // ==========================================================

  Future<void> _newChat() async {
    await _saveCurrentConversation();

    setState(() {
      _currentMessages = [];
      _currentConversationId = null;
      _selectedPage = 0;
    });

    await _saveData();
  }

  // ==========================================================
  // OPEN CHAT
  // ==========================================================

  void _openConversation(
    ChatConversation conversation,
  ) {
    setState(() {
      _currentConversationId =
          conversation.id;

      _currentMessages =
          List.from(conversation.messages);

      _selectedPage = 0;
    });
  }

  // ==========================================================
  // DELETE CHAT
  // ==========================================================

  Future<void> _deleteConversation(
    String id,
  ) async {
    setState(() {
      _conversations.removeWhere(
        (item) => item.id == id,
      );

      if (_currentConversationId == id) {
        _currentConversationId = null;
        _currentMessages = [];
      }
    });

    await _saveData();
  }

  // ==========================================================
  // MESSAGES CHANGED
  // ==========================================================

  Future<void> _messagesChanged(
    List<ChatMessage> messages,
  ) async {
    setState(() {
      _currentMessages =
          List.from(messages);
    });

    await _saveCurrentConversation();
  }

  // ==========================================================
  // BACKGROUND
  // ==========================================================

  LinearGradient _getBackground() {
    switch (_wallpaper) {
      case 1:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF141E30),
            Color(0xFF243B55),
            Color(0xFF6A3093),
          ],
        );

      case 2:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF005AA7),
            Color(0xFF56CCF2),
            Color(0xFF0F2027),
          ],
        );

      case 3:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF355C7D),
            Color(0xFFC06C84),
            Color(0xFFF67280),
          ],
        );

      case 4:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF134E5E),
            Color(0xFF71B280),
            Color(0xFF203A43),
          ],
        );

      case 5:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF000428),
            Color(0xFF004E92),
            Color(0xFF020111),
          ],
        );

      default:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _darkMode
              ? const [
                  Color(0xFF0F1020),
                  Color(0xFF17152D),
                  Color(0xFF24143B),
                ]
              : const [
                  Color(0xFFF7F3FF),
                  Color(0xFFEDE7F6),
                  Color(0xFFE3F2FD),
                ],
        );
    }
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final theme = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: Colors.deepPurple,
      brightness: _darkMode
          ? Brightness.dark
          : Brightness.light,
    );

    return Theme(
      data: theme,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: _getBackground(),
          ),
          child: SafeArea(
            child: Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedPage,
                  onDestinationSelected: (index) {
                    setState(() {
                      _selectedPage = index;
                    });
                  },
                  labelType:
                      NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(
                        Icons.chat_bubble_outline,
                      ),
                      selectedIcon: Icon(
                        Icons.chat_bubble,
                      ),
                      label: Text('Chat'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(
                        Icons.history_outlined,
                      ),
                      selectedIcon: Icon(
                        Icons.history,
                      ),
                      label: Text('History'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(
                        Icons.person_outline,
                      ),
                      selectedIcon: Icon(
                        Icons.person,
                      ),
                      label: Text('Profile'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(
                        Icons.settings_outlined,
                      ),
                      selectedIcon: Icon(
                        Icons.settings,
                      ),
                      label: Text('Settings'),
                    ),
                  ],
                ),

                const VerticalDivider(
                  width: 1,
                ),

                Expanded(
                  child: _buildPage(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // PAGE SELECTOR
  // ==========================================================

  Widget _buildPage() {
    switch (_selectedPage) {
      case 1:
        return HistoryPage(
          conversations: _conversations,
          onOpen: _openConversation,
          onDelete: _deleteConversation,
          onNewChat: _newChat,
        );

      case 2:
        return ProfilePage(
          name: _userName,
          email: _userEmail,
          isGuest: widget.isGuest,
          profileImageBase64: _profileImageBase64,
          avatarIndex: _avatar,
          onNameChanged: (value) async {
            final trimmed = value.trim();
            if (trimmed.isEmpty) return;
            setState(() {
              _userName = trimmed;
            });
            await _saveData();
          },
          onProfileImageChanged: (value) async {
            setState(() {
              _profileImageBase64 = value;
            });
            await _saveData();
          },
          onAvatarChanged: (value) async {
            setState(() {
              _avatar = value;
              _profileImageBase64 = null;
            });
            await _saveData();
          },
        );

      case 3:
        return SettingsPage(
          isGuest: widget.isGuest,
          darkMode: _darkMode,
          wallpaper: _wallpaper,
          wallpaperNames: wallpaperNames,
          onDarkModeChanged: (value) {
            setState(() {
              _darkMode = value;
            });

            _saveData();
          },
          onWallpaperChanged: (value) {
            setState(() {
              _wallpaper = value;
            });

            _saveData();
          },
          onLogout: widget.onLogout,
        );

      default:
        return ChatPage(
          isGuest: widget.isGuest,
          messages: _currentMessages,
          onMessagesChanged:
              _messagesChanged,
          onNewChat: _newChat,
        );
    }
  }
}

// ============================================================
// CHAT PAGE
// ============================================================

class ChatPage extends StatefulWidget {
  final bool isGuest;
  final List<ChatMessage> messages;
  final Future<void> Function(
    List<ChatMessage>,
  ) onMessagesChanged;
  final Future<void> Function() onNewChat;

  const ChatPage({
    super.key,
    required this.isGuest,
    required this.messages,
    required this.onMessagesChanged,
    required this.onNewChat,
  });

  @override
  State<ChatPage> createState() =>
      _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  static const String baseUrl =
      'http://127.0.0.1:8000';

  final TextEditingController _controller =
      TextEditingController();

  final ScrollController _scrollController =
      ScrollController();

  late List<ChatMessage> _messages;

  bool _sending = false;

  @override
  void initState() {
    super.initState();

    _messages =
        List.from(widget.messages);
  }

  @override
  void didUpdateWidget(
    covariant ChatPage oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.messages !=
        widget.messages) {
      _messages =
          List.from(widget.messages);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  // ==========================================================
  // SEND MESSAGE
  // ==========================================================

  Future<void> _sendMessage() async {
    final text =
        _controller.text.trim();

    if (text.isEmpty || _sending) {
      return;
    }

    _controller.clear();

    final userMessage = ChatMessage(
      text: text,
      isUser: true,
    );

    setState(() {
      _messages.add(userMessage);
      _sending = true;
    });

    await widget.onMessagesChanged(
      _messages,
    );

    _scrollToBottom();

    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/chat?message=${Uri.encodeQueryComponent(text)}',
        ),
      );

      final data =
          jsonDecode(response.body);

      String answer;

      if (response.statusCode == 200 &&
          data['message'] != null) {
        answer =
            data['message'].toString();
      } else if (data['error'] != null) {
        answer =
            'Backend error:\n${data['error']}';
      } else {
        answer =
            'Sorry, I could not get a response from NEXA AI.';
      }

      final aiMessage = ChatMessage(
        text: answer,
        isUser: false,
      );

      if (!mounted) return;

      setState(() {
        _messages.add(aiMessage);
      });

      await widget.onMessagesChanged(
        _messages,
      );
    } catch (_) {
      if (!mounted) return;

      final errorMessage = ChatMessage(
        text:
            'Could not connect to the backend.\n\n'
            'Please make sure FastAPI is running at:\n'
            '$baseUrl',
        isUser: false,
      );

      setState(() {
        _messages.add(errorMessage);
      });

      await widget.onMessagesChanged(
        _messages,
      );
    }

    if (!mounted) return;

    setState(() {
      _sending = false;
    });

    _scrollToBottom();
  }

  // ==========================================================
  // SCROLL
  // ==========================================================

  void _scrollToBottom() {
    WidgetsBinding.instance
        .addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController
            .position
            .maxScrollExtent,
        duration:
            const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // HEADER
        Padding(
          padding:
              const EdgeInsets.fromLTRB(
            20,
            12,
            20,
            8,
          ),
          child: Row(
            children: [
              const CircleAvatar(
                child: Icon(
                  Icons.auto_awesome,
                ),
              ),

              const SizedBox(width: 12),

              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NEXA AI',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Your AI assistant',
                    ),
                  ],
                ),
              ),

              if (widget.isGuest)
                const Chip(
                  avatar: Icon(
                    Icons.person_outline,
                    size: 18,
                  ),
                  label:
                      Text('Guest Mode'),
                ),

              IconButton(
                tooltip: 'New Chat',
                onPressed:
                    widget.onNewChat,
                icon: const Icon(
                  Icons.add_comment_outlined,
                ),
              ),
            ],
          ),
        ),

        const Divider(),

        // MESSAGES
        Expanded(
          child: _messages.isEmpty
              ? _welcome()
              : ListView.builder(
                  controller:
                      _scrollController,
                  padding:
                      const EdgeInsets.all(20),
                  itemCount:
                      _messages.length,
                  itemBuilder:
                      (context, index) {
                    return MessageBubble(
                      message:
                          _messages[index],
                    );
                  },
                ),
        ),

        if (_sending)
          const Padding(
            padding:
                EdgeInsets.only(bottom: 8),
            child: Text(
              'NEXA is thinking...',
            ),
          ),

        // INPUT
        Padding(
          padding:
              const EdgeInsets.fromLTRB(
            16,
            8,
            16,
            16,
          ),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller:
                      _controller,
                  minLines: 1,
                  maxLines: 6,
                  decoration:
                      InputDecoration(
                    hintText:
                        'Message NEXA AI...',
                    filled: true,
                    border:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(
                        22,
                      ),
                      borderSide:
                          BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) {
                    _sendMessage();
                  },
                ),
              ),

              const SizedBox(width: 8),

              FloatingActionButton(
                mini: true,
                onPressed:
                    _sending
                        ? null
                        : _sendMessage,
                child: const Icon(
                  Icons.send,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _welcome() {
    return Center(
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.auto_awesome,
            size: 70,
          ),

          const SizedBox(height: 20),

          const Text(
            'How can I help you?',
            style: TextStyle(
              fontSize: 28,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            widget.isGuest
                ? 'You are using NEXA AI as a guest.'
                : 'Ask NEXA AI anything.',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// MESSAGE BUBBLE
// ============================================================

class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isUser =
        message.isUser;

    return Align(
      alignment: isUser
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints:
            const BoxConstraints(
          maxWidth: 800,
        ),
        margin:
            const EdgeInsets.only(
          bottom: 12,
        ),
        padding:
            const EdgeInsets.all(15),
        decoration:
            BoxDecoration(
          color: isUser
              ? Theme.of(context)
                  .colorScheme
                  .primaryContainer
              : Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest,
          borderRadius:
              BorderRadius.circular(
            18,
          ),
        ),
        child: isUser
            ? Text(message.text)
            : MarkdownBody(
                data: message.text,
                selectable: true,
              ),
      ),
    );
  }
}

// ============================================================
// HISTORY PAGE
// ============================================================

class HistoryPage extends StatelessWidget {
  final List<ChatConversation>
      conversations;

  final void Function(
    ChatConversation,
  ) onOpen;

  final Future<void> Function(
    String,
  ) onDelete;

  final Future<void> Function()
      onNewChat;

  const HistoryPage({
    super.key,
    required this.conversations,
    required this.onOpen,
    required this.onDelete,
    required this.onNewChat,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          title: const Text(
            'Chat History',
            style: TextStyle(
              fontSize: 26,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          subtitle: Text(
            '${conversations.length} conversation(s)',
          ),
          trailing:
              FilledButton.icon(
            onPressed: onNewChat,
            icon: const Icon(
              Icons.add,
            ),
            label:
                const Text('New Chat'),
          ),
        ),

        const Divider(),

        Expanded(
          child: conversations.isEmpty
              ? const Center(
                  child: Text(
                    'No saved conversations yet.',
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.all(
                    12,
                  ),
                  itemCount:
                      conversations.length,
                  itemBuilder:
                      (context, index) {
                    final conversation =
                        conversations[index];

                    return Card(
                      child: ListTile(
                        leading:
                            const CircleAvatar(
                          child: Icon(
                            Icons.chat,
                          ),
                        ),
                        title: Text(
                          conversation
                              .title,
                          maxLines: 1,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                        ),
                        subtitle: Text(
                          '${conversation.messages.length} messages',
                        ),
                        onTap: () =>
                            onOpen(
                          conversation,
                        ),
                        trailing:
                            IconButton(
                          icon:
                              const Icon(
                            Icons
                                .delete_outline,
                          ),
                          onPressed: () =>
                              onDelete(
                            conversation
                                .id,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ============================================================
// PROFILE PAGE
// ============================================================

class ProfilePage extends StatefulWidget {
  final String name;
  final String email;
  final bool isGuest;
  final String? profileImageBase64;
  final int avatarIndex;
  final Future<void> Function(String) onNameChanged;
  final Future<void> Function(String?) onProfileImageChanged;
  final Future<void> Function(int) onAvatarChanged;

  const ProfilePage({
    super.key,
    required this.name,
    required this.email,
    required this.isGuest,
    required this.profileImageBase64,
    required this.avatarIndex,
    required this.onNameChanged,
    required this.onProfileImageChanged,
    required this.onAvatarChanged,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late TextEditingController _nameController;
  bool _editingName = false;
  bool _pickingImage = false;

  static const List<_AvatarOption> avatars = [
    _AvatarOption(
      emoji: '🤖',
      name: 'NEXA Bot',
      icon: Icons.smart_toy_rounded,
    ),
    _AvatarOption(
      emoji: '🧑‍🚀',
      name: 'Cosmo',
      icon: Icons.rocket_launch_rounded,
    ),
    _AvatarOption(
      emoji: '🦾',
      name: 'Cyber',
      icon: Icons.precision_manufacturing_rounded,
    ),
    _AvatarOption(
      emoji: '🧙',
      name: 'Wizard',
      icon: Icons.auto_awesome_rounded,
    ),
    _AvatarOption(
      emoji: '🦊',
      name: 'Fox',
      icon: Icons.pets_rounded,
    ),
    _AvatarOption(
      emoji: '🐼',
      name: 'Panda',
      icon: Icons.face_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name);
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name &&
        !_editingName &&
        _nameController.text != widget.name) {
      _nameController.text = widget.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty.')),
      );
      return;
    }

    await widget.onNameChanged(name);

    if (!mounted) return;
    setState(() {
      _editingName = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile name updated! ✨')),
    );
  }

  Future<void> _pickProfileImage() async {
    if (widget.isGuest) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create an account to save a profile picture.'),
        ),
      );
      return;
    }

    if (_pickingImage) return;

    setState(() {
      _pickingImage = true;
    });

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      await widget.onProfileImageChanged(base64Image);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated! 🖼️')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not select image: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _pickingImage = false;
        });
      }
    }
  }

  Future<void> _removeProfileImage() async {
    await widget.onProfileImageChanged(null);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile picture removed.')),
    );
  }

  Future<void> _showAvatarPicker() async {
    if (widget.isGuest) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Guest mode can try avatars, but create an account to save your profile.',
          ),
        ),
      );
    }

    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final screenHeight = MediaQuery.of(context).size.height;
        final sheetHeight = (screenHeight * 0.75).clamp(400.0, 650.0);

        return SafeArea(
          child: SizedBox(
            height: sheetHeight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose your 3D Avatar',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('Pick a character for your NEXA profile.'),
                  const SizedBox(height: 18),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: avatars.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: .95,
                      ),
                      itemBuilder: (context, index) {
                        final avatar = avatars[index];
                        final selectedNow =
                            index == widget.avatarIndex &&
                            widget.profileImageBase64 == null;

                        return InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => Navigator.pop(context, index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selectedNow
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context)
                                        .colorScheme
                                        .outlineVariant,
                                width: selectedNow ? 3 : 1,
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                  Theme.of(context)
                                      .colorScheme
                                      .secondaryContainer,
                                ],
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  avatar.emoji,
                                  style: const TextStyle(fontSize: 48),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  avatar.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selected == null) return;

    await widget.onAvatarChanged(selected);

    if (!mounted) return;
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${avatars[selected].name} avatar selected! 🤖'),
      ),
    );
  }

  Widget _profileVisual(BuildContext context) {
    if (widget.profileImageBase64 != null &&
        widget.profileImageBase64!.isNotEmpty) {
      try {
        return CircleAvatar(
          radius: 62,
          backgroundImage: MemoryImage(
            base64Decode(widget.profileImageBase64!),
          ),
        );
      } catch (_) {
        // Fall back to the selected avatar if old/corrupt image data exists.
      }
    }

    final avatar = avatars[widget.avatarIndex.clamp(0, avatars.length - 1).toInt()];

    return Container(
      width: 124,
      height: 124,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
        ),
        boxShadow: const [
          BoxShadow(
            blurRadius: 22,
            spreadRadius: 2,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: Text(
          avatar.emoji,
          style: const TextStyle(fontSize: 66),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarName =
        avatars[widget.avatarIndex.clamp(0, avatars.length - 1).toInt()].name;

    return ListView(
      padding: const EdgeInsets.all(25),
      children: [
        const Text(
          'Profile',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 25),

        // PROFILE AVATAR
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _profileVisual(context),
              Positioned(
                right: -2,
                bottom: 4,
                child: Material(
                  color: Theme.of(context).colorScheme.primary,
                  shape: const CircleBorder(),
                  elevation: 5,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _showAvatarPicker,
                    child: const Padding(
                      padding: EdgeInsets.all(11),
                      child: Icon(
                        Icons.auto_awesome,
                        size: 21,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        Center(
          child: Text(
            widget.profileImageBase64 != null
                ? 'Custom profile picture'
                : '$avatarName • 3D Avatar',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // PROFILE IMAGE BUTTONS
        if (!widget.isGuest)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _pickingImage ? null : _pickProfileImage,
                icon: _pickingImage
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.photo_library_outlined),
                label: const Text('Change Picture'),
              ),
              if (widget.profileImageBase64 != null)
                OutlinedButton.icon(
                  onPressed: _removeProfileImage,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remove'),
                ),
            ],
          ),

        if (widget.isGuest)
          Center(
            child: Text(
              'Guest profile',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),

        const SizedBox(height: 25),

        // NAME CARD
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: _editingName
                ? Column(
                    children: [
                      TextField(
                        controller: _nameController,
                        autofocus: true,
                        maxLength: 40,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Display Name',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _saveName(),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _nameController.text = widget.name;
                                _editingName = false;
                              });
                            },
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: _saveName,
                            icon: const Icon(Icons.check),
                            label: const Text('Save'),
                          ),
                        ],
                      ),
                    ],
                  )
                : ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text('Name'),
                    subtitle: Text(
                      widget.name,
                      style: const TextStyle(fontSize: 16),
                    ),
                    trailing: IconButton(
                      tooltip: 'Edit name',
                      onPressed: () {
                        setState(() {
                          _nameController.text = widget.name;
                          _editingName = true;
                        });
                      },
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 8),

        // EMAIL CARD
        Card(
          child: ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Email'),
            subtitle: Text(
              widget.isGuest ? 'Guest account' : widget.email,
            ),
          ),
        ),

        const SizedBox(height: 8),

        // AVATAR CARD
        Card(
          child: ListTile(
            leading: const Icon(Icons.face_retouching_natural),
            title: const Text('3D Avatar'),
            subtitle: Text(
              widget.profileImageBase64 != null
                  ? 'Using your profile picture'
                  : avatarName,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showAvatarPicker,
          ),
        ),

        if (widget.isGuest)
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Guest Mode'),
              subtitle: Text(
                'Your profile is temporary. Create an account to keep your profile settings.',
              ),
            ),
          ),
      ],
    );
  }
}

class _AvatarOption {
  final String emoji;
  final String name;
  final IconData icon;

  const _AvatarOption({
    required this.emoji,
    required this.name,
    required this.icon,
  });
}

// ============================================================
// SETTINGS PAGE
// ============================================================

class SettingsPage extends StatelessWidget {
  final bool isGuest;
  final bool darkMode;
  final int wallpaper;

  final List<String>
      wallpaperNames;

  final ValueChanged<bool>
      onDarkModeChanged;

  final ValueChanged<int>
      onWallpaperChanged;

  final VoidCallback onLogout;

  const SettingsPage({
    super.key,
    required this.isGuest,
    required this.darkMode,
    required this.wallpaper,
    required this.wallpaperNames,
    required this.onDarkModeChanged,
    required this.onWallpaperChanged,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding:
          const EdgeInsets.all(25),
      children: [
        const Text(
          'Settings',
          style: TextStyle(
            fontSize: 28,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(height: 20),

        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: Icon(
                  darkMode
                      ? Icons.dark_mode
                      : Icons.light_mode,
                ),
                title: const Text(
                  'Dark Mode',
                ),
                subtitle: const Text(
                  'Change app appearance',
                ),
                value: darkMode,
                onChanged:
                    onDarkModeChanged,
              ),

              const Divider(),

              ListTile(
                leading:
                    const Icon(
                  Icons.wallpaper,
                ),
                title: const Text(
                  'App Background',
                ),
                subtitle: Text(
                  wallpaperNames[
                      wallpaper],
                ),
              ),

              Padding(
                padding:
                    const EdgeInsets.all(
                  16,
                ),
                child:
                    DropdownButtonFormField<
                        int>(
                  initialValue:
                      wallpaper,
                  decoration:
                      const InputDecoration(
                    border:
                        OutlineInputBorder(),
                    labelText:
                        'Choose Wallpaper',
                  ),
                  items:
                      List.generate(
                    wallpaperNames
                        .length,
                    (index) {
                      return DropdownMenuItem<
                          int>(
                        value: index,
                        child: Text(
                          wallpaperNames[
                              index],
                        ),
                      );
                    },
                  ),
                  onChanged: (value) {
                    if (value !=
                        null) {
                      onWallpaperChanged(
                        value,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Card(
          child: ListTile(
            leading: Icon(
              isGuest
                  ? Icons.login
                  : Icons.logout,
            ),
            title: Text(
              isGuest
                  ? 'Go to Login'
                  : 'Logout',
            ),
            subtitle: Text(
              isGuest
                  ? 'Sign in to your account'
                  : 'Sign out of your NEXA account',
            ),
            onTap: onLogout,
          ),
        ),

        const SizedBox(height: 25),

        const Center(
          child: Text(
            'NEXA AI • Version 4.0',
            style: TextStyle(
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}