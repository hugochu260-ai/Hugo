import 'package:camera/camera.dart';
import 'package:mediapipe_face_mesh/mediapipe_face_mesh.dart';

/// Converts camera plugin frames into mediapipe_face_mesh input types.
class CameraFrameAdapter {
  const CameraFrameAdapter._();

  static FaceMeshNv21Image? toNv21(CameraImage image) {
    final planes = image.planes;
    if (planes.isEmpty) return null;
    if ((image.width & 1) != 0 || (image.height & 1) != 0) return null;

    if (planes.length == 1) {
      return FaceMeshNv21Image.tryFromSinglePlane(
        bytes: planes.first.bytes,
        width: image.width,
        height: image.height,
        bytesPerRow: planes.first.bytesPerRow,
      );
    }
    if (planes.length == 2) {
      return FaceMeshNv21Image.tryFromYAndInterleavedVuPlanes(
        width: image.width,
        height: image.height,
        yPlane: _plane(planes[0]),
        vuPlane: _plane(planes[1]),
      );
    }
    return FaceMeshNv21Image.tryFromYuv420Planes(
      width: image.width,
      height: image.height,
      yPlane: _plane(planes[0]),
      uPlane: _plane(planes[1]),
      vPlane: _plane(planes[2]),
    );
  }

  static FaceMeshImage? toBgra(CameraImage image) {
    final planes = image.planes;
    if (planes.isEmpty) return null;
    final plane = planes.first;
    return FaceMeshImage(
      pixels: plane.bytes,
      width: image.width,
      height: image.height,
      bytesPerRow: plane.bytesPerRow,
      pixelFormat: FaceMeshPixelFormat.bgra,
    );
  }

  static FaceMeshImagePlane _plane(Plane p) => FaceMeshImagePlane(
        bytes: p.bytes,
        bytesPerRow: p.bytesPerRow,
        bytesPerPixel: p.bytesPerPixel,
      );
}
