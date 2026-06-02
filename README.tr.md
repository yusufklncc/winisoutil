[English](README.md) | [Türkçe](README.tr.md)

# WinISOUtil - Windows ISO Özelleştirme Aracı

![Windows 11](https://img.shields.io/badge/Windows-11-0078D6?style=for-the-badge&logo=windows11)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell)
![Lisans](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)

**WinISOUtil**, Windows ISO dosyalarınızı doğrudan değiştirmenize olanak tanıyan, böylece işletim sistemini kurulumdan önce ihtiyaçlarınıza göre yapılandırmanıza imkan veren güçlü bir PowerShell betiğidir. Gereksiz (bloatware) uygulamaları kaldırabilir, gizlilik ayarlarını iyileştirebilir, performans odaklı kayıt defteri ince ayarları uygulayabilir ve sık kullandığınız sürücüleri veya güncellemeleri doğrudan ISO'ya entegre edebilirsiniz.

Bu araç, hem etkileşimli menü tabanlı bir **Manuel Mod**'a hem de daha önce kaydedilmiş bir yapılandırma dosyasını kullanıcı etkileşimi olmadan uygulayabilen bir **Katılımsız Mod**'a sahiptir.

---

## ✨ Temel Özellikler

- **Çoklu Dil Arayüzü**: Türkçe ve İngilizce desteği.
- **Etkileşimli ve Katılımsız Modlar**:
  - **Manuel Mod**: Hangi bileşenlerin kaldırılacağını veya hangi ayarların uygulanacağını adım adım seçin.
  - **Katılımsız Mod**: Ayarlarınızı bir `.json` dosyasına kaydedin ve aynı yapılandırmayı güncellenmiş ISO dosyalarına kullanıcı etkileşimi olmadan uygulayın.
- **ISO Temizliği**:
  - İstenmeyen Windows sürümlerini (ör. Home, Pro) ISO'dan kaldırarak yerden tasarruf edin.
  - Gereksiz hazır Windows uygulamalarını (Bloatware) kurulumdan önce temizleyin.
- **Entegrasyon**:
  - Kritik Windows güncellemelerini (`.msu`) ISO dosyasına ekleyin.
  - Kurulum sonrası sürücü sorunlarından kaçınmak için sürücülerinizi (`.inf`) doğrudan ISO'ya entegre edin.
- **Detaylı Yapılandırma**:
  - **Gizlilik ve Telemetri**: Veri toplama ve hata raporlama servislerini devre dışı bırakın.
  - **Arayüz İnce Ayarları**: Görev çubuğunu sola hizalayın, masaüstü simgelerini yapılandırın ve Dosya Gezgini'nde ince ayarlar yapın.
  - **Bileşen Kaldırma**: Internet Explorer ve Windows Media Player gibi eski bileşenleri kaldırın.
- **Güvenilirlik ve Bağımlılık Yönetimi**:
  - Bir `trap` mekanizması, bir hata oluşması durumunda güvenli bir çıkış ve temizlik sağlayarak "kirli" bir durumu (örneğin, bağlanmış bir imaj) önler.
  - Geçici dosyalar yalnızca `%TEMP%\WinISOUtil` altındaki işaretli ve araca ait çalışma alanından silinir.
  - Hem `install.wim` hem de `install.esd` kaynak imajları desteklenir.
  - Betik, gerekli olan **Windows ADK**'yı otomatik olarak kontrol eder. Bulunmazsa, kullanıcıya kurulum için net talimatlar sağlar.

---

## 🚀 Hızlı Başlangıç

İncelediğiniz bir sürüm arşivini indirin veya repoyu klonlayın, ardından betiği yerel dosyadan çalıştırın:

```powershell
git clone https://github.com/yusufklncc/winisoutil.git
cd winisoutil
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\winisoutil.ps1
```

`winisoutil.ps1` dosyasını **yükseltilmiş bir PowerShell penceresinden**
çalıştırın. Ana betik yönetici ayrıcalıklarını kontrol eder ve eksikse durur.
İsteğe bağlı bootstrapper ise elevation isteğini otomatik olarak açar.

Uzak betikleri doğrudan `iex` komutuna aktarmayın. Tekrarlanabilir bootstrap kurulumu için yerel `install.ps1` dosyasını sabitlenmiş Git ref ve beklenen arşiv SHA-256 değeriyle çalıştırın:

```powershell
.\install.ps1 -Ref '<etiket-veya-commit>' -ExpectedArchiveSha256 '<sha256>'
```

## ⚙️ Kullanım ve İş Akışı

1.  Başlatıcı betik önce Yönetici ayrıcalıkları ister.
2.  İsteğe bağlı bootstrapper kullanılırsa proje dosyalarını benzersiz bir geçici dizine indirir ve arşiv SHA-256 değerini doğrulayabilir.
3.  Ana betik olan `winisoutil.ps1` başlatılır.
4.  Bir dil seçmeniz istenecektir.
5.  Betik, devam etmeden önce tüm gereksinimlerin (Windows ADK gibi) karşılandığını doğrular.
6.  Düzenlemek istediğiniz Windows ISO dosyasını seçmeniz için bir dosya seçim penceresi açılır.
7.  ISO bağlanır, içeriği `%TEMP%\WinISOUtil\iso` konumuna kopyalanır ve seçilen imaj `%TEMP%\WinISOUtil\mount` konumuna bağlanır.
8.  Ana menü belirir ve istediğiniz özelleştirmelerle devam etmenize olanak tanır.

---

## 🤖 JSON ile Katılımsız Mod

Her seferinde aynı seçenekleri manuel olarak seçmek yerine, bir yapılandırma dosyası kullanarak iş akışınızı kolaylaştırabilirsiniz.

1.  **Ayarları Dışa Aktarma**:

    - Betiği etkileşimli modda çalıştırın ve menülerden istediğiniz tüm ince ayarları, bileşen kaldırma ve uygulama temizleme işlemlerini seçin.
    - Ana menüden, mevcut seçimlerinizi bir yapılandırma dosyasına kaydetmek için **"7. Ayarları Dışa Aktar (.json)"** seçeneğini seçin.

2.  **Ayarları İçe Aktarma**:
    - Betiği bir sonraki çalıştırdığınızda, bir ISO seçtikten sonra bir yapılandırma dosyası içe aktarmak isteyip istemediğiniz sorulacaktır.
    - "Evet" (`E`) seçeneğini seçin ve kaydettiğiniz `.json` dosyasını belirtin. Betik, dosyada tanımlanan ve doğrulamadan geçen ayarları otomatik olarak uygulayacaktır.

3.  **Kullanıcı etkileşimi olmadan çalıştırma**:

```powershell
.\winisoutil.ps1 `
  -Unattended `
  -Language tr `
  -IsoPath 'D:\ISO\Windows11.iso' `
  -ConfigurationPath '.\config\desktop.json' `
  -EditionIndex 1 `
  -OutputIsoPath 'D:\ISO\out\Windows11-custom.iso'
```

Yeni export dosyaları yapılandırma şeması sürüm 2'yi ve kararlı
`RemovedAppSelectors` değerlerini kullanır. Böylece aynı profil güncellenmiş ISO
build'leri ve locale hedefleri arasında tekrar kullanılabilir. Sürüm 1 profilleri
tek seferlik çalışmalar için okunmaya devam eder. Sıfır dokunuş otomasyonu sürüm
2 profil zorunluluğu koyar. Profil yaşam döngüsü için
[`docs/PROFILE.tr.md`](docs/PROFILE.tr.md) dosyasına bakın.

### Katılımsız CLI Referansı

| Parametre | Amaç |
| --- | --- |
| `-IsoPath` | Girdi Windows ISO dosyası. Katılımsız modda zorunludur. |
| `-ConfigurationPath` | Export edilmiş JSON profilidir. Katılımsız modda zorunludur. |
| `-OutputIsoPath` | Final ISO yoludur. Katılımsız modda zorunludur. |
| `-EditionIndex` | Özelleştirilecek imaj indeksidir. ISO birden fazla edition içeriyorsa zorunludur. |
| `-Language` | Araç mesaj dili: `tr` veya `en`. Katılımsız modda varsayılan `en` değeridir. |
| `-UpdatesPath` | `.msu` güncelleme paketlerini içeren isteğe bağlı klasördür. |
| `-DriversPath` | `.inf` sürücülerini içeren isteğe bağlı klasördür. Alt klasörler dahil edilir. |
| `-WorkingDirectory` | İsteğe bağlı sahipli çalışma alanıdır. Varsayılan `%TEMP%\WinISOUtil` değeridir. |
| `-SkipWimOptimization` | Final WIM export optimizasyonunu atlar. Yalnız teşhis amacıyla kullanılmalıdır. |

## Zamanlanmış UUP Otomasyonu

Önerilen sıfır dokunuş modeli GitHub Actions yerine dedicated bir Windows 11
makine veya VM üzerinde çalışır. Günlük SYSTEM görevi uygun Retail UUP build'ini
keşfeder, Microsoft CDN hostlarından hash doğrulamalı payload dosyalarını indirir,
yapılandırılmış her locale için ayrı Windows 11 Pro ISO üretir, şema sürüm 2
profilini uygular, sonucu doğrular ve belirlenen sayıda başarılı çıktıyı tutar.

Kurulum ve işletim için [`docs/AUTOMATION.tr.md`](docs/AUTOMATION.tr.md)
dosyasına bakın.

## Dokümantasyon

- [`docs/AUTOMATION.tr.md`](docs/AUTOMATION.tr.md): günlük çoklu locale UUP otomasyonu
- [`docs/PROFILE.tr.md`](docs/PROFILE.tr.md): şema sürüm 2 profillerini oluşturma ve koruma
- [`docs/TROUBLESHOOTING.tr.md`](docs/TROUBLESHOOTING.tr.md): kurtarma ve teşhis runbook'u
- [`docs/TESTING.tr.md`](docs/TESTING.tr.md): fixture, canlı API ve Hyper-V doğrulaması
- [`SECURITY.md`](SECURITY.md): güven sınırları ve tedarik zinciri politikası
- [`CONTRIBUTING.md`](CONTRIBUTING.md): katkı ve branch akışı

---

## 🛠️ Modüler Yapı ve Özelleştirme

Proje modüler olacak şekilde tasarlanmıştır. `src/` dizinindeki dosyaları düzenleyerek kolayca özelleştirmeler ekleyebilir veya değiştirebilirsiniz:

- **`src\languages.ps1`**: Desteklenen diller için tüm arayüz metinlerini içerir. Yerelleştirmeyi genişletmek için buraya yeni bir dil bloğu ekleyin.
- **`src\tweaks.ps1`**: Mevcut tüm kayıt defteri ince ayarlarını tanımlar. Yeni bir ince ayar oluşturmak için bu listeye kendi `[PSCustomObject]`'inizi ekleyebilirsiniz.
- **`src\components.ps1`**: Kaldırılabilecek veya devre dışı bırakılabilecek Windows bileşenlerini ve servislerini listeler.
- **`src\features.ps1`**: `.NET Framework 3.5` gibi etkinleştirilebilecek isteğe bağlı Windows özelliklerini tanımlar.
- **`src\app-exclusion-list.ps1`**: Sistemin bozulmasını önlemek için kaldırma listesinden hariç tutulan kritik sistem uygulamalarının (Microsoft Store gibi) bir listesini içerir.

---

## 📋 Gereksinimler

- Windows 10 veya Windows 11
- PowerShell 5.1+
- Çalıştırmak için yönetici ayrıcalıkları
- İnternet bağlantısı (betiğin ilk indirilmesi için)
- **Windows ADK**: [Windows Değerlendirme ve Dağıtım Kiti (ADK)](https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install) kurulu olmalıdır.
  - ADK kurulumu sırasında, yalnızca son ISO dosyasını oluşturmak için gerekli olan `oscdimg.exe`'yi içeren **"Dağıtım Araçları"** özelliğini seçmeniz yeterlidir.

## ✅ Doğrulama

Değişiklik göndermeden önce yerel fixture kontrollerini çalıştırın:

```powershell
.\tests\Test-Static.ps1
.\tests\Test-Automation.ps1
```

Canlı UUP API smoke testi ve Hyper-V kurulum testi
[`docs/TESTING.tr.md`](docs/TESTING.tr.md) dosyasında belgelenmiştir.

---

## 🤝 Katkıda Bulunma

Geliştirme akışı için [`CONTRIBUTING.md`](CONTRIBUTING.md) dosyasını kullanın.
Değişiklikler `dev` üzerinden entegre edilir; `main` release-ready branch'tir.

---

## ⚠️ Sorumluluk Reddi

Bu betik, Windows ISO içindeki kritik sistem dosyalarını değiştirir. Kapsamlı bir şekilde test edilmiş olmasına rağmen, herhangi bir garanti olmaksızın "olduğu gibi" sunulmaktadır. Yazar, kullanımından kaynaklanabilecek herhangi bir zarardan sorumlu değildir.

- **Kullanım riski size aittir**.
- **Sistemde değişiklik yapmadan önce her zaman önemli verileri yedekleyin**.

---

## 📄 Lisans

Bu proje MIT Lisansı altında lisanslanmıştır. Ayrıntılar için `LICENSE` dosyasına bakın.
