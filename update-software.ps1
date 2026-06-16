# GitHub-Version des Skripts
$AktuellPath = "ProgrammlisteAKTUELL.csv"
$IstPath = "ProgrammlisteIST.csv"
$IntunePath = "ProgrammlisteINTUNE.csv"
$GlobalResults = New-Object System.Collections.Generic.List[PSCustomObject]

function Write-To-ProgramList {
    param(
        [string]$Name,
        [string]$Version,
        [string]$Bemerkung
    )

    $IstVersion = "---"
    $IntuneVersion = "---"
    $Status = "NEU"

    if (Test-Path $IstPath) {
        $IstData = Import-Csv $IstPath -Delimiter ';' -Encoding UTF8
        $Match = $IstData | Where-Object { $_.Programm -eq $Name }
        if ($Match) {
            $IstVersion = $Match.Version
            if ($Version -eq $IstVersion) {
                $Status = "OK"
            }
            else {
                $Status = "UPDATE"
            }
        }
    }

    if (Test-Path $IntunePath) {
        $IntuneData = Import-Csv $IntunePath -Delimiter ';' -Encoding UTF8
        $IntuneMatch = $IntuneData | Where-Object { $_.Programm -eq $Name }
        if ($IntuneMatch) {
            $IntuneVersion = $IntuneMatch.Version
        }
    }

    $IntuneStatus = if ($IntuneVersion -eq "---") {
        "NEU"
    }
    elseif ($IntuneVersion -eq $Version) {
        "OK"
    }
    else {
        "UPDATE"
    }

    $GlobalResults.Add([PSCustomObject]@{
        Programm     = $Name
        IST          = $IstVersion
        AKTUELL      = $Version
        INTUNE       = $IntuneVersion
        INTUNESTATUS = $IntuneStatus
        Status       = $Status
        Bemerkung    = $Bemerkung
    })
}

# ============================================================
# --- HIER DEINE SOFTWARE-ABFRAGEN (Chrome, Firefox, etc.) ---
# ============================================================

# --- 1. GOOGLE CHROME ENTERPRISE (API) ---
try {
    Write-Host "Chrome Enterprise..." -NoNewline
    $ChromeApiUrl = "https://versionhistory.googleapis.com/v1/chrome/platforms/win/channels/stable/versions"
    $ChromeResponse = Invoke-RestMethod -Uri $ChromeApiUrl -Method Get
    $ChromeVersion = $ChromeResponse.versions[0].version
    Write-To-ProgramList -Name "Google Chrome Enterprise" -Version $ChromeVersion -Bemerkung "Stable Channel (Index 0)"
    Write-Host " [OK: $ChromeVersion]" -ForegroundColor Green
}
catch {
    Write-Warning " Fehler bei Chrome: $($_.Exception.Message)"
}

# --- 2. MOZILLA FIREFOX (API) ---
try {
    Write-Host "Mozilla Firefox..." -NoNewline
    $FirefoxApiUrl = "https://product-details.mozilla.org/1.0/firefox_versions.json"
    $FirefoxResponse = Invoke-RestMethod -Uri $FirefoxApiUrl -Method Get
    $FirefoxVersion = $FirefoxResponse.LATEST_FIREFOX_VERSION
    Write-To-ProgramList -Name "Mozilla Firefox" -Version $FirefoxVersion -Bemerkung "Stable Release (Official API)"
    Write-Host " [OK: $FirefoxVersion]" -ForegroundColor Green
}
catch {
    Write-Warning " Fehler bei Firefox: $($_.Exception.Message)"
}

# --- 3. ADOBE ACROBAT READER (WINGET SOURCE) ---
try {
    Write-Host "Adobe Reader DC (Winget)..." -NoNewline

    $WingetInfo = winget show --id Adobe.Acrobat.Reader.64-bit --source winget --accept-source-agreements | Select-String "Version:"

    if ($WingetInfo) {
        $AdobeVersion = $WingetInfo.ToString().Split()[-1].Trim()
        Write-To-ProgramList -Name "Adobe Acrobat Reader" -Version $AdobeVersion -Bemerkung "Quelle: Windows Package Manager (Winget)"
        Write-Host " [OK: $AdobeVersion]" -ForegroundColor Green
    }
    else {
        $WingetInfo = winget show --id Adobe.Acrobat.Reader.32-bit --source winget | Select-String "Version:"
        $AdobeVersion = $WingetInfo.ToString().Split()[-1].Trim()
        Write-To-ProgramList -Name "Adobe Acrobat Reader" -Version $AdobeVersion -Bemerkung "Quelle: Winget (32-Bit)"
        Write-Host " [OK: $AdobeVersion]" -ForegroundColor Green
    }
}
catch {
    Write-Warning " Fehler bei Adobe Reader (Winget): $($_.Exception.Message)"
}

