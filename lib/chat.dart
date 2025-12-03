import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;
import 'user_profile_service.dart';
import 'setting.dart';
import 'home.dart';
import 'main.dart';
import 'api_error_handler.dart';

class ChatPage extends StatefulWidget {
  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  int _lastId = 0;
  String _backgroundUrl = '';
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _fetchMessages();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animate = true}) {
    // With reverse: true, position 0 is the bottom (latest messages)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          if (animate) {
            _scrollController.animateTo(
              0, // With reverse: true, 0 is the bottom
              duration: Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          } else {
            _scrollController.jumpTo(0);
          }
        }
      });
    });
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await UserProfileService.getProfile();

      if (profile != null) {
        setState(() {
          _backgroundUrl = profile.chatBackground;
        });
      } else {
        Navigator.of(context)
            .pushReplacement(MaterialPageRoute(builder: (_) => LoginPage()));
      }
    } catch (e) {
      print('Error loading user profile: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
      // No need to scroll - reverse ListView starts at bottom automatically
    }
  }

  Future<void> _fetchMessages() async {
    final token = await UserProfileService.getAuthToken();
    final profile = await UserProfileService.getProfile();
    final userid = profile?.id;

    try {
      final response = await http.get(
        Uri.parse(
            "https://hope.layu.cc/hope/messages?chat_id=1:${userid}&user_id=${userid}&last_id=$_lastId"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${token}',
        },
      );

      // Use ApiErrorHandler to check for 401 and handle authentication errors
      if (!ApiErrorHandler.handleHttpResponse(response, context)) {
        return; // 401 handled, user redirected to login
      }

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        final bool hadMessages = _messages.isNotEmpty;
        setState(() {
          final newMessages = data
              .map((message) => {
                    "id": message["id"],
                    "sender_id": message["sender_id"],
                    "receiver_id": message["receiver_id"],
                    "content": message["content"],
                    "created_time": message["created_time"],
                  })
              .toList();
          _messages.addAll(newMessages);
          if (_messages.isNotEmpty) {
            _lastId = _messages.last["id"];
          }
        });

        // Only scroll when new messages added (not initial load - reverse handles that)
        if (hadMessages && data.isNotEmpty) {
          _scrollToBottom();
        }
      } else {
        // Handle other HTTP errors
        ApiErrorHandler.handleException(
            context, Exception('Failed to fetch messages'),
            customMessage: '获取消息失败 (${response.statusCode})');
      }
    } catch (e) {
      ApiErrorHandler.handleException(context, e, customMessage: '获取消息时发生网络错误');
    }
  }

  Future<void> _sendMessage() async {
    if (_controller.text.isEmpty) return;

    final profile = await UserProfileService.getProfile();
    final userid = profile?.id;
    final messageContent = _controller.text;

    // Step 1: Immediately show the message (optimistic UI)
    final tempMessage = {
      "sender_id": userid, // User's message, not AI (sender_id != 1)
      "receiver_id": 1,
      "content": messageContent,
      "created_time": DateTime.now().toIso8601String(),
    };

    setState(() {
      _messages.add(tempMessage);
    });
    _controller.clear();
    _scrollToBottom();

    // Step 2: Send to server
    try {
      final token = await UserProfileService.getAuthToken();
      final response = await http.post(
        Uri.parse('https://hope.layu.cc/hope/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${token}',
        },
        body: jsonEncode({
          "user_id": userid,
          "chat_id": "1:$userid",
          "content": messageContent
        }),
      );

      // Use ApiErrorHandler to check for 401 and handle authentication errors
      if (!ApiErrorHandler.handleHttpResponse(response, context)) {
        // Remove temp message on auth error
        setState(() {
          _messages.remove(tempMessage);
        });
        return;
      }

      if (response.statusCode == 200) {
        // Step 3: Wait 10 seconds for AI to reply
        await Future.delayed(Duration(seconds: 10));

        // Step 4: Fetch new messages - only get AI reply (skip user message we already show)
        final fetchResponse = await http.get(
          Uri.parse(
              "https://hope.layu.cc/hope/messages?chat_id=1:${userid}&user_id=${userid}&last_id=$_lastId"),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${token}',
          },
        );

        if (fetchResponse.statusCode == 200) {
          List<dynamic> data = jsonDecode(fetchResponse.body);

          setState(() {
            for (var message in data) {
              // Only add AI replies (sender_id == 1), skip user's own message
              // because we already show it as temp message
              if (message["sender_id"] == 1) {
                final newMessage = {
                  "id": message["id"],
                  "sender_id": message["sender_id"],
                  "receiver_id": message["receiver_id"],
                  "content": message["content"],
                  "created_time": message["created_time"],
                };
                _messages.add(newMessage);
              }
            }

            // Update lastId to the latest message from server
            if (data.isNotEmpty) {
              _lastId = data
                  .map((m) => m["id"] as int)
                  .reduce((a, b) => a > b ? a : b);
            }
          });
          _scrollToBottom();
        }
      } else {
        // Remove temp message on error
        setState(() {
          _messages.remove(tempMessage);
        });
        ApiErrorHandler.handleException(
            context, Exception('Failed to send message'),
            customMessage: '发送消息失败 (${response.statusCode})');
      }
    } catch (e) {
      // Remove temp message on error
      setState(() {
        _messages.remove(tempMessage);
      });
      ApiErrorHandler.handleException(context, e, customMessage: '发送消息时发生网络错误');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '心理咨询',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.more_horiz, color: AppColors.textSecondary),
            onPressed: () {},
          ),
        ],
      ),
      body: Container(
        decoration: _backgroundUrl.isNotEmpty
            ? BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(_backgroundUrl),
                  fit: BoxFit.cover,
                ),
              )
            : BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primaryLight.withOpacity(0.3),
                    AppColors.background,
                  ],
                ),
              ),
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.success),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      reverse:
                          true, // Start from bottom - standard chat pattern
                      padding: EdgeInsets.all(AppDimens.paddingMedium),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        // Since list is reversed, we need to reverse the index
                        final reversedIndex = _messages.length - 1 - index;
                        final message = _messages[reversedIndex];
                        final bool isUserMessage = message["sender_id"] != 1;

                        return Padding(
                          padding:
                              EdgeInsets.only(bottom: AppDimens.paddingMedium),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: isUserMessage
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                            children: [
                              if (!isUserMessage) ...[
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.accent,
                                        AppColors.success
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            AppColors.success.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.psychology,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                SizedBox(width: 12),
                              ],
                              Flexible(
                                child: Container(
                                  padding:
                                      EdgeInsets.all(AppDimens.paddingMedium),
                                  decoration: BoxDecoration(
                                    color: isUserMessage
                                        ? AppColors.primary
                                        : Colors.white,
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(
                                          AppDimens.radiusMedium),
                                      topRight: Radius.circular(
                                          AppDimens.radiusMedium),
                                      bottomLeft: Radius.circular(
                                        isUserMessage
                                            ? AppDimens.radiusMedium
                                            : 4,
                                      ),
                                      bottomRight: Radius.circular(
                                        isUserMessage
                                            ? 4
                                            : AppDimens.radiusMedium,
                                      ),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    message["content"] ?? '',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: AppColors.textPrimary,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ),
                              if (isUserMessage) ...[
                                SizedBox(width: 12),
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            AppColors.primary.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.person,
                                    color: AppColors.textSecondary,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
            Container(
              padding: EdgeInsets.all(AppDimens.paddingMedium),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppDimens.radiusLarge),
                  topRight: Radius.circular(AppDimens.radiusLarge),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius:
                              BorderRadius.circular(AppDimens.radiusLarge),
                          border: Border.all(
                            color: AppColors.textLight.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          controller: _controller,
                          decoration: InputDecoration(
                            hintText: '分享你的感受...',
                            hintStyle: TextStyle(
                              color: AppColors.textLight,
                              fontSize: 16,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: AppDimens.paddingMedium,
                              vertical: 12,
                            ),
                          ),
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 3,
                          minLines: 1,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.success, AppColors.accent],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.success.withOpacity(0.3),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(Icons.send, color: Colors.white, size: 20),
                        onPressed: () {
                          if (_controller.text.trim().isNotEmpty) {
                            _sendMessage();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
