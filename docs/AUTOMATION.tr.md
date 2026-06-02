# Çoklu Dil UUP Otomasyonu

WinISOUtil, GitHub Actions veya manuel ISO indirme olmadan güncel Windows 11 Pro
ISO dosyaları üretebilir. Tek bir Windows Görev Zamanlayıcı görevi, üçüncü taraf
UUP Dump API üzerinden uygun Retail build'i keşfeder, payload dosyalarını
Microsoft CDN hostlarından indirir, yapılandırılmış her locale için ayrı ISO
oluşturur ve WinISOUtil profilini uygular.

İlgili dokümanlar:

- [`PROFILE.tr.md`](PROFILE.tr.md): şema sürüm 3 profillerini oluşturma, migrate etme ve koruma
- [`TROUBLESHOOTING.tr.md`](TROUBLESHOOTING.tr.md): operasyonel kurtarma runbook'u
- [`TESTING.tr.md`](TESTING.tr.md): fixture, canlı API ve kurulum doğrulaması
- [`../SECURITY.md`](../SECURITY.md): güven sınırları ve tedarik zinciri politikası

## Güven Modeli

- Microsoft UUP, Windows güncelleme dağıtım mekanizmasıdır.
- `api.uupdump.net` üçüncü taraf metadata servisidir. Şema, erişilebilirlik veya
  metadata politikayı karşılamazsa otomasyon fail closed davranır.
- Payload URL'leri yalnız `*.delivery.mp.microsoft.com` üzerinden kabul edilir.
  Güncel bazı imzalı Microsoft CDN URL'leri HTTP kullanır ve HTTPS'e
  yükseltildiğinde CDN sertifikası hostname ile eşleşmez. Bu nedenle her payload
  kullanımdan önce boyut ve SHA-256 ile doğrulanır.
- Uzak PowerShell veya CMD dosyaları doğrudan çalıştırılmaz.
- Massgrave otomatik fallback değildir. Yalnız belgelenmiş manuel acil durum
  seçeneği olarak tutulmalıdır.

## Üretim Politikası

- Yalnız `RETAIL`, `Active`, SHA-256 hazır Windows 11 `amd64` feature build
  kayıtları kabul edilir.
- Yalnız `PROFESSIONAL` edition üretilir.
- Aktif feature sürümündeki aylık güncellemeler hemen uygulanır.
- Yeni görülen feature sürümü otomatik geçişten önce 30 gün bekletilir.
  `InitialFeatureVersion`, ilk yerel state'i seed eder; böylece ilk zamanlanmış
  çalışma bu bekleme penceresini atlayamaz.
- Her locale ayrı ISO üretir. DISM mount işlemleri, converter çalışma alanları
  ve API çağrıları çakışmasın diye hedefler sırayla çalışır.
- Başarısız hedef eski ISO'sunu değiştirmez ve diğer locale hedeflerini
  durdurmaz. Kısmi hata durumunda batch exit code `2` ile çıkar.

## Gereksinimler

En az 100 GB boş alanı olan dedicated ve güncel Windows 11 x64 makine veya VM
kullanın. Windows ADK Deployment Tools paketini kurun. Kurulum komutlarını
yükseltilmiş PowerShell penceresinden çalıştırın.

`MinimumFreeSpaceGiB` varsayılan olarak `50` değerini kullanır. Yapılandırılmış
cache, staging, output veya working volume alanlarından herhangi birinde bundan
az boş alan varsa tam üretim dönüşüm başlamadan durur. Bu değer ek çalışma alanı
rezervidir; ortak payload cache çalışmalar arasında diskte kalır.

UUP converter ayrı bir üçüncü taraf projedir. Bu repo converter dosyalarının
yeniden dağıtım lisansını garanti etmez; bu nedenle dosyaları vendor etmez.
Converter paketini inceleyin, incelediğiniz ZIP dosyasını kontrol ettiğiniz bir
HTTPS URL'ye koyun ve SHA-256 değerini yerel olarak kaydedin. Converter
güncellemelerini incelenen bakım değişiklikleri olarak ele alın: yerel pin
değerini manuel olarak güncelleyin, araçları tekrar kurun ve zamanlanmış görevi
yeniden etkinleştirmeden önce tam doğrulama akışını çalıştırın.

## Kurulum

1. Yerel settings dosyasını oluşturun:

```powershell
Copy-Item .\automation\settings.example.json .\automation\settings.json
```

2. Yolları ve `Targets` listesini düzenleyin. Bütün yollar yerel olmalı ve
   `SYSTEM` hesabı tarafından erişilebilmelidir. `InitialFeatureVersion`
   değerini ilk çalışmada bilinçli olarak kullanmak istediğiniz oturmuş feature
   sürümüne ayarlayın.

