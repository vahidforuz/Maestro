import 'package:flutter/material.dart';

const messageEmojis = <String, List<String>>{
  'Smileys': [
    '😀',
    '😃',
    '😄',
    '😁',
    '😆',
    '😅',
    '😂',
    '🤣',
    '😊',
    '🙂',
    '😉',
    '😍',
    '🥰',
    '😘',
    '😎',
    '🤔',
    '😢',
    '😭',
    '😮',
    '😴',
    '😇',
    '🙃',
    '😋',
    '😡',
    '🥳'
  ],
  'People': [
    '👋',
    '👍',
    '👎',
    '👏',
    '🙌',
    '🙏',
    '🤝',
    '💪',
    '👀',
    '🫶',
    '❤️‍🔥',
    '👨‍🎤',
    '👩‍🎤',
    '🧑‍🎤',
    '👩‍🏫',
    '👨‍🏫',
    '🧑‍🏫',
    '💃',
    '🕺',
    '👯',
    '🤗',
    '✌️',
    '👌',
    '🤟'
  ],
  'Animals': [
    '🐶',
    '🐱',
    '🐭',
    '🐰',
    '🦊',
    '🐻',
    '🐼',
    '🐨',
    '🐯',
    '🦁',
    '🐮',
    '🐷',
    '🐸',
    '🐵',
    '🐧',
    '🐦',
    '🦋',
    '🐝',
    '🐢',
    '🐬',
    '🦄',
    '🐾'
  ],
  'Food': [
    '🍎',
    '🍊',
    '🍋',
    '🍌',
    '🍉',
    '🍓',
    '🍒',
    '🥑',
    '🥕',
    '🍕',
    '🍔',
    '🍟',
    '🍣',
    '🍦',
    '🍩',
    '🎂',
    '☕',
    '🫖',
    '🥤',
    '🍪'
  ],
  'Activities': [
    '🎹',
    '🎸',
    '🎻',
    '🥁',
    '🎺',
    '🎷',
    '🎤',
    '🎧',
    '🎼',
    '🎵',
    '🎶',
    '🏆',
    '⚽',
    '🏀',
    '🎮',
    '🎨',
    '🎬',
    '🎉',
    '🎁',
    '📚'
  ],
  'Symbols': [
    '❤️',
    '🧡',
    '💛',
    '💚',
    '💙',
    '💜',
    '🖤',
    '🤍',
    '💯',
    '✨',
    '⭐',
    '🔥',
    '✅',
    '❌',
    '❗',
    '❓',
    '💬',
    '🔔',
    '➡️',
    '♬'
  ],
};

void insertMessageEmoji(TextEditingController controller, String emoji) {
  final value = controller.value;
  final selection = value.selection;
  final start = selection.isValid ? selection.start : value.text.length;
  final end = selection.isValid ? selection.end : value.text.length;
  controller.value = value.copyWith(
    text: value.text.replaceRange(start, end, emoji),
    selection: TextSelection.collapsed(offset: start + emoji.length),
    composing: TextRange.empty,
  );
}

class MessageEmojiPicker extends StatefulWidget {
  const MessageEmojiPicker({super.key});

  @override
  State<MessageEmojiPicker> createState() => _MessageEmojiPickerState();
}

class _MessageEmojiPickerState extends State<MessageEmojiPicker> {
  String category = messageEmojis.keys.first;

  @override
  Widget build(BuildContext context) {
    final emojis = messageEmojis[category]!;
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      child: SizedBox(
        width: size.width < 390 ? size.width - 40 : 350,
        height: size.height < 550 ? size.height - 80 : 410,
        child: Column(children: [
          const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('Choose emoji',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          SizedBox(
            height: 54,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final name in messageEmojis.keys)
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ChoiceChip(
                        label: Text(name),
                        selected: name == category,
                        onSelected: (_) => setState(() => category = name))),
            ]),
          ),
          Expanded(
            child: GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6),
                itemCount: emojis.length,
                itemBuilder: (_, index) => IconButton(
                    tooltip: emojis[index],
                    onPressed: () => Navigator.pop(context, emojis[index]),
                    icon: Text(emojis[index],
                        style: const TextStyle(fontSize: 25)))),
          ),
        ]),
      ),
    );
  }
}
