// Levlofit AI: a full-screen chat in the shape people know from ChatGPT. Chats in a side list, one memory
// across them, replies that write themselves in, and any sent message can be edited or a reply regenerated.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'icons.dart';
import 'main.dart';
import 'theme.dart';

/// Opens Levlofit AI as a floating panel over the current screen, rising from the corner where the
/// launcher sits. [prompt] starts a new chat with that message already sent.
Future<void> openCoach(BuildContext context, {String? prompt}) => showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close Levlofit AI',
      barrierColor: Colors.black.withValues(alpha: 0.28),
      transitionDuration: motion(context, 420),
      pageBuilder: (context, _, _) {
        final size = MediaQuery.sizeOf(context);
        final insets = MediaQuery.viewInsetsOf(context);
        final pad = MediaQuery.paddingOf(context);
        final phone = size.width < 600;
        return SafeArea(
          child: AnimatedPadding(
            duration: motion(context, 200),
            padding: EdgeInsets.only(left: 12, right: phone ? 12 : 24, top: 12, bottom: (phone ? 12 : 24) + insets.bottom),
            child: Align(
              alignment: Alignment.bottomRight,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 420, maxHeight: (size.height - insets.bottom - pad.vertical - 24).clamp(320.0, 680.0)),
                child: Material(
                  elevation: 24,
                  shadowColor: Colors.black54,
                  borderRadius: BorderRadius.circular(28),
                  clipBehavior: Clip.antiAlias,
                  color: Theme.of(context).colorScheme.surface,
                  // The panel already moves above the keyboard, so the chat inside must not shrink for it again.
                  // Same for the notch and home bar: the panel sits inside the safe area already.
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    removeBottom: true,
                    child: MediaQuery.removeViewInsets(context: context, removeBottom: true, child: CoachScreen(prompt: prompt)),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, a, _, child) {
        final curve = CurvedAnimation(parent: a, curve: spring, reverseCurve: Curves.easeInCubic);
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(scale: Tween(begin: 0.86, end: 1.0).animate(curve), alignment: Alignment.bottomRight, child: child),
        );
      },
    );

/// Floating entry point for the assistant: Levlofit's fitness bot, bobbing gently in the corner.
class CoachLauncher extends StatefulWidget {
  const CoachLauncher({super.key});

  @override
  State<CoachLauncher> createState() => _CoachLauncherState();
}

class _CoachLauncherState extends State<CoachLauncher> with SingleTickerProviderStateMixin {
  late final _idle = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200))..repeat();
  bool _pressed = false;
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    // Arrive after the plan has settled, so it reads as an offer, not a popup.
    Future.delayed(const Duration(milliseconds: 700), () => mounted ? setState(() => _shown = true) : null);
  }

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final still = MediaQuery.disableAnimationsOf(context);
    return AnimatedSlide(
      offset: _shown ? Offset.zero : const Offset(0, 1.5),
      duration: motion(context, 520),
      curve: spring,
      child: AnimatedOpacity(
        opacity: _shown ? 1 : 0,
        duration: motion(context, 380),
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1,
          duration: motion(context, 120),
          curve: Curves.easeOutCubic,
          child: Tooltip(
            message: 'Ask Levlofit AI',
            child: Semantics(
              button: true,
              label: 'Ask Levlofit AI, your fitness bot',
              child: Material(
                color: c.secondary,
                shape: const CircleBorder(),
                elevation: 6,
                shadowColor: Colors.black45,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onHighlightChanged: (v) => setState(() => _pressed = v),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    openCoach(context);
                  },
                  child: SizedBox.square(
                    dimension: 64,
                    child: AnimatedBuilder(
                      animation: _idle,
                      builder: (_, _) => CustomPaint(painter: FitBotPainter(t: still ? 0 : _idle.value, face: c.surface, ink: c.secondary)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Levlofit's fitness bot: a rounded head with a sweatband, a dark visor with two eyes that blink, and an
/// antenna tipped in Levlofit orange. [t] runs 0 to 1 over one idle loop (bob, blink, antenna glow).
class FitBotPainter extends CustomPainter {
  const FitBotPainter({required this.t, required this.face, required this.ink});
  final double t;
  final Color face, ink;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 64; // drawn on a 64-unit grid
    final bob = math.sin(t * 2 * math.pi) * 1.6 * u;
    canvas.translate(0, bob);
    final fill = Paint()..isAntiAlias = true;

    // Antenna with a glowing tip.
    fill.color = face;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(31 * u, 12 * u, 2 * u, 7 * u), Radius.circular(u)), fill);
    final glow = 0.5 + 0.5 * math.sin(t * 4 * math.pi);
    canvas.drawCircle(Offset(32 * u, 11 * u), (3.2 + 1.6 * glow) * u, Paint()..color = accent.withValues(alpha: 0.25 * glow));
    canvas.drawCircle(Offset(32 * u, 11 * u), 2.6 * u, fill..color = accent);

    // Head and side bolts (ears).
    fill.color = face;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(13 * u, 21 * u, 4 * u, 12 * u), Radius.circular(2 * u)), fill);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(47 * u, 21 * u, 4 * u, 12 * u), Radius.circular(2 * u)), fill);
    final head = RRect.fromRectAndRadius(Rect.fromLTWH(16 * u, 18 * u, 32 * u, 28 * u), Radius.circular(10 * u));
    canvas.drawRRect(head, fill);

    // Sweatband across the forehead.
    canvas.save();
    canvas.clipRRect(head);
    canvas.drawRect(Rect.fromLTWH(16 * u, 22.5 * u, 32 * u, 4.5 * u), fill..color = accent);
    canvas.restore();

    // Visor with two eyes; a blink near the end of each loop.
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(20 * u, 29 * u, 24 * u, 12 * u), Radius.circular(6 * u)), fill..color = ink);
    final blink = t > 0.9 && t < 0.95 ? 0.15 : 1.0;
    final eyeH = 5 * u * blink;
    for (final x in [25.5 * u, 34.5 * u]) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, 35 * u - eyeH / 2, 4 * u, eyeH), Radius.circular(2 * u)), fill..color = accent);
    }
    // A small smile under the visor.
    canvas.drawArc(Rect.fromLTWH(28.5 * u, 41.5 * u, 7 * u, 3 * u), 0.2, math.pi - 0.4, false,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 * u
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(FitBotPainter old) => old.t != t || old.face != face || old.ink != ink;
}

