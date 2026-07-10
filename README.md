# شينيغامي - Flutter Application (Material 3) 🏆 😉 🕵️

Welcome to the **Shinigami** Flutter project! This folder contains a complete, robust, offline-first conversion of the original group party games application into **Flutter with Material 3**, preserving the entire visual layout, animations, Arabic content, offline database loading, and responsive design.

---

## 📱 Features Included

1. **الرئيسية (Home Dashboard)**:
   - Customized dark background with glowing Crimson red highlights.
   - Elegant, custom-rendered vector Oni/Shinigami mask.
   - Clean, interactive game launcher cards for the three main games.
   - Integrated Arabic language alignment (RTL) across all screens.

2. **بكاسة - الجاسوس (Spy Game)**:
   - Full player setup (from 3 to 20 players) with animated lists.
   - Categorized game launcher loading words directly from `assets/database.json`.
   - Pass-phone flow revealing cards and secret words to citizens and hiding them from the spy.
   - Dynamic questioning carousel pairs to ensure full discussion circle loops.
   - Ticking countdown discussion timer.
   - Secret-voting session and calculations determining winner teams (Citizens vs Spy).

3. **من غير كلام - الإشارة والتمثيل (Charades Game)**:
   - Fully loaded database category selector.
   - Customizable setup (number of teams from 2 to 4, customizable round counters, and customizable timer limit).
   - Dynamic gameplay card displaying active word, progress bar, correct answers, skips, and pause toggles.
   - Dynamic results ranking podiums for the best team!

4. **الغمزة - القاتل الصامت (Wink Game)**:
   - Live list of players where deceased ones tap ONLY their name to state they are dead (`💀 ميت`).
   - Real-time updating counters tracking **🟢 Alive Players** and **🔴 Dead Players**.
   - **بدء التصويت (Start Voting)** flow implementing secret votes.
   - Results screen announcing winner teams, murderer identity, most voted player, and vote counts breakdown.

5. **الإعدادات (Settings System)**:
   - Standard preferences modal sheet.
   - Toggle buttons to control Haptic Feedback/Vibration and Sound Effects offline using `shared_preferences`.

---

## 🛠️ Project Directory Tree

The Flutter structure is organized cleanly as follows:

```
/flutter_shinigami/
├── assets/
│   └── database.json          # Offline word collections
├── lib/
│   ├── main.dart              # Entry point + Home View + Settings Dialogue
│   ├── models.dart            # Data structures & schemas
│   ├── game_spy.dart          # بكاسة (The Spy Game)
│   ├── game_charades.dart     # من غير كلام (Charades Game)
│   └── game_wink.dart         # الغمزة (Silent Killer Game)
└── pubspec.yaml               # Project dependencies and configuration
```

---

## 🚀 How to Run the Flutter Project

To run this app on your local computer, simulator, or real Android/iOS device, follow these simple steps:

1. **Prerequisites**: Make sure you have the [Flutter SDK](https://docs.flutter.dev/get-started/install) installed on your machine.
2. **Open the Project Folder**:
   ```bash
   cd flutter_shinigami
   ```
3. **Download Dependencies**:
   ```bash
   flutter pub get
   ```
4. **Connect a Device**: Make sure you have an Android/iOS emulator running, or a physical device plugged in.
5. **Start Debugging**:
   ```bash
   flutter run
   ```

To build a production release ready for Google Play Store or Apple App Store:
```bash
# For Android APK
flutter build apk --release

# For iOS Bundle
flutter build ipa --release
```

---

## 📱 دليل المبتدئين خطوة بخطوة لبناء تطبيق الأندرويد (APK / AAB) 🚀

إذا كنت مبتدئاً تماماً في مجال البرمجة وتريد تحويل هذا المجلد إلى تطبيق جاهز للتثبيت على هاتفك الأندرويد فوراً، اتبع هذه الخطوات البسيطة والمفصلة:

### 1️⃣ الخطوة الأولى: تحميل وتثبيت الأدوات اللازمة على جهازك الكمبيوتر
لتحويل الكود إلى تطبيق حقيقي، تحتاج لتثبيت بيئة عمل مجانية تسمى **Flutter SDK**:
1. اذهب للموقع الرسمي لـ [Flutter](https://docs.flutter.dev/get-started/install) وحمّل النسخة المناسبة لنظام تشغيل جهازك (Windows أو macOS أو Linux).
2. قم بفك الضغط عن الملف في مكان ثابت على جهازك (مثلاً `C:\flutter`).
3. أضف مسار `flutter/bin` إلى متغيرات النظام البيئية (Environment Variables) لتتمكن من تشغيل أوامر فلاتر من أي مكان.
4. قم بتحميل وتثبيت برنامج **Android Studio** مجاناً من [هنا](https://developer.android.com/studio). أثناء التثبيت، ستقوم الأداة تلقائياً بتحميل الـ Android SDK وأدوات البناء اللازمة للأندرويد.

### 2️⃣ الخطوة الثانية: تحميل مجلد المشروع الخاص بك
1. قم بتحميل مجلد المشروع الكامل هذا (`flutter_shinigami`) كملف مضغوط ZIP من القائمة الجانبية (Settings -> Export ZIP) أو قم بتنزيله من مستودع GitHub.
2. قم بفك الضغط عنه في جهازك الكمبيوتر.

### 3️⃣ الخطوة الثالثة: تشغيل الأوامر لبناء التطبيق
1. افتح موجه الأوامر (CMD في ويندوز، أو Terminal في ماك).
2. انتقل إلى مجلد المشروع باستخدام أمر `cd` (مثال):
   ```bash
   cd path/to/flutter_shinigami
   ```
3. الآن، قم بتشغيل الأمر التالي للتأكد من ربط مكتبات المشروع وتنزيلها:
   ```bash
   flutter pub get
   ```
4. لبناء ملف الـ **APK** (الملف الجاهز للتثبيت على أي موبايل أندرويد فوراً وبدون إنترنت):
   ```bash
   flutter build apk --release
   ```
   *سيقوم محرك فلاتر ببناء نسخة محسنة ومضغوطة بالكامل وتطبيق ميزات Resource Shrinking و Minification لتقليل حجم التطبيق ورفع كفاءته للأقصى.*
5. بعد انتهاء البناء، ستجد ملف الـ APK جاهزاً في المسار التالي داخل مجلد المشروع:
   `build/app/outputs/flutter-apk/app-release.apk`
   *يمكنك نقله لموبايلك وتثبيته فوراً ولعب اللعبة بالكامل بدون إنترنت!*

6. إذا كنت ترغب في رفع التطبيق على متجر جوجل بلاي، قم بتشغيل هذا الأمر لبناء ملف **AAB** (Android App Bundle):
   ```bash
   flutter build appbundle --release
   ```
   ستجده في المسار:
   `build/app/outputs/bundle/release/app-release.aab`

Enjoy playing and coding! 🎮✨

