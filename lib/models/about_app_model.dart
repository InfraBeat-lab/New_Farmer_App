import 'package:flutter/material.dart';

class AboutAppModel {
  final String content;

  AboutAppModel({required this.content});

  factory AboutAppModel.fromJson(Map<String, dynamic> json) {
    final content = json['data']?.toString() ?? '';
    debugPrint("App Content: $content");
    return AboutAppModel(content: content);
  }
}







