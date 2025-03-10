import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;
import 'user_profile_service.dart';


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

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _fetchMessages();
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
        // If not in local storage, fetch from API (assuming user ID 2)
        final fetchedProfile = await UserProfileService.fetchAndSaveProfile(2);
        if (fetchedProfile != null) {
          setState(() {
            _backgroundUrl = fetchedProfile.chatBackground;
          });
        }
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
    try {
      final response = await http.get(
        Uri.parse(
            "http://hope.ioaths.com/hope/messages?chat_id=1:2&user_id=2&last_id=$_lastId"),
			headers: {
				  'Content-Type': 'application/json',
				  'Authorization': 'Bearer ${UserProfileService.getAuthToken()}',
		   },
      );

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _messages = data
              .map((message) => {
                    "id": message["id"],
                    "sender_id": message["sender_id"],
                    "receiver_id": message["receiver_id"],
                    "content": message["content"],
                    "created_time": message["created_time"],
                  })
              .toList();
          if (_messages.isNotEmpty) {
            _lastId = _messages.last["id"];
          }
        });
      }
    } catch (e) {
      print('Error fetching messages: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_controller.text.isEmpty) return;

    final message = {
      "user_id": 2,
      "chat_id": "1:2",
      "content": _controller.text
    };

    try {
      final response = await http.post(
        Uri.parse('http://hope.ioaths.com/hope/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${UserProfileService.getAuthToken()}',
        },
        body: jsonEncode(message),
      );

      if (response.statusCode == 200) {
        // Clear the input field
        _controller.clear();
        // Fetch updated messages
        await _fetchMessages();
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
                                Text(
                                  'ID: ${message["id"]}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
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
