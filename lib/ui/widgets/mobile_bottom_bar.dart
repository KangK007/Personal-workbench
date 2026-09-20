import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 移动端底栏单项（方案 C 规格）。
@immutable
class MobileBottomBarItem {
  const MobileBottomBarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// 移动端底部导航。
///
/// 与 Material `NavigationBar` 的差别来自方案 C 的明确要求：
///
/// * **选中态 = 主色图标与文字 + 标签下方 16×2.5 短指示条**，不使用胶囊底座。
///   `NavigationBar` 的 `indicator` 只能画在图标背后，且无法落到文字下方，
///   所以这里自建——不是重复造轮子，是默认控件给不出这个形态。
/// * 容器 58 高、实色底、顶缘 1px 分隔线。
///
/// 触摸目标：每项在 58 高的栏内等宽铺开，手机上宽度必然 ≥ 48dp。
class MobileBottomBar extends StatelessWidget {
  const MobileBottomBar({
    super.key,
    required this.selectedIndex,
    required this.items,
    required this.onSelected,
  });

  final int selectedIndex;
  final List<MobileBottomBarItem> items;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: tokens.panel,
        border: Border(top: BorderSide(color: tokens.panelBorder)),
      ),
      child: Row(
        children: [
          for (var index = 0; index < items.length; index++)
            Expanded(
              child: _MobileBottomBarTile(
                item: items[index],
                selected: index == selectedIndex,
                onTap: () => onSelected(index),
                selectedColor: scheme.primary,
                unselectedColor: tokens.mutedText,
              ),
            ),
        ],
      ),
    );
  }
}

class _MobileBottomBarTile extends StatelessWidget {
  const _MobileBottomBarTile({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.selectedColor,
    required this.unselectedColor,
  });

  final MobileBottomBarItem item;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedColor;
  final Color unselectedColor;

  @override
  Widget build(BuildContext context) {
    final color = selected ? selectedColor : unselectedColor;
    return Semantics(
      button: true,
      selected: selected,
      child: Tooltip(
        message: item.label,
        child: Material(
          // 本地 Material：让水波纹画在容器实色之上，否则会被底色盖住。
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: AppIconSize.sm,
                  color: color,
                ),
                const SizedBox(height: 3),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.15,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                // 指示条常驻占位（未选中为透明），避免选中时整项纵向跳动。
                Container(
                  width: 16,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: selected ? selectedColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
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
