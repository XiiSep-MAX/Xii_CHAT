import 'package:flutter/material.dart';

import 'models.dart';

class AppChromePalette {
  static const accent = Color(0xFF60A5FA);
  static const text = Color(0xFFE2E8F0);
  static const textMuted = Color(0xFF94A3B8);
  static const textSoft = Color(0xFF7C8AA5);
  static const borderSoft = Color(0x334C6A95);
}

class ComposerImagePreview extends StatelessWidget {
  final List<ChatImageAttachment> attachments;
  final ValueChanged<int>? onRemoveAt;
  final Widget Function(ChatImageAttachment attachment) previewBuilder;

  const ComposerImagePreview({
    super.key,
    required this.attachments,
    required this.previewBuilder,
    this.onRemoveAt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppChromePalette.borderSoft,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '已选择参考图（${attachments.length} 张）',
                  style: const TextStyle(
                    color: AppChromePalette.text,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: attachments.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final attachment = attachments[index];
                      return SizedBox(
                        width: 72,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: previewBuilder(attachment),
                                ),
                                Positioned(
                                  top: 3,
                                  right: 3,
                                  child: Material(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(999),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(999),
                                      onTap: onRemoveAt == null
                                          ? null
                                          : () => onRemoveAt!(index),
                                      child: const Padding(
                                        padding: EdgeInsets.all(3),
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 11,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              attachment.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppChromePalette.textMuted,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ComposerPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const ComposerPill({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: enabled
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.white.withValues(alpha: 0.025),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppChromePalette.borderSoft,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: enabled
                    ? AppChromePalette.accent
                    : AppChromePalette.textSoft.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: enabled
                      ? AppChromePalette.text
                      : AppChromePalette.textSoft.withValues(alpha: 0.78),
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

class ComposerDropdownPill extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final String Function(String value) displayBuilder;
  final ValueChanged<String>? onChanged;

  const ComposerDropdownPill({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.displayBuilder,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150, maxWidth: 210),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppChromePalette.borderSoft,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          borderRadius: BorderRadius.circular(18),
          dropdownColor: const Color(0xFF16233D),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppChromePalette.textMuted,
          ),
          style: const TextStyle(
            color: AppChromePalette.text,
            fontWeight: FontWeight.w600,
          ),
          selectedItemBuilder: (context) => items
              .map(
                (item) => Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$label · ${displayBuilder(item)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: onChanged == null
              ? null
              : (nextValue) {
                  if (nextValue != null) {
                    onChanged!(nextValue);
                  }
                },
          items: items
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    '$label · ${displayBuilder(item)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}
