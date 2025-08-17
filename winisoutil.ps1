# --- YARDIMCI FONKSİYONLAR ---
# Scriptin herhangi bir yerinde kullanılmadan önce tüm fonksiyonların tanımlanması,
# özellikle "irm | iex" ile çalıştırma sırasında oluşabilecek hataları engeller.

function Write-ColorText {
    param([string]$Text, [string]$Color = "White")
    Write-Host $Text -ForegroundColor $Color
}

function Show-Banner {
    Clear-Host
    Write-ColorText "================================================================" $Cyan
    Write-ColorText "                 Windows 11 ISO Ozellestirme Araci              " $Cyan
    Write-ColorText "================================================================" $Cyan
    Write-Host ""
}

function Invoke-LongRunningOperation {
    param(
        [ScriptBlock]$ScriptBlock,
        [string]$Message
    )

    $job = Start-Job -ScriptBlock $ScriptBlock
    $spinner = @('|', '/', '-', '\')
    $spinnerIndex = 0
    
    while ($job.State -eq 'Running') {
        Write-Host -NoNewline "`r$Message $($spinner[$spinnerIndex])"
        $spinnerIndex = ($spinnerIndex + 1) % $spinner.Length
        Start-Sleep -Milliseconds 100
    }

    Write-Host "`r$(' ' * ($Message.Length + 5))`r"

    if ($job.State -eq 'Failed') {
        $errorMsg = $job.ChildJobs[0].Error
        throw "Arka plan isleminde hata olustu: $errorMsg"
    }
}

function Get-UserChoice {
    param(
        [string]$Title,
        [string[]]$Options,
        [bool]$MultiSelect = $false,
        [string]$GoBackOption = "Geri"
    )
    
    Write-ColorText "`n$Title" $Yellow
    Write-ColorText ("=" * $Title.Length) $Yellow
    
    for ($i = 0; $i -lt $Options.Length; $i++) {
        Write-Host "[$($i + 1)] $($Options[$i])"
    }
    Write-ColorText "[g] $GoBackOption" $Red

    if ($MultiSelect) {
        Write-ColorText "`nBirden fazla seçim yapabilirsiniz (örn: 1,3,5), 'tumu' veya 'g' (geri):" $Green
        $selection = Read-Host "Seciminiz"
        
        if ($selection -ieq 'g') { return 'go_back' }
        if ($selection -ieq "tumu") { return @(1..$Options.Length) }
        
        try {
            return $selection.Split(',').Trim() | ForEach-Object { [int]$_ }
        } catch {
            Write-ColorText "Gecersiz secim!" $Red
            return @()
        }
    } else {
        $selection = Read-Host "Seciminiz (1-$($Options.Length) veya 'g')"
        if ($selection -ieq 'g') { return 'go_back' }
        try {
            return [int]$selection
        } catch {
            Write-ColorText "Gecersiz secim!" $Red
            return 0
        }
    }
}

function Get-IsoTool {
    $adkPaths = @(
        "C:\Program Files (x86)\Windows Kits\11\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg",
        "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg"
    )
    foreach ($path in $adkPaths) {
        $oscdimgPath = Join-Path $path "oscdimg.exe"
        if (Test-Path $oscdimgPath) {
            Write-ColorText "Sistemde kurulu oscdimg.exe bulundu." $Green
            return @{ Tool = 'oscdimg'; Path = $oscdimgPath }
        }
    }

    Write-ColorText "Sistemde oscdimg.exe bulunamadi. Alternatif arac (mkisofs) indiriliyor..." $Yellow
    $toolsDir = Join-Path $env:TEMP "WinIsoTools"
    $mkisofsPath = Join-Path $toolsDir "mkisofs.exe"

    if (Test-Path $mkisofsPath) {
        Write-ColorText "mkisofs zaten indirilmis." $Green
        return @{ Tool = 'mkisofs'; Path = $mkisofsPath }
    }

    try {
        New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null
        $repoUrl = "https://raw.githubusercontent.com/yusufklncc/winisoutil/main/tools"
        
        Write-ColorText "mkisofs.exe indiriliyor..." $Cyan
        Invoke-WebRequest -Uri "$repoUrl/mkisofs.exe" -OutFile $mkisofsPath
        
        Write-ColorText "cygwin1.dll indiriliyor..." $Cyan
        Invoke-WebRequest -Uri "$repoUrl/cygwin1.dll" -OutFile (Join-Path $toolsDir "cygwin1.dll")

        if (Test-Path $mkisofsPath) {
            Write-ColorText "mkisofs basariyla indirildi." $Green
            return @{ Tool = 'mkisofs'; Path = $mkisofsPath }
        } else {
            throw "Indirme basarisiz oldu."
        }
    } catch {
        Write-ColorText "Hata: Alternatif ISO araci indirilemedi. $_" $Red
        Write-ColorText "Lutfen internet baglantinizi kontrol edin veya Windows ADK'yi yukleyin." $Yellow
        return $null
    }
}

# --- ANA SCRIPT FONKSİYONU ---
# Script'in tüm mantığı bu fonksiyonun içinde çalışır.
function Start-IsoCustomizer {
    param(
        [string]$IsoPath = ""
    )

    # --- GLOBAL DEĞİŞKENLER VE HATA YÖNETİMİ ---
    $Red = "Red"
    $Green = "Green"
    $Yellow = "Yellow"
    $Cyan = "Cyan"
    $White = "White"

    $global:ScriptConfig = @{
        RemovedApps            = @()
        RegistryTweaks         = @()
        EnabledFeatures        = @()
        ComponentServiceTweaks = @()
    }

    $script:runMode = 'MANUAL'

    trap {
        Write-ColorText "Beklenmedik bir hata oluştu! Güvenli çıkış yapılıyor..." $Red
        Write-ColorText "Hata: $($_.Exception.Message)" $Yellow

        Cleanup
        exit 1
    }

    # --- İÇE/DIŞA AKTARMA VE OTOMASYON FONKSİYONLARI ---

    function Import-Configuration {
        Show-Banner
        Write-ColorText "Kaydedilmiş bir yapılandırma dosyasını içe aktarmak ister misiniz?" $Yellow
        Write-ColorText "Evet derseniz, işlemler yapılandırma dosyanıza göre otomatik olarak yapılacaktır." $Cyan
        $choice = Read-Host "Seciminiz (E/H)"
        
        if ($choice -ieq 'E') {
            Add-Type -AssemblyName System.Windows.Forms
            $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
            $OpenFileDialog.Title = "Yapilandirma dosyasini secin (.json)"
            $OpenFileDialog.Filter = "JSON files (*.json)|*.json"
            $OpenFileDialog.InitialDirectory = [Environment]::GetFolderPath("Desktop")

            if ($OpenFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                $configPath = $OpenFileDialog.FileName
                try {
                    Write-ColorText "Yapilandirma dosyasi okunuyor: $configPath" $Green
                    $configContent = Get-Content -Path $configPath -Raw | ConvertFrom-Json
                    
                    if ($configContent.PSObject.Properties.Name -contains 'RemovedApps') { $global:ScriptConfig.RemovedApps = $configContent.RemovedApps }
                    if ($configContent.PSObject.Properties.Name -contains 'RegistryTweaks') { $global:ScriptConfig.RegistryTweaks = $configContent.RegistryTweaks }
                    if ($configContent.PSObject.Properties.Name -contains 'EnabledFeatures') { $global:ScriptConfig.EnabledFeatures = $configContent.EnabledFeatures }
                    if ($configContent.PSObject.Properties.Name -contains 'ComponentServiceTweaks') { $global:ScriptConfig.ComponentServiceTweaks = $configContent.ComponentServiceTweaks }

                    Write-ColorText "Yapilandirma basariyla yuklendi! Otomatik mod baslatiliyor..." $Green
                    Start-Sleep -Seconds 2
                    return $true
                } catch {
                    Write-ColorText "Yapilandirma dosyasi okunurken hata olustu: $_" $Red
                    if ($script:runMode -ne 'AUTOMATIC') { Write-Host -NoNewLine 'Devam etmek icin herhangi bir tusa basin...'; $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown'); }
                    return $false
                }
            } else {
                Write-ColorText "Dosya secilmedi. Manuel yapilandirmaya devam ediliyor." $Yellow
                if ($script:runMode -ne 'AUTOMATIC') { Write-Host -NoNewLine 'Devam etmek icin herhangi bir tusa basin...'; $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown'); }
                return $false
            }
        } else {
            Write-ColorText "Manuel yapilandirmaya devam ediliyor." $Yellow
            if ($script:runMode -ne 'AUTOMATIC') { Write-Host -NoNewLine 'Devam etmek icin herhangi bir tusa basin...'; $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown'); }
            return $false
        }
    }

    function Export-Configuration {
        Show-Banner
        Write-ColorText "Mevcut ayarlar bir .json dosyasina aktarilacak." $Yellow

        Add-Type -AssemblyName System.Windows.Forms
        $SaveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
        $SaveFileDialog.Title = "Yapilandirma dosyasini kaydet"
        $SaveFileDialog.Filter = "JSON files (*.json)|*.json"
        $SaveFileDialog.DefaultExt = "json"
        $SaveFileDialog.FileName = "MyWindowsConfig.json"
        $SaveFileDialog.InitialDirectory = [Environment]::GetFolderPath("Desktop")

        if ($SaveFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $exportPath = $SaveFileDialog.FileName
            try {
                $exportObject = @{
                    Description            = "Windows 11 Ozellestirme Ayarlari"
                    DateCreated            = (Get-Date).ToString("yyyy-MM-dd")
                    RemovedApps            = $global:ScriptConfig.RemovedApps
                    RegistryTweaks         = $global:ScriptConfig.RegistryTweaks
                    EnabledFeatures        = $global:ScriptConfig.EnabledFeatures
                    ComponentServiceTweaks = $global:ScriptConfig.ComponentServiceTweaks
                }

                $exportObject | ConvertTo-Json -Depth 5 | Out-File -FilePath $exportPath -Encoding utf8
                Write-ColorText "Yapilandirma basariyla kaydedildi: $exportPath" $Green
            } catch {
                Write-ColorText "Dosya kaydedilirken hata olustu: $_" $Red
            }
        } else {
            Write-ColorText "Disa aktarma islemi iptal edildi." $Yellow
        }
        if ($script:runMode -ne 'AUTOMATIC') { Write-Host -NoNewLine 'Devam etmek icin herhangi bir tusa basin...'; $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown'); }
    }


    # --- ANA İŞLEM FONKSİYONLARI ---

    function Initialize-Environment {
        Write-ColorText "Calisma ortami hazirlaniyor..." $Green
        try {
            if (Test-Path "C:\temp_iso") { Remove-Item "C:\temp_iso" -Recurse -Force }
            if (Test-Path "C:\mount") { Remove-Item "C:\mount" -Recurse -Force }
            New-Item -ItemType Directory -Path "C:\temp_iso" -Force | Out-Null
            New-Item -ItemType Directory -Path "C:\mount" -Force | Out-Null
            Write-ColorText "Ortam hazirlandi!" $Green
        } catch {
            Write-ColorText "Ortam hazırlanırken hata oluştu: $_" $Red
            throw "Ortam hazırlanamadı."
        }
    }

    function Copy-IsoFiles {
        param([string]$IsoPath)
        Write-ColorText "ISO dosyalari kopyalaniyor..." $Green
        $mountResult = $null
        try {
            $mountResult = Mount-DiskImage -ImagePath $IsoPath -PassThru
            $driveLetter = ($mountResult | Get-Volume).DriveLetter
            Copy-Item -Path "$($driveLetter):\*" -Destination "C:\temp_iso\" -Recurse -Force
            Write-ColorText "install.wim dosyasinin salt okunur ozelligi kaldiriliyor..." $Yellow
            Set-ItemProperty -Path "C:\temp_iso\sources\install.wim" -Name IsReadOnly -Value $false
            Write-ColorText "ISO dosyalari kopyalandi!" $Green
        } catch {
            Write-ColorText "ISO dosyaları kopyalanırken hata oluştu: $_" $Red
            throw "ISO kopyalama başarısız."
        } finally {
            if ($mountResult) { Dismount-DiskImage -ImagePath $IsoPath }
        }
    }

    function Find-DismPath {
        $dismPaths = @(
            "C:\Program Files (x86)\Windows Kits\11\Assessment and Deployment Kit\Deployment Tools\amd64\DISM\dism.exe",
            "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM\dism.exe",
            "C:\Windows\System32\dism.exe",
            "C:\Windows\SysWOW64\dism.exe"
        )
        foreach ($path in $dismPaths) {
            if (Test-Path $path) {
                Write-ColorText "DISM bulundu: $path" $Green
                return $path
            }
        }
        try {
            $dismInPath = Get-Command "dism.exe" -ErrorAction SilentlyContinue
            if ($dismInPath) {
                Write-ColorText "DISM PATH'te bulundu: $($dismInPath.Source)" $Green
                return $dismInPath.Source
            }
        } catch {}
        Write-ColorText "UYARI: DISM bulunamadi! Windows ADK veya system DISM gerekli." $Red
        return $null
    }

    $global:dismPath = Find-DismPath
    if (-not $global:dismPath) {
        Write-ColorText "DISM bulunamadığı için script sonlandırılıyor." $Red
        exit 1
    }

    function Remove-WindowsEditions {
        $wimFile = "C:\temp_iso\sources\install.wim"
        do {
            Clear-Host
            Show-Banner
            Write-ColorText "Mevcut Windows surumleri analiz ediliyor..." $Green
            
            $wimInfo = & $global:dismPath /Get-WimInfo /WimFile:$wimFile
            $editions = $wimInfo | Select-String "Index|Name"
            Write-ColorText "Mevcut surumler:" $Yellow
            $editions | ForEach-Object { Write-Host $_.Line }
            $indexCount = ($editions | Where-Object { $_.Line -match "Name" }).Count
            
            if ($indexCount -le 1) { 
                Write-ColorText "Yalnizca bir surum kaldi. Silme islemi atlandi." $Yellow
                Start-Sleep -Seconds 3
                break 
            }

            Write-ColorText "`n[g] Geri don ve duzenlenecek surumu sec" $Cyan
            $choice = Read-Host "Kaldirmak istediginiz surumlerin index numaralarini girin (virgulle ayirarak, orn: 1,3)"

            if ($choice -ieq 'g') { break }

            try {
                $indicesToDelete = $choice.Split(',') | ForEach-Object { [int]$_.Trim() } | Sort-Object -Descending
                
                $validInput = $true
                foreach($index in $indicesToDelete) {
                    if ($index -lt 1 -or $index -gt $indexCount) {
                        Write-ColorText "Gecersiz index numarasi bulundu: $index. Lutfen 1 ile $indexCount arasinda degerler girin." $Red
                        $validInput = $false
                        break
                    }
                }

                if (-not $validInput) {
                    Start-Sleep -Seconds 3
                    continue
                }

                foreach ($index in $indicesToDelete) {
                    Write-ColorText "Index $index kaldiriliyor..." $Yellow
                    try {
                        & $global:dismPath /Delete-Image /ImageFile:$wimFile /Index:$index /CheckIntegrity
                        Write-ColorText "Index $index basariyla kaldirildi!" $Green
                        Start-Sleep -Seconds 1
                    } catch {
                        Write-ColorText "Index $index kaldirilirken hata olustu: $_" $Red
                        Start-Sleep -Seconds 3
                    }
                }
                Write-ColorText "Secilen surumler kaldirildi. Liste guncelleniyor..." $Green
                Start-Sleep -Seconds 2

            } catch {
                Write-ColorText "Gecersiz giris! Lutfen sayilari virgulle ayirarak girin (orn: 1,3)." $Red
                Start-Sleep -Seconds 3
            }
        } while ($true)
    }

    function Mount-WindowsImage {
        Clear-Host
        Show-Banner

        $wimFile = "C:\temp_iso\sources\install.wim"
        Write-ColorText "Mevcut Windows surumleri listeleniyor..." $Green
        $wimInfo = & $global:dismPath /Get-WimInfo /WimFile:$wimFile
        $editions = $wimInfo | Select-String "Index|Name"
        Write-ColorText "Mevcut surumler:" $Yellow
        $editions | ForEach-Object { Write-Host $_.Line }
        $indexCount = ($editions | Where-Object { $_.Line -match "Name" }).Count

        if ($indexCount -eq 1) {
            Write-ColorText "`nWindows imaji C:\mount dizinine mount ediliyor..." $Yellow
            try {
                & $global:dismPath /Mount-Image /ImageFile:$wimFile /Index:1 /MountDir:"C:\mount"
                if ($LASTEXITCODE -ne 0) { throw "Mount işlemi başarısız." }
                Write-ColorText "Image basariyla mount edildi!" $Green
                Start-Sleep -Seconds 3
                return $true
            } catch {
                Write-ColorText "Image mount edilirken hata olustu: $_" $Red
                throw "Mount işlemi başarısız."
            }
        } else {
            $choice = Read-Host "Duzenleme yapmak istediginiz Windows surumunun index numarasini girin"
            if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $indexCount) {
                Write-ColorText "Windows imaji C:\mount dizinine mount ediliyor..." $Yellow
                try {
                    & $global:dismPath /Mount-Image /ImageFile:$wimFile /Index:$choice /MountDir:"C:\mount"
                    if ($LASTEXITCODE -ne 0) { throw "Mount işlemi başarısız." }
                    Write-ColorText "Image basariyla mount edildi!" $Green
                    Start-Sleep -Seconds 3
                    return $true
                } catch {
                    Write-ColorText "Image mount edilirken hata olustu: $_" $Red
                    throw "Mount işlemi başarısız."
                } 
            } else {
                Write-ColorText "Gecersiz index numarasi." $Red
                return $false
            }
        }
    }

    function Add-WindowsUpdates {
        Clear-Host
        Show-Banner
        Write-ColorText "[g] Geri donmek icin 'g' yazin." $Cyan
        $updatesPath = Read-Host "Guncellemelerin bulundugu klasorun yolunu girin"
        if ($updatesPath -ieq 'g') { return }

        if (Test-Path $updatesPath) {
            $updateFiles = Get-ChildItem -Path $updatesPath -Filter "*.msu" -ErrorAction SilentlyContinue
            if ($updateFiles) {
                Write-ColorText "Guncellemeler ekleniyor..." $Green
                foreach ($file in $updateFiles) {
                    Write-ColorText "Ekleniyor: $($file.Name)" $Yellow
                    try {
                        & $global:dismPath /Image:"C:\mount" /Add-Package /PackagePath:"$($file.FullName)" /LogPath=C:\mount\dism.log
                        Write-ColorText "Eklendi: $($file.Name)" $Green
                    } catch {
                        Write-ColorText "$($file.Name) eklenirken hata olustu: $_" $Red
                    }
                }
            } else {
                Write-ColorText "Belirtilen yolda .msu uzantili guncelleme dosyasi bulunamadi." $Red
            }
        } else {
            Write-ColorText "Gecersiz klasor yolu!" $Red
        }
        if ($script:runMode -ne 'AUTOMATIC') { Write-Host -NoNewLine 'Devam etmek icin herhangi bir tusa basin...'; $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown'); }
    }

    function Add-Drivers {
        Clear-Host
        Show-Banner
        Write-ColorText "[g] Geri donmek icin 'g' yazin." $Cyan
        $driversPath = Read-Host "Suruculerin bulundugu ana klasorun yolunu girin"
        if ($driversPath -ieq 'g') { return }

        if (Test-Path $driversPath) {
            Write-ColorText "Suruculer ekleniyor..." $Yellow
            try {
                & $global:dismPath /Image:C:\mount /Add-Driver /Driver:"$driversPath" /Recurse
                Write-ColorText "Suruculer basariyla eklendi." $Green
            } catch {
                Write-ColorText "Suruculer eklenirken hata olustu: $_" $Red
            }
        } else {
            Write-ColorText "Gecersiz klasor yolu!" $Red
        }
        if ($script:runMode -ne 'AUTOMATIC') { Write-Host -NoNewLine 'Devam etmek icin herhangi bir tusa basin...'; $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown'); }
    }

    function Configure-ComponentsAndServices {
        $allTweaks = @(
            [PSCustomObject]@{ ID = 'RemoveIE'; Description = "Internet Explorer'i Kaldir (Eski bilesenleri temizler)"; Type = 'Component'; FeatureName = 'Internet-Explorer-Optional-amd64' },
            [PSCustomObject]@{ ID = 'RemoveWMP'; Description = "Windows Media Player'i Kaldir (Eski medya oynaticiyi kaldirir)"; Type = 'Component'; FeatureName = 'WindowsMediaPlayer' },
            [PSCustomObject]@{ ID = 'DisableTelemetry'; Description = "Telemetri Servislerini Devre Disi Birak (Microsoft'a veri gonderimini engeller)"; Type = 'Service'; ServiceNames = @('DiagTrack', 'dmwappushservice') },
            [PSCustomObject]@{ ID = 'DisableWerSvc'; Description = "Hata Raporlama Servisini Devre Disi Birak (Sorun raporlarini gondermeyi durdurur)"; Type = 'Service'; ServiceNames = @('WerSvc') },
            [PSCustomObject]@{ ID = 'DisableFax'; Description = "Fax Servisini Devre Disi Birak (Gereksiz faks ozelligini kapatir)"; Type = 'Service'; ServiceNames = @('Fax') }
        )

        $tweaksToApply = [System.Collections.Generic.List[object]]::new()

        if ($script:runMode -eq 'AUTOMATIC' -and $global:ScriptConfig.ComponentServiceTweaks.Count -gt 0) {
            Write-ColorText "Yapilandirma dosyasindan bilesen ve servis ayarlari uygulaniyor..." $Cyan
            $selectedTweakIDs = $global:ScriptConfig.ComponentServiceTweaks
            $tweaksToApply.AddRange(($allTweaks | Where-Object { $selectedTweakIDs -contains $_.ID }))
        } else {
            $menuOptions = $allTweaks.Description + "TUMUNU UYGULA"
            $selection = Get-UserChoice -Title "Bilesenleri Kaldir ve Servisleri Yapilandir" -Options $menuOptions -MultiSelect $true
            
            if ($selection -eq 'go_back' -or !$selection) { return }

            if ($selection -contains $menuOptions.Length) {
                $tweaksToApply.AddRange($allTweaks)
            } else {
                $selection | ForEach-Object { $tweaksToApply.Add($allTweaks[$_ - 1]) }
            }
            $global:ScriptConfig.ComponentServiceTweaks = $tweaksToApply.ID
        }

        if ($tweaksToApply.Count -eq 0) {
            Write-ColorText "Uygulanacak ayar secilmedi." $Yellow
            Start-Sleep -Seconds 2
            return
        }

        $servicesToDisable = $tweaksToApply | Where-Object { $_.Type -eq 'Service' }
        if ($servicesToDisable) {
            try {
                Write-ColorText "Servisler yapilandiriliyor..." $Yellow
                REG LOAD HKLM\TEMPSYSTEM C:\mount\Windows\System32\config\SYSTEM
                foreach ($tweak in $servicesToDisable) {
                    foreach ($serviceName in $tweak.ServiceNames) {
                        try {
                            $servicePath = "Registry::HKLM\TEMPSYSTEM\ControlSet001\Services\$serviceName"
                            if (Test-Path $servicePath) {
                                Set-ItemProperty -Path $servicePath -Name "Start" -Value 4 -Type DWord -Force
                                Write-ColorText " -> '$serviceName' servisi devre disi birakildi." $Green
                            } else {
                                Write-ColorText " -> '$serviceName' servisi bulunamadi, atlandi." $Yellow
                            }
                        } catch {
                            Write-ColorText " -> '$serviceName' servisi yapilandirilirken hata: $_" $Red
                        }
                    }
                }
            } finally {
                [gc]::Collect(); [gc]::WaitForPendingFinalizers()
                REG UNLOAD HKLM\TEMPSYSTEM
            }
        }

        $componentsToRemove = $tweaksToApply | Where-Object { $_.Type -eq 'Component' }
        if ($componentsToRemove) {
            Write-ColorText "Bilesenler kaldiriliyor..." $Yellow
            foreach ($tweak in $componentsToRemove) {
                $componentName = ($tweak.Description.Split('(')[0]).Trim()
                Write-ColorText "Islem yapiliyor: $componentName" $Yellow
                try {
                    $featureInfo = & $global:dismPath /Image:C:\mount /Get-FeatureInfo /FeatureName:$($tweak.FeatureName)
                    $featureStateLine = $featureInfo | Select-String "State"
                    
                    if ($featureStateLine) {
                        $featureState = $featureStateLine.Line.Split(':')[1].Trim()
                        if ($featureState -eq 'Enabled') {
                            Write-ColorText " -> Durum: Etkin. Kaldiriliyor..." $Yellow
                            & $global:dismPath /Image:C:\mount /Disable-Feature /FeatureName:$($tweak.FeatureName) /Remove /NoRestart | Out-Null
                            if ($LASTEXITCODE -eq 0) {
                                Write-ColorText " -> Basariyla kaldirildi." $Green
                            } else {
                                Write-ColorText " -> Kaldirilirken hata olustu. DISM Exit Code: $LASTEXITCODE" $Red
                            }
                        } else {
                            Write-ColorText " -> Bilesen etkin degil (Durum: $featureState). Islem atlandi." $Cyan
                        }
                    } else {
                        Write-ColorText " -> Bilesen durumu okunamadi veya bilesen bulunamadi. Islem atlandi." $Cyan
                    }
                } catch {
                    Write-ColorText " -> Bilesen durumu kontrol edilirken veya kaldirilirken kritik hata: $_" $Red
                }
            }
        }

        if ($script:runMode -ne 'AUTOMATIC') { Write-Host -NoNewLine 'Devam etmek icin herhangi bir tusa basin...'; $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown'); }
    }

    function Set-Registry {
        $registryTweaks = @(
            [PSCustomObject]@{ Description = "Windows Update: Indirmeden once bildir"; Action = "InlineScript"; Code = "try { $auPath = 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\WindowsUpdate\AU'; if (-not (Test-Path $auPath)) { New-Item -Path $auPath -Force | Out-Null }; Set-ItemProperty -Path $auPath -Name 'AUOptions' -Value 2 -Type DWord -Force; Set-ItemProperty -Path $auPath -Name 'NoAutoUpdate' -Value 1 -Type DWord -Force } catch {}" },
            [PSCustomObject]@{ Description = "Windows Update: Otomatik indir, yuklemeden once bildir"; Action = "InlineScript"; Code = "try { $auPath = 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\WindowsUpdate\AU'; if (-not (Test-Path $auPath)) { New-Item -Path $auPath -Force | Out-Null }; Set-ItemProperty -Path $auPath -Name 'AUOptions' -Value 3 -Type DWord -Force; Set-ItemProperty -Path $auPath -Name 'NoAutoUpdate' -Value 0 -Type DWord -Force } catch {}" },
            [PSCustomObject]@{ Description = "Microsoft Store uygulamasini gorev cubuguna sabitlemeyi engelle"; Action = "Registry"; Hive = "HKU"; Path = "HKU\TEMP\Software\Policies\Microsoft\Windows\Explorer"; Name = "NoPinningStoreToTaskbar"; Value = 1; Type = "DWord" },
            [PSCustomObject]@{ Description = "Masaustune 'Bu Bilgisayar' ekle"; Action = "Registry"; Hive = "HKLM"; Path = "HKLM\TEMP\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel"; Name = "{20D04FE0-3AEA-1069-A2D8-08002B30309D}"; Value = 0; Type = "DWord" },
            [PSCustomObject]@{ Description = "Masaustune 'Geri Donusum Kutusu' ekle"; Action = "Registry"; Hive = "HKLM"; Path = "HKLM\TEMP\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel"; Name = "{645FF040-5081-101B-9F08-00AA002F954E}"; Value = 0; Type = "DWord" },
            [PSCustomObject]@{ Description = "Masaustune 'Kullanici Klasoru' ekle"; Action = "Registry"; Hive = "HKLM"; Path = "HKLM\TEMP\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel"; Name = "{59031a47-3f72-44a7-89c5-5595fe6b30ee}"; Value = 0; Type = "DWord" },
            [PSCustomObject]@{ Description = "Gorev cubugunda Arama simgesini gizle"; Action = "SetupScript"; Code = "try { Set-ItemProperty -Path 'Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Search' -Name 'SearchboxTaskbarMode' -Value 0 -Force } catch {}" },
            [PSCustomObject]@{ Description = "Baslat menusunde Bing web sonuclarini devre disi birak"; Action = "Registry"; Hive = "HKU"; Path = "HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Search"; Name = "BingSearchEnabled"; Value = 0; Type = "DWord" },
            [PSCustomObject]@{ Description = "Gorev cubugunu sola hizala"; Action = "Registry"; Hive = "HKU"; Path = "HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "TaskbarAl"; Value = 0; Type = "DWord" },
            [PSCustomObject]@{ Description = "Gorev cubugundan 'Haberler ve Ilgi Alanlari' (Widgets) simgesini kaldir"; Action = "Registry"; Hive = "HKLM"; Path = "HKLM\TEMP\Policies\Microsoft\Dsh"; Name = "AllowNewsAndInterests"; Value = 0; Type = "DWord" },
            [PSCustomObject]@{ Description = "Gorev cubugundan 'Gorev Gorunumu' simgesini kaldir"; Action = "Registry"; Hive = "HKU"; Path = "HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "ShowTaskViewButton"; Value = 0; Type = "DWord" },
            [PSCustomObject]@{ Description = "Detayli kopyalama diyalogunu etkinlestir"; Action = "Registry"; Hive = "HKU"; Path = "HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\OperationStatusManager"; Name = "EnthusiastMode"; Value = 1; Type = "DWord" },
            [PSCustomObject]@{ Description = "Dosya Gezgini'nde kompakt gorunumu etkinlestir"; Action = "Registry"; Hive = "HKU"; Path = "HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "UseCompactMode"; Value = 1; Type = "DWord" },
            [PSCustomObject]@{ Description = "Dosya Gezgini'ni 'Bu Bilgisayar' ile baslat"; Action = "Registry"; Hive = "HKU"; Path = "HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "LaunchTo"; Value = 1; Type = "DWord" },
            [PSCustomObject]@{ Description = "Telemetri ve veri toplamayi devre disi birak"; Action = "Registry"; Hive = "HKLM"; Path = "HKLM\TEMP\Policies\Microsoft\Windows\DataCollection"; Name = "AllowTelemetry"; Value = 0; Type = "DWord" },
            [PSCustomObject]@{ Description = "Otomatik onerilen uygulama kurulumunu engelle (Consumer Features)"; Action = "Registry"; Hive = "HKLM"; Path = "HKLM\TEMP\Policies\Microsoft\Windows\CloudContent"; Name = "DisableWindowsConsumerFeatures"; Value = 1; Type = "DWord" },
            [PSCustomObject]@{ Description = "Kilit ekraninda ipuclari ve onerileri devre disi birak (Spotlight)"; Action = "Registry"; Hive = "HKU"; Path = "HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SubscribedContent-338387Enabled"; Value = 0; Type = "DWord" },
            [PSCustomObject]@{ Description = "Cortana icin veri toplamayi devre disi birak"; Action = "Registry"; Hive = "HKLM"; Path = "HKLM\TEMP\Policies\Microsoft\Windows\Windows Search"; Name = "AllowCortana"; Value = 0; Type = "DWord" },
            [PSCustomObject]@{ Description = "Reklam kimliginin uygulamalarla paylasimini engelle"; Action = "Registry"; Hive = "HKLM"; Path = "HKLM\TEMP\Policies\Microsoft\Windows\AdvertisingInfo"; Name = "DisabledByGroupPolicy"; Value = 1; Type = "DWord" },
            [PSCustomObject]@{ Description = "Yazma verisinin Microsoft'a gonderilmesini engelle"; Action = "Registry"; Hive = "HKLM"; Path = "HKLM\TEMP\Policies\Microsoft\Windows\TabletPC"; Name = "PreventHandwritingDataSharing"; Value = 1; Type = "DWord" },
            [PSCustomObject]@{ Description = "Baslat menusunde 'Onerilenler' bolumunu gizle"; Action = "InlineScript"; Code = "try { New-Item -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\Explorer' -Force -ErrorAction SilentlyContinue | Out-Null; New-ItemProperty -Path 'Registry::HKLM\TEMP\Policies\Microsoft\Windows\Explorer' -Name 'HideRecommendedSection' -Value 1 -Type DWord -Force } catch {}; try { New-Item -Path 'Registry::HKLM\TEMP\Microsoft\PolicyManager\current\device\Start' -Force -ErrorAction SilentlyContinue | Out-Null; New-ItemProperty -Path 'Registry::HKLM\TEMP\Microsoft\PolicyManager\current\device\Start' -Name 'HideRecommendedSection' -Value 1 -Type DWord -Force; New-Item -Path 'Registry::HKLM\TEMP\Microsoft\PolicyManager\current\device\Education' -Force -ErrorAction SilentlyContinue | Out-Null; New-ItemProperty -Path 'Registry::HKLM\TEMP\Microsoft\PolicyManager\current\device\Education' -Name 'IsEducationEnvironment' -Value 1 -Type DWord -Force; } catch {}" },
            [PSCustomObject]@{ Description = "Hazir kurulu OEM uygulamalarini engelle"; Action = "InlineScript"; Code = "try { Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'OemPreInstalledAppsEnabled' -Value 0 -Type DWord -Force; Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'PreInstalledAppsEnabled' -Value 0 -Type DWord -Force; Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'PreInstalledAppsEverEnabled' -Value 0 -Type DWord -Force; Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SilentInstalledAppsEnabled' -Value 0 -Type DWord -Force } catch {}" },
            [PSCustomObject]@{ Description = "Ayarlar uygulamasindaki promosyon bildirimlerini kapat"; Action = "Registry"; Hive = "HKU"; Path = "HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "SettingsPageNotifications"; Value = 0; Type = "DWord" },
            [PSCustomObject]@{ Description = "Ayarlar uygulamasindaki onerilen icerikleri kapat"; Action = "Registry"; Hive = "HKU"; Path = "HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SubscribedContent-338389Enabled"; Value = 0; Type = "DWord" },
            [PSCustomObject]@{ Description = "Dokunmatik klavyede cevrimici metin tamamlamayi kapat"; Action = "Registry"; Hive = "HKU"; Path = "HKU\TEMP\Software\Microsoft\Input\Settings"; Name = "isPreemptiveTypingEnabled"; Value = 0; Type = "DWord" },
            [PSCustomObject]@{ Description = "Edge icin SmartScreen'i devre disi birak"; Action = "Registry"; Hive = "HKLM"; Path = "HKLM\TEMP\Policies\Microsoft\Windows\System"; Name = "EnableSmartScreen"; Value = 0; Type = "DWord" },
            [PSCustomObject]@{ Description = "Windows Copilot'u devre disi birak"; Action = "Registry"; Hive = "HKU"; Path = "HKU\TEMP\Software\Policies\Microsoft\Windows\WindowsCopilot"; Name = "TurnOffWindowsCopilot"; Value = 1; Type = "DWord" },
            [PSCustomObject]@{ Description = "Windows Copilot+ Recall ozelligini devre disi birak (24H2)"; Action = "Registry"; Hive = "HKLM"; Path = "HKLM\TEMP\Policies\Microsoft\Windows\WindowsAI"; Name = "AllowRecallEnablement"; Value = 0; Type = "DWord" },
            [PSCustomObject]@{ Description = "Yeniden baslatirken uygulamalari otomatik olarak geri yukle"; Action = "Registry"; Hive = "HKU"; Path = "HKU\TEMP\Software\Microsoft\Windows NT\CurrentVersion\Winlogon"; Name = "RestartApps"; Value = 1; Type = "DWord" },
            [PSCustomObject]@{ Description = "Kurulumda cevrimdisi (yerel) hesap kullanmaya zorla (OOBE)"; Action = "Registry"; Hive = "HKLM"; Path = "HKLM\TEMP\Microsoft\Windows\CurrentVersion\OOBE"; Name = "BypassNRO"; Value = 1; Type = "DWord" },
            [PSCustomObject]@{ Description = "Yapiskan Tuslar uyarilarini devre disi birak"; Action = "Registry"; Hive = "HKU"; Path = "HKU\TEMP\Control Panel\Accessibility\StickyKeys"; Name = "Flags"; Value = "506"; Type = "String" },
            [PSCustomObject]@{ Description = "Depolama Bilinci'ni (Storage Sense) etkinlestir ve otomatik calistir"; Action = "Registry"; Hive = "HKLM"; Path = "HKLM\TEMP\Policies\Microsoft\Windows\StorageSense"; Name = "AllowStorageSenseTemporaryFilesCleanup"; Value = 1; Type = "DWord" },
            [PSCustomObject]@{ Description = "Microsoft Edge otomatik kisayol olusturmayi devre disi birak"; Action = "Registry"; Hive = "HKLM"; Path = "HKLM\TEMP\Policies\Microsoft\EdgeUpdate"; Name = "CreateDesktopShortcutDefault"; Value = 0; Type = "DWord" },
            [PSCustomObject]@{ Description = "En son istege bagli guncellemeleri otomatik almayi engelle"; Action = "Registry"; Hive = "HKLM"; Path = "HKLM\TEMP\Microsoft\WindowsUpdate\UX\Settings"; Name = "IsContinuousInnovationOptedIn"; Value = 0; Type = "DWord" },
            [PSCustomObject]@{ Description = "Dosya uzantilarini goster"; Action = "Registry"; Hive = "HKU"; Path = "HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "HideFileExt"; Value = 0; Type = "DWord" },
            [PSCustomObject]@{ Description = "Gorev cubugunda sag tik ile 'Gorevi Sonlandir'"; Action = "Registry"; Hive = "HKU"; Path = "HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings"; Name = "TaskbarEndTask"; Value = 1; Type = "DWord" },
            [PSCustomObject]@{ Description = "Windows Spotlight duvar kagıdı ve ozellikleri"; Action = "InlineScript"; Code = "try { New-Item -Path 'Registry::HKU\TEMP\Software\Policies\Microsoft\Windows\CloudContent' -Force -ErrorAction SilentlyContinue | Out-Null; Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Policies\Microsoft\Windows\CloudContent' -Name 'DisableWindowsSpotlightFeatures' -Value 1 -Type DWord -Force; Set-ItemProperty -Path 'Registry::HKU\TEMP\Software\Policies\Microsoft\Windows\CloudContent' -Name 'DisableSpotlightCollectionOnDesktop' -Value 1 -Type DWord -Force } catch {}; try { Set-ItemProperty -Path 'Registry::HKU\TEMP\Control Panel\Desktop' -Name 'WallPaper' -Value 'C:\Windows\Web\Wallpaper\Windows\img0.jpg' -Force } catch {}" },
            [PSCustomObject]@{ Description = "OneDrive otomatik kurulumu devre disi birak"; Action = "Registry"; Hive = "HKU"; Path = "HKU\TEMP\Software\Microsoft\Windows\CurrentVersion\Run"; Name = "OneDriveSetup"; Value = $null; Type = "Remove" }
        )
        $finalSetupScript = "[System.Threading.Thread]::Sleep(5000); try { Remove-Item -Path 'Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount' -Recurse -Force; Stop-Process -Name explorer -Force } catch {}"
        
        $tweaksToApply = [System.Collections.Generic.List[object]]::new()

        if ($script:runMode -eq 'AUTOMATIC' -and $global:ScriptConfig.RegistryTweaks.Count -gt 0) {
            Write-ColorText "Yapilandirma dosyasindan registry ayarlari uygulaniyor..." $Cyan
            $selectedTweakDescriptions = $global:ScriptConfig.RegistryTweaks
            $tweaksToApply.AddRange(($registryTweaks | Where-Object { $selectedTweakDescriptions -contains $_.Description }))
        } else {
            $menuOptions = $registryTweaks.Description + "TUMUNU UYGULA"
            $selection = Get-UserChoice -Title "Registry yapilandirmalarini uygula" -Options $menuOptions -MultiSelect $true
            
            if ($selection -eq 'go_back' -or !$selection) { return }

            if ($selection -contains $menuOptions.Length) {
                $updateOptions = @(
                    "Windows Update: Indirmeden once bildir",
                    "Windows Update: Otomatik indir, yuklemeden once bildir"
                )
                $tweaksToApply.AddRange(($registryTweaks | Where-Object { $_.Description -notin $updateOptions }))
                
                Write-ColorText "`nTüm ayarlar seçildi. Lütfen Windows Update için bir tercih yapın:" $Yellow
                Write-Host "[1] Indirmeden once bildir"
                Write-Host "[2] Otomatik indir, yuklemeden once bildir"
                $updateChoice = Read-Host "Seciminiz (1/2)"
                if ($updateChoice -eq '1') {
                    $tweaksToApply.Add(($registryTweaks | Where-Object { $_.Description -eq $updateOptions[0] }))
                } elseif ($updateChoice -eq '2') {
                    $tweaksToApply.Add(($registryTweaks | Where-Object { $_.Description -eq $updateOptions[1] }))
                }
            } else {
                $selection | ForEach-Object { $tweaksToApply.Add($registryTweaks[$_ - 1]) }
            }
            $global:ScriptConfig.RegistryTweaks = $tweaksToApply.Description
        }
        
        $updateOptions = @(
            "Windows Update: Indirmeden once bildir",
            "Windows Update: Otomatik indir, yuklemeden once bildir"
        )
        $selectedUpdateOptions = $tweaksToApply.Description | Where-Object { $updateOptions -contains $_ }

        if ($selectedUpdateOptions.Count -gt 1) {
            if ($script:runMode -eq 'AUTOMATIC') {
                Write-ColorText "Uyarı: Birden fazla Windows Update ayarı algılandı. Yalnızca ilki uygulanacak: '$($selectedUpdateOptions[0])'" $Yellow
                $firstOption = $selectedUpdateOptions[0]
                $tweaksToApply = $tweaksToApply | Where-Object { ($_.Description -notin $updateOptions) -or ($_.Description -eq $firstOption) }
            } else {
                Write-ColorText "Hata: Windows Update için yalnızca bir seçenek belirleyebilirsiniz. Lütfen tekrar deneyin." $Red
                Start-Sleep -Seconds 3
                return
            }
        }

        if ($tweaksToApply.Count -eq 0) {
            Write-ColorText "Uygulanacak registry ayari secilmedi." $Yellow
            Start-Sleep -Seconds 2
            return
        }

        try {
            REG LOAD HKLM\TEMP C:\mount\Windows\System32\config\SOFTWARE
            REG LOAD HKU\TEMP C:\mount\Users\Default\NTUSER.DAT

            $setupScriptContent = [System.Text.StringBuilder]::new()
            
            foreach ($tweak in $tweaksToApply) {
                Write-ColorText "Uygulaniyor: $($tweak.Description)" $Yellow
                try {
                    switch ($tweak.Action) {
                        "Registry" {
                            $regPath = "Registry::$($tweak.Path)"
                            if ($tweak.Type -eq "Remove") {
                                if (Test-Path $regPath) { Remove-ItemProperty -Path $regPath -Name $tweak.Name -Force -ErrorAction SilentlyContinue }
                            } else {
                                if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
                                Set-ItemProperty -Path $regPath -Name $tweak.Name -Value $tweak.Value -Type $tweak.Type -Force
                            }
                            Write-ColorText " -> Basarili." $Green
                            break
                        }
                        "InlineScript" {
                            Invoke-Command -ScriptBlock ([scriptblock]::Create($tweak.Code))
                            Write-ColorText " -> Basarili." $Green
                            break
                        }
                        "SetupScript" {
                            $setupScriptContent.AppendLine($tweak.Code) | Out-Null
                            Write-ColorText " -> Kurulum sonrasi icin siraya eklendi." $Cyan
                            break
                        }
                    }
                } catch {
                    Write-ColorText " -> Yapilandirma BASARISIZ oldu: $($tweak.Description). Error: $_" $Red
                }
            }

            if ($setupScriptContent.Length -gt 0) {
                $setupScriptContent.AppendLine($finalSetupScript) | Out-Null
                $scriptsPath = "C:\mount\Windows\Setup\Scripts"
                if (-not (Test-Path $scriptsPath)) {
                    New-Item -ItemType Directory -Path $scriptsPath -Force | Out-Null
                }
                $setupScriptContent.ToString() | Out-File -FilePath "$scriptsPath\registry-config.ps1" -Encoding utf8
                Write-ColorText "Kurulum sonrasi script basariyla olusturuldu." $Green

                $desktopPath = "C:\mount\Users\Default\Desktop"
                if (-not (Test-Path $desktopPath)) {
                    New-Item -ItemType Directory -Path $desktopPath -Force | Out-Null
                }
                $batContent = @"
@echo off
echo Ayarlar uygulaniyor, lutfen bekleyin...
powershell.exe -ExecutionPolicy Bypass -File "%SystemRoot%\Setup\Scripts\registry-config.ps1"
echo.
echo Islem tamamlandi. Bu pencereyi kapatabilirsiniz.
pause
del "%~f0"
"@
                $batContent | Out-File -FilePath "$desktopPath\run after internet connection.bat" -Encoding OEM
                Write-ColorText "Masaustu icin otomatik calistirici olusturuldu." $Green
            }
            
        } finally {
            Write-ColorText "Registry yapilandirmasi kaydediliyor..." $Yellow
            [gc]::Collect(); [gc]::WaitForPendingFinalizers()
            REG UNLOAD HKU\TEMP
            REG UNLOAD HKLM\TEMP
            Write-ColorText "Registry yapilandirmasi tamamlandi." $Green
            if ($script:runMode -ne 'AUTOMATIC') { Write-Host -NoNewLine 'Devam etmek icin herhangi bir tusa basin...'; $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown'); }
        }
    }

    function Remove-WindowsApps {
        $mountPath = "C:\mount"
        $packagesToRemove = [System.Collections.Generic.List[string]]::new()

        if ($script:runMode -eq 'AUTOMATIC' -and $global:ScriptConfig.RemovedApps.Count -gt 0) {
            Write-ColorText "Yapilandirma dosyasindan uygulamalar kaldiriliyor..." $Cyan
            $packagesToRemove.AddRange([string[]]$global:ScriptConfig.RemovedApps)
        } else {
            Write-ColorText "ISO icindeki kurulu uygulamalarin listesi aliniyor. Bu islem biraz surebilir..." $Yellow
            $dismOutput = & $global:dismPath /Image:$mountPath /Get-ProvisionedAppxPackages
            if ($LASTEXITCODE -ne 0) {
                Write-ColorText "Uygulama listesi alinamadi. DISM Exit Code: $LASTEXITCODE" $Red
                if ($script:runMode -ne 'AUTOMATIC') { Write-Host -NoNewLine 'Devam etmek icin herhangi bir tusa basin...'; $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown'); }
                return
            }

            $allAppPackages = [System.Collections.Generic.List[object]]::new()
            $packageBlocks = ($dismOutput -join "`n") -split '(?:\r?\n){2,}'
            foreach ($block in $packageBlocks) {
                $displayNameMatch = [regex]::Match($block, "DisplayName\s*:\s*(.+)")
                $packageNameMatch = [regex]::Match($block, "PackageName\s*:\s*(.+)")
                if ($displayNameMatch.Success -and $packageNameMatch.Success) {
                    $allAppPackages.Add([PSCustomObject]@{
                        DisplayName = $displayNameMatch.Groups[1].Value.Trim()
                        PackageName = $packageNameMatch.Groups[1].Value.Trim()
                    })
                }
            }
            $allAppPackages = $allAppPackages | Sort-Object DisplayName

            $exclusionList = @(
                "Microsoft.ApplicationCompatibilityEnhancements*", "Microsoft.AV1VideoExtension*",
                "Microsoft.AVCEncoderVideoExtension*", "Microsoft.BingSearch*",
                "Microsoft.DesktopAppInstaller*", "Microsoft.HEIFImageExtension*",
                "Microsoft.HEVCVideoExtension*", "Microsoft.MPEG2VideoExtension*",
                "Microsoft.RawImageExtension*", "Microsoft.SecHealthUI*",
                "Microsoft.StorePurchaseApp*", "Microsoft.VP9VideoExtensions*",
                "Microsoft.WebMediaExtensions*", "Microsoft.WebpImageExtension*",
                "Microsoft.WindowsStore*", "MicrosoftWindows.Client.WebExperience*"
            )

            Write-ColorText "Kritik sistem uygulamalari liste disi birakiliyor..." $Cyan
            $filteredAppPackages = $allAppPackages | Where-Object {
                $currentPackage = $_
                $isExcluded = $false
                foreach ($pattern in $exclusionList) {
                    if ($currentPackage.PackageName -like $pattern) {
                        $isExcluded = $true
                        break
                    }
                }
                -not $isExcluded
            }
            
            if (-not $filteredAppPackages) {
                Write-ColorText "Kaldirilabilecek uygulama bulunamadi." $Cyan
                if ($script:runMode -ne 'AUTOMATIC') { Write-Host -NoNewLine 'Devam etmek icin herhangi bir tusa basin...'; $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown'); }
                return
            }

            $menuOptions = $filteredAppPackages.DisplayName + "TUMUNU UYGULA"
            $selection = Get-UserChoice -Title "Hangi uygulamalari kaldirmak istiyorsunuz?" -Options $menuOptions -MultiSelect $true
            if ($selection -eq 'go_back' -or !$selection) { return }

            if ($selection -contains $menuOptions.Length) {
                $packagesToRemove.AddRange($filteredAppPackages.PackageName)
            } else {
                foreach ($selectedIndex in $selection) {
                    $packagesToRemove.Add($filteredAppPackages[$selectedIndex - 1].PackageName)
                }
            }
            $global:ScriptConfig.RemovedApps = $packagesToRemove
        }

        if ($packagesToRemove.Count -eq 0) {
            Write-ColorText "Kaldirilacak uygulama secilmedi." $Yellow
            Start-Sleep -Seconds 2
            return
        }

        Write-ColorText "`nKaldirma islemi basliyor..." $Green
        foreach ($packageName in $packagesToRemove) {
            Write-ColorText "Kaldiriliyor: $packageName" $Yellow
            try {
                & $global:dismPath /Image:$mountPath /Remove-ProvisionedAppxPackage /PackageName:$packageName | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-ColorText "Basarili bir sekilde kaldirildi: $packageName" $Green
                } else {
                    Write-ColorText "Kaldirilamadi: $packageName. DISM Exit Code: $LASTEXITCODE" $Red
                }
            } catch {
                Write-ColorText "$packageName kaldirilirken hata: $_" $Red
            }
        }
        
        Write-ColorText "`nUygulama kaldirma islemi tamamlandi." $Cyan
        if ($script:runMode -ne 'AUTOMATIC') { Write-Host -NoNewLine 'Devam etmek icin herhangi bir tusa basin...'; $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown'); }
    }

    function Enable-Features {
        $allAvailableFeatures = @(
            [PSCustomObject]@{ Name = ".NET Framework 3.5 (2 ve 3 dahil)"; FeatureName = "NetFx3"; Source = "C:\temp_iso\sources\sxs" },
            [PSCustomObject]@{ Name = ".NET Framework 4.8 Advanced Services"; FeatureName = "NetFx4-AdvSrvs"; Source = "C:\temp_iso\sources\sxs" },
            [PSCustomObject]@{ Name = "Telnet Istemcisi"; FeatureName = "TelnetClient"; Source = $null }
        )
        $featuresToEnable = [System.Collections.Generic.List[object]]::new()

        if ($script:runMode -eq 'AUTOMATIC' -and $global:ScriptConfig.EnabledFeatures.Count -gt 0) {
            Write-ColorText "Yapilandirma dosyasindan ozellikler etkinlestiriliyor..." $Cyan
            $selectedFeatureNames = $global:ScriptConfig.EnabledFeatures
            $featuresToEnable.AddRange(($allAvailableFeatures | Where-Object { $selectedFeatureNames -contains $_.Name }))
        } else {
            $menuOptions = $allAvailableFeatures.Name + "Tum onerilen ozellikleri etkinlestir"
            $selection = Get-UserChoice -Title "Hangi ozellikleri etkinlestirmek istiyorsunuz?" -Options $menuOptions -MultiSelect $true
            if ($selection -eq 'go_back' -or !$selection) { return }

            if ($selection -contains $menuOptions.Length) {
                $featuresToEnable.AddRange($allAvailableFeatures)
            } else {
                $selection | ForEach-Object { $featuresToEnable.Add($allAvailableFeatures[$_ - 1]) }
            }
            $global:ScriptConfig.EnabledFeatures = $featuresToEnable.Name
        }
        
        if ($featuresToEnable.Count -eq 0) {
            Write-ColorText "Etkinlestirilecek ozellik secilmedi." $Yellow
            Start-Sleep -Seconds 2
            return
        }

        foreach ($feature in $featuresToEnable) {
            Write-ColorText "$($feature.Name) etkinlestiriliyor..." $Green
            try {
                $dismParams = @("/Image:C:\mount", "/Enable-Feature", "/FeatureName:$($feature.FeatureName)", "/All")
                if ($feature.Source) {
                    $dismParams += @("/LimitAccess", "/Source:$($feature.Source)")
                }
                & $global:dismPath $dismParams
                Write-ColorText "$($feature.Name) basariyla etkinlestirildi." $Green
            } catch {
                Write-ColorText "Hata: $($feature.Name) etkinlestirilemedi. $_" $Red
            }
        }
        
        if ($script:runMode -ne 'AUTOMATIC') { Write-Host -NoNewLine 'Devam etmek icin herhangi bir tusa basin...'; $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown'); }
    }

    function Complete-Image {
        Remove-Item -Path "C:\mount\dism.log" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
        
        try {
            $commitScriptBlock = {
                & $using:global:dismPath /Unmount-Image /MountDir:"C:\mount" /Commit
                if ($LASTEXITCODE -ne 0) { throw "Unmount/Commit işlemi başarısız oldu. Cikis Kodu: $LASTEXITCODE" }
            }
            Invoke-LongRunningOperation -ScriptBlock $commitScriptBlock -Message "Image degisiklikleri kaydediliyor, bu islem uzun surebilir..."
            
        } catch {
            Write-ColorText "`nImage kaydedilirken kritik bir hata olustu: $_" $Red
            throw "Image sonlandırılamadı."
        }
        
        Write-ColorText "Yeni ISO olusturuluyor..." $Green
        $isoTool = Get-IsoTool
        if (-not $isoTool) {
            Write-ColorText "ISO olusturma araci bulunamadi veya indirilemedi. Islem iptal ediliyor." $Red
            Write-ColorText "Degisiklikleriniz C:\temp_iso klasorunde hazir durumda. ISO'yu manuel olusturabilirsiniz." $Yellow
            return
        }

        Add-Type -AssemblyName System.Windows.Forms
        $SaveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
        $SaveFileDialog.Title = "Cikti ISO dosyasinin kaydedilecegi yeri secin"
        $SaveFileDialog.Filter = "ISO files (*.iso)|*.iso|All files (*.*)|*.*"
        $SaveFileDialog.DefaultExt = "iso"
        $SaveFileDialog.FileName = "Custom_Windows11.iso"
        $SaveFileDialog.InitialDirectory = [Environment]::GetFolderPath("Desktop")

        if ($SaveFileDialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
            Write-ColorText "Cikti yolu secilmedi. ISO olusturma iptal edildi." $Red
            return
        }
        $outputIso = $SaveFileDialog.FileName
        Write-Host "Cikti ISO dosyasi yolu: $outputIso" -ForegroundColor Green

        try {
            if ($isoTool.Tool -eq 'oscdimg') {
                $bootData = '2#p0,e,bC:\temp_iso\boot\etfsboot.com#pEF,e,bC:\temp_iso\efi\microsoft\boot\efisys.bin'
                & $isoTool.Path -m -o -u2 -udfver102 -bootdata:$bootData C:\temp_iso $outputIso
            } else { # mkisofs
                $toolDir = Split-Path $isoTool.Path -Parent
                & $isoTool.Path -iso-level 4 -l -r -J -joliet-long -no-emul-boot -boot-load-size 8 -b "boot/etfsboot.com" -c "boot/boot.catalog" -eltorito-alt-boot -no-emul-boot -eltorito-boot "efi/microsoft/boot/efisys.bin" -o $outputIso "C:\temp_iso"
            }
            Write-ColorText "ISO basariyla olusturuldu: $outputIso" $Green
            Cleanup
        } catch {
            Write-ColorText "ISO olusturulurken hata olustu: $_" $Red
            Write-ColorText "Dosyalariniz C:\temp_iso klasorunde korunuyor." $Yellow
        }
    }

    function Cleanup {
        Write-ColorText "Gecici dosyalar ve klasorler temizleniyor..." $Green
        [gc]::Collect(); [gc]::WaitForPendingFinalizers()
        
        try { REG UNLOAD HKU\TEMP 2>$null } catch {}
        try { REG UNLOAD HKLM\TEMP 2>$null } catch {}
        
        if (Test-Path "C:\mount\Windows") {
            Write-ColorText "Hala mount edilmis bir imaj var, degisiklikler iptal ediliyor..." $Yellow
            & $global:dismPath /Unmount-Image /MountDir:"C:\mount" /Discard
        }

        if (Test-Path "C:\temp_iso") { Remove-Item "C:\temp_iso" -Recurse -Force -ErrorAction SilentlyContinue }
        if (Test-Path "C:\mount") { Remove-Item "C:\mount" -Recurse -Force -ErrorAction SilentlyContinue }
        
        Write-ColorText "Temizlik tamamlandi!" $Green
    }


    # --- SCRIPT BAŞLANGICI ---

    Show-Banner
        
    if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
        Write-ColorText "Bu script yonetici olarak calistirilmalidir!" $Red
        Start-Sleep -Seconds 5
        exit 1
    }

    if (Test-Path "C:\mount\Windows") {
        Write-ColorText "Mevcut bir mount islemi bulundu. Dogrudan menuye geciliyor..." $Yellow
        Start-Sleep -Seconds 3
    } else {
        if ([string]::IsNullOrWhiteSpace($IsoPath)) {
            Add-Type -AssemblyName System.Windows.Forms
            $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
            $OpenFileDialog.Title = "Windows 11 ISO dosyasini secin"
            $OpenFileDialog.Filter = "ISO files (*.iso)|*.iso|All files (*.*)|*.*"
            $OpenFileDialog.InitialDirectory = [Environment]::GetFolderPath("Desktop")
            
            if ($OpenFileDialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
                Write-Host "ISO dosyasi secilmedi. Script sonlandiriliyor." -ForegroundColor Red
                exit
            }
            $IsoPath = $OpenFileDialog.FileName
            Write-Host "Secilen ISO dosyasi: $IsoPath" -ForegroundColor Green
        }
        if (-not (Test-Path $IsoPath) -or $IsoPath -notlike "*.iso") {
            Write-ColorText "ISO dosyasi bulunamadi veya gecersiz: $IsoPath" $Red
            exit 1
        }
        Write-ColorText "ISO dosyasi bulundu: $IsoPath" $Green
            
        Initialize-Environment
        Copy-IsoFiles -IsoPath $IsoPath
        Remove-WindowsEditions

        if (-not (Mount-WindowsImage)) {
            Write-ColorText "Image mount edilemedi. Script sonlandiriliyor." $Red
            Cleanup
            exit 1
        }

        Show-Banner
        $updateChoice = Read-Host "Windows Guncellemesi eklemek ister misiniz? (E/H)"
        if ($updateChoice -ieq 'E') { Add-WindowsUpdates }

        Show-Banner
        $driverChoice = Read-Host "Surucu eklemek ister misiniz? (E/H)"
        if ($driverChoice -ieq 'E') { Add-Drivers }

        if (Import-Configuration) {
            $script:runMode = 'AUTOMATIC'
        }
    }

    # --- YÜRÜTME BLOĞU ---

    if ($script:runMode -eq 'AUTOMATIC') {
        Write-ColorText "`n--- OTOMATIK ISLEMLER BASLATILDI ---" $Cyan
        if ($global:ScriptConfig.ComponentServiceTweaks.Count -gt 0) { Configure-ComponentsAndServices }
        if ($global:ScriptConfig.RegistryTweaks.Count -gt 0) { Set-Registry }
        if ($global:ScriptConfig.RemovedApps.Count -gt 0) { Remove-WindowsApps }
        if ($global:ScriptConfig.EnabledFeatures.Count -gt 0) { Enable-Features }
        Write-ColorText "`n--- OTOMATIK ISLEMLER TAMAMLANDI ---" $Cyan

        $extraChoice = Read-Host "Otomatik işlemler tamamlandı. Ekstra bir işlem yapmak (manuel moda geçmek) ister misiniz? (E/H)"
        if ($extraChoice -ieq 'E') {
            $script:runMode = 'MANUAL'
        } else {
            Write-ColorText "ISO olusturma asamasina geciliyor..." $Green
            Start-Sleep -Seconds 2
            Complete-Image
            $script:runMode = 'FINISHED'
        }
    }

    if ($script:runMode -eq 'MANUAL') {
        do {
            Clear-Host
            Show-Banner
            Write-ColorText "1. Windows Guncellemesi Ekle (.msu)" $White
            Write-ColorText "2. Surucu Ekle (.inf)" $White
            Write-ColorText "3. Bilesenleri Kaldir ve Servisleri Yapilandir" $White
            Write-ColorText "4. Registry Ayarlarini Yapilandir" $White
            Write-ColorText "5. Windows Uygulamalarini Kaldir" $White
            Write-ColorText "6. Windows Ozelliklerini Etkinlestir" $White
            Write-ColorText "7. Ayarlari Disa Aktar (.json)" $Cyan
            Write-ColorText "8. Degisiklikleri Kaydet ve ISO Olustur" $Green
            Write-ColorText "9. Degisiklikleri Kaydetme ve Cik" $Red
            Write-Host ""
            
            $choice = Read-Host "Seciminizi yapin"
            
            switch ($choice) {
                "1" { Add-WindowsUpdates }
                "2" { Add-Drivers }
                "3" { Configure-ComponentsAndServices }
                "4" { Set-Registry }
                "5" { Remove-WindowsApps }
                "6" { Enable-Features }
                "7" { Export-Configuration }
                "8" { Complete-Image; $choice = "exit" }
                "9" { Cleanup; $choice = "exit" }
                default { 
                    Write-Host "Gecersiz secim!" -ForegroundColor Red
                    Start-Sleep -Seconds 2
                }
            }
        } while ($choice -ne "exit")
    }

    Write-ColorText "Islem tamamlandi. Cikmak icin herhangi bir tusa basin..." $Yellow
    Read-Host
}

# --- SCRIPT'İ BAŞLAT ---
# Tüm fonksiyonlar tanımlandıktan sonra ana fonksiyonu çağır.
Start-IsoCustomizer