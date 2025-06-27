# Define o tenant ID e a URL da API do Microsoft Graph
$tenantId = "SEU_TENANT_ID"
$graphApiUrl = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices"

# Função para obter o token de acesso
function Get-AccessToken {
    $clientId = "SEU_CLIENT_ID"
    $clientSecret = "SEU_CLIENT_SECRET"
    $tokenUrl = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
    $body = @{
        grant_type    = "client_credentials"
        client_id     = $clientId
        client_secret = $clientSecret
        scope         = "https://graph.microsoft.com/.default"
    }
    $response = Invoke-RestMethod -Method Post -Uri $tokenUrl -Body $body
    return $response.access_token
}

# Função para obter os dispositivos do Intune
function Get-ManagedDevices {
    $token = Get-AccessToken
    $headers = @{
        Authorization = "Bearer $token"
    }
    $devices = @()
    $url = $graphApiUrl
    do {
        $response = Invoke-RestMethod -Method Get -Uri $url -Headers $headers
        $devices += $response.value
        $url = $response.'@odata.nextLink'
    } while ($url)
    return $devices
}

# Obtém os dispositivos
$devices = Get-ManagedDevices

# Converte os dispositivos para JSON
$devicesJson = $devices | ConvertTo-Json -Depth 3 -Compress