class _Msg {
  _Msg(this.role, this.text, {this.id, this.fresh = false});
  final String role;
  final String text;
  int? id; // set once the server has saved it; only saved messages can be edited
  bool fresh; // a reply that has just arrived writes itself in once

  bool get mine => role == 'user';
}

typedef _Thread = ({String id, String title, DateTime updated});

class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key, this.prompt});
  final String? prompt;

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final _messages = <_Msg>[];
  List<_Thread> _threads = [];
  String? _threadId;
  String _first = '';
  bool _busy = false;
  bool _loadingThread = false;
  int? _editing; // index of the message being edited
  ({String text, int? editFrom, int cut})? _failed; // what to resend after an error
  String? _error;

  String get _uid => supabase.auth.currentUser!.id;

  static const _starters = [
    (LvIcons.barbell, 'Walk me through today\'s session'),
    (LvIcons.forkKnife, 'What should I eat today?'),
    (LvIcons.lightbulb, 'Why is my plan built this way?'),
    (LvIcons.arrowsClockwise, 'I missed a session. What now?'),
  ];

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
    _boot();
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    try {
      final [profile, threads] = await Future.wait<dynamic>([
        supabase.from('profiles').select('display_name').eq('id', _uid).maybeSingle(),
        supabase.from('coach_threads').select('id, title, updated_at').order('updated_at', ascending: false).limit(50),
      ]);
      _first = ((profile?['display_name'] as String?) ?? '').split(' ').first;
      _threads = [for (final t in threads as List) (id: t['id'] as String, title: t['title'] as String, updated: DateTime.parse(t['updated_at'] as String))];
    } catch (_) {
      // The chat works without the list; the next send retries the network.
    }
    if (!mounted) return;
    setState(() {});
    if (widget.prompt != null) _send(widget.prompt!);
  }

  Future<void> _openThread(String? id) async {
    setState(() {
      _threadId = id;
      _messages.clear();
      _editing = null;
      _error = null;
      _failed = null;
      _input.clear();
      _loadingThread = id != null;
    });
    if (id == null) return _focus.requestFocus();
    try {
      final rows = await supabase.from('coach_messages').select('id, role, content').eq('thread_id', id).order('id', ascending: true).limit(200);
      if (!mounted || _threadId != id) return;
      _messages.addAll([for (final r in rows) _Msg(r['role'] as String, r['content'] as String, id: r['id'] as int)]);
    } catch (_) {
      _error = 'Could not open this chat. Check your connection.';
    }
    if (!mounted) return;
    setState(() => _loadingThread = false);
    _toEnd(jump: true);
  }

  /// Sends [text]. [cut] drops local messages from that index first (edit and regenerate); [editFrom] tells the server.
  Future<void> _send(String text, {int? editFrom, int? cut}) async {
    text = text.trim();
    if (text.isEmpty || _busy) return;
    HapticFeedback.selectionClick();
    final at = cut ?? _messages.length;
    setState(() {
      _messages.removeRange(at, _messages.length);
      _messages.add(_Msg('user', text));
      _input.clear();
      _editing = null;
      _busy = true;
      _error = null;
      _failed = null;
    });
    _toEnd();
    try {
      final res = await supabase.functions.invoke('coach-chat', body: {'message': text, 'threadId': ?_threadId, 'editFrom': ?editFrom});
      final data = res.data as Map;
      if (!mounted) return;
      final threadId = data['threadId'] as String;
      setState(() {
        _messages.last.id = data['userMessageId'] as int?;
        _messages.add(_Msg('assistant', data['reply'] as String, id: data['assistantMessageId'] as int?, fresh: true));
        final known = _threads.where((t) => t.id == threadId).map((t) => t.title).firstOrNull;
        _threadId = threadId;
        _threads = [(id: threadId, title: known ?? data['title'] as String, updated: DateTime.now()), ..._threads.where((t) => t.id != threadId)];
      });
    } on FunctionException catch (e) {
      final d = e.details;
      _fail(d is Map && d['error'] is String ? d['error'] as String : 'Levlofit AI is unavailable. Try again.', text, editFrom, at);
    } catch (_) {
      _fail('Could not reach Levlofit AI. Check your connection.', text, editFrom, at);
    } finally {
      if (mounted) setState(() => _busy = false);
      _toEnd();
    }
  }

  void _fail(String message, String text, int? editFrom, int cut) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _failed = (text: text, editFrom: editFrom, cut: cut);
    });
  }

  void _regenerate() {
    final i = _messages.lastIndexWhere((m) => m.mine);
    if (i < 0 || _messages[i].id == null) return;
    _send(_messages[i].text, editFrom: _messages[i].id, cut: i);
  }

  void _startEdit(int i) {
    setState(() {
      _editing = i;
      _input.text = _messages[i].text;
    });
    _focus.requestFocus();
  }

  void _submit() {
    final i = _editing;
    if (i != null) {
      _send(_input.text, editFrom: _messages[i].id, cut: i);
    } else {
      _send(_input.text);
    }
  }

  Future<void> _deleteThread(_Thread t) async {
    try {
      await supabase.from('coach_threads').delete().eq('id', t.id);
      setState(() => _threads = _threads.where((x) => x.id != t.id).toList());
      if (_threadId == t.id) _openThread(null);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not delete that chat.')));
    }
  }

  Future<void> _showMemory() async {
    String notes = '';
    try {
      notes = ((await supabase.from('coach_notes').select('notes').eq('user_id', _uid).maybeSingle())?['notes'] as String?) ?? '';
    } catch (_) {}
    if (!mounted) return;
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('MEMORY', style: monoLabel(context)),
            const SizedBox(height: 6),
            Text('What Levlofit AI remembers about you', style: t.titleLarge),
            const SizedBox(height: 4),
            Text('Learned from your chats and used in every new one.', style: t.bodySmall?.copyWith(color: muted)),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.4),
              child: SingleChildScrollView(
                child: Text(notes.isEmpty ? 'Nothing yet. Tell it about your schedule, likes and dislikes, and it will remember.' : notes, style: t.bodyMedium),
              ),
            ),
            const SizedBox(height: 16),
            if (notes.isNotEmpty)
              OutlinedButton(
                onPressed: () async {
                  Navigator.pop(sheet);
                  try {
                    await supabase.from('coach_notes').delete().eq('user_id', _uid);
                  } catch (_) {}
                },
                child: const Text('Forget everything'),
              ),
          ]),
        ),
      ),
    );
  }

  void _toEnd({bool jump = false}) => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        if (jump) return _scroll.jumpTo(_scroll.position.maxScrollExtent);
        _scroll.animateTo(_scroll.position.maxScrollExtent + 120, duration: motion(context, 320), curve: spring);
      });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final title = _threadId == null ? 'New chat' : _threads.where((x) => x.id == _threadId).map((x) => x.title).firstOrNull ?? 'Chat';
    final lastAssistant = _messages.lastIndexWhere((m) => !m.mine);
    return Scaffold(
      drawer: _ChatList(
        threads: _threads,
        current: _threadId,
        onOpen: (id) {
          Navigator.pop(context);
          _openThread(id);
        },
        onDelete: _deleteThread,
        onMemory: () {
          Navigator.pop(context);
          _showMemory();
        },
      ),
      appBar: AppBar(
        leading: Builder(builder: (context) => IconButton(tooltip: 'Your chats', icon: const Icon(LvIcons.list, size: 22), onPressed: () => Scaffold.of(context).openDrawer())),
        titleSpacing: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('LEVLOFIT AI', style: monoLabel(context)),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleMedium),
        ]),
        actions: [
          IconButton(tooltip: 'New chat', icon: const Icon(LvIcons.notePencil, size: 22), onPressed: _busy ? null : () => _openThread(null)),
          IconButton(tooltip: 'Close', icon: const Icon(LvIcons.x, size: 20), onPressed: () => Navigator.pop(context)),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: _loadingThread
                  ? const Center(child: _Typing())
                  : _messages.isEmpty && !_busy
                      ? _Empty(first: _first, starters: _starters, onPick: _send)
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                          itemCount: _messages.length + 1,
                          itemBuilder: (context, i) {
                            if (i == _messages.length) return _tail();
                            final m = _messages[i];
                            return m.mine
                                ? _UserBubble(msg: m, editing: _editing == i, onEdit: m.id == null || _busy ? null : () => _startEdit(i))
                                : _Reply(
                                    msg: m,
                                    onRegenerate: i == lastAssistant && !_busy ? _regenerate : null,
                                    onTyped: () => m.fresh = false,
                                    onGrow: () => _toEnd(jump: true),
                                  );
                          },
                        ),
            ),
          ),
        ),
        _Composer(
          controller: _input,
          focus: _focus,
          busy: _busy,
          editing: _editing != null,
          onCancelEdit: () => setState(() {
            _editing = null;
            _input.clear();
          }),
          onSend: _submit,
        ),
      ]),
    );
  }

  /// Under the last message: the thinking dots, or the error with a retry.
  Widget _tail() {
    if (_busy) return const Padding(padding: EdgeInsets.only(left: 38, top: 4), child: _Typing());
    if (_error == null) return const SizedBox.shrink();
    final f = _failed;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ErrorLine(_error!),
        if (f != null)
          TextButton.icon(
            onPressed: () => _send(f.text, editFrom: f.editFrom, cut: f.cut),
            icon: const Icon(LvIcons.arrowsClockwise, size: 16),
            label: const Text('Try again'),
          ),
      ]),
    );
  }
}

