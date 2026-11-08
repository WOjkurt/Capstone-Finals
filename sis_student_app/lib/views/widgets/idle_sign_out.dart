import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Signs the student out after a while with no taps, clicks, scrolls or typing, so a school lab computer
/// left open does not show their information to the next person.
class IdleSignOut extends StatefulWidget {
  final Duration timeout;
  final VoidCallback onTimeout;
  final Widget child;

  const IdleSignOut({super.key, required this.timeout, required this.onTimeout, required this.child});

  @override
  State<IdleSignOut> createState() => _IdleSignOutState();
}

class _IdleSignOutState extends State<IdleSignOut> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    _restart();
  }

  @override
  void dispose() {
    _timer?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    _restart();
    return false; // never swallow the key
  }

  void _restart() {
    _timer?.cancel();
    _timer = Timer(widget.timeout, () {
      if (mounted) widget.onTimeout();
    });
  }

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _restart(),
        onPointerSignal: (PointerSignalEvent _) => _restart(),
        onPointerMove: (_) => _restart(),
        child: widget.child,
      );
}
