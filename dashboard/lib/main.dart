import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'src/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = true;
  runApp(const TrailifyDashboardApp());
}