class _ChatList extends StatelessWidget {
  const _ChatList({required this.threads, required this.current, required this.onOpen, required this.onDelete, required this.onMemory});
  final List<_Thread> threads;
  final String? current;
  final void Function(String? id) onOpen;
  final void Function(_Thread t) onDelete;
  final VoidCallback onMemory;

  static String _when(DateTime d) {
    final days = DateTime.now().difference(d).inDays;
    return days == 0 ? 'TODAY' : days == 1 ? 'YESTERDAY' : days < 7 ? '$days DAYS AGO' : '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Drawer(
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(28))),
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: FilledButton.icon(onPressed: () => onOpen(null), icon: const Icon(LvIcons.notePencil, size: 18), label: const Text('New chat')),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(24, 16, 24, 8), child: Text('YOUR CHATS', style: monoLabel(context))),
          Expanded(
            child: threads.isEmpty
                ? Padding(padding: const EdgeInsets.all(24), child: Text('Your chats will appear here.', style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)))
                : ListView(padding: const EdgeInsets.symmetric(horizontal: 8), children: [
                    for (final th in threads)
                      Material(
                        color: th.id == current ? c.surfaceContainerHighest : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        child: ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          title: Text(th.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                          subtitle: Text(_when(th.updated), style: monoLabel(context).copyWith(fontSize: 10)),
                          onTap: () => onOpen(th.id),
                          trailing: IconButton(tooltip: 'Delete chat', icon: Icon(LvIcons.trash, size: 18, color: c.onSurfaceVariant), onPressed: () => onDelete(th)),
                        ),
                      ),
                  ]),
          ),
          Divider(height: 1, color: c.outline),
          ListTile(leading: const Icon(LvIcons.brain), title: const Text('Memory'), subtitle: const Text('What it knows about you'), onTap: onMemory),
        ]),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.first, required this.starters, required this.onPick});
  final String first;
  final List<(IconData, String)> starters;
  final void Function(String) onPick;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      children: staggered([
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondary, shape: BoxShape.circle),
            child: CustomPaint(painter: FitBotPainter(t: 0, face: Theme.of(context).colorScheme.surface, ink: Theme.of(context).colorScheme.secondary)),
          ),
        ),
        const SizedBox(height: 20),
        Text(first.isEmpty ? 'What are we working on?' : 'What are we working on, $first?', style: t.headlineMedium),
        const SizedBox(height: 8),
        Text('I know your plan and your training, and I remember what you tell me.', style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
        const SizedBox(height: 28),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.45,
          children: [
            for (final (icon, text) in starters)
              Pressable(
                child: Material(
                  color: c.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: c.outline)),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onPick(text),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(icon, size: 20, color: c.tertiary),
                        const Spacer(),
                        Text(text, maxLines: 3, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.3)),
                      ]),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ]),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.msg, required this.editing, required this.onEdit});
  final _Msg msg;
  final bool editing;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return _Arrive(
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          GestureDetector(
            onLongPress: onEdit,
            child: AnimatedContainer(
              duration: motion(context, 200),
              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: c.surfaceContainerHighest,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20), bottomLeft: Radius.circular(20), bottomRight: Radius.circular(6)),
                border: Border.all(color: editing ? c.primary : Colors.transparent, width: 1.5),
              ),
              child: SelectableText(msg.text, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.45)),
            ),
          ),
          Row(mainAxisSize: MainAxisSize.min, children: [
            _Action(icon: LvIcons.copy, label: 'Copy', onTap: () => _copy(context, msg.text)),
            if (onEdit != null) _Action(icon: LvIcons.pencilSimple, label: 'Edit', onTap: onEdit!),
          ]),
        ]),
      ),
    );
  }
}

