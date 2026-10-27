import 'package:flutter/services.dart';

void init() {}
void tick() => HapticFeedback.lightImpact();
void selection() => HapticFeedback.selectionClick();
void confirm() => HapticFeedback.mediumImpact();