# --- 4. ADOBE AIR (CHOCOLATEY) ---
try {
    Write-Host "Adobe AIR..." -NoNewline
    $AirUrl = "https://community.chocolatey.org/packages/AdobeAIR"
    $AirResponse = Invoke-WebRequest -Uri $AirUrl -UseBasicParsing -UserAgent "Mozilla/5.0"
    if ($AirResponse.Content -match 'Adobe AIR Runtime\s+([\d\.]+)') {
        $AirVersion = $Matches[1]
        Write-To-ProgramList -Name "Adobe AIR" -Version $AirVersion -Bemerkung "Quelle: Chocolatey (Harman)"
        Write-Host " [OK: $AirVersion]" -ForegroundColor Green
    }
    else {
        Write-Host " [FEHLER]" -ForegroundColor Red
        Write-Warning " Adobe AIR Version nicht gefunden."
    }
}
catch {
    Write-Warning " Fehler bei Adobe AIR: $($_.Exception.Message)"
}

# --- 5. JAVA 8 (ORACLE API & CHOCO FALLBACK) ---
try {
    Write-Host "Java 8..." -NoNewline
    $JavaVersion = $null
    $Quelle = ""

    try {
        $JavaResp = Invoke-RestMethod -Uri "https://java.oraclecloud.com/currentJavaReleases/8" -Method Get -TimeoutSec 5
        if ($JavaResp.releaseVersion) {
            $JavaVersion = $JavaResp.releaseVersion
            $Quelle = "Oracle Cloud API"
        }
    }
    catch {
        $JavaVersion = $null
    }

    if (-not $JavaVersion) {
        $ChocoResp = Invoke-WebRequest -Uri "https://community.chocolatey.org/packages/jre8" -UseBasicParsing -UserAgent "Mozilla/5.0"
        if ($ChocoResp.Content -match 'Java SE Runtime Environment\s+(\d+\.\d+\.\d+)') {
            $JavaVersion = $Matches[1]
            $Quelle = "Chocolatey (Fallback)"
        }
    }

    if ($JavaVersion) {
        $JavaVersion = $JavaVersion -replace '^1\.8\.0[_.]', '8.'
        $JavaVersion = $JavaVersion -replace '^8\.0\.', '8.'
        Write-To-ProgramList -Name "Java 8" -Version $JavaVersion -Bemerkung "Quelle: $Quelle"
        Write-Host " [OK: $JavaVersion]" -ForegroundColor Green
    }
    else {
        Write-Host " [FEHLER]" -ForegroundColor Red
    }
}
catch {
    Write-Warning " Fehler bei Java: $($_.Exception.Message)"
}

# --- 6. PDF24 CREATOR (OFFIZIELLER CHANGELOG) ---
try {
    Write-Host "PDF24 Creator..." -NoNewline
    $PdfUrl = "https://creator.pdf24.org/changelog/de.html"
    $PdfResponse = Invoke-WebRequest -Uri $PdfUrl -UseBasicParsing -UserAgent "Mozilla/5.0"

    if ($PdfResponse.Content -match 'v(\d+\.\d+\.\d+)') {
        $PdfVersion = $Matches[1]
        Write-To-ProgramList -Name "PDF24 Creator" -Version $PdfVersion -Bemerkung "Offizieller Changelog"
        Write-Host " [OK: $PdfVersion]" -ForegroundColor Green
    }
    else {
        Write-Host " [FEHLER]" -ForegroundColor Red
        Write-Warning " PDF24 Version konnte im Changelog nicht gefunden werden."
    }
}
catch {
    Write-Host " [FEHLER]" -ForegroundColor Red
    Write-Warning " Fehler bei PDF24: $($_.Exception.Message)"
}

# --- 7. FOXIT PDF READER (CHOCOLATEY) ---
try {
    Write-Host "Foxit PDF Reader..." -NoNewline
    $FoxitUrl = "https://community.chocolatey.org/packages/foxitreader"
    $FoxitResponse = Invoke-WebRequest -Uri $FoxitUrl -UseBasicParsing -UserAgent "Mozilla/5.0"

    if ($FoxitResponse.Content -match 'Foxit PDF Reader\s+([\d\.]+)') {
        $FoxitVersion = $Matches[1]
        Write-To-ProgramList -Name "Foxit PDF Reader" -Version $FoxitVersion -Bemerkung "Quelle: Chocolatey"
        Write-Host " [OK: $FoxitVersion]" -ForegroundColor Green
    }
    else {
        Write-Host " [FEHLER]" -ForegroundColor Red
        Write-Warning " Foxit Version konnte bei Chocolatey nicht gefunden werden."
    }
}
catch {
    Write-Host " [FEHLER]" -ForegroundColor Red
    Write-Warning " Fehler bei Foxit: $($_.Exception.Message)"
}

