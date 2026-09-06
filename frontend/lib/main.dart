import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const NexaAIApp());
}

// ============================================================
// NEXA AI APP
// ============================================================

class NexaAIApp extends StatefulWidget {
  const NexaAIApp({super.key});

  @override
  State<NexaAIApp> createState() => _NexaAIAppState();
}

class _NexaAIAppState extends State<NexaAIApp> {
  bool darkMode = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      darkMode = prefs.getBool('darkMode') ?? false;
    });
  }

  Future<void> _changeTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('darkMode', value);

    if (!mounted) return;

    setState(() {
      darkMode = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NEXA AI',
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,

      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5146B8),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF9F7FF),
      ),

      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5146B8),
          brightness: Brightness.dark,
        ),
      ),

      home: NexaHome(
        darkMode: darkMode,
        onThemeChanged: _changeTheme,
      ),
    );
  }
}

// ============================================================
// MAIN HOME
// ============================================================

class NexaHome extends StatefulWidget {
  final bool darkMode;
  final Future<void> Function(bool) onThemeChanged;

  const NexaHome({
    super.key,
    required this.darkMode,
    required this.onThemeChanged,
  });

  @override
  State<NexaHome> createState() => _NexaHomeState();
}

class _NexaHomeState extends State<NexaHome> {
  // ----------------------------------------------------------
  // NAVIGATION
  // ----------------------------------------------------------

  int selectedPage = 0;

  // ----------------------------------------------------------
  // PROFILE
  // ----------------------------------------------------------

  String username = 'User';
  String userStatus = 'AI Student';
  String selectedAvatar = '🧑🏻‍💻';
  Uint8List? profileImage;

  // ----------------------------------------------------------
  // HISTORY
  // ----------------------------------------------------------

  List<Map<String, dynamic>> conversations = [];

  // ----------------------------------------------------------
  // CURRENT CHAT
  // ----------------------------------------------------------

  List<Map<String, dynamic>> currentMessages = [];

  String? currentConversationId;

  bool dataLoaded = false;

  // ==========================================================
  // INIT
  // ==========================================================

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  // ==========================================================
  // LOAD EVERYTHING
  // ==========================================================

  Future<void> _loadAllData() async {
    final prefs = await SharedPreferences.getInstance();

    String savedUsername =
        prefs.getString('username') ?? 'User';

    String savedStatus =
        prefs.getString('userStatus') ?? 'AI Student';

    String savedAvatar =
        prefs.getString('avatar') ?? '🧑🏻‍💻';

    Uint8List? savedProfileImage;

    final imageData =
        prefs.getString('profileImage');

    if (imageData != null && imageData.isNotEmpty) {
      try {
        savedProfileImage = base64Decode(imageData);
      } catch (_) {
        savedProfileImage = null;
      }
    }

    List<Map<String, dynamic>> savedConversations = [];

    final historyData =
        prefs.getString('conversationHistory');

    if (historyData != null && historyData.isNotEmpty) {
      try {
        final decoded = jsonDecode(historyData);

        if (decoded is List) {
          savedConversations = decoded
              .map(
                (item) =>
                    Map<String, dynamic>.from(item),
              )
              .toList();
        }
      } catch (_) {
        savedConversations = [];
      }
    }

    if (!mounted) return;

    setState(() {
      username = savedUsername;
      userStatus = savedStatus;
      selectedAvatar = savedAvatar;
      profileImage = savedProfileImage;
      conversations = savedConversations;
      dataLoaded = true;
    });
  }

  // ==========================================================
  // SAVE EVERYTHING
  // ==========================================================

