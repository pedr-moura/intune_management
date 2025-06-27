const modelImages = {
    "Surface Pro 7": "https://via.placeholder.com/150?text=Surface+Pro+7",
    "Surface Laptop 4": "https://via.placeholder.com/150?text=Surface+Laptop+4",
    "iPhone 12": "https://via.placeholder.com/150?text=iPhone+12",
    "Latitude 3400": "https://via.placeholder.com/150?text=Latitude+3400",
    "default": "https://via.placeholder.com/150?text=Sem+Imagem"
};

let currentPage = 1;
const rowsPerPage = 100;
let isGridView = false;
let filteredDevices = [...devices];
let sortKey = 'deviceName';
let sortOrder = 'asc';
let visibleColumns = [
    'deviceName', 'userPrincipalName', 'operatingSystem', 'osVersion',
    'manufacturer', 'model', 'serialNumber', 'lastSyncDateTime',
    'complianceState', 'totalStorageGB', 'freeStorageGB'
];

// Função para formatar data
function formatDate(dateStr) {
    if (dateStr === "N/A") return "N/A";
    const date = new Date(dateStr);
    return isNaN(date) ? "N/A" : date.toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' });
}

// Função debounce
function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

// Exibe/oculta loading com animação
function showLoading(show) {
    const loading = document.getElementById('loading');
    loading.style.display = show ? 'flex' : 'none';
    if (show) {
        loading.classList.add('animate-pulse');
        setTimeout(() => loading.classList.remove('animate-pulse'), 1000);
    }
}

// Popula dropdowns com valores únicos
function populateDropdowns() {
    const operatingSystems = [...new Set(devices.map(d => d.operatingSystem).filter(v => v !== "N/A"))].sort();
    const manufacturers = [...new Set(devices.map(d => d.manufacturer).filter(v => v !== "N/A"))].sort();
    const models = [...new Set(devices.map(d => d.model).filter(v => v !== "N/A"))].sort();

    const osSelect = document.getElementById('operatingSystemFilter');
    operatingSystems.forEach(os => {
        const option = document.createElement('option');
        option.value = os;
        option.textContent = os;
        osSelect.appendChild(option);
    });

    const manufacturerSelect = document.getElementById('manufacturerFilter');
    manufacturers.forEach(man => {
        const option = document.createElement('option');
        option.value = man;
        option.textContent = man;
        manufacturerSelect.appendChild(option);
    });

    const modelSelect = document.getElementById('modelFilter');
    models.forEach(model => {
        const option = document.createElement('option');
        option.value = model;
        option.textContent = model;
        modelSelect.appendChild(option);
    });
}

// Carrega colunas visíveis do localStorage
function loadVisibleColumns() {
    const savedColumns = localStorage.getItem('visibleColumns');
    if (savedColumns) {
        visibleColumns = JSON.parse(savedColumns);
    }
    document.querySelectorAll('.column-toggle').forEach(checkbox => {
        checkbox.checked = visibleColumns.includes(checkbox.dataset.column);
    });
    updateTableColumns();
}

// Salva colunas visíveis no localStorage
function saveVisibleColumns() {
    localStorage.setItem('visibleColumns', JSON.stringify(visibleColumns));
}

// Atualiza visibilidade das colunas
function updateTableColumns() {
    document.querySelectorAll('th, td').forEach(cell => {
        const column = cell.dataset.column;
        if (column) {
            cell.style.display = visibleColumns.includes(column) ? '' : 'none';
        }
    });
}

