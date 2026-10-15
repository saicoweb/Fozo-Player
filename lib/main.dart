import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kAppName = 'Fozo Player'; // غيّر الاسم هنا
const kBlue = Color(0xFF2196FF);
const kCard = Color(0xFF1C1C1C);
const kGrey = Color(0xFF9E9E9E);

const _tr = {
  'ar': {
    'chooseLang': 'اختر لغتك', 'start': 'البدء',
    'terms': 'من خلال النقر على "البدء"، فإنك تقر بقراءتك وموافقتك على شروط الخدمة وسياسة الخصوصية الخاصة بنا.',
    'songs': 'الأغاني', 'videos': 'الفيديوهات', 'playlists': 'قوائم التشغيل', 'folders': 'مجلدات',
    'notFound': 'لم يتم العثور على الأغاني؟', 'scan': 'فحص المجلدات', 'tap': 'اضغط للتشغيل',
    'soon': 'قريباً', 'noLyrics': 'كلمات الأغنية غير متاحة', 'unknown': 'غير معروف',
    'sortDate': 'الأحدث إضافة', 'sortTitle': 'الاسم', 'sortArtist': 'الفنان', 'speed': 'سرعة التشغيل',
    'count': 'أغنية', 'language': 'اللغة', 'noPerm': 'اسمح بالوصول للملفات الصوتية من إعدادات الجهاز',
  },
  'en': {
    'chooseLang': 'Choose your language', 'start': 'Start',
    'terms': 'By tapping "Start", you confirm that you have read and agree to our Terms of Service and Privacy Policy.',
    'songs': 'Songs', 'videos': 'Videos', 'playlists': 'Playlists', 'folders': 'Folders',
    'notFound': "Can't find your songs?", 'scan': 'Scan folders', 'tap': 'Tap to play',
    'soon': 'Coming soon', 'noLyrics': 'Lyrics not available', 'unknown': 'Unknown',
    'sortDate': 'Recently added', 'sortTitle': 'Title', 'sortArtist': 'Artist', 'speed': 'Playback speed',
    'count': 'songs', 'language': 'Language', 'noPerm': 'Allow audio access from device settings',
  },
};
String lang = 'ar';
String t(String k) => _tr[lang]![k]!;
final appRev = ValueNotifier<int>(0);
late SharedPreferences prefs;

class Ctl {
  static final Ctl i = Ctl._();
  Ctl._();
  final player = AudioPlayer();
  final query = OnAudioQuery();
  final songs = ValueNotifier<List<SongModel>>([]);
  final loading = ValueNotifier<bool>(false);
  final likes = ValueNotifier<Set<String>>({});
  List<SongModel> queue = [];

  Future<bool> perm() async {
    final r = await [Permission.audio, Permission.storage, Permission.notification].request();
    return (r[Permission.audio]?.isGranted ?? false) || (r[Permission.storage]?.isGranted ?? false);
  }

  Future<void> scan() async {
    loading.value = true;
    likes.value = (prefs.getStringList('likes') ?? []).toSet();
    try {
      if (await perm()) {
        final r = await query.querySongs(
          sortType: SongSortType.DATE_ADDED,
          orderType: OrderType.DESC_OR_GREATER,
          uriType: UriType.EXTERNAL,
          ignoreCase: true,
        );
        songs.value = r.where((s) => s.uri != null).toList();
      }
    } catch (_) {}
    loading.value = false;
  }

  Future<void> playAt(List<SongModel> list, int index) async {
    queue = list;
    final src = ConcatenatingAudioSource(
      children: list
          .map((s) => AudioSource.uri(Uri.parse(s.uri!),
              tag: MediaItem(id: '${s.id}', title: s.title, artist: artistOf(s))))
          .toList(),
    );
    await player.setAudioSource(src, initialIndex: index);
    player.play();
  }

  void toggleLike(SongModel s) {
    final n = {...likes.value};
    n.contains('${s.id}') ? n.remove('${s.id}') : n.add('${s.id}');
    likes.value = n;
    prefs.setStringList('likes', n.toList());
  }
}

String artistOf(SongModel s) {
  final a = s.artist;
  return (a == null || a == '<unknown>') ? t('unknown') : a;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.musicplayer.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
  );
  prefs = await SharedPreferences.getInstance();
  lang = prefs.getString('lang') ?? 'ar';
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: appRev,
        builder: (_, __, ___) => MaterialApp(
          key: ValueKey('$lang${appRev.value}'),
          debugShowCheckedModeBanner: false,
          title: kAppName,
          locale: Locale(lang),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: Colors.black,
            colorScheme: const ColorScheme.dark(primary: kBlue),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          home: prefs.getBool('welcomed') == true ? const HomePage() : const WelcomePage(),
        ),
      );
}

