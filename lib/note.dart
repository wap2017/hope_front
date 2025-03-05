import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:developer' as developer;

// Custom HTTP client wrapper with logging
class LoggingHttpClient {
  final http.Client _client = http.Client();
  
  // Log request details as cURL command
  void _logRequestAsCurl(String method, Uri url, Map<String, String>? headers, dynamic body) {
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
    /* developer.log('HTTP Request as cURL: ${curlCmd.toString()}', name: 'NetworkDebug'); */
    print('NETWORK_DEBUG: ${curlCmd.toString()}');
  }
  
  // Log response details
  void _logResponse(http.Response response) {
    developer.log(
      'HTTP Response: Status=${response.statusCode}, Body=${response.body.substring(0, 
        response.body.length > 1000 ? 1000 : response.body.length)}${response.body.length > 1000 ? "..." : ""}',
      name: 'NetworkDebug'
    );
  }
  
  // Log error details
  void _logError(String method, Uri url, dynamic error) {
    developer.log(
      'HTTP Error for $method $url: $error',
      name: 'NetworkDebug',
      error: error
    );
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
  Future<http.Response> post(Uri url, {Map<String, String>? headers, dynamic body}) async {
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
  Future<http.Response> put(Uri url, {Map<String, String>? headers, dynamic body}) async {
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

class _NotePageState extends State<NotePage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  
  List<Map<String, dynamic>> _notes = [];
  Map<DateTime, List<dynamic>> _eventsMap = {};
  
  TextEditingController _noteController = TextEditingController();
  bool _isLoading = false;
  String? _currentNoteId;
  String? _errorMessage;
  
  // Create an instance of our logging HTTP client
  final LoggingHttpClient _httpClient = LoggingHttpClient();
  
  // Base URL for API calls
  final String _baseUrl = "http://hope.ioaths.com/hope";
  
  // Format for displaying dates in the UI
  final DateFormat _displayDateFormat = DateFormat('yyyy.M.d');
  
  // Format for API date strings (matching your backend format)
  String _formatDateForApi(DateTime date) {
    return "${date.year}.${date.month}.${date.day}";
  }
  
  // Parse API date string to DateTime
  DateTime _parseDateFromApi(String dateStr) {
    final parts = dateStr.split('.');
    if (parts.length == 3) {
      return DateTime(
        int.parse(parts[0]), 
        int.parse(parts[1]), 
        int.parse(parts[2])
      );
    }
    return DateTime.now();
  }

  @override
  void initState() {
    super.initState();
    developer.log('App started - testing logging system', name:'NetworkDebug');
    print('Hello');
    _fetchNotes();
  }
  
  @override
  void dispose() {
    // Clean up resources
    _noteController.dispose();
    _httpClient.close();
    super.dispose();
  }
  
  // Fetch all notes and build the events map for the calendar
  Future<void> _fetchNotes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      developer.log('Fetching all notes', name: 'NotePage');
      
      final response = await _httpClient.get(
        Uri.parse("$_baseUrl/notes"),
        headers: {
          'X-User-ID': '1', // Replace with actual user authentication
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        
        if (responseData['success'] == true && responseData['data'] != null) {
          final notesList = List<Map<String, dynamic>>.from(responseData['data']);
          
          // Build events map for calendar
          Map<DateTime, List<dynamic>> eventsData = {};
          
          for (var note in notesList) {
            final dateStr = note['note_date'];
            final dateTime = _parseDateFromApi(dateStr);
            
            // Normalize date to avoid time component issues
            final normalizedDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
            
            if (eventsData[normalizedDate] == null) {
              eventsData[normalizedDate] = [];
            }
            eventsData[normalizedDate]!.add(note);
          }
          
          setState(() {
            _notes = notesList;
            _eventsMap = eventsData;
            _isLoading = false;
          });
          
          // Fetch note for the selected day
          _fetchNoteForDate(_selectedDay);
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
  
  // Get events for a specific day
  List<dynamic> _getEventsForDay(DateTime day) {
    // Normalize date to avoid time component issues
    final normalizedDate = DateTime(day.year, day.month, day.day);
    return _eventsMap[normalizedDate] ?? [];
  }
  
  // Fetch a note for the selected date
  Future<void> _fetchNoteForDate(DateTime date) async {
    final dateString = _formatDateForApi(date);
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _noteController.clear();
      _currentNoteId = null;
    });
    
    try {
      developer.log('Fetching note for date: $dateString', name: 'NotePage');
      
      final response = await _httpClient.get(
        Uri.parse("$_baseUrl/notes/date/$dateString"),
        headers: {
          'X-User-ID': '1', // Replace with actual user authentication
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        
        if (responseData['success'] == true && responseData['data'] != null) {
          final noteData = responseData['data'];
          setState(() {
            _noteController.text = noteData['content'] ?? '';
            _currentNoteId = noteData['note_id'].toString();
            _isLoading = false;
          });
        } else {
          // No note for this date, which is fine
          setState(() {
            _isLoading = false;
          });
        }
      } else if (response.statusCode == 404) {
        // No note found for this date, which is expected
        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Server error: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      developer.log('Error fetching note for date', name: 'NotePage', error: e);
      setState(() {
        _errorMessage = 'Error connecting to server: $e';
        _isLoading = false;
      });
    }
  }
  
  // Save or update a note
  Future<void> _saveNote() async {
    if (_noteController.text.isEmpty) return;
    
    final dateString = _formatDateForApi(_selectedDay);
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      http.Response response;
      
      if (_currentNoteId != null) {
        // Update existing note
        developer.log('Updating note with ID: $_currentNoteId', name: 'NotePage');
        
        response = await _httpClient.put(
          Uri.parse("$_baseUrl/notes/$_currentNoteId"),
          headers: {
            'X-User-ID': '1', // Replace with actual user authentication
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'content': _noteController.text,
          }),
        );
      } else {
        // Create new note
        developer.log('Creating new note for date: $dateString', name: 'NotePage');
        
        response = await _httpClient.post(
          Uri.parse("$_baseUrl/notes"),
          headers: {
            'X-User-ID': '1', // Replace with actual user authentication
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'note_date': dateString,
            'content': _noteController.text,
          }),
        );
      }
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        
        if (responseData['success'] == true) {
          // Refresh the notes to update the calendar
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
  
  // Delete a note
  Future<void> _deleteNote() async {
    if (_currentNoteId == null) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      developer.log('Deleting note with ID: $_currentNoteId', name: 'NotePage');
      
      final response = await _httpClient.delete(
        Uri.parse("$_baseUrl/notes/$_currentNoteId"),
        headers: {
          'X-User-ID': '1', // Replace with actual user authentication
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        
        if (responseData['success'] == true) {
          // Clear the form
          setState(() {
            _noteController.clear();
            _currentNoteId = null;
          });
          
          // Refresh notes to update the calendar
          await _fetchNotes();
          
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Calendar
          Card(
            elevation: 4,
            margin: EdgeInsets.only(bottom: 16),
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
              eventLoader: _getEventsForDay,
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
                _fetchNoteForDate(selectedDay);
              },
              onFormatChanged: (format) {
                setState(() {
                  _calendarFormat = format;
                });
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
              // Calendar styling
              calendarStyle: CalendarStyle(
                // Today decoration
                todayDecoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                // Selected day decoration
                selectedDecoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                // Days with events
                markerDecoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          
          // Error message
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red),
              ),
            ),
            
          // Selected date display
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                Text(
                  'Note for ${_displayDateFormat.format(_selectedDay)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacer(),
                if (_currentNoteId != null)
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: _isLoading ? null : _deleteNote,
                    tooltip: 'Delete this note',
                  ),
              ],
            ),
          ),
          
          // Note editor
          Expanded(
            child: Card(
              elevation: 4,
              child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _noteController,
                      decoration: InputDecoration(
                        hintText: 'Write your note here...',
                        border: InputBorder.none,
                      ),
                      maxLines: null,
                      expands: true,
                    ),
                  ),
            ),
          ),
          
          // Save button
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(_isLoading ? Icons.hourglass_empty : Icons.save),
                label: Text(_isLoading ? 'Saving...' : 'Save Note'),
                onPressed: _isLoading ? null : _saveNote,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          
          // Debug button (only in debug mode)
          if (true) // Change this to a debug flag in production
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: Icon(Icons.bug_report),
                  label: Text('Test Connection'),
                  onPressed: () async {
                    try {
                      developer.log('Testing server connection', name: 'NetworkDebug');
                      final response = await _httpClient.get(
                        Uri.parse("$_baseUrl/health"),
                        headers: {'Content-Type': 'application/json'},
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Server response: ${response.statusCode}')),
                      );
                    } catch (e) {
                      developer.log('Connection test failed', name: 'NetworkDebug', error: e);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Connection error: $e')),
                      );
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
