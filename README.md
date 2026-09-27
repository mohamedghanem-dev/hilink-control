# HiLink Control Hub

لوحة تحكم غير رسمية لراوتر Huawei B535 (HiLink API) — Flutter + Riverpod.
الألوان والأيقونة متجهزين على شعار **NEXUS NETWORK** (تيل غامق + سيان نيون + رمادي معدني).

## اللي جاهز فعلياً (تكامل حقيقي مع الراوتر، مش محاكاة)

- `lib/services/hilink_api_service.dart`: تسجيل دخول حقيقي (SesTokInfo → SHA256 login)، جلب الأجهزة المتصلة (`/api/wlan/host-list`)، حظر/فك حظر عبر `mac-filter`، **وضع الرعب** (حظر الكل ما عدا المسموح لهم)، حالة الراوتر والإشارة، تشغيل/إيقاف 2.4G و5G.
- تسمية الأجهزة: بتتخزن محلياً على التليفون (الراوتر مش بيدعم تسمية الأجهزة من الأساس).
- 4 شاشات: الرئيسية، إدارة الأجهزة، الأمان ووضع الرعب، الإعدادات (فيها التبديل بين الوضع الداكن/الفاتح/حسب النظام).
- **أيقونة التطبيق**: `assets/icon/icon.png` (شعار NEXUS NETWORK اللي بعتّه) — الـ GitHub Actions workflow بيولّدها لكل أحجام الأندرويد أوتوماتيك عند كل build، مش محتاج تعمل حاجة يدوي.
- GitHub Actions يبني APK تلقائي (ده اللي هيولّد أي ملف تحمّله — مش أنا).

## خطوة لازم تعملها قبل أول build (مرة واحدة بس)

الملفات دي هي كود Dart بس — مفيهاش مجلد `android/` (اللي فيه Gradle وملفات المشروع الأصلية للأندرويد) لأن ده بيتولد تلقائي من الـ Flutter SDK نفسه، مش حاجة أقدر أكتبها يدوي بشكل موثوق.

عندك Flutter SDK شغال بالفعل جوه Termux/proot-Ubuntu، فنفذ الأوامر دي جوه مجلد المشروع:

```bash
flutter create . --project-name hilink_control_hub --org com.yourname
```

ده هيولد `android/` (وiOS لو حابب لاحقاً) من غير ما يلمس `lib/` أو `pubspec.yaml` بتاعك.

بعدها، فعّل الـ HTTP الصريح للراوتر (لازم لأنه http مش https):

1. حط ملف `android_network_security_config.xml` الموجود في جذر المشروع في:
   `android/app/src/main/res/xml/network_security_config.xml`
2. في `android/app/src/main/AndroidManifest.xml`، جوه تاج `<application ...>` ضيف:
   ```xml
   android:networkSecurityConfig="@xml/network_security_config"
   android:usesCleartextTraffic="true"
   ```
3. وتحت في نفس الملف، فوق تاج `<application>`، تأكد إن الصلاحيات دي موجودة:
   ```xml
   <uses-permission android:name="android.permission.INTERNET"/>
   <uses-permission android:name="android.permission.ACCESS_WIFI_STATE"/>
   <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
   ```

بعد كده:
```bash
flutter pub get
flutter run   # للتجربة المحلية
```

## بناء الـ APK أوتوماتيك (GitHub Actions)

اعمل push للمشروع على GitHub (تأكد إن `android/` اتعمله commit بعد خطوة `flutter create` فوق)، والـ workflow في
`.github/workflows/build-apk.yml` هيشتغل لوحده ويبني الـ APK، وتقدر تنزله من تبويب **Actions → آخر run → Artifacts**.

لو عايز Release رسمي بالـ APK مرفق بيه:
```bash
git tag v1.0.0
git push --tags
```

## ملاحظات مهمة

- شيل أي صورة أو ملف فيه باسورد الأدمن الحقيقي أو اسم الشبكة قبل ما ترفع حاجة على مكان عام.
- أسماء الـ endpoints (زي `InterfaceType` لتحديد 2.4G/5G) بتختلف شوية حسب نسخة الفيرموير — لو لقيت الأجهزة مش بتتصنف صح، ابعتلي استجابة `/api/wlan/host-list` الخام (من غير باسورد) وأظبطها.
- `password_type` مضبوطة على `4` (SHA256) وهي الأكتر شيوعاً في B535 الحديث؛ لو فشل تسجيل الدخول، محتمل الفيرموير القديم محتاج `password_type=0`.
