import 'package:flutter/material.dart';

class AboutCompanyModel {
  final String content;

  AboutCompanyModel({required this.content});

  factory AboutCompanyModel.fromJson(Map<String, dynamic> json) {
    final content = json['data']?.toString() ?? '';
    debugPrint("Content: $content");
    return AboutCompanyModel(content: content);
  }
}







