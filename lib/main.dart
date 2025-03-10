import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'note.dart';
import 'chat.dart';
import 'setting.dart';
import 'post.dart';
import 'user_profile_service.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // title: 'Flutter App',
      // home: MyHomePage(),
      title: 'Hope App',
      home: AuthWrapper(),

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
        selectedItemColor: Colors.blue, // Set selected icon color
        unselectedItemColor: Colors.grey, // Set unselected icon color
        showUnselectedLabels: true, // Ensure unselected labels are visible
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.photo), label: 'Post'),
          BottomNavigationBarItem(icon: Icon(Icons.note), label: 'Notes'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}


// class PostSquarePage extends StatefulWidget {
//   @override
//   _PostSquarePageState createState() => _PostSquarePageState();
// }

// class _PostSquarePageState extends State<PostSquarePage> {
//   List<Map<String, String>> _posts = [];
//   TextEditingController _postController = TextEditingController();

//   Future<void> _pickImage(String type) async {
//     final ImagePicker _picker = ImagePicker();
//     final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

//     if (image != null) {
//       setState(() {
//         _posts.insert(0, {"image": image.path, "text": _postController.text});
//         _postController.clear();
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.all(8.0),
//       child: Column(
//         children: [
//           Expanded(
//             child: ListView.builder(
//               itemCount: _posts.length,
//               itemBuilder: (context, index) {
//                 return Card(
//                   margin: EdgeInsets.symmetric(vertical: 8.0),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       if (_posts[index]["image"] != null)
//                         Image.file(File(_posts[index]["image"]!),
//                             fit: BoxFit.cover),
//                       Padding(
//                         padding: const EdgeInsets.all(8.0),
//                         child: Text(_posts[index]["text"] ?? ''),
//                       ),
//                     ],
//                   ),
//                 );
//               },
//             ),
//           ),
//           TextField(
//             controller: _postController,
//             decoration: InputDecoration(hintText: 'Write a post'),
//           ),
//           IconButton(
//             icon: Icon(Icons.photo),
//             onPressed: () => _pickImage('image'),
//           ),
//         ],
//       ),
//     );
//   }
// }

class AuthWrapper extends StatefulWidget {
  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    // final profile = await UserProfileService.getProfile();
    final String? token = await UserProfileService.getAuthToken();
    setState(() {
      print("setStateBefore");
      // print("$profile");
      print("setStateAfter");
      // _isAuthenticated = profile != null;
      _isAuthenticated = token !=null && token.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    print("hello");
    print(_isAuthenticated);
    print("hello2");
    return _isAuthenticated ? MyHomePage() : LoginPage();
  }
}




class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<void> _login() async {
    final profile = await UserProfileService.login(
      _mobileController.text, 
      _passwordController.text
    );

    if (profile != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => MyHomePage())
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login failed'),
          backgroundColor: Colors.red,
        )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _mobileController,
              decoration: InputDecoration(labelText: 'Mobile Number'),
              keyboardType: TextInputType.phone,
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _login,
              child: Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}

