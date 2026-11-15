import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../services/settings_store.dart';
import 'assistant_portrait.dart';

/// Copies a gallery photo into app storage and remembers it as Ah Chi's face.
Future<void> changeAssistantImage(BuildContext context) async {
  final settings = context.read<SettingsStore>();
  final s = settings.strings;
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final p = Theme.of(sheetContext).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 64,
                    height: 64,
                    child: AssistantPortrait(),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: AssistantPortrait(imagePath: settings.assistantImagePath),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      s.tr(
                        '長按頭像，或在設定頁，都可以換阿智的相片。',
                        '长按头像，或在设置页，都可以换阿智的照片。',
                        'Long-press the portrait, or open Settings, to change the photo.',
                      ),
                      style: TextStyle(color: p.onSurface, height: 1.35),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.pop(sheetContext, 'pick'),
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(s.tr('從相簿選擇', '从相册选择', 'Choose from gallery')),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(sheetContext, 'reset'),
                icon: const Icon(Icons.restart_alt_rounded),
                label: Text(s.tr('恢復預設頭像', '恢复默认头像', 'Use the default portrait')),
              ),
            ],
          ),
        ),
      );
    },
  );
  if (!context.mounted || choice == null) return;
  if (choice == 'reset') {
    await settings.updateAssistantImagePath('');
    return;
  }
  try {
    final shot = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 720,
      imageQuality: 85,
    );
    if (shot == null) return;
    final bytes = await shot.readAsBytes();
    final dir = await getApplicationDocumentsDirectory();
    final dest = File('${dir.path}/assistant_portrait.jpg');
    await dest.writeAsBytes(bytes, flush: true);
    await settings.updateAssistantImagePath(dest.path);
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          s.tr(
            '未能讀取相片，請再選一次。',
            '未能读取照片，请再选一次。',
            'Could not read that photo. Please try another one.',
          ),
        ),
      ),
    );
  }
}
