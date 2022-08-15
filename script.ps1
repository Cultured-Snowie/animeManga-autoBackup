#!/usr/bin/env pwsh

# Set variable
$isAction = $null -ne $Env:GITHUB_WORKSPACE

function Write-None {
    Write-Host ""
}

Write-None
# Set output encoding to UTF-8
Write-Host "Setting output encoding to UTF-8" -ForegroundColor Green
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Check prerequisites

if (Get-Command -Name "curl" -ErrorAction SilentlyContinue) {
    Write-Host "curl is installed"
} else {
    Write-Host "curl is not installed"
    Write-Host "Installing curl"
    if ($isWindows) {
        choco install curl
    } elseif ($isLinux) {
        sudo apt install curl
    } elseif ($isMac) {
        brew install curl
    } else {
        Write-Host "Unsupported OS"
        Exit 1
    }
}

if (Get-Command -Name "pip" -ErrorAction SilentlyContinue) {
    Write-Host "pip is installed"
} else {
    Write-Host "pip is not installed"
    Write-Host "Installing pip"
    if ($isWindows) {
        choco install python
    } elseif ($isLinux) {
        sudo apt install python3-pip
    } elseif ($isMac) {
        Write-Host "Please to install Python 3 manually" -ForegroundColor Red
        Exit 1
    } else {
        Write-Host "Unsupported OS"
        Exit 1
    }
}

Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted 

Write-None
# check if the script run from GitHub Actions
if ($isAction) {
    Write-Host "Script running from GitHub Actions"
} else {
    Write-Host "Script running locally"
}

Write-None
Write-Host "Checking if PS-SetEnv is installed"
if (-Not (Get-Module -Name "Set-PsEnv")) {
    Write-Host "Set-PsEnv is not installed"
    Write-Host "Installing Set-PsEnv locally"
    Install-Module -Name "Set-PsEnv" -Scope CurrentUser
}
Write-Host "Set-PsEnv is installed" -ForegroundColor Green

# check if PSGraphQL module is installed
Write-None
Write-Host "Checking if PSGraphQL is installed"
if (-Not (Get-Module -Name "PSGraphQL")) {
    Write-Host "PSGraphQL is not installed" -ForegroundColor Red
    Write-Host "Installing PSGraphQL"
    Install-Module -Name "PSGraphQL" -Scope CurrentUser
}
Write-Host "PSGraphQL is installed" -ForegroundColor Green

Write-None
Write-Host "Importing dotEnv file"
if (-Not($isAction)) {
    if (Test-Path -Path ".env") {
        Write-Host ".env file exists" -ForegroundColor Green
        Set-PsEnv
        Write-Host ".env file imported" -ForegroundColor Green
    } else {
        Write-None
        Write-Host ".env file does not exist, creating..." -ForegroundColor Red
        Copy-Item -Path ".env.example" -Destination ".env"
        Write-Host "Please to edit .env from your preferred text editor first and rerun the script." -ForegroundColor Red
        exit 1 # User requires to manually configure the file
    }
}

Import-Module "./Modules/Format-Json.psm1"

# Create directory
Write-None
Write-Host "Creating directory"
New-Item -ItemType Directory -Force -Path ./aniList
New-Item -ItemType Directory -Force -Path ./annict
New-Item -ItemType Directory -Force -Path ./kitsu
New-Item -ItemType Directory -Force -Path ./mangaUpdates
New-Item -ItemType Directory -Force -Path ./myAnimeList
New-Item -ItemType Directory -Force -Path ./notifyMoe
New-Item -ItemType Directory -Force -Path ./shikimori
New-Item -ItemType Directory -Force -Path ./simkl
New-Item -ItemType Directory -Force -Path ./trakt

# Download MyAnimeList Anime List with MALScraper

$malUsername = $Env:MAL_USERNAME
$userAgent = $Env:USER_AGENT