# --- 8. LEGO MINDSTORMS EV3 CLASSROOM (APPLE STORE) ---
try {
    Write-Host "Lego EV3 Classroom..." -NoNewline
    $Matches = $null
    $LegoVersion = $null

    $LegoUrl = "https://apps.apple.com/us/app/ev3-classroom-lego-education/id1502412247"
    $LegoResponse = Invoke-WebRequest -Uri $LegoUrl -UseBasicParsing

    if ($LegoResponse.Content -match '(?s)Version History.*?(?<!\d)(\d+\.\d+\.\d+)') {
        $LegoVersion = $Matches[1]
        Write-To-ProgramList -Name "Lego Mindstorms EV3 Classroom" -Version $LegoVersion -Bemerkung "Quelle: Apple App Store (Proxy)"
        Write-Host " [OK: $LegoVersion]" -ForegroundColor Green
    }
    else {
        Write-Host " [FEHLER]" -ForegroundColor Red
        Write-Warning " Version konnte im App Store Quelltext nicht gefunden werden."
    }
}
catch {
    Write-Host " [FEHLER]" -ForegroundColor Red
    Write-Warning " Fehler bei Lego: $($_.Exception.Message)"
}

# --- 9. WORKSHEET CRAFTER (OFFIZIELLE DOWNLOAD-SEITE) ---
try {
    Write-Host "Worksheet Crafter..." -NoNewline
    $Matches = $null
    $WscVersion = $null

    $WscUrl = "https://worksheetcrafter.com/de/downloads/vollversion"
    $WscResponse = Invoke-WebRequest -Uri $WscUrl -UseBasicParsing -UserAgent "Mozilla/5.0"

    if ($WscResponse.Content -match 'Version\s+(\d{4}\.[\d\.]+)') {
        $WscVersion = $Matches[1]
        Write-To-ProgramList -Name "Worksheet Crafter" -Version $WscVersion -Bemerkung "Offizielle Download-Seite"
        Write-Host " [OK: $WscVersion]" -ForegroundColor Green
    }
    else {
        Write-Host " [FEHLER]" -ForegroundColor Red
        Write-Warning " Version konnte auf der Download-Seite nicht gefunden werden."
    }
}
catch {
    Write-Host " [FEHLER]" -ForegroundColor Red
    Write-Warning " Fehler bei Worksheet Crafter: $($_.Exception.Message)"
}

# --- 10. PAINT.NET (CHOCOLATEY) ---
try {
    Write-Host "Paint.NET..." -NoNewline
    $Matches = $null
    $PaintVersion = $null

    $PaintNetUrl = "https://community.chocolatey.org/packages/paint.net"
    $PaintNetResponse = Invoke-WebRequest -Uri $PaintNetUrl -UseBasicParsing -UserAgent "Mozilla/5.0"

    if ($PaintNetResponse.Content -match 'paint.net\s+([\d\.]+)') {
        $PaintVersion = $Matches[1]
        Write-To-ProgramList -Name "Paint.NET" -Version $PaintVersion -Bemerkung "Quelle: Chocolatey"
        Write-Host " [OK: $PaintVersion]" -ForegroundColor Green
    }
    else {
        Write-Host " [FEHLER]" -ForegroundColor Red
        Write-Warning " Paint.NET Version konnte bei Chocolatey nicht gefunden werden."
    }
}
catch {
    Write-Host " [FEHLER]" -ForegroundColor Red
    Write-Warning " Fehler bei Paint.NET: $($_.Exception.Message)"
}