/* ---------------- شاشة اختيار اللغة ---------------- */
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});
  @override
  State<WelcomePage> createState() => _WelcomeState();
}

class _WelcomeState extends State<WelcomePage> {
  String sel = lang;
  @override
  Widget build(BuildContext context) {
    lang = sel;
    return Directionality(
      textDirection: sel == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1B2A3A), Colors.black],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                const Spacer(),
                Container(
                  width: 110, height: 110,
                  decoration: const BoxDecoration(color: kBlue, shape: BoxShape.circle),
                  child: const Icon(Icons.headphones_rounded, size: 64, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text(t('chooseLang'), style: const TextStyle(fontSize: 26, color: Colors.white)),
                const SizedBox(height: 28),
                Container(
                  decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(28)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(children: [
                    for (final l in const [['ar', 'العربية'], ['en', 'English']])
                      InkWell(
                        onTap: () => setState(() => sel = l[0]),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
                          child: Row(children: [
                            Text(l[1], style: TextStyle(fontSize: 18, color: sel == l[0] ? kBlue : Colors.white)),
                            const Spacer(),
                            if (sel == l[0]) const Icon(Icons.check, color: kBlue, size: 30),
                          ]),
                        ),
                      ),
                  ]),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity, height: 56,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: kBlue, shape: const StadiumBorder()),
                    onPressed: () async {
                      await prefs.setString('lang', sel);
                      await prefs.setBool('welcomed', true);
                      lang = sel;
                      appRev.value++;
                    },
                    child: Text(t('start'), style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 14),
                Text(t('terms'), textAlign: TextAlign.center, style: const TextStyle(color: kGrey, fontSize: 12, height: 1.8)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/* ---------------- مكونات مشتركة ---------------- */
class Art extends StatelessWidget {
  final int id;
  final double size, radius;
  const Art(this.id, {super.key, this.size = 64, this.radius = 14});
  @override
  Widget build(BuildContext context) => QueryArtworkWidget(
        id: id,
        type: ArtworkType.AUDIO,
        size: 400,
        quality: 100,
        artworkWidth: size,
        artworkHeight: size,
        artworkFit: BoxFit.cover,
        artworkBorder: BorderRadius.circular(radius),
        nullArtworkWidget: Container(
          width: size, height: size,
          decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(radius)),
          child: Icon(Icons.music_note_rounded, color: Colors.white, size: size * .5),
        ),
      );
}

class SongTile extends StatelessWidget {
  final SongModel s;
  final VoidCallback onTap;
  const SongTile(this.s, this.onTap, {super.key});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            Art(s.id),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                Text(artistOf(s), maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: kGrey)),
              ]),
            ),
          ]),
        ),
      );
}

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Ctl.i;
    return StreamBuilder<int?>(
      stream: c.player.currentIndexStream,
      builder: (_, snap) {
        final i = snap.data;
        final s = (i != null && i < c.queue.length) ? c.queue[i] : null;
        return GestureDetector(
          onTap: () async {
            if (s == null && c.songs.value.isNotEmpty) await c.playAt(c.songs.value, 0);
            if (context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerPage()));
          },
          child: Container(
            height: 92,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            decoration: const BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Row(children: [
              s != null ? Art(s.id, size: 64) : Container(
                width: 64, height: 64,
                decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 32),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(s?.title ?? t('tap'), maxLines: 1, overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, color: Colors.white)),
                ),
              ),
              StreamBuilder<bool>(
                stream: c.player.playingStream,
                builder: (_, p) => GestureDetector(
                  onTap: () {
                    if (s == null) {
                      if (c.songs.value.isNotEmpty) c.playAt(c.songs.value, 0);
                    } else {
                      (p.data ?? false) ? c.player.pause() : c.player.play();
                    }
                  },
                  child: Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white54, width: 2)),
                    child: Icon((p.data ?? false) ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
                  ),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}

/* ---------------- الشاشة الرئيسية ---------------- */
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomeState();
}

class _HomeState extends State<HomePage> {
  final c = Ctl.i;
  int tab = 1, sort = 0;
  bool searching = false;
  String q = '';

  @override
  void initState() {
    super.initState();
    c.scan();
  }

  List<SongModel> view(List<SongModel> l) {
    final k = q.toLowerCase();
    final r = k.isEmpty
        ? [...l]
        : l.where((s) => s.title.toLowerCase().contains(k) || artistOf(s).toLowerCase().contains(k)).toList();
    if (sort == 1) r.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    if (sort == 2) r.sort((a, b) => artistOf(a).compareTo(artistOf(b)));
    return r;
  }

