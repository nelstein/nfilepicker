import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photo_manager/photo_manager.dart';

class PickerState {
  Map<AssetPathEntity, AssetPage> pathMap;
  List<AssetPathEntity> pathList;
  List<AssetEntity> selectedData;
  AssetPathEntity current;
  RequestType type;

  int get selectedCount => selectedData.length;

  bool containsEntity(AssetEntity entity) {
    return selectedData.map((e) => e.id).contains(entity.id);
  }

  int indexOfSelected(AssetEntity entity) {
    return selectedData.map((e) => e.id).toList().indexOf(entity.id);
  }

  var camera = AssetEntity(
      id: 'camera',
      isFavorite: false,
      height: 100,
      typeInt: 0,
      orientation: 90,
      width: 100);

  AssetPage? getPaging() => pathMap[current];

  bool get noMore => getPaging()?.noMore ?? false;

  PickerState(
      {required this.current,
      this.pathList = const [],
      required this.pathMap,
      this.selectedData = const [],
      this.type = RequestType.all});

  PickerState copyWith({
    Map<AssetPathEntity, AssetPage>? pathMap,
    List<AssetPathEntity>? pathList,
    List<AssetEntity>? selectedData,
    AssetPathEntity? current,
    RequestType? type,
  }) {
    return PickerState(
      pathList: pathList ?? this.pathList,
      pathMap: pathMap ?? this.pathMap,
      selectedData: selectedData ?? this.selectedData,
      type: type ?? this.type,
      current: current ?? this.current,
    );
  }
}

class PickerProvider extends Cubit<PickerState> {
  PickerProvider()
      : super(PickerState(
            current: AssetPathEntity()
              ..name = 'Loading...'
              ..id = 'loading',
            pathMap: Map<AssetPathEntity, AssetPage>()));

  Future<bool> refreshGallery({RequestType? type, bool clear = false}) async {
    var _list = await PhotoManager.getAssetPathList(
      type: type ?? RequestType.image,
    );
    if (_list.isNotEmpty) {
      _list.sort((s1, s2) {
        return s2.assetCount.compareTo(s1.assetCount);
      });

      emit(state.copyWith(pathList: _list));
      await onPathChange(_list.first);
      return true;
    }
    return false;
  }

  onPathChange(AssetPathEntity path) async {
    emit(state.copyWith(current: path));
    await loadMore();
  }

  addPickedAsset(List<AssetEntity> list, int limit) {
    for (final entity in list) {
      if (state.selectedData.length == limit) {
        return false;
      }
      addSelectEntity(entity);
    }
  }

  bool removeSelectEntity(AssetEntity entity) {
    if (!state.containsEntity(entity)) {
      return false;
    }
    var list = state.selectedData.toList();
    list.removeWhere((e) => e.id == entity.id);
    emit(state.copyWith(selectedData: list));
    return true;
  }

  Future<bool> loadMore() async {
    var paging = state.getPaging();
    if (paging == null) {
      paging ??= AssetPage(state.current);
    }
    await paging.loadMore();
    var pathMap = state.pathMap;
    pathMap[state.current] = paging;
    emit(state.copyWith(pathMap: pathMap));

    return true;
  }

  clearPickedAsset() {
    emit(state.copyWith(selectedData: []));
  }

  bool addSelectEntity(AssetEntity entity) {
    if (state.containsEntity(entity)) {
      return false;
    }
    emit(state.copyWith(selectedData: state.selectedData + [entity]));
    return true;
  }
}

class AssetPage {
  int page = 0;

  Map<String, AssetEntity> data = Map<String, AssetEntity>();

  final AssetPathEntity path;

  final int pageCount;

  bool noMore = false;

  AssetPage(this.path, {this.pageCount = 50}) {
    loadMore();
  }

  Future<void> loadMore() async {
    if (noMore == true) {
      return;
    }
    var _data = await path.getAssetListPaged(page, pageCount);
    if (_data.length == 0) {
      noMore = true;
    }
    page++;
    _data.forEach((element) {
      data[element.id] = element;
    });
  }
}
