import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'user_profile_service.dart';
import 'home.dart';

class ApiErrorHandler {
  // Static method to handle HTTP responses and check for 401 errors
  static bool handleHttpResponse(
    http.Response response,
    BuildContext context, {
    bool shouldRedirectOn401 = true,
  }) {
    if (response.statusCode == 401 && shouldRedirectOn401) {
      _handleTokenExpiration(context);
      return false; // Indicates that the request failed due to authentication
    }
    return true; // Request can be processed normally
  }

  // Static method to handle token expiration
  static void _handleTokenExpiration(BuildContext context) {
    // Clear all cached data
    UserProfileService.clearCache();

    // Show message to user
    _showTokenExpiredMessage(context);

    // Navigate to login page and clear all routes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LoginPage()),
        (route) => false,
      );
    });
  }

  // Show token expired message
  static void _showTokenExpiredMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('登录已过期，请重新登录'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
      ),
    );
  }

  // Convenience method for handling API responses with error messages
  static Map<String, dynamic>? handleApiResponse(
    http.Response response,
    BuildContext context, {
    bool shouldRedirectOn401 = true,
    String? customErrorMessage,
  }) {
    // Check for 401 first
    if (!handleHttpResponse(response, context,
        shouldRedirectOn401: shouldRedirectOn401)) {
      return null; // Token expired, handled by the method above
    }

    // Handle other status codes
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        return jsonDecode(response.body);
      } catch (e) {
        _showErrorMessage(context, customErrorMessage ?? '数据解析失败');
        return null;
      }
    } else {
      // Handle other error status codes
      String errorMessage =
          customErrorMessage ?? '服务器错误 (${response.statusCode})';

      try {
        final errorData = jsonDecode(response.body);
        if (errorData['message'] != null) {
          errorMessage = errorData['message'];
        }
      } catch (e) {
        // Keep the default error message if JSON parsing fails
      }

      _showErrorMessage(context, errorMessage);
      return null;
    }
  }

  // Show error message
  static void _showErrorMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // Method to handle exceptions (network errors, etc.)
  static void handleException(BuildContext context, dynamic exception,
      {String? customMessage}) {
    String errorMessage = customMessage ?? '网络连接失败，请检查网络设置';

    if (exception.toString().contains('SocketException')) {
      errorMessage = '无法连接到服务器，请检查网络连接';
    } else if (exception.toString().contains('TimeoutException')) {
      errorMessage = '请求超时，请稍后重试';
    }

    _showErrorMessage(context, errorMessage);
  }
}