/// The assistant's turn: no bubble, full width, formatted, with actions underneath.
class _Reply extends StatelessWidget {
  const _Reply({required this.msg, required this.onRegenerate, required this.onTyped, required this.onGrow});
  final _Msg msg;
  final VoidCallback? onRegenerate;
  final VoidCallback onTyped, onGrow;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return _Arrive(
      child: Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.only(top: 2, right: 12),
            decoration: BoxDecoration(color: c.secondary, shape: BoxShape.circle),
            child: Center(child: Container(width: 8, height: 8, decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle))),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              msg.fresh ? _Typewriter(text: msg.text, onDone: onTyped, onGrow: onGrow) : Markdown(msg.text),
              const SizedBox(height: 4),
              Row(children: [
                _Action(icon: LvIcons.copy, label: 'Copy', onTap: () => _copy(context, msg.text)),
                if (onRegenerate != null) _Action(icon: LvIcons.arrowsClockwise, label: 'Regenerate', onTap: onRegenerate!),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

void _copy(BuildContext context, String text) {
  Clipboard.setData(ClipboardData(text: text));
  HapticFeedback.selectionClick();
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)));
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: label,
        visualDensity: VisualDensity.compact,
        iconSize: 16,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        onPressed: onTap,
        icon: Icon(icon),
      );
}

