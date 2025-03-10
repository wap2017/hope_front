import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'user_profile_service.dart';
import 'main.dart';


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
  int _userId = 2; // Default user ID, consider making this dynamic

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
        profile = await UserProfileService.fetchAndSaveProfile(_userId);
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

    try {
      final updatedProfile = UserProfile(
        id: _userId,
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

  Future<void> _changeAvatar() async {
    // This would typically upload the image to your server
    // For now, we'll just demonstrate with URL changing
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Avatar'),
        content: TextField(
          decoration: InputDecoration(hintText: 'Enter new avatar URL'),
          onChanged: (value) => _avatarUrl = value,
          controller: TextEditingController(text: _avatarUrl),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {});
              Navigator.pop(context);
            },
            child: Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _changeBackground() async {
    // This would typically upload the image to your server
    // For now, we'll just demonstrate with URL changing
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Background'),
        content: TextField(
          decoration: InputDecoration(hintText: 'Enter new background URL'),
          onChanged: (value) => _backgroundUrl = value,
          controller: TextEditingController(text: _backgroundUrl),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {});
              Navigator.pop(context);
            },
            child: Text('Update'),
          ),
        ],
      ),
    );
  }
  
  // Original image picking method kept for reference
  // Can be modified to upload images to server
  Future<void> _pickImage(String type) async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      // Here you would upload the image to your server and get back a URL
      // For now we'll just pretend we got a URL back
      setState(() {
        if (type == 'avatar') {
          _avatarUrl = 'https://example.com/uploaded/avatar.jpg';
        } else {
          _backgroundUrl = 'https://example.com/uploaded/background.jpg';
        }
      });
    }
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
          Text('Profile Information', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          
          Row(
            children: [
              Column(
                children: [
                  Text('Avatar'),
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
                    Text('Nickname'),
                    TextField(
                      controller: _nicknameController,
                      decoration: InputDecoration(
                        hintText: 'Enter nickname',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    SizedBox(height: 12),
                    Text('Mobile Number'),
                    TextField(
                      controller: _mobileNumberController,
                      decoration: InputDecoration(
                        hintText: 'Enter mobile number',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 24),
          Text('Patient Information', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          
          Text('Patient Name'),
          TextField(
            controller: _patientNameController,
            decoration: InputDecoration(
              hintText: 'Enter patient name',
              border: OutlineInputBorder(),
            ),
          ),
          
          SizedBox(height: 16),
          Text('Relationship to Patient'),
          TextField(
            controller: _relationshipController,
            decoration: InputDecoration(
              hintText: 'Enter relationship',
              border: OutlineInputBorder(),
            ),
          ),
          
          SizedBox(height: 16),
          Text('Illness Cause/Type'),
          TextField(
            controller: _illnessCauseController,
            decoration: InputDecoration(
              hintText: 'Enter illness information',
              border: OutlineInputBorder(),
            ),
          ),
          
          SizedBox(height: 24),
          Text('Chat Background', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                      errorBuilder: (context, error, stackTrace) => 
                        Container(
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
              child: Text('Save Settings'),
            ),
          ),

		 // In the build method, add this near the bottom of the Column children
		Center(
		  child: ElevatedButton(
			onPressed: _logout,
			style: ElevatedButton.styleFrom(
			  backgroundColor: Colors.red, // Optional: make it stand out
			),
			child: Text('Logout'),
		  ),
		),
        ],
      ),
    );
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
			MaterialPageRoute(builder: (_) => LoginPage()),
			(route) => false
		  );
		}

}


