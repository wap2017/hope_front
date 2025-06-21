import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  Future<http.Response> sendMultipartRequest(
      http.MultipartRequest request) async {
    StringBuffer curlCmd = StringBuffer('curl -X ${request.method}');

    request.headers.forEach((key, value) {
      curlCmd.write(" -H '$key: $value'");
    });

    request.fields.forEach((key, value) {
      curlCmd.write(" -F '$key=$value'");
    });

    for (var file in request.files) {
      curlCmd.write(" -F '${file.field}=@${file.filename}'");
    }

    curlCmd.write(" '${request.url}'");
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
      final token = await UserProfileService.getAuthToken();

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/posts'),
      );

      request.headers.addAll({
        'Authorization': 'Bearer $token',
      });

      request.fields['content'] = _postController.text.trim();

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

      final response = await _httpClient.sendMultipartRequest(request);

      if (response.statusCode == 201) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        if (responseData['success'] == true) {
          setState(() {
            _postController.clear();
            _selectedImages = [];
            _isLoading = false;
          });

          _refreshPosts();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('发布成功'),
              backgroundColor: AppColors.success,
            ),
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
      final token = await UserProfileService.getAuthToken();

      final url = _posts[index]['liked']
          ? '$_baseUrl/posts/$postId/unlike'
          : '$_baseUrl/posts/$postId/like';

      final response = await _httpClient.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
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
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _showPostOptions(int postId, int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(AppDimens.radiusMedium),
              topRight: Radius.circular(AppDimens.radiusMedium),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.textLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.delete, color: AppColors.error),
                  title: Text('删除帖子'),
                  onTap: () {
                    Navigator.pop(context);
                    _deletePost(postId, index);
                  },
                ),
              ],
            ),
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
          'Authorization': 'Bearer $token',
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
            SnackBar(
              content: Text('删除成功'),
              backgroundColor: AppColors.success,
            ),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '社区广场',
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
      body: Column(
        children: [
          // Post creation card
          Container(
            margin: EdgeInsets.all(AppDimens.paddingMedium),
            padding: EdgeInsets.all(AppDimens.paddingMedium),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.accent],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _userAvatarUrl != null &&
                              _userAvatarUrl!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.network(
                                _userAvatarUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Icon(Icons.person,
                                        color: AppColors.textSecondary),
                              ),
                            )
                          : Icon(Icons.person, color: AppColors.textSecondary),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _postController,
                        decoration: InputDecoration(
                          hintText: '分享你的感受和想法...',
                          hintStyle: TextStyle(color: AppColors.textLight),
                          border: InputBorder.none,
                        ),
                        maxLines: 3,
                        minLines: 1,
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
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
                                borderRadius: BorderRadius.circular(
                                    AppDimens.radiusSmall),
                                image: DecorationImage(
                                  image: FileImage(
                                      File(_selectedImages[index].path)),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 12,
                              child: GestureDetector(
                                onTap: () => _removeImage(index),
                                child: Container(
                                  padding: EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withOpacity(0.8),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                SizedBox(height: AppDimens.paddingSmall),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: _pickImages,
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.5),
                          borderRadius:
                              BorderRadius.circular(AppDimens.radiusSmall),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.photo_library,
                              color: AppColors.success,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              '添加图片 (${_selectedImages.length}/9)',
                              style: TextStyle(
                                color: AppColors.success,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _createPost,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimens.radiusSmall),
                        ),
                        elevation: 0,
                        padding:
                            EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              '发布',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Post list
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshPosts,
              color: AppColors.success,
              child: _posts.isEmpty && !_isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: AppColors.textLight,
                          ),
                          SizedBox(height: 16),
                          Text(
                            '还没有帖子\n来分享第一个想法吧',
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
                      controller: _scrollController,
                      padding: EdgeInsets.symmetric(
                          horizontal: AppDimens.paddingMedium),
                      itemCount: _posts.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _posts.length) {
                          return Center(
                            child: Padding(
                              padding: EdgeInsets.all(AppDimens.paddingMedium),
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.success),
                              ),
                            ),
                          );
                        }

                        final post = _posts[index];
                        final postId = post['id'];
                        final userInfo = post['user_info'] ?? {};
                        final images = List<Map<String, dynamic>>.from(
                            post['images'] ?? []);

                        return Container(
                          margin:
                              EdgeInsets.only(bottom: AppDimens.paddingMedium),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(AppDimens.radiusMedium),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Post header
                              Padding(
                                padding:
                                    EdgeInsets.all(AppDimens.paddingMedium),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            AppColors.primary,
                                            AppColors.accent
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: userInfo['user_avatar'] != null &&
                                              userInfo['user_avatar']
                                                  .toString()
                                                  .isNotEmpty
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              child: Image.network(
                                                userInfo['user_avatar'],
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error,
                                                        stackTrace) =>
                                                    Icon(Icons.person,
                                                        color: AppColors
                                                            .textSecondary),
                                              ),
                                            )
                                          : Icon(Icons.person,
                                              color: AppColors.textSecondary),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            userInfo['user_nickname'] ?? '匿名用户',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 16,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          Text(
                                            _formatDate(post['created_at']),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textLight,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.more_horiz,
                                          color: AppColors.textLight),
                                      onPressed: () =>
                                          _showPostOptions(postId, index),
                                    ),
                                  ],
                                ),
                              ),

                              // Post content
                              if (post['content'] != null &&
                                  post['content'].toString().isNotEmpty)
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: AppDimens.paddingMedium),
                                  child: Text(
                                    post['content'],
                                    style: TextStyle(
                                      fontSize: 16,
                                      height: 1.5,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),

                              // Post images
                              if (images.isNotEmpty)
                                Padding(
                                  padding:
                                      EdgeInsets.all(AppDimens.paddingMedium),
                                  child: _buildImageGallery(images),
                                ),

                              // Post stats and actions
                              Padding(
                                padding:
                                    EdgeInsets.all(AppDimens.paddingMedium),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '${post['like_count'] ?? 0} 赞',
                                          style: TextStyle(
                                            color: AppColors.textLight,
                                            fontSize: 14,
                                          ),
                                        ),
                                        SizedBox(width: 16),
                                        Text(
                                          '${post['comment_count'] ?? 0} 评论',
                                          style: TextStyle(
                                            color: AppColors.textLight,
                                            fontSize: 14,
                                          ),
                                        ),
                                        SizedBox(width: 16),
                                        Text(
                                          '${post['view_count'] ?? 0} 浏览',
                                          style: TextStyle(
                                            color: AppColors.textLight,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 12),
                                    Container(
                                      height: 1,
                                      color:
                                          AppColors.textLight.withOpacity(0.1),
                                    ),
                                    SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () =>
                                                _likePost(postId, index),
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: 8),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    post['liked'] == true
                                                        ? Icons.favorite
                                                        : Icons.favorite_border,
                                                    color: post['liked'] == true
                                                        ? AppColors.error
                                                        : AppColors.textLight,
                                                    size: 20,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    '赞',
                                                    style: TextStyle(
                                                      color: post['liked'] ==
                                                              true
                                                          ? AppColors.error
                                                          : AppColors.textLight,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () =>
                                                _viewPostDetail(postId),
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: 8),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.chat_bubble_outline,
                                                    color: AppColors.textLight,
                                                    size: 20,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    '评论',
                                                    style: TextStyle(
                                                      color:
                                                          AppColors.textLight,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
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
          onPressed: _pickImages,
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Icon(
            Icons.add_a_photo,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildImageGallery(List<Map<String, dynamic>> images) {
    if (images.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.network(
            _getImageUrl(images[0]['image_path']),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: AppColors.textLight.withOpacity(0.1),
              child: Icon(Icons.broken_image, color: AppColors.textLight),
            ),
          ),
        ),
      );
    } else {
      return Container(
        height: 200,
        child: GridView.builder(
          physics: NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: images.length > 2 ? 3 : 2,
            childAspectRatio: 1.0,
            crossAxisSpacing: 4.0,
            mainAxisSpacing: 4.0,
          ),
          itemCount: images.length > 6 ? 6 : images.length,
          itemBuilder: (context, index) {
            return Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
                  child: Image.network(
                    _getImageUrl(images[index]['image_path']),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: AppColors.textLight.withOpacity(0.1),
                      child:
                          Icon(Icons.broken_image, color: AppColors.textLight),
                    ),
                  ),
                ),
                if (index == 5 && images.length > 6)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius:
                          BorderRadius.circular(AppDimens.radiusSmall),
                    ),
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

  String _formatDate(int? timestamp) {
    if (timestamp == null) return '';

    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} 年前';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} 个月前';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} 天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} 小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} 分钟前';
    } else {
      return '刚刚';
    }
  }
}