/// Reveals a new reply word by word, so it arrives like a live answer instead of a block.
class _Typewriter extends StatefulWidget {
  const _Typewriter({required this.text, required this.onDone, required this.onGrow});
  final String text;
  final VoidCallback onDone, onGrow;

  @override
  State<_Typewriter> createState() => _TypewriterState();
}

class _TypewriterState extends State<_Typewriter> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: Duration(milliseconds: (widget.text.length * 9).clamp(300, 3200)));
  int _lines = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isAnimating || _c.isCompleted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
      widget.onDone();
      return;
    }
    _c.addListener(() {
      // Keep the newest line in view while it writes.
      final lines = '\n'.allMatches(_visible).length;
      if (lines != _lines) {
        _lines = lines;
        widget.onGrow();
      }
    });
    _c.forward().whenComplete(widget.onDone);
  }

  String get _visible {
    final n = (widget.text.length * Curves.easeOut.transform(_c.value)).round();
    final cut = widget.text.indexOf(' ', n); // whole words only
    return cut < 0 ? widget.text : widget.text.substring(0, cut);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: _c, builder: (_, _) => Markdown(_visible));
}

/// Just enough Markdown for chat replies: headings, bullet and numbered lists, **bold**, `code`, paragraphs.
class Markdown extends StatelessWidget {
  const Markdown(this.text, {super.key});
  final String text;

