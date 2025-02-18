import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter App',
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    ChatPage(),
    PostSquarePage(),
    NotePage(),
    SettingsPage()
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('抑郁伴侣')),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blue,  // Set selected icon color
        unselectedItemColor: Colors.grey, // Set unselected icon color
        showUnselectedLabels: true,  // Ensure unselected labels are visible
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.photo), label: 'Post'),
          BottomNavigationBarItem(icon: Icon(Icons.note), label: 'Notes'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class ChatPage extends StatefulWidget {
  @override
  _ChatPageState createState() => _ChatPageState();
}

// class _ChatPageState extends State<ChatPage> {
//   TextEditingController _controller = TextEditingController();
//   List<String> _messages = [];
//
//   void _sendMessage() {
//     if (_controller.text.isNotEmpty) {
//       setState(() {
//         _messages.add(_controller.text);
//         _controller.clear();
//       });
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.all(8.0),
//       child: Column(
//         children: [
//           Expanded(
//             child: ListView.builder(
//               itemCount: _messages.length,
//               itemBuilder: (context, index) {
//                 return ListTile(title: Text(_messages[index]));
//               },
//             ),
//           ),
//           TextField(
//             controller: _controller,
//             decoration: InputDecoration(hintText: 'Enter message'),
//           ),
//           IconButton(
//             icon: Icon(Icons.send),
//             onPressed: _sendMessage,
//           ),
//         ],
//       ),
//     );
//   }
// }

class _ChatPageState extends State<ChatPage> {
  TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  int _lastId = 0;  // Track the last message ID for pagination

  // Fetch messages from the API
  Future<void> _fetchMessages() async {
    const String url = "http://192.168.3.11:8080/messages";
    final response = await http.get(
      Uri.parse("$url?chat_id=1:2&user_id=2&last_id=$_lastId"),
    );

    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      setState(() {
        // Add fetched messages to the list
        _messages = data.map((message) => {
          "id": message["id"],
          "sender_id": message["sender_id"],
          "receiver_id": message["receiver_id"],
          "content": message["content"],
          "created_time": message["created_time"],
        }).toList();
        if (_messages.isNotEmpty) {
          _lastId = _messages.last["id"];
        }
      });
    } else {
      throw Exception('Failed to load messages');
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchMessages();  // Load messages when the page is first loaded
  }

  void _sendMessage() {
    if (_controller.text.isNotEmpty) {
      setState(() {
        _messages.add({
          "id": _lastId + 1,
          "sender_id": 2,
          "receiver_id": 1,
          "content": _controller.text,
          "created_time": DateTime.now().millisecondsSinceEpoch,
        });
        _lastId++;
        _controller.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_messages[index]["content"] ?? ''),
                );
              },
            ),
          ),
          TextField(
            controller: _controller,
            decoration: InputDecoration(hintText: 'Enter message'),
          ),
          IconButton(
            icon: Icon(Icons.send),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}

class PostSquarePage extends StatefulWidget {
  @override
  _PostSquarePageState createState() => _PostSquarePageState();
}

class _PostSquarePageState extends State<PostSquarePage> {
  List<Map<String, String>> _posts = [];
  TextEditingController _postController = TextEditingController();

  Future<void> _pickImage(String type) async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _posts.insert(0, {"image": image.path, "text": _postController.text});
        _postController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _posts.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_posts[index]["image"] != null)
                        Image.file(File(_posts[index]["image"]!), fit: BoxFit.cover),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(_posts[index]["text"] ?? ''),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          TextField(
            controller: _postController,
            decoration: InputDecoration(hintText: 'Write a post'),
          ),
          IconButton(
            icon: Icon(Icons.photo),
            onPressed: () => _pickImage('image'),
          ),
        ],
      ),
    );
  }
}

class NotePage extends StatefulWidget {
  @override
  _NotePageState createState() => _NotePageState();
}

class _NotePageState extends State<NotePage> {
  List<Map<String, String>> _notes = [];
  TextEditingController _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  void _saveNote() {
    if (_noteController.text.isNotEmpty) {
      setState(() {
        _notes.insert(0, {
          "date": _selectedDate.toLocal().toString().split(' ')[0],
          "note": _noteController.text,
        });
        _notes.sort((a, b) {
          return DateTime.parse(b["date"]!).compareTo(DateTime.parse(a["date"]!));
        });
        _noteController.clear();
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate)
      setState(() {
        _selectedDate = picked;
      });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _notes.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_notes[index]["note"] ?? ''),
                  subtitle: Text(_notes[index]["date"] ?? ''),
                );
              },
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.calendar_today),
                onPressed: _selectDate,
              ),
              Text("${_selectedDate.toLocal()}".split(' ')[0]),
            ],
          ),
          TextField(
            controller: _noteController,
            decoration: InputDecoration(hintText: 'Write your note'),
          ),
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _saveNote,
          ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  TextEditingController _nicknameController = TextEditingController();
  TextEditingController _descriptionController = TextEditingController();
  String _avatarPath = '';
  String _backgroundPath = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _nicknameController.text = prefs.getString('nickname') ?? '';
      _descriptionController.text = prefs.getString('description') ?? '';
      _avatarPath = prefs.getString('avatarPath') ?? '';
      _backgroundPath = prefs.getString('backgroundPath') ?? '';
    });
  }

  _saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('nickname', _nicknameController.text);
    prefs.setString('description', _descriptionController.text);
    prefs.setString('avatarPath', _avatarPath);
    prefs.setString('backgroundPath', _backgroundPath);
  }

  Future<void> _pickImage(String type) async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        if (type == 'avatar') {
          _avatarPath = image.path;
        } else {
          _backgroundPath = image.path;
        }
      });
      _saveSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Avatar'),
          GestureDetector(
            onTap: () => _pickImage('avatar'),
            child: _avatarPath.isNotEmpty
                ? Image.file(File(_avatarPath), width: 100, height: 100)
                : Container(color: Colors.grey, width: 100, height: 100),
          ),
          SizedBox(height: 16),
          Text('Nickname'),
          TextField(
            controller: _nicknameController,
            decoration: InputDecoration(hintText: 'Enter nickname'),
          ),
          SizedBox(height: 16),
          Text('Description'),
          TextField(
            controller: _descriptionController,
            decoration: InputDecoration(hintText: 'Enter description'),
            maxLines: 3,
          ),
          SizedBox(height: 16),
          Text('Background Picture'),
          GestureDetector(
            onTap: () => _pickImage('background'),
            child: _backgroundPath.isNotEmpty
                ? Image.file(File(_backgroundPath), width: double.infinity, height: 200, fit: BoxFit.cover)
                : Container(color: Colors.grey, width: double.infinity, height: 200),
          ),
          SizedBox(height: 32),
          ElevatedButton(
            onPressed: _saveSettings,
            child: Text('Save Settings'),
          ),
        ],
      ),
    );
  }
}
