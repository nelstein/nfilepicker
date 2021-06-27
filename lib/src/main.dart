import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:nlazyloader/nlazyloader.dart';
import 'provider.dart';
import 'util.dart';
import 'dart:async';

class MediaType {
  static const String image = 'image/jpeg;image/jpg;image/png';
  static const String video = 'video/*';
  static const String file = "application/*";
  static const String all = '.jpg,.png,.jpeg,video/*';
}

class MediaPicker {
  MediaPicker._();

  static Future<List<AssetData>?> picker(
    BuildContext context, {
    List<AssetData>? data,
    RequestType? type,
    int? limit,
    Widget? emptyView,
  }) async {
    await context.read<PickerProvider>().refreshGallery(type: type);
    return _pick(context, data: data, limit: limit, emptyView: emptyView);
  }

  // static Future<List<AssetData>> pickWeb(
  //     BuildContext context, PickerProvider provider,
  //     {String type = MediaType.all,
  //     bool multiple = true,
  //     int limit = 2}) async {
  //   var imageArr = ['image/jpeg', 'image/jpg', 'image/png', 'video/*'];
  //   final html.FileUploadInputElement input = html.FileUploadInputElement();
  //   input..accept = type;
  //   input..multiple = multiple;
  //   input.click();
  //   await input.onChange.first;
  //   var list = input.files.toList();
  //   if (input.files.isEmpty) return null;
  //   if (input.files.length > limit) {
  //     toaster('Maximum number of files exceeded');
  //     list = list.sublist(0, limit - 1);
  //   }

  //   return Future.wait(list
  //       .map((element) async {
  //         var data = AssetData();
  //         if (type == MediaType.image && element.size > 5 * 1024000) {
  //           toaster("File can not be larger than 5 MB");
  //           return null;
  //         }
  //         if (!imageArr.contains(element.type)) {
  //           toaster("Invalid file format.");
  //           return null;
  //         }
  //         final imageName = element.name;
  //         final imagePath = element.relativePath;
  //         final _type = element.type;
  //         final reader = html.FileReader();
  //         var file = input.files.first;
  //         reader.readAsDataUrl(file);

  //         await reader.onLoad.first;
  //         data.file = file;
  //         final encoded = reader.result as String;
  //         final stripped =
  //             encoded.replaceFirst(RegExp(r'data:image/[^;]+;base64,'), '');
  //         data.data = base64.decode(stripped);
  //         data.id = DateTime.now().millisecondsSinceEpoch.toString();
  //         data.name = imageName;
  //         data.path = imagePath;
  //         data.mimeType = _type;
  //         data.size = element.size;
  //         return data;
  //       })
  //       .toList()
  //       .where((element) => element != null)
  //       .toList());
  // }

  static Future<List<AssetData>?> _pick(
    BuildContext context, {
    List<AssetData>? data,
    int? limit,
    Widget? emptyView,
  }) async {
    List<AssetData> data = [];
    if (kIsWeb) {
      var _data = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.image,
        allowCompression: true,
      );
      if (_data != null && _data.count > 0) {
        List<PlatformFile> files = _data.files;
        if (_data.count > 2) {
          files = _data.files.sublist(0, 1);
          toaster('Maximum of two images allowed');
        }
        data = files
            .map((e) => AssetData(
                id: e.name,
                path: e.path,
                data: e.bytes,
                size: e.size,
                mimeType: 'image'))
            .toList();
      }
    } else {
      data = await Navigator.of(context, rootNavigator: true)
          .push(MaterialPageRoute(
        builder: (context) => PickerPage(
          limit: limit,
        ),
      ));
    }
    return data;
  }

  static Future<List<AssetData>> pickDocument() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'ppt',
          'pptx',
          'mp4',
          'mp3',
          'zip',
          'rar',
          'xls',
          'xlsx'
        ]);
    if (result == null || result.count == 0) return [];
    return result.files
        .map((e) => AssetData(
            id: e.name,
            path: e.path,
            data: e.bytes,
            size: e.size,
            mimeType: 'image'))
        .toList();
  }
}

class PickerPage extends StatelessWidget {
  final int? limit;
  final String? type;
  PickerPage({
    Key? key,
    this.limit,
    this.type,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PickerProvider, PickerState>(builder: (context, state) {
      dropHeader() {
        return Container(
            child: DropdownButtonHideUnderline(
          child: DropdownButton(
              iconEnabledColor: Colors.white,
              iconDisabledColor: Colors.white70,
              selectedItemBuilder: (context) {
                return state.pathList.map<Widget>((e) {
                  return Container(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      e.name,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .headline6!
                          .copyWith(color: Colors.white),
                    ),
                  );
                }).toList();
              },
              value: state.current,
              items: state.pathList.map((e) {
                return DropdownMenuItem(
                  child: Text(e.name),
                  value: e,
                );
              }).toList(),
              onChanged: (dynamic val) {
                context.read<PickerProvider>().onPathChange(val);
              }),
        ));
      }

      return WillPopScope(
        onWillPop: () {
          context.read<PickerProvider>().clearPickedAsset();
          return Future.value(true);
        },
        child: Scaffold(
            appBar: AppBar(
              iconTheme: IconThemeData(color: Colors.white),
              backgroundColor: Colors.black,
              title: dropHeader(),
              actions: <Widget>[
                TextButton(
                    child: Text(
                      'Done',
                      style: TextStyle(color: Colors.white),
                    ),
                    onPressed: () async {
                      var files = await convertToAssetData(state.selectedData);
                      Navigator.of(context).pop(files);
                    })
              ],
            ),
            backgroundColor: Colors.black87,
            body: state.current.id == 'loading'
                ? state.pathMap.isEmpty
                    ? buildEmpty('List is empty')
                    : buildLoading(context, color: Colors.white)
                : GalleryListPage(
                    limit: limit,
                  )),
      );
    });
  }
}

