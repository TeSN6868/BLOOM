import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const premiumBlue = Color(0xFFC56A4A);
const lightBlue = Color(0xFFF8EDE8);
const navy = Color(0xFF243044);
const softText = Color(0xFF718096);
const pageBg = Color(0xFFF7F9FC);

void main() => runApp(const BloomApp());

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
    String? text,
    String? mood,
    String? location,
    String? imagePath,
    String? videoPath,
    String? voicePath,
    String? listening,
    bool? liked,
    bool? bookmarked,
  }) {
    return BloomPost(
      id: id,
      name: name,
      text: text ?? this.text,
      mood: mood ?? this.mood,
      location: location ?? this.location,
      imagePath: imagePath ?? this.imagePath,
      videoPath: videoPath ?? this.videoPath,
      voicePath: voicePath ?? this.voicePath,
      listening: listening ?? this.listening,
      createdAt: createdAt,
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

  static const String userId = 'ayie';

  static Future<List<BloomPost>> loadPosts() async {
    final uri = Uri.parse(
      '$baseUrl/api/posts?user_id=${Uri.encodeQueryComponent(userId)}',
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

      return BloomPost(
        id: '${item['id'] ?? ''}',
        name: 'Ayie',
        text: '${item['text'] ?? ''}',
        mood: 'New Bloom',
        location: 'BLOOM',
        createdAt: createdAt,
      );
    }).toList();
  }

  static Future<BloomPost> createPost({required String text}) async {
    final now = DateTime.now();
    final uri = Uri.parse('$baseUrl/api/posts');

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': userId,
            'text': text,
            'media_url': '',
            'media_type': '',
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

    return BloomPost(
      id: '${item['id']}',
      name: 'Ayie',
      text: '${item['text'] ?? text}',
      mood: 'Feeling thoughtful',
      location: 'BLOOM',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        int.tryParse('${item['created_at'] ?? now.millisecondsSinceEpoch}') ??
            now.millisecondsSinceEpoch,
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
      home: const BloomShell(),
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

  final homeKey = GlobalKey<_BloomHomePageState>();

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
          }
        },
        destinations: const [
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
            icon: Icon(Icons.notifications_none),
            selectedIcon: Icon(Icons.notifications, color: premiumBlue),
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

class BloomHomePage extends StatefulWidget {
  const BloomHomePage({super.key});

  @override
  State<BloomHomePage> createState() => _BloomHomePageState();
}

class _BloomHomePageState extends State<BloomHomePage> {
  List<BloomPost> posts = [];
  XFile? newMedia;

  @override
  void initState() {
    super.initState();
    _loadPosts();
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
      final remotePost = await BloomApi.createPost(text: post.text);

      // Simpan hasil server sebagai cache lokal.
      await BloomStore.addPost(post.copyWith(text: remotePost.text));

      debugPrint('[BLOOM API] Unified Moment berhasil dikirim ke D1.');
    } catch (e) {
      // API gagal -> tetap simpan lokal agar Moment tidak hilang.
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

    post.text = edited;
    await BloomStore.updatePost(post);
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
        const SliverAppBar(
          pinned: true,
          backgroundColor: Colors.white,
          title: Text(
            'BLOOM',
            style: TextStyle(
              color: premiumBlue,
              fontSize: 25,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          actions: [
            Icon(Icons.search_rounded, color: navy),
            SizedBox(width: 18),
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
              const SizedBox(height: 14),
              const SizedBox(height: 26),
              const _ActivityCard(),
              const SizedBox(height: 18),
              const Text(
                'Moments',
                style: TextStyle(
                  color: navy,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              const _StoryRow(),
              const SizedBox(height: 20),
              ...posts.map(
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

  const months = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  final day = local.day.toString().padLeft(2, '0');
  final month = months[local.month - 1];
  final year = local.year;
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');

  return '$day $month $year • $hour:$minute';
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
                child: _Pill(widget.location, Icons.location_on_outlined),
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
              const Icon(Icons.chat_bubble_outline, color: softText),
              const SizedBox(width: 20),
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
  const _ActivityCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [premiumBlue, Color(0xFF4C8DF6)],
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR DAY',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w900,
              fontSize: 11,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Little activities',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Activity(Icons.music_note, 'Listening'),
              _Activity(Icons.movie_outlined, 'Watching'),
              _Activity(Icons.menu_book, 'Reading'),
              _Activity(Icons.bedtime, 'Sleep'),
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

  const _Activity(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Column(
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
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
      ),
    );

    return '${position.latitude.toStringAsFixed(6)}, '
        '${position.longitude.toStringAsFixed(6)}';
  } catch (_) {
    return null;
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

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) => const _SimplePage(
    icon: Icons.notifications,
    title: 'Alerts',
    subtitle: 'Aktivitas terbaru di BLOOM.',
  );
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

  String? profilePhotoPath;
  String? backgroundPhotoPath;

  @override
  void initState() {
    super.initState();
    _loadProfile();
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
    });
  }

  Future<String> _savePhoto(XFile file, String prefix) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/bloom_profile');

    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    final extension = file.path.contains('.')
        ? file.path.split('.').last
        : 'jpg';

    final path =
        '${folder.path}/${prefix}_${DateTime.now().microsecondsSinceEpoch}.$extension';

    return (await File(file.path).copy(path)).path;
  }

  Future<void> _pickProfilePhoto() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);

    if (file == null) return;

    final path = await _savePhoto(file, 'profile');
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_profilePhotoKey, path);

    if (!mounted) return;

    setState(() {
      profilePhotoPath = path;
    });
  }

  Future<void> _pickBackgroundPhoto() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);

    if (file == null) return;

    final path = await _savePhoto(file, 'background');
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_backgroundPhotoKey, path);

    if (!mounted) return;

    setState(() {
      backgroundPhotoPath = path;
    });
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
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
        profilePhotoPath != null && File(profilePhotoPath!).existsSync();

    final hasBackground =
        backgroundPhotoPath != null && File(backgroundPhotoPath!).existsSync();

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
                    Image.file(File(backgroundPhotoPath!), fit: BoxFit.cover)
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
                    bottom: -1,
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
                          child: ClipOval(
                            child: hasProfilePhoto
                                ? Image.file(
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
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 12),

                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: navy,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(23),
                    ),
                    child: Row(
                      children: [
                        _stat('12', 'Blooms', Icons.local_florist_rounded),
                        _stat('128', 'Roots', Icons.people_alt_rounded),
                        _stat('64', 'Branches', Icons.account_tree_rounded),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _profileTile(
                        Icons.music_note_rounded,
                        'Music',
                        'Your favorite sounds',
                      ),
                      _profileTile(
                        Icons.photo_library_rounded,
                        'Photos',
                        'Moments from your Bloom',
                      ),
                      _profileTile(
                        Icons.videocam_rounded,
                        'Videos',
                        'Your visual stories',
                      ),
                      _profileTile(Icons.mic_rounded, 'Voice', 'Voice moments'),
                      _profileTile(
                        Icons.bookmark_rounded,
                        'Saved',
                        'Blooms you want to keep',
                      ),
                      _profileTile(
                        Icons.local_florist_rounded,
                        'Garden',
                        'Everything growing in your Bloom',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