# --- 11. SHOTCUT (RELEASE NOTES Liste) ---
try {
    Write-Host "Shotcut..." -NoNewline
    $Matches = $null
    $ShotcutVersion = $null

    $ShotcutUrl = "https://www.shotcut.org/download/releasenotes/"
    $ShotcutResponse = Invoke-WebRequest -Uri $ShotcutUrl -UseBasicParsing -UserAgent "Mozilla/5.0"

    if ($ShotcutResponse.Content -match 'Release\s+(\d+\.\d+\.\d+)\b') {
        $ShotcutVersion = $Matches[1]
        Write-To-ProgramList -Name "Shotcut" -Version $ShotcutVersion -Bemerkung "Quelle: shotcut.org (Release Notes)"
        Write-Host " [OK: $ShotcutVersion]" -ForegroundColor Green
    }
    elseif ($ShotcutResponse.Content -match 'New Version\s+(\d+\.\d+)\b') {
        $ShotcutVersion = $Matches[1]
        Write-To-ProgramList -Name "Shotcut" -Version $ShotcutVersion -Bemerkung "Quelle: shotcut.org (Release Notes)"
        Write-Host " [OK: $ShotcutVersion]" -ForegroundColor Green
    }
    else {
        Write-Host " [FEHLER]" -ForegroundColor Red
        Write-Warning " Shotcut Version konnte in den Release Notes nicht gefunden werden."
    }
}
catch {
    Write-Host " [FEHLER]" -ForegroundColor Red
    Write-Warning " Fehler bei Shotcut: $($_.Exception.Message)"
}

# --- 12. SWEET HOME 3D (CHOCOLATEY) ---
try {
    Write-Host "Sweet Home 3D..." -NoNewline
    $Matches = $null
    $SweetHomeVersion = $null

    $SweetHomeUrl = "https://community.chocolatey.org/packages/sweet-home-3d"
    $SweetHomeResponse = Invoke-WebRequest -Uri $SweetHomeUrl -UseBasicParsing -UserAgent "Mozilla/5.0"

    if ($SweetHomeResponse.Content -match 'Sweet Home 3D\s+([\d\.]+)') {
        $SweetHomeVersion = $Matches[1]
        Write-To-ProgramList -Name "Sweet Home 3D" -Version $SweetHomeVersion -Bemerkung "Quelle: Chocolatey"
        Write-Host " [OK: $SweetHomeVersion]" -ForegroundColor Green
    }
    else {
        Write-Host " [FEHLER]" -ForegroundColor Red
        Write-Warning " Sweet Home 3D Version konnte bei Chocolatey nicht gefunden werden."
    }
}
catch {
    Write-Host " [FEHLER]" -ForegroundColor Red
    Write-Warning " Fehler bei Sweet Home 3D: $($_.Exception.Message)"
}

# --- 13. VLC MEDIA PLAYER (DOWNLOAD-LINK VARIANTE) ---
try {
    Write-Host "VLC Media Player..." -NoNewline
    $Matches = $null
    $VlcVersion = $null

    $VlcUrl = "https://www.videolan.org/vlc/download-windows.html"
    $VlcResponse = Invoke-WebRequest -Uri $VlcUrl -UseBasicParsing -UserAgent "Mozilla/5.0"

    if ($VlcResponse.Content -match 'vlc-([\d\.]+)-win') {
        $VlcVersion = $Matches[1]
        Write-To-ProgramList -Name "VLC Media Player" -Version $VlcVersion -Bemerkung "Quelle: Offizielle Download-Seite"
        Write-Host " [OK: $VlcVersion]" -ForegroundColor Green
    }
    else {
        Write-Host " [FEHLER]" -ForegroundColor Red
        Write-Warning " VLC Version konnte im Download-Link nicht gefunden werden."
    }
}
catch {
    Write-Host " [FEHLER]" -ForegroundColor Red
    Write-Warning " Fehler bei VLC: $($_.Exception.Message)"
}

# --- 14. LEGO SPIKE APP (LEGO EDUCATION RELEASE NOTES) ---
try {
    Write-Host "Lego SPIKE App..." -NoNewline
    $Matches = $null
    $SpikeVersion = $null

    $SpikeUrl = "https://legoeducation.atlassian.net/servicedesk/customer/article/38611681568"
    $SpikeResponse = Invoke-WebRequest -Uri $SpikeUrl -UseBasicParsing -UserAgent "Mozilla/5.0"

    if ($SpikeResponse.Content -match 'SPIKE.*?App.*?version\s+(\d+\.\d+\.\d+)' -or
        $SpikeResponse.Content -match 'version\s+(\d+\.\d+\.\d+)') {
        $SpikeVersion = $Matches[1]
        Write-To-ProgramList -Name "Lego SPIKE App" -Version $SpikeVersion -Bemerkung "Quelle: Lego Education Release Notes"
        Write-Host " [OK: $SpikeVersion]" -ForegroundColor Green
    }
    else {
        Write-Host " [FEHLER]" -ForegroundColor Red
        Write-Warning " SPIKE Version konnte in den Release Notes nicht gefunden werden."
    }
}
catch {
    Write-Host " [FEHLER]" -ForegroundColor Red
    Write-Warning " Fehler bei Lego SPIKE: $($_.Exception.Message)"
}

