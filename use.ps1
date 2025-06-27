# Usa CSS e JS hospedados em https://intune-management.vercel.app/

param (
    [Parameter(Mandatory=$false)]
    [ValidateScript({$_ -gt 0 -and $_ -eq [int]$_})]
    [int]$ActiveDeviceSyncDays = 90, # Período para considerar dispositivo ativo (padrão: 90 dias)
    [string]$OutputDir = "C:\IntManager\report" # Diretório de saída
)

# Função para mensagens simples
function Write-Status {
    param($Message, [string]$Color = "White")
    Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] $Message" -ForegroundColor $Color
}

# Exibe banner simples
Write-Host "`n=== Intune Report Manager ===`n" -ForegroundColor Cyan

# Valida o parâmetro ActiveDeviceSyncDays
if ($ActiveDeviceSyncDays -le 0) {
    Write-Status "Erro: O parâmetro ActiveDeviceSyncDays deve ser um número inteiro positivo." -Color Red
    exit
}

# Verifica e instala módulo Microsoft.Graph se necessário
Write-Status "Verificando módulo Microsoft.Graph..."
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.DeviceManagement)) {
    Write-Status "Instalando módulo Microsoft.Graph..." -Color Yellow
    try {
        Install-Module Microsoft.Graph -Scope CurrentUser -Force -ErrorAction Stop
    }
    catch {
        Write-Status "Erro ao instalar módulo: $($_.Exception.Message)" -Color Red
        exit
    }
}
Import-Module Microsoft.Graph.DeviceManagement -ErrorAction Stop

# Conexão com Microsoft Graph
Write-Status "Conectando ao Microsoft Graph..."
try {
    Connect-MgGraph -Scopes "DeviceManagementManagedDevices.Read.All" -NoWelcome -ErrorAction Stop | Out-Null
    Write-Status "Conexão estabelecida!" -Color Green
}
catch {
    Write-Status "Falha na conexão: $($_.Exception.Message)" -Color Red
    exit
}

# Cria diretório de saída
Write-Status "Criando diretório de saída: $OutputDir"
try {
    New-Item -Path $OutputDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
}
catch {
    Write-Status "Erro ao criar diretório: $($_.Exception.Message)" -Color Red
    Write-Status "Tentando salvar em '$env:TEMP\intune_report'..." -Color Yellow
    $OutputDir = "$env:TEMP\intune_report"
    New-Item -Path $OutputDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
}

# Define caminhos dos arquivos
$HtmlPath = Join-Path $OutputDir "index.html"
$LogPath = Join-Path $OutputDir "device_models.log"