// Renderiza página atual com animação
function renderPage() {
    showLoading(true);
    setTimeout(() => {
        const start = (currentPage - 1) * rowsPerPage;
        const end = start + rowsPerPage;
        const pageDevices = filteredDevices.slice(start, end);

        if (isGridView) {
            const gridHtml = pageDevices.map(device => `
                <div class="device-card animate-fade-in" title="Clique para detalhes">
                    <img class="device-image" src="${modelImages[device.model] || modelImages['default']}" alt="${device.model}">
                    <h2>${device.deviceName}</h2>
                    ${visibleColumns.includes('userPrincipalName') ? `<p><strong>Usuário:</strong> ${device.userPrincipalName}</p>` : ''}
                    ${visibleColumns.includes('operatingSystem') ? `<p><strong>SO:</strong> ${device.operatingSystem} ${device.osVersion}</p>` : ''}
                    ${visibleColumns.includes('manufacturer') ? `<p><strong>Fabricante:</strong> ${device.manufacturer}</p>` : ''}
                    ${visibleColumns.includes('model') ? `<p><strong>Modelo:</strong> ${device.model}</p>` : ''}
                    ${visibleColumns.includes('serialNumber') ? `<p><strong>Número de Série:</strong> ${device.serialNumber}</p>` : ''}
                    ${visibleColumns.includes('lastSyncDateTime') ? `<p><strong>Última Sinc.:</strong> ${formatDate(device.lastSyncDateTime)}</p>` : ''}
                    ${visibleColumns.includes('complianceState') ? `<p><strong>Conformidade:</strong> ${device.complianceState}</p>` : ''}
                    ${visibleColumns.includes('totalStorageGB') || visibleColumns.includes('freeStorageGB') ? `<p><strong>Armazenamento:</strong> ${device.totalStorageGB} GB (Livre: ${device.freeStorageGB} GB)</p>` : ''}
                </div>
            `).join('');
            document.getElementById('gridContainer').innerHTML = gridHtml;
            document.getElementById('devicesTable').classList.add('hidden');
            document.getElementById('devicesGrid').classList.remove('hidden');
        } else {
            const tableHtml = pageDevices.map(device => `
                <tr class="animate-fade-in" title="Detalhes do dispositivo">
                    <td data-column="deviceName">${device.deviceName}</td>
                    <td data-column="userPrincipalName">${device.userPrincipalName}</td>
                    <td data-column="operatingSystem">${device.operatingSystem}</td>
                    <td data-column="osVersion">${device.osVersion}</td>
                    <td data-column="manufacturer">${device.manufacturer}</td>
                    <td data-column="model">${device.model}</td>
                    <td data-column="serialNumber">${device.serialNumber}</td>
                    <td data-column="lastSyncDateTime">${formatDate(device.lastSyncDateTime)}</td>
                    <td data-column="complianceState">${device.complianceState}</td>
                    <td data-column="totalStorageGB">${device.totalStorageGB}</td>
                    <td data-column="freeStorageGB">${device.freeStorageGB}</td>
                </tr>
            `).join('');
            document.getElementById('tableBody').innerHTML = tableHtml;
            document.getElementById('devicesGrid').classList.add('hidden');
            document.getElementById('devicesTable').classList.remove('hidden');
            updateTableColumns();
        }

        const totalPages = Math.ceil(filteredDevices.length / rowsPerPage);
        document.getElementById('pageInfo').textContent = `Página ${currentPage} de ${totalPages} (${filteredDevices.length} dispositivos)`;
        document.getElementById('prevPage').disabled = currentPage === 1;
        document.getElementById('nextPage').disabled = currentPage === totalPages;
        updateSortIndicators();
        showLoading(false);
    }, 100);
}

// Atualiza indicadores de ordenação com ícones SVG
function updateSortIndicators() {
    document.querySelectorAll('th').forEach(th => {
        const sortIcon = th.querySelector('.sort-icon');
        th.classList.remove('sort-asc', 'sort-desc');
        if (th.dataset.column === sortKey) {
            th.classList.add(`sort-${sortOrder}`);
            sortIcon.style.transform = sortOrder === 'asc' ? 'rotate(0deg)' : 'rotate(180deg)';
        } else {
            sortIcon.style.transform = 'rotate(0deg)';
        }
    });
}

