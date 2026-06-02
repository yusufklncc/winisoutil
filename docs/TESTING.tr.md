# Doğrulama ve Test

WinISOUtil yerel PowerShell mantığını, Windows servicing araçlarını, üçüncü taraf
metadata API'sini, Microsoft CDN payload dosyalarını ve boot edilebilir ISO
çıktısını birleştirir. Tek bir başarılı script çalışmasını tam kapsam olarak
kabul etmek yerine katmanlı doğrulama kullanın.

## Yerel Fixture Kontrolleri

Kod veya dokümantasyon değişikliklerinden sonra repo kökünde şu kontrolleri
çalıştırın:

```powershell
.\tests\Test-Static.ps1
.\tests\Test-Automation.ps1
.\tests\Test-ProfileValidation.ps1
git diff --check
```

`Test-Static.ps1`, PowerShell dosyalarını parse eder; yerelleştirme ve kritik
invariant kontrollerini yapar. `Test-Automation.ps1`, provider fixture
değerlerini, örnek ayarları, tedarik zinciri kısıtlarını, kurtarma hook'larını,
log davranışını ve çıktı adlandırmasını doğrular. `Test-ProfileValidation.ps1`,
Windows imajı mount etmeden şema migration, legacy normalizasyon, fail-closed
katalog, desired-state no-op, strict kontrol ve deferred post-login raporlama
davranışlarını doğrular.

## Verifier-Only Kontrolü

UUP assembly veya debloat aşamasını tekrar çalıştırmadan mevcut ISO'yu
doğrulayın:

```powershell
.\automation\Test-WinIsoUtilIso.ps1 `
  -IsoPath 'D:\WinISOUtil\output\tr-tr-pro\Windows11-Pro-tr-tr-25H2-26200.8524-custom.iso' `
  -ConfigurationPath 'D:\WinISOUtil\config\desktop-v3.json'
```

Komut final install imajını read-only mount eder, profile-aware kontrolleri
çalıştırır ve `<iso>.validation.json` yazar.

## Canlı UUP API Smoke Testi

Bu opt-in test güncel UUP Dump API çağrılarını yapar ve Windows payload
dosyalarını indirmeden yapılandırılmış locale manifestlerini doğrular:

```powershell
.\tests\Test-LiveUupApi.ps1
```

Gerektiğinde locale değerlerini açıkça belirtin:

```powershell
.\tests\Test-LiveUupApi.ps1 -Locales @('tr-tr', 'en-us')
```

Canlı test hatasını entegrasyon sinyali olarak ele alın. Üretim politikasını
değiştirmeden önce nedenin yerel kod, ağ erişimi, upstream erişilebilirliği veya
upstream şema değişikliği olup olmadığını belirleyin.

## Hedef Bazlı Tam Üretim

Zamanlanmış batch'i etkinleştirmeden önce bir locale için manuel çalışma yapın:

```powershell
.\automation\Invoke-AutomatedBuild.ps1 `
  -SettingsPath '.\automation\settings.json' `
  -ToolsPinPath '.\automation\tools.pin.json' `
  -TargetId 'tr-tr-pro'
```

Otomasyon çıktıyı promote etmeden önce final ISO'yu mount eder; Professional
imajı, locale, seçilmiş build ve revision değerini, boot image, WinRE yapısını,
korunan zorunlu uygulamaları, strict offline profil state değerini ve deferred
post-login artefact dosyalarını doğrular.

## Hyper-V Kurulum Smoke Testi

İlk iki aylık çıktıda, her feature sürümü değişikliğinde, converter pin
değişikliğinde, profil değişikliğinde ve servicing mantığı değişikliğinde:

1. Disposable bir Generation 2 Hyper-V VM oluşturun.
2. Promote edilmiş ISO'dan boot edin.
3. Temiz kurulum yapın.
4. Kurulumun masaüstüne ulaştığını doğrulayın.
5. Beklenen locale ve edition değerini doğrulayın.
6. Ağ, Windows Security, Microsoft Store, kurtarma ortamı ve Windows Update
   işlevlerinin kullanılabilir kaldığını doğrulayın.
7. Seçilmiş uygulama kaldırma, servis, feature ve registry tercihlerinin
   beklendiği gibi davrandığını doğrulayın.
8. Masaüstündeki post-login BAT dosyasını manuel çalıştırıp Arama simgesi
   davranışını doğrulayın.

ISO yanındaki manifest, validation JSON ve ilgili logları test kaydıyla birlikte
tutun.
