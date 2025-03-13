import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;
import 'user_profile_service.dart';

// Custom HTTP client wrapper with logging
class LoggingHttpClient {
  final http.Client _client = http.Client();

  // Log request details as cURL command
  void _logRequestAsCurl(
      String method, Uri url, Map<String, String>? headers, dynamic body) {
    StringBuffer curlCmd = StringBuffer('curl -X $method');

    // Add headers
    if (headers != null) {
      headers.forEach((key, value) {
        curlCmd.write(" -H '$key: $value'");
      });
    }

    // Add body if present
    if (body != null) {
      // Escape quotes in body
      String escapedBody = body.toString().replaceAll("'", "'\\''");
      curlCmd.write(" -d '$escapedBody'");
    }

    // Add URL
    curlCmd.write(" '$url'");

    // Log the cURL command
    print('NETWORK_DEBUG: ${curlCmd.toString()}');
  }

  // Log response details
  void _logResponse(http.Response response) {
    developer.log(
        'HTTP Response: Status=${response.statusCode}, Body=${response.body.substring(0, response.body.length > 1000 ? 1000 : response.body.length)}${response.body.length > 1000 ? "..." : ""}',
        name: 'NetworkDebug');
  }

  // Log error details
  void _logError(String method, Uri url, dynamic error) {
    developer.log('HTTP Error for $method $url: $error',
        name: 'NetworkDebug', error: error);
  }

  // GET request with logging
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

  // POST request with logging
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

  // PUT request with logging
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

  // DELETE request with logging
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

  // Close the client
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

    // Initialize with existing note data if available
    if (widget.existingNote != null) {
      contentController.text = widget.existingNote!['content'] ?? '';
      selectedDate = widget.parseDateFromApi(widget.existingNote!['note_date']);
    } else {
      selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    // Properly dispose controller when the widget is disposed
    contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existingNote == null ? 'Add New Note' : 'Edit Note'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date picker section
            if (widget.existingNote ==
                null) // Only show date picker for new notes
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Date:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Text(widget.displayDateFormat.format(selectedDate)),
                      Spacer(),
                      TextButton.icon(
                        icon: Icon(Icons.calendar_today),
                        label: Text('Select'),
                        onPressed: () async {
                          final DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
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
                  Divider(),
                ],
              ),

            // Note content section
            Text('Note:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: TextField(
                controller: contentController,
                decoration: InputDecoration(
                  hintText: 'Write your note here...',
                  border: OutlineInputBorder(),
                ),
                maxLines: null,
                minLines: 5,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: Text('Cancel'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        ElevatedButton(
          child: Text('Save'),
          onPressed: () {
            final String noteContent = contentController.text;
            widget.onSave(noteContent, selectedDate);
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

class _NotePageState extends State<NotePage> {
  List<Map<String, dynamic>> _notes = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Create an instance of our logging HTTP client
  final LoggingHttpClient _httpClient = LoggingHttpClient();

  // Base URL for API calls
  final String _baseUrl = "http://hope.ioaths.com/hope";

  // Format for displaying dates in the UI
  final DateFormat _displayDateFormat = DateFormat('yyyy.MM.dd');

  // Format for API date strings (matching your backend format)
  String _formatDateForApi(DateTime date) {
    return "${date.year}.${date.month}.${date.day}";
  }

  // Parse API date string to DateTime
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
    // Clean up resources
    _httpClient.close();
    super.dispose();
  }

  // Fetch all notes
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

          // Sort notes by date (newest first)
          notesList.sort((a, b) {
            final dateA = _parseDateFromApi(a['note_date']);
            final dateB = _parseDateFromApi(b['note_date']);
            return dateB.compareTo(dateA); // Newest first
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

  // Save a new note
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
          // Refresh the notes list
          await _fetchNotes();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Note saved successfully')),
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

  // Update an existing note
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
          // Update the note in the local list before fetching
          final int noteIndex =
              _notes.indexWhere((note) => note['note_id'].toString() == noteId);
          if (noteIndex != -1) {
            setState(() {
              _notes[noteIndex]['content'] = content;
            });
          }

          // Refresh the notes list
          await _fetchNotes();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Note updated successfully')),
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

  // Delete a note
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
          // Remove the note from the local list
          setState(() {
            _notes.removeWhere((note) => note['note_id'].toString() == noteId);
            _isLoading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Note deleted successfully')),
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

  // Updated _showNoteDialog method for your _NotePageState class
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
              // Create new note
              _saveNote(content, date);
            } else {
              // Update existing note
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

  // Shows a confirmation dialog before deleting a note
  Future<bool> _confirmDelete() async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Delete Note'),
              content: Text('Are you sure you want to delete this note?'),
              actions: <Widget>[
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                TextButton(
                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Error message
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red),
                    ),
                  ),

                // Notes list
                Expanded(
                  child: _notes.isEmpty
                      ? Center(
                          child: Text(
                            'No notes yet. Click the + button to add one!',
                            style: TextStyle(fontSize: 16),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _notes.length,
                          itemBuilder: (context, index) {
                            final note = _notes[index];
                            final date = _parseDateFromApi(note['note_date']);

                            return Card(
                              margin: EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 10,
                              ),
                              elevation: 2,
                              child: InkWell(
                                onTap: () =>
                                    _showNoteDialog(existingNote: note),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.calendar_today, size: 16),
                                          SizedBox(width: 8),
                                          Text(
                                            _displayDateFormat.format(date),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Spacer(),
                                          IconButton(
                                            icon: Icon(Icons.edit,
                                                color: Colors.blue),
                                            onPressed: () {
                                              _showNoteDialog(
                                                  existingNote: note);
                                            },
                                            tooltip: 'Edit Note',
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.delete_outline,
                                                color: Colors.red),
                                            onPressed: () async {
                                              if (await _confirmDelete()) {
                                                _deleteNote(
                                                    note['note_id'].toString());
                                              }
                                            },
                                            tooltip: 'Delete Note',
                                          ),
                                        ],
                                      ),
                                      Divider(),
                                      Text(
                                        note['content'] ?? '',
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 15),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNoteDialog(),
        child: Icon(Icons.add),
        tooltip: 'Add New Note',
      ),
    );
  }
}
