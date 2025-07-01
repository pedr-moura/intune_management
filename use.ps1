<#
.SYNOPSIS
    Generates an HTML report for Intune-managed devices with advanced chart customization.

.DESCRIPTION
    This script connects to Microsoft Graph, retrieves device data for devices synced within a specified period,
    and generates an HTML report with filtering, sorting, and advanced chart visualization capabilities.
    Charts support customizable X/Y axes, data exclusion, and multiple aggregation methods.

.PARAMETER ActiveDeviceSyncDays
    Number of days to filter devices based on their last sync date. Default is 90 days.

.PARAMETER OutputDir
    Directory to save the HTML report and model log. Default is "C:\IntManager\report".

.EXAMPLE
    .\use.ps1 -ActiveDeviceSyncDays 30 -OutputDir "C:\Reports"
    Generates a report for devices synced in the last 30 days, saved to C:\Reports.
#>

param (
    [Parameter(Mandatory=$false)]
    [ValidateScript({$_ -gt 0 -and $_ -eq [int]$_})]
    [int]$ActiveDeviceSyncDays = 90,
    [string]$OutputDir = "C:\IntManager\report"
)

function Write-Status {
    param($Message, [string]$Color = "White")
    Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] $Message" -ForegroundColor $Color
}

Write-Host "`n=== Intune Report Manager ===`n" -ForegroundColor Cyan

# Validate parameters
if ($ActiveDeviceSyncDays -le 0) {
    Write-Status "Erro: ActiveDeviceSyncDays deve ser um número inteiro positivo." -Color Red
    exit 1
}

# Check and install Microsoft.Graph module
Write-Status "Verificando módulo Microsoft.Graph..."
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.DeviceManagement)) {
    Write-Status "Instalando módulo Microsoft.Graph..." -Color Yellow
    try {
        Install-Module Microsoft.Graph -Scope CurrentUser -Force -ErrorAction Stop
    }
    catch {
        Write-Status "Erro ao instalar módulo: $($_.Exception.Message)" -Color Red
        exit 1
    }
}
Import-Module Microsoft.Graph.DeviceManagement -ErrorAction Stop

# Connect to Microsoft Graph
Write-Status "Conectando ao Microsoft Graph..."
try {
    Connect-MgGraph -Scopes "DeviceManagementManagedDevices.Read.All" -NoWelcome -ErrorAction Stop | Out-Null
    Write-Status "Conexão estabelecida!" -Color Green
}
catch {
    Write-Status "Falha na conexão: $($_.Exception.Message)" -Color Red
    exit 1
}

# Create output directory
Write-Status "Criando diretório de saída: $OutputDir"
try {
    New-Item -Path $OutputDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
}
catch {
    Write-Status "Erro ao criar diretório: $($_.Exception.Message)" -Color Red
    Write-Status "Usando diretório temporário: $env:TEMP\intune_report" -Color Yellow
    $OutputDir = "$env:TEMP\intune_report"
    New-Item -Path $OutputDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
}

$HtmlPath = Join-Path $OutputDir "index.html"
$LogPath = Join-Path $OutputDir "device_models.log"