3. Güncel baseline ISO üzerinden interaktif olarak `SchemaVersion: 3`
   WinISOUtil profili export edin. Sürüm 3 kararlı AppX, capability ve
   removable-feature seçimlerini saklar. [`PROFILE.tr.md`](PROFILE.tr.md)
   dokümanını izleyin. Minimal başlangıç için
   `automation\profile-v3.example.json` kullanabilirsiniz.

4. Yerel converter pin dosyasını oluşturun:

```powershell
Copy-Item .\automation\tools.pin.example.json .\automation\tools.pin.json
```

5. `tools.pin.json` içindeki `ArchiveUri`, `ArchiveSha256` ve
   `CommandRelativePath` değerlerini yazın, ardından incelenmiş ZIP'i kurun:

```powershell
.\automation\Install-UupTools.ps1 `
  -SettingsPath '.\automation\settings.json' `
  -ToolsPinPath '.\automation\tools.pin.json'
```

ZIP, yapılandırılmış relatif yolda `convert-UUP.cmd`, `ConvertConfig.ini` ve
yardımcı dosyalarını içermelidir. Installer, SHA-256 değeri yerel pin ile
eşleşmeyen arşivi promote etmez.

6. Discovery çalıştırın:

```powershell
.\automation\Invoke-AutomatedBuild.ps1 `
  -SettingsPath '.\automation\settings.json' `
  -ToolsPinPath '.\automation\tools.pin.json' `
  -DiscoverOnly
```

7. Hedef bazlı bir tam üretimi manuel çalıştırıp ISO'yu Hyper-V üzerinde doğrulayın:

```powershell
.\automation\Invoke-AutomatedBuild.ps1 `
  -SettingsPath '.\automation\settings.json' `
  -ToolsPinPath '.\automation\tools.pin.json' `
  -TargetId 'tr-tr-pro'
```

   Zamanlanmış görevi etkinleştirmeden önce her locale için smoke üretimini
   tekrarlayın. Yapılandırılmış bütün hedefleri sırayla işlemek için `-TargetId`
   parametresini yazmayın.

8. Manuel doğrulama başarıyla tamamlandıktan sonra her gün `04:00`'te çalışan
   SYSTEM görevini kaydedin:

```powershell
.\automation\Register-ScheduledTask.ps1 `
  -SettingsPath '.\automation\settings.json' `
  -ToolsPinPath '.\automation\tools.pin.json'
```

   Kayıt sonrasında görevi bilinçli olarak hemen başlatmak istiyorsanız
   `-RunNow` parametresini ekleyin.

## Ayar Referansı

| Ayar | Amaç |
| --- | --- |
| `SchemaVersion` | Otomasyon ayar şemasıdır. `2` olmalıdır. |
| `ToolLanguage` | Katılımsız çalışmalara geçirilen WinISOUtil mesaj dilidir. |
| `Architecture` | UUP mimarisidir. Güncel üretim politikası `amd64` kullanır. |
| `Edition` | UUP edition değeridir. Güncel üretim politikası `PROFESSIONAL` gerektirir. |
| `InitialFeatureVersion` | İlk kullanımda aktif feature sürümünü seed eder. |
| `FeatureReleaseHoldDays` | Yeni feature sürümü promote edilmeden önce uygulanacak gözlem süresidir. |
| `RetentionCount` | Hedef başına tutulacak başarılı final ISO sayısıdır. |
| `MinimumFreeSpaceGiB` | Tam üretim öncesinde cache, staging, output ve working disklerinde gerekli boş alan rezervidir. Yazılmazsa varsayılan `50` değeridir. |
| `DefaultConfigurationPath` | Varsayılan şema sürüm 3 WinISOUtil profilidir. Sürüm 2 migration uyarısıyla desteklenir. |
| `WebhookUrl` | Final batch özetini alan isteğe bağlı HTTPS endpoint'tir. Kimlik bilgilerini tracked dosyalarda tutmayın. |
| `Targets[].Id` | Yol, log ve `-TargetId` için kullanılan kararlı yerel hedef kimliğidir. |
| `Targets[].Locale` | `tr-tr`, `en-us` veya `de-de` gibi UUP locale değeridir. |
| `Targets[].ConfigurationPath` | İsteğe bağlı hedef bazlı şema sürüm 2 veya 3 profil override değeridir. |
| `Paths` | `SYSTEM` hesabının erişebildiği yerel tools, cache, staging, output, logs, working ve state kökleridir. |

## Operasyon Notları

Otomasyon varsayılan olarak locale başına son iki başarılı ISO'yu tutar.
Payload dosyaları ortak SHA-256 cache kullanır; ortak UUP ve AppX dosyaları
tekrar indirilmez. Microsoft CDN range destekliyorsa yarım indirmeler kaldığı
yerden sürer. Süresi dolan imzalı URL'ler için manifest bir kez yenilenir.

