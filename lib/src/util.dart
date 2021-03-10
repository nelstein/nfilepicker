import 'dart:typed_data';
import 'dart:ui';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_editor/image_editor.dart';
import 'package:isolate/isolate.dart';
import 'package:photo_manager/photo_manager.dart';
import 'dart:collection';
import 'package:video_compress/video_compress.dart';

class AssetData {
  ///ios id与path不一致，Android id与path相同
  String id;
  String name;
  String path;
  String mimeType;
  int time;
  int width;
  int height;
  dynamic file;
  Duration duration;
  Uint8List data;
  Map youtube;
  int size;

  AssetData(
      {this.id,
      this.height,
      this.width,
      this.mimeType,
      this.name,
      this.path,
      this.time,
      this.data,
      this.file,
      this.size,
      this.duration,
      this.youtube});

  AssetData.fromJson(Map<dynamic, dynamic> json) {
    id = json["id"];
    name = json["name"];
    path = json["path"];
    mimeType = json["mimeType"];
    time = json["time"];
    width = json["width"];
    height = json["height"];
    data = json["data"];
    file = json['file'];
    size = json['size'];
    youtube = json['youtube'];
    duration = json['duration'];
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "path": path,
      "mimeType": mimeType,
      "time": time,
      "width": width,
      "height": height,
      "data": data,
      "file": file,
      "size": size,
      "duration": duration,
      "youtube": youtube
    };
  }

  bool get isImage => mimeType.contains("image") ?? false;

  bool get isYoutube => youtube != null;

  @override
  bool operator ==(Object other) {
    if (other is AssetData && runtimeType == other.runtimeType) {
      return id == other.id;
    } else {
      return false;
    }
  }

  @override
  int get hashCode {
    return id.hashCode;
  }
}

final loadBalancer = LoadBalancer.create(10, IsolateRunner.spawn);

Future<List<AssetData>> convertToAssetData(List<AssetEntity> data) async {
  return Future.wait(data.map((e) async {
    return AssetData(
        path: (await e.file).path,
        height: e.height,
        width: e.width,
        name: e.id,
        mimeType: e.type == AssetType.image ? 'image' : 'video',
        duration: Duration(seconds: e.duration),
        size: await (await e.file).length(),
        file: (await e.file),
        time: e.createDateTime.millisecondsSinceEpoch);
  }).toList());
}

Future<MediaInfo> trimVideo(String path) async {
  try {
    final info = await VideoCompress.compressVideo(
      path,
      quality:
          VideoQuality.MediumQuality, // default(VideoQuality.DefaultQuality)
      deleteOrigin: false, // default(false)
    );
    return info;
  } catch (e) {
    print(e);
    return null;
  }
}

Future<List<int>> cropImageDataWithDartLibrary(
    {ExtendedImageEditorState state}) async {
  print("dart library start cropping");

  final Rect rect = state.getCropRect();
  final EditActionDetails action = state.editAction;

  final rotateAngle = action.rotateAngle.toInt();
  final flipHorizontal = action.flipY;
  final flipVertical = action.flipX;
  final img = state.rawImageData;

  var time1 = DateTime.now();
  ImageEditorOption option = ImageEditorOption();

  if (action.needCrop) option.addOption(ClipOption.fromRect(rect));

  if (action.needFlip)
    option.addOption(
        FlipOption(horizontal: flipHorizontal, vertical: flipVertical));

  if (action.hasRotateAngle) option.addOption(RotateOption(rotateAngle));

  final result = await ImageEditor.editImage(
    image: img,
    imageEditorOption: option,
  );
  var time4 = DateTime.now();
  print("${time4.difference(time1)} : total time");

  return result;
}

Widget buildBadge(BuildContext context, AssetType type, Duration duration) {
  if (type == AssetType.video) {
    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: Align(
        alignment: Alignment.topLeft,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            borderRadius: BorderRadius.circular(3.0),
          ),
          child: Text(
            "video",
            style: const TextStyle(
              fontSize: 12.0,
              color: Colors.white,
            ),
          ),
          padding: const EdgeInsets.all(4.0),
        ),
      ),
    );
  }

  return Container();
}

Widget videoBadge(BuildContext context, AssetType type, Duration duration) {
  if (type == AssetType.video) {
    var s = duration.inSeconds % 60;
    var m = duration.inMinutes % 60;
    var h = duration.inHours;

    String text =
        "$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";

    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: Align(
        alignment: Alignment.bottomRight,
        child: Container(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12.0,
              color: Colors.white,
            ),
          ),
          padding: const EdgeInsets.all(4.0),
        ),
      ),
    );
  }

  return Container();
}

