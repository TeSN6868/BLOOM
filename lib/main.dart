import 'dart:io';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const premiumBlue = Color(0xFF245A78);
const lightBlue = Color(0xFFEAF4F8);
const navy = Color(0xFF18303A);
const softText = Color(0xFF687D88);
const pageBg = Color(0xFFFFFFFF);

const bloomBlue = Color(0xFF245A78);
const bloomGreen = Color(0xFF3F82A3);

const bloomGradient = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [bloomBlue, bloomGreen],
);


void main() => runApp(const BloomApp());

class BloomAlert {
  final String id;
  final String type;
  final String message;
  final DateTime createdAt;
  final bool read;

  const BloomAlert({
    required this.id,
    required this.type,
    required this.message,
    required this.createdAt,
    this.read = false,
  });

  BloomAlert copyWith({
    String? id,
    String? type,
    String? message,
    DateTime? createdAt,
    bool? read,
  }) {
    return BloomAlert(
      id: id ?? this.id,
      type: type ?? this.type,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      read: read ?? this.read,
    );
  }

  String encode() {
    return [
      id,
      type,
      message.replaceAll('|', ' '),
      createdAt.millisecondsSinceEpoch.toString(),
      read ? '1' : '0',
    ].join('|');
  }

  static BloomAlert? decode(String value) {
    final parts = value.split('|');
    if (parts.length < 5) return null;

    return BloomAlert(
      id: parts[0],
      type: parts[1],
      message: parts[2],
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        int.tryParse(parts[3]) ?? 0,
      ),
      read: parts[4] == '1',
    );
  }
}

class BloomAlertStore {
  static const _key = 'bloom_alerts_v1';

  static Future<List<BloomAlert>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];

    return raw.map(BloomAlert.decode).whereType<BloomAlert>().toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static Future<void> save(List<BloomAlert> alerts) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(
      _key,
      alerts.map((alert) => alert.encode()).toList(),
    );
  }

  static Future<void> add(BloomAlert alert) async {
    final alerts = await load();
    alerts.insert(0, alert);

    await save(alerts.take(100).toList());
  }

  static Future<void> markAllRead() async {
    final alerts = await load();

    await save(alerts.map((alert) => alert.copyWith(read: true)).toList());
  }

  static Future<int> unreadCount() async {
    final alerts = await load();
    return alerts.where((alert) => !alert.read).length;
  }
}

class BloomPost {
  final String id;
  final String name;
  String text;
  final String mood;
  final String location;
  final String? imagePath;
  final String? videoPath;
  final String? voicePath;
  final String? listening;
  final DateTime createdAt;
  bool liked;
  bool bookmarked;

  BloomPost({
    required this.id,
    required this.name,
    required this.text,
    required this.mood,
    required this.location,
    this.imagePath,
    this.videoPath,
    this.voicePath,
    this.listening,
    required this.createdAt,
    this.liked = false,
    this.bookmarked = false,
  });

  BloomPost copyWith({
    String? id,
    String? text,
    String? mood,
    String? location,
    String? imagePath,
    String? videoPath,
    String? voicePath,
    String? listening,
    DateTime? createdAt,
    bool? liked,
    bool? bookmarked,
  }) {
    return BloomPost(
      id: id ?? this.id,
      name: name,
      text: text ?? this.text,
      mood: mood ?? this.mood,
      location: location ?? this.location,
      imagePath: imagePath ?? this.imagePath,
      videoPath: videoPath ?? this.videoPath,
      voicePath: voicePath ?? this.voicePath,
      listening: listening ?? this.listening,
      createdAt: createdAt ?? this.createdAt,
      liked: liked ?? this.liked,
      bookmarked: bookmarked ?? this.bookmarked,
    );
  }

  String encode() {
    return [
      id,
      name,
      text.replaceAll('|', ' '),
      mood.replaceAll('|', ' '),
      location.replaceAll('|', ' '),
      imagePath ?? '',
      videoPath ?? '',
      voicePath ?? '',
      listening ?? '',
      createdAt.millisecondsSinceEpoch.toString(),
      liked ? '1' : '0',
      bookmarked ? '1' : '0',
    ].join('|');
  }

  static BloomPost? decode(String value) {
    final parts = value.split('|');

    // Format lama: 9 field.
    if (parts.length == 9) {
      return BloomPost(
        id: parts[0],
        name: parts[1],
        text: parts[2],
        mood: parts[3],
        location: parts[4],
        imagePath: parts[5].isEmpty ? null : parts[5],
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          int.tryParse(parts[6]) ?? 0,
        ),
        liked: parts[7] == '1',
        bookmarked: parts[8] == '1',
      );
    }

    // Format baru: 12 field.
    if (parts.length < 12) return null;

    return BloomPost(
      id: parts[0],
      name: parts[1],
      text: parts[2],
      mood: parts[3],
      location: parts[4],
      imagePath: parts[5].isEmpty ? null : parts[5],
      videoPath: parts[6].isEmpty ? null : parts[6],
      voicePath: parts[7].isEmpty ? null : parts[7],
      listening: parts[8].isEmpty ? null : parts[8],
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        int.tryParse(parts[9]) ?? 0,
      ),
      liked: parts[10] == '1',
      bookmarked: parts[11] == '1',
    );
  }
}

class BloomComment {
  final String id;
  final String postId;
  final String username;
  final String text;
  final DateTime createdAt;

  const BloomComment({
    required this.id,
    required this.postId,
    required this.username,
    required this.text,
    required this.createdAt,
  });

  String encode() {
    return [
      id,
      postId,
      username.replaceAll('|', ' '),
      text.replaceAll('|', ' '),
      createdAt.millisecondsSinceEpoch.toString(),
    ].join('|');
  }

  static BloomComment? decode(String value) {
    final parts = value.split('|');
    if (parts.length < 5) return null;

    return BloomComment(
      id: parts[0],
      postId: parts[1],
      username: parts[2],
      text: parts[3],
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        int.tryParse(parts[4]) ?? 0,
      ),
    );
  }
}

class BloomCommentStore {
  static const _commentsKey = 'bloom_comments_v1';

  static Future<List<BloomComment>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_commentsKey) ?? [];

    return raw.map(BloomComment.decode).whereType<BloomComment>().toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  static Future<void> save(List<BloomComment> comments) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(
      _commentsKey,
      comments.map((comment) => comment.encode()).toList(),
    );
  }

  static Future<List<BloomComment>> forPost(String postId) async {
    final comments = await load();
    return comments.where((comment) => comment.postId == postId).toList();
  }

  static Future<void> add(BloomComment comment) async {
    final comments = await load();
    comments.add(comment);
    await save(comments);
  }
}

class BloomStore {
  static const _postsKey = 'bloom_posts_v1';

  static Future<List<BloomPost>> loadPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_postsKey) ?? [];

    return raw.map(BloomPost.decode).whereType<BloomPost>().toList();
  }

  static Future<void> savePosts(List<BloomPost> posts) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(
      _postsKey,
      posts.map((post) => post.encode()).toList(),
    );
  }

  static Future<void> addPost(BloomPost post) async {
    final posts = await loadPosts();
    posts.insert(0, post);
    await savePosts(posts);
  }

  static Future<void> updatePost(BloomPost post) async {
    final posts = await loadPosts();
    final index = posts.indexWhere((p) => p.id == post.id);

    if (index >= 0) {
      posts[index] = post;
      await savePosts(posts);
    }
  }

  static Future<void> deletePost(String id) async {
    final posts = await loadPosts();
    posts.removeWhere((post) => post.id == id);
    await savePosts(posts);
  }
}

class BloomApi {
  static const String baseUrl = 'https://bloom-api.coolalaga686.workers.dev';

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('bloom_user_id');
    return id != null && id.trim().isNotEmpty;
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('bloom_user_id');

    if (id == null || id.trim().isEmpty) {
      return null;
    }

