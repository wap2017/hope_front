import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class UserProfile {
  final int id;
  final String patientName;
  final String relationshipToPatient;
  final String illnessCause;
  final String chatBackground;
  final String userAvatar;
  final String userNickname;
  final String mobileNumber;

  UserProfile({
    required this.id,
    required this.patientName,
    required this.relationshipToPatient,
    required this.illnessCause,
    required this.chatBackground,
    required this.userAvatar,
    required this.userNickname,
    required this.mobileNumber,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? 0,
      patientName: json['patient_name'] ?? '',
      relationshipToPatient: json['relationship_to_patient'] ?? '',
      illnessCause: json['illness_cause'] ?? '',
      chatBackground: json['chat_background'] ?? '',
      userAvatar: json['user_avatar'] ?? '',
      userNickname: json['user_nickname'] ?? '',
      mobileNumber: json['mobile_number'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_name': patientName,
      'relationship_to_patient': relationshipToPatient,
      'illness_cause': illnessCause,
      'chat_background': chatBackground,
      'user_avatar': userAvatar,
      'user_nickname': userNickname,
      'mobile_number': mobileNumber,
    };
  }
}

class UserProfileService {
  static const String _userProfileKey = 'user_profile';
  static const String _authTokenKey = 'auth_token';
  static const String _apiBaseUrl = 'http://hope.ioaths.com/hope';
  static UserProfile? _cachedProfile;
  static String? _authToken;

  // Set authentication token
  static void setAuthToken(String token) {
    _authToken = token;
  }

  static String get apiBaseUrl {
    return _apiBaseUrl;
  }

// Add this method to your UserProfileService class
  static Future<UserProfile?> register({
    required String mobileNumber,
    required String password,
    required String verificationCode,
    required String patientName,
    required String relationshipToPatient,
    required String userNickname,
    String illnessCause = '',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/auth/register'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Apifox/1.0.0 (https://apifox.com)',
        },
        body: jsonEncode({
          'mobile_number': mobileNumber,
          'password': password,
          'verification_code': verificationCode,
          'patient_name': patientName,
          'relationship_to_patient': relationshipToPatient,
          'user_nickname': userNickname,
          'illness_cause': illnessCause,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          // Save auth token
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', data['data']['token']);

          // Save profile
          final profile = UserProfile.fromJson(data['data']['profile']);
          await _saveProfileLocally(profile);
          _cachedProfile = profile;
          return profile;
        }
      }
      return null;
    } catch (e) {
      print('Error during registration: $e');
      return null;
    }
  }

  /* static String? getAuthToken() { */
  /*   // If the token is already in memory, return it immediately */
  /*   return _authToken; */
  /* } */

  // Recommended async method for token retrieval
  static Future<String?> getAuthToken() async {
    // If the token is already in memory, return it immediately
    if (_authToken != null && _authToken!.isNotEmpty) {
      return _authToken;
    }

    // Asynchronously retrieve the token from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final String? storedToken = prefs.getString(_authTokenKey);

    // Update the in-memory token if a valid token is found
    if (storedToken != null && storedToken.isNotEmpty) {
      _authToken = storedToken;
      return _authToken;
    }

    // Return null if no token is found
    return null;
  }

  // Fetch user profile from API and save locally
  static Future<UserProfile?> fetchAndSaveProfile(int userId) async {
    try {
      final token = await UserProfileService.getAuthToken();
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/user/profile?id=$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final profile = UserProfile.fromJson(data['data']);
          await _saveProfileLocally(profile);
          _cachedProfile = profile;
          return profile;
        }
      }
      return null;
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }

  // Get profile from local storage
  static Future<UserProfile?> getProfile() async {
    print("getProfile");
    if (_cachedProfile != null) {
      return _cachedProfile;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final profileString = prefs.getString(_userProfileKey);
      print("profileString, $profileString");

      if (profileString != null) {
        final profileJson = jsonDecode(profileString);
        _cachedProfile = UserProfile.fromJson(profileJson);
        print("_cachedProfile, $_cachedProfile");
        return _cachedProfile;
      }
      return null;
    } catch (e) {
      print('Error getting profile from local storage: $e');
      return null;
    }
  }

  // Save token to local storage
  static Future<bool> _saveAuthTokenLocally(String? token) async {
    print("_saveAuthTokenLocally $token");
    try {
      final prefs = await SharedPreferences.getInstance();
      /* final profileJson = jsonEncode(profile.toJson()); */
      return await prefs.setString(_authTokenKey, token ?? '');
    } catch (e) {
      print('Error saving auth token to local storage: $e');
      return false;
    }
  }

  // Save profile to local storage
  static Future<bool> _saveProfileLocally(UserProfile profile) async {
    print("_saveProfileLocally $profile");
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = jsonEncode(profile.toJson());
      return await prefs.setString(_userProfileKey, profileJson);
    } catch (e) {
      print('Error saving profile to local storage: $e');
      return false;
    }
  }

  // Update profile via API and save locally
  static Future<bool> updateProfile(UserProfile updatedProfile) async {
    try {
      final token = await UserProfileService.getAuthToken();
      final response = await http.put(
        Uri.parse('$_apiBaseUrl/user/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(updatedProfile.toJson()),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          await _saveProfileLocally(updatedProfile);
          _cachedProfile = updatedProfile;
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Error updating profile: $e');
      return false;
    }
  }

// Login method
  static Future<UserProfile?> login(
      String mobileNumber, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'mobile_number': mobileNumber,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          setAuthToken(data['data']['token']);
          await _saveAuthTokenLocally(data['data']['token']);
          final profile = UserProfile.fromJson(data['data']['profile']);
          await _saveProfileLocally(profile);
          _cachedProfile = profile;
          return profile;
        }
      }
      return null;
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }

  // Add this method to the UserProfileService class
  static void clearCache() {
    _cachedProfile = null;
    _authToken = null;
    // Clear local storage
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove(_userProfileKey);
    });
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove(_authTokenKey);
    });
  }
}
