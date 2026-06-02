# Conservative allow-list of removable Windows capabilities.

$allRemovableCapabilities = @(
    [PSCustomObject]@{
        Name = 'App.StepsRecorder~~~~0.0.1.0'; ID = 'StepsRecorder'
        Category = 'Legacy'; RiskLevel = 'Low'; ExecutionPhase = 'Offline'
        RequiresNetwork = $false; AllowAbsent = $true; Verification = 'CapabilityNotInstalled'
    },
    [PSCustomObject]@{
        Name = 'MathRecognizer~~~~0.0.1.0'; ID = 'MathRecognizer'
        Category = 'Legacy'; RiskLevel = 'Low'; ExecutionPhase = 'Offline'
        RequiresNetwork = $false; AllowAbsent = $true; Verification = 'CapabilityNotInstalled'
    },
    [PSCustomObject]@{
        Name = 'Print.Fax.Scan~~~~0.0.1.0'; ID = 'FaxScan'
        Category = 'Legacy'; RiskLevel = 'Low'; ExecutionPhase = 'Offline'
        RequiresNetwork = $false; AllowAbsent = $true; Verification = 'CapabilityNotInstalled'
    },
    [PSCustomObject]@{
        Name = 'XPS.Viewer~~~~0.0.1.0'; ID = 'XpsViewer'
        Category = 'Legacy'; RiskLevel = 'Low'; ExecutionPhase = 'Offline'
        RequiresNetwork = $false; AllowAbsent = $true; Verification = 'CapabilityNotInstalled'
    }
)