Promote edilen ISO dosyaları
`Windows11-Pro-<locale>-<feature>-<build>-by-WinISOUtil.iso` adını kullanır.
Mevcut `-custom.iso` çıktıları geçiş sırasında geçerli no-op eşleşmeleri olarak
kabul edilir; ad değişikliği daha önce promote edilmiş build'i tekrar üretmez.

Loglar canlı olarak `Paths.Logs` altına yazılır. Native converter ve WinISOUtil
stdout/stderr kayıtları ayrıca tutulur. `Paths.State\current-run.json` her faz
geçişinde atomik olarak güncellenir; bu nedenle yarıda kesilen bir işlem son
bilinen fazını ve log yolunu korur. State manifestleri, hedef bazlı ISO hash
değerleri ve tamamlanan son batch sonucu `Paths.State` altında ve promote edilen
ISO yanında tutulur. Batch ayrıca Application Event Log girdisi yazar. İsteğe
bağlı HTTPS `WebhookUrl`, aynı özet JSON verisini alır. Promote edilen her ISO
yanında strict offline, no-op ve deferred post-login kontrollerini içeren
`<iso>.validation.json` raporu da oluşturulur. Güncel logu izlemek için:

```powershell
Get-Content D:\WinISOUtil\logs\automated-build-*.log -Wait -Tail 50
```

UUP assembly sonrasında doğrulanmış kaynak ISO geçici assembled-source cache
alanına taşınır. Özelleştirme veya final doğrulama başarısız olursa sonraki
çalıştırma kaynak ISO'yu yeniden üretmek yerine tekrar kullanır. Başarılı promote
sonrasında disk alanını geri kazanmak için geçici kaynak cache silinir. Owned
staging klasörlerinde kalan geçerli assembled ISO dosyaları da otomatik olarak
kurtarılır.

Başarısız staging klasörleri teşhis için bilerek korunur. Bu klasörleri yalnız
`Paths.Staging` altında olduklarını ve `.winisoutil-staging.json` ownership
marker içerdiklerini doğruladıktan sonra kaldırın.

Sabitlenmiş converter ayrıca `<staging-volume>:\W10UIuup` ve
`<staging-volume>:\MountUUP` sabit geçici klasörlerini kullanır. Yarıda kesilen
bir dönüşüm bu klasörleri geride bırakabilir. Sonraki tam üretim, aktif DISM
mount kayıtları incelenip eski klasörler temizlenene kadar erken aşamada durur.

`Invoke-MonthlyBuild.ps1`, deprecated uyumluluk wrapper'ı olarak kalır.

## Görev İşlemleri

Kayıtlı görevi inceleyin:

```powershell
Get-ScheduledTask -TaskName 'WinISOUtil Daily UUP Build'
Get-ScheduledTaskInfo -TaskName 'WinISOUtil Daily UUP Build'
```

Kayıtlı görevi başlatın:

```powershell
Start-ScheduledTask -TaskName 'WinISOUtil Daily UUP Build'
```

Yerel çıktıları veya cache dosyalarını silmeden görevi kaldırın:

```powershell
Unregister-ScheduledTask -TaskName 'WinISOUtil Daily UUP Build' -Confirm:$false
```

Son state ve Application Event Log kayıtlarını inceleyin:

```powershell
Get-Content D:\WinISOUtil\state\current-run.json -Raw
Get-Content D:\WinISOUtil\state\last-run.json -Raw
Get-WinEvent -FilterHashtable @{
  LogName = 'Application'
  ProviderName = 'WinISOUtil Automation'
} -MaxEvents 10
```

## Sonuçlar ve Exit Code Değerleri

Final ISO yalnız doğrulama başarılı olursa promote edilir. Doğrulama
Professional edition değerini, istenen locale bilgisini, seçilmiş build ve
revision değerini, boot image, install image, WinRE yapısını, korunan zorunlu
provisioned app paketlerini ve profile-aware AppX, capability, optional-feature,
servis ve registry state değerlerini kontrol eder. Post-login seçimleri deferred
olarak raporlanır ve masaüstü BAT payload varlığı doğrulanır. Promote edilen ISO
yanında kaynak, final ve validation-report SHA-256 değerlerini içeren bir JSON
manifesti oluşturulur.

| Exit code | Anlam |
| --- | --- |
| `0` | Discovery veya üretim batch'i hedef hatası olmadan tamamlandı. Mevcut çıktılar no-op hedef olarak raporlanır. |
| `1` | Kullanılabilir bir sonuç tamamlanmadan batch başarısız oldu. |
| `2` | Kısmi hata: en az bir hedef başarılı veya no-op iken başka bir hedef başarısız oldu. |

Korunmuş staging verisini veya converter geçici klasörlerini manuel olarak
silmeden önce [`TROUBLESHOOTING.tr.md`](TROUBLESHOOTING.tr.md) dokümanını
kullanın.