# Coleta dispositivos ativos
Write-Status "Coletando dispositivos ativos (últimos $ActiveDeviceSyncDays dias)..."
$syncThreshold = (Get-Date).AddDays(-$ActiveDeviceSyncDays).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$devices = @()
$uniqueModels = New-Object System.Collections.Generic.HashSet[string]
try {
    $selectProps = "id,deviceName,userPrincipalName,operatingSystem,osVersion,manufacturer,model,serialNumber,lastSyncDateTime,complianceState,totalStorageSpaceInBytes,freeStorageSpaceInBytes"
    $uri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$filter=lastSyncDateTime ge $syncThreshold&`$select=$selectProps"
    do {
        $response = Invoke-MgGraphRequest -Uri $uri -Method Get -ErrorAction Stop
        $batchDevices = $response.value
        foreach ($device in $batchDevices) {
            $totalStorageGB = [math]::Round($device.totalStorageSpaceInBytes / 1GB, 2)
            $freeStorageGB = [math]::Round($device.freeStorageSpaceInBytes / 1GB, 2)
            $deviceData = [PSCustomObject]@{
                deviceName        = if ($device.deviceName) { $device.deviceName } else { "N/A" }
                userPrincipalName = if ($device.userPrincipalName) { $device.userPrincipalName } else { "N/A" }
                operatingSystem   = if ($device.operatingSystem) { $device.operatingSystem } else { "N/A" }
                osVersion         = if ($device.osVersion) { $device.osVersion } else { "N/A" }
                manufacturer      = if ($device.manufacturer) { $device.manufacturer } else { "N/A" }
                model             = if ($device.model) { $device.model } else { "N/A" }
                serialNumber      = if ($device.serialNumber) { $device.serialNumber } else { "N/A" }
                lastSyncDateTime  = if ($device.lastSyncDateTime) { $device.lastSyncDateTime } else { "N/A" }
                complianceState   = if ($device.complianceState) { $device.complianceState } else { "N/A" }
                totalStorageGB    = $totalStorageGB
                freeStorageGB     = $freeStorageGB
            }
            $devices += $deviceData
            $null = $uniqueModels.Add($device.model)
        }
        $uri = $response.'@odata.nextLink'
    } while ($uri)
    Write-Status "Encontrados $($devices.Count) dispositivos." -Color Green
}
catch {
    Write-Status "Erro ao coletar dispositivos: $($_.Exception.Message)" -Color Red
    exit
}

# Gera log de modelos únicos
Write-Status "Gerando log de modelos em $LogPath..."
try {
    $uniqueModels | Sort-Object | Out-File -FilePath $LogPath -Encoding UTF8 -ErrorAction Stop
    Write-Status "Log de modelos salvo com sucesso! ($($uniqueModels.Count) modelos únicos)" -Color Green
}
catch {
    Write-Status "Erro ao salvar log de modelos: $($_.Exception.Message)" -Color Red
    Write-Status "Tentando salvar em '$env:TEMP\device_models.log'..." -Color Yellow
    $LogPath = "$env:TEMP\device_models.log"
    $uniqueModels | Sort-Object | Out-File -FilePath $LogPath -Encoding UTF8 -ErrorAction Stop
}

# Gera HTML com dados em JSON
Write-Status "Gerando relatório HTML em $HtmlPath..."
try {
    $devicesJson = $devices | ConvertTo-Json -Depth 3 -Compress
    $htmlContent = @"
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Intune Report Manager</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://intune-management.vercel.app/style.css">
    <style>
        /* Efeitos de iluminação */
        #particle-container {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            z-index: -1;
            pointer-events: none;
        }

        #cursor-aura {
            position: fixed;
            width: 150px;
            height: 150px;
            border-radius: 50%;
            background: radial-gradient(circle, var(--accent-color) 10%, transparent 70%);
            opacity: 0.15;
            pointer-events: none;
            z-index: -1;
            transform: translate(-50%, -50%);
            transition: transform 0.05s ease;
            mix-blend-mode: screen;
        }

        .particle {
            position: absolute;
            border-radius: 50%;
            background: var(--accent-color);
            mix-blend-mode: screen;
            animation: fadeOut 1s ease-out forwards;
        }

        @keyframes fadeOut {
            0% { opacity: 0.8; transform: scale(1); }
            100% { opacity: 0; transform: scale(0.5); }
        }

        /* Ajuste do fundo para mais escuro */
        body {
            background: linear-gradient(180deg, #0d121f, #1e293b);
        }

        /* Ajuste responsivo para efeitos de iluminação */
        @media (max-width: 768px) {
            #cursor-aura {
                width: 100px;
                height: 100px;
            }

            .particle {
                width: 6px !important;
                height: 6px !important;
            }
        }
    </style>
</head>
<body>
    <div id="particle-container"></div>
    <div id="cursor-aura"></div>
    <header class="header">
        <h1 class="header-title">Intune Report Manager</h1>
        <p class="subtitle">Dispositivos sincronizados nos últimos $ActiveDeviceSyncDays dias.</p>
    </header>

    <section class="welcome animate-fade">
        <h2 class="welcome-title">Bem vindo!</h2>
        <p>Explore e gerencie $($devices.Count) dispositivos com filtros avançados, visualizações personalizadas e ordenação inteligente.</p>
    </section>

    <div class="controls frosted-glass">
        <div class="control-card">
            <button id="toggleFilters" class="btn">
                <svg class="icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M3 6h18M6 12h12M9 18h6"></path>
                </svg>
                Filtros Avançados
                <svg class="arrow" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <polyline points="6 9 12 15 18 9"></polyline>
                </svg>
            </button>
            <div id="filterPanel" class="dropdown-content hidden">
                <div class="filter-group">
                    <label for="deviceNameFilter">Nome do Dispositivo</label>
                    <div class="input-wrapper">
                        <svg class="input-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <circle cx="11" cy="11" r="8"></circle>
                            <path d="m21 21-4.3-4.3"></path>
                        </svg>
                        <input type="text" id="deviceNameFilter" placeholder="Pesquisar...">
                    </div>
                </div>
                <div class="filter-group">
                    <label for="userPrincipalNameFilter">Usuário</label>
                    <div class="input-wrapper">
                        <svg class="input-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M12 12m-4-4a4 4 0 1 0 8 0a4 4 0 1 0-8 0"></path>
                            <path d="M16 18v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"></path>
                        </svg>
                        <input type="text" id="userPrincipalNameFilter" placeholder="Pesquisar...">
                    </div>
                </div>
                <div class="filter-group">
                    <label for="operatingSystemFilter">Sistema Operacional</label>
                    <select id="operatingSystemFilter">
                        <option value="">Todos</option>
                    </select>
                </div>
                <div class="filter-group">
                    <label for="osVersionFilter">Versão do SO</label>
                    <div class="input-wrapper">
                        <svg class="input-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"></path>
                        </svg>
                        <input type="text" id="osVersionFilter" placeholder="Pesquisar...">
                    </div>
                </div>
                <div class="filter-group">
                    <label for="manufacturerFilter">Fabricante</label>
                    <select id="manufacturerFilter">
                        <option value="">Todos</option>
                    </select>
                </div>
                <div class="filter-group">
                    <label for="modelFilter">Modelo</label>
                    <select id="modelFilter">
                        <option value="">Todos</option>
                    </select>
                </div>
                <div class="filter-group">
                    <label for="serialNumberFilter">Número de Série</label>
                    <div class="input-wrapper">
                        <svg class="input-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M4 4h16v16H4z"></path>
                        </svg>
                        <input type="text" id="serialNumberFilter" placeholder="Pesquisar...">
                    </div>
                </div>
                <div class="filter-group">
                    <label for="lastSyncDateStart">Última Sinc. (Início)</label>
                    <div class="input-wrapper">
                        <svg class="input-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <rect x="3" y="4" width="18" height="18" rx="2" ry="2"></rect>
                            <path d="M16 2v4"></path>
                            <path d="M8 2v4"></path>
                            <path d="M3 10h18"></path>
                        </svg>
                        <input type="date" id="lastSyncDateStart">
                    </div>
                </div>
                <div class="filter-group">
                    <label for="lastSyncDateEnd">Última Sinc. (Fim)</label>
                    <div class="input-wrapper">
                        <svg class="input-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <rect x="3" y="4" width="18" height="18" rx="2" ry="2"></rect>
                            <path d="M16 2v4"></path>
                            <path d="M8 2v4"></path>
                            <path d="M3 10h18"></path>
                        </svg>
                        <input type="date" id="lastSyncDateEnd">
                    </div>
                </div>
                <div class="filter-group">
                    <label for="complianceStateFilter">Conformidade</label>
                    <select id="complianceStateFilter">
                        <option value="">Todos</option>
                        <option value="Compliant">Compliant</option>
                        <option value="Noncompliant">Noncompliant</option>
                    </select>
                </div>
                <div class="filter-group">
                    <label for="totalStorageMin">Armazenamento Total (Mín. GB)</label>
                    <div class="input-wrapper">
                        <svg class="input-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M4 4h16v16H4z"></path>
                        </svg>
                        <input type="number" id="totalStorageMin" placeholder="Mínimo">
                    </div>
                </div>
                <div class="filter-group">
                    <label for="totalStorageMax">Armazenamento Total (Máx. GB)</label>
                    <div class="input-wrapper">
                        <svg class="input-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M4 4h16v16H4z"></path>
                        </svg>
                        <input type="number" id="totalStorageMax" placeholder="Máximo">
                    </div>
                </div>
                <div class="filter-group">
                    <label for="freeStorageMin">Armazenamento Livre (Mín. GB)</label>
                    <div class="input-wrapper">
                        <svg class="input-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M4 4h16v16H4z"></path>
                        </svg>
                        <input type="number" id="freeStorageMin" placeholder="Mínimo">
                    </div>
                </div>
                <div class="filter-group">
                    <label for="freeStorageMax">Armazenamento Livre (Máx. GB)</label>
                    <div class="input-wrapper">
                        <svg class="input-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M4 4h16v16H4z"></path>
                        </svg>
                        <input type="number" id="freeStorageMax" placeholder="Máximo">
                    </div>
                </div>
                <div class="filter-actions">
                    <button id="applyFilters" class="btn btn-primary">Aplicar</button>
                    <button id="clearFilters" class="btn btn-secondary">Limpar</button>
                </div>
            </div>
        </div>
        <div class="control-card">
            <button id="toggleColumns" class="btn">
                <svg class="icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M3 6h18M6 12h12M9 18h6"></path>
                </svg>
                Selecionar Colunas
                <svg class="arrow" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <polyline points="6 9 12 15 18 9"></polyline>
                </svg>
            </button>
            <div id="columnPanel" class="dropdown-content hidden">
                <label class="checkbox-label">
                    <input type="checkbox" class="column-toggle" data-column="deviceName" checked>
                    <span class="checkbox-custom"></span>
                    Nome do Dispositivo
                </label>
                <label class="checkbox-label">
                    <input type="checkbox" class="column-toggle" data-column="userPrincipalName" checked>
                    <span class="checkbox-custom"></span>
                    Usuário
                </label>
                <label class="checkbox-label">
                    <input type="checkbox" class="column-toggle" data-column="operatingSystem" checked>
                    <span class="checkbox-custom"></span>
                    Sistema Operacional
                </label>
                <label class="checkbox-label">
                    <input type="checkbox" class="column-toggle" data-column="osVersion" checked>
                    <span class="checkbox-custom"></span>
                    Versão do SO
                </label>
                <label class="checkbox-label">
                    <input type="checkbox" class="column-toggle" data-column="manufacturer" checked>
                    <span class="checkbox-custom"></span>
                    Fabricante
                </label>
                <label class="checkbox-label">
                    <input type="checkbox" class="column-toggle" data-column="model" checked>
                    <span class="checkbox-custom"></span>
                    Modelo
                </label>
                <label class="checkbox-label">
                    <input type="checkbox" class="column-toggle" data-column="serialNumber" checked>
                    <span class="checkbox-custom"></span>
                    Número de Série
                </label>
                <label class="checkbox-label">
                    <input type="checkbox" class="column-toggle" data-column="lastSyncDateTime" checked>
                    <span class="checkbox-custom"></span>
                    Última Sincronização
                </label>
                <label class="checkbox-label">
                    <input type="checkbox" class="column-toggle" data-column="complianceState" checked>
                    <span class="checkbox-custom"></span>
                    Conformidade
                </label>
                <label class="checkbox-label">
                    <input type="checkbox" class="column-toggle" data-column="totalStorageGB" checked>
                    <span class="checkbox-custom"></span>
                    Armazenamento Total
                </label>
                <label class="checkbox-label">
                    <input type="checkbox" class="column-toggle" data-column="freeStorageGB" checked>
                    <span class="checkbox-custom"></span>
                    Armazenamento Livre
                </label>
                <button id="applyColumns" class="btn btn-primary">Aplicar</button>
            </div>
        </div>
        <div class="control-card">
            <select id="sortSelect" class="btn">
                <option value="deviceName">Ordenar por Nome do Dispositivo</option>
                <option value="userPrincipalName">Ordenar por Usuário</option>
                <option value="operatingSystem">Ordenar por Sistema Operacional</option>
                <option value="osVersion">Ordenar por Versão do SO</option>
                <option value="manufacturer">Ordenar por Fabricante</option>
                <option value="model">Ordenar por Modelo</option>
                <option value="serialNumber">Ordenar por Número de Série</option>
                <option value="lastSyncDateTime">Ordenar por Última Sincronização</option>
                <option value="complianceState">Ordenar por Conformidade</option>
                <option value="totalStorageGB">Ordenar por Armazenamento Total</option>
                <option value="freeStorageGB">Ordenar por Armazenamento Livre</option>
            </select>
        </div>
        <div class="control-card">
            <button id="toggleView" class="btn">
                <svg class="icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M12 2l10 6-10 6-10-6 10-6zM2 12l10 6 10-6"></path>
                </svg>
                Ver como Grade
            </button>
        </div>
    </div>

    <div id="loading" class="loading">
        Carregando <span class="loading-dot">.</span><span class="loading-dot">.</span><span class="loading-dot">.</span>
    </div>

    <div id="devicesTable">
        <table>
            <thead>
                <tr>
                    <th data-column="deviceName">Nome do Dispositivo<svg class="sort-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"></polyline></svg></th>
                    <th data-column="userPrincipalName">Usuário<svg class="sort-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"></polyline></svg></th>
                    <th data-column="operatingSystem">SO<svg class="sort-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"></polyline></svg></th>
                    <th data-column="osVersion">Versão do SO<svg class="sort-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"></polyline></svg></th>
                    <th data-column="manufacturer">Fabricante<svg class="sort-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"></polyline></svg></th>
                    <th data-column="model">Modelo<svg class="sort-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"></polyline></svg></th>
                    <th data-column="serialNumber">Número de Série<svg class="sort-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"></polyline></svg></th>
                    <th data-column="lastSyncDateTime">Última Sincronização<svg class="sort-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"></polyline></svg></th>
                    <th data-column="complianceState">Conformidade<svg class="sort-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"></polyline></svg></th>
                    <th data-column="totalStorageGB">Armazenamento Total (GB)<svg class="sort-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"></polyline></svg></th>
                    <th data-column="freeStorageGB">Armazenamento Livre (GB)<svg class="sort-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"></polyline></svg></th>
                </tr>
            </thead>
            <tbody id="tableBody"></tbody>
        </table>
    </div>

    <div id="devicesGrid" class="grid-view hidden">
        <div id="gridContainer"></div>
    </div>

    <div class="pagination">
        <button id="prevPage" class="btn">◄ Anterior</button>
        <span id="pageInfo"></span>
        <button id="nextPage" class="btn">Próximo ►</button>
    </div>

    <script>
        window.devices = ${devicesJson};
    </script>
    <script src="https://intune-management.vercel.app/script.js"></script>
</body>
</html>
"@
    $htmlContent | Out-File -FilePath $HtmlPath -Encoding UTF8 -Force
    Write-Status "Relatório HTML salvo com sucesso!" -Color Green
}
catch {
    Write-Status "Erro ao salvar relatório: $($_.Exception.Message)" -Color Red
    Write-Status "Tente especificar um caminho diferente usando -OutputDir." -Color Yellow
    exit
}

Write-Status "Processo concluído." -Color Green