  void sheet(List<Widget> kids) => showModalBottomSheet(
        context: context,
        backgroundColor: kCard,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: kids)),
      );

  Widget opt(String label, bool on, VoidCallback f) => ListTile(
        title: Text(label, style: TextStyle(color: on ? kBlue : Colors.white)),
        trailing: on ? const Icon(Icons.check, color: kBlue) : null,
        onTap: () { Navigator.pop(context); f(); },
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const MiniPlayer(),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 16, 4),
            child: searching
                ? TextField(
                    autofocus: true,
                    onChanged: (v) => setState(() => q = v),
                    decoration: InputDecoration(
                      filled: true, fillColor: kCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
                      prefixIcon: const Icon(Icons.search, color: Colors.white),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => setState(() { searching = false; q = ''; }),
                      ),
                    ),
                  )
                : Row(children: [
                    const Text(kAppName, style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.search, size: 30, color: Colors.white),
                      onPressed: () => setState(() => searching = true),
                    ),
                    IconButton(
                      icon: const Icon(Icons.sort_rounded, size: 30, color: Colors.white),
                      onPressed: () => sheet([
                        opt(t('sortDate'), sort == 0, () => setState(() => sort = 0)),
                        opt(t('sortTitle'), sort == 1, () => setState(() => sort = 1)),
                        opt(t('sortArtist'), sort == 2, () => setState(() => sort = 2)),
                      ]),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, size: 30, color: Colors.white),
                      onPressed: () => sheet([
                        for (final l in const [['ar', 'العربية'], ['en', 'English']])
                          opt(l[1], lang == l[0], () async {
                            await prefs.setString('lang', l[0]);
                            lang = l[0];
                            appRev.value++;
                          }),
                      ]),
                    ),
                  ]),
          ),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                chip(0, t('videos'), Icons.play_circle_outline_rounded),
                const SizedBox(width: 8),
                chip(1, t('songs'), null),
                chip(2, t('playlists'), null),
                chip(3, t('folders'), null),
              ],
            ),
          ),
          Expanded(child: body()),
        ]),
      ),
    );
  }

  Widget chip(int i, String label, IconData? icon) {
    final on = tab == i;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: GestureDetector(
        onTap: () => setState(() => tab = i),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(color: on ? kBlue : kCard, borderRadius: BorderRadius.circular(24)),
          child: Row(children: [
            Text(label, style: TextStyle(fontSize: 16, color: on ? Colors.white : kGrey)),
            if (icon != null) ...[const SizedBox(width: 8), Icon(icon, color: Colors.white)],
          ]),
        ),
      ),
    );
  }

  Widget body() {
    if (tab == 0 || tab == 2) {
      return Center(child: Text(t('soon'), style: const TextStyle(color: kGrey, fontSize: 18)));
    }
    return ValueListenableBuilder<List<SongModel>>(
      valueListenable: c.songs,
      builder: (_, all, __) {
        final list = view(all);
        if (tab == 3) {
          final m = <String, List<SongModel>>{};
          for (final s in list) {
            final i = s.data.lastIndexOf('/');
            m.putIfAbsent(i > 0 ? s.data.substring(0, i) : '/', () => []).add(s);
          }
          final keys = m.keys.toList();
          return ListView.builder(
            itemCount: keys.length,
            itemBuilder: (_, i) {
              final name = keys[i].split('/').last;
              return InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SongListPage(name, m[keys[i]]!))),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.folder_rounded, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text('${m[keys[i]]!.length} ${t('count')}', style: const TextStyle(color: kGrey)),
                      ]),
                    ),
                  ]),
                ),
              );
            },
          );
        }
        return ListView.builder(
          itemCount: list.length + 1,
          itemBuilder: (_, i) {
            if (i < list.length) return SongTile(list[i], () => c.playAt(list, i));
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(children: [
                Text(t('notFound'), style: const TextStyle(color: kGrey, fontSize: 16)),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: kCard, padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16), shape: const StadiumBorder()),
                  onPressed: () async {
                    await c.scan();
                    if (c.songs.value.isEmpty && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('noPerm'))));
                      openAppSettings();
                    }
                  },
                  child: Text(t('scan'), style: const TextStyle(color: kBlue, fontSize: 17)),
                ),
              ]),
            );
          },
        );
      },
    );
  }
}

class SongListPage extends StatelessWidget {
  final String title;
  final List<SongModel> list;
  const SongListPage(this.title, this.list, {super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(backgroundColor: Colors.black, title: Text(title)),
        bottomNavigationBar: const MiniPlayer(),
        body: ListView.builder(
          itemCount: list.length,
          itemBuilder: (_, i) => SongTile(list[i], () => Ctl.i.playAt(list, i)),
        ),
      );
}

/* ---------------- شاشة المشغّل ---------------- */
class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});
  @override
  State<PlayerPage> createState() => _PlayerState();
}

