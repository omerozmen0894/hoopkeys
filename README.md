# Hoop Keys

Flutter ve Firebase ile hazırlanmış dokun-aç engelli, sıralamalı ve çok oyunculu mobil oyun prototipi.

## Oyun

- Top üstten bırakılır.
- Kapalı engeller topun yolunu keser.
- Engellere dokunarak onları açarsın.
- Amaç topu alttaki hedef bölgeye en az hamle ve en kısa sürede ulaştırmaktır.
- Skor Firebase Firestore leaderboard koleksiyonuna yazılır.
- Çok oyunculu modda oda oluşturulur veya oda koduyla katılınır; iki oyuncu aynı seviye üzerinde skor yarışı yapar.

## Çalıştırma

Bu klasörde Flutter SDK kurulu olduğunda:

```powershell
flutter pub get
flutter run
```

Bu makinede `flutter` komutu PATH içinde bulunamadığı için burada çalıştırma yapılamadı.

## Firebase bağlama

1. Firebase Console içinde proje oluştur.
2. Android ve iOS uygulamalarını ekle.
3. Anonymous Authentication etkinleştir.
4. Firestore Database oluştur.
5. `firestore.rules` dosyasını Firestore Rules olarak yayınla.
6. FlutterFire CLI ile gerçek ayarları üret:

```powershell
dart pub global activate flutterfire_cli
flutterfire configure
```

Bu işlem `lib/firebase_options.dart` dosyasındaki placeholder değerleri gerçek proje ayarlarıyla değiştirmeli.

Firebase ayarları yapılmamışsa oyun yerel demo modunda açılır; leaderboard ve oda özellikleri ekranda pasif bilgi verir.
