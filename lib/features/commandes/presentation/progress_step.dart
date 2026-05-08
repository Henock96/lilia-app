import 'package:flutter/material.dart';

class ProgressStep {
  final IconData icon;
  final String label;
  final bool isCompleted;
  final bool isCurrent;

  ProgressStep({
    required this.icon,
    required this.label,
    required this.isCompleted,
    required this.isCurrent,
  });
}
