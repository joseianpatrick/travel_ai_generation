import 'dart:async';

import 'package:base_project/data/repository/repository.dart';

/// In-memory [Repository] fake with deterministic ids for tests.
class FakeRepository<T> implements Repository<T> {
  final Map<String, T> _items = {};
  final StreamController<List<T>> _controller = StreamController.broadcast();
  int _idCounter = 0;

  void _emit() => _controller.add(_items.values.toList());

  @override
  Stream<List<T>> watch() async* {
    yield _items.values.toList();
    yield* _controller.stream;
  }

  @override
  Future<T?> getById(String id) async => _items[id];

  @override
  Future<void> create(String id, T value) async {
    _items[id] = value;
    _emit();
  }

  @override
  Future<void> update(String id, Map<String, Object?> data) async {}

  @override
  Future<void> delete(String id) async {
    _items.remove(id);
    _emit();
  }

  @override
  String newId() => 'id_${_idCounter++}';

  void emitError(Object error) => _controller.addError(error);

  void close() => _controller.close();
}
