extension MapExtensions on Map<String, dynamic> {
  void renameKey(String oldKey, String newKey) {
    if (containsKey(oldKey)) {
      this[newKey] = remove(oldKey);
    }
  }
}

extension NullExtensions on dynamic {
  String toClearStr() {
    return '${this ?? ''}';
  }

  String? toNullableStr() {
    return this != null ? '$this' : null;
  }
}
