import 'package:shared_preferences/shared_preferences.dart';

import 'bookshelf_service.dart';

class PreferencesShelfStorage implements ShelfStorage {
  static const key = 'gitlore.bookshelf.v1';
  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(key);
  @override
  Future<void> write(String value) async {
    if (!await (await SharedPreferences.getInstance()).setString(key, value)) {
      throw StateError('Could not save projects on this device.');
    }
  }
}
