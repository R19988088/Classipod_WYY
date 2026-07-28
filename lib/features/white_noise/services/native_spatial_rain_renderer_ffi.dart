import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

typedef _NativeSampleRate = Int32 Function();
typedef _DartSampleRate = int Function();
typedef _NativeRenderAlloc =
    Pointer<Int16> Function(Int32, Uint64, Int64, Int32);
typedef _DartRenderAlloc = Pointer<Int16> Function(int, int, int, int);
typedef _NativeFree = Void Function(Pointer<Int16>);
typedef _DartFree = void Function(Pointer<Int16>);

final class _NativeBindings {
  _NativeBindings(DynamicLibrary library)
    : sampleRate = library.lookupFunction<_NativeSampleRate, _DartSampleRate>(
        'classipod_spatial_rain_sample_rate',
      ),
      renderAlloc = library
          .lookupFunction<_NativeRenderAlloc, _DartRenderAlloc>(
            'classipod_spatial_rain_render_alloc',
          ),
      free = library.lookupFunction<_NativeFree, _DartFree>(
        'classipod_spatial_rain_free',
      );

  final _DartSampleRate sampleRate;
  final _DartRenderAlloc renderAlloc;
  final _DartFree free;
}

_NativeBindings? _loadBindings() {
  if (!Platform.isAndroid) return null;
  try {
    final bindings = _NativeBindings(
      DynamicLibrary.open('libclassipod_spatial_audio.so'),
    );
    return bindings.sampleRate() == 48000 ? bindings : null;
  } on Object {
    return null;
  }
}

final _NativeBindings? _bindings = _loadBindings();

Uint8List? renderNativeSpatialRain({
  required int scene,
  required int seed,
  required int startFrame,
  required int frameCount,
}) {
  final bindings = _bindings;
  if (bindings == null || frameCount <= 0) return null;
  final pointer = bindings.renderAlloc(scene, seed, startFrame, frameCount);
  if (pointer == nullptr) return null;
  try {
    return Uint8List.fromList(
      pointer.cast<Uint8>().asTypedList(frameCount * 4),
    );
  } finally {
    bindings.free(pointer);
  }
}