# --- 15. SMART NOTEBOOK (SMART TECH UPDATES) ---
try {
    Write-Host "SMART Notebook..." -NoNewline
    $Matches = $null
    $SmartVersion = $null

    $SmartUrl = "https://support.smarttech.com/docs/software/notebook/current/en/about/release-notes.cshtml"
    $SmartResponse = Invoke-WebRequest -Uri $SmartUrl -UseBasicParsing -UserAgent "Mozilla/5.0"

    if ($SmartResponse.Content -match 'Windows[|\s]+(\d+\.\d+\.\d+(?:\.\d+)?)') {
        $SmartVersion = $Matches[1]
    }
    elseif ($SmartResponse.Content -match 'Version[:\s]+(\d+\.\d+\.\d+(?:\.\d+)?)') {
        $SmartVersion = $Matches[1]
    }
    elseif ($SmartResponse.Content -match '(\d+\.\d+\.\d{4}(?:\.\d+)?)') {
        $SmartVersion = $Matches[1]
    }

    if ($SmartVersion) {
        Write-To-ProgramList -Name "SMART Notebook" -Version $SmartVersion -Bemerkung "Quelle: SMART Release Notes"
        Write-Host " [OK: $SmartVersion]" -ForegroundColor Green
    }
    else {
        Write-Host " [FEHLER]" -ForegroundColor Red
        Write-Warning " SMART Notebook Version konnte auf der Release Notes-Seite nicht gefunden werden."
    }
}
catch {
    Write-Host " [FEHLER]" -ForegroundColor Red
    Write-Warning " Fehler bei SMART Notebook: $($_.Exception.Message)"
}

# --- 16. LYNX WHITEBOARD (GOOGLE PLAY STORE QUELLE) ---
try {
    Write-Host "LYNX Whiteboard..." -NoNewline
    $Matches = $null
    $LynxVersion = $null

    $LynxUrl = "https://play.google.com/store/apps/details?id=com.clevertouch.lynx&hl=de"
    $LynxResponse = Invoke-WebRequest -Uri $LynxUrl -UseBasicParsing -UserAgent "Mozilla/5.0"

    $Pattern = '8\.\d+\.\d+(?:\.\d+)?'
    $AllMatches = [regex]::Matches($LynxResponse.Content, $Pattern)

    if ($AllMatches.Count -gt 0) {
        $LynxVersion = $AllMatches.Value | Sort-Object { [version]$_ } -Descending | Select-Object -First 1
        Write-To-ProgramList -Name "LYNX Whiteboard" -Version $LynxVersion -Bemerkung "Quelle: Google Play Store"
        Write-Host " [OK: $LynxVersion]" -ForegroundColor Green
    }
    else {
        Write-Host " [FEHLER]" -ForegroundColor Red
        Write-Warning " LYNX Version konnte im Play Store nicht identifiziert werden."
    }
}
catch {
    Write-Host " [FEHLER]" -ForegroundColor Red
    Write-Warning " Fehler bei LYNX Whiteboard: $($_.Exception.Message)"
}

# --- 17. OPENBOARD (GITHUB API) ---
try {
    Write-Host "OpenBoard..." -NoNewline
    $Matches = $null
    $OpenBoardVersion = $null

    $ObApiUrl = "https://api.github.com/repos/OpenBoard-org/OpenBoard/releases/latest"
    $ObResponse = Invoke-RestMethod -Uri $ObApiUrl

    if ($ObResponse.tag_name -match 'v?(\d+\.\d+\.\d+)') {
        $OpenBoardVersion = $Matches[1]
        Write-To-ProgramList -Name "OpenBoard" -Version $OpenBoardVersion -Bemerkung "Quelle: GitHub API"
        Write-Host " [OK: $OpenBoardVersion]" -ForegroundColor Green
    }
    else {
        Write-Host " [FEHLER]" -ForegroundColor Red
        Write-Warning " OpenBoard Version konnte via GitHub API nicht ermittelt werden."
    }
}
catch {
    Write-Host " [FEHLER]" -ForegroundColor Red
    Write-Warning " Fehler bei OpenBoard: $($_.Exception.Message)"
}