    return id.trim();
  }

  static Future<String> requireUserId() async {
    final id = await getUserId();

    if (id == null || id.isEmpty) {
      throw Exception('Sesi akun tidak ditemukan. Silakan login kembali.');
    }

    return id;
  }

  static Future<void> saveUserId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bloom_user_id', id);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('bloom_user_id');
  }

  static Future<Map<String, dynamic>> register({
    required String username,
    required String pin,
    String name = '',
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'username': username.trim().toLowerCase(),
            'pin': pin.trim(),
            'name': name.trim(),
          }),
        )
        .timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body);

    if (response.statusCode != 201 || data['ok'] != true) {
      throw Exception(
        'Registrasi gagal: ${data['error'] ?? response.statusCode}',
      );
    }

    final user = Map<String, dynamic>.from(data['user'] as Map);
    final id = '${user['id'] ?? ''}'.trim();

    if (id.isEmpty) {
      throw Exception('Registrasi gagal: user ID kosong.');
    }

    await saveUserId(id);
    return user;
  }

  static Future<Map<String, dynamic>> login({
    required String username,
    required String pin,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'username': username.trim().toLowerCase(),
            'pin': pin.trim(),
          }),
        )
        .timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body);

    if (response.statusCode != 200 || data['ok'] != true) {
      throw Exception('Login gagal: ${data['error'] ?? response.statusCode}');
    }

    final user = Map<String, dynamic>.from(data['user'] as Map);
    final id = '${user['id'] ?? ''}'.trim();

    if (id.isEmpty) {
      throw Exception('Login gagal: user ID kosong.');
    }

    await saveUserId(id);
    return user;
  }

  static Future<List<BloomPost>> loadPosts() async {
    final currentUserId = await requireUserId();

    final uri = Uri.parse(
      '$baseUrl/api/posts?user_id=${Uri.encodeQueryComponent(currentUserId)}',
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Gagal mengambil Moments: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);

    if (data['ok'] != true) {
      throw Exception('API menolak permintaan.');
    }

    final rawPosts = data['posts'];

    if (rawPosts is! List) {
      return [];
    }

    return rawPosts.map<BloomPost>((item) {
      final createdAt = DateTime.fromMillisecondsSinceEpoch(
        int.tryParse('${item['created_at'] ?? 0}') ?? 0,
      );

      final serverLocation = '${item['location'] ?? ''}'.trim();

      final serverActivity = '${item['activity'] ?? ''}'.trim();

      return BloomPost(
        id: '${item['id'] ?? ''}',
        name: 'Ayie',
        text: '${item['text'] ?? ''}',
        mood: serverActivity.isEmpty ? 'New Bloom' : serverActivity,
        location: serverLocation.isEmpty ? 'BLOOM' : serverLocation,
        createdAt: createdAt,
      );
    }).toList();
  }

  static Future<BloomPost> createPost({
    required String text,
    String? location,
    String? activity,
    String mediaUrl = '',
    String mediaType = '',
  }) async {
    final now = DateTime.now();
    final currentUserId = await requireUserId();
    final uri = Uri.parse('$baseUrl/api/posts');

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': currentUserId,
            'text': text,
            'media_url': mediaUrl,
            'media_type': mediaType,
            'location': location ?? '',
            'activity': activity ?? '',
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 201) {
      throw Exception('Gagal membuat Moment: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);

    if (data['ok'] != true || data['post'] == null) {
      throw Exception('API gagal membuat Moment.');
    }

    final item = data['post'];

    final createdAt = DateTime.fromMillisecondsSinceEpoch(
      int.tryParse('${item['created_at'] ?? now.millisecondsSinceEpoch}') ??
          now.millisecondsSinceEpoch,
    );

    return BloomPost(
      id: '${item['id'] ?? ''}',
      name: '${item['name'] ?? ''}'.trim().isEmpty
          ? 'BLOOM'
          : '${item['name']}',
      text: '${item['text'] ?? text}',
      mood: '${item['activity'] ?? activity ?? 'New Bloom'}',
      location: '${item['location'] ?? location ?? 'BLOOM'}',
      createdAt: createdAt,
    );
  }

  static Future<BloomPost> updatePost({
    required String id,
    required String text,
    String? location,
    String? activity,
    String mediaUrl = '',
    String mediaType = '',
  }) async {
    final uri = Uri.parse('$baseUrl/api/posts/${Uri.encodeComponent(id)}');

    final response = await http
        .put(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'text': text,
            'location': location ?? '',
            'activity': activity ?? '',
            'media_url': mediaUrl,
            'media_type': mediaType,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Gagal memperbarui Moment: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);

    if (data['ok'] != true || data['post'] == null) {
      throw Exception('API gagal memperbarui Moment.');
    }

    final item = data['post'];

    return BloomPost(
      id: '${item['id'] ?? id}',
      name: '${item['name'] ?? ''}'.trim().isEmpty
          ? 'BLOOM'
          : '${item['name']}',
      text: '${item['text'] ?? text}',
      mood: '${item['activity'] ?? activity ?? 'New Bloom'}',
      location: '${item['location'] ?? location ?? 'BLOOM'}',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        int.tryParse('${item['created_at'] ?? 0}') ?? 0,
      ),
    );
  }

  static Future<void> deletePost(String id) async {
    final uri = Uri.parse('$baseUrl/api/posts/${Uri.encodeComponent(id)}');

    final response = await http
        .delete(uri)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Gagal menghapus Moment: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);

    if (data['ok'] != true) {
      throw Exception('API gagal menghapus Moment.');
    }
  }
}

class BloomApp extends StatelessWidget {
  const BloomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BLOOM',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: pageBg,
        colorScheme: ColorScheme.fromSeed(seedColor: premiumBlue),
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: navy,
          displayColor: navy,
        ),
      ),
      home: const BloomAuthGate(),
    );
  }
}

class BloomAuthGate extends StatefulWidget {
  const BloomAuthGate({super.key});

  @override
  State<BloomAuthGate> createState() => _BloomAuthGateState();
}

class _BloomAuthGateState extends State<BloomAuthGate> {
  bool loading = true;
  bool loggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final active = await BloomApi.isLoggedIn();

    if (!mounted) return;

    setState(() {
      loggedIn = active;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (loggedIn) {
      return const BloomShell();
    }

    return BloomLoginPage(
      onLoggedIn: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const BloomShell()),
        );
      },
    );
  }
}

class BloomLoginPage extends StatefulWidget {
  final VoidCallback onLoggedIn;

  const BloomLoginPage({super.key, required this.onLoggedIn});

  @override
  State<BloomLoginPage> createState() => _BloomLoginPageState();
}

class _BloomLoginPageState extends State<BloomLoginPage> {
  final usernameController = TextEditingController();
  final pinController = TextEditingController();

  bool loading = false;
  bool obscurePin = true;

