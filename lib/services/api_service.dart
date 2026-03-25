import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/user_model.dart' as app_models;
import '../models/post_model.dart';
import '../models/meetup_model.dart';
import '../models/job_model.dart';
import '../models/marketplace_model.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import '../models/notification_model.dart';
import '../models/comment_model.dart';

import '../models/question_model.dart';
import '../models/answer_model.dart';
import '../services/auth_service.dart';

class ApiService extends ChangeNotifier {
  static const String baseUrl = 'http://localhost:8080';
  final AuthService _authService;
  // 백엔드에 아직 없는 엔드포인트를 콜하지 않도록 제어
  static const bool _skipUnimplementedApis = true;

  ApiService(this._authService);

  Map<String, String> get _authHeaders => _authService.authHeaders;
  String? get currentUserId => _authService.currentUser?.id;

  /// USERS
  Future<app_models.User?> getCurrentUser() async {
    // 백엔드에 /users/me 없음 → AuthService에 저장된 사용자 정보 반환
    return _authService.currentUser;
  }

  /// POSTS
  Future<List<Post>> fetchPosts() async {
    if (_skipUnimplementedApis) return [];
    final res = await http.get(Uri.parse('$baseUrl/posts'), headers: _authHeaders);
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => Post.fromJson(e)).toList();
    }
    return [];
  }

  Future<Post?> fetchPost(String id) async {
    if (_skipUnimplementedApis) return null;
    final res = await http.get(Uri.parse('$baseUrl/posts/$id'), headers: _authHeaders);
    if (res.statusCode == 200) return Post.fromJson(jsonDecode(res.body));
    return null;
  }

  Future<void> createPost(Post post) async {
    await http.post(
      Uri.parse('$baseUrl/posts'),
      headers: _authHeaders,
      body: jsonEncode(post.toJson()),
    );
  }

  Future<void> updatePost(String id, Map<String, dynamic> body) async {
    await http.patch(Uri.parse('$baseUrl/posts/$id'), headers: _authHeaders, body: jsonEncode(body));
  }

  Future<void> deletePost(String id) async {
    await http.delete(Uri.parse('$baseUrl/posts/$id'), headers: _authHeaders);
  }

  /// QUESTIONS (Q&A)
  Future<List<Question>> fetchQuestions() async {
    if (_skipUnimplementedApis) return [];
    final res = await http.get(Uri.parse('$baseUrl/questions'), headers: _authHeaders);
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => Question.fromJson(e)).toList();
    }
    return [];
  }

  Future<void> createQuestion(Question q) async {
    await http.post(Uri.parse('$baseUrl/questions'), headers: _authHeaders, body: jsonEncode(q.toJson()));
  }

  Future<void> updateQuestion(String id, Map<String, dynamic> body) async {
    await http.patch(Uri.parse('$baseUrl/questions/$id'), headers: _authHeaders, body: jsonEncode(body));
  }

  Future<void> deleteQuestion(String id) async {
    await http.delete(Uri.parse('$baseUrl/questions/$id'), headers: _authHeaders);
  }

  /// MEETUPS
  Future<List<Meetup>> fetchMeetups() async {
    if (_skipUnimplementedApis) return [];
    final res = await http.get(Uri.parse('$baseUrl/meetups'), headers: _authHeaders);
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => Meetup.fromJson(e)).toList();
    }
    return [];
  }

  Future<Meetup?> fetchMeetup(String id) async {
    if (_skipUnimplementedApis) return null;
    final res = await http.get(Uri.parse('$baseUrl/meetups/$id'), headers: _authHeaders);
    if (res.statusCode == 200) return Meetup.fromJson(jsonDecode(res.body));
    return null;
  }

  Future<void> createMeetup(Meetup meetup) async {
    await http.post(Uri.parse('$baseUrl/meetups'), headers: _authHeaders, body: jsonEncode(meetup.toJson()));
  }

  Future<void> updateMeetup(String id, Map<String, dynamic> body) async {
    await http.patch(Uri.parse('$baseUrl/meetups/$id'), headers: _authHeaders, body: jsonEncode(body));
  }

  Future<void> deleteMeetup(String id) async {
    await http.delete(Uri.parse('$baseUrl/meetups/$id'), headers: _authHeaders);
  }

  /// JOBS
  Future<List<Job>> fetchJobs() async {
    if (_skipUnimplementedApis) return [];
    final res = await http.get(Uri.parse('$baseUrl/jobs'), headers: _authHeaders);
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => Job.fromJson(e)).toList();
    }
    return [];
  }

  Future<void> createJob(Job job) async {
    await http.post(Uri.parse('$baseUrl/jobs'), headers: _authHeaders, body: jsonEncode(job.toJson()));
  }

  Future<void> updateJob(String id, Map<String, dynamic> body) async {
    await http.patch(Uri.parse('$baseUrl/jobs/$id'), headers: _authHeaders, body: jsonEncode(body));
  }

  Future<void> deleteJob(String id) async {
    await http.delete(Uri.parse('$baseUrl/jobs/$id'), headers: _authHeaders);
  }

  /// MARKETPLACE
  Future<List<MarketplaceItem>> fetchMarketplace() async {
    if (_skipUnimplementedApis) return [];
    final res = await http.get(Uri.parse('$baseUrl/marketplace'), headers: _authHeaders);
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => MarketplaceItem.fromJson(e)).toList();
    }
    return [];
  }

  Future<void> createMarketplaceItem(MarketplaceItem item) async {
    await http.post(Uri.parse('$baseUrl/marketplace'), headers: _authHeaders, body: jsonEncode(item.toJson()));
  }

  Future<void> updateMarketplaceItem(String id, Map<String, dynamic> body) async {
    await http.patch(Uri.parse('$baseUrl/marketplace/$id'), headers: _authHeaders, body: jsonEncode(body));
  }

  Future<void> deleteMarketplaceItem(String id) async {
    await http.delete(Uri.parse('$baseUrl/marketplace/$id'), headers: _authHeaders);
  }

  /// CONVERSATIONS & MESSAGES
  Future<List<Conversation>> fetchConversations() async {
    if (_skipUnimplementedApis) return [];
    final res = await http.get(Uri.parse('$baseUrl/conversations'), headers: _authHeaders);
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => Conversation.fromJson(e)).toList();
    }
    return [];
  }

  Future<List<Message>> fetchMessages(String conversationId) async {
    if (_skipUnimplementedApis) return [];
    final res = await http.get(Uri.parse('$baseUrl/conversations/$conversationId/messages'), headers: _authHeaders);
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => Message.fromJson(e)).toList();
    }
    return [];
  }

  Future<void> sendMessage(String conversationId, Message msg) async {
    await http.post(
      Uri.parse('$baseUrl/conversations/$conversationId/messages'),
      headers: _authHeaders,
      body: jsonEncode(msg.toJson()),
    );
  }

  /// NOTIFICATIONS
  Future<List<NotificationModel>> fetchNotifications() async {
    if (_skipUnimplementedApis) return [];
    final res = await http.get(Uri.parse('$baseUrl/notifications'), headers: _authHeaders);
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => NotificationModel.fromJson(e)).toList();
    }
    return [];
  }

  // --------- Compatibility helpers for existing UI (placeholders / simple wrappers) ---------

  // Counts
  Stream<int> getTotalUnreadMessageCount() => Stream.value(0);
  Stream<int> getUnreadNotificationCount() => Stream.value(0);

  // Users
  Future<app_models.User?> getUserById(String userId) async {
    final res = await http.get(Uri.parse('$baseUrl/users/$userId'), headers: _authHeaders);
    if (res.statusCode == 200) return app_models.User.fromJson(jsonDecode(res.body));
    return null;
  }

  Stream<app_models.User?> getUserStream(String userId) =>
      Stream.fromFuture(getUserById(userId));

  Future<void> updateUserProfile({
    required String name,
    String bio = '',
    String nationality = '',
    String avatarUrl = '',
    int? age,
    String personalInfo = '',
    String instagramId = '',
  }) async {
    await http.patch(
      Uri.parse('$baseUrl/users/me'),
      headers: _authHeaders,
      body: jsonEncode({
        'name': name,
        'bio': bio,
        'nationality': nationality,
        'avatarUrl': avatarUrl,
        'age': age,
        'personalInfo': personalInfo,
        'instagramId': instagramId,
      }),
    );
  }

  // Feed / Posts
  Stream<List<Post>> getFeed() => Stream.fromFuture(fetchPosts());
  Stream<Post?> getPostStream(String id) => Stream.fromFuture(fetchPost(id));
  Future<void> addPost(
    String title,
    String content,
    String authorId,
    String authorName, {
    String? imageUrl,
    String category = 'general',
    String authorAvatar = '',
    String? subCategory,
    DateTime? eventDate,
  }) async {
    final post = Post(
      id: '',
      authorId: authorId,
      authorName: authorName,
      title: title,
      content: content,
      timestamp: DateTime.now(),
      imageUrl: imageUrl ?? '',
      category: category,
      authorAvatar: authorAvatar,
      subCategory: subCategory,
      eventDate: eventDate,
    );
    await createPost(post);
  }

  Future<void> toggleLikePost(String postId) async {}
  Future<void> toggleScrapPost(String postId) async {}

  // Comments
  Stream<List<Comment>> getComments(String postId) => Stream.value([]);
  Future<void> addComment(
    String postId,
    String content, {
    String? replyToCommentId,
    String? replyToCommentText,
    String? replyToCommentAuthor,
  }) async {}
  Future<void> deleteComment(String postId, String commentId) async {}
  Future<void> toggleCommentReaction({
    required String postId,
    required String commentId,
    required String emoji,
  }) async {}

  // Q&A search helpers
  Future<List<Post>> searchPosts(String q) async =>
      (await fetchPosts()).where((p) => p.title.toLowerCase().contains(q.toLowerCase())).toList();
  Future<List<Meetup>> searchMeetups(String q) async =>
      (await fetchMeetups()).where((m) => m.title.toLowerCase().contains(q.toLowerCase())).toList();
  Future<List<Question>> searchQuestions(String q) async =>
      (await fetchQuestions()).where((x) => x.title.toLowerCase().contains(q.toLowerCase())).toList();
  Future<List<Job>> searchJobs(String q) async =>
      (await fetchJobs()).where((x) => x.title.toLowerCase().contains(q.toLowerCase())).toList();
  Future<List<MarketplaceItem>> searchMarketplace(String q) async =>
      (await fetchMarketplace()).where((x) => x.title.toLowerCase().contains(q.toLowerCase())).toList();

  // Meetups
  Stream<List<Meetup>> getMeetups() => Stream.fromFuture(fetchMeetups());
  Stream<Meetup> getMeetup(String id) =>
      Stream.fromFuture(fetchMeetup(id)).where((m) => m != null).cast<Meetup>();
  Future<void> addMeetup(Meetup m) => createMeetup(m);
  Future<void> toggleLikeMeetup(String meetupId) async {}
  Future<void> toggleScrapMeetup(String meetupId) async {}
  Future<void> leaveMeetup(String meetupId) async {}
  Future<bool> joinMeetup(String meetupId) async => true;
  Future<void> acceptMeetupParticipant(String meetupId, String userId) async {}
  Future<void> declineMeetupParticipant(String meetupId, String userId) async {}
  Future<void> kickMeetupParticipant(String meetupId, String userId) async {}
  Stream<List<Meetup>> getJoinedMeetups(String userId) => Stream.value([]);
  Future<void> addMeetupComment(String meetupId, String content) async {}
  Stream<List<Comment>> getMeetupComments(String meetupId) => Stream.value([]);
  Future<void> sendMeetupMessage(
    String meetupId,
    String content, {
    String? replyToMessageId,
    String? replyToMessageText,
    String? replyToMessageSender,
  }) async {}
  Stream<List<Message>> getMeetupMessages(String meetupId) => Stream.value([]);

  // Chats
  Stream<List<Conversation>> getConversations() => Stream.fromFuture(fetchConversations());
  Future<String> getOrCreateConversation(String otherUserId) async => '';
  Future<String> startConversation(String otherUserId) async =>
      getOrCreateConversation(otherUserId);
  Future<void> leaveConversation(String conversationId) async {}
  Stream<List<Message>> getChatMessages(String conversationId) =>
      Stream.fromFuture(fetchMessages(conversationId));
  Future<void> sendDirectMessage(
    String conversationId,
    String content, {
    String? sharedPostId,
    String? sharedPostType,
    String? sharedPostTitle,
    String? sharedPostDescription,
    String? replyToMessageId,
    String? replyToMessageText,
    String? replyToMessageSender,
  }) async {}
  Future<void> markConversationAsRead(String conversationId) async {}
  Future<void> toggleMessageReaction({
    required String conversationId,
    required String messageId,
    required String emoji,
  }) async {}

  // Notifications
  Stream<List<NotificationModel>> getNotifications() =>
      Stream.fromFuture(fetchNotifications());
  Future<void> deleteAllNotifications() async {}
  Future<void> deleteNotification(String id) async {}
  Future<void> markNotificationAsRead(String id) async {}

  // Jobs/Marketplace streams
  Stream<List<Job>> getJobs() => Stream.fromFuture(fetchJobs());
  Stream<List<MarketplaceItem>> getMarketplaceItems() =>
      Stream.fromFuture(fetchMarketplace());
  Future<void> addJob(Job job) => createJob(job);
  Future<void> addMarketplaceItem(MarketplaceItem item) => createMarketplaceItem(item);

  // Followers
  Stream<List<app_models.User>> getFollowers(String userId) => Stream.value([]);
  Stream<List<app_models.User>> getFollowing(String userId) => Stream.value([]);
  Future<void> followUser(String userId) async {}
  Future<void> unfollowUser(String userId) async {}

  // Profile data
  Stream<List<Post>> getUserPosts(String userId) => Stream.value([]);
  Stream<List<Job>> getUserJobs(String userId) => Stream.value([]);
  Stream<List<MarketplaceItem>> getUserMarketplaceItems(String userId) => Stream.value([]);
  Stream<List<Post>> getScrappedFeed(String userId) => Stream.value([]);

  // Misc
  Future<String?> getUserNicknameByEmail(String email) async => null;
  Future<void> resetAppData() async {}
}

// 임시 호환용
typedef FirestoreService = ApiService;