# --- 18. 7-ZIP (OFFIZIELLE WEBSEITE) ---
try {
    Write-Host "7-Zip..." -NoNewline
    $Matches = $null
    $ZipVersion = $null

    $ZipUrl = "https://www.7-zip.org/"
    $ZipResponse = Invoke-WebRequest -Uri $ZipUrl -UseBasicParsing -UserAgent "Mozilla/5.0"

    if ($ZipResponse.Content -match 'Download 7-Zip\s+([\d\.]+)') {
        $ZipVersion = $Matches[1]
        Write-To-ProgramList -Name "7-Zip" -Version $ZipVersion -Bemerkung "Quelle: 7-zip.org"
        Write-Host " [OK: $ZipVersion]" -ForegroundColor Green
    }
    else {
        Write-Host " [FEHLER]" -ForegroundColor Red
        Write-Warning " 7-Zip Version konnte auf der Webseite nicht gefunden werden."
    }
}
catch {
    Write-Host " [FEHLER]" -ForegroundColor Red
    Write-Warning " Fehler bei 7-Zip: $($_.Exception.Message)"
}

# --- 19. GIMP (OFFIZIELLE JSON-API - NUR LATEST) ---
try {
    Write-Host "GIMP..." -NoNewline

    $GimpVersion = $null
    $GimpApiUrl = "https://www.gimp.org/gimp_versions.json"
    $GimpData = Invoke-RestMethod -Uri $GimpApiUrl

    if ($GimpData.stable -is [array]) {
        $GimpVersion = $GimpData.stable[0].version
    }
    elseif ($GimpData.stable.windows) {
        $GimpVersion = $GimpData.stable.windows[0].version
    }
    else {
        $GimpVersion = $GimpData.stable.version
    }

    if ($GimpVersion -is [array]) {
        $GimpVersion = $GimpVersion[0]
    }

    if ($GimpVersion) {
        Write-To-ProgramList -Name "GIMP" -Version $GimpVersion -Bemerkung "Quelle: gimp.org API (Latest)"
        Write-Host " [OK: $GimpVersion]" -ForegroundColor Green
    }
    else {
        Write-Host " [FEHLER]" -ForegroundColor Red
        Write-Warning " GIMP Version konnte nicht eindeutig bestimmt werden."
    }
}
catch {
    Write-Host " [FEHLER]" -ForegroundColor Red
    Write-Warning " Fehler bei GIMP: $($_.Exception.Message)"
}

# --- 20. INKSCAPE (OFFIZIELLE WEBSEITE) ---
try {
    Write-Host "Inkscape..." -NoNewline
    $Matches = $null
    $InkVersion = $null

    $InkUrl = "https://inkscape.org/de/release/"
    $InkResponse = Invoke-WebRequest -Uri $InkUrl -UseBasicParsing -UserAgent "Mozilla/5.0"

    if ($InkResponse.Content -match 'Inkscape\s+([\d\.]+)') {
        $InkVersion = $Matches[1]
        Write-To-ProgramList -Name "Inkscape" -Version $InkVersion -Bemerkung "Quelle: inkscape.org"
        Write-Host " [OK: $InkVersion]" -ForegroundColor Green
    }
    else {
        if ($InkResponse.Content -match 'release-([\d-]+)/') {
            $InkVersion = $Matches[1] -replace '-', '.'
            Write-To-ProgramList -Name "Inkscape" -Version $InkVersion -Bemerkung "Quelle: inkscape.org (Fallback)"
            Write-Host " [OK: $InkVersion]" -ForegroundColor Green
        }
        else {
            Write-Host " [FEHLER]" -ForegroundColor Red
            Write-Warning " Inkscape Version konnte auf der Webseite nicht gefunden werden."
        }
    }
}
catch {
    Write-Host " [FEHLER]" -ForegroundColor Red
    Write-Warning " Fehler bei Inkscape: $($_.Exception.Message)"
}

# --- 21. IRFANVIEW (OFFIZIELLE WEBSEITE) ---
try {
    Write-Host "IrfanView..." -NoNewline
    $Matches = $null
    $IrfanVersion = $null

    $IrfanUrl = "https://www.irfanview.com/"
    $IrfanResponse = Invoke-WebRequest -Uri $IrfanUrl -UseBasicParsing -UserAgent "Mozilla/5.0"

    if ($IrfanResponse.Content -match '(?:Current version|Version)\s+([\d\.]+)') {
        $IrfanVersion = $Matches[1]
        Write-To-ProgramList -Name "IrfanView" -Version $IrfanVersion -Bemerkung "Quelle: irfanview.com"
        Write-Host " [OK: $IrfanVersion]" -ForegroundColor Green
    }
    else {
        Write-Host " [FEHLER]" -ForegroundColor Red
        Write-Warning " IrfanView Version konnte auf der Webseite nicht gefunden werden."
    }
}
catch {
    Write-Host " [FEHLER]" -ForegroundColor Red
    Write-Warning " Fehler bei IrfanView: $($_.Exception.Message)"
}

