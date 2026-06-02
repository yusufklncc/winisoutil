# Şema Sürüm 2 Profilleri

WinISOUtil profilleri, etkileşimli import ve katılımsız çalışmalar için tekrar
kullanılabilir özelleştirme seçimlerini saklar. Sıfır dokunuş UUP otomasyonu
`SchemaVersion: 2` zorunluluğu koyar.

## Neden Sürüm 2

Windows provisioned app paket adları, aylık build'ler arasında değişebilen sürüm
bilgileri içerir. Sürüm 2, kararlı uygulama `DisplayName` değerlerini
`RemovedAppSelectors` olarak export eder. Katılımsız çalışma sırasında
WinISOUtil bu seçicileri mount edilmiş imajdaki paketlerle eşler, güncel paket
adlarını kaldırır ve seçilmiş uygulamaların artık mevcut olmadığını doğrular.

Sürüm 1 profilleri tek seferlik kullanım için okunmaya devam eder. Zamanlanmış
otomasyonda kullanmayın.

## İncelenmiş Profil Oluşturma

1. Yükseltilmiş bir PowerShell penceresi açın.
2. WinISOUtil'i yerel checkout üzerinden başlatın:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\winisoutil.ps1
```

3. Güncel bir baseline ISO ve otomasyonda kullanacağınız edition değerini seçin.
4. Korumak istediğiniz component, servis, registry, uygulama kaldırma ve isteğe
   bağlı feature seçimlerini uygulayın.
5. Ana menüden `7. Ayarları Dışa Aktar (.json)` seçeneğini seçin.
6. Export edilen profili aşağıdaki gibi yerel bir yapılandırma klasöründe tutun:

```text
D:\WinISOUtil\config\desktop-v2.json
```

7. Ortaya çıkan ISO'yu disposable bir Hyper-V VM üzerinde mount edin veya kurun.
   Beklenen uygulamaları, kurulum akışını, ağı, servicing ve kurtarma davranışını
   doğrulayın.

Feature sürümü değiştikten veya önemli özelleştirmeler yaptıktan sonra profili
tekrar inceleyin. Kararlı seçiciler aylık bakımı azaltır ancak kurulum
doğrulamasının yerini tutmaz.

## Minimal Profil

Kaldırma veya tweak gerekmiyorsa
[`../automation/profile-v2.example.json`](../automation/profile-v2.example.json)
dosyasını kullanın:

```json
{
  "SchemaVersion": 2,
  "Description": "Example unattended WinISOUtil profile",
  "RemovedAppSelectors": [],
  "RegistryTweaks": [],
  "EnabledFeatures": [],
  "ComponentServiceTweaks": []
}
```

Dizilerdeki ID değerleri `src\` altındaki tanımlara göre doğrulanır. Bilinmeyen
ID değerleri fail closed davranışıyla reddedilir.

## Profili Doğrudan Kullanma

```powershell
.\winisoutil.ps1 `
  -Unattended `
  -Language tr `
  -IsoPath 'D:\ISO\Windows11.iso' `
  -ConfigurationPath 'D:\WinISOUtil\config\desktop-v2.json' `
  -EditionIndex 1 `
  -OutputIsoPath 'D:\ISO\out\Windows11-by-WinISOUtil.iso'
```

Girdi ISO tek install image içeriyorsa `-EditionIndex` yazılmayabilir.

## Profilleri Zamanlanmış Otomasyonda Kullanma

Bir hedef kendi `ConfigurationPath` değerini tanımlamadıkça
`DefaultConfigurationPath` bütün hedeflere uygulanır:

```json
{
  "DefaultConfigurationPath": "D:\\WinISOUtil\\config\\desktop-v2.json",
  "Targets": [
    { "Id": "tr-tr-pro", "Locale": "tr-tr" },
    {
      "Id": "de-de-pro",
      "Locale": "de-de",
      "ConfigurationPath": "D:\\WinISOUtil\\config\\desktop-de-v2.json"
    }
  ]
}
```

Üretim profillerini public repo dışında tutun. Yerel operasyonel yapılandırma
olarak yedekleyin ve değişiklikleri kullanmadan önce inceleyin.
