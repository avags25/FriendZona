import 'dart:convert';

class FormValidation {
  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Введите email';
    if (email.length > 320 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Проверьте формат email';
    }
    return null;
  }

  static String? password(String? value) {
    final password = value ?? '';
    if (password.length < 12) {
      return 'Минимум 12 символов';
    }
    if (utf8.encode(password).length > 72) {
      return 'Пароль не должен превышать 72 байта';
    }
    return null;
  }

  static String? displayName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Введите имя';
    if (name.length > 80) return 'Не более 80 символов';
    return null;
  }
}
