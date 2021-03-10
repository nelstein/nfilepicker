import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:nlazyloader/nlazyloader.dart';
import 'provider.dart';
import 'util.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:html' as html;

class MediaType {
  static const String image = 'image/jpeg;image/jpg;image/png';
  static const String video = 'video/*';
  static const String file = "application/*";
  static const String all = '.jpg,.png,.jpeg,video/*';
}

class MediaPicker {
  MediaPicker._();
  static void picker(
    BuildContext context, {
    List<AssetData> data,
    String type,
    int limit,
    Widget emptyView,
    Function(List<AssetData>) mulCallback,
  }) async {
    (kIsWeb
            ? pickWeb(context, type: type, limit: limit)
            : Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
                builder: (context) => PickerPage(
                  type: type,
                  limit: limit,
                ),
              )))
        .then((data) {
      if (data != null && mulCallback != null) {
        mulCallback(data);
      }
    });
  }

  static Future<List<AssetData>> pickWeb(BuildContext context,
      {String type = MediaType.all,
      bool multiple = true,
      int limit = 2}) async {
    var imageArr = ['image/jpeg', 'image/jpg', 'image/png', 'video/*'];
    final html.FileUploadInputElement input = html.FileUploadInputElement();
    input..accept = type;
    input..multiple = multiple;
    input.click();
    await input.onChange.first;
    var list = input.files.toList();
    if (input.files.isEmpty) return null;
    if (input.files.length > limit) {
      toaster('Maximum number of files exceeded');
      list = list.sublist(0, limit - 1);
    }

    return Future.wait(list
        .map((element) async {
          var data = AssetData();
          if (type == MediaType.image && element.size > 5 * 1024000) {
            toaster("File can not be larger than 5 MB");
            return null;
          }
          if (!imageArr.contains(element.type)) {
            toaster("Invalid file format.");
            return null;
          }
          final imageName = element.name;
          final imagePath = element.relativePath;
          final _type = element.type;
          final reader = html.FileReader();
          var file = input.files.first;
          reader.readAsDataUrl(file);

          await reader.onLoad.first;
          data.file = file;
          final encoded = reader.result as String;
          final stripped =
              encoded.replaceFirst(RegExp(r'data:image/[^;]+;base64,'), '');
          data.data = base64.decode(stripped);
          data.id = DateTime.now().millisecondsSinceEpoch.toString();
          data.name = imageName;
          data.path = imagePath;
          data.mimeType = _type;
          data.size = element.size;
          return data;
        })
        .toList()
        .where((element) => element != null)
        .toList());
  }

  static Future<List<AssetData>> pick(
    BuildContext context, {
    List<AssetData> data,
    String type,
    int limit,
    Widget emptyView,
  }) async {
    var data =
        await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
      builder: (context) => PickerPage(
        type: type,
        limit: limit,
      ),
    ));
    return data;
  }

  static Future<List<String>> pickDocument() async {
    FilePickerResult result = await FilePicker.platform.pickFiles(
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
    return result?.paths;
  }
}

class PickerPage extends StatefulWidget {
  final int limit;
  final String type;

  const PickerPage({
    Key key,
    this.limit,
    this.type,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return PickerPageState();
  }
}

class PickerPageState extends State<PickerPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<AssetEntity> data = [];
  bool _isInit = true;
  PickerProvider provider;
  @override
  void didChangeDependencies() {
    provider = Provider.of<PickerProvider>(context);
    super.didChangeDependencies();
    if (!_isInit) {
      provider.refreshGallery();
    }
  }