class ImageItem extends StatelessWidget {
  final AssetEntity entity;
  final int size;
  const ImageItem({
    Key key,
    this.entity,
    this.size = 64,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var thumb = ImageLruCache.getData(entity, size);
    if (thumb != null) {
      return _buildImageItem(context, thumb);
    }

    return FutureBuilder<Uint8List>(
      future: entity.thumbDataWithSize(size, size),
      builder: (BuildContext context, AsyncSnapshot<Uint8List> snapshot) {
        var futureData = snapshot.data;
        if (snapshot.connectionState == ConnectionState.done &&
            futureData != null) {
          ImageLruCache.setData(entity, size, futureData);
          return _buildImageItem(context, futureData);
        }
        return Container();
      },
    );
  }

  Widget _buildImageItem(BuildContext context, Uint8List data) {
    var image = Image.memory(
      data,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
    );
    var badge;
    final badgeBuilder = videoBadge(context, entity.type, entity.videoDuration);
    if (badgeBuilder == null) {
      badge = Container();
    } else {
      badge = badgeBuilder;
    }

    return Stack(
      children: <Widget>[
        image,
        IgnorePointer(
          child: badge,
        ),
      ],
    );
  }
}

class ImageLruCache {
  static LRUMap<_ImageCacheEntity, Uint8List> _map = LRUMap(500);

  static Uint8List getData(AssetEntity entity, [int size = 64]) {
    return _map.get(_ImageCacheEntity(entity, size));
  }

  static void setData(AssetEntity entity, int size, Uint8List list) {
    _map.put(_ImageCacheEntity(entity, size), list);
  }
}

class _ImageCacheEntity {
  AssetEntity entity;
  int size;

  _ImageCacheEntity(this.entity, this.size);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ImageCacheEntity &&
          runtimeType == other.runtimeType &&
          entity == other.entity &&
          size == other.size;

  @override
  int get hashCode => entity.hashCode ^ size.hashCode;
}

// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

typedef EvictionHandler<K, V>(K key, V value);

class LRUMap<K, V> {
  final LinkedHashMap<K, V> _map = LinkedHashMap<K, V>();
  final int _maxSize;
  final EvictionHandler<K, V> _handler;

  LRUMap(this._maxSize, [this._handler]);

  V get(K key) {
    V value = _map.remove(key);
    if (value != null) {
      _map[key] = value;
    }
    return value;
  }

  void put(K key, V value) {
    _map.remove(key);
    _map[key] = value;
    if (_map.length > _maxSize) {
      K evictedKey = _map.keys.first;
      V evictedValue = _map.remove(evictedKey);
      if (_handler != null) {
        _handler(evictedKey, evictedValue);
      }
    }
  }

  void remove(K key) {
    _map.remove(key);
  }
}

class ProgressColors {
  ProgressColors({
    Color playedColor: const Color.fromRGBO(256, 256, 256, 1),
    Color bufferedColor: const Color.fromRGBO(256, 256, 256, 0.5),
    Color handleColor: const Color.fromRGBO(255, 255, 255, 1),
    Color backgroundColor: const Color.fromRGBO(200, 200, 200, 0.5),
  })  : playedPaint = Paint()..color = playedColor,
        bufferedPaint = Paint()..color = bufferedColor,
        handlePaint = Paint()..color = handleColor,
        backgroundPaint = Paint()..color = backgroundColor;

  final Paint playedPaint;
  final Paint bufferedPaint;
  final Paint handlePaint;
  final Paint backgroundPaint;
}

String formatDuration(Duration position) {
  final ms = position.inMilliseconds;

  int seconds = ms ~/ 1000;
  final int hours = seconds ~/ 3600;
  seconds = seconds % 3600;
  var minutes = seconds ~/ 60;
  seconds = seconds % 60;

  final hoursString = hours >= 10
      ? '$hours'
      : hours == 0
          ? '00'
          : '0$hours';

  final minutesString = minutes >= 10
      ? '$minutes'
      : minutes == 0
          ? '00'
          : '0$minutes';

  final secondsString = seconds >= 10
      ? '$seconds'
      : seconds == 0
          ? '00'
          : '0$seconds';

  final formattedTime =
      '${hoursString == '00' ? '' : hoursString + ':'}$minutesString:$secondsString';

  return formattedTime;
}

bool isValid(item) {
  return item != null && item.isNotEmpty;
}

Container buildLoading(BuildContext context, {Color color, double width}) {
  return new Container(
    child: new Padding(
      padding: EdgeInsets.only(top: 20.0),
      child: new Center(
        child: Theme.of(context).platform != TargetPlatform.iOS
            ? CircularProgressIndicator(
                strokeWidth: width ?? 2.0,
                valueColor: new AlwaysStoppedAnimation<Color>(color ?? null),
              )
            : CupertinoActivityIndicator(),
      ),
    ),
  );
}

Container buildEmpty(String text, {double top}) {
  return Container(
    padding: EdgeInsets.only(top: top ?? 80),
    child: Center(
      child: Column(
        children: <Widget>[
          Text(text ?? 'Failed to load list',
              style: TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    ),
  );
}

toaster(String content) {
  return SnackBar(
    content: Text(content),
  );
}