# --- 22. AUDACITY (GITHUB API) ---
try {
    Write-Host "Audacity..." -NoNewline
    $Matches = $null
    $AudacityVersion = $null

    $AudacityApiUrl = "https://api.github.com/repos/audacity/audacity/releases/latest"
    $AudacityResponse = Invoke-RestMethod -Uri $AudacityApiUrl

    if ($AudacityResponse.tag_name -match '(\d+\.\d+\.\d+)') {
        $AudacityVersion = $Matches[1]
        Write-To-ProgramList -Name "Audacity" -Version $AudacityVersion -Bemerkung "Quelle: GitHub API"
        Write-Host " [OK: $AudacityVersion]" -ForegroundColor Green
    }
    else {
        Write-Host " [FEHLER]" -ForegroundColor Red
        Write-Warning " Audacity Version konnte nicht aus dem API-Tag extrahiert werden."
    }
}
catch {
    Write-Host " [FEHLER]" -ForegroundColor Red
    Write-Warning " Fehler bei Audacity: $($_.Exception.Message)"
}

# --- 23. MUSESCORE (GITHUB API) ---
try {
    Write-Host "MuseScore..." -NoNewline
    $Matches = $null
    $MuseVersion = $null

    $MuseApiUrl = "https://api.github.com/repos/musescore/MuseScore/releases/latest"
    $MuseResponse = Invoke-RestMethod -Uri $MuseApiUrl

    if ($MuseResponse.tag_name -match '(\d+\.\d+\.\d+)') {
        $MuseVersion = $Matches[1]
        Write-To-ProgramList -Name "MuseScore" -Version $MuseVersion -Bemerkung "Quelle: GitHub API"
        Write-Host " [OK: $MuseVersion]" -ForegroundColor Green
    }
    else {
        Write-Host " [FEHLER]" -ForegroundColor Red
        Write-Warning " MuseScore Version konnte nicht aus dem API-Tag extrahiert werden."
    }
}
catch {
    Write-Host " [FEHLER]" -ForegroundColor Red
    Write-Warning " Fehler bei MuseScore: $($_.Exception.Message)"
}

# --- 24. MINECRAFT EDUCATION (DIRECT DOWNLOAD REDIRECT) ---
try {
    Write-Host "Minecraft Education..." -NoNewline

    $Matches = $null
    $McVersion = $null
    $AkaUrl = "https://aka.ms/downloadmee-desktopApp"

    $Request = [System.Net.HttpWebRequest]::Create($AkaUrl)
    $Request.AllowAutoRedirect = $true
    $Request.Method = "HEAD"

    $Response = $Request.GetResponse()
    $RealUrl = $Response.ResponseUri.ToString()
    $Response.Close()

    if ($RealUrl -match '(\d+\.\d+\.\d+(?:\.\d+)?)') {
        $McVersion = $Matches[1]
        Write-To-ProgramList -Name "Minecraft Education" -Version $McVersion -Bemerkung "Quelle: aka.ms Redirect"
        Write-Host " [OK: $McVersion]" -ForegroundColor Green
    }
    else {
        Write-Host " [FEHLER]" -ForegroundColor Red
        Write-Warning " Version konnte nicht aus der Ziel-URL extrahiert werden: $RealUrl"
    }
}
catch {
    Write-Host " [FEHLER]" -ForegroundColor Red
    Write-Warning " Fehler bei Minecraft Education: $($_.Exception.Message)"
}

# --- 25. AFFINITY (FREE-CODECS) ---
try {
    Write-Host "Affinity Suite..." -NoNewline
    $Matches = $null
    $AffVersion = $null

    $AffUrl = "https://www.free-codecs.com/download/affinity.htm"
    $AffResponse = Invoke-WebRequest -Uri $AffUrl -UseBasicParsing -UserAgent "Mozilla/5.0"

    if ($AffResponse.Content -match 'Affinity[^\d]*?(\d+\.\d+\.\d+(?:\.\d+)?)') {
        $AffVersion = $Matches[1]
        Write-To-ProgramList -Name "Affinity Suite" -Version $AffVersion -Bemerkung "Quelle: Free-Codecs"
        Write-Host " [OK: $AffVersion]" -ForegroundColor Green
    }
    else {
        Write-Host " [FEHLER]" -ForegroundColor Red
        Write-Warning " Affinity Version konnte auf Free-Codecs nicht gefunden werden."
    }
}
catch {
    Write-Host " [FEHLER]" -ForegroundColor Red
    Write-Warning " Fehler bei Affinity: $($_.Exception.Message)"
}