class _PlayerState extends State<PlayerPage> {
  final c = Ctl.i;
  int loop = 0; // 0 إيقاف، 1 تكرار القائمة، 2 تكرار أغنية، 3 عشوائي
  double? drag;

  String fmt(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  void cycle() {
    setState(() => loop = (loop + 1) % 4);
    c.player.setLoopMode(loop == 1 ? LoopMode.all : loop == 2 ? LoopMode.one : LoopMode.off);
    c.player.setShuffleModeEnabled(loop == 3);
  }

  void speedSheet() => showModalBottomSheet(
        context: context,
        backgroundColor: kCard,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(padding: const EdgeInsets.all(16), child: Text(t('speed'), style: const TextStyle(fontSize: 18, color: Colors.white))),
            for (final v in const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
              ListTile(
                title: Text('${v}x', style: TextStyle(color: c.player.speed == v ? kBlue : Colors.white)),
                onTap: () { c.player.setSpeed(v); Navigator.pop(context); },
              ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int?>(
      stream: c.player.currentIndexStream,
      builder: (_, snap) {
        final i = snap.data;
        final s = (i != null && i < c.queue.length) ? c.queue[i] : null;
        final w = MediaQuery.of(context).size.width - 48;
        return Scaffold(
          backgroundColor: const Color(0xFF232323),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 34, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: s == null ? const SizedBox() : Art(s.id, size: w > 340 ? 340 : w, radius: 28),
                  ),
                ),
                const SizedBox(height: 16),
                Text(s?.title ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white, height: 1.4)),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.more_vert, color: Colors.white),
                  const SizedBox(width: 20),
                  ValueListenableBuilder<Set<String>>(
                    valueListenable: c.likes,
                    builder: (_, l, __) {
                      final on = s != null && l.contains('${s.id}');
                      return GestureDetector(
                        onTap: () { if (s != null) c.toggleLike(s); },
                        child: Icon(on ? Icons.favorite : Icons.favorite_border, size: 30, color: Colors.white),
                      );
                    },
                  ),
                  const Spacer(),
                  Text(s == null ? '' : artistOf(s), style: const TextStyle(fontSize: 18, color: kGrey)),
                ]),
                const SizedBox(height: 28),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: StreamBuilder<Duration>(
                    stream: c.player.positionStream,
                    builder: (_, p) {
                      final dur = c.player.duration ?? Duration.zero;
                      final pos = p.data ?? Duration.zero;
                      final max = dur.inMilliseconds.toDouble();
                      final val = drag ?? (max > 0 ? pos.inMilliseconds.clamp(0, dur.inMilliseconds).toDouble() : 0.0);
                      return Column(children: [
                        SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 6,
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: Colors.white24,
                            thumbColor: Colors.white,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                            overlayShape: SliderComponentShape.noOverlay,
                          ),
                          child: Slider(
                            min: 0,
                            max: max > 0 ? max : 1,
                            value: val.clamp(0, max > 0 ? max : 1),
                            onChanged: (v) => setState(() => drag = v),
                            onChangeEnd: (v) {
                              c.player.seek(Duration(milliseconds: v.toInt()));
                              setState(() => drag = null);
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text(fmt(Duration(milliseconds: val.toInt())), style: const TextStyle(color: kGrey)),
                            Text(fmt(dur), style: const TextStyle(color: kGrey)),
                          ]),
                        ),
                      ]);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    IconButton(
                      iconSize: 64,
                      icon: const Icon(Icons.fast_rewind_rounded, color: Colors.white),
                      onPressed: () => c.player.seekToPrevious(),
                    ),
                    StreamBuilder<bool>(
                      stream: c.player.playingStream,
                      builder: (_, p) => IconButton(
                        iconSize: 88,
                        icon: Icon((p.data ?? false) ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
                        onPressed: () => (p.data ?? false) ? c.player.pause() : c.player.play(),
                      ),
                    ),
                    IconButton(
                      iconSize: 64,
                      icon: const Icon(Icons.fast_forward_rounded, color: Colors.white),
                      onPressed: () => c.player.seekToNext(),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  IconButton(icon: const Icon(Icons.tune_rounded, size: 30, color: Colors.white), onPressed: speedSheet),
                  Expanded(
                    child: Container(
                      height: 52,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: const Color(0xFF2E2E2E), borderRadius: BorderRadius.circular(26)),
                      child: Text(t('noLyrics'), style: const TextStyle(color: Colors.white70)),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      loop == 2 ? Icons.repeat_one_rounded : loop == 3 ? Icons.shuffle_rounded : Icons.repeat_rounded,
                      size: 30,
                      color: loop == 0 ? Colors.white54 : Colors.white,
                    ),
                    onPressed: cycle,
                  ),
                ]),
                const SizedBox(height: 16),
              ]),
            ),
          ),
        );
      },
    );
  }
}