import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Holds the shell's branch navigators in a [PageView] so tabs move under the
/// finger. Each child is a distinct branch navigator (not a duplicate shell),
/// so this avoids the "Duplicate GlobalKey" crash a naive PageView would cause.
class BranchPageView extends StatefulWidget {
  const BranchPageView({super.key, required this.navigationShell, required this.children});
  final StatefulNavigationShell navigationShell;
  final List<Widget> children;

  @override
  State<BranchPageView> createState() => _BranchPageViewState();
}

class _BranchPageViewState extends State<BranchPageView> {
  late final PageController _controller =
      PageController(initialPage: widget.navigationShell.currentIndex);

  @override
  void didUpdateWidget(BranchPageView old) {
    super.didUpdateWidget(old);
    // Keep the PageView in sync when a tab is changed elsewhere (nav pill / swipe).
    final target = widget.navigationShell.currentIndex;
    if (_controller.hasClients && _controller.page?.round() != target) {
      _controller.animateToPage(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPageChanged(int i) {
    if (i == widget.navigationShell.currentIndex) return;
    // `initialLocation: false` preserves each branch's own navigation stack.
    widget.navigationShell.goBranch(i, initialLocation: false);
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _controller,
      onPageChanged: _onPageChanged,
      physics: const ClampingScrollPhysics(),
      children: widget.children,
    );
  }
}
