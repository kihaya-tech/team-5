// ダークモード切り替えの状態を管理するProvider。
// 選択したテーマは端末のローカルストレージに保存し、再起動後も維持する。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeModeKey = 'theme_mode_is_dark';

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.light;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_themeModeKey);
    if (isDark == null) return;
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> toggle() async {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeModeKey, state == ThemeMode.dark);
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
