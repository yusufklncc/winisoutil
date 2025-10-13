[English](README.md) | [Türkçe](README.tr.md)

# WinISOUtil - Windows ISO Özelleştirme Aracı

![Windows 11](https://img.shields.io/badge/Windows-11-0078D6?style=for-the-badge&logo=windows11)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell)
![Lisans](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)

**WinISOUtil**, Windows ISO dosyalarınızı doğrudan değiştirmenize olanak tanıyan, böylece işletim sistemini kurulumdan önce ihtiyaçlarınıza göre yapılandırmanıza imkan veren güçlü bir PowerShell betiğidir. Gereksiz (bloatware) uygulamaları kaldırabilir, gizlilik ayarlarını iyileştirebilir, performans odaklı kayıt defteri ince ayarları uygulayabilir ve sık kullandığınız sürücüleri veya güncellemeleri doğrudan ISO'ya entegre edebilirsiniz.

Bu araç, hem etkileşimli menü tabanlı bir **Manuel Mod**'a hem de daha önce kaydedilmiş bir yapılandırma dosyasını uygulayarak tüm süreci otomatikleştirebilen bir **Otomatik Mod**'a sahiptir.

---

## ✨ Temel Özellikler

- **Çoklu Dil Arayüzü**: Türkçe ve İngilizce desteği.
- **Etkileşimli ve Otomatik Modlar**:
  - **Manuel Mod**: Hangi bileşenlerin kaldırılacağını veya hangi ayarların uygulanacağını adım adım seçin.
  - **Otomatik Mod**: Ayarlarınızı bir `.json` dosyasına kaydedin ve aynı yapılandırmayı diğer ISO'lara otomatik olarak uygulayın.
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
  - Betik, gerekli olan **Windows ADK**'yı otomatik olarak kontrol eder. Bulunmazsa, kullanıcıya kurulum için net talimatlar sağlar.

---

## 🚀 Hızlı Başlangıç

Bu aracı kullanmak için bir **Terminal** veya **PowerShell** penceresi açın ve aşağıdaki komutu çalıştırın. Bu komut, kurulumu sizin için yöneten başlatıcı betiğini indirip çalıştıracaktır.

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; irm https://raw.githubusercontent.com/yusufklncc/winisoutil/refs/heads/main/install.ps1 | iex
```

## ⚙️ Kullanım ve İş Akışı

1.  Başlatıcı betik önce Yönetici ayrıcalıkları ister.
2.  Gerekli tüm proje dosyalarını GitHub'dan geçici bir dizine indirir.
3.  Ana betik olan `winisoutil.ps1` başlatılır.
4.  Bir dil seçmeniz istenecektir.
5.  Betik, devam etmeden önce tüm gereksinimlerin (Windows ADK gibi) karşılandığını doğrular.
6.  Düzenlemek istediğiniz Windows ISO dosyasını seçmeniz için bir dosya seçim penceresi açılır.
7.  ISO bağlanır, içeriği `C:\temp_iso` konumuna kopyalanır ve `install.wim` içindeki imaj `C:\mount` konumuna bağlanır.
8.  Ana menü belirir ve istediğiniz özelleştirmelerle devam etmenize olanak tanır.

---

## 🤖 JSON ile Otomatik Mod

Her seferinde aynı seçenekleri manuel olarak seçmek yerine, bir yapılandırma dosyası kullanarak iş akışınızı kolaylaştırabilirsiniz.

1.  **Ayarları Dışa Aktarma**:

    - Betiği etkileşimli modda çalıştırın ve menülerden istediğiniz tüm ince ayarları, bileşen kaldırma ve uygulama temizleme işlemlerini seçin.
    - Ana menüden, mevcut seçimlerinizi bir yapılandırma dosyasına kaydetmek için **"7. Ayarları Dışa Aktar (.json)"** seçeneğini seçin.

2.  **Ayarları İçe Aktarma**:
    - Betiği bir sonraki çalıştırdığınızda, bir ISO seçtikten sonra bir yapılandırma dosyası içe aktarmak isteyip istemediğiniz sorulacaktır.
    - "Evet" (`E`) seçeneğini seçin ve kaydettiğiniz `.json` dosyasını belirtin. Betik, dosyada tanımlanan tüm ayarları otomatik olarak uygulayacaktır.

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

---

## 🤝 Katkıda Bulunma

Katkılarınız projeyi daha iyi hale getirir! Bir hata bulursanız, yeni bir özellik önermek veya kodu iyileştirmek isterseniz, lütfen bir "Issue" açın veya bir "Pull Request" gönderin.

1.  Projeyi Fork'layın.
2.  Yeni bir Özellik Dalı oluşturun (`git checkout -b feature/HarikaYeniOzellik`).
3.  Değişikliklerinizi Commit'leyin (`git commit -m 'Harika bir yeni özellik ekle'`).
4.  Dala Push'layın (`git push origin feature/HarikaYeniOzellik`).
5.  Bir Pull Request açın.

---

## ⚠️ Sorumluluk Reddi

Bu betik, Windows ISO içindeki kritik sistem dosyalarını değiştirir. Kapsamlı bir şekilde test edilmiş olmasına rağmen, herhangi bir garanti olmaksızın "olduğu gibi" sunulmaktadır. Yazar, kullanımından kaynaklanabilecek herhangi bir zarardan sorumlu değildir.

- **Kullanım riski size aittir**.
- **Sistemde değişiklik yapmadan önce her zaman önemli verileri yedekleyin**.

---

## 📄 Lisans

Bu proje MIT Lisansı altında lisanslanmıştır. Ayrıntılar için `LICENSE` dosyasına bakın.
