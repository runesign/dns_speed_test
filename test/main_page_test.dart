import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dns_speed_test/main.dart'; // 根据实际项目名更新
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('MainPage 有标题和语言按钮', (WidgetTester tester) async {
    // 模拟 SharedPreferences
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(MyApp(prefs: prefs));

    // 检查标题是否存在
    expect(find.text('DNS Speed Test'), findsOneWidget); // 用实际标题替换

    // 检查语言按钮是否存在
    expect(find.byIcon(Icons.language), findsOneWidget);

  });

}