# Gera o conteúdo HTML
$htmlContent = @"
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Intune Report Manager</title>
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@400;600;700&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://intune-management.vercel.app/style.css">
    <style>
        :root {
            --primary-color: #1e40af;
            --bg-color: #0f172a;
            --frosted-bg: rgba(255, 255, 255, 0.1);
            --glow-color: rgba(30, 64, 175, 0.2);
            --aura-color: rgba(30, 64, 175, 0.15);
            --shadow-neon: 0 0 6px rgba(30, 64, 175, 0.3);
            --text-color: #ffffff;
            --text-muted: rgba(255, 255, 255, 0.7);
        }

        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Poppins', sans-serif;
            background: linear-gradient(180deg, var(--bg-color), #1e293b);
            color: var(--text-color);
            min-height: 100vh;
            padding: 2rem;
            position: relative;
            overflow-x: hidden;
        }

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
            background: radial-gradient(circle, var(--aura-color), transparent 70%);
            pointer-events: none;
            z-index: -1;
            transform: translate(-50%, -50%);
            transition: transform 0.05s ease;
            mix-blend-mode: screen;
        }

        .particle {
            position: absolute;
            border-radius: 50%;
            background: var(--glow-color);
            mix-blend-mode: screen;
            animation: fadeOut 1s ease-out forwards;
        }

        @keyframes fadeOut {
            0% { opacity: 0.8; transform: scale(1); }
            100% { opacity: 0; transform: scale(0.5); }
        }

        /* Header */
        .header {
            text-align: center;
            padding: 2rem 0;
            margin-bottom: 1.5rem;
            animation: fadeIn 0.8s ease-in-out;
        }

        .header-title {
            font-size: 2rem;
            font-weight: 700;
            color: var(--primary-color);
        }

        .subtitle {
            font-size: 1rem;
            color: var(--text-muted);
            margin-top: 0.5rem;
        }

        /* Barra de opções com vidro fosco */
        .controls {
            display: flex;
            justify-content: center;
            gap: 0.5rem;
            padding: 0.8rem;
            background: var(--frosted-bg);
            backdrop-filter: blur(5px);
            border-radius: 8px;
            border: 1px solid rgba(255, 255, 255, 0.1);
            box-shadow: var(--shadow-neon);
            margin-bottom: 2rem;
            flex-wrap: wrap;
        }

        .control-card {
            position: relative;
        }

        .btn {
            background: var(--primary-color);
            color: var(--text-color);
            padding: 0.5rem 1rem;
            border: none;
            border-radius: 6px;
            font-size: 0.9rem;
            font-weight: 600;
            cursor: pointer;
            transition: transform 0.2s ease, box-shadow 0.2s ease;
            display: flex;
            align-items: center;
            gap: 0.4rem;
        }

        .btn:hover {
            transform: translateY(-2px);
            box-shadow: var(--shadow-neon);
        }

        .icon {
            stroke: var(--text-color);
            stroke-width: 2;
            width: 16px;
            height: 16px;
        }

        .arrow {
            width: 14px;
            height: 14px;
        }

        /* Dropdown Content */
        .dropdown-content {
            position: absolute;
            top: calc(100% + 6px);
            left: 0;
            background: var(--frosted-bg);
            backdrop-filter: blur(5px);
            border-radius: 8px;
            border: 1px solid rgba(255, 255, 255, 0.1);
            box-shadow: var(--shadow-neon);
            padding: 1rem;
            width: 250px;
            max-height: 300px;
            overflow-y: auto;
            opacity: 0;
            visibility: hidden;
            transform: translateY(8px);
            transition: opacity 0.2s ease, transform 0.2s ease, visibility 0.2s ease;
            z-index: 1000;
        }

        .dropdown-content:not(.hidden) {
            opacity: 1;
            visibility: visible;
            transform: translateY(0);
        }

        .control-card:last-child .dropdown-content {
            left: auto;
            right: 0;
        }

        .filter-group {
            margin-bottom: 0.8rem;
        }

        .filter-group label {
            display: block;
            font-size: 0.85rem;
            color: var(--text-muted);
            margin-bottom: 0.3rem;
        }

        .input-wrapper {
            position: relative;
            display: flex;
            align-items: center;
        }

        .input-icon {
            position: absolute;
            left: 0.8rem;
            width: 16px;
            height: 16px;
            stroke: var(--text-muted);
        }

        input, select {
            width: 100%;
            padding: 0.5rem 0.8rem 0.5rem 2.5rem;
            background: rgba(255, 255, 255, 0.05);
            border: 1px solid rgba(255, 255, 255, 0.1);
            border-radius: 6px;
            color: var(--text-color);
            font-size: 0.85rem;
            transition: border-color 0.2s ease;
        }

        input:focus, select:focus {
            outline: none;
            border-color: var(--primary-color);
            box-shadow: 0 0 4px rgba(30, 64, 175, 0.2);
        }

        .btn-primary {
            background: var(--primary-color);
            color: var(--text-color);
        }

        .btn-secondary {
            background: transparent;
            border: 1px solid var(--primary-color);
            color: var(--primary-color);
        }

        /* Tabela e Grade */
        #devicesTable, #devicesGrid {
            max-width: 1200px;
            margin: 0 auto;
        }

        table {
            background: var(--frosted-bg);
            border-radius: 8px;
            box-shadow: var(--shadow-neon);
            border: 1px solid rgba(255, 255, 255, 0.1);
        }

        th {
            background: var(--primary-color);
            color: var(--text-color);
            padding: 0.8rem;
        }

        .grid-view {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 1rem;
        }

        .device-card {
            background: var(--frosted-bg);
            border-radius: 8px;
            border: 1px solid rgba(255, 255, 255, 0.1);
            box-shadow: var(--shadow-neon);
            padding: 1rem;
        }

        /* Paginação */
        .pagination {
            display: flex;
            justify-content: center;
            gap: 1rem;
            margin-top: 2rem;
        }

        .pagination .btn {
            padding: 0.5rem 1rem;
        }

        #pageInfo {
            font-size: 0.9rem;
            color: var(--text-muted);
        }

        /* Loading */
        #loading {
            display: flex;
            justify-content: center;
            font-size: 1rem;
            color: var(--text-muted);
            margin: 2rem 0;
        }

        /* Animação de fade-in */
        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(-15px); }
            to { opacity: 1; transform: translateY(0); }
        }

        /* Responsividade */
        @media (max-width: 768px) {
            body {
                padding: 1rem;
            }

            .controls {
                flex-direction: column;
                width: 100%;
            }

            .btn {
                width: 100%;
                justify-content: center;
                font-size: 0.85rem;
            }

            .header-title {
                font-size: 1.8rem;
            }

            #cursor-aura {
                width: 100px;
                height: 100px;
            }

            .particle {
                width: 6px !important;
                height: 6px !important;
            }

            .dropdown-content {
                width: 100%;
                max-width: calc(100vw - 2rem);
            }

            #devicesTable, #devicesGrid {
                max-width: 100%;
            }
        }
    </style>