// Valida inputs numéricos
function validateNumberInput(input) {
    const value = input.value;
    if (value && (isNaN(value) || value < 0)) {
        input.classList.add('invalid');
    } else {
        input.classList.remove('invalid');
    }
}

// Aplica filtros
function applyFilters() {
    const deviceNameFilter = document.getElementById('deviceNameFilter').value.toLowerCase();
    const userPrincipalNameFilter = document.getElementById('userPrincipalNameFilter').value.toLowerCase();
    const operatingSystemFilter = document.getElementById('operatingSystemFilter').value;
    const osVersionFilter = document.getElementById('osVersionFilter').value.toLowerCase();
    const manufacturerFilter = document.getElementById('manufacturerFilter').value;
    const modelFilter = document.getElementById('modelFilter').value;
    const serialNumberFilter = document.getElementById('serialNumberFilter').value.toLowerCase();
    const lastSyncDateStart = document.getElementById('lastSyncDateStart').value;
    const lastSyncDateEnd = document.getElementById('lastSyncDateEnd').value;
    const complianceStateFilter = document.getElementById('complianceStateFilter').value;
    const totalStorageMin = parseFloat(document.getElementById('totalStorageMin').value) || -Infinity;
    const totalStorageMax = parseFloat(document.getElementById('totalStorageMax').value) || Infinity;
    const freeStorageMin = parseFloat(document.getElementById('freeStorageMin').value) || -Infinity;
    const freeStorageMax = parseFloat(document.getElementById('freeStorageMax').value) || Infinity;

    filteredDevices = devices.filter(device => {
        const deviceNameMatch = !deviceNameFilter || device.deviceName.toLowerCase().includes(deviceNameFilter);
        const userPrincipalNameMatch = !userPrincipalNameFilter || device.userPrincipalName.toLowerCase().includes(userPrincipalNameFilter);
        const operatingSystemMatch = !operatingSystemFilter || device.operatingSystem === operatingSystemFilter;
        const osVersionMatch = !osVersionFilter || device.osVersion.toLowerCase().includes(osVersionFilter);
        const manufacturerMatch = !manufacturerFilter || device.manufacturer === manufacturerFilter;
        const modelMatch = !modelFilter || device.model === modelFilter;
        const serialNumberMatch = !serialNumberFilter || device.serialNumber.toLowerCase().includes(serialNumberFilter);
        const complianceStateMatch = !complianceStateFilter || device.complianceState === complianceStateFilter;
        const totalStorageMatch = device.totalStorageGB >= totalStorageMin && device.totalStorageGB <= totalStorageMax;
        const freeStorageMatch = device.freeStorageGB >= freeStorageMin && device.freeStorageGB <= freeStorageMax;
        let lastSyncDateMatch = true;
        if (lastSyncDateStart || lastSyncDateEnd) {
            const syncDate = device.lastSyncDateTime !== "N/A" ? new Date(device.lastSyncDateTime) : null;
            const startDate = lastSyncDateStart ? new Date(lastSyncDateStart) : null;
            const endDate = lastSyncDateEnd ? new Date(lastSyncDateEnd) : null;
            lastSyncDateMatch = syncDate && 
                (!startDate || syncDate >= startDate) && 
                (!endDate || syncDate <= endDate);
        }
        return deviceNameMatch && userPrincipalNameMatch && operatingSystemMatch && osVersionMatch &&
               manufacturerMatch && modelMatch && serialNumberMatch && lastSyncDateMatch &&
               complianceStateMatch && totalStorageMatch && freeStorageMatch;
    });

    currentPage = 1;
    renderPage();
}

