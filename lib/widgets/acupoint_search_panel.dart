import 'package:flutter/material.dart';

import '../models/meridian.dart';

class AcupointSearchPanel extends StatelessWidget {
  const AcupointSearchPanel({
    super.key,
    required this.points,
    required this.meridians,
    required this.controller,
    required this.query,
    required this.onQueryChanged,
    required this.selectedMeridianId,
    required this.onMeridianChanged,
    required this.favoritesOnly,
    required this.onFavoritesOnlyChanged,
    required this.favoriteIds,
    required this.favoritesReady,
    required this.onFavoriteToggle,
    required this.onPointSelected,
  });

  static const _allMeridians = 'all';

  final List<Acupoint> points;
  final List<Meridian> meridians;
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final String selectedMeridianId;
  final ValueChanged<String> onMeridianChanged;
  final bool favoritesOnly;
  final ValueChanged<bool> onFavoritesOnlyChanged;
  final Set<String> favoriteIds;
  final bool favoritesReady;
  final ValueChanged<Acupoint> onFavoriteToggle;
  final ValueChanged<Acupoint> onPointSelected;

  List<Acupoint> _matchingPoints() {
    final normalizedQuery = _normalize(query.trim());
    return points.where((point) {
      if (selectedMeridianId != _allMeridians &&
          point.meridianId != selectedMeridianId) {
        return false;
      }
      if (favoritesOnly && !favoriteIds.contains(point.id)) return false;
      if (normalizedQuery.isEmpty) return true;

      final meridian = meridians.firstWhere(
        (item) => item.id == point.meridianId,
        orElse: () => meridians.first,
      );
      final searchable = _normalize([
        point.nameZh,
        point.pinyin,
        point.code,
        meridian.nameZh,
        meridian.pinyin,
        meridian.code,
      ].join(' '));
      return searchable.contains(normalizedQuery);
    }).toList(growable: false);
  }

  String _normalize(String value) {
    var normalized = value.toLowerCase();
    const folds = {
      'ā': 'a', 'á': 'a', 'ǎ': 'a', 'à': 'a',
      'ē': 'e', 'é': 'e', 'ě': 'e', 'è': 'e',
      'ī': 'i', 'í': 'i', 'ǐ': 'i', 'ì': 'i',
      'ō': 'o', 'ó': 'o', 'ǒ': 'o', 'ò': 'o',
      'ū': 'u', 'ú': 'u', 'ǔ': 'u', 'ù': 'u',
      'ǖ': 'v', 'ǘ': 'v', 'ǚ': 'v', 'ǜ': 'v', 'ü': 'v',
      'ḿ': 'm',
    };
    for (final entry in folds.entries) {
      normalized = normalized.replaceAll(entry.key, entry.value);
    }
    return normalized.replaceAll(RegExp(r'[\s·-]'), '');
  }

  @override
  Widget build(BuildContext context) {
    final shouldShowResults = query.trim().isNotEmpty ||
        favoritesOnly ||
        selectedMeridianId != _allMeridians;
    final results = shouldShowResults ? _matchingPoints() : const <Acupoint>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onQueryChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: '穴位名、拼音或代码（如合谷、hegu、LI4）',
                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF82928D)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '清除搜索',
                          onPressed: () {
                            controller.clear();
                            onQueryChanged('');
                          },
                          icon: const Icon(Icons.close_rounded, size: 17),
                        ),
                  filled: true,
                  fillColor: const Color(0xFF121D20),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF26383A)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF26383A)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF4A8275)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 7),
            IconButton.filledTonal(
              tooltip: favoritesOnly ? '显示全部穴位' : '只看收藏',
              onPressed: () => onFavoritesOnlyChanged(!favoritesOnly),
              icon: Icon(favoritesOnly ? Icons.star_rounded : Icons.star_border_rounded),
              style: IconButton.styleFrom(
                foregroundColor: const Color(0xFFD7C27D),
                backgroundColor: favoritesOnly
                    ? const Color(0xFF3A3422)
                    : const Color(0xFF1A282A),
                fixedSize: const Size(48, 48),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: selectedMeridianId,
          isExpanded: true,
          icon: const Icon(Icons.expand_more_rounded),
          dropdownColor: const Color(0xFF172326),
          style: const TextStyle(fontSize: 12, color: Color(0xFFD8E3DE)),
          decoration: InputDecoration(
            labelText: '按经络筛选',
            labelStyle: const TextStyle(fontSize: 11, color: Color(0xFF92A69F)),
            prefixIcon: const Icon(Icons.alt_route_rounded, size: 18),
            filled: true,
            fillColor: const Color(0xFF121D20),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF26383A)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF26383A)),
            ),
          ),
          items: [
            const DropdownMenuItem<String>(
              value: _allMeridians,
              child: Text('全部经络'),
            ),
            ...meridians.map((meridian) => DropdownMenuItem<String>(
                  value: meridian.id,
                  child: Text('${meridian.nameZh}  ${meridian.code}',
                      overflow: TextOverflow.ellipsis),
                )),
          ],
          onChanged: (value) {
            if (value != null) onMeridianChanged(value);
          },
        ),
        if (shouldShowResults) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                favoritesOnly ? '我的收藏' : '搜索结果',
                style: const TextStyle(fontSize: 12, color: Color(0xFFB6C8C2)),
              ),
              const Spacer(),
              Text('${results.length} 个穴位',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF81968F))),
            ],
          ),
          const SizedBox(height: 7),
          if (favoritesOnly && !favoritesReady)
            _emptyState('正在读取收藏…', Icons.more_horiz_rounded)
          else if (results.isEmpty)
            _emptyState('没有匹配的穴位，试试其他关键词或经络。', Icons.search_off_rounded)
          else
            ...results.map(_pointTile),
        ],
      ],
    );
  }

  Widget _pointTile(Acupoint point) {
    final meridian = meridians.firstWhere(
      (item) => item.id == point.meridianId,
      orElse: () => meridians.first,
    );
    final isFavorite = favoriteIds.contains(point.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF121D20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF26383A)),
      ),
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.only(left: 12, right: 4),
        onTap: () => onPointSelected(point),
        leading: Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: meridian.color, shape: BoxShape.circle),
        ),
        title: Text(
          '${point.nameZh}  ${point.code}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${point.pinyin}  ·  ${meridian.nameZh}',
          style: const TextStyle(fontSize: 10, color: Color(0xFF94AAA2)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          tooltip: isFavorite ? '取消收藏' : '收藏穴位',
          onPressed: () => onFavoriteToggle(point),
          icon: Icon(
            isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
            color: isFavorite ? const Color(0xFFE2C66E) : const Color(0xFF83958F),
            size: 21,
          ),
        ),
      ),
    );
  }

  Widget _emptyState(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF121D20),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: const Color(0xFF81968F)),
          const SizedBox(width: 9),
          Expanded(
            child: Text(message,
                style: const TextStyle(fontSize: 11, color: Color(0xFF9AABA5))),
          ),
        ],
      ),
    );
  }
}
