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
git diff --check
```

`Test-Static.ps1`, PowerShell dosyalarını parse eder; yerelleştirme ve kritik
invariant kontrollerini yapar. `Test-Automation.ps1`, provider fixture
değerlerini, örnek ayarları, tedarik zinciri kısıtlarını, kurtarma hook'larını,
log davranışını ve çıktı adlandırmasını doğrular.

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
imajı, locale, seçilmiş build ve revision değerini, boot image, WinRE yapısını
ve korunan zorunlu uygulamaları doğrular.

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

ISO yanındaki JSON manifestini ve ilgili logları test kaydıyla birlikte tutun.