  static final _inline = RegExp(r'\*\*(.+?)\*\*|`([^`]+)`');
  static final _heading = RegExp(r'^#{1,4}\s+(.*)');
  static final _bullet = RegExp(r'^(\s*)[-*•]\s+(.*)');
  static final _number = RegExp(r'^(\s*)(\d+)[.)]\s+(.*)');

  List<InlineSpan> _spans(BuildContext context, String s) {
    final c = Theme.of(context).colorScheme;
    final out = <InlineSpan>[];
    var at = 0;
    for (final m in _inline.allMatches(s)) {
      if (m.start > at) out.add(TextSpan(text: s.substring(at, m.start)));
      out.add(m[1] != null
          ? TextSpan(text: m[1], style: const TextStyle(fontWeight: FontWeight.w700))
          : TextSpan(text: m[2], style: monoNumber(context, size: 14).copyWith(backgroundColor: c.surfaceContainerHighest)));
      at = m.end;
    }
    if (at < s.length) out.add(TextSpan(text: s.substring(at)));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final body = t.bodyLarge?.copyWith(height: 1.55);
    Widget item(String indent, Widget marker, String content) => Padding(
          padding: EdgeInsets.only(left: indent.length > 1 ? 18 : 0, bottom: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 22, child: marker),
            Expanded(child: Text.rich(TextSpan(children: _spans(context, content)), style: body)),
          ]),
        );
    final blocks = <Widget>[];
    for (final raw in text.split('\n')) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        blocks.add(const SizedBox(height: 8));
      } else if (_heading.firstMatch(line) case final h?) {
        blocks.add(Padding(padding: const EdgeInsets.only(top: 8, bottom: 4), child: Text.rich(TextSpan(children: _spans(context, h[1]!)), style: t.titleMedium)));
      } else if (_bullet.firstMatch(line) case final b?) {
        blocks.add(item(b[1]!, Padding(padding: const EdgeInsets.only(top: 10), child: Container(width: 5, height: 5, decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle))), b[2]!));
      } else if (_number.firstMatch(line) case final n?) {
        blocks.add(item(n[1]!, Text('${n[2]}.', style: body?.copyWith(color: c.tertiary, fontWeight: FontWeight.w600)), n[3]!));
      } else {
        blocks.add(Padding(padding: const EdgeInsets.only(bottom: 2), child: Text.rich(TextSpan(children: _spans(context, line)), style: body)));
      }
    }
    return SelectionArea(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: blocks));
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.focus, required this.busy, required this.editing, required this.onCancelEdit, required this.onSend});
  final TextEditingController controller;
  final FocusNode focus;
  final bool busy, editing;
  final VoidCallback onCancelEdit, onSend;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final ready = controller.text.trim().isNotEmpty && !busy;
    return SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedSize(
                duration: motion(context, 220),
                curve: spring,
                child: editing
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 6, left: 4),
                        child: Row(children: [
                          Icon(LvIcons.pencilSimple, size: 14, color: c.tertiary),
                          const SizedBox(width: 6),
                          Expanded(child: Text('Editing your message. The chat continues from here.', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant))),
                          TextButton(onPressed: onCancelEdit, child: const Text('Cancel')),
                        ]),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 4, 6, 4),
                decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(28), border: Border.all(color: editing ? c.primary : c.outline)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                    child: CallbackShortcuts(
                      // Enter sends, Shift+Enter breaks the line (keyboards on phones keep their own newline key).
                      bindings: {const SingleActivator(LogicalKeyboardKey.enter): () => ready ? onSend() : null},
                      child: TextField(
                        controller: controller,
                        focusNode: focus,
                        maxLength: 2000,
                        minLines: 1,
                        maxLines: 6,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Message Levlofit AI',
                          counterText: '',
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: AnimatedContainer(
                      duration: motion(context, 200),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: ready ? c.primary : c.surfaceContainerHighest, shape: BoxShape.circle),
                      child: IconButton(
                        tooltip: editing ? 'Save and resend' : 'Send',
                        padding: EdgeInsets.zero,
                        onPressed: ready ? onSend : null,
                        icon: Icon(LvIcons.arrowUp, size: 20, color: ready ? c.onPrimary : c.onSurfaceVariant),
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 6),
              Text('Levlofit AI can make mistakes. Not a doctor. Plan numbers come from your plan.',
                  textAlign: TextAlign.center, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant, fontSize: 11)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Eases a new message up into place.
class _Arrive extends StatelessWidget {
  const _Arrive({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: motion(context, 380),
        curve: spring,
        builder: (_, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 12 * (1 - v)), child: child)),
        child: child,
      );
}

/// Three dots that rise in turn while the model is answering.
class _Typing extends StatefulWidget {
  const _Typing();

  @override
  State<_Typing> createState() => _TypingState();
}

class _TypingState extends State<_Typing> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // 1 while dot i is at its peak, easing back to 0 as the wave moves on.
  double _wave(int i) => (1 - ((_c.value * 3 - i) % 3)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Levlofit AI is thinking',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: 8,
                height: 8,
                margin: EdgeInsets.only(right: 6, bottom: 5 * _wave(i)),
                decoration: BoxDecoration(color: c.primary.withValues(alpha: 0.35 + 0.65 * _wave(i)), shape: BoxShape.circle),
              ),
          ]),
        ),
      ),
    );
  }
}
