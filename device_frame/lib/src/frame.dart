import 'package:flutter/material.dart';

import 'info/device_type.dart';
import 'info/info.dart';

/// Simulate a physical device and embedding a virtual
/// [screen] into it.
///
/// The [screen] media query's `padding`, `devicePixelRatio`, `size` are also
/// simulated from the device's info by overriding the default values.
///
/// The [screen]'s [Theme] will also have the `platform` of the simulated device.
///
/// Using the [DeviceFrame.identifier] constructor will load an
/// svg file from assets first to get device frame visuals, but also
/// device info.
///
/// To preload the info, the [DeviceFrame.info] constructor can be
/// used instead.
///
/// See also:
///
/// * [Devices] to get all available devices.
///
class DeviceFrame extends StatelessWidget {
  /// The screen that should be inserted into the simulated
  /// device.
  ///
  /// It is cropped with the device screen shape and its size
  /// is the [info]'s screensize.
  final Widget screen;

  /// All information related to the device.
  final DeviceInfo device;

  /// The current frame simulated orientation.
  ///
  /// It will also affect the media query.
  final Orientation orientation;

  /// Indicates whether the device frame is visible, else
  /// only the screen is displayed.
  final bool isFrameVisible;

  /// Sets device frame scale factor. If null, device frame fits to its
  /// container
  final double? scaleFactor;

  Size get actualSize =>
      device.isLandscape(orientation) ? _frameSize.flipped : _frameSize;

  final Size _frameSize;
  final Path _screenPath;
  final double _actualScale;

  /// Displays the given [screen] into the given [info]
  /// simulated device.
  ///
  /// The orientation of the device can be updated if the frame supports
  /// it (else it is ignored).
  ///
  /// If [isFrameVisible] is `true`, only the [screen] is displayed, but
  /// clipped with the device screen shape.
  const DeviceFrame._(
    Key? key,
    this.device,
    this.screen,
    this.orientation,
    this.isFrameVisible,
    this.scaleFactor,
    this._frameSize,
    this._screenPath,
    this._actualScale,
  ) : super(key: key);

  factory DeviceFrame({
    Key? key,
    required DeviceInfo device,
    required Widget screen,
    Orientation orientation = Orientation.portrait,
    bool isFrameVisible = true,
    double? scaleFactor,
  }) {
    final actualScale = (scaleFactor ?? 1.0) *
        device.screenSize.width /
        device.screenPath.getBounds().width;
    final frameSize = device.frameSize * actualScale;
    final scaleMatrix = Matrix4.identity()..scale(actualScale);
    final screenPath = device.screenPath.transform(scaleMatrix.storage);

    return DeviceFrame._(
      key,
      device,
      screen,
      orientation,
      isFrameVisible,
      scaleFactor,
      frameSize,
      screenPath,
      actualScale,
    );
  }

  /// Creates a [MediaQuery] from the given device [info], and for the current device [orientation].
  ///
  /// All properties that are not simulated are inherited from the current [context]'s inherited [MediaQuery].
  static MediaQueryData mediaQuery({
    required BuildContext context,
    required DeviceInfo? info,
    required Orientation orientation,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final isRotated = info?.isLandscape(orientation) ?? false;
    final viewPadding = isRotated
        ? (info?.rotatedSafeAreas ?? info?.safeAreas)
        : (info?.safeAreas ?? mediaQuery.padding);

    final screenSize = info != null ? info.screenSize : mediaQuery.size;
    final width = isRotated ? screenSize.height : screenSize.width;
    final height = isRotated ? screenSize.width : screenSize.height;

    return mediaQuery.copyWith(
      size: Size(width, height),
      padding: viewPadding,
      viewInsets: EdgeInsets.zero,
      viewPadding: viewPadding,
      devicePixelRatio: info?.pixelRatio ?? mediaQuery.devicePixelRatio,
    );
  }

  ThemeData _theme(BuildContext context) {
    final density = [
      DeviceType.desktop,
      DeviceType.laptop,
    ].contains(device.identifier.type)
        ? VisualDensity.compact
        : null;
    return Theme.of(context).copyWith(
      platform: device.identifier.platform,
      visualDensity: density,
    );
  }

  Widget _screen(BuildContext context, DeviceInfo? info) {
    final mediaQuery = MediaQuery.of(context);
    final isRotated = info?.isLandscape(orientation) ?? false;
    final screenSize = info != null ? info.screenSize : mediaQuery.size;
    final width = isRotated ? screenSize.height : screenSize.width;
    final height = isRotated ? screenSize.width : screenSize.height;

    return RotatedBox(
      quarterTurns: isRotated ? 1 : 0,
      child: SizedBox(
        width: width,
        height: height,
        child: MediaQuery(
          data: DeviceFrame.mediaQuery(
            info: info,
            orientation: orientation,
            context: context,
          ),
          child: Theme(
            data: _theme(context),
            child: screen,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenRect = _screenPath.getBounds();
    final stack = SizedBox(
      width: _frameSize.width,
      height: _frameSize.height,
      child: Stack(
        children: [
          if (isFrameVisible)
            Transform.scale(
              key: const Key('frame'),
              scale: _actualScale,
              alignment: Alignment.topLeft,
              child: CustomPaint(
                key: ValueKey(device.identifier),
                painter: device.framePainter,
              ),
            ),
          Positioned(
            key: const Key('Screen'),
            left: isFrameVisible ? screenRect.left : 0,
            top: isFrameVisible ? screenRect.top : 0,
            width: screenRect.width,
            height: screenRect.height,
            child: ClipPath(
              clipper: _ScreenClipper(_screenPath),
              child: FittedBox(
                child: _screen(context, device),
              ),
            ),
          ),
        ],
      ),
    );

    final isRotated = device.isLandscape(orientation);
    final rotated = RotatedBox(
      quarterTurns: isRotated ? -1 : 0,
      child: stack,
    );

    if (scaleFactor == null) {
      return FittedBox(
        child: rotated,
      );
    }

    return rotated;
  }
}

class _ScreenClipper extends CustomClipper<Path> {
  const _ScreenClipper(this.path);

  final Path? path;

  @override
  Path getClip(Size size) {
    final path = (this.path ?? (Path()..addRect(Offset.zero & size)));
    final bounds = path.getBounds();
    var transform = Matrix4.translationValues(-bounds.left, -bounds.top, 0);

    return path.transform(transform.storage);
  }

  @override
  bool shouldReclip(_ScreenClipper oldClipper) {
    return oldClipper.path != path;
  }
}
