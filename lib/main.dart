import 'package:flutter/material.dart';

const premiumBlue = Color(0xFFC56A4A);
const lightBlue = Color(0xFFF8EDE8);
const navy = Color(0xFF243044);
const softText = Color(0xFF718096);
const pageBg = Color(0xFFF7F9FC);

void main() => runApp(const BloomApp());

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

  @override
  Widget build(BuildContext context) {
    final pages = [
      const BloomHomePage(),
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
              builder: (_) => const CreateBloomSheet(),
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

class BloomHomePage extends StatelessWidget {
  const BloomHomePage({super.key});

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
              GestureDetector(
                onTap: () => showModalBottomSheet(
                  context: context,
                  showDragHandle: true,
                  builder: (_) => const CreateBloomSheet(),
                ),
                child: const _PremiumCard(
                  icon: Icons.add_rounded,
                  title: 'Create a Bloom',
                  subtitle: 'Bagikan sesuatu yang berarti hari ini',
                ),
              ),
              const SizedBox(height: 26),
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
              const _PostCard(
                name: 'Ayie',
                letter: 'A',
                text: 'Hari ini terasa sederhana, tapi justru hal-hal kecil seperti ini yang ingin aku simpan. ✨',
                mood: 'Feeling peaceful',
                location: 'Bandung',
              ),
              const SizedBox(height: 16),
              const _PostCard(
                name: 'BLOOM',
                letter: 'B',
                text: 'Selamat datang di BLOOM — tempat menyimpan momen yang benar-benar berarti.',
                mood: 'Feeling grateful',
                location: 'BLOOM',
              ),
              const SizedBox(height: 20),
              const _ActivityCard(),
            ]),
          ),
        ),
      ],
    );
  }
}

class _PremiumCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PremiumCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .06),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: lightBlue,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: premiumBlue, size: 29),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: navy,
                        fontSize: 16,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(
                        color: softText, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: softText),
        ],
      ),
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
        separatorBuilder: (_, __) => const SizedBox(width: 15),
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

class _PostCard extends StatefulWidget {
  final String name;
  final String letter;
  final String text;
  final String mood;
  final String location;

  const _PostCard({
    required this.name,
    required this.letter,
    required this.text,
    required this.mood,
    required this.location,
  });

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool liked = false;

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
                child: Text(
                  widget.name,
                  style: const TextStyle(
                    color: navy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Icon(Icons.more_horiz, color: softText),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            widget.text,
            style: const TextStyle(
              color: navy,
              fontSize: 15,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            children: [
              _Pill(widget.mood, Icons.sentiment_satisfied_alt),
              _Pill(widget.location, Icons.location_on_outlined),
            ],
          ),
          const Divider(height: 25),
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => liked = !liked),
                icon: Icon(
                  liked ? Icons.favorite : Icons.favorite_border,
                  color: liked ? premiumBlue : softText,
                ),
              ),
              const Icon(Icons.chat_bubble_outline, color: softText),
              const SizedBox(width: 20),
              const Icon(Icons.ios_share, color: softText),
              const Spacer(),
              const Icon(Icons.bookmark_border, color: softText),
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
          Text('YOUR DAY',
              style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w900,
                  fontSize: 11)),
          SizedBox(height: 5),
          Text('Little activities',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900)),
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
        Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class CreateBloomSheet extends StatelessWidget {
  const CreateBloomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Photo & Video', Icons.photo_library_outlined),
      ('Thought', Icons.edit_note_rounded),
      ('Check-in', Icons.location_on_outlined),
      ('Listening', Icons.music_note_rounded),
      ('Watching', Icons.movie_outlined),
      ('Reading', Icons.menu_book_rounded),
      ('Asleep', Icons.bedtime_rounded),
      ('Awake', Icons.wb_sunny_outlined),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Create a Bloom',
              style: TextStyle(
                color: navy,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 18),
            ...items.map(
              (item) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: lightBlue,
                  child: Icon(item.$2, color: premiumBlue),
                ),
                title: Text(
                  item.$1,
                  style: const TextStyle(
                    color: navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right, color: softText),
                onTap: () {
                  if (item.$1 == 'Thought') {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (_) => const ThoughtDialog(),
                    );
                  } else {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${item.$1} siap diaktifkan berikutnya.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
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
        style: TextStyle(
          color: navy,
          fontWeight: FontWeight.w900,
        ),
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
          child: const Text(
            'Batal',
            style: TextStyle(color: softText),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: premiumBlue,
          ),
          onPressed: () {
            if (controller.text.trim().isEmpty) return;
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Thought berhasil dibuat.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          child: const Text('Bloom'),
        ),
      ],
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

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) => const _SimplePage(
        icon: Icons.person,
        title: 'Profile',
        subtitle: 'Profil dan momen milikmu.',
      );
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'BLOOM',
              style: TextStyle(
                color: premiumBlue,
                fontSize: 25,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 35),
            CircleAvatar(
              radius: 32,
              backgroundColor: lightBlue,
              child: Icon(icon, color: premiumBlue, size: 30),
            ),
            const SizedBox(height: 18),
            Text(title,
                style: const TextStyle(
                    color: navy,
                    fontSize: 27,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(subtitle,
                style: const TextStyle(
                    color: softText,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