</head>
<body>
    <div id="particle-container"></div>
    <div id="cursor-aura"></div>
    <header class="header">
        <h1 class="header-title">Intune Report Manager</h1>
        <p class="subtitle">Dispositivos sincronizados nos últimos 90 dias</p>
    </header>

    <section class="welcome">
        <h2 class="welcome-title">Bem-vindo</h2>
        <p>Gerencie ${devices.length} dispositivos com filtros e visualizações otimizadas.</p>
    </section>

    <div class="controls frosted-glass">
        <div class="control-card">
            <button id="toggleFilters" class="btn">
                <svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor">
                    <path d="M4 4h16v2H4zM4 10h16v2H4zM4 16h16v2H4z" />
                </svg>
                Filtros
                <svg class="arrow" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <polyline points="6 9 12 15 18 9"></polyline>
                </svg>
            </button>
            <div id="filterPanel" class="dropdown-content hidden">
                <div class="filter-group">
                    <label for="deviceNameFilter">Nome do Dispositivo</label>
                    <div class="input-wrapper">
                        <svg class="input-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M21 21l-4.35-4.35M11 19a8 8 0 100-16 8 8 0 000 16z" />
                        </svg>
                        <input type="text" id="deviceNameFilter" placeholder="Pesquisar...">
                    </div>
                </div>
                <div class="filter-group">
                    <label for="userPrincipalNameFilter">Usuário</label>
                    <div class="input-wrapper">
                        <svg class="input-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M12 12m-4-4a4 4 0 1 0 8 0a4 4 0 1 0-8 0" />
                            <path d="M16 18v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
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
                        <svg class="input-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M4 4h16v16H4z" />
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
                        <svg class="input-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M4 4h16v16H4z" />
                        </svg>
                        <input type="text" id="serialNumberFilter" placeholder="Pesquisar...">
                    </div>
                </div>
                <div class="filter-group">
                    <label for="lastSyncDateStart">Última Sinc. (Início)</label>
                    <div class="input-wrapper">
                        <svg class="input-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M6 4h12v2H6zM4 8h16v12H4z" />
                        </svg>
                        <input type="date" id="lastSyncDateStart">
                    </div>
                </div>
                <div class="filter-group">
                    <label for="lastSyncDateEnd">Última Sinc. (Fim)</label>
                    <div class="input-wrapper">
                        <svg class="input-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M6 4h12v2H6zM4 8h16v12H4z" />
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
                        <svg class="input-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M4 4h16v16H4z" />
                        </svg>
                        <input type="number" id="totalStorageMin" placeholder="Mínimo">
                    </div>
                </div>
                <div class="filter-group">
                    <label for="totalStorageMax">Armazenamento Total (Máx. GB)</label>
                    <div class="input-wrapper">
                        <svg class="input-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M4 4h16v16H4z" />
                        </svg>
                        <input type="number" id="totalStorageMax" placeholder="Máximo">
                    </div>
                </div>
                <div class="filter-group">
                    <label for="freeStorageMin">Armazenamento Livre (Mín. GB)</label>
                    <div class="input-wrapper">
                        <svg class="input-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M4 4h16v16H4z" />
                        </svg>
                        <input type="number" id="freeStorageMin" placeholder="Mínimo">
                    </div>
                </div>
                <div class="filter-group">
                    <label for="freeStorageMax">Armazenamento Livre (Máx. GB)</label>
                    <div class="input-wrapper">
                        <svg class="input-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M4 4h16v16H4z" />
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
                <svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor">
                    <path d="M12 2v20M2 12h20" />
                </svg>
                Colunas
                <svg class="arrow" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <polyline points="6 9 12 15 18 9"></polyline>
                </svg>
            </button>
            <div id="columnPanel" class="dropdown-content hidden">
                <label class="checkbox-label"><input type="checkbox" class="column-toggle" data-column="deviceName" checked> Nome do Dispositivo</label>
                <label class="checkbox-label"><input type="checkbox" class="column-toggle" data-column="userPrincipalName" checked> Usuário</label>
                <label class="checkbox-label"><input type="checkbox" class="column-toggle" data-column="operatingSystem" checked> Sistema Operacional</label>
                <label class="checkbox-label"><input type="checkbox" class="column-toggle" data-column="osVersion" checked> Versão do SO</label>
                <label class="checkbox-label"><input type="checkbox" class="column-toggle" data-column="manufacturer" checked> Fabricante</label>
                <label class="checkbox-label"><input type="checkbox" class="column-toggle" data-column="model" checked> Modelo</label>
                <label class="checkbox-label"><input type="checkbox" class="column-toggle" data-column="serialNumber" checked> Número de Série</label>
                <label class="checkbox-label"><input type="checkbox" class="column-toggle" data-column="lastSyncDateTime" checked> Última Sincronização</label>
                <label class="checkbox-label"><input type="checkbox" class="column-toggle" data-column="complianceState" checked> Conformidade</label>
                <label class="checkbox-label"><input type="checkbox" class="column-toggle" data-column="totalStorageGB" checked> Armazenamento Total</label>
                <label class="checkbox-label"><input type="checkbox" class="column-toggle" data-column="freeStorageGB" checked> Armazenamento Livre</label>
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
                <svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor">
                    <path d="M12 2l10 6-10 6-10-6 10-6zM2 12l10  ASCIId6 10-6z" />
                </svg>
                Grade
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
                    <th data-column="deviceName">Nome do Dispositivo<svg class="sort-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"></polyline></svg></th>
                    <th data-column="userPrincipalName">Usuário<svg class="sort-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"></polyline></svg></th>
                    <th data-column="operatingSystem">SO<svg class="sort-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"></polyline></svg></th>
                    <th data-column="osVersion">Versão do SO<svg class="sort-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"></polyline></svg></th>
                    <th data-column="manufacturer">Fabricante<svg class="sort-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"></polyline></svg></th>
                    <th data-column="model">Modelo<svg class="sort-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"></polyline></svg></th>
                    <th data-column="serialNumber">Número de Série<svg class="sort-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"></polyline></svg></th>
                    <th data-column="lastSyncDateTime">Última Sincronização<svg class="sort-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"></polyline></svg></th>
                    <th data-column="complianceState">Conformidade<svg class="sort-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"></polyline></svg></th>
                    <th data-column="totalStorageGB">Armazenamento Total (GB)<svg class="sort-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"></polyline></svg></th>
                    <th data-column="freeStorageGB">Armazenamento Livre (GB)<svg class="sort-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"></polyline></svg></th>
                </tr>
            </thead>
            <tbody id="tableBody"></tbody>
        </table>
    </div>

    <div id="devicesGrid" class="grid-view hidden"></div>

    <div class="pagination">
        <button id="prevPage" class="btn">◄ Anterior</button>
        <span id="pageInfo"></span>
        <button id="nextPage" class="btn">Próximo ►</button>
    </div>

    <script>
        const devices = ${devicesJson};

        // Efeitos de iluminação
        const particleContainer = document.getElementById('particle-container');
        document.addEventListener('mousemove', (e) => {
            // Partículas
            const particle = document.createElement('div');
            particle.className = 'particle';
            const size = Math.random() * 8 + 4;
            particle.style.width = `${size}px`;
            particle.style.height = `${size}px`;
            particle.style.left = `${e.clientX}px`;
            particle.style.top = `${e.clientY}px`;
            particle.style.opacity = Math.random() * 0.5 + 0.3;
            particleContainer.appendChild(particle);
            setTimeout(() => particle.remove(), 1000);

            // Aura
            const aura = document.getElementById('cursor-aura');
            aura.style.left = `${e.clientX}px`;
            aura.style.top = `${e.clientY}px`;
        });

        // Funcionalidade dos dropdowns
        document.getElementById('toggleFilters').addEventListener('click', (e) => {
            e.preventDefault();
            const panel = document.getElementById('filterPanel');
            const button = e.currentTarget;
            const otherPanel = document.getElementById('columnPanel');
            otherPanel.classList.add('hidden');
            panel.classList.toggle('hidden');
            const isHidden = panel.classList.contains('hidden');
            button.querySelector('.arrow').style.transform = isHidden ? 'rotate(0deg)' : 'rotate(180deg)';
        });

        document.getElementById('toggleColumns').addEventListener('click', (e) => {
            e.preventDefault();
            const panel = document.getElementById('columnPanel');
            const button = e.currentTarget;
            const otherPanel = document.getElementById('filterPanel');
            otherPanel.classList.add('hidden');
            panel.classList.toggle('hidden');
            const isHidden = panel.classList.contains('hidden');
            button.querySelector('.arrow').style.transform = isHidden ? 'rotate(0deg)' : 'rotate(180deg)';
        });

        document.addEventListener('click', (e) => {
            const dropdowns = document.querySelectorAll('.dropdown-content');
            dropdowns.forEach(panel => {
                const card = panel.closest('.control-card');
                if (!card.contains(e.target)) {
                    panel.classList.add('hidden');
                    const button = card.querySelector('.btn');
                    const arrow = button.querySelector('.arrow');
                    if (arrow) arrow.style.transform = 'rotate(0deg)';
                }
            });
        });
    </script>
    <script src="https://intune-management.vercel.app/script.js"></script>
</body>
</html>
"@

# Salva o HTML em um arquivo
$htmlContent | Out-File -FilePath ".\IntuneReport.html" -Encoding UTF8

# Abre o relatório no navegador padrão
Start-Process ".\IntuneReport.html"
