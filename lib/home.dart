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
import 'register.dart';
import 'user_profile_service.dart';
import 'main.dart';

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
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTabItem(
                    0, Icons.chat_bubble_outline, Icons.chat_bubble, '心理咨询'),
                _buildTabItem(1, Icons.people_outline, Icons.people, '社区广场'),
                _buildTabItem(2, Icons.book_outlined, Icons.book, '心情日记'),
                _buildTabItem(3, Icons.settings_outlined, Icons.settings, '设置'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(
      int index, IconData iconOutlined, IconData iconFilled, String label) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? iconFilled : iconOutlined,
              color: isSelected ? AppColors.textPrimary : AppColors.textLight,
              size: 24,
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.textPrimary : AppColors.textLight,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
    final String? token = await UserProfileService.getAuthToken();
    setState(() {
      _isAuthenticated = token != null && token.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _isAuthenticated ? MyHomePage() : LoginPage();
  }
}

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _mobileController = TextEditingController(text: "13609747823");
  final _passwordController = TextEditingController(text: "12345678");
  bool _isLoading = false;

  Future<void> _login() async {
    if (_mobileController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('请填写完整信息'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final profile = await UserProfileService.login(
          _mobileController.text, _passwordController.text);

      if (profile != null) {
        Navigator.of(context)
            .pushReplacement(MaterialPageRoute(builder: (_) => MyHomePage()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('登录失败，请检查账号密码'),
          backgroundColor: AppColors.error,
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('登录出错: $e'),
        backgroundColor: AppColors.error,
      ));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryLight, AppColors.accent],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(AppDimens.paddingLarge),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo区域
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(60),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.favorite,
                      size: 60,
                      color: AppColors.success,
                    ),
                  ),
                  SizedBox(height: AppDimens.paddingLarge),

                  Text(
                    '心灵伴侣',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '温暖陪伴，疗愈内心',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: AppDimens.paddingLarge * 2),

                  // 登录表单
                  Container(
                    padding: EdgeInsets.all(AppDimens.paddingLarge),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(AppDimens.radiusMedium),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _mobileController,
                          decoration: InputDecoration(
                            labelText: '手机号码',
                            labelStyle:
                                TextStyle(color: AppColors.textSecondary),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppDimens.radiusSmall),
                              borderSide:
                                  BorderSide(color: AppColors.textLight),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppDimens.radiusSmall),
                              borderSide: BorderSide(color: AppColors.success),
                            ),
                            prefixIcon: Icon(Icons.phone,
                                color: AppColors.textSecondary),
                          ),
                          keyboardType: TextInputType.phone,
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                        SizedBox(height: AppDimens.paddingMedium),
                        TextField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: '密码',
                            labelStyle:
                                TextStyle(color: AppColors.textSecondary),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppDimens.radiusSmall),
                              borderSide:
                                  BorderSide(color: AppColors.textLight),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppDimens.radiusSmall),
                              borderSide: BorderSide(color: AppColors.success),
                            ),
                            prefixIcon: Icon(Icons.lock,
                                color: AppColors.textSecondary),
                          ),
                          obscureText: true,
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                        SizedBox(height: AppDimens.paddingLarge),
                        Container(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    AppDimens.radiusSmall),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    '登录',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: AppDimens.paddingLarge),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => RegisterPage()),
                      );
                    },
                    child: Text(
                      '还没有账号？立即注册',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
