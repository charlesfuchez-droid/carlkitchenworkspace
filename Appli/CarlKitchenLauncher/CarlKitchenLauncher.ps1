$ProjectPath = "C:\Docker\CarlKitchen\mealie-lab"
$Url = "http://kitchen.carl.io"

Set-Location $ProjectPath

docker compose up -d

Write-Host "Démarrage de l'application..."

$Ready = $false

for ($i = 0; $i -lt 30; $i++) {
    try {
        $Response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 2
        if ($Response.StatusCode -eq 200) {
            $Ready = $true
            break
        }
    } catch {
        Start-Sleep -Seconds 2
    }
}

if ($Ready) {
    Start-Process "msedge.exe" "--app=$Url"
} else {
    Start-Process $Url
}