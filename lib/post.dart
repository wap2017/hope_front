import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  // Extension for MultipartRequest with logging
  Future<http.Response> sendMultipartRequest(
      http.MultipartRequest request) async {
    // Log as curl command with simplified body info
    StringBuffer curlCmd = StringBuffer('curl -X ${request.method}');

    // Add headers
    request.headers.forEach((key, value) {
      curlCmd.write(" -H '$key: $value'");
    });

    // Log fields
    request.fields.forEach((key, value) {
      curlCmd.write(" -F '$key=$value'");
    });

    // Log files (simplified)
    for (var file in request.files) {
      curlCmd.write(" -F '${file.field}=@${file.filename}'");
    }

    // Add URL
    curlCmd.write(" '${request.url}'");

    // Log the cURL command
    print('NETWORK_DEBUG: ${curlCmd.toString()}');

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      _logResponse(response);
      return response;
    } catch (e) {
      _logError(request.method, request.url, e);
      rethrow;
    }
  }
}

class PostSquarePage extends StatefulWidget {
  @override
  _PostSquarePageState createState() => _PostSquarePageState();
}

class _PostSquarePageState extends State<PostSquarePage> {
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String? _userAvatarUrl = "";
  final int _pageSize = 10;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _postController = TextEditingController();
  List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  final String _baseUrl = "https://hope.layu.cc/hope";

  // Create an instance of our logging HTTP client
  final LoggingHttpClient _httpClient = LoggingHttpClient();

