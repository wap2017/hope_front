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
import 'home.dart';

void main() {
  runApp(MyApp());
}
