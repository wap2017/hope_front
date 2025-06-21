import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'user_profile_service.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import 'home.dart';

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _verificationCodeController = TextEditingController();
  final _patientNameController = TextEditingController();
  final _relationshipController = TextEditingController();
  final _nicknameController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _verificationCodeController.dispose();
    _patientNameController.dispose();
    _relationshipController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _requestVerificationCode() async {
    if (_mobileController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your mobile number';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('https://hope.layu.cc/hope/auth/verification-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'mobile_number': _mobileController.text}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Verification code sent successfully')),
          );
        } else {
          setState(() {
            _errorMessage =
                data['message'] ?? 'Failed to send verification code';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Server error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _register() async {
    // Basic validation
    print("-------");
    print("do _register");
    print("-------");
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Passwords do not match';
      });
      return;
    }

    if (_mobileController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _verificationCodeController.text.isEmpty ||
        _patientNameController.text.isEmpty ||
        _relationshipController.text.isEmpty ||
        _nicknameController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please fill in all required fields';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('https://hope.layu.cc/hope/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'mobile_number': _mobileController.text,
          'password': _passwordController.text,
          'verification_code': _verificationCodeController.text,
          'patient_name': _patientNameController.text,
          'relationship_to_patient': _relationshipController.text,
          'user_nickname': _nicknameController.text,
          'illness_cause': '', // Optional field
        }),
      );

      print("---response-----");
      print("${response.statusCode}");
      print("${response.body}");
      print("---response-----");

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          // Save auth token
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', data['data']['token']);

          // Navigate to home page
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => MyHomePage()),
          );
        } else {
          setState(() {
            _errorMessage = data['message'] ?? 'Registration failed';
          });
        }
      } else {
        print("non 201");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${response.body}"),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
        setState(() {
          _errorMessage = 'Server error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Register')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage != null)
              Padding(
                padding: EdgeInsets.only(bottom: 16.0),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red),
                ),
              ),
            Text('Mobile Number *',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mobileController,
                    decoration:
                        InputDecoration(hintText: 'Enter your mobile number'),
                    keyboardType: TextInputType.phone,
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _requestVerificationCode,
                  child: Text('Get Code'),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text('Verification Code *',
                style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _verificationCodeController,
              decoration: InputDecoration(hintText: 'Enter verification code'),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16),
            Text('Password *', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                  hintText: 'Enter password (minimum 8 characters)'),
              obscureText: true,
            ),
            SizedBox(height: 16),
            Text('Confirm Password *',
                style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _confirmPasswordController,
              decoration: InputDecoration(hintText: 'Confirm your password'),
              obscureText: true,
            ),
            SizedBox(height: 24),
            Text('Profile Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Text('Nickname *', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _nicknameController,
              decoration: InputDecoration(hintText: 'Enter your nickname'),
            ),
            SizedBox(height: 16),
            Text('Patient Name *',
                style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _patientNameController,
              decoration: InputDecoration(hintText: 'Enter patient name'),
            ),
            SizedBox(height: 16),
            Text('Relationship to Patient *',
                style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _relationshipController,
              decoration: InputDecoration(
                  hintText: 'E.g., Self, Caregiver, Family member'),
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _register,
              child: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text('Register'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => LoginPage()),
                );
              },
              child: Text('Already have an account? Login'),
            ),
          ],
        ),
      ),
    );
  }
}
