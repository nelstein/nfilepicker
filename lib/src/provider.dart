import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class PickerProvider extends ChangeNotifier {
  Map<AssetPathEntity?, AssetPage> _pathMap = {};
  List<AssetPathEntity> pathList = [];
  List<AssetEntity> selectedData = [];

  AssetPathEntity? _current;
  AssetPathEntity? get current => _current;

  RequestType? _type;

  set current(AssetPathEntity? current) {
    _current = current;
    if (_pathMap[current] == null) {
      final paging = AssetPage(current);
      _pathMap[current] = paging;
    }
  }

  void refreshGallery({RequestType? type, bool clear = true}) async {
    if (clear) {
      _pathMap.clear();
      pathList.clear();
    }

    var _list = await PhotoManager.getAssetPathList(
      type: type ?? RequestType.image,
      hasAll: true,
    );
    _type = type ?? RequestType.image;
    if (_list != null && _list.isNotEmpty) {
      _list.sort((s1, s2) {
        return s2.assetCount.compareTo(s1.assetCount);
      });

      current = _list.first;
      pathList.addAll(_list);
      await loadMore();
      notifyListeners();
    }
  }

  onPathChange(AssetPathEntity? path) async {
    if (path != current) {
      current = path;
      await loadMore();
      notifyListeners();
    }
  }

  String? get currentGalleryName {
    if (current == null) return null;
    return current!.isAll ? current?.name : "Gallery";
  }

  List<AssetEntity> get data => [
        AssetEntity(
            id: 'camera',
            isFavorite: false,
            height: 100,
            typeInt: 0,
            orientation: 90,
            width: 100),
      ].followedBy(_pathMap[current]?.data ?? []).toList();

  int get selectedCount => selectedData.length;

  bool containsEntity(AssetEntity entity) {
    return selectedData.contains(entity);
  }

  int indexOfSelected(AssetEntity entity) {
    return selectedData.indexOf(entity);
  }

  Future togglePickEntity() async {
    List<AssetEntity> notExistsList = [];
    selectedData.forEach((entity) async {
      var exists = await entity.exists;
      if (!exists) {
        notExistsList.add(entity);
      }
      selectedData.removeWhere((e) {
        return notExistsList.contains(e);
      });
      notifyListeners();
    });
  }

  addPickedAsset(List<AssetEntity> list, int limit) {
    for (final entity in list) {
      if (selectedData.length == limit) {
        return false;
      }
      addSelectEntity(entity);
    }
  }

  clearPickedAsset() {
    selectedData.clear();
    notifyListeners();
  }

  bool addSelectEntity(AssetEntity entity) {
    if (containsEntity(entity)) {
      return false;
    }
    selectedData.add(entity);
    notifyListeners();
    return true;
  }

  bool removeSelectEntity(AssetEntity entity) {
    if (!containsEntity(entity)) {
      return false;
    }
    selectedData.remove(entity);
    notifyListeners();
    return true;
  }

  void compareAndRemoveEntities(List<AssetEntity> previewSelectedList) {
    var srcList = List.of(selectedData);
    selectedData.clear();
    srcList.forEach((entity) {
      if (previewSelectedList.contains(entity)) {
        selectedData.add(entity);
      }
    });
  }

  Future<void> loadMore() async {
    final paging = getPaging();
    if (paging != null) {
      await paging.loadMore();
    }
    notifyListeners();
  }

  AssetPage? getPaging() => _pathMap[current];

  bool get noMore => getPaging()?.noMore ?? false;

  int get count => data.length;
}

class AssetPage {
  int page = 0;

  List<AssetEntity> data = [];

  final AssetPathEntity? path;

  final int pageCount;

  bool noMore = false;

  AssetPage(this.path, {this.pageCount = 50});

  Future<void> loadMore() async {
    if (noMore == true) {
      return;
    }

    var data = await path!.getAssetListPaged(page, pageCount);
    if (data.length == 0) {
      noMore = true;
    }
    page++;
    this.data.addAll(data);
  }
}