  Future<void> _saveAllData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'username',
      username,
    );

    await prefs.setString(
      'userStatus',
      userStatus,
    );

    await prefs.setString(
      'avatar',
      selectedAvatar,
    );

    if (profileImage != null) {
      await prefs.setString(
        'profileImage',
        base64Encode(profileImage!),
      );
    } else {
      await prefs.remove('profileImage');
    }

    await prefs.setString(
      'conversationHistory',
      jsonEncode(conversations),
    );
  }

  // ==========================================================
  // SAVE CURRENT CHAT
  // ==========================================================

  Future<void> _saveCurrentConversation() async {
    if (!dataLoaded) return;

    if (currentMessages.isEmpty) return;

    // --------------------------------------------------------
    // CREATE ID IF THIS IS A NEW CONVERSATION
    // --------------------------------------------------------

    currentConversationId ??=
        DateTime.now()
            .millisecondsSinceEpoch
            .toString();

    // --------------------------------------------------------
    // CREATE TITLE
    // --------------------------------------------------------

    String title = 'New Conversation';

    for (final message in currentMessages) {
      if (message['role'] == 'user') {
        final content =
            message['content']?.toString() ?? '';

        if (content.isNotEmpty) {
          title = content.length > 45
              ? '${content.substring(0, 45)}...'
              : content;
        }

        break;
      }
    }

    // --------------------------------------------------------
    // COPY MESSAGES
    // --------------------------------------------------------

    final messagesCopy = currentMessages
        .map(
          (message) => <String, dynamic>{
            'role': message['role'],
            'content': message['content'],
          },
        )
        .toList();

    // --------------------------------------------------------
    // FIND EXISTING CONVERSATION
    // --------------------------------------------------------

    final existingIndex =
        conversations.indexWhere(
      (conversation) =>
          conversation['id']?.toString() ==
          currentConversationId,
    );

    final conversation = <String, dynamic>{
      'id': currentConversationId,
      'title': title,
      'date': DateTime.now().toIso8601String(),
      'messages': messagesCopy,
    };

    if (existingIndex >= 0) {
      conversations[existingIndex] =
          conversation;
    } else {
      conversations.insert(
        0,
        conversation,
      );
    }

    // --------------------------------------------------------
    // MOVE CURRENT CONVERSATION TO TOP
    // --------------------------------------------------------

    if (existingIndex >= 0) {
      final updated =
          conversations.removeAt(
        existingIndex,
      );

      conversations.insert(
        0,
        updated,
      );
    }

    await _saveAllData();

    if (!mounted) return;

    setState(() {});
  }

  // ==========================================================
  // NEW CHAT
  // ==========================================================

  Future<void> _newChat() async {
    // Save current conversation first.
    await _saveCurrentConversation();

    if (!mounted) return;

    setState(() {
      currentMessages = [];
      currentConversationId = null;
      selectedPage = 0;
    });
  }

  // ==========================================================
  // OPEN HISTORY
  // ==========================================================

  void _openConversation(
    Map<String, dynamic> conversation,
  ) {
    final rawMessages =
        conversation['messages'];

    if (rawMessages is! List) {
      return;
    }

    final restoredMessages = rawMessages
        .map(
          (item) =>
              Map<String, dynamic>.from(item),
        )
        .toList();

    setState(() {
      currentMessages = restoredMessages;

      currentConversationId =
          conversation['id']?.toString();

      selectedPage = 0;
    });
  }

  // ==========================================================
  // DELETE HISTORY
  // ==========================================================

  Future<void> _deleteConversation(
    int index,
  ) async {
    if (index < 0 ||
        index >= conversations.length) {
      return;
    }

    conversations.removeAt(index);

    await _saveAllData();

    if (!mounted) return;

    setState(() {});
  }

  // ==========================================================
  // UPDATE PROFILE
  // ==========================================================

  Future<void> _updateProfile(
    String name,
    String status,
    String avatar,
    Uint8List? image,
  ) async {
    username =
        name.trim().isEmpty
            ? 'User'
            : name.trim();

    userStatus =
        status.trim().isEmpty
            ? 'AI Student'
            : status.trim();

    selectedAvatar = avatar;
    profileImage = image;

    await _saveAllData();

    if (!mounted) return;

    setState(() {});
  }

  // ==========================================================
  // PAGE TITLE
  // ==========================================================

  String _pageTitle() {
    switch (selectedPage) {
      case 1:
        return 'History';

      case 2:
        return 'My Profile';

      case 3:
        return 'Settings';

      default:
        return 'NEXA AI';
    }
  }

  // ==========================================================
  // PROFILE ICON
  // ==========================================================

  Widget _profileIcon(double size) {
    if (profileImage != null) {
      return ClipOval(
        child: Image.memory(
          profileImage!,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF5146B8),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          selectedAvatar,
          style: TextStyle(
            fontSize: size * 0.48,
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // BUILD PAGE
  // ==========================================================

  Widget _buildPage() {
    if (selectedPage == 1) {
      return HistoryPage(
        conversations: conversations,
        onDelete: _deleteConversation,
        onOpen: _openConversation,
      );
    }

    if (selectedPage == 2) {
      return ProfilePage(
        username: username,
        userStatus: userStatus,
        avatar: selectedAvatar,
        profileImage: profileImage,
        onSave: _updateProfile,
      );
    }

    if (selectedPage == 3) {
      return SettingsPage(
        darkMode: widget.darkMode,
        onDarkModeChanged:
            widget.onThemeChanged,
      );
    }

    return ChatPage(
      username: username,
      avatar: selectedAvatar,
      profileImage: profileImage,
      messages: currentMessages,
      isCurrentConversation:
          currentConversationId != null,
      onMessagesChanged:
          _onMessagesChanged,
    );
  }

  // ==========================================================
  // CHAT MESSAGE CHANGED
  // ==========================================================

  Future<void> _onMessagesChanged(
    List<Map<String, dynamic>> messages,
  ) async {
    currentMessages = messages;

    await _saveCurrentConversation();

    if (!mounted) return;

    setState(() {});
  }

  // ==========================================================
  // MENU
  // ==========================================================

  Widget _menuItem({
    required IconData icon,
    required String title,
    required int page,
  }) {
    final selected =
        selectedPage == page;

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 2,
      ),
      child: ListTile(
        selected: selected,
        selectedTileColor:
            const Color(0xFF5146B8)
                .withAlpha(25),
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(12),
        ),
        leading: Icon(
          icon,
          color: selected
              ? const Color(0xFF5146B8)
              : Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: selected
                ? const Color(0xFF5146B8)
                : null,
            fontWeight: selected
                ? FontWeight.w600
                : FontWeight.normal,
          ),
        ),
        onTap: () {
          setState(() {
            selectedPage = page;
          });
        },
      ),
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    if (!dataLoaded) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          // ====================================================
          // SIDEBAR
          // ====================================================

          SizedBox(
            width: 260,
            child: Container(
              decoration: BoxDecoration(
                color:
                    Theme.of(context).brightness ==
                            Brightness.dark
                        ? const Color(0xFF17151F)
                        : const Color(0xFFFDFBFF),
                border: Border(
                  right: BorderSide(
                    color: Theme.of(context)
                        .dividerColor,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // LOGO
                  Padding(
                    padding:
                        const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration:
                              BoxDecoration(
                            color:
                                const Color(
                              0xFF5146B8,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              13,
                            ),
                          ),
                          child:
                              const Center(
                            child: Text(
                              'N',
                              style:
                                  TextStyle(
                                color:
                                    Colors.white,
                                fontSize: 25,
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 12,
                        ),
                        const Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              'NEXA AI',
                              style:
                                  TextStyle(
                                fontSize: 20,
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),
                            Text(
                              'Your AI Assistant',
                              style:
                                  TextStyle(
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // NEW CHAT
                  Padding(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 8,
                    ),
                    child: SizedBox(
                      width:
                          double.infinity,
                      height: 48,
                      child:
                          FilledButton.icon(
                        onPressed:
                            _newChat,
                        icon:
                            const Icon(
                          Icons.add,
                        ),
                        label:
                            const Text(
                          'New Chat',
                          style:
                              TextStyle(
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  _menuItem(
                    icon: Icons
                        .chat_bubble_outline,
                    title: 'Chat',
                    page: 0,
                  ),

                  _menuItem(
                    icon:
                        Icons.history,
                    title: 'History',
                    page: 1,
                  ),

                  _menuItem(
                    icon:
                        Icons.person_outline,
                    title: 'My Profile',
                    page: 2,
                  ),

                  _menuItem(
                    icon:
                        Icons.settings_outlined,
                    title: 'Settings',
                    page: 3,
                  ),

                  const Spacer(),

                  // USER PROFILE
                  Padding(
                    padding:
                        const EdgeInsets
                            .all(10),
                    child: Container(
                      padding:
                          const EdgeInsets
                              .all(10),
                      decoration:
                          BoxDecoration(
                        color: Theme.of(
                          context,
                        )
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius:
                            BorderRadius
                                .circular(
                          15,
                        ),
                      ),
                      child: Row(
                        children: [
                          _profileIcon(42),

                          const SizedBox(
                            width: 9,
                          ),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                Text(
                                  username,
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                  style:
                                      const TextStyle(
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                                Text(
                                  userStatus,
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                  style:
                                      TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(
                                      context,
                                    )
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ====================================================
          // MAIN
          // ====================================================

          Expanded(
            child: Column(
              children: [
                Container(
                  height: 72,
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 22,
                  ),
                  decoration:
                      BoxDecoration(
                    border: Border(
                      bottom:
                          BorderSide(
                        color:
                            Theme.of(
                          context,
                        ).dividerColor,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (selectedPage == 0)
                        Container(
                          width: 44,
                          height: 44,
                          decoration:
                              const BoxDecoration(
                            color:
                                Color(
                              0xFFE4E6FF,
                            ),
                            shape:
                                BoxShape
                                    .circle,
                          ),
                          child:
                              const Center(
                            child: Text(
                              'N',
                              style:
                                  TextStyle(
                                color:
                                    Color(
                                  0xFF38418F,
                                ),
                                fontWeight:
                                    FontWeight
                                        .bold,
                                fontSize: 21,
                              ),
                            ),
                          ),
                        ),

                      if (selectedPage == 0)
                        const SizedBox(
                          width: 12,
                        ),

                      Text(
                        _pageTitle(),
                        style:
                            const TextStyle(
                          fontSize: 18,
                          fontWeight:
                              FontWeight
                                  .bold,
                        ),
                      ),

                      const Spacer(),

                      if (selectedPage == 0)
                        Container(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 13,
                            vertical: 8,
                          ),
                          decoration:
                              BoxDecoration(
                            color: Colors
                                .green
                                .withAlpha(
                              25,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              20,
                            ),
                          ),
                          child:
                              const Row(
                            children: [
                              Icon(
                                Icons.circle,
                                size: 8,
                                color:
                                    Colors.green,
                              ),
                              SizedBox(
                                width: 7,
                              ),
                              Text(
                                'Online',
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(
                        width: 12,
                      ),

                      if (selectedPage == 0)
                        IconButton(
                          tooltip:
                              'New Chat',
                          onPressed:
                              _newChat,
                          icon:
                              const Icon(
                            Icons
                                .add_box_outlined,
                          ),
                        ),
                    ],
                  ),
                ),

                Expanded(
                  child: _buildPage(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CHAT PAGE
// ============================================================

class ChatPage extends StatefulWidget {
  final String username;
  final String avatar;
  final Uint8List? profileImage;

  final List<Map<String, dynamic>> messages;

  final bool isCurrentConversation;

  final Future<void> Function(
    List<Map<String, dynamic>> messages,
  ) onMessagesChanged;

  const ChatPage({
    super.key,
    required this.username,
    required this.avatar,
    required this.profileImage,
    required this.messages,
    required this.isCurrentConversation,
    required this.onMessagesChanged,
  });

  @override
  State<ChatPage> createState() =>
      _ChatPageState();
}

class _ChatPageState
    extends State<ChatPage> {
  late TextEditingController
      messageController;

  late ScrollController
      scrollController;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();

    messageController =
        TextEditingController();

    scrollController =
        ScrollController();
  }

  // ==========================================================
  // SEND MESSAGE
  // ==========================================================

  Future<void> sendMessage() async {
    final text =
        messageController.text.trim();

    if (text.isEmpty ||
        isLoading) {
      return;
    }

    messageController.clear();

    final userMessage =
        <String, dynamic>{
      'role': 'user',
      'content': text,
    };

    // --------------------------------------------------------
    // SAVE USER MESSAGE IMMEDIATELY
    // --------------------------------------------------------

    final updatedMessages =
        List<Map<String, dynamic>>.from(
      widget.messages,
    );

    updatedMessages.add(
      userMessage,
    );

    await widget.onMessagesChanged(
      updatedMessages,
    );

    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    _scrollToBottom();

    try {
      final uri = Uri.parse(
        'http://127.0.0.1:8000/chat?message=${Uri.encodeComponent(text)}',
      );

      final response =
          await http.get(uri);

      if (response.statusCode == 200) {
        final data =
            jsonDecode(response.body);

        final aiMessage =
            data['message']
                    ?.toString() ??
                'I could not generate a response.';

        final messagesAfterAI =
            List<Map<String, dynamic>>.from(
          updatedMessages,
        );

        messagesAfterAI.add(
          <String, dynamic>{
            'role': 'assistant',
            'content': aiMessage,
          },
        );

        // ------------------------------------------------------
        // SAVE AI RESPONSE IMMEDIATELY
        // ------------------------------------------------------

        await widget.onMessagesChanged(
          messagesAfterAI,
        );
      } else {
        final errorMessages =
            List<Map<String, dynamic>>.from(
          updatedMessages,
        );

        errorMessages.add(
          <String, dynamic>{
            'role': 'assistant',
            'content':
                '⚠️ The AI server returned an error.',
          },
        );

        await widget.onMessagesChanged(
          errorMessages,
        );
      }
    } catch (_) {
      final errorMessages =
          List<Map<String, dynamic>>.from(
        updatedMessages,
      );

      errorMessages.add(
        <String, dynamic>{
          'role': 'assistant',
          'content':
              '⚠️ I could not connect to the backend.\n\n'
              'Please make sure FastAPI is running on port 8000.',
        },
      );

      await widget.onMessagesChanged(
        errorMessages,
      );
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });

    _scrollToBottom();
  }

  // ==========================================================
  // SCROLL
  // ==========================================================

  void _scrollToBottom() {
    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        if (!scrollController
            .hasClients) {
          return;
        }

        scrollController.animateTo(
          scrollController
              .position
              .maxScrollExtent,
          duration:
              const Duration(
            milliseconds: 300,
          ),
          curve:
              Curves.easeOut,
        );
      },
    );
  }

  // ==========================================================
  // LINK
  // ==========================================================

  Future<void> _openLink(
    String text,
    String? href,
    String title,
  ) async {
    if (href == null) return;

    final uri =
        Uri.tryParse(href);

    if (uri == null) return;

    try {
      await launchUrl(
        uri,
        mode:
            LaunchMode.externalApplication,
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open this link.',
          ),
        ),
      );
    }
  }

  // ==========================================================
  // AI AVATAR
  // ==========================================================

  Widget _aiAvatar(
    double size,
  ) {
    return Container(
      width: size,
      height: size,
      decoration:
          const BoxDecoration(
        color: Color(0xFFE4E6FF),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          'N',
          style: TextStyle(
            color:
                const Color(
              0xFF5146B8,
            ),
            fontWeight:
                FontWeight.bold,
            fontSize:
                size * 0.45,
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // USER AVATAR
  // ==========================================================

  Widget _userAvatar() {
    if (widget.profileImage !=
        null) {
      return ClipOval(
        child: Image.memory(
          widget.profileImage!,
          width: 38,
          height: 38,
          fit: BoxFit.cover,
        ),
      );
    }

    return Container(
      width: 38,
      height: 38,
      decoration:
          const BoxDecoration(
        color: Color(0xFF5146B8),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          widget.avatar,
          style:
              const TextStyle(
            fontSize: 21,
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // WELCOME
  // ==========================================================

  Widget _welcome() {
    return Center(
      child:
          SingleChildScrollView(
        padding:
            const EdgeInsets.all(
          25,
        ),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 115,
              height: 115,
              decoration:
                  const BoxDecoration(
                gradient:
                    LinearGradient(
                  colors: [
                    Color(0xFF5146B8),
                    Color(0xFF7046C5),
                  ],
                ),
                shape:
                    BoxShape.circle,
              ),
              child:
                  const Center(
                child: Text(
                  'N',
                  style:
                      TextStyle(
                    color:
                        Colors.white,
                    fontSize: 62,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(
              height: 25,
            ),

            const Text(
              'Welcome to NEXA AI',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                fontSize: 31,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              'Your intelligent digital assistant',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                fontSize: 17,
                color: Theme.of(
                  context,
                )
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),

            const SizedBox(
              height: 28,
            ),

            Wrap(
              alignment:
                  WrapAlignment
                      .center,
              spacing: 10,
              runSpacing: 10,
              children: [
                _prompt(
                  '💡 Explain something',
                  'Explain something interesting to me.',
                ),
                _prompt(
                  '🐍 Help me with Python',
                  'Teach me Python programming.',
                ),
                _prompt(
                  '🌐 Search the web',
                  'What are the latest technology news today?',
                ),
                _prompt(
                  '🚀 Help with Flutter',
                  'Teach me Flutter development.',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _prompt(
    String label,
    String prompt,
  ) {
    return OutlinedButton(
      onPressed: () {
        messageController.text =
            prompt;

        sendMessage();
      },
      child: Text(label),
    );
  }

  // ==========================================================
  // MESSAGE
  // ==========================================================

  Widget _message(
    Map<String, dynamic>
        message,
  ) {
    final role =
        message['role']
                ?.toString() ??
            '';

    final content =
        message['content']
                ?.toString() ??
            '';

    final isUser =
        role == 'user';

    return Align(
      alignment: isUser
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints:
            const BoxConstraints(
          maxWidth: 780,
        ),
        margin:
            const EdgeInsets.only(
          bottom: 18,
        ),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment
                  .start,
          mainAxisAlignment:
              isUser
                  ? MainAxisAlignment
                      .end
                  : MainAxisAlignment
                      .start,
          children: [
            if (!isUser)
              Padding(
                padding:
                    const EdgeInsets
                        .only(
                  right: 10,
                ),
                child:
                    _aiAvatar(38),
              ),

            Flexible(
              child:
                  Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 17,
                  vertical: 13,
                ),
                decoration:
                    BoxDecoration(
                  color: isUser
                      ? const Color(
                          0xFF5146B8,
                        )
                      : Theme.of(
                          context,
                        )
                          .colorScheme
                          .surfaceContainerHighest,
                  borderRadius:
                      BorderRadius
                          .circular(
                    18,
                  ),
                ),
                child: isUser
                    ? Text(
                        content,
                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                          fontSize: 15,
                          height: 1.45,
                        ),
                      )
                    : MarkdownBody(
                        data:
                            content,
                        selectable:
                            true,
                        onTapLink:
                            _openLink,
                        styleSheet:
                            MarkdownStyleSheet(
                          p: TextStyle(
                            fontSize:
                                15,
                            height:
                                1.5,
                            color: Theme.of(
                              context,
                            )
                                .colorScheme
                                .onSurface,
                          ),
                          a:
                              const TextStyle(
                            color:
                                Color(
                              0xFF5146B8,
                            ),
                            decoration:
                                TextDecoration
                                    .underline,
                          ),
                        ),
                      ),
              ),
            ),

            if (isUser)
              Padding(
                padding:
                    const EdgeInsets
                        .only(
                  left: 10,
                ),
                child:
                    _userAvatar(),
              ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // BUILD CHAT
  // ==========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final messages =
        widget.messages;

    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? _welcome()
              : ListView.builder(
                  controller:
                      scrollController,
                  padding:
                      const EdgeInsets
                          .fromLTRB(
                    24,
                    24,
                    24,
                    120,
                  ),
                  itemCount:
                      messages.length,
                  itemBuilder:
                      (context, index) {
                    return _message(
                      messages[index],
                    );
                  },
                ),
        ),

        if (isLoading)
          Padding(
            padding:
                const EdgeInsets
                    .fromLTRB(
              25,
              0,
              25,
              8,
            ),
            child: Row(
              children: [
                _aiAvatar(35),
                const SizedBox(
                  width: 10,
                ),
                Text(
                  'NEXA is thinking...',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    )
                        .colorScheme
                        .onSurfaceVariant,
                    fontStyle:
                        FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

        // INPUT
        Padding(
          padding:
              const EdgeInsets
                  .fromLTRB(
            16,
            8,
            16,
            15,
          ),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment
                    .end,
            children: [
              Expanded(
                child:
                    TextField(
                  controller:
                      messageController,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction:
                      TextInputAction
                          .newline,
                  decoration:
                      InputDecoration(
                    hintText:
                        'Ask NEXA anything...',
                    filled: true,
                    fillColor:
                        Theme.of(
                      context,
                    )
                            .colorScheme
                            .surfaceContainerHighest,
                    prefixIcon:
                        const Icon(
                      Icons
                          .chat_outlined,
                    ),
                    border:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        28,
                      ),
                      borderSide:
                          BorderSide.none,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                width: 8,
              ),

              SizedBox(
                width: 50,
                height: 50,
                child:
                    FilledButton(
                  onPressed:
                      isLoading
                          ? null
                          : sendMessage,
                  style:
                      FilledButton
                          .styleFrom(
                    padding:
                        EdgeInsets.zero,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        17,
                      ),
                    ),
                  ),
                  child:
                      const Icon(
                    Icons
                        .arrow_upward,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }
}

// ============================================================
// HISTORY PAGE
// ============================================================

class HistoryPage
    extends StatelessWidget {
  final List<Map<String, dynamic>>
      conversations;

  final Future<void> Function(
    int index,
  ) onDelete;

  final void Function(
    Map<String, dynamic>,
  ) onOpen;

  const HistoryPage({
    super.key,
    required this.conversations,
    required this.onDelete,
    required this.onOpen,
  });

  // ==========================================================
  // DATE
  // ==========================================================

  String _formatDate(
    String value,
  ) {
    final date =
        DateTime.tryParse(value);

    if (date == null) {
      return '';
    }

    final day =
        date.day.toString()
            .padLeft(2, '0');

    final month =
        date.month.toString()
            .padLeft(2, '0');

    final hour =
        date.hour.toString()
            .padLeft(2, '0');

    final minute =
        date.minute.toString()
            .padLeft(2, '0');

    return '$day/$month/${date.year} '
        '$hour:$minute';
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    if (conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment
                  .center,
          children: [
            Icon(
              Icons.history,
              size: 80,
              color: Theme.of(
                context,
              )
                  .colorScheme
                  .outline,
            ),

            const SizedBox(
              height: 18,
            ),

            const Text(
              'No conversations yet',
              style:
                  TextStyle(
                fontSize: 21,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              'Your conversations will be saved automatically.',
              style: TextStyle(
                color: Theme.of(
                  context,
                )
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding:
          const EdgeInsets.all(
        25,
      ),
      itemCount:
          conversations.length,
      itemBuilder:
          (context, index) {
        final conversation =
            conversations[index];

        final title =
            conversation['title']
                    ?.toString() ??
                'Conversation';

        final date =
            conversation['date']
                    ?.toString() ??
                '';

        return Card(
          margin:
              const EdgeInsets.only(
            bottom: 12,
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets
                    .symmetric(
              horizontal: 18,
              vertical: 8,
            ),

            leading:
                const CircleAvatar(
              child: Icon(
                Icons.chat_outlined,
              ),
            ),

            title: Text(
              title,
              maxLines: 2,
              overflow:
                  TextOverflow
                      .ellipsis,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            subtitle:
                Text(
              _formatDate(date),
            ),

            trailing:
                IconButton(
              tooltip:
                  'Delete',
              icon:
                  const Icon(
                Icons
                    .delete_outline,
              ),
              onPressed: () {
                onDelete(index);
              },
            ),

            onTap: () {
              onOpen(
                conversation,
              );
            },
          ),
        );
      },
    );
  }
}

// ============================================================
// PROFILE PAGE
// ============================================================

class ProfilePage
    extends StatefulWidget {
  final String username;
  final String userStatus;
  final String avatar;
  final Uint8List? profileImage;

  final Future<void> Function(
    String name,
    String status,
    String avatar,
    Uint8List? image,
  ) onSave;

  const ProfilePage({
    super.key,
    required this.username,
    required this.userStatus,
    required this.avatar,
    required this.profileImage,
    required this.onSave,
  });

  @override
  State<ProfilePage> createState() =>
      _ProfilePageState();
}

class _ProfilePageState
    extends State<ProfilePage> {
  late TextEditingController
      nameController;

  late TextEditingController
      statusController;

  late String selectedAvatar;

  Uint8List? selectedImage;

  final ImagePicker
      imagePicker =
      ImagePicker();

  @override
  void initState() {
    super.initState();

    nameController =
        TextEditingController(
      text: widget.username,
    );

    statusController =
        TextEditingController(
      text: widget.userStatus,
    );

    selectedAvatar =
        widget.avatar;

    selectedImage =
        widget.profileImage;
  }

  // ==========================================================
  // PICK GALLERY PHOTO
  // ==========================================================

  Future<void> _pickGallery()
      async {
    try {
      final file =
          await imagePicker
              .pickImage(
        source:
            ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1000,
        maxHeight: 1000,
      );

      if (file == null) {
        return;
      }

      final bytes =
          await file.readAsBytes();

      if (!mounted) return;

      setState(() {
        selectedImage = bytes;
      });
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not select the photo.',
          ),
        ),
      );
    }
  }

  // ==========================================================
  // CHOOSE AVATAR
  // ==========================================================

  void _chooseAvatar() {
    final avatars = [
      '🧑🏻‍💻',
      '👨🏻‍💻',
      '👨🏼‍💻',
      '👨🏽‍💻',
      '👨🏾‍💻',
      '👨🏿‍💻',
      '🧑🏻‍🚀',
      '🧑🏻‍🎨',
      '🧑🏻‍🔬',
      '🧑🏻‍💼',
      '🧑🏻‍🏫',
      '🤖',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            constraints:
                BoxConstraints(
              maxHeight:
                  MediaQuery.of(
                        context,
                      ).size.height *
                      0.85,
            ),
            decoration:
                BoxDecoration(
              color: Theme.of(
                context,
              )
                  .colorScheme
                  .surface,
              borderRadius:
                  const BorderRadius
                      .only(
                topLeft:
                    Radius.circular(
                  28,
                ),
                topRight:
                    Radius.circular(
                  28,
                ),
              ),
            ),
            child:
                SingleChildScrollView(
              padding:
                  const EdgeInsets.all(
                20,
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    decoration:
                        BoxDecoration(
                      color: Theme.of(
                        context,
                      )
                          .colorScheme
                          .outline,
                      borderRadius:
                          BorderRadius
                              .circular(
                        10,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  const Text(
                    'Choose Profile Picture',
                    style:
                        TextStyle(
                      fontSize: 21,
                      fontWeight:
                          FontWeight
                              .bold,
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  Text(
                    'Use your photo or choose an avatar.',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      )
                          .colorScheme
                          .onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  // GALLERY
                  SizedBox(
                    width:
                        double.infinity,
                    height: 52,
                    child:
                        FilledButton.icon(
                      onPressed:
                          () async {
                        Navigator.pop(
                          context,
                        );

                        await _pickGallery();
                      },
                      icon:
                          const Icon(
                        Icons
                            .photo_library_outlined,
                      ),
                      label:
                          const Text(
                        'Choose from Gallery',
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  if (selectedImage !=
                      null)
                    SizedBox(
                      width:
                          double.infinity,
                      height: 48,
                      child:
                          OutlinedButton
                              .icon(
                        onPressed:
                            () {
                          setState(() {
                            selectedImage =
                                null;
                          });

                          Navigator.pop(
                            context,
                          );
                        },
                        icon:
                            const Icon(
                          Icons
                              .delete_outline,
                        ),
                        label:
                            const Text(
                          'Remove Current Photo',
                        ),
                      ),
                    ),

                  const SizedBox(
                    height: 22,
                  ),

                  const Align(
                    alignment:
                        Alignment.centerLeft,
                    child: Text(
                      'Choose an Avatar',
                      style:
                          TextStyle(
                        fontSize: 17,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  GridView.builder(
                    shrinkWrap:
                        true,
                    physics:
                        const NeverScrollableScrollPhysics(),
                    itemCount:
                        avatars.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount:
                          4,
                      crossAxisSpacing:
                          10,
                      mainAxisSpacing:
                          10,
                    ),
                    itemBuilder:
                        (context, index) {
                      final avatar =
                          avatars[index];

                      final selected =
                          selectedAvatar ==
                                  avatar &&
                              selectedImage ==
                                  null;

                      return InkWell(
                        borderRadius:
                            BorderRadius
                                .circular(
                          16,
                        ),
                        onTap: () {
                          setState(() {
                            selectedAvatar =
                                avatar;

                            selectedImage =
                                null;
                          });

                          Navigator.pop(
                            context,
                          );
                        },
                        child:
                            Container(
                          decoration:
                              BoxDecoration(
                            color: selected
                                ? const Color(
                                    0xFF5146B8,
                                  ).withAlpha(
                                    25,
                                  )
                                : Theme.of(
                                    context,
                                  )
                                      .colorScheme
                                      .surfaceContainerHighest,
                            borderRadius:
                                BorderRadius
                                    .circular(
                              16,
                            ),
                            border:
                                Border.all(
                              color: selected
                                  ? const Color(
                                      0xFF5146B8,
                                    )
                                  : Theme.of(
                                      context,
                                    )
                                        .colorScheme
                                        .outlineVariant,
                              width:
                                  selected
                                      ? 2
                                      : 1,
                            ),
                          ),
                          child:
                              Center(
                            child: Text(
                              avatar,
                              style:
                                  const TextStyle(
                                fontSize:
                                    36,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  SizedBox(
                    width:
                        double.infinity,
                    height: 48,
                    child:
                        OutlinedButton(
                      onPressed: () {
                        Navigator.pop(
                          context,
                        );
                      },
                      child:
                          const Text(
                        'Cancel',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ==========================================================
  // PREVIEW
  // ==========================================================

  Widget _preview() {
    if (selectedImage != null) {
      return ClipOval(
        child: Image.memory(
          selectedImage!,
          width: 140,
          height: 140,
          fit: BoxFit.cover,
        ),
      );
    }

    return Center(
      child: Text(
        selectedAvatar,
        style:
            const TextStyle(
          fontSize: 70,
        ),
      ),
    );
  }

  // ==========================================================
  // SAVE PROFILE
  // ==========================================================

  Future<void> _saveProfile()
      async {
    await widget.onSave(
      nameController.text,
      statusController.text,
      selectedAvatar,
      selectedImage,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      const SnackBar(
        content: Text(
          'Profile saved successfully!',
        ),
      ),
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return SingleChildScrollView(
      padding:
          const EdgeInsets.all(30),
      child: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(
            maxWidth: 700,
          ),
          child: Column(
            children: [
              const SizedBox(
                height: 10,
              ),

              GestureDetector(
                onTap:
                    _chooseAvatar,
                child: Stack(
                  children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration:
                          const BoxDecoration(
                        gradient:
                            LinearGradient(
                          colors: [
                            Color(
                              0xFF5146B8,
                            ),
                            Color(
                              0xFF7046C5,
                            ),
                          ],
                        ),
                        shape:
                            BoxShape
                                .circle,
                      ),
                      child:
                          _preview(),
                    ),

                    Positioned(
                      bottom: 2,
                      right: 2,
                      child:
                          Container(
                        width: 40,
                        height: 40,
                        decoration:
                            const BoxDecoration(
                          color:
                              Color(
                            0xFF5146B8,
                          ),
                          shape:
                              BoxShape
                                  .circle,
                        ),
                        child:
                            const Icon(
                          Icons.edit,
                          color:
                              Colors.white,
                          size: 19,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              Text(
                'Tap your picture to change it',
                style:
                    TextStyle(
                  color: Theme.of(
                    context,
                  )
                      .colorScheme
                      .onSurfaceVariant,
                ),
              ),

              const SizedBox(
                height: 35,
              ),

              const Align(
                alignment:
                    Alignment.centerLeft,
                child: Text(
                  'Profile Information',
                  style:
                      TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight
                            .bold,
                  ),
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              TextField(
                controller:
                    nameController,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Your Name',
                  prefixIcon:
                      Icon(
                    Icons
                        .person_outline,
                  ),
                  border:
                      OutlineInputBorder(),
                ),
              ),

              const SizedBox(
                height: 18,
              ),

              TextField(
                controller:
                    statusController,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Status / Profession',
                  prefixIcon:
                      Icon(
                    Icons
                        .badge_outlined,
                  ),
                  border:
                      OutlineInputBorder(),
                ),
              ),

              const SizedBox(
                height: 25,
              ),

              SizedBox(
                width:
                    double.infinity,
                height: 50,
                child:
                    FilledButton.icon(
                  onPressed:
                      _saveProfile,
                  icon:
                      const Icon(
                    Icons.save,
                  ),
                  label:
                      const Text(
                    'Save Profile',
                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight
                              .bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    statusController.dispose();
    super.dispose();
  }
}

// ============================================================
// SETTINGS PAGE
// ============================================================

class SettingsPage
    extends StatelessWidget {
  final bool darkMode;

  final Future<void> Function(
    bool,
  ) onDarkModeChanged;

  const SettingsPage({
    super.key,
    required this.darkMode,
    required this.onDarkModeChanged,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return ListView(
      padding:
          const EdgeInsets.all(30),
      children: [
        const Text(
          'Appearance',
          style:
              TextStyle(
            fontSize: 20,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 10,
        ),

        Card(
          child:
              SwitchListTile(
            value: darkMode,
            onChanged:
                onDarkModeChanged,
            secondary:
                Icon(
              darkMode
                  ? Icons.dark_mode
                  : Icons.light_mode,
            ),
            title:
                const Text(
              'Dark Mode',
              style:
                  TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),
            subtitle:
                const Text(
              'Change the appearance of NEXA AI.',
            ),
          ),
        ),

        const SizedBox(
          height: 25,
        ),

        const Text(
          'Application',
          style:
              TextStyle(
            fontSize: 20,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 10,
        ),

        Card(
          child:
              Column(
            children: [
              const ListTile(
                leading:
                    Icon(
                  Icons
                      .smart_toy_outlined,
                ),
                title:
                    Text(
                  'NEXA AI',
                ),
                subtitle:
                    Text(
                  'Your intelligent AI assistant',
                ),
              ),

              const Divider(
                height: 1,
              ),

              const ListTile(
                leading:
                    Icon(
                  Icons
                      .cloud_outlined,
                ),
                title:
                    Text(
                  'AI Backend',
                ),
                subtitle:
                    Text(
                  'FastAPI + OpenRouter',
                ),
              ),

              const Divider(
                height: 1,
              ),

              const ListTile(
                leading:
                    Icon(
                  Icons.public,
                ),
                title:
                    Text(
                  'Web Search',
                ),
                subtitle:
                    Text(
                  'Real-time web search enabled',
                ),
              ),
            ],
          ),
        ),

        const SizedBox(
          height: 25,
        ),

        const Text(
          'Privacy',
          style:
              TextStyle(
            fontSize: 20,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 10,
        ),

        const Card(
          child:
              ListTile(
            leading:
                Icon(
              Icons.lock_outline,
            ),
            title:
                Text(
              'Local Data Storage',
            ),
            subtitle:
                Text(
              'Profile and chat history are stored locally on this device.',
            ),
          ),
        ),

        const SizedBox(
          height: 30,
        ),

        Center(
          child:
              Text(
            'NEXA AI • Version 3.0',
            style:
                TextStyle(
              color: Theme.of(
                context,
              )
                  .colorScheme
                  .onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}