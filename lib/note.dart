import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;
import 'user_profile_service.dart';
import 'main.dart';

// Custom HTTP client wrapper with logging
class LoggingHttpClient {
  final http.Client _client = http.Client();

  void _logRequestAsCurl(
      String method, Uri url, Map<String, String>? headers, dynamic body) {
    StringBuffer curlCmd = StringBuffer('curl -X $method');

    if (headers != null) {
      headers.forEach((key, value) {
        curlCmd.write(" -H '$key: $value'");
      });
    }

    if (body != null) {
      String escapedBody = body.toString().replaceAll("'", "'\\''");
      curlCmd.write(" -d '$escapedBody'");
    }

    curlCmd.write(" '$url'");
    print('NETWORK_DEBUG: ${curlCmd.toString()}');
  }

  void _logResponse(http.Response response) {
    developer.log(
        'HTTP Response: Status=${response.statusCode}, Body=${response.body.substring(0, response.body.length > 1000 ? 1000 : response.body.length)}${response.body.length > 1000 ? "..." : ""}',
        name: 'NetworkDebug');
  }

  void _logError(String method, Uri url, dynamic error) {
    developer.log('HTTP Error for $method $url: $error',
        name: 'NetworkDebug', error: error);
  }

  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    _logRequestAsCurl('GET', url, headers, null);

    try {
      final response = await _client.get(url, headers: headers);
      _logResponse(response);
      return response;
    } catch (e) {
      _logError('GET', url, e);
      rethrow;
    }
  }

  Future<http.Response> post(Uri url,
      {Map<String, String>? headers, dynamic body}) async {
    _logRequestAsCurl('POST', url, headers, body);

    try {
      final response = await _client.post(url, headers: headers, body: body);
      _logResponse(response);
      return response;
    } catch (e) {
      _logError('POST', url, e);
      rethrow;
    }
  }

  Future<http.Response> put(Uri url,
      {Map<String, String>? headers, dynamic body}) async {
    _logRequestAsCurl('PUT', url, headers, body);

    try {
      final response = await _client.put(url, headers: headers, body: body);
      _logResponse(response);
      return response;
    } catch (e) {
      _logError('PUT', url, e);
      rethrow;
    }
  }

  Future<http.Response> delete(Uri url, {Map<String, String>? headers}) async {
    _logRequestAsCurl('DELETE', url, headers, null);

    try {
      final response = await _client.delete(url, headers: headers);
      _logResponse(response);
      return response;
    } catch (e) {
      _logError('DELETE', url, e);
      rethrow;
    }
  }

  void close() {
    _client.close();
  }
}

class NotePage extends StatefulWidget {
  @override
  _NotePageState createState() => _NotePageState();
}

// Define a separate StatefulWidget for the note dialog content
class NoteDialogContent extends StatefulWidget {
  final Map<String, dynamic>? existingNote;
  final Function(String content, DateTime date) onSave;
  final DateFormat displayDateFormat;
  final Function(String dateStr) parseDateFromApi;

  NoteDialogContent({
    Key? key,
    this.existingNote,
    required this.onSave,
    required this.displayDateFormat,
    required this.parseDateFromApi,
  }) : super(key: key);

  @override
  _NoteDialogContentState createState() => _NoteDialogContentState();
}

class _NoteDialogContentState extends State<NoteDialogContent> {
  late TextEditingController contentController;
  late DateTime selectedDate;

