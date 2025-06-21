import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'note.dart';
import 'chat.dart';
import 'setting.dart';
import 'post.dart';
import 'user_profile_service.dart';
import 'home.dart';

// 配色方案 - 温柔疗愈色系
class AppColors {
  // 主色调 - 温柔粉色系
  static const Color primary = Color(0xFFF8E8E7); // 浅粉色
  static const Color primaryLight = Color(0xFFFDF5F5); // 极浅粉
  static const Color accent = Color(0xFFE8F5E8); // 温柔绿色

  // 背景色
  static const Color background = Color(0xFFFCFBF9); // 温暖米白色
  static const Color cardBackground = Colors.white;

  // 文字颜色
  static const Color textPrimary = Color(0xFF2D2D2D); // 深灰色
  static const Color textSecondary = Color(0xFF8B8B8B); // 中灰色
  static const Color textLight = Color(0xFFB8B8B8); // 浅灰色

  // 功能色
  static const Color success = Color(0xFF92C5A7); // 温柔绿
  static const Color warning = Color(0xFFF4D4A7); // 温柔橙
  static const Color error = Color(0xFFE8A5A5); // 温柔红
}

// 圆角和间距
class AppDimens {
  static const double radiusSmall = 12.0;
  static const double radiusMedium = 16.0;
  static const double radiusLarge = 24.0;

  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
}

// 主题
class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      primarySwatch: Colors.pink,
      fontFamily: 'SF Pro Display',
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 8,
        selectedItemColor: AppColors.textPrimary,
        unselectedItemColor: AppColors.textLight,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle:
            TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        unselectedLabelStyle: TextStyle(fontSize: 12),
      ),
    );
  }
}

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '心灵伴侣',
      theme: AppTheme.theme,
      home: AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}
