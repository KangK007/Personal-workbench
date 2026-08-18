// THESIS: 每日工作是一张可操作的研究台面，不是指标卡片墙。
// OWN-WORLD: 清爽灰白底色、翠绿主操作、暖橙点缀，以现代卡片和刻度组织内容。
// STORY: 先看今天，再收集、安排、专注，最后进入日记与回顾。
// FIRST VIEWPORT: 桌面是分组侧栏、今日时间线和三项重点；手机纵向呈现同一节奏。
// FORM: Operate 模式的 Windows/Android 自适应应用，遵循 Material 3 平台规则。

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  const databasePath = String.fromEnvironment('WORKBENCH_DATABASE_PATH');
  SupabaseClient? client;
  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );
    client = Supabase.instance.client;
  }

  runApp(
    PersonalWorkbenchApp(
      supabaseClient: client,
      databasePath: databasePath.isEmpty ? null : databasePath,
    ),
  );
}