  @override
  void dispose() {
    usernameController.dispose();
    pinController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = usernameController.text.trim();
    final pin = pinController.text.trim();

    if (username.isEmpty) {
      _message('Username wajib diisi.');
      return;
    }

    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      _message('PIN harus terdiri dari 6 angka.');
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      await BloomApi.login(username: username, pin: pin);

      if (!mounted) return;

      widget.onLoggedIn();
    } catch (e) {
      if (!mounted) return;

      _message(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _openRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BloomRegisterPage(
          onRegistered: (username, pin) async {
            usernameController.text = username;
            pinController.text = pin;

            if (!mounted) return;

            Navigator.of(context).pop();

            await _login();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: premiumBlue,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.local_florist_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'BLOOM',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                      color: navy,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Masuk ke akun BLOOM',
                    style: TextStyle(color: softText, fontSize: 15),
                  ),

                  const SizedBox(height: 32),

                  TextField(
                    controller: usernameController,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    obscureText: obscurePin,
                    maxLength: 6,
                    onSubmitted: (_) => _login(),
                    decoration: InputDecoration(
                      labelText: 'PIN 6 digit',
                      counterText: '',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            obscurePin = !obscurePin;
                          });
                        },
                        icon: Icon(
                          obscurePin
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: loading ? null : _login,
                      style: FilledButton.styleFrom(
                        backgroundColor: premiumBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'MASUK',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  TextButton(
                    onPressed: loading ? null : _openRegister,
                    child: const Text(
                      'Belum punya akun? Buat Akun',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: navy,
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

class BloomRegisterPage extends StatefulWidget {
  final Future<void> Function(String username, String pin) onRegistered;

  const BloomRegisterPage({super.key, required this.onRegistered});

  @override
  State<BloomRegisterPage> createState() => _BloomRegisterPageState();
}

class _BloomRegisterPageState extends State<BloomRegisterPage> {
  final nameController = TextEditingController();
  final usernameController = TextEditingController();
  final pinController = TextEditingController();
  final confirmPinController = TextEditingController();

  bool loading = false;
  bool obscurePin = true;
  bool obscureConfirm = true;

  @override
  void dispose() {
    nameController.dispose();
    usernameController.dispose();
    pinController.dispose();
    confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name = nameController.text.trim();
    final username = usernameController.text.trim().toLowerCase();
    final pin = pinController.text.trim();
    final confirm = confirmPinController.text.trim();

    if (name.isEmpty) {
      _message('Nama wajib diisi.');
      return;
    }

    if (!RegExp(r'^[a-z0-9_.]{3,30}$').hasMatch(username)) {
      _message(
        'Username 3-30 karakter: huruf kecil, angka, titik atau garis bawah.',
      );
      return;
    }

    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      _message('PIN harus terdiri dari 6 angka.');
      return;
    }

    if (pin != confirm) {
      _message('Konfirmasi PIN tidak sama.');
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      await BloomApi.register(name: name, username: username, pin: pin);

      if (!mounted) return;

      await widget.onRegistered(username, pin);
    } catch (e) {
      if (!mounted) return;

      _message(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  InputDecoration _decoration(
    String label,
    IconData icon, {
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: pageBg,
        elevation: 0,
        leading: IconButton(
          onPressed: loading ? null : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text(
          'Buat Akun',
          style: TextStyle(fontWeight: FontWeight.w800, color: navy),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                const SizedBox(height: 12),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Buat akun BLOOM baru',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: navy,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Akun akan tersimpan di cloud BLOOM.',
                    style: TextStyle(color: softText, fontSize: 14),
                  ),
                ),

                const SizedBox(height: 28),

                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration('Nama', Icons.badge_outlined),
                ),

                const SizedBox(height: 14),

                TextField(
                  controller: usernameController,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration(
                    'Username',
                    Icons.alternate_email_rounded,
                  ),
                ),

                const SizedBox(height: 14),

                TextField(
                  controller: pinController,
                  keyboardType: TextInputType.number,
                  obscureText: obscurePin,
                  maxLength: 6,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration(
                    'PIN 6 digit',
                    Icons.lock_outline_rounded,
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          obscurePin = !obscurePin;
                        });
                      },
                      icon: Icon(
                        obscurePin
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ).copyWith(counterText: ''),
                ),

                const SizedBox(height: 14),

                TextField(
                  controller: confirmPinController,
                  keyboardType: TextInputType.number,
                  obscureText: obscureConfirm,
                  maxLength: 6,
                  onSubmitted: (_) => _register(),
                  decoration: _decoration(
                    'Konfirmasi PIN',
                    Icons.verified_user_outlined,
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          obscureConfirm = !obscureConfirm;
                        });
                      },
                      icon: Icon(
                        obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ).copyWith(counterText: ''),
                ),

                const SizedBox(height: 22),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: loading ? null : _register,
                    style: FilledButton.styleFrom(
                      backgroundColor: premiumBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'DAFTAR AKUN',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 12),

                TextButton(
                  onPressed: loading ? null : () => Navigator.of(context).pop(),
                  child: const Text(
                    'Sudah punya akun? Masuk',
                    style: TextStyle(fontWeight: FontWeight.w700, color: navy),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BloomShell extends StatefulWidget {
  const BloomShell({super.key});

  @override
  State<BloomShell> createState() => _BloomShellState();
}

class _BloomShellState extends State<BloomShell> {
  int index = 0;
  int unreadAlerts = 0;

  final homeKey = GlobalKey<_BloomHomePageState>();

  @override
  void initState() {
    super.initState();
    _loadUnreadAlerts();
  }

  Future<void> _loadUnreadAlerts() async {
    final count = await BloomAlertStore.unreadCount();

    if (!mounted) return;

    setState(() {
      unreadAlerts = count;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      BloomHomePage(key: homeKey),
      const CirclePage(),
      const SizedBox(),
      const NotificationsPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        backgroundColor: Colors.white,
        indicatorColor: lightBlue,
        onDestinationSelected: (i) {
          if (i == 2) {
            showModalBottomSheet(
              context: context,
              showDragHandle: true,
              builder: (_) => CreateBloomSheet(
                onCreate:
                    ({
                      String text = '',
                      XFile? image,
                      XFile? video,
                      String? location,
                      String? voicePath,
                      String? listening,
                    }) async {
                      await homeKey.currentState?._addUnifiedBloom(
                        text: text,
                        image: image,
                        video: video,
                        location: location,
                        voicePath: voicePath,
                        listening: listening,
                      );
                      if (mounted) {
                        setState(() => index = 0);
                      }
                    },
              ),
            );
          } else {
            setState(() => index = i);

            if (i == 3) {
              _loadUnreadAlerts();
            }
          }
        },
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: premiumBlue),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people, color: premiumBlue),
            label: 'Circle',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle, color: premiumBlue),
            label: 'Bloom',
          ),
          NavigationDestination(
            icon: _AlertNavIcon(
              icon: Icons.notifications_none,
              unread: unreadAlerts,
            ),
            selectedIcon: _AlertNavIcon(
              icon: Icons.notifications,
              unread: unreadAlerts,
              selected: true,
            ),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: premiumBlue),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _AlertNavIcon extends StatelessWidget {
  final IconData icon;
  final int unread;
  final bool selected;

  const _AlertNavIcon({
    required this.icon,
    required this.unread,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: selected ? premiumBlue : null),
        if (unread > 0)
          Positioned(
            right: -8,
            top: -6,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: premiumBlue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class BloomHomePage extends StatefulWidget {
  const BloomHomePage({super.key});

  @override
  State<BloomHomePage> createState() => _BloomHomePageState();
}

class _BloomHomePageState extends State<BloomHomePage> {
  List<BloomPost> posts = [];
  XFile? newMedia;

  String? _livingActivity;
  String? _livingDetail;
  static const String _livingActivityKey = 'bloom_living_activity';
  static const String _livingDetailKey = 'bloom_living_detail';

  bool _searching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<BloomPost> get _filteredPosts {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) return posts;

    return posts.where((post) {
      return post.name.toLowerCase().contains(query) ||
          post.text.toLowerCase().contains(query) ||
          post.mood.toLowerCase().contains(query) ||
          post.location.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _selectLivingActivity(String activity) async {
    if (activity == 'Sleep') {
      final isMorning = DateTime.now().hour >= 6 && DateTime.now().hour < 18;

      final detail = isMorning
          ? 'Good morning · waktunya beristirahat?'
          : 'Good night · waktunya tidur';

      setState(() {
        _livingActivity = 'Sleep';
        _livingDetail = detail;
      });

      await _saveLivingActivity('Sleep', detail);
      return;
    }

    final details = <String, List<String>>{
      'Listening': ['Music', 'Podcast', 'Radio', 'Audiobook'],
      'Watching': ['Movie', 'TV', 'Video', 'Series'],
      'Reading': ['Book', 'Article', 'News', 'Magazine'],
    };

    final choices = details[activity] ?? [];

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  activity,
                  style: const TextStyle(
                    color: navy,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              for (final item in choices)
                ListTile(
                  leading: Icon(
                    activity == 'Listening'
                        ? Icons.headphones_rounded
                        : activity == 'Watching'
                        ? Icons.play_circle_outline_rounded
                        : Icons.menu_book_rounded,
                    color: premiumBlue,
                  ),
                  title: Text(item),
                  onTap: () => Navigator.pop(context, item),
                ),
            ],
          ),
        );
      },
    );

    if (!mounted || selected == null) return;

    setState(() {
      _livingActivity = activity;
      _livingDetail = selected;
    });

    await _saveLivingActivity(activity, selected);
  }

  void _openSearch() {
    setState(() {
      _searching = true;
    });
  }

  void _closeSearch() {
    _searchController.clear();

    setState(() {
      _searching = false;
      _searchQuery = '';
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _loadLivingActivity();
  }

  Future<void> _loadLivingActivity() async {
    final prefs = await SharedPreferences.getInstance();

    final activity = prefs.getString(_livingActivityKey);
    final detail = prefs.getString(_livingDetailKey);
    if (!mounted) return;

    setState(() {
      _livingActivity = activity;
      _livingDetail = detail;
    });
  }

  Future<void> _saveLivingActivity(String activity, String? detail) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_livingActivityKey, activity);

    if (detail == null || detail.isEmpty) {
      await prefs.remove(_livingDetailKey);
    } else {
      await prefs.setString(_livingDetailKey, detail);
    }
  }

  Future<void> _loadPosts() async {
    final loaded = await BloomStore.loadPosts();

    if (!mounted) return;

    setState(() {
      posts = loaded;
    });
  }

  Future<void> _addThought(String thought) async {
    final post = BloomPost(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: 'Ayie',
      text: thought.trim(),
      mood: 'Feeling thoughtful',
      location: 'BLOOM',
      createdAt: DateTime.now(),
    );

    try {
      final remotePost = await BloomApi.createPost(text: post.text);

      // Simpan hasil dari server ke lokal sebagai cache.
      await BloomStore.addPost(remotePost);

      debugPrint('[BLOOM API] Moment berhasil dikirim ke D1.');
    } catch (e) {
      // API gagal -> tetap simpan lokal agar Moment tidak hilang.
      await BloomStore.addPost(post);

      debugPrint('[BLOOM API] Gagal kirim Moment ke D1: $e');
    }

    await _loadPosts();
  }

  Future<void> _addUnifiedBloom({
    String text = '',
    XFile? image,
    XFile? video,
    String? location,
    String? voicePath,
    String? listening,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory('${appDir.path}/bloom_media');

    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }

    String? savedImagePath;
    String? savedVideoPath;

    if (image != null) {
      final ext = image.path.contains('.') ? image.path.split('.').last : 'jpg';

      final path =
          '${mediaDir.path}/${DateTime.now().microsecondsSinceEpoch}_image.$ext';

      savedImagePath = (await File(image.path).copy(path)).path;
    }

    if (video != null) {
      final ext = video.path.contains('.') ? video.path.split('.').last : 'mp4';

      final path =
          '${mediaDir.path}/${DateTime.now().microsecondsSinceEpoch}_video.$ext';

      savedVideoPath = (await File(video.path).copy(path)).path;
    }

    final post = BloomPost(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: 'Ayie',
      text: text.trim(),
      mood: listening != null ? 'Listening $listening' : 'New Bloom',
      location: location ?? 'BLOOM',
      imagePath: savedImagePath,
      videoPath: savedVideoPath,
      voicePath: voicePath,
      createdAt: DateTime.now(),
    );

    try {
      final remotePost = await BloomApi.createPost(
        text: post.text,
        location: location,
        activity: listening,
      );

      final syncedPost = post.copyWith(
        id: remotePost.id,
        text: remotePost.text,
        mood: remotePost.mood,
        location: remotePost.location,
        createdAt: remotePost.createdAt,
      );

      await BloomStore.addPost(syncedPost);

      debugPrint(
        '[BLOOM API] Unified Moment + metadata berhasil dikirim ke D1.',
      );
    } catch (e) {
      await BloomStore.addPost(post);

      debugPrint('[BLOOM API] Gagal kirim Unified Moment ke D1: $e');
    }

    await _loadPosts();
  }

  Future<void> _editPost(BloomPost post) async {
    final controller = TextEditingController(text: post.text);

    final edited = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Edit status',
          style: TextStyle(color: navy, fontWeight: FontWeight.w900),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Tulis keterangan status...',
            filled: true,
            fillColor: lightBlue,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: softText)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: premiumBlue),
            onPressed: () {
              Navigator.pop(context, controller.text.trim());
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (edited == null) return;

    try {
      final remotePost = await BloomApi.updatePost(
        id: post.id,
        text: edited,
        location: post.location == 'BLOOM' ? '' : post.location,
        activity: post.mood == 'New Bloom' ? '' : post.mood,
      );

      final updatedPost = post.copyWith(
        text: remotePost.text,
        mood: remotePost.mood,
        location: remotePost.location,
        createdAt: remotePost.createdAt,
      );

      await BloomStore.updatePost(updatedPost);

      debugPrint('[BLOOM API] Moment berhasil diperbarui di D1.');
    } catch (e) {
      debugPrint('[BLOOM API] Gagal update Moment di D1: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Moment gagal diperbarui ke server.')),
      );
    }

    await _loadPosts();
  }

  Future<void> _deletePost(BloomPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Hapus status?',
          style: TextStyle(color: navy, fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'Status ini akan dihapus dari BLOOM.',
          style: TextStyle(color: softText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: softText)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: premiumBlue),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await BloomApi.deletePost(post.id);
      await BloomStore.deletePost(post.id);

      if (!mounted) return;

      setState(() {
        posts.removeWhere((item) => item.id == post.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Status berhasil dihapus.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      debugPrint('[BLOOM API] Moment berhasil dihapus dari D1.');
    } catch (e) {
      debugPrint('[BLOOM API] Gagal menghapus Moment dari D1: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Moment gagal dihapus dari server.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> createThought() async {
    final thought = await showDialog<String>(
      context: context,
      builder: (_) => const ThoughtDialog(),
    );

    if (thought != null && thought.trim().isNotEmpty) {
      await _addThought(thought);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: Colors.white,
          title: _searching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  style: const TextStyle(
                    color: navy,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Cari Moment...',
                    border: InputBorder.none,
                  ),
                )
              : const Text(
                  'BLOOM',
                  style: TextStyle(
                    color: premiumBlue,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
          actions: [
            IconButton(
              tooltip: _searching ? 'Tutup pencarian' : 'Cari Moment',
              onPressed: _searching ? _closeSearch : _openSearch,
              icon: Icon(
                _searching ? Icons.close_rounded : Icons.search_rounded,
                color: navy,
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const Text(
                'Good evening',
                style: TextStyle(color: softText, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Apa kabarmu hari ini?',
                style: TextStyle(
                  color: navy,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 20),

              // BLOOM PREMIUM LIQUID FLOW
              Container(
                height: 112,
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF003B73),
                      Color(0xFF1976D2),
                      Color(0xFFDCEEFF),
                    ],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33003B73),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: BloomFlowPainter(),
                      ),
                    ),
                    const Positioned(
                      left: 20,
                      top: 18,
                      child: Text(
                        'MOMENTS',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const Positioned(
                      left: 20,
                      top: 42,
                      child: Text(
                        'Stay connected.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Positioned(
                      left: 21,
                      top: 75,
                      child: Text(
                        'Without the noise.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const _StoryRow(),
              const SizedBox(height: 20),
              if (_searching && _searchQuery.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(
                    '${_filteredPosts.length} Moment ditemukan',
                    style: const TextStyle(
                      color: softText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (_searching &&
                  _searchQuery.trim().isNotEmpty &&
                  _filteredPosts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: softText,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Moment tidak ditemukan',
                          style: TextStyle(
                            color: navy,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Coba kata kunci lain.',
                          style: TextStyle(color: softText),
                        ),
                      ],
                    ),
                  ),
                ),
              ..._filteredPosts.map(
                (post) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _PostCard(
                    name: post.name,
                    letter: post.name.isNotEmpty ? post.name[0] : 'A',
                    text: post.text,
                    mood: post.mood,
                    location: post.location,
                    imagePath: post.imagePath,
                    videoPath: post.videoPath,
                    voicePath: post.voicePath,
                    listening: post.listening,
                    createdAt: post.createdAt,
                    initiallyLiked: post.liked,
                    initiallyBookmarked: post.bookmarked,
                    onEdit: () => _editPost(post),
                    onDelete: () => _deletePost(post),
                    onLikeChanged: (value) async {
                      post.liked = value;
                      await BloomStore.updatePost(post);
                    },
                    onBookmarkChanged: (value) async {
                      post.bookmarked = value;
                      await BloomStore.updatePost(post);
                    },
                    onComment: () =>
                        _showBloomComments(context, postId: post.id),
                  ),
                ),
              ),
              _PostCard(
                name: 'Ayie',
                letter: 'A',
                text:
                    'Hari ini terasa sederhana, tapi justru hal-hal kecil seperti ini yang ingin aku simpan. ✨',
                mood: 'Feeling peaceful',
                location: 'Bandung',
                createdAt: DateTime(2026, 8, 28, 9, 0),
                onComment: () =>
                    _showBloomComments(context, postId: 'demo-ayie'),
              ),
              const SizedBox(height: 16),
              _PostCard(
                name: 'BLOOM',
                letter: 'B',
                text:
                    'Selamat datang di BLOOM — tempat menyimpan momen yang benar-benar berarti.',
                mood: 'Feeling grateful',
                location: 'BLOOM',
                createdAt: DateTime(2026, 8, 28, 8, 30),
                onComment: () =>
                    _showBloomComments(context, postId: 'demo-bloom'),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _StoryRow extends StatelessWidget {
  const _StoryRow();

  @override
  Widget build(BuildContext context) {
    final names = ['Your Bloom'];

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: names.length,
        separatorBuilder: (_, _) => const SizedBox(width: 15),
        itemBuilder: (_, i) => SizedBox(
          width: 70,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: premiumBlue,
                ),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: lightBlue,
                  child: Text(
                    i == 0 ? '+' : names[i][0],
                    style: const TextStyle(
                      color: premiumBlue,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                names[i],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: navy,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _isVideoFile(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.mp4') ||
      lower.endsWith('.mov') ||
      lower.endsWith('.m4v') ||
      lower.endsWith('.avi') ||
      lower.endsWith('.mkv') ||
      lower.endsWith('.webm');
}

String _formatBloomDateTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year.toString();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');

  return '$day/$month/$year • $hour:$minute';
}

class _PostCard extends StatefulWidget {
  final String name;
  final String letter;
  final String text;
  final String mood;
  final String location;
  final String? imagePath;
  final String? videoPath;
  final String? voicePath;
  final String? listening;
  final DateTime createdAt;
  final bool initiallyLiked;
  final bool initiallyBookmarked;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final ValueChanged<bool>? onLikeChanged;
  final ValueChanged<bool>? onBookmarkChanged;
  final VoidCallback? onComment;

  const _PostCard({
    required this.name,
    required this.letter,
    required this.text,
    required this.mood,
    required this.location,
    this.imagePath,
    this.videoPath,
    this.voicePath,
    this.listening,
    required this.createdAt,
    this.initiallyLiked = false,
    this.initiallyBookmarked = false,
    this.onEdit,
    this.onDelete,
    this.onLikeChanged,
    this.onBookmarkChanged,
    this.onComment,
  });

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  late bool liked;
  late bool bookmarked;
  VideoPlayerController? _videoController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _voicePlaying = false;

  @override
  void initState() {
    super.initState();
    liked = widget.initiallyLiked;
    bookmarked = widget.initiallyBookmarked;

    if (widget.videoPath != null) {
      _videoController = VideoPlayerController.file(File(widget.videoPath!))
        ..initialize().then((_) {
          if (mounted) setState(() {});
        });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _toggleVoice() async {
    final path = widget.voicePath;
    if (path == null) return;

    if (_voicePlaying) {
      await _audioPlayer.stop();
      if (mounted) setState(() => _voicePlaying = false);
      return;
    }

    await _audioPlayer.play(DeviceFileSource(path));

    if (mounted) {
      setState(() => _voicePlaying = true);
    }

    _audioPlayer.onPlayerComplete.first.then((_) {
      if (mounted) setState(() => _voicePlaying = false);
    });
  }

  Future<void> _openLocation() async {
    final value = widget.location.trim();

    if (value.isEmpty || value == 'BLOOM') return;

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(value)}',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .045),
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: premiumBlue,
                child: Text(
                  widget.letter,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      style: const TextStyle(
                        color: navy,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatBloomDateTime(widget.createdAt),
                      style: const TextStyle(
                        color: softText,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                color: Colors.white,
                icon: const Icon(Icons.more_horiz, color: softText),
                onSelected: (value) {
                  if (value == 'edit') {
                    widget.onEdit?.call();
                  } else if (value == 'delete') {
                    widget.onDelete?.call();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, color: premiumBlue),
                        SizedBox(width: 10),
                        Text(
                          'Edit Status',
                          style: TextStyle(
                            color: navy,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: premiumBlue),
                        SizedBox(width: 10),
                        Text(
                          'Hapus Status',
                          style: TextStyle(
                            color: navy,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 15),

          if (widget.text.isNotEmpty)
            Text(
              widget.text,
              style: const TextStyle(
                color: navy,
                fontSize: 15,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),

          if (widget.imagePath != null) ...[
            if (widget.text.isNotEmpty) const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: _isVideoFile(widget.imagePath!)
                  ? (_videoController != null &&
                            _videoController!.value.isInitialized
                        ? AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                VideoPlayer(_videoController!),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (_videoController!.value.isPlaying) {
                                        _videoController!.pause();
                                      } else {
                                        _videoController!.play();
                                      }
                                    });
                                  },
                                  child: Container(
                                    width: 58,
                                    height: 58,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: .55,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _videoController!.value.isPlaying
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                      color: Colors.white,
                                      size: 34,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox(
                            height: 220,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: premiumBlue,
                              ),
                            ),
                          ))
                  : Image.file(
                      File(widget.imagePath!),
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
            ),
          ],

          if (widget.voicePath != null) ...[
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _toggleVoice,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: lightBlue,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      _voicePlaying
                          ? Icons.stop_circle_rounded
                          : Icons.play_circle_fill_rounded,
                      color: premiumBlue,
                      size: 32,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _voicePlaying
                            ? 'Memutar Voice Bloom...'
                            : 'Voice Bloom',
                        style: const TextStyle(
                          color: navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Icon(Icons.graphic_eq_rounded, color: premiumBlue),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          Wrap(
            spacing: 7,
            children: [
              _Pill(widget.mood, Icons.sentiment_satisfied_alt),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _openLocation,
                child: _Pill(
                  widget.location.split('\n').first,
                  Icons.location_on_outlined,
                ),
              ),
            ],
          ),

          if (widget.listening != null) ...[
            const SizedBox(height: 10),
            _Pill('Listening ${widget.listening!}', Icons.music_note_rounded),
          ],

          const Divider(height: 25),

          Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() => liked = !liked);
                  widget.onLikeChanged?.call(liked);
                },
                icon: Icon(
                  liked ? Icons.favorite : Icons.favorite_border,
                  color: liked ? premiumBlue : softText,
                ),
              ),
              IconButton(
                onPressed: widget.onComment,
                tooltip: 'Komentar',
                icon: const Icon(Icons.chat_bubble_outline, color: softText),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.ios_share, color: softText),
              const Spacer(),
              IconButton(
                onPressed: () {
                  setState(() => bookmarked = !bookmarked);
                  widget.onBookmarkChanged?.call(bookmarked);
                },
                icon: Icon(
                  bookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: bookmarked ? premiumBlue : softText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _showBloomComments(
  BuildContext context, {
  required String postId,
}) async {
  final controller = TextEditingController();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (sheetContext) {
      return FutureBuilder<List<BloomComment>>(
        future: BloomCommentStore.forPost(postId),
        builder: (context, snapshot) {
          final comments = snapshot.data ?? [];

          return Padding(
            padding: EdgeInsets.only(
              left: 18,
              right: 18,
              top: 8,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 18,
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Komentar',
                    style: TextStyle(
                      color: navy,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (comments.isNotEmpty)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 260),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: comments.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, index) {
                          final comment = comments[index];

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: lightBlue,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '@${comment.username}',
                                  style: const TextStyle(
                                    color: navy,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  comment.text,
                                  style: const TextStyle(
                                    color: navy,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Text(
                        'Belum ada komentar.',
                        style: TextStyle(color: softText),
                      ),
                    ),

                  const SizedBox(height: 10),

                  TextField(
                    controller: controller,
                    autofocus: true,
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: 'Tulis komentar...',
                      filled: true,
                      fillColor: lightBlue,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final text = controller.text.trim();
                        if (text.isEmpty) return;

                        final prefs = await SharedPreferences.getInstance();

                        final username =
                            prefs.getString('bloom_profile_username') ?? 'ayie';

                        final comment = BloomComment(
                          id: DateTime.now().microsecondsSinceEpoch.toString(),
                          postId: postId,
                          username: username,
                          text: text,
                          createdAt: DateTime.now(),
                        );

                        await BloomCommentStore.add(comment);

                        if (!sheetContext.mounted) return;

                        Navigator.of(sheetContext).pop();

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Komentar berhasil dikirim.'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.send_rounded),
                      label: const Text('Kirim Komentar'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  controller.dispose();
}

class _Pill extends StatelessWidget {
  final String text;
  final IconData icon;

  const _Pill(this.text, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: lightBlue,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: premiumBlue),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: premiumBlue,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final String? activity;
  final String? detail;
  final ValueChanged<String> onActivity;

  const _ActivityCard({this.activity, this.detail, required this.onActivity});

  @override
  Widget build(BuildContext context) {
    final isMorning = DateTime.now().hour >= 6 && DateTime.now().hour < 18;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [bloomBlue, bloomGreen],
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'YOUR DAY',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w900,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            activity == null ? 'Little activities' : activity!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                const Text(
                  'ACTIVE',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              detail!,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Activity(
                Icons.music_note,
                'Listening',
                selected: activity == 'Listening',
                onTap: () => onActivity('Listening'),
              ),
              _Activity(
                Icons.movie_outlined,
                'Watching',
                selected: activity == 'Watching',
                onTap: () => onActivity('Watching'),
              ),
              _Activity(
                Icons.menu_book,
                'Reading',
                selected: activity == 'Reading',
                onTap: () => onActivity('Reading'),
              ),
              _Activity(
                isMorning ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                'Sleep',
                selected: activity == 'Sleep',
                onTap: () => onActivity('Sleep'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Activity extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _Activity(
    this.icon,
    this.text, {
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.22)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(height: 7),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<String?> getBloomLocation() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return null;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    String placeName = '';

    try {
      final geocoding = Geocoding();
      final placemarks = await geocoding.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;

        final parts = <String>[
          if ((p.name ?? '').trim().isNotEmpty) p.name!.trim(),
          if ((p.street ?? '').trim().isNotEmpty) p.street!.trim(),
          if ((p.subLocality ?? '').trim().isNotEmpty) p.subLocality!.trim(),
          if ((p.locality ?? '').trim().isNotEmpty) p.locality!.trim(),
          if ((p.subAdministrativeArea ?? '').trim().isNotEmpty)
            p.subAdministrativeArea!.trim(),
          if ((p.administrativeArea ?? '').trim().isNotEmpty)
            p.administrativeArea!.trim(),
        ];

        placeName = parts.toSet().join(', ');
      }
    } catch (_) {
      // Koordinat tetap dipakai walaupun reverse geocoding gagal.
    }

    final coordinates =
        '${position.latitude.toStringAsFixed(6)}, '
        '${position.longitude.toStringAsFixed(6)}';

    if (placeName.isEmpty) {
      return coordinates;
    }

    return '$placeName\n$coordinates';
  } catch (_) {
    return null;
  }
}

class _BloomLocationMap extends StatelessWidget {
  final String location;

  const _BloomLocationMap({required this.location});

  @override
  Widget build(BuildContext context) {
    final match = RegExp(
      r'(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)',
    ).firstMatch(location);

    if (match == null) {
      return const SizedBox.shrink();
    }

    final latitude = double.tryParse(match.group(1)!);
    final longitude = double.tryParse(match.group(2)!);

    if (latitude == null || longitude == null) {
      return const SizedBox.shrink();
    }

    final point = LatLng(latitude, longitude);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 190,
        child: FlutterMap(
          options: MapOptions(initialCenter: point, initialZoom: 16),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.bloom.app',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: point,
                  width: 52,
                  height: 52,
                  child: Container(
                    decoration: BoxDecoration(
                      color: premiumBlue,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .20),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class BloomVoiceRecorder {
  final AudioRecorder recorder = AudioRecorder();

  Future<String?> start() async {
    if (!await recorder.hasPermission()) {
      return null;
    }

    final dir = await getApplicationDocumentsDirectory();
    final voiceDir = Directory('${dir.path}/bloom_voice');

    if (!await voiceDir.exists()) {
      await voiceDir.create(recursive: true);
    }

    final path =
        '${voiceDir.path}/${DateTime.now().microsecondsSinceEpoch}.m4a';

    await recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );

    return path;
  }

  Future<String?> stop() async {
    return recorder.stop();
  }

  Future<void> dispose() async {
    await recorder.dispose();
  }
}

class CreateBloomSheet extends StatefulWidget {
  final Future<void> Function({
    String text,
    XFile? image,
    XFile? video,
    String? location,
    String? voicePath,
    String? listening,
  })?
  onCreate;

  const CreateBloomSheet({super.key, this.onCreate});

  @override
  State<CreateBloomSheet> createState() => _CreateBloomSheetState();
}

class _CreateBloomSheetState extends State<CreateBloomSheet> {
  final textController = TextEditingController();
  final recorder = BloomVoiceRecorder();

  XFile? image;
  XFile? video;
  String? location;
  String? voicePath;
  String? listening;
  bool recording = false;
  bool publishing = false;

  @override
  void dispose() {
    textController.dispose();
    recorder.dispose();
    super.dispose();
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);

    if (file != null && mounted) {
      setState(() => image = file);
    }
  }

  Future<void> pickVideo() async {
    final picker = ImagePicker();
    final file = await picker.pickVideo(source: ImageSource.gallery);

    if (file != null && mounted) {
      setState(() => video = file);
    }
  }

  Future<void> pickLocation() async {
    final result = await getBloomLocation();

    if (!mounted) return;

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Lokasi belum aktif. Aktifkan GPS dan izin lokasi BLOOM.',
          ),
        ),
      );
      return;
    }

    setState(() => location = result);
  }

  Future<void> toggleVoice() async {
    if (!recording) {
      final path = await recorder.start();

      if (!mounted) return;

      if (path == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Izin mikrofon belum diberikan.')),
        );
        return;
      }

      setState(() {
        recording = true;
        voicePath = path;
      });
      return;
    }

    final path = await recorder.stop();

    if (!mounted) return;

    setState(() {
      recording = false;
      voicePath = path ?? voicePath;
    });
  }

  Future<void> chooseListening() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'Listening',
                style: TextStyle(
                  color: navy,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            for (final item in [
              'Music',
              'Podcast',
              'Radio',
              'Audiobook',
              'Nothing',
            ])
              ListTile(
                leading: const Icon(
                  Icons.music_note_rounded,
                  color: premiumBlue,
                ),
                title: Text(item),
                onTap: () => Navigator.pop(context, item),
              ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        listening = result == 'Nothing' ? null : result;
      });
    }
  }

  Future<void> publish() async {
    if (publishing) return;

    final text = textController.text.trim();

    if (text.isEmpty &&
        image == null &&
        video == null &&
        location == null &&
        voicePath == null &&
        listening == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tambahkan sesuatu sebelum membuat Bloom.'),
        ),
      );
      return;
    }

    setState(() => publishing = true);

    await widget.onCreate?.call(
      text: text,
      image: image,
      video: video,
      location: location,
      voicePath: voicePath,
      listening: listening,
    );

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                'Create a Bloom',
                style: TextStyle(
                  color: navy,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 18),

            TextField(
              controller: textController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Apa yang ingin kamu bagikan hari ini?',
                filled: true,
                fillColor: lightBlue,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 16),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.photo_outlined),
                  label: Text(image == null ? 'Foto' : 'Foto ✓'),
                  onPressed: pickImage,
                ),
                ActionChip(
                  avatar: const Icon(Icons.videocam_outlined),
                  label: Text(video == null ? 'Video' : 'Video ✓'),
                  onPressed: pickVideo,
                ),
                ActionChip(
                  avatar: const Icon(Icons.location_on_outlined),
                  label: Text(location == null ? 'Lokasi' : 'Lokasi ✓'),
                  onPressed: pickLocation,
                ),
                ActionChip(
                  avatar: Icon(
                    recording
                        ? Icons.stop_circle_outlined
                        : Icons.mic_none_rounded,
                  ),
                  label: Text(recording ? 'Stop Voice' : 'Voice'),
                  onPressed: toggleVoice,
                ),
                ActionChip(
                  avatar: const Icon(Icons.music_note_rounded),
                  label: Text(listening == null ? 'Listening' : listening!),
                  onPressed: chooseListening,
                ),
              ],
            ),

            if (image != null) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.file(
                  File(image!.path),
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],

            if (video != null) ...[
              const SizedBox(height: 10),
              const _Pill('Video siap', Icons.videocam_rounded),
            ],

            if (location != null) ...[
              const SizedBox(height: 10),
              _Pill(location!, Icons.location_on_rounded),
              const SizedBox(height: 10),
              _BloomLocationMap(location: location!),
            ],

            if (voicePath != null) ...[
              const SizedBox(height: 10),
              const _Pill('Voice siap', Icons.mic_rounded),
            ],

            if (listening != null) ...[
              const SizedBox(height: 10),
              _Pill(listening!, Icons.music_note_rounded),
            ],

            const SizedBox(height: 22),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: premiumBlue,
                  foregroundColor: Colors.white,
                ),
                onPressed: publishing ? null : publish,
                icon: const Icon(Icons.bubble_chart_rounded),
                label: Text(
                  publishing ? 'MEMBUAT...' : 'POST BLOOM',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ThoughtDialog extends StatefulWidget {
  const ThoughtDialog({super.key});

  @override
  State<ThoughtDialog> createState() => _ThoughtDialogState();
}

class _ThoughtDialogState extends State<ThoughtDialog> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: const Text(
        'What are you thinking?',
        style: TextStyle(color: navy, fontWeight: FontWeight.w900),
      ),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 5,
        decoration: InputDecoration(
          hintText: 'Tulis sesuatu yang berarti...',
          filled: true,
          fillColor: lightBlue,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal', style: TextStyle(color: softText)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: premiumBlue),
          onPressed: () {
            if (controller.text.trim().isEmpty) return;
            Navigator.pop(context, controller.text.trim());
          },
          child: const Text('Bloom'),
        ),
      ],
    );
  }
}

class EditStatusDialog extends StatefulWidget {
  final String initialText;

  const EditStatusDialog({super.key, required this.initialText});

  @override
  State<EditStatusDialog> createState() => _EditStatusDialogState();
}

class _EditStatusDialogState extends State<EditStatusDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: const Text(
        'Edit Status',
        style: TextStyle(color: navy, fontWeight: FontWeight.w900),
      ),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 6,
        decoration: InputDecoration(
          hintText: 'Tulis keterangan status...',
          filled: true,
          fillColor: lightBlue,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal', style: TextStyle(color: softText)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: premiumBlue),
          onPressed: () {
            Navigator.pop(context, controller.text.trim());
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}


class _BloomFeatureHub extends StatefulWidget {
  const _BloomFeatureHub();

  @override
  State<_BloomFeatureHub> createState() => _BloomFeatureHubState();
}

class _BloomFeatureHubState extends State<_BloomFeatureHub>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool opened = false;

  final features = const [
    (
      icon: Icons.music_note_rounded,
      title: 'Music',
      subtitle: 'Your favorite sounds',
    ),
    (
      icon: Icons.photo_library_rounded,
      title: 'Photos',
      subtitle: 'Moments from your Bloom',
    ),
    (
      icon: Icons.videocam_rounded,
      title: 'Videos',
      subtitle: 'Your visual stories',
    ),
    (
      icon: Icons.mic_rounded,
      title: 'Voice',
      subtitle: 'Voice moments',
    ),
    (
      icon: Icons.bookmark_rounded,
      title: 'Saved',
      subtitle: 'Blooms you want to keep',
    ),
    (
      icon: Icons.local_florist_rounded,
      title: 'Garden',
      subtitle: 'Everything growing in your Bloom',
    ),
  ];

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      opened = !opened;
      if (opened) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  void _openFeature(int index) {
    final feature = features[index];

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _SimplePage(
          icon: feature.icon,
          title: feature.title,
          subtitle: feature.subtitle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 270,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          for (int i = 0; i < features.length; i++)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final t = Curves.easeOutBack.transform(_controller.value);

                // Setengah lingkaran di atas tombol BLOOM.
                const positions = [
                  Offset(-120, -175),
                  Offset(-72, -205),
                  Offset(-24, -220),
                  Offset(24, -220),
                  Offset(72, -205),
                  Offset(120, -175),
                ];

                final target = positions[i];

                return Transform.translate(
                  offset: Offset(
                    target.dx * t,
                    target.dy * t,
                  ),
                  child: Opacity(
                    opacity: _controller.value.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 0.75 + (0.25 * t),
                      child: child,
                    ),
                  ),
                );
              },
              child: GestureDetector(
                onTap: () => _openFeature(i),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: premiumBlue,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    features[i].icon,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
              ),
            ),

          GestureDetector(
            onTap: _toggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              width: opened ? 54 : 50,
              height: opened ? 54 : 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: premiumBlue,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: AnimatedRotation(
                turns: opened ? 0.125 : 0,
                duration: const Duration(milliseconds: 260),
                child: Icon(
                  opened
                      ? Icons.close_rounded
                      : Icons.blur_on_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class BloomFlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Motif putih 20%: garis-garis organik yang menyatu
    // di dalam gradasi biru BLOOM.
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paths = [
      (0.98, 0.02, 0.62, 0.20, 0.22, 0.52),
      (1.00, 0.14, 0.66, 0.30, 0.18, 0.62),
      (0.96, 0.28, 0.58, 0.42, 0.12, 0.74),
      (0.90, 0.44, 0.52, 0.58, 0.08, 0.88),
      (0.82, 0.62, 0.46, 0.72, 0.18, 0.98),
    ];

    for (int i = 0; i < paths.length; i++) {
      final p = paths[i];

      paint
        ..color = Colors.white.withValues(
          alpha: 0.20 - (i * 0.018),
        )
        ..strokeWidth = 1.2 + (i * 0.22);

      final path = ui.Path();

      path.moveTo(
        size.width * p.$1,
        size.height * p.$2,
      );

      path.cubicTo(
        size.width * p.$3,
        size.height * (p.$2 + 0.06),
        size.width * p.$4,
        size.height * (p.$5 - 0.08),
        size.width * p.$5,
        size.height * p.$6,
      );

      canvas.drawPath(path, paint);
    }

    // Motif kedua yang lebih halus.
    paint
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1.0;

    for (int i = 0; i < 3; i++) {
      final path = ui.Path();

      path.moveTo(
        size.width * (0.02 + i * 0.04),
        size.height * (0.82 + i * 0.035),
      );

      path.cubicTo(
        size.width * 0.28,
        size.height * (0.52 + i * 0.04),
        size.width * 0.62,
        size.height * (0.86 - i * 0.06),
        size.width * 0.98,
        size.height * (0.24 + i * 0.07),
      );

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant BloomFlowPainter oldDelegate) => false;
}

class _SimplePage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SimplePage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: premiumBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: premiumBlue,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(icon, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: navy,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: softText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CirclePage extends StatelessWidget {
  const CirclePage({super.key});

  @override
  Widget build(BuildContext context) => const _SimplePage(
    icon: Icons.people,
    title: 'Your Circle',
    subtitle: 'Tempat untuk orang-orang yang berarti.',
  );
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<BloomAlert> alerts = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    final loaded = await BloomAlertStore.load();

    if (!mounted) return;

    setState(() {
      alerts = loaded;
      loading = false;
    });
  }

  Future<void> _markAllRead() async {
    await BloomAlertStore.markAllRead();
    await _loadAlerts();
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'like':
        return Icons.favorite_rounded;
      case 'bookmark':
        return Icons.bookmark_rounded;
      case 'bloom':
        return Icons.local_florist_rounded;
      case 'media':
        return Icons.photo_library_rounded;
      case 'voice':
        return Icons.mic_rounded;
      case 'location':
        return Icons.location_on_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _timeLabel(DateTime value) {
    final difference = DateTime.now().difference(value);

    if (difference.inMinutes < 1) return 'Baru saja';
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} menit lalu';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours} jam lalu';
    }
    if (difference.inDays < 7) {
      return '${difference.inDays} hari lalu';
    }

    return '${value.day}/${value.month}/${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    final unread = alerts.where((alert) => !alert.read).length;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Alerts',
          style: TextStyle(color: navy, fontWeight: FontWeight.w900),
        ),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text(
                'Tandai dibaca',
                style: TextStyle(
                  color: premiumBlue,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : alerts.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 58,
                    color: softText,
                  ),
                  SizedBox(height: 14),
                  Text(
                    'Belum ada aktivitas',
                    style: TextStyle(
                      color: navy,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Aktivitas Bloom kamu akan muncul di sini.',
                    style: TextStyle(color: softText),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadAlerts,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: alerts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final alert = alerts[index];

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: alert.read ? Colors.white : lightBlue,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.white,
                          child: Icon(_iconFor(alert.type), color: premiumBlue),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                alert.message,
                                style: const TextStyle(
                                  color: navy,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                _timeLabel(alert.createdAt),
                                style: const TextStyle(
                                  color: softText,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!alert.read)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: CircleAvatar(
                              radius: 4,
                              backgroundColor: premiumBlue,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const _profilePhotoKey = 'bloom_profile_photo';
  static const _backgroundPhotoKey = 'bloom_profile_background';
  static const _nameKey = 'bloom_profile_name';
  static const _usernameKey = 'bloom_profile_username';
  static const _bioKey = 'bloom_profile_bio';

  final ImagePicker _picker = ImagePicker();

  String name = 'Ayie';
  String username = 'ayie';
  String bio = 'Menemukan keindahan dalam hal-hal sederhana. 🌸';

  // Badge verifikasi dari server.
  String verifiedBadge = '';

  int roots = 0;
  int sprouts = 0;
  int branches = 0;
  String myStatus = '';

  String? profilePhotoPath;
  String? backgroundPhotoPath;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadProfileStats();
    _loadMyStatus();
  }

  Future<void> _loadCloudProfile() async {
    try {
      final userId = await BloomApi.requireUserId();

      final response = await http.get(
        Uri.parse(
          '${BloomApi.baseUrl}/api/profile?user_id=${Uri.encodeQueryComponent(userId)}',
        ),
      );

      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body);
      if (data is! Map || data['ok'] != true) return;

      final user = data['user'];
      if (user is! Map) return;

      final prefs = await SharedPreferences.getInstance();

      final cloudName = '${user['name'] ?? ''}'.trim();
      final cloudUsername = '${user['username'] ?? ''}'.trim();
      final cloudBio = '${user['bio'] ?? ''}';
      final cloudPhoto = '${user['photo_url'] ?? ''}'.trim();
      final cloudBackground = '${user['background_url'] ?? ''}'.trim();
      final cloudVerifiedBadge = '${user['verified_badge'] ?? ''}'
          .trim()
          .toLowerCase();

      if (cloudName.isNotEmpty) {
        await prefs.setString(_nameKey, cloudName);
      }

      if (cloudUsername.isNotEmpty) {
        await prefs.setString(_usernameKey, cloudUsername);
      }

      await prefs.setString(_bioKey, cloudBio);

      if (cloudPhoto.isNotEmpty) {
        await prefs.setString(_profilePhotoKey, cloudPhoto);
      }

      if (cloudBackground.isNotEmpty) {
        await prefs.setString(_backgroundPhotoKey, cloudBackground);
      }

      if (!mounted) return;

      setState(() {
        if (cloudName.isNotEmpty) name = cloudName;
        if (cloudUsername.isNotEmpty) username = cloudUsername;
        bio = cloudBio;
        verifiedBadge = cloudVerifiedBadge;

        if (cloudPhoto.isNotEmpty) {
          profilePhotoPath = cloudPhoto;
        }

        if (cloudBackground.isNotEmpty) {
          backgroundPhotoPath = cloudBackground;
        }
      });
    } catch (e) {
      debugPrint('[BLOOM PROFILE] Cloud load failed: $e');
    }
  }

  Future<void> _loadProfileStats() async {
    try {
      final userId = await BloomApi.requireUserId();

      final response = await http.get(
        Uri.parse(
          '${BloomApi.baseUrl}/api/profile/stats?user_id=${Uri.encodeQueryComponent(userId)}',
        ),
      );

      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body);

      if (data is! Map || data['ok'] != true) return;

      final stats = data['stats'];

      if (stats is! Map) return;

      if (!mounted) return;

      setState(() {
        roots = int.tryParse('${stats['roots'] ?? 0}') ?? 0;
        sprouts = int.tryParse('${stats['sprouts'] ?? 0}') ?? 0;
        branches = int.tryParse('${stats['branches'] ?? 0}') ?? 0;
      });
    } catch (e) {
      debugPrint('[BLOOM PROFILE] Stats load failed: $e');
    }
  }

  Future<void> _loadMyStatus() async {
    try {
      final userId = await BloomApi.requireUserId();

      final response = await http.get(
        Uri.parse(
          '${BloomApi.baseUrl}/api/profile/status?user_id=${Uri.encodeQueryComponent(userId)}',
        ),
      );

      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body);

      if (data is! Map || data['ok'] != true) return;

      final status = data['status'];

      if (status is! Map) return;

      if (!mounted) return;

      setState(() {
        myStatus = '${status['text'] ?? ''}';
      });
    } catch (e) {
      debugPrint('[BLOOM PROFILE] Status load failed: $e');
    }
  }

  Future<void> _saveMyStatus(String text) async {
    try {
      final userId = await BloomApi.requireUserId();

      final response = await http.put(
        Uri.parse('${BloomApi.baseUrl}/api/profile/status'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'text': text.trim()}),
      );

      if (response.statusCode != 200) return;

      if (!mounted) return;

      setState(() {
        myStatus = text.trim();
      });
    } catch (e) {
      debugPrint('[BLOOM PROFILE] Status save failed: $e');
    }
  }

  Future<void> _deleteMyStatus() async {
    try {
      final userId = await BloomApi.requireUserId();

      final response = await http.delete(
        Uri.parse(
          '${BloomApi.baseUrl}/api/profile/status?user_id=${Uri.encodeQueryComponent(userId)}',
        ),
      );

      if (response.statusCode != 200) return;

      if (!mounted) return;

      setState(() {
        myStatus = '';
      });
    } catch (e) {
      debugPrint('[BLOOM PROFILE] Status delete failed: $e');
    }
  }

  Future<void> _editMyStatus() async {
    final controller = TextEditingController(text: myStatus);

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Status Saya'),
          content: TextField(
            controller: controller,
            maxLength: 500,
            maxLines: 4,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Apa yang sedang kamu rasakan atau pikirkan?',
            ),
          ),
          actions: [
            if (myStatus.isNotEmpty)
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, '__DELETE__');
                },
                child: const Text('Hapus'),
              ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, controller.text.trim());
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result == null) return;

    if (result == '__DELETE__') {
      await _deleteMyStatus();
      return;
    }

    await _saveMyStatus(result);
  }

  Future<void> _saveCloudProfile() async {
    try {
      final userId = await BloomApi.requireUserId();

      await http.put(
        Uri.parse('${BloomApi.baseUrl}/api/profile'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'name': name,
          'username': username,
          'bio': bio,
          'photo_url': profilePhotoPath ?? '',
          'background_url': backgroundPhotoPath ?? '',
        }),
      );
    } catch (e) {
      debugPrint('[BLOOM PROFILE] Cloud save failed: $e');
    }
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      name = prefs.getString(_nameKey) ?? 'Ayie';
      username = prefs.getString(_usernameKey) ?? 'ayie';
      bio =
          prefs.getString(_bioKey) ??
          'Menemukan keindahan dalam hal-hal sederhana. 🌸';
      profilePhotoPath = prefs.getString(_profilePhotoKey);
      backgroundPhotoPath = prefs.getString(_backgroundPhotoKey);
      verifiedBadge = '';
    });

    await _loadCloudProfile();
    await _loadProfileStats();
    await _loadMyStatus();
  }

  Future<String?> _uploadProfileMedia(XFile file, String type) async {
    try {
      final userId = await BloomApi.getUserId();

      if (userId == null || userId.isEmpty) {
        debugPrint('[BLOOM R2] User ID belum tersedia.');
        return null;
      }

      final bytes = await file.readAsBytes();

      final contentType = switch (file.path.toLowerCase()) {
        final p when p.endsWith('.png') => 'image/png',
        final p when p.endsWith('.webp') => 'image/webp',
        _ => 'image/jpeg',
      };

      final uri = Uri.parse(
        '${BloomApi.baseUrl}/api/media'
        '?user_id=${Uri.encodeQueryComponent(userId)}'
        '&type=${Uri.encodeQueryComponent(type)}',
      );

      final response = await http
          .put(uri, headers: {'content-type': contentType}, body: bytes)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        debugPrint(
          '[BLOOM R2] Upload gagal: '
          '${response.statusCode} ${response.body}',
        );
        return null;
      }

      final data = jsonDecode(response.body);

      if (data is! Map || data['ok'] != true) {
        debugPrint('[BLOOM R2] Response tidak valid.');
        return null;
      }

      final url = '${data['url'] ?? ''}'.trim();

      if (url.isEmpty) {
        debugPrint('[BLOOM R2] URL media kosong.');
        return null;
      }

      debugPrint('[BLOOM R2] Upload berhasil: $url');
      return url;
    } catch (e) {
      debugPrint('[BLOOM R2] Upload error: $e');
      return null;
    }
  }

  Future<void> _pickProfilePhoto() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);

    if (file == null) return;

    final cloudUrl = await _uploadProfileMedia(file, 'profile');

    if (cloudUrl == null || cloudUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto profil gagal diunggah ke server.'),
          ),
        );
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profilePhotoKey, cloudUrl);

    if (!mounted) return;

    setState(() {
      profilePhotoPath = cloudUrl;
    });

    await _saveCloudProfile();
  }

  Future<void> _pickBackgroundPhoto() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);

    if (file == null) return;

    final cloudUrl = await _uploadProfileMedia(file, 'background');

    if (cloudUrl == null || cloudUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Background gagal diunggah ke server.')),
        );
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backgroundPhotoKey, cloudUrl);

    if (!mounted) return;

    setState(() {
      backgroundPhotoPath = cloudUrl;
    });

    await _saveCloudProfile();
  }

  Future<void> _editProfileInfo() async {
    final nameController = TextEditingController(text: name);
    final usernameController = TextEditingController(text: username);
    final bioController = TextEditingController(text: bio);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              10,
              20,
              MediaQuery.of(sheetContext).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      'Edit Your Bloom',
                      style: TextStyle(
                        color: navy,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  const Text(
                    'Nama',
                    style: TextStyle(color: navy, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 7),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: lightBlue,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  const Text(
                    'Username',
                    style: TextStyle(color: navy, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 7),
                  TextField(
                    controller: usernameController,
                    decoration: InputDecoration(
                      prefixText: '@',
                      filled: true,
                      fillColor: lightBlue,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  const Text(
                    'Tentang kamu',
                    style: TextStyle(color: navy, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 7),
                  TextField(
                    controller: bioController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Ceritakan sedikit tentang dirimu...',
                      filled: true,
                      fillColor: lightBlue,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: premiumBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                      ),
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();

                        final newName = nameController.text.trim();
                        final newUsername = usernameController.text.trim();
                        final newBio = bioController.text.trim();

                        final savedName = newName.isEmpty ? 'Ayie' : newName;
                        final savedUsername = newUsername.isEmpty
                            ? 'ayie'
                            : newUsername;
                        final savedBio = newBio.isEmpty
                            ? 'Menemukan keindahan dalam hal-hal sederhana. 🌸'
                            : newBio;

                        await prefs.setString(_nameKey, savedName);
                        await prefs.setString(_usernameKey, savedUsername);
                        await prefs.setString(_bioKey, savedBio);

                        if (!mounted) return;

                        setState(() {
                          name = savedName;
                          username = savedUsername;
                          bio = savedBio;
                        });

                        if (!sheetContext.mounted) return;
                        Navigator.pop(sheetContext);
                      },
                      child: const Text(
                        'Simpan Perubahan',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    nameController.dispose();
    usernameController.dispose();
    bioController.dispose();
  }

  Future<void> _showCustomize() async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Customize Your Bloom',
                  style: TextStyle(
                    color: navy,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 15),

                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: premiumBlue,
                    child: Icon(Icons.person_rounded, color: Colors.white),
                  ),
                  title: const Text(
                    'Foto profil',
                    style: TextStyle(color: navy, fontWeight: FontWeight.w800),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickProfilePhoto();
                  },
                ),

                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: premiumBlue,
                    child: Icon(Icons.image_rounded, color: Colors.white),
                  ),
                  title: const Text(
                    'Background profil',
                    style: TextStyle(color: navy, fontWeight: FontWeight.w800),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickBackgroundPhoto();
                  },
                ),

                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: premiumBlue,
                    child: Icon(Icons.edit_rounded, color: Colors.white),
                  ),
                  title: const Text(
                    'Nama, username & bio',
                    style: TextStyle(color: navy, fontWeight: FontWeight.w800),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _editProfileInfo();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _stat(String value, String label, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: premiumBlue, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: navy,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: softText,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileTile(IconData icon, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.67),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.32),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: premiumBlue,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: softText,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: softText),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasProfilePhoto =
        profilePhotoPath != null && profilePhotoPath!.trim().isNotEmpty;

    final hasBackground =
        backgroundPhotoPath != null && backgroundPhotoPath!.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: pageBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 390,
            pinned: true,
            backgroundColor: premiumBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              IconButton(
                tooltip: 'Customize',
                icon: const Icon(Icons.tune_rounded),
                onPressed: _showCustomize,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasBackground)
                    backgroundPhotoPath!.startsWith('http')
                        ? Image.network(backgroundPhotoPath!, fit: BoxFit.cover)
                        : Image.file(
                            File(backgroundPhotoPath!),
                            fit: BoxFit.cover,
                          )
                  else
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [premiumBlue, navy],
                        ),
                      ),
                    ),

                  // Lapisan gelap agar tombol tetap terlihat.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.45),
                        ],
                      ),
                    ),
                  ),

                  // Tombol ganti background.
                  Positioned(
                    right: 18,
                    bottom: 18,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.42),
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Ganti background',
                        icon: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                        ),
                        onPressed: _pickBackgroundPhoto,
                      ),
                    ),
                  ),

                  // FOTO PROFIL BULAT SEMPURNA.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 18,
                    child: Center(
                      child: GestureDetector(
                        onTap: _pickProfilePhoto,
                        child: Container(
                          width: 126,
                          height: 126,
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.30),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: SizedBox(
                            width: 116,
                            height: 116,
                            child: ClipOval(
                              child: hasProfilePhoto
                                  ? profilePhotoPath!.startsWith('http')
                                        ? Image.network(
                                            profilePhotoPath!,
                                            width: 116,
                                            height: 116,
                                            fit: BoxFit.cover,
                                          )
                                        : Image.file(
                                            File(profilePhotoPath!),
                                            width: 116,
                                            height: 116,
                                            fit: BoxFit.cover,
                                          )
                                  : Container(
                                      color: lightBlue,
                                      child: const Icon(
                                        Icons.person_rounded,
                                        color: premiumBlue,
                                        size: 64,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Stack(
              children: [
                if (hasBackground)
                  Positioned.fill(
                    child: backgroundPhotoPath!.startsWith('http')
                        ? Image.network(backgroundPhotoPath!, fit: BoxFit.cover)
                        : Image.file(
                            File(backgroundPhotoPath!),
                            fit: BoxFit.cover,
                          ),
                  )
                else
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [premiumBlue, navy],
                        ),
                      ),
                    ),
                  ),

                Positioned.fill(
                  child: Container(color: Colors.white.withValues(alpha: 0.18)),
                ),

                Column(
                  children: [
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: navy,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),

                        // BLOOM PLATINUM GOLD — compact premium badge.
                        // Status berasal dari server/D1.
                        if (verifiedBadge == 'platinum_gold') ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 19,
                            height: 19,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFFFFE7A0),
                                  Color(0xFFD4AF37),
                                  Color(0xFFA87808),
                                ],
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x66D4AF37),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                                BoxShadow(
                                  color: Color(0x55B8860B),
                                  blurRadius: 4,
                                  spreadRadius: 0.5,
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 25,
                                  height: 25,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0x66FFD966),
                                      width: 1,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.check_rounded,
                                  size: 11,
                                  color: Color(0xFFFFFCF2),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 2),

                    Text(
                      '@$username',
                      style: const TextStyle(
                        color: premiumBlue,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Text(
                        bio,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: softText,
                          fontSize: 14,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 17,
                          horizontal: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.67),
                          borderRadius: BorderRadius.circular(23),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.32),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            _stat('$roots', 'ROOTS', Icons.fingerprint_rounded),
                            _stat('$sprouts', 'SPROUTS', Icons.spa_rounded),
                            _stat(
                              '$branches',
                              'BRANCHES',
                              Icons.account_tree_rounded,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // =========================
                    // BLOOM STATUS SAYA
                    // =========================
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GestureDetector(
                        onTap: _editMyStatus,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.67),
                            borderRadius: BorderRadius.circular(21),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: premiumBlue.withValues(alpha: 0.12),
                                ),
                                child: const Icon(
                                  Icons.auto_awesome_rounded,
                                  color: premiumBlue,
                                  size: 21,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'STATUS SAYA',
                                      style: TextStyle(
                                        color: navy,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      myStatus.isEmpty
                                          ? 'Bagikan apa yang sedang kamu rasakan...'
                                          : myStatus,
                                      maxLines: 4,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: myStatus.isEmpty
                                            ? softText
                                            : navy,
                                        fontSize: 14,
                                        height: 1.4,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                myStatus.isEmpty
                                    ? Icons.add_rounded
                                    : Icons.edit_rounded,
                                color: premiumBlue,
                                size: 21,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    const SizedBox(height: 8),

                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: _BloomFeatureHub(),
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