Write-None
Write-Host "Exporting MyAnimeList anime list"
curl -X POST -d "username=$malUsername&listtype=anime&update_on_import=on" -H "Origin: https://malscraper.azurewebsites.net" -H "Referrer: https://malscraper.azurewebsites.net/" -A "$userAgent" https://malscraper.azurewebsites.net/scrape > ./myAnimeList/animeList.xml

Write-None
Write-Host "Exporting MyAnimeList manga list"
curl -X POST -d "username=$malUsername&listtype=manga&update_on_import=on" -H "Origin: https://malscraper.azurewebsites.net" -H "Referrer: https://malscraper.azurewebsites.net/" -A "$userAgent" https://malscraper.azurewebsites.net/scrape > ./myAnimeList/mangaList.xml

$kitsuUserId = $Env:KITSU_USERID

Write-None
Write-Host "Exporting Kitsu anime list"
curl -X POST -d "username=$kitsuUserId&listtype=kitsuanime&update_on_import=on" -H "Origin: https://malscraper.azurewebsites.net" -H "Referrer: https://malscraper.azurewebsites.net/" -A "$userAgent" https://malscraper.azurewebsites.net/scrape > ./kitsu/animeList.xml

Write-None
Write-Host "Exporting Kitsu manga list"
curl -X POST -d "username=$kitsuUserId&listtype=kitsumanga&update_on_import=on" -H "Origin: https://malscraper.azurewebsites.net" -H "Referrer: https://malscraper.azurewebsites.net/" -A "$userAgent" https://malscraper.azurewebsites.net/scrape > ./kitsu/mangaList.xml

$aniListUsername = $Env:ANILIST_USERNAME
$aniListUri = "https://graphql.anilist.co"

Write-None
Write-Host "Exporting AniList anime list"
$alAnimeBody = '
    query($name: String!){
        MediaListCollection(userName: $name, type: ANIME){
            lists{
                name
                isCustomList
                isSplitCompletedList
                entries{
                    ... mediaListEntry
                }
            }
        }
        User(name: $name){
            name
            id
            mediaListOptions{
                scoreFormat
            }
        }
    }

    fragment mediaListEntry on MediaList{
        mediaId
        status
        progress
        repeat
        notes
        priority
        hiddenFromStatusLists
        customLists
        advancedScores
        startedAt{
            year
            month
            day
        }
        completedAt{
            year
            month
            day
        }
        updatedAt
        createdAt
        media{
            idMal
            title{romaji native english}
        }
        score
    }
'

$alMangaBody = '
    query($name: String!){
        MediaListCollection(userName: $name, type: MANGA){
            lists{
                name
                isCustomList
                isSplitCompletedList
                entries{
                    ... mediaListEntry
                }
            }
        }
        User(name: $name){
            name
            id
            mediaListOptions{
                scoreFormat
            }
        }
    }

    fragment mediaListEntry on MediaList{
        mediaId
        status
        progress
        progressVolumes
        repeat
        notes
        priority
        hiddenFromStatusLists
        customLists
        advancedScores
        startedAt{
            year
            month
            day
        }
        completedAt{
            year
            month
            day
        }
        updatedAt
        createdAt
        media{
            idMal
            title{romaji native english}
        }
        score
    }
'

$alVariableRaw = '
    {
        "name": "anonymous"
    }
'

$alVariableFix = $alVariableRaw -replace "anonymous", $aniListUsername

Invoke-GraphQLQuery -Uri $aniListUri -Query $alAnimeBody -Variable $alVariableFix -Raw > ./aniList/animeList.json

Write-None
Write-Host "Exporting AniList manga list"
Invoke-GraphQLQuery -Uri $aniListUri -Query $alMangaBody -Variable $alVariableFix -Raw > ./aniList/mangaList.json

Write-None
Write-Host "Format JSON files"
Get-ChildItem -Path "*" -Filter "*.json" -File  -Recurse | ForEach-Object {
    Write-Host "Formatting $($_)"
    Format-Json -Json (Get-Content $_ -Raw).trim() -Indentation 2 -ErrorAction SilentlyContinue | Out-File -FilePath $_
}