  @override
  Widget build(BuildContext context) {
    dropHeader() {
      return Container(
          child: isValid(provider.pathList)
              ? DropdownButtonHideUnderline(
                  child: DropdownButton(
                      iconEnabledColor:
                          Theme.of(context).brightness == Brightness.light
                              ? Colors.white
                              : null,
                      iconDisabledColor:
                          Theme.of(context).brightness == Brightness.light
                              ? Colors.white70
                              : null,
                      selectedItemBuilder: (context) {
                        item(AssetPathEntity e) {
                          return Container(
                            width: 120,
                            padding: EdgeInsets.only(top: 10),
                            child: Text(
                              e.name != 'Recent' ? e.name : 'Gallery',
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .headline6
                                  .copyWith(
                                      color: Theme.of(context).brightness ==
                                              Brightness.light
                                          ? Colors.white
                                          : null),
                            ),
                          );
                        }

                        return provider.pathList.map<Widget>((e) {
                          return item(e);
                        }).toList();
                      },
                      value: provider.current,
                      items: provider.pathList.map((e) {
                        var val = e.name != 'Recent' ? e.name : 'Gallery';
                        return DropdownMenuItem(
                          child: Text(
                            val,
                          ),
                          value: e,
                        );
                      }).toList(),
                      onChanged: (val) {
                        provider.onPathChange(val);
                      }),
                )
              : Text(''));
    }

    return WillPopScope(
      onWillPop: () {
        provider.clearPickedAsset();
        return Future.value(true);
      },
      child: Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            iconTheme: IconThemeData(color: Colors.white),
            backgroundColor: Colors.black,
            title: dropHeader(),
            actions: <Widget>[
              TextButton(
                  child: Text(
                    'Done',
                    style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.light
                            ? Colors.white
                            : null),
                  ),
                  onPressed: () async {
                    var files =
                        await convertToAssetData(provider.selectedData ?? []);
                    Navigator.of(context).pop(files);
                  })
            ],
          ),
          backgroundColor: Colors.black87,
          body: provider.current == null
              ? provider.pathList.isEmpty
                  ? buildEmpty('List is empty')
                  : buildLoading(context, color: Colors.white)
              : GalleryListPage(
                  path: provider.current,
                  provider: provider,
                  limit: widget.limit,
                  type: widget.type)),
    );
  }
}

class GalleryListPage extends StatefulWidget {
  const GalleryListPage(
      {Key key, this.path, this.provider, this.limit, this.type})
      : super(key: key);

  final AssetPathEntity path;
  final PickerProvider provider;
  final int limit;
  final String type;

  @override
  _GalleryListPageState createState() => _GalleryListPageState();
}

class _GalleryListPageState extends State<GalleryListPage> {
  AssetPathEntity get path => widget.path;
  PickerProvider provider;

  @override
  void initState() {
    provider = widget.provider;
    super.initState();
  }

  _onItemClick(AssetEntity data) {
    {
      if (provider.containsEntity(data)) {
        return provider.removeSelectEntity(data);
      } else {
        if (data.type == AssetType.video &&
            provider.selectedData
                .where((e) => e.type == AssetType.image)
                .isEmpty)
          return provider.selectedData.isEmpty
              ? provider.addSelectEntity(data)
              : SnackBar(content: Text('Maximum number selected'));

        if (data.type == AssetType.image &&
            provider.selectedData
                .where((e) => e.type == AssetType.video)
                .isEmpty) {
          return provider.selectedData.length < widget.limit
              ? provider.addSelectEntity(data)
              : SnackBar(content: Text('Maximum number selected'));
        }
        return SnackBar(
            content: Text('You can only choose either images or video'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget _buildText(AssetEntity entity) {
      var isSelected = provider.containsEntity(entity);
      Widget child;
      BoxDecoration decoration;
      if (isSelected) {
        child = Text(
          (provider.indexOfSelected(entity) + 1).toString(),
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
          color: showMask ? Colors.white.withOpacity(0.5) : Colors.transparent,
          duration: Duration(milliseconds: 300),
        ),
      );
    }

    _loadMore() async {
      await provider.loadMore();
      setState(() {});
    }

    Widget _buildItem(BuildContext context, int index) {
      final noMore = provider.noMore;
      if (!noMore && index == provider.count) {
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
                  await ImagePicker().getImage(source: ImageSource.camera);
              AssetData entity = AssetData(
                path: file.path,
                mimeType: 'image',
              );
              Navigator.of(context).pop([entity]);
            }
          },
        );
      }

      var data = provider.data[index];
      return data.id == 'camera'
          ? defaultItem(data)
          : RepaintBoundary(
              child: GestureDetector(
                onTap: () => _onItemClick(data),
                child: Stack(
                  children: <Widget>[
                    ImageItem(
                      entity: data,
                      size: 200,
                    ),
                    _buildMask(provider.containsEntity(data)),
                    _buildSelected(data),
                  ],
                ),
              ),
            );
    }
    return NLazyLoader(
        items: provider.data,
        onLoadMore: () => provider.loadMore(),
        child: CustomScrollView(slivers: [
          SliverGrid.count(
              crossAxisCount: 3,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              children: List.generate(
                provider.data?.length,
                (int index) {
                  return _buildItem(context, index);
                },
              ))
        ]));
  }
}
