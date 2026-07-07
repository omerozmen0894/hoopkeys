# Hoop Keys Magaza Yayin Checklist

## Google Play

- [ ] Google Play Console'da yeni uygulama olustur.
- [ ] Uygulama adi: Hoop Keys.
- [ ] Varsayilan dil: Turkce.
- [ ] Paket adi: `com.omergames.tapdroparena`.
- [ ] AAB dosyasini yukle: `dist/hoop_keys-playstore-v1.0.0+1.aab`.
- [ ] Uygulama simgesi olarak `store/assets/google_play_icon_512.png` yukle.
- [ ] Feature graphic olarak `store/assets/google_play_feature_1024x500.png` yukle.
- [ ] Telefon screenshotlari ekle.
- [ ] Kisa ve tam aciklamayi `store/STORE_LISTING_TR.md` dosyasindan gir.
- [ ] Gizlilik politikasi URL'si ekle.
- [ ] Data Safety formunda Firebase Auth/Firestore verilerini beyan et.
- [ ] Icerik derecelendirme formunu doldur.
- [ ] Kapali test veya ic test yayini olustur.

## App Store

- [ ] Apple Developer hesabinda App ID olustur: `com.omergames.hoopkeys`.
- [ ] Firebase iOS uygulamasini ayni bundle id ile ekle ve `GoogleService-Info.plist` dosyasini `ios/Runner` altina koy.
- [ ] Mac/Xcode uzerinden archive al ve App Store Connect'e yukle.
- [ ] Uygulama adi: Hoop Keys.
- [ ] Kategori: Games / Arcade.
- [ ] Screenshotlari App Store Connect'e yukle.
- [ ] App Privacy sorularini `store/PRIVACY_POLICY_TR.md` dosyasina gore doldur.
- [ ] Uygulama aciklamasini `store/STORE_LISTING_TR.md` dosyasindan gir.
- [ ] TestFlight ile test yayini yap.

## Notlar

Android Firebase paketi su an `com.omergames.tapdroparena` olarak bagli. Google Play'e cikmadan once paket adini degistirmek istersen Firebase Android app yeniden olusturulmalidir.

iOS IPA/Archive Windows uzerinde uretilemez; Mac ve Xcode gerekir.

