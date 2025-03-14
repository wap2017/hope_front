import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'user_profile_service.dart';
import 'home.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  TextEditingController _nicknameController = TextEditingController();
  TextEditingController _patientNameController = TextEditingController();
  TextEditingController _relationshipController = TextEditingController();
  TextEditingController _illnessCauseController = TextEditingController();
  TextEditingController _mobileNumberController = TextEditingController();
  String _avatarUrl = '';
  String _backgroundUrl = '';
  bool _isLoading = true;
  // int _userId = 2; // Default user ID, consider making this dynamic

  @override
  void initState() {
    super.initState();
    _fetchUserSettings();
  }

  Future<void> _fetchUserSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // First try to get from local storage
      UserProfile? profile = await UserProfileService.getProfile();

      // If not available locally, fetch from API
      if (profile == null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => LoginPage()),
        );
      }

      if (profile != null) {
        setState(() {
          _nicknameController.text = profile?.userNickname ?? '';
          _patientNameController.text = profile?.patientName ?? '';
          _relationshipController.text = profile?.relationshipToPatient ?? '';
          _illnessCauseController.text = profile?.illnessCause ?? '';
          _mobileNumberController.text = profile?.mobileNumber ?? '';
          _avatarUrl = profile?.userAvatar ?? '';
          _backgroundUrl = profile?.chatBackground ?? '';
        });
      } else {
        _showErrorMessage('Failed to load user settings');
      }
    } catch (e) {
      _showErrorMessage('Error fetching settings: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateUserSettings() async {
    setState(() {
      _isLoading = true;
    });

    final profile = await UserProfileService.getProfile();
    final userid = profile?.id ?? 0;

    try {
      final updatedProfile = UserProfile(
        id: userid,
        userNickname: _nicknameController.text,
        patientName: _patientNameController.text,
        relationshipToPatient: _relationshipController.text,
        illnessCause: _illnessCauseController.text,
        mobileNumber: _mobileNumberController.text,
        userAvatar: _avatarUrl,
        chatBackground: _backgroundUrl,
      );

      final success = await UserProfileService.updateProfile(updatedProfile);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Settings updated successfully')),
        );
      } else {
        _showErrorMessage('Failed to update settings');
      }
    } catch (e) {
      _showErrorMessage('Error updating settings: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
    print(message);
  }

  // Method to handle avatar image selection and upload
  Future<void> _changeAvatar() async {
    final ImagePicker picker = ImagePicker();

    // Display option dialog for camera or gallery
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Change Avatar'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                GestureDetector(
                  child: Text('Take a picture'),
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    _getAvatarImage(ImageSource.camera);
                  },
                ),
                Padding(padding: EdgeInsets.all(8.0)),
                GestureDetector(
                  child: Text('Select from gallery'),
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    _getAvatarImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Method to pick and upload avatar image
  Future<void> _getAvatarImage(ImageSource source) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        // Upload the image to server
        final String? newAvatarUrl =
            await _uploadFile(File(pickedFile.path), 'avatar');

        if (newAvatarUrl != null) {
          setState(() {
            _avatarUrl = newAvatarUrl;
          });

          // Save the updated avatar URL through UserProfileService
          final profile = await UserProfileService.getProfile();
          if (profile != null) {
            final updatedProfile = UserProfile(
              id: profile.id,
              patientName: profile.patientName ?? '',
              relationshipToPatient: profile.relationshipToPatient ?? '',
              illnessCause: profile.illnessCause ?? '',
              chatBackground: profile.chatBackground ?? '',
              userAvatar: newAvatarUrl,
              userNickname: profile.userNickname ?? '',
              mobileNumber: profile.mobileNumber ?? '',
            );

            await UserProfileService.updateProfile(updatedProfile);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Avatar updated successfully')),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Failed to upload avatar image'),
                backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error selecting image: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Method to handle background image selection and upload
  Future<void> _changeBackground() async {
    final ImagePicker picker = ImagePicker();

    // Display option dialog for camera or gallery
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Change Background'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                GestureDetector(
                  child: Text('Take a picture'),
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    _getBackgroundImage(ImageSource.camera);
                  },
                ),
                Padding(padding: EdgeInsets.all(8.0)),
                GestureDetector(
                  child: Text('Select from gallery'),
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    _getBackgroundImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Method to pick and upload background image
  Future<void> _getBackgroundImage(ImageSource source) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        // Upload the image to server
        final String? newBackgroundUrl =
            await _uploadFile(File(pickedFile.path), 'background');

        if (newBackgroundUrl != null) {
          setState(() {
            _backgroundUrl = newBackgroundUrl;
          });

          // Save the updated background URL through UserProfileService
          final profile = await UserProfileService.getProfile();
          if (profile != null) {
            final updatedProfile = UserProfile(
              id: profile.id,
              patientName: profile.patientName ?? '',
              relationshipToPatient: profile.relationshipToPatient ?? '',
              illnessCause: profile.illnessCause ?? '',
              chatBackground: newBackgroundUrl,
              userAvatar: profile.userAvatar ?? '',
              userNickname: profile.userNickname ?? '',
              mobileNumber: profile.mobileNumber ?? '',
            );

            await UserProfileService.updateProfile(updatedProfile);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Background updated successfully')),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Failed to upload background image'),
                backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error selecting image: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Method to upload a file to the server
  Future<String?> _uploadFile(File file, String type) async {
    try {
      // Get the token for authorization
      final prefs = await SharedPreferences.getInstance();
      final token = await UserProfileService.getAuthToken();
      print("----");
      print(token);
      print(type);
      print("----");

      // Create multipart request
      final url =
          Uri.parse('http://hope.ioaths.com/hope/user/upload?type=$type');
      var request = http.MultipartRequest('POST', url);

      // Add authorization header
      request.headers.addAll({
        'Authorization': 'Bearer $token',
      });

      // Get file extension
      final fileExtension = path.extension(file.path).replaceAll('.', '');

      // Add file to request
      final multipartFile = await http.MultipartFile.fromPath(
        'file', // field name that the server expects
        file.path,
        contentType: MediaType('image', fileExtension),
      );
      request.files.add(multipartFile);

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          // Return the URL of the uploaded file
          return responseData['data']['file_url'];
        }
      }

      print(
          'Upload failed with status: ${response.statusCode}, response: ${response.body}');
      return null;
    } catch (e) {
      print('Error uploading file: $e');
      return null;
    }
  }

  Future<void> _login() async {
    // Implement login dialog or screen
    final mobileNumber = _mobileNumberController.text;
    final password = ''; // You'll want a password field

    final profile = await UserProfileService.login(mobileNumber, password);

    if (profile != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login successful')),
      );
      _fetchUserSettings();
      //TODO 这里是不是要存到shared_preferences
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Inside the _SettingsPageState class
  Future<void> _logout() async {
    // Clear the stored profile and token
    UserProfileService.clearCache();
    // Navigate to the login page and remove all previous routes
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LoginPage()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('用户信息',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),

          Row(
            children: [
              Column(
                children: [
                  Text('头像'),
                  SizedBox(height: 8),
                  GestureDetector(
                    onTap: _changeAvatar,
                    child: _avatarUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(50),
                            child: Image.network(
                              _avatarUrl,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                width: 100,
                                height: 100,
                                color: Colors.grey,
                                child: Icon(Icons.error),
                              ),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(50),
                            ),
                            width: 100,
                            height: 100,
                            child: Icon(Icons.person, size: 50),
                          ),
                  ),
                ],
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('昵称'),
                    TextField(
                      controller: _nicknameController,
                      decoration: InputDecoration(
                        hintText: 'Enter nickname',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    SizedBox(height: 12),
                    Text('联系方式'),
                    TextField(
                      controller: _mobileNumberController,
                      decoration: InputDecoration(
                        hintText: 'Enter mobile number',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 24),
          Text('患者信息',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),

          Text('患者昵称'),
          TextField(
            controller: _patientNameController,
            decoration: InputDecoration(
              hintText: 'Enter patient name',
              border: OutlineInputBorder(),
            ),
          ),

          SizedBox(height: 16),
          Text('与患者关系'),
          TextField(
            controller: _relationshipController,
            decoration: InputDecoration(
              hintText: 'Enter relationship',
              border: OutlineInputBorder(),
            ),
          ),

          SizedBox(height: 16),
          Text('患病主要诱因'),
          TextField(
            controller: _illnessCauseController,
            decoration: InputDecoration(
              hintText: 'Enter illness information',
              border: OutlineInputBorder(),
            ),
          ),

          SizedBox(height: 24),
          Text('聊天背景图片',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),

          GestureDetector(
            onTap: _changeBackground,
            child: _backgroundUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _backgroundUrl,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: double.infinity,
                        height: 200,
                        color: Colors.grey,
                        child: Icon(Icons.error),
                      ),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    width: double.infinity,
                    height: 200,
                    child: Icon(Icons.image, size: 50),
                  ),
          ),

          SizedBox(height: 32),
          Center(
            child: ElevatedButton(
              onPressed: _updateUserSettings,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: Text('保存设置'),
            ),
          ),

          // In the build method, add this near the bottom of the Column children
          Center(
            child: ElevatedButton(
              onPressed: _logout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, // Optional: make it stand out
              ),
              child: Text('登出'),
            ),
          ),
        ],
      ),
    );
  }
}

// class LoginPage extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     // Implement your login page here
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Login'),
//       ),
//       body: Center(
//         child: Text('Login Page'),
//       ),
//     );
//   }
// }
