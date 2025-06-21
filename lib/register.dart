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
import 'main.dart';

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
  bool _isCodeSent = false;
  int _countdown = 0;

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
        _errorMessage = '请输入手机号码';
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
          setState(() {
            _isCodeSent = true;
            _countdown = 60;
          });
          _startCountdown();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('验证码发送成功'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          setState(() {
            _errorMessage = data['message'] ?? '验证码发送失败';
          });
        }
      } else {
        setState(() {
          _errorMessage = '服务器错误: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '网络错误: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startCountdown() {
    Future.delayed(Duration(seconds: 1), () {
      if (_countdown > 0) {
        setState(() {
          _countdown--;
        });
        _startCountdown();
      }
    });
  }

  Future<void> _register() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = '两次输入的密码不一致';
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
        _errorMessage = '请填写所有必填项';
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
          'illness_cause': '',
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', data['data']['token']);

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => MyHomePage()),
          );
        } else {
          setState(() {
            _errorMessage = data['message'] ?? '注册失败';
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("错误: ${response.body}"),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 4),
          ),
        );
        setState(() {
          _errorMessage = '服务器错误: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '网络错误: $e';
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryLight, AppColors.accent],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(AppDimens.paddingLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.arrow_back,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      '创建账号',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Padding(
                  padding: EdgeInsets.only(left: 56),
                  child: Text(
                    '让我们开始温暖的陪伴之旅',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                SizedBox(height: AppDimens.paddingLarge * 2),

                // Registration Form
                Container(
                  padding: EdgeInsets.all(AppDimens.paddingLarge),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_errorMessage != null)
                        Container(
                          padding: EdgeInsets.all(AppDimens.paddingMedium),
                          margin:
                              EdgeInsets.only(bottom: AppDimens.paddingMedium),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.1),
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusSmall),
                            border: Border.all(
                                color: AppColors.error.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline,
                                  color: AppColors.error, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                      color: AppColors.error, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Phone number section
                      Text(
                        '手机号码 *',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _mobileController,
                              hintText: '请输入手机号码',
                              keyboardType: TextInputType.phone,
                              prefixIcon: Icons.phone,
                            ),
                          ),
                          SizedBox(width: 12),
                          Container(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: (_isLoading || _countdown > 0)
                                  ? null
                                  : _requestVerificationCode,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _countdown > 0
                                    ? AppColors.textLight
                                    : AppColors.success,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      AppDimens.radiusSmall),
                                ),
                                elevation: 0,
                                padding: EdgeInsets.symmetric(horizontal: 16),
                              ),
                              child: Text(
                                _countdown > 0 ? '${_countdown}s' : '获取验证码',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppDimens.paddingMedium),

                      // Verification code
                      Text(
                        '验证码 *',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 8),
                      _buildTextField(
                        controller: _verificationCodeController,
                        hintText: '请输入验证码',
                        keyboardType: TextInputType.number,
                        prefixIcon: Icons.security,
                      ),
                      SizedBox(height: AppDimens.paddingMedium),

                      // Password
                      Text(
                        '密码 *',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 8),
                      _buildTextField(
                        controller: _passwordController,
                        hintText: '请输入密码（至少8位）',
                        obscureText: true,
                        prefixIcon: Icons.lock,
                      ),
                      SizedBox(height: AppDimens.paddingMedium),

                      // Confirm Password
                      Text(
                        '确认密码 *',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 8),
                      _buildTextField(
                        controller: _confirmPasswordController,
                        hintText: '请再次输入密码',
                        obscureText: true,
                        prefixIcon: Icons.lock_outline,
                      ),
                      SizedBox(height: AppDimens.paddingLarge),

                      // Profile Information Section
                      Container(
                        padding: EdgeInsets.all(AppDimens.paddingMedium),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.1),
                          borderRadius:
                              BorderRadius.circular(AppDimens.radiusSmall),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.person_outline,
                                  color: AppColors.success,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  '个人信息',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            Text(
                              '昵称 *',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 8),
                            _buildTextField(
                              controller: _nicknameController,
                              hintText: '请输入您的昵称',
                              prefixIcon: Icons.tag_faces,
                            ),
                            SizedBox(height: AppDimens.paddingMedium),
                            Text(
                              '患者姓名 *',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 8),
                            _buildTextField(
                              controller: _patientNameController,
                              hintText: '请输入患者姓名',
                              prefixIcon: Icons.people,
                            ),
                            SizedBox(height: AppDimens.paddingMedium),
                            Text(
                              '与患者关系 *',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 8),
                            _buildTextField(
                              controller: _relationshipController,
                              hintText: '如：本人、家属、朋友等',
                              prefixIcon: Icons.favorite,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: AppDimens.paddingLarge),

                      // Register Button
                      Container(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppDimens.radiusSmall),
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
                                  '创建账号',
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
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => LoginPage()),
                      );
                    },
                    child: Text(
                      '已有账号？立即登录',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    TextInputType? keyboardType,
    IconData? prefixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
        border: Border.all(
          color: AppColors.textLight.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: AppColors.textLight,
            fontSize: 14,
          ),
          prefixIcon: prefixIcon != null
              ? Icon(
                  prefixIcon,
                  color: AppColors.textSecondary,
                  size: 20,
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: prefixIcon != null ? 0 : AppDimens.paddingMedium,
            vertical: 15,
          ),
        ),
        style: TextStyle(
          fontSize: 15,
          color: AppColors.textPrimary,
        ),
        obscureText: obscureText,
        keyboardType: keyboardType,
      ),
    );
  }
}