  @override
  void initState() {
    super.initState();
    contentController = TextEditingController();

    if (widget.existingNote != null) {
      contentController.text = widget.existingNote!['content'] ?? '';
      selectedDate = widget.parseDateFromApi(widget.existingNote!['note_date']);
    } else {
      selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(AppDimens.paddingMedium),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryLight, AppColors.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppDimens.radiusMedium),
                  topRight: Radius.circular(AppDimens.radiusMedium),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.book,
                    color: AppColors.success,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Text(
                    widget.existingNote == null ? '记录心情' : '编辑心情',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(AppDimens.paddingMedium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date picker section
                    if (widget.existingNote == null)
                      Container(
                        padding: EdgeInsets.all(AppDimens.paddingMedium),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.3),
                          borderRadius:
                              BorderRadius.circular(AppDimens.radiusSmall),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '日期',
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
                                  child: Text(
                                    widget.displayDateFormat
                                        .format(selectedDate),
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  icon: Icon(
                                    Icons.calendar_today,
                                    color: AppColors.success,
                                    size: 18,
                                  ),
                                  label: Text(
                                    '选择',
                                    style: TextStyle(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  onPressed: () async {
                                    final DateTime? pickedDate =
                                        await showDatePicker(
                                      context: context,
                                      initialDate: selectedDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2030),
                                      builder: (context, child) {
                                        return Theme(
                                          data: Theme.of(context).copyWith(
                                            colorScheme: ColorScheme.light(
                                              primary: AppColors.success,
                                              onPrimary: Colors.white,
                                              surface: Colors.white,
                                              onSurface: AppColors.textPrimary,
                                            ),
                                          ),
                                          child: child!,
                                        );
                                      },
                                    );
                                    if (pickedDate != null && mounted) {
                                      setState(() {
                                        selectedDate = pickedDate;
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                    if (widget.existingNote == null)
                      SizedBox(height: AppDimens.paddingMedium),

                    // Note content section
                    Text(
                      '心情记录',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius:
                            BorderRadius.circular(AppDimens.radiusSmall),
                        border: Border.all(
                          color: AppColors.textLight.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: contentController,
                        decoration: InputDecoration(
                          hintText: '记录今天的感受和想法...',
                          hintStyle: TextStyle(color: AppColors.textLight),
                          border: InputBorder.none,
                          contentPadding:
                              EdgeInsets.all(AppDimens.paddingMedium),
                        ),
                        maxLines: null,
                        minLines: 6,
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textPrimary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: EdgeInsets.all(AppDimens.paddingMedium),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimens.radiusSmall),
                        ),
                      ),
                      child: Text(
                        '取消',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final String noteContent =
                            contentController.text.trim();
                        if (noteContent.isNotEmpty) {
                          widget.onSave(noteContent, selectedDate);
                          Navigator.of(context).pop();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimens.radiusSmall),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        '保存',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotePageState extends State<NotePage> {
  List<Map<String, dynamic>> _notes = [];
  bool _isLoading = false;
  String? _errorMessage;

  final LoggingHttpClient _httpClient = LoggingHttpClient();
  final String _baseUrl = "https://hope.layu.cc/hope";
  final DateFormat _displayDateFormat = DateFormat('yyyy.MM.dd');

  String _formatDateForApi(DateTime date) {
    return "${date.year}.${date.month}.${date.day}";
  }

  DateTime _parseDateFromApi(String dateStr) {
    final parts = dateStr.split('.');
    if (parts.length == 3) {
      return DateTime(
          int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    }
    return DateTime.now();
  }

  @override
  void initState() {
    super.initState();
    developer.log('App started - testing logging system', name: 'NetworkDebug');
    _fetchNotes();
  }

  @override
  void dispose() {
    _httpClient.close();
    super.dispose();
  }

  Future<void> _fetchNotes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      developer.log('Fetching all notes', name: 'NotePage');

      final token = await UserProfileService.getAuthToken();
      final response = await _httpClient.get(
        Uri.parse("$_baseUrl/notes"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        if (responseData['success'] == true && responseData['data'] != null) {
          final notesList =
              List<Map<String, dynamic>>.from(responseData['data']);

          notesList.sort((a, b) {
            final dateA = _parseDateFromApi(a['note_date']);
            final dateB = _parseDateFromApi(b['note_date']);
            return dateB.compareTo(dateA);
          });

          setState(() {
            _notes = notesList;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = responseData['message'] ?? 'Failed to load notes';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Server error: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      developer.log('Error fetching notes', name: 'NotePage', error: e);
      setState(() {
        _errorMessage = 'Error connecting to server: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveNote(String content, DateTime date) async {
    if (content.isEmpty) return;

    final dateString = _formatDateForApi(date);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      developer.log('Creating new note for date: $dateString',
          name: 'NotePage');

      final token = await UserProfileService.getAuthToken();
      final response = await _httpClient.post(
        Uri.parse("$_baseUrl/notes"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'note_date': dateString,
          'content': content,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        if (responseData['success'] == true) {
          await _fetchNotes();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('心情记录保存成功'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          setState(() {
            _errorMessage = responseData['message'] ?? 'Failed to save note';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Server error: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      developer.log('Error saving note', name: 'NotePage', error: e);
      setState(() {
        _errorMessage = 'Error connecting to server: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateNote(String noteId, String content) async {
    if (content.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      developer.log('Updating note with ID: $noteId', name: 'NotePage');

      final token = await UserProfileService.getAuthToken();
      final response = await _httpClient.put(
        Uri.parse("$_baseUrl/notes/$noteId"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'content': content,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        if (responseData['success'] == true) {
          final int noteIndex =
              _notes.indexWhere((note) => note['note_id'].toString() == noteId);
          if (noteIndex != -1) {
            setState(() {
              _notes[noteIndex]['content'] = content;
            });
          }

          await _fetchNotes();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('心情记录更新成功'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          setState(() {
            _errorMessage = responseData['message'] ?? 'Failed to update note';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Server error: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      developer.log('Error updating note', name: 'NotePage', error: e);
      setState(() {
        _errorMessage = 'Error connecting to server: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteNote(String noteId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      developer.log('Deleting note with ID: $noteId', name: 'NotePage');

      final token = await UserProfileService.getAuthToken();
      final response = await _httpClient.delete(
        Uri.parse("$_baseUrl/notes/$noteId"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        if (responseData['success'] == true) {
          setState(() {
            _notes.removeWhere((note) => note['note_id'].toString() == noteId);
            _isLoading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('心情记录删除成功'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          setState(() {
            _errorMessage = responseData['message'] ?? 'Failed to delete note';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Server error: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      developer.log('Error deleting note', name: 'NotePage', error: e);
      setState(() {
        _errorMessage = 'Error connecting to server: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _showNoteDialog({Map<String, dynamic>? existingNote}) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return NoteDialogContent(
          existingNote: existingNote,
          displayDateFormat: _displayDateFormat,
          parseDateFromApi: _parseDateFromApi,
          onSave: (String content, DateTime date) {
            if (existingNote == null) {
              _saveNote(content, date);
            } else {
              _updateNote(
                existingNote['note_id'].toString(),
                content,
              );
            }
          },
        );
      },
    );
  }

  Future<bool> _confirmDelete() async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
              ),
              child: Padding(
                padding: EdgeInsets.all(AppDimens.paddingMedium),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.delete_outline,
                      size: 48,
                      color: AppColors.error,
                    ),
                    SizedBox(height: 16),
                    Text(
                      '删除心情记录',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '确定要删除这条心情记录吗？删除后将无法恢复。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              '取消',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    AppDimens.radiusSmall),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              '删除',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ) ??
        false;
  }

  IconData _getMoodIcon(DateTime date) {
    // Simple mood icon based on day of week for demo
    final dayOfWeek = date.weekday;
    switch (dayOfWeek) {
      case 1:
        return Icons.sentiment_very_satisfied;
      case 2:
        return Icons.sentiment_satisfied;
      case 3:
        return Icons.sentiment_neutral;
      case 4:
        return Icons.sentiment_dissatisfied;
      case 5:
        return Icons.sentiment_very_dissatisfied;
      case 6:
        return Icons.sentiment_satisfied_alt;
      case 7:
        return Icons.sentiment_very_satisfied;
      default:
        return Icons.sentiment_neutral;
    }
  }

  Color _getMoodColor(DateTime date) {
    final dayOfWeek = date.weekday;
    switch (dayOfWeek) {
      case 1:
        return AppColors.success;
      case 2:
        return AppColors.success;
      case 3:
        return AppColors.warning;
      case 4:
        return AppColors.error;
      case 5:
        return AppColors.error;
      case 6:
        return AppColors.success;
      case 7:
        return AppColors.success;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '心情日记',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.success),
              ),
            )
          : Column(
              children: [
                if (_errorMessage != null)
                  Container(
                    margin: EdgeInsets.all(AppDimens.paddingMedium),
                    padding: EdgeInsets.all(AppDimens.paddingMedium),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(AppDimens.radiusSmall),
                      border:
                          Border.all(color: AppColors.error.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: AppColors.error),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: AppColors.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: _notes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.book_outlined,
                                size: 64,
                                color: AppColors.textLight,
                              ),
                              SizedBox(height: 16),
                              Text(
                                '还没有心情记录\n开始记录你的第一篇日记吧',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.textLight,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.all(AppDimens.paddingMedium),
                          itemCount: _notes.length,
                          itemBuilder: (context, index) {
                            final note = _notes[index];
                            final date = _parseDateFromApi(note['note_date']);

                            return Container(
                              margin: EdgeInsets.only(
                                  bottom: AppDimens.paddingMedium),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(
                                    AppDimens.radiusMedium),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 12,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // Header with gradient background
                                  Container(
                                    width: double.infinity,
                                    padding:
                                        EdgeInsets.all(AppDimens.paddingMedium),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.primaryLight,
                                          AppColors.accent
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(
                                            AppDimens.radiusMedium),
                                        topRight: Radius.circular(
                                            AppDimens.radiusMedium),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(0.8),
                                            borderRadius: BorderRadius.circular(
                                                AppDimens.radiusSmall),
                                          ),
                                          child: Icon(
                                            _getMoodIcon(date),
                                            color: _getMoodColor(date),
                                            size: 24,
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _displayDateFormat.format(date),
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                              Text(
                                                _getRelativeDate(date),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        PopupMenuButton<String>(
                                          icon: Icon(
                                            Icons.more_vert,
                                            color: AppColors.textSecondary,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                                AppDimens.radiusSmall),
                                          ),
                                          onSelected: (value) async {
                                            if (value == 'edit') {
                                              _showNoteDialog(
                                                  existingNote: note);
                                            } else if (value == 'delete') {
                                              if (await _confirmDelete()) {
                                                _deleteNote(
                                                    note['note_id'].toString());
                                              }
                                            }
                                          },
                                          itemBuilder: (BuildContext context) =>
                                              [
                                            PopupMenuItem<String>(
                                              value: 'edit',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.edit,
                                                      color: AppColors.success,
                                                      size: 20),
                                                  SizedBox(width: 12),
                                                  Text('编辑'),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem<String>(
                                              value: 'delete',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.delete,
                                                      color: AppColors.error,
                                                      size: 20),
                                                  SizedBox(width: 12),
                                                  Text('删除'),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Content
                                  InkWell(
                                    onTap: () =>
                                        _showNoteDialog(existingNote: note),
                                    child: Container(
                                      width: double.infinity,
                                      padding: EdgeInsets.all(
                                          AppDimens.paddingMedium),
                                      child: Text(
                                        note['content'] ?? '',
                                        style: TextStyle(
                                          fontSize: 15,
                                          height: 1.6,
                                          color: AppColors.textPrimary,
                                        ),
                                        maxLines: 4,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.success, AppColors.accent],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.success.withOpacity(0.3),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => _showNoteDialog(),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Icon(
            Icons.add,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }

  String _getRelativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    final noteDate = DateTime(date.year, date.month, date.day);

    if (noteDate == today) {
      return '今天';
    } else if (noteDate == yesterday) {
      return '昨天';
    } else {
      final difference = today.difference(noteDate).inDays;
      if (difference < 7) {
        return '$difference 天前';
      } else if (difference < 30) {
        return '${(difference / 7).floor()} 周前';
      } else if (difference < 365) {
        return '${(difference / 30).floor()} 个月前';
      } else {
        return '${(difference / 365).floor()} 年前';
      }
    }
  }
}
