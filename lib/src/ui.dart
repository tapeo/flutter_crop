import 'dart:ui' as ui;
import 'dart:math';

import 'package:crop/src/geometry_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class Crop extends StatefulWidget {
  final Widget child;
  final Color backgroundColor;
  final Color dimColor;
  final EdgeInsetsGeometry padding;
  final Color borderColor;
  final double borderWidth;
  final CropController controller;
  Crop({
    Key key,
    @required this.child,
    @required this.controller,
    this.padding: const EdgeInsets.all(8),
    this.dimColor: const Color.fromRGBO(0, 0, 0, 0.8),
    this.backgroundColor: Colors.black,
    this.borderColor: Colors.white,
    this.borderWidth: 2
  }) : super(key: key);
  @override
  State<StatefulWidget> createState() {
    return _CropState();
  }
}

class _CropState extends State<Crop> with TickerProviderStateMixin {
  final _key = GlobalKey();

  double _previousScale = 1;
  Offset _previousOffset = Offset.zero;
  Offset _startOffset = Offset.zero;
  Offset _endOffset = Offset.zero;

  AnimationController _controller;
  CurvedAnimation _animation;

  @override
  void initState() {
    widget.controller.addListener(_reCenterImage);

    //Setup animation.
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 200),
    );

    _animation = CurvedAnimation(curve: Curves.easeInOut, parent: _controller);
    _animation.addListener(() {
      setState(() {});
    });
    super.initState();
  }

  void _reCenterImage() {
    final sz = _key.currentContext.size;
    final s = widget.controller._scale * widget.controller._getMinScale();
    final w = sz.width;
    final h = sz.height;
    final canvas = Rect.fromLTWH(0, 0, w, h);
    final image = getRotated(
        canvas, widget.controller._rotation, s, widget.controller._offset);
    _startOffset = widget.controller._offset;
    _endOffset = widget.controller._offset;

    if (widget.controller._rotation < 0) {
      final tl = line(image.topRight, image.topLeft, canvas.topLeft);
      final tr = line(image.bottomRight, image.topRight, canvas.topRight);
      final br = line(image.bottomLeft, image.bottomRight, canvas.bottomRight);
      final bl = line(image.topLeft, image.bottomLeft, canvas.bottomLeft);

      final dtl = side(image.topRight, image.topLeft, canvas.topLeft);
      final dtr = side(image.bottomRight, image.topRight, canvas.topRight);
      final dbr = side(image.bottomLeft, image.bottomRight, canvas.bottomRight);
      final dbl = side(image.topLeft, image.bottomLeft, canvas.bottomLeft);

      if (dtl > 0) {
        final d = canvas.topLeft - tl;
        _endOffset += d;
      }

      if (dtr > 0) {
        final d = canvas.topRight - tr;
        _endOffset += d;
      }

      if (dbr > 0) {
        final d = canvas.bottomRight - br;
        _endOffset += d;
      }
      if (dbl > 0) {
        final d = canvas.bottomLeft - bl;
        _endOffset += d;
      }
    } else {
      final tl = line(image.topLeft, image.bottomLeft, canvas.topLeft);
      final tr = line(image.topLeft, image.topRight, canvas.topRight);
      final br = line(image.bottomRight, image.topRight, canvas.bottomRight);
      final bl = line(image.bottomLeft, image.bottomRight, canvas.bottomLeft);

      final dtl = side(image.topLeft, image.bottomLeft, canvas.topLeft);
      final dtr = side(image.topRight, image.topLeft, canvas.topRight);
      final dbr = side(image.bottomRight, image.topRight, canvas.bottomRight);
      final dbl = side(image.bottomLeft, image.bottomRight, canvas.bottomLeft);

      if (dtl > 0) {
        final d = canvas.topLeft - tl;
        _endOffset += d;
      }

      if (dtr > 0) {
        final d = canvas.topRight - tr;
        _endOffset += d;
      }

      if (dbr > 0) {
        final d = canvas.bottomRight - br;
        _endOffset += d;
      }
      if (dbl > 0) {
        final d = canvas.bottomLeft - bl;
        _endOffset += d;
      }
    }

    widget.controller._offset = _endOffset;

    if (_controller.isCompleted || _controller.isAnimating) {
      _controller.reset();
    }
    _controller.forward();

    setState(() {});
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    widget.controller._offset += details.focalPoint - _previousOffset;
    _previousOffset = details.focalPoint;
    widget.controller._scale = _previousScale * details.scale;
    _startOffset = widget.controller._offset;
    _endOffset = widget.controller._offset;

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.controller._rotation / 180.0 * pi;
    final s = widget.controller._scale * widget.controller._getMinScale();
    final o = Offset.lerp(_startOffset, _endOffset, _animation.value);

    return LayoutBuilder(
      builder: (context, constraints) {
        final sz = Size(constraints.maxWidth, constraints.maxHeight);

        final insets = widget.padding.resolve(Directionality.of(context));
        final v = insets.left + insets.right;
        final h = insets.top + insets.bottom;
        final size = getSizeToFitByRatio(
          widget.controller._aspectRatio,
          sz.width - v,
          sz.height - h,
        );

        final offset = Offset(
          sz.width - size.width,
          sz.height - size.height,
        ).scale(0.5, 0.5);

        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Container(color: widget.backgroundColor),
              Padding(
                padding: widget.padding,
                child: FittedBox(
                  child: SizedBox.fromSize(
                    size: size,
                    child: RepaintBoundary(
                      key: widget.controller._previewKey,
                      child: IgnorePointer(
                        key: _key,
                        child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..translate(o.dx, o.dy, 0)
                              ..rotateZ(r)
                              ..scale(s, s, 1),
                            child: widget.child),
                      ),
                    ),
                  ),
                ),
              ),
              ClipPath(
                clipper: _InvertedRectangleClipper(offset & size),
                child: IgnorePointer(
                  child: Container(color: widget.dimColor),
                ),
              ),
              Padding(
                padding: widget.padding,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox.fromSize(
                    size: size,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: widget.borderColor, width: widget.borderWidth),
                      ),
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onScaleStart: (details) {
                  _previousOffset = details.focalPoint;
                  _previousScale = max(widget.controller._scale, 1);
                },
                onScaleUpdate: _onScaleUpdate,
                onScaleEnd: (details) {
                  widget.controller._scale = max(widget.controller._scale, 1);
                  _reCenterImage();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    widget.controller.removeListener(_reCenterImage);
    super.dispose();
  }
}

class _InvertedRectangleClipper extends CustomClipper<Path> {
  final Rect rect;
  _InvertedRectangleClipper(this.rect);

  @override
  Path getClip(Size size) {
    return Path()
      ..addRect(rect)
      ..addRect(Rect.fromLTWH(0.0, 0.0, size.width, size.height))
      ..fillType = PathFillType.evenOdd;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class CropController extends ChangeNotifier {
  final _previewKey = GlobalKey();
  double _aspectRatio = 1;
  double _rotation = 0;
  double _scale = 1;
  Offset _offset = Offset.zero;

  double get aspectRatio => _aspectRatio;
  set aspectRatio(double value) {
    _aspectRatio = value;
    notifyListeners();
  }

  double get scale => max(_scale, 1);
  set scale(double value) {
    _scale = max(value, 1);
    notifyListeners();
  }

  double get rotation => _rotation;
  set rotation(double value) {
    _rotation = value;
    notifyListeners();
  }

  Offset get offset => _offset;
  set offset(Offset value) {
    _offset = value;
    notifyListeners();
  }

  CropController({
    double aspectRatio: 1.0,
    double scale: 1.0,
    double rotation: 0,
  }) {
    _aspectRatio = aspectRatio;
    _scale = scale;
    _rotation = rotation;
  }

  double _getMinScale() {
    final r = _rotation / 180.0 * pi;
    final rabs = r.abs();

    final sinr = sin(rabs);
    final cosr = cos(rabs);

    final x = cosr * _aspectRatio + sinr;
    final y = sinr * _aspectRatio + cosr;

    return max(x / _aspectRatio, y);
  }

  /// Capture an image of the current state of this widget and its children.
  ///
  /// The returned [ui.Image] has uncompressed raw RGBA bytes, will have
  /// dimensions equal to the size of the [child] widget multiplied by [pixelRatio].
  ///
  /// The [pixelRatio] describes the scale between the logical pixels and the
  /// size of the output image. It is independent of the
  /// [window.devicePixelRatio] for the device, so specifying 1.0 (the default)
  /// will give you a 1:1 mapping between logical pixels and the output pixels
  /// in the image.
  Future<ui.Image> crop({double pixelRatio: 1}) {
    RenderRepaintBoundary rrb = _previewKey.currentContext.findRenderObject();
    return rrb.toImage(pixelRatio: pixelRatio);
  }
}
