# Şema Sürüm 3 Profilleri

WinISOUtil profilleri etkileşimli import ve katılımsız çalışmalar için
incelenmiş özelleştirme seçimlerini saklar. Yeni export dosyaları
`SchemaVersion: 3` kullanır.

## Sözleşme

Sürüm 2, aylık AppX paket sürümü değişiklikleri incelenmiş kaldırma seçimlerini
bozmasın diye kararlı `RemovedAppSelectors` değerlerini ekledi. Sürüm 3 kararlı
`RemovedCapabilities` ve `DisabledFeatures` dizilerini ekler; servis seçimlerini
`ComponentServiceTweaks` altında ayrı tutar.

```json
{
  "SchemaVersion": 3,
  "RemovedAppSelectors": [],
  "RemovedCapabilities": [],
  "DisabledFeatures": [],
  "RegistryTweaks": [],
  "EnabledFeatures": [],
  "ComponentServiceTweaks": []
}
```

Bütün ID değerleri `src\` altındaki allow-list tanımlarına göre doğrulanır.
Bilinmeyen ID değerleri ve enable/disable çakışmaları fail closed davranışıyla
reddedilir. Sürüm 1 profilleri tek seferlik kullanım için okunur. Sürüm 2
profilleri zamanlanmış otomasyonda migration uyarısıyla desteklenir.

## İncelenmiş Profil Oluşturma

1. Yükseltilmiş PowerShell penceresi açıp `.\winisoutil.ps1` çalıştırın.
2. Güncel baseline ISO ve otomasyonda kullanacağınız edition değerini seçin.
3. İncelenmiş servis, registry, AppX, capability, feature-disable ve
   feature-enable tercihlerini uygulayın.
4. Ana menüden `9. Ayarları Dışa Aktar (.json)` seçeneğini seçin.
5. Profili public repo dışında tutun, örneğin:

```text
D:\WinISOUtil\config\desktop-v3.json
```

6. Ortaya çıkan ISO'yu disposable Hyper-V VM üzerinde doğrulayın.

## Sürüm 2 Profilini Migrate Etme

Migration komutu mevcut profili değiştirmeden önce timestamp içeren yedek
oluşturur:

```powershell
.\automation\Convert-WinIsoUtilProfile.ps1 `
  -Path 'D:\WinISOUtil\config\desktop-v2.json' `
  -InPlace
```

Eski `RemoveIE` ve `RemoveWMP` değerleri `DisabledFeatures` alanına normalize
edilir. Mevcut AppX, registry, feature-enable ve servis seçimleri değişmez.

## Profili Doğrudan Kullanma

```powershell
.\winisoutil.ps1 `
  -Unattended `
  -Language tr `
  -IsoPath 'D:\ISO\Windows11.iso' `
  -ConfigurationPath 'D:\WinISOUtil\config\desktop-v3.json' `
  -EditionIndex 1 `
  -OutputIsoPath 'D:\ISO\out\Windows11-by-WinISOUtil.iso'
```

Katılımsız çıktı yanında `<iso>.validation.json` raporu oluşturulur. Strict
offline uyumsuzluklar ISO tamamlamasını durdurur.

## Profilleri Zamanlanmış Otomasyonda Kullanma

Bir hedef override tanımlamadıkça `DefaultConfigurationPath` bütün hedeflere
uygulanır:

```json
{
  "DefaultConfigurationPath": "D:\\WinISOUtil\\config\\desktop-v3.json",
  "Targets": [
    { "Id": "tr-tr-pro", "Locale": "tr-tr" },
    {
      "Id": "de-de-pro",
      "Locale": "de-de",
      "ConfigurationPath": "D:\\WinISOUtil\\config\\desktop-de-v3.json"
    }
  ]
}
```

Feature sürümü veya anlamlı özelleştirme değişiklikleri sonrasında profili
tekrar inceleyin. Kararlı ID değerleri aylık bakımı azaltır ancak kurulum
doğrulamasının yerini tutmaz.
