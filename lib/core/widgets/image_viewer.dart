import 'package:flutter/material.dart';
import '../design/design.dart';

/// Full-screen, in-app image viewer: pinch zoom + pan, a close button, system back / swipe-down to leave, a loading state and an error
/// state with "Try again". The picture is decoded from the network into memory only (Flutter's in-memory image cache); app code never writes
/// it to disk, never offers to save it, and never logs the URL (signed links must not leak).
///
/// [refreshUrl] (optional) returns a fresh link; "Try again" calls it first, so a retry after a signed link expired gets a new one.
class ImageViewer extends StatefulWidget {
  const ImageViewer({super.key, required this.url, this.title = '', this.refreshUrl});
  final String url;
  final String title;
  final Future<String?> Function()? refreshUrl;

  static const double minScale = 1;
  static const double maxScale = 5;

  /// Test seam: how a URL becomes an [ImageProvider]. Defaults to [NetworkImage] (what `Image.network` uses; no disk cache).
  static ImageProvider Function(String url) providerFor = NetworkImage.new;

  static Future<void> open(BuildContext context, {required String url, String title = '', Future<String?> Function()? refreshUrl}) =>
      Navigator.of(context).push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => ImageViewer(url: url, title: title, refreshUrl: refreshUrl)));

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> {
  late String _url = widget.url;
  final _transform = TransformationController();
  int _attempt = 0;
  bool _failed = false;
  bool _retrying = false;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    final refresh = widget.refreshUrl;
    if (refresh != null) {
      try {
        final fresh = await refresh();
        if (fresh != null && fresh.isNotEmpty) _url = fresh;
      } catch (_) {
        // keep the old link; the image request below reports the failure
      }
    }
    if (!mounted) return;
    await ImageViewer.providerFor(_url).evict();
    if (!mounted) return;
    setState(() {
      _retrying = false;
      _failed = false;
      _attempt++;
    });
  }

  void _markFailed() {
    if (_failed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _failed = true);
    });
  }

  Widget _body() {
    if (_retrying) return const Center(child: _OnLight(child: EmLoading()));
    if (_failed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(EmSpacing.s16),
          child: Container(
            key: const Key('image_viewer_error'),
            decoration: const BoxDecoration(color: EmColors.surface, borderRadius: EmRadius.mdAll),
            padding: const EdgeInsets.all(EmSpacing.s8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              EmErrorState(
                key: const Key('image_viewer_error_state'),
                title: 'Photo could not be loaded',
                message: 'The link may have expired. Check your connection and try again.',
                onRetry: _retry,
                retryLabel: 'Try again',
                scroll: false,
                compact: true,
              ),
              EmTextAction(key: const Key('image_viewer_error_close'), label: 'Close', onPressed: () => Navigator.of(context).pop()),
            ]),
          ),
        ),
      );
    }
    return InteractiveViewer(
      key: const Key('image_viewer_zoom'),
      transformationController: _transform,
      minScale: ImageViewer.minScale,
      maxScale: ImageViewer.maxScale,
      onInteractionEnd: (d) {
        final v = d.velocity.pixelsPerSecond;
        final unzoomed = _transform.value.getMaxScaleOnAxis() <= 1.01;
        if (unzoomed && v.dy > 900 && v.dy.abs() > v.dx.abs() * 2) Navigator.of(context).maybePop();
      },
      child: Center(
        child: Image(
          key: ValueKey('image_viewer_image_$_attempt'),
          image: ImageViewer.providerFor(_url),
          fit: BoxFit.contain,
          // frameBuilder (not loadingBuilder): it also covers the time before the first byte arrives, when no progress event exists yet.
          frameBuilder: (c, child, frame, sync) => frame == null && !sync ? const Center(child: _OnLight(child: EmLoading(label: 'Loading photo'))) : child,
          errorBuilder: (c, e, s) {
            _markFailed();
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.title.trim().isEmpty ? 'Photo' : widget.title.trim();
    return Scaffold(
      key: const Key('image_viewer'),
      backgroundColor: EmColors.scrim,
      body: SafeArea(
        child: Stack(children: [
          Positioned.fill(
            child: Semantics(label: label, image: true, child: _body()),
          ),
          PositionedDirectional(
            top: EmSpacing.s8,
            start: EmSpacing.s8,
            child: EmIconCircleButton(key: const Key('image_viewer_close'), icon: Icons.close_rounded, semanticLabel: 'Close photo', tooltip: 'Close', onTap: () => Navigator.of(context).pop()),
          ),
        ]),
      ),
    );
  }
}

class _OnLight extends StatelessWidget {
  const _OnLight({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(color: EmColors.surface, borderRadius: EmRadius.mdAll),
        child: Padding(padding: const EdgeInsets.all(EmSpacing.s16), child: child),
      );
}