class GalleryListPage extends StatelessWidget {
  const GalleryListPage({
    Key? key,
    this.limit = 2,
  }) : super(key: key);

  final int? limit;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PickerProvider, PickerState>(builder: (context, state) {
      var data = ([state.camera] +
          (state.pathMap[state.current]?.data.values.toList() ?? []));

      _onItemClick(AssetEntity data) {
        {
          if (state.containsEntity(data)) {
            return context.read<PickerProvider>().removeSelectEntity(data);
          } else {
            if (data.type == AssetType.video &&
                state.selectedData
                    .where((e) => e.type == AssetType.image)
                    .isEmpty)
              return state.selectedData.isEmpty
                  ? context.read<PickerProvider>().addSelectEntity(data)
                  : SnackBar(content: Text('Maximum number selected'));

            if (data.type == AssetType.image &&
                state.selectedData
                    .where((e) => e.type == AssetType.video)
                    .isEmpty) {
              return state.selectedData.length < limit!
                  ? context.read<PickerProvider>().addSelectEntity(data)
                  : SnackBar(content: Text('Maximum number selected'));
            }
            return SnackBar(
                content: Text('You can only choose either images or video'));
          }
        }
      }

      Widget _buildText(AssetEntity entity) {
        var isSelected = state.containsEntity(entity);
        Widget? child;
        BoxDecoration decoration;
        if (isSelected) {
          child = Text(
            (state.indexOfSelected(entity) + 1).toString(),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.0, color: Colors.black87),
          );
          decoration = BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: Colors.white),
          );
        } else {
          decoration = BoxDecoration(
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: Colors.white70),
          );
        }
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            decoration: decoration,
            alignment: Alignment.center,
            child: child,
          ),
        );
      }

      Widget _buildSelected(AssetEntity entity) {
        return Positioned(
          right: 0.0,
          width: 36.0,
          height: 36.0,
          child: GestureDetector(
            onTap: () {
              _onItemClick(entity);
            },
            behavior: HitTestBehavior.translucent,
            child: _buildText(entity),
          ),
        );
      }

      _buildMask(bool showMask) {
        return IgnorePointer(
          child: AnimatedContainer(
            color:
                showMask ? Colors.white.withOpacity(0.5) : Colors.transparent,
            duration: Duration(milliseconds: 300),
          ),
        );
      }

      _loadMore() async {
        await context.read<PickerProvider>().loadMore();
      }

      Widget _buildItem(BuildContext context, int index) {
        final noMore = state.noMore;
        if (!noMore && index == data.length) {
          _loadMore();
          return buildLoading(context);
        }

        defaultItem(AssetEntity data) {
          return GestureDetector(
            child: Container(
              decoration: BoxDecoration(
                  border: Border(
                      top: BorderSide(color: Colors.white12),
                      bottom: BorderSide(color: Colors.white12),
                      left: BorderSide(color: Colors.white12))),
              child: Center(
                  child: data.id == 'camera'
                      ? Icon(
                          Icons.photo_camera_outlined,
                          color: Colors.white,
                          size: 30,
                        )
                      : Container()),
            ),
            onTap: () async {
              if (data.id == 'camera') {
                var file =
                    await (ImagePicker().getImage(source: ImageSource.camera)
                        as FutureOr<PickedFile>);
                AssetData entity = AssetData(
                  path: file.path,
                  mimeType: 'image',
                );
                Navigator.of(context).pop([entity]);
              }
            },
          );
        }

        var item = data[index];
        return item.id == 'camera'
            ? defaultItem(item)
            : RepaintBoundary(
                child: GestureDetector(
                  onTap: () => _onItemClick(item),
                  child: Stack(
                    children: <Widget>[
                      ImageItem(
                        entity: item,
                        size: 200,
                      ),
                      _buildMask(state.containsEntity(item)),
                      _buildSelected(item),
                    ],
                  ),
                ),
              );
      }

      return NLazyLoader(
          items: data,
          onLoadMore: context.read<PickerProvider>().loadMore,
          child: CustomScrollView(slivers: [
            SliverGrid.count(
                crossAxisCount: 3,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
                children: List.generate(
                  data.length,
                  (int index) {
                    return _buildItem(context, index);
                  },
                ))
          ]));
    });
  }
}
