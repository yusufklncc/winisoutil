# Otomasyon Sorun Giderme Runbook'u

Teşhis işlemlerini dedicated otomasyon makinesindeki yükseltilmiş bir PowerShell
penceresinden çalıştırın. Güncel state, loglar ve aktif DISM mount kayıtları
incelenmeden korunmuş staging verisini silmeyin.

## Güncel State Kaydını Okuma

```powershell
Get-Content D:\WinISOUtil\state\current-run.json -Raw
Get-Content D:\WinISOUtil\state\last-run.json -Raw
Get-ChildItem D:\WinISOUtil\logs -File |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 20 Name, Length, LastWriteTime
```

Aktif logu canlı izleyin:

```powershell
Get-Content D:\WinISOUtil\logs\automated-build-*.log -Wait -Tail 50
```

Native converter ve WinISOUtil stdout, stderr ve exit-code transcript dosyaları
aynı log klasöründe ayrıca saklanır.

## Zamanlanmış Görevi İnceleme

```powershell
Get-ScheduledTask -TaskName 'WinISOUtil Daily UUP Build'
Get-ScheduledTaskInfo -TaskName 'WinISOUtil Daily UUP Build'
```

Görev mevcut değilse yükseltilmiş PowerShell penceresinden kaydedin:

```powershell
.\automation\Register-ScheduledTask.ps1 `
  -SettingsPath '.\automation\settings.json' `
  -ToolsPinPath '.\automation\tools.pin.json'
```

Görev `SYSTEM` hesabıyla çalışır. Yapılandırılmış bütün yerel yollar, profiller
ve kurulu converter dosyaları bu hesap tarafından okunabilmelidir.

## Temizlik Öncesinde DISM Mount Kayıtlarını İnceleme

```powershell
Get-WindowsImage -Mounted
```

Mount kaydı yarıda kesilmiş bir WinISOUtil çalışmasına aitse discard veya
kurtarma kararı vermeden önce raporlanan yol ve durumu inceleyin. DISM mount
kaydını göstermeye devam ederken mount klasörünü recursive olarak silmeyin.

## Converter Geçici Klasörleri

Sabitlenmiş converter yarıda kesildikten sonra staging volume üzerinde şu sabit
klasörleri bırakabilir:

```text
D:\W10UIuup
D:\MountUUP
```

Silmeden önce:

1. Hiçbir otomasyon veya converter işleminin çalışmadığını doğrulayın.
2. `Get-WindowsImage -Mounted` komutunu çalıştırın.
3. Aktif DISM mount kayıtlarını çözün.
4. Kesin yolların yapılandırılmış staging volume üzerindeki converter
   artıklarına ait olduğunu doğrulayın.
5. Yalnız doğruladığınız artık klasörleri silin.

Sonraki tam üretim eski converter klasörleri mevcutsa bilerek erken durur. Bu
davranış sonraki dönüşümün belirsiz state devralmasını önler.

## Korunmuş Staging Verisi

Başarısız hedef staging klasörleri teşhis ve kurtarma için tutulur. Downstream
özelleştirme veya doğrulama hatasından sonra otomasyon geçerli assembled kaynak
ISO'yu otomatik olarak tekrar kullanır.

Bir klasörü yalnız şu koşullarda manuel olarak silmeyi değerlendirin:

- yapılandırılmış `Paths.Staging` kökü altındadır;
- `.winisoutil-staging.json` içerir;
- kurtarma için gerekli bir kaynak ISO içermez;
- çalışan bir görev tarafından kullanılmıyordur.

## Yaygın Hata Kategorileri

| Belirti | Kontrol |
| --- | --- |
| Üretim dönüşüm öncesinde duruyor | `MinimumFreeSpaceGiB`, ADK Deployment Tools, sabitlenmiş converter kurulumu, eski converter klasörleri ve aktif DISM mount kayıtlarını kontrol edin. |
| UUP API retry sonrasında başarısız oluyor | `https://api.uupdump.net` ağ erişimini kontrol edin. Provider 5, 15, 45 ve 120 saniyelik gecikmelerle tekrar dener. |
| Payload indirme başarısız oluyor | `.partial` dosyasını koruyun. Sonraki deneme CDN range destekliyorsa devam eder ve her zaman boyut ile SHA-256 değerini tekrar kontrol eder. |
| Bir locale başarısız oluyor | Hedef bazlı transcript dosyalarını inceleyin. Diğer locale hedefleri devam eder ve mevcut geçerli çıktılar değiştirilmez. |
| Final ISO doğrulaması başarısız oluyor | Staging verisini koruyup WinISOUtil transcript dosyasını inceleyin. Assembled kaynak ISO tekrar kullanım için tutulur. |
| Görev manuel çalışıyor ancak zamanlanmış çalışmıyor | `SYSTEM` hesabının yapılandırılmış bütün disk, profil ve tools yollarına erişebildiğini doğrulayın. Mapped network drive kullanmayın. |
| Mevcut çıktı no-op olarak raporlanıyor | Beklenen davranıştır. Aynı locale, feature ve build tekrar üretilmez. |

## Disk Kullanımı

Payload cache dosyaları çalışmalar arasında bilerek korunur:

```powershell
Get-ChildItem D:\WinISOUtil\cache -Recurse -File |
  Measure-Object Length -Sum
Get-PSDrive D
```

Aktif çalışma sırasında cache dosyalarını silmeyin. Cache temizliği ayrı ve
incelenmiş bir bakım işlemidir; final ISO retention işlemi ortak payload
dosyalarını temizlemez.

## Profil Doğrulamasını İnceleme

Promote edilen ve verifier-only kontrolden geçen ISO dosyaları yanında
`<iso>.validation.json` raporu oluşturulur. Profili değiştirmeden önce
`FailedChecks`, `NoOpChecks` ve `DeferredPostLoginChecks` alanlarını inceleyin.
Allow-list içindeki bir capability, feature veya servisin bulunmaması beklenen
desired-state no-op davranışıdır.
