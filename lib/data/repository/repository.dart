abstract interface class Repository<T> {
  Stream<List<T>> watch();
  Future<T?> getById(String id);
  Future<void> create(String id, T value);
  Future<void> update(String id, Map<String, Object?> data);
  Future<void> delete(String id);
  String newId();
}