// Ordena dispositivos
function sortDevices(key) {
    if (sortKey === key) {
        sortOrder = sortOrder === 'asc' ? 'desc' : 'asc';
    } else {
        sortKey = key;
        sortOrder = 'asc';
    }
    document.getElementById('sortSelect').value = key;
    filteredDevices.sort((a, b) => {
        let aValue = a[sortKey];
        let bValue = b[sortKey];
        if (sortKey === 'lastSyncDateTime' && aValue !== "N/A" && bValue !== "N/A") {
            aValue = new Date(aValue);
            bValue = new Date(bValue);
        } else if (sortKey === 'totalStorageGB' || sortKey === 'freeStorageGB') {
            aValue = parseFloat(aValue);
            bValue = parseFloat(bValue);
        } else {
            aValue = aValue.toString().toLowerCase();
            bValue = bValue.toString().toLowerCase();
        }
        if (aValue === "N/A" || bValue === "N/A") {
            return aValue === bValue ? 0 : aValue === "N/A" ? 1 : -1;
        }
        if (aValue > bValue) return sortOrder === 'asc' ? 1 : -1;
        if (aValue < bValue) return sortOrder === 'asc' ? -1 : 1;
        return 0;
    });
    renderPage();
}

// Limpa filtros
function clearFilters() {
    document.getElementById('deviceNameFilter').value = '';
    document.getElementById('userPrincipalNameFilter').value = '';
    document.getElementById('operatingSystemFilter').value = '';
    document.getElementById('osVersionFilter').value = '';
    document.getElementById('manufacturerFilter').value = '';
    document.getElementById('modelFilter').value = '';
    document.getElementById('serialNumberFilter').value = '';
    document.getElementById('lastSyncDateStart').value = '';
    document.getElementById('lastSyncDateEnd').value = '';
    document.getElementById('complianceStateFilter').value = '';
    document.getElementById('totalStorageMin').value = '';
    document.getElementById('totalStorageMax').value = '';
    document.getElementById('freeStorageMin').value = '';
    document.getElementById('freeStorageMax').value = '';
    document.querySelectorAll('input').forEach(input => input.classList.remove('invalid'));
    applyFilters();
}

// Aplica seleção de colunas
function applyColumns() {
    visibleColumns = Array.from(document.querySelectorAll('.column-toggle:checked')).map(cb => cb.dataset.column);
    saveVisibleColumns();
    renderPage();
}

// Fecha dropdowns ao clicar fora com animação
function closeDropdowns(event) {
    const filterPanel = document.getElementById('filterPanel');
    const columnPanel = document.getElementById('columnPanel');
    const toggleFilters = document.getElementById('toggleFilters');
    const toggleColumns = document.getElementById('toggleColumns');

    if (!event.target.closest('.dropdown')) {
        filterPanel.classList.add('hidden');
        toggleFilters.classList.remove('active');
        toggleFilters.querySelector('.arrow').style.transform = 'rotate(0deg)';
        columnPanel.classList.add('hidden');
        toggleColumns.classList.remove('active');
        toggleColumns.querySelector('.arrow').style.transform = 'rotate(0deg)';
    }
}

