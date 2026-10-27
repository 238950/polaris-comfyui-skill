# Download a checkpoint for a Polaris (RX 580 class) ComfyUI install.
#
#   powershell -ExecutionPolicy Bypass -File download_models.ps1 -Model animagine
#   powershell -ExecutionPolicy Bypass -File download_models.ps1 -Model sd15 -Models D:\ComfyUI\models\checkpoints
#   powershell -ExecutionPolicy Bypass -File download_models.ps1 -List
#
# Resumable: re-run the same command and it continues where it stopped.

param(
    [string]$Model = "animagine",
    [string]$Models = "C:\ComfyUI\models\checkpoints",
    [string]$Proxy = "",
    [switch]$List
)

$catalog = @{
    "illustrious" = @{
        File = "Illustrious-XL-v1.0.safetensors"
        Url  = "https://huggingface.co/OnomaAIResearch/Illustrious-XL-v1.0/resolve/main/Illustrious-XL-v1.0.safetensors"
        Size = 6900000000; Note = "SDXL / anime / tag style"
    }
    "noobai" = @{
        File = "NoobAI-XL-v1.1.safetensors"
        Url  = "https://huggingface.co/Laxhar/noobai-XL-1.1/resolve/main/NoobAI-XL-v1.1.safetensors"
        Size = 7100000000; Note = "SDXL / anime / widest artist coverage"
    }
    "animagine" = @{
        File = "animagine-xl-4.0.safetensors"
        Url  = "https://huggingface.co/cagliostrolab/animagine-xl-4.0/resolve/main/animagine-xl-4.0.safetensors"
        Size = 6900000000; Note = "SDXL / anime / easiest defaults"
    }
    "pony" = @{
        File = "v6.safetensors"
        Url  = "https://huggingface.co/astraliteheart/pony-diffusion-v6/resolve/main/v6.safetensors"
        Size = 6900000000; Note = "SDXL / anime / own tag system"
    }
    "realvis" = @{
        File = "RealVisXL_V4.0.safetensors"
        Url  = "https://huggingface.co/SG161222/RealVisXL_V4.0/resolve/main/RealVisXL_V4.0.safetensors"
        Size = 6900000000; Note = "SDXL / photoreal"
    }
    "juggernaut" = @{
        File = "Juggernaut-XL_v9_RunDiffusionPhoto_v2.safetensors"
        Url  = "https://huggingface.co/RunDiffusion/Juggernaut-XL-v9/resolve/main/Juggernaut-XL_v9_RunDiffusionPhoto_v2.safetensors"
        Size = 7100000000; Note = "SDXL / photoreal / cinematic"
    }
    "sdxl-base" = @{
        File = "sd_xl_base_1.0.safetensors"
        Url  = "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors"
        Size = 6900000000; Note = "SDXL / official base"
    }
    "sd15" = @{
        File = "v1-5-pruned-emaonly-fp16.safetensors"
        Url  = "https://huggingface.co/Comfy-Org/stable-diffusion-v1-5-archive/resolve/main/v1-5-pruned-emaonly-fp16.safetensors"
        Size = 2100000000; Note = "SD1.5 / fastest on Polaris"
    }
    "counterfeit" = @{
        File = "Counterfeit-V3.0_fp32.safetensors"
        Url  = "https://huggingface.co/gsdf/Counterfeit-V3.0/resolve/main/Counterfeit-V3.0_fp32.safetensors"
        Size = 5700000000; Note = "SD1.5 / anime"
    }
}

if ($List) {
    foreach ($key in $catalog.Keys | Sort-Object) {
        $item = $catalog[$key]
        Write-Host ("{0,-14} {1,6:N1} GB  {2}  {3}" -f $key, ($item.Size / 1GB), $item.File, $item.Note)
    }
    exit 0
}

if (-not $catalog.ContainsKey($Model)) {
    Write-Host "Unknown model: $Model"
    Write-Host "Run with -List to see available names."
    exit 1
}

$item = $catalog[$Model]
if (-not (Test-Path $Models)) {
    New-Item -ItemType Directory -Force -Path $Models | Out-Null
}
$target = Join-Path $Models $item.File

Write-Host ""
Write-Host "[$Model] $($item.Note)"
Write-Host "[target] $target"

for ($attempt = 1; $attempt -le 8; $attempt++) {
    $curlArgs = @("-L", "--fail", "-C", "-", "--retry", "3", "--retry-delay", "5",
                  "-o", $target, $item.Url)
    if ($Proxy -ne "") {
        $curlArgs = @("-x", $Proxy) + $curlArgs
    }
    & curl.exe @curlArgs

    if (Test-Path $target) {
        $size = (Get-Item $target).Length
        if ($size -ge ($item.Size * 0.97)) {
            Write-Host ("[ok] {0:N0} MB" -f ($size / 1MB))
            Write-Host ""
            Write-Host "Next: put it in ComfyUI/models/checkpoints and press R in the UI."
            exit 0
        }
    }
    Write-Host "[retry $attempt] incomplete, resuming in 5s"
    Start-Sleep -Seconds 5
}

Write-Host "[failed] download did not complete. Re-run the same command to resume."
exit 1
