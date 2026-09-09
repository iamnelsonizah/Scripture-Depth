import 'package:flutter/foundation.dart';

class ReaderNavigationRequest {
  final String bookCode;
  final String? bookName;
  final int chapter;
  final int? verse;

  const ReaderNavigationRequest({
    required this.bookCode,
    this.bookName,
    required this.chapter,
    this.verse,
  });
}

class ReaderNavigationService {
  static final ReaderNavigationService _instance = ReaderNavigationService._internal();
  factory ReaderNavigationService() => _instance;
  ReaderNavigationService._internal();

  final ValueNotifier<ReaderNavigationRequest?> navigationRequest =
      ValueNotifier<ReaderNavigationRequest?>(null);

  VoidCallback? switchToReadTab;

  void navigateTo({
    required String bookCode,
    String? bookName,
    required int chapter,
    int? verse,
  }) {
    navigationRequest.value = ReaderNavigationRequest(
      bookCode: bookCode,
      bookName: bookName,
      chapter: chapter,
      verse: verse,
    );
    switchToReadTab?.call();
  }
}
