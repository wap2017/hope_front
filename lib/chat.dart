import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;
import 'user_profile_service.dart';
import 'setting.dart';

// 这个StatefulWidget好像看上去还挺常用的
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
  // Add ScrollController for auto-scrolling
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _fetchMessages();
  }

  @override
  void dispose() {
    // Dispose the scroll controller when not needed
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  // Method to scroll to bottom of chat
  void _scrollToBottom() {
    // Add a small delay to ensure the list is updated before scrolling
    Future.delayed(Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _loadUserProfile() async {
    try {
      // First try to get from local storage
      final profile = await UserProfileService.getProfile();

      if (profile != null) {
        setState(() {
          _backgroundUrl = profile.chatBackground;
        });
      } else {
        // 跳到登录页
        Navigator.of(context)
            .pushReplacement(MaterialPageRoute(builder: (_) => LoginPage()));
      }
    } catch (e) {
      print('Error loading user profile: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchMessages() async {
    final token = await UserProfileService.getAuthToken();
    final profile = await UserProfileService.getProfile();
    final userid = profile?.id;

    try {
      final response = await http.get(
        Uri.parse(
            "http://hope.ioaths.com/hope/messages?chat_id=1:${userid}&user_id=${userid}&last_id=$_lastId"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${token}',
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
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

        // Scroll to bottom after messages are loaded
        if (!_isLoading) {
          _scrollToBottom();
        }
      }
    } catch (e) {
      print('Error fetching messages: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_controller.text.isEmpty) return;

    final profile = await UserProfileService.getProfile();
    final userid = profile?.id;
    final message = {
      "user_id": userid,
      "chat_id": "1:$userid",
      "content": _controller.text
    };

    try {
      final token = await UserProfileService.getAuthToken();
      final response = await http.post(
        Uri.parse('http://hope.ioaths.com/hope/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${token}',
        },
        body: jsonEncode(message),
      );

      if (response.statusCode == 200) {
        // Clear the input field
        _controller.clear();
        // Fetch updated messages
        await _fetchMessages();
        // Scroll to bottom after sending message
        _scrollToBottom();
      } else {
        print('Failed to send message: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // Apply background from profile
      decoration: BoxDecoration(
        image: _backgroundUrl.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(_backgroundUrl),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller:
                          _scrollController, // Assign the ScrollController
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final bool isUserMessage = message["sender_id"] == 2;

                        return Align(
                          alignment: isUserMessage
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: EdgeInsets.symmetric(
                              vertical: 4.0,
                              horizontal: 8.0,
                            ),
                            padding: EdgeInsets.all(12.0),
                            decoration: BoxDecoration(
                              color: isUserMessage
                                  ? Colors.blue[100]
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12.0),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  offset: Offset(0, 1),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.7,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message["content"] ?? '',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 4),
                                // Text(
                                //   'ID: ${message["id"]}',
                                //   style: TextStyle(
                                //     fontSize: 12,
                                //     color: Colors.black54,
                                //   ),
                                // ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    offset: Offset(0, -1),
                    blurRadius: 3,
                  ),
                ],
              ),
              margin: EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Enter message',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
