// Profile pictures: eight built-in sport avatars (an icon on a solid tone), the user's own photo,
// or their initial. The choice lives in profiles.avatar; a photo is stored privately at
// progress-photos/<user id>/avatar, which delete-account already clears.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'icons.dart';
import 'main.dart';
import 'theme.dart';

typedef AvatarStyle = ({IconData icon, Color bg, Color fg, String label});

const avatars = <String, AvatarStyle>{
  'barbell': (icon: LvIcons.barbell, bg: accent, fg: graphite, label: 'Lifter'),
  'run': (icon: LvIcons.personSimpleRun, bg: Color(0xFF1F3A34), fg: Color(0xFF9FE0C8), label: 'Runner'),
  'bike': (icon: LvIcons.personSimpleBike, bg: Color(0xFF1D2B45), fg: Color(0xFFA9C4FF), label: 'Rider'),
  'swim': (icon: LvIcons.personSimpleSwim, bg: Color(0xFF173B4A), fg: Color(0xFF8FD9F2), label: 'Swimmer'),
  'flame': (icon: LvIcons.flame, bg: Color(0xFF3A1A12), fg: Color(0xFFFF9A62), label: 'Burner'),
  'bolt': (icon: LvIcons.lightning, bg: Color(0xFF34300F), fg: Color(0xFFF2D75C), label: 'Sprinter'),
  'peak': (icon: LvIcons.mountains, bg: Color(0xFF2A2433), fg: Color(0xFFCDB8F0), label: 'Climber'),
  'trophy': (icon: LvIcons.trophy, bg: cloud, fg: graphite, label: 'Champion'),
};

String _photoPath(String uid) => '$uid/avatar';

/// Short-lived link to the user's own photo, or null when they have none.
Future<String?> avatarPhotoUrl(String uid) async {
  try {
    return await supabase.storage.from('progress-photos').createSignedUrl(_photoPath(uid), 3600);
  } catch (_) {
    return null;
  }
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.name, this.avatar, this.photoUrl, this.size = 56});
  final String name;
  final String? avatar; // a key of [avatars], 'photo', or null for the initial
  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final initial = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
      child: Text(name.trim().isEmpty ? 'L' : name.trim()[0].toUpperCase(),
          style: TextStyle(fontSize: size * 0.42, fontWeight: FontWeight.w700, color: c.onPrimary)),
    );
    if (avatar == 'photo' && photoUrl != null) {
      return ClipOval(
        child: Image.network(photoUrl!, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, _, _) => initial),
      );
    }
    final style = avatars[avatar];
    if (style == null) return initial;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: style.bg, shape: BoxShape.circle),
      child: Icon(style.icon, size: size * 0.52, color: style.fg),
    );
  }
}

/// Lets the user choose an avatar, upload their own photo, or go back to their initial.
/// Returns true when the choice was saved.
Future<bool> pickAvatar(BuildContext context, {required String name, String? current}) async {
  final uid = supabase.auth.currentUser!.id;
  final messenger = ScaffoldMessenger.of(context);
  Future<bool> save(String? value) async {
    try {
      await supabase.from('profiles').update({'avatar': value}).eq('id', uid);
      HapticFeedback.selectionClick();
      return true;
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not save your picture. Check your connection.')));
      return false;
    }
  }

  Future<bool> upload() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 85);
    if (file == null) return false;
    try {
      final png = file.name.toLowerCase().endsWith('.png');
      await supabase.storage.from('progress-photos').uploadBinary(
            _photoPath(uid),
            await file.readAsBytes(),
            fileOptions: FileOptions(contentType: png ? 'image/png' : 'image/jpeg', upsert: true),
          );
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not upload the photo. Use a JPG or PNG under 8 MB.')));
      return false;
    }
    return save('photo');
  }

  final picked = await showModalBottomSheet<String>(
    context: context,
    builder: (sheet) {
      final t = Theme.of(sheet).textTheme;
      final c = Theme.of(sheet).colorScheme;
      Widget choice(String key, Widget child, String label) => Semantics(
            button: true,
            selected: current == key,
            label: label,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.pop(sheet, key),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: current == key ? c.primary : Colors.transparent, width: 2)),
                  child: child,
                ),
                const SizedBox(height: 4),
                Text(label, style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
              ]),
            ),
          );
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Profile picture', style: t.titleLarge),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              mainAxisSpacing: 12,
              crossAxisSpacing: 8,
              childAspectRatio: 0.8,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final MapEntry(:key, :value) in avatars.entries) choice(key, UserAvatar(name: name, avatar: key, size: 52), value.label),
              ],
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: FilledButton.icon(onPressed: () => Navigator.pop(sheet, 'upload'), icon: const Icon(LvIcons.camera, size: 18), label: const Text('Use my photo')),
              ),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(sheet, 'initial'), child: const Text('Use my initial'))),
            ]),
          ]),
        ),
      );
    },
  );
  return switch (picked) {
    null => false,
    'upload' => upload(),
    'initial' => save(null),
    final key => save(key),
  };
}