# --- 26. HELBLING MEDIA APP (PARTIAL DOWNLOAD) ---
try {
    Write-Host "Helbling Media App..." -NoNewline

    $HelVersion = $null
    $Url = "https://mediaapp.helbling.com/downloads/OU34DJKB/latest/HELBLING%20Media%20App%20Setup.exe"
    $TempPath = Join-Path $env:TEMP "HelblingCheck.exe"

    $Request = [System.Net.HttpWebRequest]::Create($Url)
    $Request.AddRange(0, 2MB - 1)
    $Response = $Request.GetResponse()

    $FileStream = [System.IO.File]::Create($TempPath)
    $Response.GetResponseStream().CopyTo($FileStream)
    $FileStream.Close()
    $Response.Close()

    $HelVersion = (Get-Item $TempPath).VersionInfo.FileVersion

    if (Test-Path $TempPath) {
        Remove-Item $TempPath -Force
    }

    if ($HelVersion) {
        Write-To-ProgramList -Name "Helbling Media App" -Version $HelVersion -Bemerkung "Quelle: File-Header (Partial Download)"
        Write-Host " [OK: $HelVersion]" -ForegroundColor Green
    }
    else {
        Write-Host " [FEHLER]" -ForegroundColor Red
        Write-Warning " Version konnte nicht aus dem Datei-Header gelesen werden."
    }
}
catch {
    Write-Host " [FEHLER]" -ForegroundColor Red
    Write-Warning " Fehler bei Helbling: $($_.Exception.Message)"
}

# --- 27. FFMPEG (GITHUB API - GyanD Builds) ---
try {
    Write-Host "FFmpeg..." -NoNewline
    $Matches = $null
    $FfmpegVersion = $null

    $FfmpegApiUrl = "https://api.github.com/repos/GyanD/codexffmpeg/releases/latest"
    $FfmpegResponse = Invoke-RestMethod -Uri $FfmpegApiUrl

    if ($FfmpegResponse.tag_name -match '(\d+\.\d+(?:\.\d+)?)') {
        $FfmpegVersion = $Matches[1]
        Write-To-ProgramList -Name "FFmpeg" -Version $FfmpegVersion -Bemerkung "Quelle: GitHub (GyanD Builds)"
        Write-Host " [OK: $FfmpegVersion]" -ForegroundColor Green
    }
    else {
        Write-Host " [FEHLER]" -ForegroundColor Red
        Write-Warning " FFmpeg Version konnte via GitHub API nicht extrahiert werden."
    }
}
catch {
    Write-Host " [FEHLER]" -ForegroundColor Red
    Write-Warning " Fehler bei FFmpeg: $($_.Exception.Message)"
}

# --- 28. NOTEPAD++ (GitHub Releases API) ---
try {
    Write-Host "Notepad++..." -NoNewline
    $NppApiUrl = "https://api.github.com/repos/notepad-plus-plus/notepad-plus-plus/releases/latest"
    $NppHeaders = @{ "User-Agent" = "PowerShell" }
    $NppResponse = Invoke-RestMethod -Uri $NppApiUrl -Method Get -Headers $NppHeaders
    $NppVersion = ($NppResponse.tag_name -replace '^v','')
    Write-To-ProgramList -Name "Notepad++" -Version $NppVersion -Bemerkung "GitHub Releases latest (tag_name=$($NppResponse.tag_name))"
    Write-Host " [OK: $NppVersion]" -ForegroundColor Green
}
catch {
    Write-Warning " Fehler bei Notepad++: $($_.Exception.Message)"
}

# ============================================================
# ENDE SOFTWARE-ABFRAGEN -------------------------------------
# ============================================================

function Export-To-Csv {
    $ExportData = $GlobalResults |
        Sort-Object Programm |
        Select-Object `
            @{Name = 'Programm'; Expression = { $_.Programm } },
            @{Name = 'Version'; Expression = { $_.AKTUELL } },
            @{Name = 'Bemerkung'; Expression = { $_.Bemerkung } }

    $ExportData | Export-Csv -Path $AktuellPath -Delimiter ';' -NoTypeInformation -Encoding UTF8
    Write-Host ""
    Write-Host "CSV-Datei erstellt: $AktuellPath" -ForegroundColor Cyan
}

Export-To-Csv
