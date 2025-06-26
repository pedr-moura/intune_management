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

// Função para formatar data
function formatDate(dateStr) {
    if (dateStr === "N/A") return "N/A";
    const date = new Date(dateStr);
    return date.toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' });
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

// Exibe/oculta loading
function showLoading(show) {
    document.getElementById('loading').style.display = show ? 'block' : 'none';
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

// Renderiza página atual
function renderPage() {
    showLoading(true);
    setTimeout(() => {
        const start = (currentPage - 1) * rowsPerPage;
        const end = start + rowsPerPage;
        const pageDevices = filteredDevices.slice(start, end);

        if (isGridView) {
            const gridHtml = pageDevices.map(device => `
                <div class="device-card" title="Clique para detalhes">
                    <img class="device-image" src="${modelImages[device.model] || modelImages['default']}" alt="${device.model}">
                    <h2>${device.deviceName}</h2>
                    <p><strong>Usuário:</strong> ${device.userPrincipalName}</p>
                    <p><strong>SO:</strong> ${device.operatingSystem} ${device.osVersion}</p>
                    <p><strong>Fabricante:</strong> ${device.manufacturer}</p>
                    <p><strong>Modelo:</strong> ${device.model}</p>
                    <p><strong>Número de Série:</strong> ${device.serialNumber}</p>
                    <p><strong>Última Sinc.:</strong> ${formatDate(device.lastSyncDateTime)}</p>
                    <p><strong>Conformidade:</strong> ${device.complianceState}</p>
                    <p><strong>Armazenamento:</strong> ${device.totalStorageGB} GB (Livre: ${device.freeStorageGB} GB)</p>
                </div>
            `).join('');
            document.getElementById('gridContainer').innerHTML = gridHtml;
            document.getElementById('devicesTable').classList.add('hidden');
            document.getElementById('devicesGrid').classList.remove('hidden');
        } else {
            const tableHtml = pageDevices.map(device => `
                <tr title="Detalhes do dispositivo">
                    <td>${device.deviceName}</td>
                    <td>${device.userPrincipalName}</td>
                    <td>${device.operatingSystem}</td>
                    <td>${device.osVersion}</td>
                    <td>${device.manufacturer}</td>
                    <td>${device.model}</td>
                    <td>${device.serialNumber}</td>
                    <td>${formatDate(device.lastSyncDateTime)}</td>
                    <td>${device.complianceState}</td>
                    <td>${device.totalStorageGB}</td>
                    <td>${device.freeStorageGB}</td>
                </tr>
            `).join('');
            document.getElementById('tableBody').innerHTML = tableHtml;
            document.getElementById('devicesGrid').classList.add('hidden');
            document.getElementById('devicesTable').classList.remove('hidden');
        }

        const totalPages = Math.ceil(filteredDevices.length / rowsPerPage);
        document.getElementById('pageInfo').textContent = `Página ${currentPage} de ${totalPages} (${filteredDevices.length} dispositivos)`;
        document.getElementById('prevPage').disabled = currentPage === 1;
        document.getElementById('nextPage').disabled = currentPage === totalPages;
        showLoading(false);
    }, 100);
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
function sortDevices() {
    const sortSelect = document.getElementById('sortSelect');
    sortKey = sortSelect.value;
    sortOrder = sortOrder === 'asc' ? 'desc' : 'asc';
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
    applyFilters();
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
document.getElementById('totalStorageMin').addEventListener('input', debouncedApplyFilters);
document.getElementById('totalStorageMax').addEventListener('input', debouncedApplyFilters);
document.getElementById('freeStorageMin').addEventListener('input', debouncedApplyFilters);
document.getElementById('freeStorageMax').addEventListener('input', debouncedApplyFilters);
document.getElementById('sortSelect').addEventListener('change', sortDevices);
document.getElementById('toggleView').addEventListener('click', () => {
    isGridView = !isGridView;
    document.getElementById('toggleView').textContent = isGridView ? 'Ver como Lista' : 'Ver como Grade';
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
document.getElementById('toggleFilters').addEventListener('click', () => {
    const filterPanel = document.getElementById('filterPanel');
    filterPanel.classList.toggle('hidden');
    document.getElementById('toggleFilters').textContent = filterPanel.classList.contains('hidden') ? 'Filtros Avançados' : 'Esconder Filtros';
});

// Inicialização
window.onload = () => {
    populateDropdowns();
    renderPage();
    document.getElementById('toggleView').textContent = 'Ver como Grade';
};