  @override
  void initState() {
    super.initState();
    developer.log('PostSquarePage initialized', name: 'NetworkDebug');
    _fetchPosts();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _postController.dispose();
    _httpClient.close();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.9 &&
        !_isLoading &&
        _hasMore) {
      _loadMorePosts();
    }
  }

  Future<void> _fetchPosts() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final profile = await UserProfileService.getProfile();
      print(profile);
      _userAvatarUrl = profile?.userAvatar;
      final token = await UserProfileService.getAuthToken();

      final response = await _httpClient.get(
        Uri.parse('$_baseUrl/posts?page=$_currentPage&size=$_pageSize'),
        headers: {
          'Authorization': 'Bearer ${token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        if (responseData['success'] == true) {
          final List<dynamic> newPosts = responseData['data'] ?? [];
          final int totalCount = responseData['total'] ?? 0;

          setState(() {
            if (_currentPage == 1) {
              _posts = List<Map<String, dynamic>>.from(newPosts);
            } else {
              _posts.addAll(List<Map<String, dynamic>>.from(newPosts));
            }

            _hasMore = _posts.length < totalCount;
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
          _showErrorMessage(responseData['message'] ?? 'Failed to load posts');
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        _showErrorMessage('Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorMessage('Error loading posts: $e');
    }
  }

  Future<void> _loadMorePosts() async {
    _currentPage++;
    await _fetchPosts();
  }

  Future<void> _refreshPosts() async {
    setState(() {
      _currentPage = 1;
      _hasMore = true;
    });
    await _fetchPosts();
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();

      if (images.isNotEmpty) {
        // Limit to 9 images maximum
        final newImages = images.length + _selectedImages.length > 9
            ? images.sublist(0, 9 - _selectedImages.length)
            : images;

        setState(() {
          _selectedImages.addAll(newImages);
          if (_selectedImages.length > 9) {
            _selectedImages = _selectedImages.sublist(0, 9);
          }
        });
      }
    } catch (e) {
      _showErrorMessage('Error picking images: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _createPost() async {
    if (_postController.text.trim().isEmpty && _selectedImages.isEmpty) {
      _showErrorMessage('Please enter some text or select at least one image');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/posts'),
      );

      // Add headers
      request.headers.addAll({
        'Authorization': 'Bearer ${UserProfileService.getAuthToken()}',
      });

      // Add text fields
      request.fields['content'] = _postController.text.trim();

      // Add image files
      for (var image in _selectedImages) {
        final bytes = await image.readAsBytes();
        final file = http.MultipartFile.fromBytes(
          'images',
          bytes,
          filename: image.name,
          contentType: MediaType('image', image.name.split('.').last),
        );
        request.files.add(file);
      }

      // Send request using our logging client
      final response = await _httpClient.sendMultipartRequest(request);

      if (response.statusCode == 201) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        if (responseData['success'] == true) {
          // Clear form
          setState(() {
            _postController.clear();
            _selectedImages = [];
          });

          // Refresh posts to show the new one
          _refreshPosts();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Post created successfully')),
          );
        } else {
          setState(() {
            _isLoading = false;
          });
          _showErrorMessage(responseData['message'] ?? 'Failed to create post');
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        _showErrorMessage('Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      developer.log('Error creating post', name: 'NetworkDebug', error: e);
      _showErrorMessage('Error creating post: $e');
    }
  }

  Future<void> _likePost(int postId, int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      final url = _posts[index]['liked']
          ? '$_baseUrl/posts/$postId/unlike'
          : '$_baseUrl/posts/$postId/like';

      final response = await _httpClient.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer ${UserProfileService.getAuthToken()}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        if (responseData['success'] == true) {
          setState(() {
            _posts[index]['liked'] = !_posts[index]['liked'];
            if (_posts[index]['liked']) {
              _posts[index]['like_count']++;
            } else {
              _posts[index]['like_count']--;
            }
          });
        } else {
          _showErrorMessage(
              responseData['message'] ?? 'Failed to update like status');
        }
      } else {
        _showErrorMessage('Server error: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorMessage('Error updating like status: $e');
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showPostOptions(int postId, int index) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.delete),
                title: Text('Delete Post'),
                onTap: () {
                  Navigator.pop(context);
                  _deletePost(postId, index);
                },
              ),
              // Add more options as needed
            ],
          ),
        );
      },
    );
  }

  Future<void> _deletePost(int postId, int index) async {
    try {
      final token = await UserProfileService.getAuthToken();
      final response = await _httpClient.delete(
        Uri.parse('$_baseUrl/posts/$postId'),
        headers: {
          'Authorization': 'Bearer ${token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        if (responseData['success'] == true) {
          setState(() {
            _posts.removeAt(index);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Post deleted successfully')),
          );
        } else {
          _showErrorMessage(responseData['message'] ?? 'Failed to delete post');
        }
      } else {
        _showErrorMessage('Server error: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorMessage('Error deleting post: $e');
    }
  }

  void _viewPostDetail(int postId) {
    // Navigate to post detail page
    // This would be implemented in a separate file
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Post creation card
          Card(
            margin: EdgeInsets.all(8.0),
            child: Padding(
              padding: EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundImage: NetworkImage(_userAvatarUrl ?? ''),
                        radius: 20,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _postController,
                          decoration: InputDecoration(
                            hintText: 'Share your thoughts...',
                            border: InputBorder.none,
                          ),
                          maxLines: 3,
                          minLines: 1,
                        ),
                      ),
                    ],
                  ),
                  if (_selectedImages.isNotEmpty)
                    Container(
                      height: 100,
                      margin: EdgeInsets.only(top: 8),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedImages.length,
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              Container(
                                margin: EdgeInsets.only(right: 8),
                                width: 100,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  image: DecorationImage(
                                    image: FileImage(
                                        File(_selectedImages[index].path)),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 0,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () => _removeImage(index),
                                  child: Container(
                                    padding: EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(Icons.photo_library),
                        onPressed: _pickImages,
                        tooltip: 'Add Images (${_selectedImages.length}/9)',
                      ),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _createPost,
                        child: _isLoading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text('Post'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Post list
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshPosts,
              child: _posts.isEmpty && !_isLoading
                  ? Center(
                      child: Text('No posts yet. Create your first post!'),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _posts.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _posts.length) {
                          return Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        final post = _posts[index];
                        final postId = post['id'];
                        final userInfo = post['user_info'] ?? {};
                        final images = List<Map<String, dynamic>>.from(
                            post['images'] ?? []);

                        return Card(
                          margin: EdgeInsets.symmetric(
                              vertical: 8.0, horizontal: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Post header
                              ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: NetworkImage(
                                    userInfo['user_avatar'] ??
                                        'https://via.placeholder.com/150',
                                  ),
                                ),
                                title: Text(
                                    userInfo['user_nickname'] ?? 'Anonymous'),
                                subtitle: Text(
                                  _formatDate(post['created_at']),
                                  style: TextStyle(fontSize: 12),
                                ),
                                trailing: IconButton(
                                  icon: Icon(Icons.more_vert),
                                  onPressed: () =>
                                      _showPostOptions(postId, index),
                                ),
                              ),

                              // Post content
                              Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 8.0),
                                child: Text(post['content'] ?? ''),
                              ),

                              // Post images
                              if (images.isNotEmpty) _buildImageGallery(images),

                              // Post stats
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16.0),
                                child: Row(
                                  children: [
                                    Text(
                                      '${post['like_count'] ?? 0} likes',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                    SizedBox(width: 16),
                                    Text(
                                      '${post['comment_count'] ?? 0} comments',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                    SizedBox(width: 16),
                                    Text(
                                      '${post['view_count'] ?? 0} views',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),

                              Divider(),

                              // Post actions
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _likePost(postId, index),
                                    icon: Icon(
                                      post['liked'] == true
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: post['liked'] == true
                                          ? Colors.red
                                          : null,
                                    ),
                                    label: Text('Like'),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => _viewPostDetail(postId),
                                    icon: Icon(Icons.comment_outlined),
                                    label: Text('Comment'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGallery(List<Map<String, dynamic>> images) {
    if (images.length == 1) {
      // Single image display
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          _getImageUrl(images[0]['image_path']),
          fit: BoxFit.cover,
        ),
      );
    } else {
      // Grid view for multiple images
      return Container(
        height: 200,
        child: GridView.builder(
          physics: NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: images.length > 2 ? 3 : 2,
            childAspectRatio: 1.0,
            crossAxisSpacing: 2.0,
            mainAxisSpacing: 2.0,
          ),
          itemCount: images.length > 6 ? 6 : images.length,
          itemBuilder: (context, index) {
            return Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  _getImageUrl(images[index]['image_path']),
                  fit: BoxFit.cover,
                ),
                if (index == 5 && images.length > 6)
                  Container(
                    color: Colors.black54,
                    child: Center(
                      child: Text(
                        '+${images.length - 6}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      );
    }
  }

  String _getImageUrl(String path) {
    if (path.startsWith('http')) {
      return path;
    }
    return '$_baseUrl/file/$path';
  }

  String _formatDate(int timestamp) {
    if (timestamp == null) return '';

    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} years ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} months ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }
}