// Adiciona eventos
const debouncedApplyFilters = debounce(applyFilters, 300);
document.getElementById('applyFilters').addEventListener('click', applyFilters);
document.getElementById('clearFilters').addEventListener('click', clearFilters);
document.getElementById('deviceNameFilter').addEventListener('input', debouncedApplyFilters);
document.getElementById('userPrincipalNameFilter').addEventListener('input', debouncedApplyFilters);
document.getElementById('osVersionFilter').addEventListener('input', debouncedApplyFilters);
document.getElementById('serialNumberFilter').addEventListener('input', debouncedApplyFilters);
document.getElementById('operatingSystemFilter').addEventListener('change', applyFilters);
document.getElementById('manufacturerFilter').addEventListener('change', applyFilters);
document.getElementById('modelFilter').addEventListener('change', applyFilters);
document.getElementById('complianceStateFilter').addEventListener('change', applyFilters);
document.getElementById('lastSyncDateStart').addEventListener('change', applyFilters);
document.getElementById('lastSyncDateEnd').addEventListener('change', applyFilters);
document.getElementById('totalStorageMin').addEventListener('input', (e) => {
    validateNumberInput(e.target);
    debouncedApplyFilters();
});
document.getElementById('totalStorageMax').addEventListener('input', (e) => {
    validateNumberInput(e.target);
    debouncedApplyFilters();
});
document.getElementById('freeStorageMin').addEventListener('input', (e) => {
    validateNumberInput(e.target);
    debouncedApplyFilters();
});
document.getElementById('freeStorageMax').addEventListener('input', (e) => {
    validateNumberInput(e.target);
    debouncedApplyFilters();
});
document.getElementById('sortSelect').addEventListener('change', () => sortDevices(document.getElementById('sortSelect').value));
document.getElementById('toggleView').addEventListener('click', () => {
    isGridView = !isGridView;
    document.getElementById('toggleView').innerHTML = `
        <svg class="icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M${isGridView ? '12 2l10 6-10 6-10-6 10-6zM2 12l10 6 10-6' : '12 2l5 5-5 5-5-5 5-5zM7 12l5 5 5-5'}" />
        </svg>
        Ver como ${isGridView ? 'Lista' : 'Grade'}
    `;
    renderPage();
});
document.getElementById('prevPage').addEventListener('click', () => {
    if (currentPage > 1) {
        currentPage--;
        renderPage();
    }
});
document.getElementById('nextPage').addEventListener('click', () => {
    const totalPages = Math.ceil(filteredDevices.length / rowsPerPage);
    if (currentPage < totalPages) {
        currentPage++;
        renderPage();
    }
});
document.getElementById('toggleFilters').addEventListener('click', (e) => {
    e.preventDefault();
    const filterPanel = document.getElementById('filterPanel');
    const isHidden = filterPanel.classList.toggle('hidden');
    document.getElementById('toggleFilters').classList.toggle('active', !isHidden);
    document.getElementById('toggleFilters').querySelector('.arrow').style.transform = isHidden ? 'rotate(0deg)' : 'rotate(180deg)';
    if (!isHidden) {
        document.getElementById('columnPanel').classList.add('hidden');
        document.getElementById('toggleColumns').classList.remove('active');
        document.getElementById('toggleColumns').querySelector('.arrow').style.transform = 'rotate(0deg)';
    }
    filterPanel.style.opacity = isHidden ? '0' : '1';
    filterPanel.style.transform = isHidden ? 'translateY(-10px)' : 'translateY(0)';
});
document.getElementById('toggleColumns').addEventListener('click', (e) => {
    e.preventDefault();
    const columnPanel = document.getElementById('columnPanel');
    const isHidden = columnPanel.classList.toggle('hidden');
    document.getElementById('toggleColumns').classList.toggle('active', !isHidden);
    document.getElementById('toggleColumns').querySelector('.arrow').style.transform = isHidden ? 'rotate(0deg)' : 'rotate(180deg)';
    if (!isHidden) {
        document.getElementById('filterPanel').classList.add('hidden');
        document.getElementById('toggleFilters').classList.remove('active');
        document.getElementById('toggleFilters').querySelector('.arrow').style.transform = 'rotate(0deg)';
    }
    columnPanel.style.opacity = isHidden ? '0' : '1';
    columnPanel.style.transform = isHidden ? 'translateY(-10px)' : 'translateY(0)';
});
document.getElementById('applyColumns').addEventListener('click', applyColumns);
document.querySelectorAll('th').forEach(th => {
    th.addEventListener('click', () => {
        const column = th.dataset.column;
        if (column) sortDevices(column);
    });
});
document.addEventListener('click', closeDropdowns);

// Inicialização
window.onload = () => {
    populateDropdowns();
    loadVisibleColumns();
    renderPage();
    document.querySelectorAll('.animate-fade').forEach(el => el.classList.add('visible'));
    document.getElementById('toggleView').innerHTML = `
        <svg class="icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M12 2l10 6-10 6-10-6 10-6zM2 12l10 6 10-6" />
        </svg>
        Ver como Grade
    `;
};