# Collect devices
Write-Status "Coletando dispositivos ativos (últimos $ActiveDeviceSyncDays dias)..."
$syncThreshold = (Get-Date).AddDays(-$ActiveDeviceSyncDays).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$devices = @()
$uniqueModels = New-Object System.Collections.Generic.HashSet[string]
try {
    $selectProps = "id,deviceName,userPrincipalName,operatingSystem,osVersion,manufacturer,model,serialNumber,lastSyncDateTime,complianceState,totalStorageSpaceInBytes,freeStorageSpaceInBytes"
    $uri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$filter=lastSyncDateTime ge $syncThreshold&`$select=$selectProps"
    do {
        $response = Invoke-MgGraphRequest -Uri $uri -Method Get -ErrorAction Stop
        foreach ($device in $response.value) {
            $totalStorageGB = if ($device.totalStorageSpaceInBytes) { [math]::Round($device.totalStorageSpaceInBytes / 1GB, 2) } else { 0 }
            $freeStorageGB = if ($device.freeStorageSpaceInBytes) { [math]::Round($device.freeStorageSpaceInBytes / 1GB, 2) } else { 0 }
            $devices += [PSCustomObject]@{
                deviceName = if ($device.deviceName) { $device.deviceName } else { "N/A" }
                userPrincipalName = if ($device.userPrincipalName) { $device.userPrincipalName } else { "N/A" }
                operatingSystem = if ($device.operatingSystem) { $device.operatingSystem } else { "N/A" }
                osVersion = if ($device.osVersion) { $device.osVersion } else { "N/A" }
                manufacturer = if ($device.manufacturer) { $device.manufacturer } else { "N/A" }
                model = if ($device.model) { $device.model } else { "N/A" }
                serialNumber = if ($device.serialNumber) { $device.serialNumber } else { "N/A" }
                lastSyncDateTime = if ($device.lastSyncDateTime) { $device.lastSyncDateTime } else { "N/A" }
                complianceState = if ($device.complianceState) { $device.complianceState } else { "N/A" }
                totalStorageGB = $totalStorageGB
                freeStorageGB = $freeStorageGB
            }
            if ($device.model) { $null = $uniqueModels.Add($device.model) }
        }
        $uri = $response.'@odata.nextLink'
    } while ($uri)
    Write-Status "Encontrados $($devices.Count) dispositivos." -Color Green
}
catch {
    Write-Status "Erro ao coletar dispositivos: $($_.Exception.Message)" -Color Red
    exit 1
}

# Save model log
Write-Status "Gerando log de modelos em $LogPath..."
try {
    $uniqueModels | Sort-Object | Out-File -FilePath $LogPath -Encoding UTF8 -ErrorAction Stop
    Write-Status "Log de modelos salvo com sucesso!" -Color Green
}
catch {
    Write-Status "Erro ao salvar log: $($_.Exception.Message)" -Color Red
    Write-Status "Usando caminho temporário: $env:TEMP\device_models.log" -Color Yellow
    $LogPath = "$env:TEMP\device_models.log"
    $uniqueModels | Sort-Object | Out-File -FilePath $LogPath -Encoding UTF8 -ErrorAction Stop
}

# Generate HTML report
Write-Status "Gerando relatório HTML em $HtmlPath..."
$devicesJson = $devices | ConvertTo-Json -Depth 3 -Compress
$htmlContent = @"
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Intune Report Manager</title>
    <link rel="stylesheet" href="style.css">
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
</head>
<body>
    <div id="particle-container"></div>
    <div id="cursor-aura"></div>

    <header class="header">
        <h1 class="header-title">Intune Report Manager</h1>
        <p class="subtitle">Dispositivos sincronizados nos últimos $ActiveDeviceSyncDays dias</p>
    </header>

    <div class="welcome animate-fade">
        <h2 class="welcome-title">Bem-vindo!</h2>
        <p>Explore e gerencie $($devices.Count) dispositivos com filtros avançados, visualizações personalizadas e gráficos interativos.</p>
    </div>

    <div class="controls chart-controls">
        <div class="control-card">
            <button class="btn" id="toggleChartConfig">
                <svg class="icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M4 9h16M4 15h16M10 3L8 21M16 3l-2 18"></path>
                </svg>
                Configurar Gráficos
                <span class="arrow">▼</span>
            </button>
            <div class="dropdown-content hidden" id="chartConfigPanel">
                <div class="chart-control-group">
                    <label for="chartType">Tipo de Gráfico</label>
                    <select id="chartType">
                        <option value="bar">Barra</option>
                        <option value="pie">Pizza</option>
                        <option value="doughnut">Rosca</option>
                        <option value="line">Linha</option>
                        <option value="scatter">Dispersão</option>
                    </select>
                </div>
                <div class="chart-control-group">
                    <label for="chartXField">Eixo X</label>
                    <select id="chartXField">
                        <option value="">Selecione...</option>
                    </select>
                </div>
                <div class="chart-control-group">
                    <label for="chartYField">Eixo Y</label>
                    <select id="chartYField">
                        <option value="">Selecione...</option>
                    </select>
                </div>
                <div class="chart-control-group">
                    <label for="chartAggregation">Agregação</label>
                    <select id="chartAggregation">
                        <option value="count">Contagem</option>
                        <option value="sum">Soma</option>
                        <option value="avg">Média</option>
                        <option value="min">Mínimo</option>
                        <option value="max">Máximo</option>
                    </select>
                </div>
                <div class="chart-control-group">
                    <label for="chartExcludeValues">Excluir Valores (Eixo X)</label>
                    <select id="chartExcludeValues" multiple>
                        <option value="">Nenhum</option>
                    </select>
                </div>
                <div class="chart-control-group">
                    <label for="chartColor">Cor Principal</label>
                    <input type="color" id="chartColor" value="#4f46e5">
                </div>
                <div class="chart-control-group">
                    <label for="chartTitle">Título do Gráfico</label>
                    <input type="text" id="chartTitle" placeholder="Digite o título do gráfico">
                </div>
                <div class="chart-control-group">
                    <span id="chartError" class="error-message"></span>
                </div>
                <button class="btn-primary" id="addChart">Adicionar Gráfico</button>
            </div>
        </div>
    </div>

    <div class="charts-container" id="chartsContainer"></div>

    <div class="controls">
        <div class="control-card">
            <button class="btn" id="toggleFilters">
                <svg class="icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M22 3H2l8 9.46V19l4 2v-8.54L22 3z"></path>
                </svg>
                Filtros Avançados
                <span class="arrow">▼</span>
            </button>
            <div class="dropdown-content hidden" id="filterPanel">
                <div class="filter-group">
                    <label for="deviceNameFilter">Nome do Dispositivo</label>
                    <div class="input-wrapper">
                        <svg class="input-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <rect x="3" y="4" width="18" height="16" rx="2"></rect>
                        </svg>
                        <input type="text" id="deviceNameFilter" placeholder="Pesquisar...">
                    </div>
                </div>
                <div class="filter-group">
                    <label for="userPrincipalNameFilter">Usuário</label>
                    <div class="input-wrapper">
                        <svg class="input-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"></path>
                            <circle cx="12" cy="7" r="4"></circle>
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
                            <rect x="3" y="4" width="18" height="16" rx="2"></rect>
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
                            <path d="M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1z"></path>
                        </svg>
                        <input type="text" id="serialNumberFilter" placeholder="Pesquisar...">
                    </div>
                </div>
                <div class="filter-group">
                    <label for="lastSyncDateStart">Última Sinc. (Início)</label>
                    <div class="input-wrapper">
                        <svg class="input-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <rect x="3" y="4" width="18" height="18" rx="2" ry="2"></rect>
                            <line x1="16" y1="2" x2="16" y2="6"></line>
                            <line x1="8" y1="2" x2="8" y2="6"></line>
                            <line x1="3" y1="10" x2="21" y2="10"></line>
                        </svg>
                        <input type="date" id="lastSyncDateStart">
                    </div>
                </div>
                <div class="filter-group">
                    <label for="lastSyncDateEnd">Última Sinc. (Fim)</label>
                    <div class="input-wrapper">
                        <svg class="input-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <rect x="3" y="4" width="18" height="18" rx="2" ry="2"></rect>
                            <line x1="16" y1="2" x2="16" y2="6"></line>
                            <line x1="8" y1="2" x2="8" y2="6"></line>
                            <line x1="3" y1="10" x2="21" y2="10"></line>
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
                            <path d="M22 12h-4l-3 9L9 3l-3 9H2"></path>
                        </svg>
                        <input type="number" id="totalStorageMin" min="0" placeholder="0">
                    </div>
                </div>
                <div class="filter-group">
                    <label for="totalStorageMax">Armazenamento Total (Máx. GB)</label>
                    <div class="input-wrapper">
                        <svg class="input-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M22 12h-4l-3 9L9 3l-3 9H2"></path>
                        </svg>
                        <input type="number" id="totalStorageMax" min="0" placeholder="0">
                    </div>
                </div>
                <div class="filter-group">
                    <label for="freeStorageMin">Armazenamento Livre (Mín. GB)</label>
                    <div class="input-wrapper">
                        <svg class="input-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M22 12h-4l-3 9L9 3l-3 9H2"></path>
                        </svg>
                        <input type="number" id="freeStorageMin" min="0" placeholder="0">
                    </div>
                </div>
                <div class="filter-group">
                    <label for="freeStorageMax">Armazenamento Livre (Máx. GB)</label>
                    <div class="input-wrapper">
                        <svg class="input-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M22 12h-4l-3 9L9 3l-3 9H2"></path>
                        </svg>
                        <input type="number" id="freeStorageMax" min="0" placeholder="0">
                    </div>
                </div>
                <div class="filter-actions">
                    <button class="btn-primary" id="applyFilters">Aplicar</button>
                    <button class="btn-secondary" id="clearFilters">Limpar</button>
                </div>
            </div>
        </div>
        <div class="control-card">
            <button class="btn" id="toggleColumns">
                <svg class="icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <rect x="3" y="3" width="7" height="9"></rect>
                    <rect x="14" y="3" width="7" height="5"></rect>
                    <rect x="14" y="12" width="7" height="9"></rect>
                    <rect x="3" y="16" width="7" height="5"></rect>
                </svg>
                Selecionar Colunas
                <span class="arrow">▼</span>
            </button>
            <div class="dropdown-content hidden" id="columnPanel">
                <label class="checkbox-label"><input type="checkbox" class="column-toggle" data-column="deviceName" checked><span class="checkbox-custom"></span>Nome do Dispositivo</label>
                <label class="checkbox-label"><input type="checkbox" class="column-toggle" data-column="userPrincipalName" checked><span class="checkbox-custom"></span>Usuário</label>
                <label class="checkbox-label"><input type="checkbox" class="column-toggle" data-column="operatingSystem" checked><span class="checkbox-custom"></span>Sistema Operacional</label>
                <label class="checkbox-label"><input type="checkbox" class="column-toggle" data-column="osVersion" checked><span class="checkbox-custom"></span>Versão do SO</label>
                <label class="checkbox-label"><input type="checkbox" class="column-toggle" data-column="manufacturer" checked><span class="checkbox-custom"></span>Fabricante</label>
                <label class="checkbox-label"><input type="checkbox" class="column-toggle" data-column="model" checked><span class="checkbox-custom"></span>Modelo</label>
                <label class="checkbox-label"><input type="checkbox" class="column-toggle" data-column="serialNumber" checked><span class="checkbox-custom"></span>Número de Série</label>
                <label class="checkbox-label"><input type="checkbox" class="column-toggle" data-column="lastSyncDateTime" checked><span class="checkbox-custom"></span>Última Sincronização</label>
                <label class="checkbox-label"><input type="checkbox" class="column-toggle" data-column="complianceState" checked><span class="checkbox-custom"></span>Conformidade</label>
                <label class="checkbox-label"><input type="checkbox" class="column-toggle" data-column="totalStorageGB" checked><span class="checkbox-custom"></span>Armazenamento Total</label>
                <label class="checkbox-label"><input type="checkbox" class="column-toggle" data-column="freeStorageGB" checked><span class="checkbox-custom"></span>Armazenamento Livre</label>
                <button class="btn-primary" id="applyColumns">Aplicar</button>
            </div>
        </div>
        <div class="control-card">
            <select id="sortSelect">
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
            <button class="btn" id="toggleView">
                <svg class="icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M3 6h18M6 12h12M9 18h6"></path>
                </svg>
                Ver como Grade
            </button>
        </div>
    </div>

    <div id="loading" class="loading">
        Carregando <span class="loading-dot"></span><span class="loading-dot"></span><span class="loading-dot"></span>
    </div>

    <table id="devicesTable" class="hidden">
        <thead>
            <tr>
                <th data-column="deviceName">Nome do Dispositivo <span class="sort-icon">▲</span></th>
                <th data-column="userPrincipalName">Usuário <span class="sort-icon">▲</span></th>
                <th data-column="operatingSystem">SO <span class="sort-icon">▲</span></th>
                <th data-column="osVersion">Versão do SO <span class="sort-icon">▲</span></th>
                <th data-column="manufacturer">Fabricante <span class="sort-icon">▲</span></th>
                <th data-column="model">Modelo <span class="sort-icon">▲</span></th>
                <th data-column="serialNumber">Número de Série <span class="sort-icon">▲</span></th>
                <th data-column="lastSyncDateTime">Última Sincronização <span class="sort-icon">▲</span></th>
                <th data-column="complianceState">Conformidade <span class="sort-icon">▲</span></th>
                <th data-column="totalStorageGB">Armazenamento Total (GB) <span class="sort-icon">▲</span></th>
                <th data-column="freeStorageGB">Armazenamento Livre (GB) <span class="sort-icon">▲</span></th>
            </tr>
        </thead>
        <tbody id="tableBody"></tbody>
    </table>

    <div id="devicesGrid" class="grid-view"></div>

    <div class="pagination">
        <button class="btn" id="prevPage">◄ Anterior</button>
        <span id="pageInfo"></span>
        <button class="btn" id="nextPage">Próximo ►</button>
    </div>

    <script>
        window.devices = $devicesJson;
    </script>
    <script src="script.js"></script>
</body>
</html>
"@

try {
    $htmlContent | Out-File -FilePath $HtmlPath -Encoding UTF8 -ErrorAction Stop
    Write-Status "Relatório HTML gerado com sucesso!" -Color Green
}
catch {
    Write-Status "Erro ao salvar relatório HTML: $($_.Exception.Message)" -Color Red
    exit 1
}

Write-Status "Processo concluído! Relatório salvo em: $HtmlPath" -Color Green
Write-Status "Log de modelos salvo em: $LogPath" -Color Green
