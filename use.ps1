# Usa CSS e JS hospedados em https://intune-management.vercel.app/

param (
    [int]$ActiveDeviceSyncDays = 90, # Período para considerar dispositivo ativo
    [string]$OutputDir = "C:\IntManager\report" # Diretório de saída
)

# Função para mensagens simples
function Write-Status {
    param($Message, [string]$Color = "White")
    Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] $Message" -ForegroundColor $Color
}

# Exibe banner simples
Write-Host "`n=== Intune Report Manager ===`n" -ForegroundColor Cyan

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
    <link rel="stylesheet" href="https://intune-management.vercel.app/style.css">
</head>
<body>
    <header class="header">
        <h1 class="header-title">Intune Report Manager</h1>
        <p class="subtitle">Dispositivos sincronizados nos ultimos 90 dias.</p>
        <div class="header-icons">
            <svg class="icon animate-spin" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M12 4v6l4 4m-6-6l4 4M12 20a8 8 0 100-16 8 8 0 000 16z" />
            </svg>
            <svg class="icon animate-pulse" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M12 2l10 6-10 6-10-6 10-6zM2 12l10 6 10-6" />
            </svg>
            <svg class="icon animate-bounce" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M12 2l5 5-5 5-5-5 5-5zM7 12l5 5 5-5" />
            </svg>
            <svg class="icon animate-fade" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M4 12h16M12 4v16" />
            </svg>
        </div>
    </header>
    <section class="welcome">
        <h2 class="welcome-title">Bem vindo!</h2>
        <p class="welcome-text">Explore e gerencie <span class="device-count">$($devices.Count)</span> dispositivos com filtros avançados, visualizações personalizadas e ordenação inteligente.</p>
    </section>
    <div class="controls">
        <div class="control-card">
            <button id="toggleFilters" class="btn btn-icon" aria-label="Mostrar/esconder filtros">
                <svg class="icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M3 4h18M7 8h10M3 12h18M7 16h10M3 20h18" />
                </svg>
                Filtros Avançados
                <svg class="arrow" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M6 9l6 6 6-6" />
                </svg>
            </button>
            <div id="filterPanel" class="dropdown-content filter-panel hidden">
                <div class="filter-group">
                    <label for="deviceNameFilter">Nome do Dispositivo</label>
                    <div class="input-wrapper">
                        <svg class="input-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <circle cx="11" cy="11" r="8" />
                            <path d="M21 21l-4.35-4.35" />
                        </svg>
                        <input type="text" id="deviceNameFilter" placeholder="Ex.: NDEL3P6GPZ2" aria-label="Filtrar por Nome do Dispositivo">
                    </div>
                </div>
                <div class="filter-group">
                    <label for="userPrincipalNameFilter">Usuário</label>
                    <div class="input-wrapper">
                        <svg class="input-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M16 7a4 4 0 11-8 0 4 4 0 018 0z" />
                            <path d="M12 14c-3.3 0-6 2.7-6 6h12c0-3.3-2.7-6-6-6z" />
                        </svg>
                        <input type="text" id="userPrincipalNameFilter" placeholder="Ex.: hpaula@suzano.com.br" aria-label="Filtrar por Usuário">
                    </div>
                </div>
                <div class="filter-group">
                    <label for="operatingSystemFilter">Sistema Operacional</label>
                    <select id="operatingSystemFilter" aria-label="Filtrar por Sistema Operacional">
                        <option value="">Todos</option>
                    </select>
                </div>
                <div class="filter-group">
                    <label for="osVersionFilter">Versão do SO</label>
                    <div class="input-wrapper">
                        <svg class="input-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <rect x="4" y="4" width="16" height="16" rx="2" />
                        </svg>
                        <input type="text" id="osVersionFilter" placeholder="Ex.: 10.0.26100" aria-label="Filtrar por Versão do SO">
                    </div>
                </div>
                <div class="filter-group">
                    <label for="manufacturerFilter">Fabricante</label>
                    <select id="manufacturerFilter" aria-label="Filtrar por Fabricante">
                        <option value="">Todos</option>
                    </select>
                </div>
                <div class="filter-group">
                    <label for="modelFilter">Modelo</label>
                    <select id="modelFilter" aria-label="Filtrar por Modelo">
                        <option value="">Todos</option>
                    </select>
                </div>
                <div class="filter-group">
                    <label for="serialNumberFilter">Número de Série</label>
                    <div class="input-wrapper">
                        <svg class="input-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M12 2v20M2 12h20" />
                        </svg>
                        <input type="text" id="serialNumberFilter" placeholder="Ex.: 3P6GPZ2" aria-label="Filtrar por Número de Série">
                    </div>
                </div>
                <div class="filter-group">
                    <label for="lastSyncDateStart">Última Sinc. (Início)</label>
                    <div class="input-wrapper">
                        <svg class="input-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <rect x="4" y="4" width="16" height="16" rx="2" />
                            <path d="M16 2v4M8 2v4M3 10h18" />
                        </svg>
                        <input type="date" id="lastSyncDateStart" aria-label="Filtrar por Última Sincronização (Início)">
                    </div>
                </div>
                <div class="filter-group">
                    <label for="lastSyncDateEnd">Última Sinc. (Fim)</label>
                    <div class="input-wrapper">
                        <svg class="input-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <rect x="4" y="4" width="16" height="16" rx="2" />
                            <path d="M16 2v4M8 2v4M3 10h18" />
                        </svg>
                        <input type="date" id="lastSyncDateEnd" aria-label="Filtrar por Última Sincronização (Fim)">
                    </div>
                </div>
                <div class="filter-group">
                    <label for="complianceStateFilter">Conformidade</label>
                    <select id="complianceStateFilter" aria-label="Filtrar por Conformidade">
                        <option value="">Todos</option>
                        <option value="compliant">Compliant</option>
                        <option value="noncompliant">Noncompliant</option>
                    </select>
                </div>
                <div class="filter-group">
                    <label for="totalStorageMin">Armazenamento Total (Mín. GB)</label>
                    <div class="input-wrapper">
                        <svg class="input-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M12 2v20M2 12h20" />
                        </svg>
                        <input type="number" id="totalStorageMin" placeholder="Ex.: 100" min="0" step="1" aria-label="Filtrar por Armazenamento Total Mínimo">
                    </div>
                </div>
                <div class="filter-group">
                    <label for="totalStorageMax">Armazenamento Total (Máx. GB)</label>
                    <div class="input-wrapper">
                        <svg class="input-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M12 2v20M2 12h20" />
                        </svg>
                        <input type="number" id="totalStorageMax" placeholder="Ex.: 500" min="0" step="1" aria-label="Filtrar por Armazenamento Total Máximo">
                    </div>
                </div>
                <div class="filter-group">
                    <label for="freeStorageMin">Armazenamento Livre (Mín. GB)</label>
                    <div class="input-wrapper">
                        <svg class="input-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M12 2v20M2 12h20" />
                        </svg>
                        <input type="number" id="freeStorageMin" placeholder="Ex.: 10" min="0" step="1" aria-label="Filtrar por Armazenamento Livre Mínimo">
                    </div>
                </div>
                <div class="filter-group">
                    <label for="freeStorageMax">Armazenamento Livre (Máx. GB)</label>
                    <div class="input-wrapper">
                        <svg class="input-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M12 2v20M2 12h20" />
                        </svg>
                        <input type="number" id="freeStorageMax" placeholder="Ex.: 200" min="0" step="1" aria-label="Filtrar por Armazenamento Livre Máximo">
                    </div>
                </div>
                <div class="filter-actions">
                    <button id="applyFilters" class="btn btn-primary" aria-label="Aplicar filtros">Aplicar</button>
                    <button id="clearFilters" class="btn btn-secondary" aria-label="Limpar filtros">Limpar</button>
                </div>
            </div>
        </div>
        <div class="control-card">
            <button id="toggleColumns" class="btn btn-icon" aria-label="Mostrar/esconder seleção de colunas">
                <svg class="icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M3 3h18M3 7h18M3 11h18M3 15h18M3 19h18" />
                </svg>
                Selecionar Colunas
                <svg class="arrow" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M6 9l6 6 6-6" />
                </svg>
            </button>
            <div id="columnPanel" class="dropdown-content column-panel hidden">
                <div class="column-group">
                    <label class="checkbox-label">
                        <input type="checkbox" class="column-toggle" data-column="deviceName" checked>
                        <span class="checkbox-custom"></span> Nome do Dispositivo
                    </label>
                    <label class="checkbox-label">
                        <input type="checkbox" class="column-toggle" data-column="userPrincipalName" checked>
                        <span class="checkbox-custom"></span> Usuário
                    </label>
                    <label class="checkbox-label">
                        <input type="checkbox" class="column-toggle" data-column="operatingSystem" checked>
                        <span class="checkbox-custom"></span> Sistema Operacional
                    </label>
                    <label class="checkbox-label">
                        <input type="checkbox" class="column-toggle" data-column="osVersion" checked>
                        <span class="checkbox-custom"></span> Versão do SO
                    </label>
                    <label class="checkbox-label">
                        <input type="checkbox" class="column-toggle" data-column="manufacturer" checked>
                        <span class="checkbox-custom"></span> Fabricante
                    </label>
                    <label class="checkbox-label">
                        <input type="checkbox" class="column-toggle" data-column="model" checked>
                        <span class="checkbox-custom"></span> Modelo
                    </label>
                    <label class="checkbox-label">
                        <input type="checkbox" class="column-toggle" data-column="serialNumber" checked>
                        <span class="checkbox-custom"></span> Número de Série
                    </label>
                    <label class="checkbox-label">
                        <input type="checkbox" class="column-toggle" data-column="lastSyncDateTime" checked>
                        <span class="checkbox-custom"></span> Última Sincronização
                    </label>
                    <label class="checkbox-label">
                        <input type="checkbox" class="column-toggle" data-column="complianceState" checked>
                        <span class="checkbox-custom"></span> Conformidade
                    </label>
                    <label class="checkbox-label">
                        <input type="checkbox" class="column-toggle" data-column="totalStorageGB" checked>
                        <span class="checkbox-custom"></span> Armazenamento Total
                    </label>
                    <label class="checkbox-label">
                        <input type="checkbox" class="column-toggle" data-column="freeStorageGB" checked>
                        <span class="checkbox-custom"></span> Armazenamento Livre
                    </label>
                </div>
                <button id="applyColumns" class="btn btn-primary" aria-label="Aplicar seleção de colunas">Aplicar</button>
            </div>
        </div>
        <div class="control-card">
            <div class="input-wrapper">
                <svg class="input-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M12 2v2m0 16v2m-6-6h2m10 0h2M2 12h2m16 0h2" />
                </svg>
                <select id="sortSelect" aria-label="Opções de ordenação">
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
        </div>
        <div class="control-card">
            <button id="toggleView" class="btn btn-icon" aria-label="Alternar visualização">
                <svg class="icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M12 2l10 6-10 6-10-6 10-6zM2 12l10 6 10-6" />
                </svg>
                Ver como Grade
            </button>
        </div>
    </div>
    <main>
        <div id="loading" class="loading">Carregando <span class="loading-dot">.</span><span class="loading-dot">.</span><span class="loading-dot">.</span></div>
        <div id="devicesTable" class="hidden">
            <table>
                <thead>
                    <tr>
                        <th data-column="deviceName">
                            <svg class="sort-icon" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <path d="M12 6l-6 6h12l-6-6z" />
                            </svg>
                            Nome do Dispositivo
                        </th>
                        <th data-column="userPrincipalName">
                            <svg class="sort-icon" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <path d="M12 6l-6 6h12l-6-6z" />
                            </svg>
                            Usuário
                        </th>
                        <th data-column="operatingSystem">
                            <svg class="sort-icon" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <path d="M12 6l-6 6h12l-6-6z" />
                            </svg>
                            SO
                        </th>
                        <th data-column="osVersion">
                            <svg class="sort-icon" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <path d="M12 6l-6 6h12l-6-6z" />
                            </svg>
                            Versão do SO
                        </th>
                        <th data-column="manufacturer">
                            <svg class="sort-icon" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <path d="M12 6l-6 6h12l-6-6z" />
                            </svg>
                            Fabricante
                        </th>
                        <th data-column="model">
                            <svg class="sort-icon" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <path d="M12 6l-6 6h12l-6-6z" />
                            </svg>
                            Modelo
                        </th>
                        <th data-column="serialNumber">
                            <svg class="sort-icon" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <path d="M12 6l-6 6h12l-6-6z" />
                            </svg>
                            Número de Série
                        </th>
                        <th data-column="lastSyncDateTime">
                            <svg class="sort-icon" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <path d="M12 6l-6 6h12l-6-6z" />
                            </svg>
                            Última Sincronização
                        </th>
                        <th data-column="complianceState">
                            <svg class="sort-icon" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <path d="M12 6l-6 6h12l-6-6z" />
                            </svg>
                            Conformidade
                        </th>
                        <th data-column="totalStorageGB">
                            <svg class="sort-icon" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <path d="M12 6l-6 6h12l-6-6z" />
                            </svg>
                            Armazenamento Total (GB)
                        </th>
                        <th data-column="freeStorageGB">
                            <svg class="sort-icon" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <path d="M12 6l-6 6h12l-6-6z" />
                            </svg>
                            Armazenamento Livre (GB)
                        </th>
                    </tr>
                </thead>
                <tbody id="tableBody"></tbody>
            </table>
        </div>
        <div id="devicesGrid" class="hidden">
            <div id="gridContainer"></div>
        </div>
        <div class="pagination">
            <button id="prevPage" class="btn btn-secondary" disabled aria-label="Página anterior">◄ Anterior</button>
            <span id="pageInfo"></span>
            <button id="nextPage" class="btn btn-secondary" aria-label="Próxima página">Próximo ►</button>
        </div>
    </main>
    <script>
        const devices = $devicesJson;
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