let filteredDevices = [];
let currentPage = 1;
let rowsPerPage = 10;
let isGridView = false;
let sortColumn = 'deviceName';
let sortDirection = 'asc';

const modelImages = {
    'Surface Pro 7': 'https://via.placeholder.com/150?text=Surface+Pro+7',
    'iPhone 12': 'https://via.placeholder.com/150?text=iPhone+12',
    'default': 'https://via.placeholder.com/150?text=Device'
};

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

function formatDate(dateStr) {
    if (dateStr === 'N/A') return 'N/A';
    const date = new Date(dateStr);
    return date.toLocaleString('pt-BR', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    });
}

function populateSelectOptions(devices) {
    const operatingSystemFilter = document.getElementById('operatingSystemFilter');
    const manufacturerFilter = document.getElementById('manufacturerFilter');
    const modelFilter = document.getElementById('modelFilter');

    const operatingSystems = [...new Set(devices.map(d => d.operatingSystem).filter(os => os !== 'N/A'))].sort();
    const manufacturers = [...new Set(devices.map(d => d.manufacturer).filter(m => m !== 'N/A'))].sort();
    const models = [...new Set(devices.map(d => d.model).filter(m => m !== 'N/A'))].sort();

    operatingSystems.forEach(os => {
        const option = document.createElement('option');
        option.value = os;
        option.textContent = os;
        operatingSystemFilter.appendChild(option);
    });

    manufacturers.forEach(m => {
        const option = document.createElement('option');
        option.value = m;
        option.textContent = m;
        manufacturerFilter.appendChild(option);
    });

    models.forEach(m => {
        const option = document.createElement('option');
        option.value = m;
        option.textContent = m;
        modelFilter.appendChild(option);
    });
}

function applyFilters() {
    const deviceNameFilter = document.getElementById('deviceNameFilter').value.toLowerCase();
    const userPrincipalNameFilter = document.getElementById('userPrincipalNameFilter').value.toLowerCase();
    const operatingSystemFilter = document.getElementById('operatingSystemFilter').value;
    const osVersionFilter = document.getElementById('osVersionFilter').value.toLowerCase();
    const manufacturerFilter = document.getElementById('manufacturerFilter').value;
    const modelFilter = document.getElementById('modelFilter').value;
    const serialNumberFilter = document.getElementById('serialNumberFilter').value.toLowerCase();
    const wifiMacAddressFilter = document.getElementById('wifiMacAddressFilter').value.toLowerCase();
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
        const wifiMacAddressMatch = !wifiMacAddressFilter || device.wifiMacAddress.toLowerCase().includes(wifiMacAddressFilter);
        const complianceStateMatch = !complianceStateFilter || device.complianceState === complianceStateFilter;
        const totalStorageMatch = device.totalStorageGB >= totalStorageMin && device.totalStorageGB <= totalStorageMax;
        const freeStorageMatch = device.freeStorageGB >= freeStorageMin && device.freeStorageGB <= freeStorageMax;
        let lastSyncDateMatch = true;
        if (lastSyncDateStart || lastSyncDateEnd) {
            const syncDate = device.lastSyncDateTime !== 'N/A' ? new Date(device.lastSyncDateTime) : null;
            const startDate = lastSyncDateStart ? new Date(lastSyncDateStart) : null;
            const endDate = lastSyncDateEnd ? new Date(lastSyncDateEnd) : null;
            lastSyncDateMatch = syncDate &&
                (!startDate || syncDate >= startDate) &&
                (!endDate || syncDate <= endDate);
        }
        return deviceNameMatch && userPrincipalNameMatch && operatingSystemMatch && osVersionMatch &&
               manufacturerMatch && modelMatch && serialNumberMatch && wifiMacAddressMatch &&
               complianceStateMatch && totalStorageMatch && freeStorageMatch;
    });

    currentPage = 1;
    renderPage();
}

function renderPage() {
    showLoading(true);
    setTimeout(() => {
        const start = (currentPage - 1) * rowsPerPage;
        const end = start + rowsPerPage;
        const pageDevices = filteredDevices.slice(start, end);

        if (isGridView) {
            const gridHtml = pageDevices.map(device => `
                <div class="device-card animate-fade-in" title="Clique para detalhes">
                    <img class="device-image" src="${modelImages[device.model] || modelImages['default']}" alt="${device.model}" onerror="this.src='${modelImages['default']}';">
                    <h2>${device.deviceName}</h2>
                    ${visibleColumns.includes('userPrincipalName') ? `<p><strong>Usuário:</strong> ${device.userPrincipalName}</p>` : ''}
                    ${visible部分: visibleColumns.includes('operatingSystem') ? `<p><strong>SO:</strong> ${device.operatingSystem} ${device.osVersion}</p>` : ''}
                    ${visibleColumns.includes('manufacturer') ? `<p><strong>Fabricante:</strong> ${device.manufacturer}</p>` : ''}
                    ${visibleColumns.includes('model') ? `<p><strong>Modelo:</strong> ${device.model}</p>` : ''}
                    ${visibleColumns.includes('serialNumber') ? `<p><strong>Número de Série:</strong> ${device.serialNumber}</p>` : ''}
                    ${visibleColumns.includes('wifiMacAddress') ? `<p><strong>MAC WiFi:</strong> ${device.wifiMacAddress}</p>` : ''}
                    ${visibleColumns.includes('lastSyncDateTime') ? `<p><strong>Última Sinc.:</strong> ${formatDate(device.lastSyncDateTime)}</p>` : ''}
                    ${visibleColumns.includes('complianceState') ? `<p><strong>Conformidade:</strong> ${device.complianceState}</p>` : ''}
                    ${visibleColumns.includes('totalStorageGB') || visibleColumns.includes('freeStorageGB') ? `<p><strong>Armazenamento:</strong> ${device.totalStorageGB} GB (Livre: ${device.freeStorageGB} GB)</p>` : ''}
                </div>
            `).join('');
            document.getElementById('devicesGrid').innerHTML = gridHtml;
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
                    <td data-column="wifiMacAddress">${device.wifiMacAddress}</td>
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

function updateTableColumns() {
    const headers = document.querySelectorAll('#devicesTable th');
    const cells = document.querySelectorAll('#devicesTable td');
    headers.forEach(header => {
        const column = header.getAttribute('data-column');
        header.style.display = visibleColumns.includes(column) ? '' : 'none';
    });
    cells.forEach(cell => {
        const column = cell.getAttribute('data-column');
        cell.style.display = visibleColumns.includes(column) ? '' : 'none';
    });
}

function sortDevices(column) {
    if (sortColumn === column) {
        sortDirection = sortDirection === 'asc' ? 'desc' : 'asc';
    } else {
        sortColumn = column;
        sortDirection = 'asc';
    }

    filteredDevices.sort((a, b) => {
        let aValue = a[sortColumn];
        let bValue = b[sortColumn];

        if (sortColumn === 'lastSyncDateTime') {
            aValue = aValue !== 'N/A' ? new Date(aValue) : null;
            bValue = bValue !== 'N/A' ? new Date(bValue) : null;
            if (!aValue) return 1;
            if (!bValue) return -1;
        } else if (['totalStorageGB', 'freeStorageGB'].includes(sortColumn)) {
            aValue = parseFloat(aValue);
            bValue = parseFloat(bValue);
        } else {
            aValue = aValue.toString().toLowerCase();
            bValue = bValue.toString().toLowerCase();
        }

        if (aValue < bValue) return sortDirection === 'asc' ? -1 : 1;
        if (aValue > bValue) return sortDirection === 'asc' ? 1 : -1;
        return 0;
    });

    renderPage();
}

function updateSortIndicators() {
    const headers = document.querySelectorAll('#devicesTable th');
    headers.forEach(header => {
        const column = header.getAttribute('data-column');
        const icon = header.querySelector('.sort-icon');
        if (column === sortColumn) {
            icon.style.transform = sortDirection === 'asc' ? 'rotate(0deg)' : 'rotate(180deg)';
            icon.style.opacity = '1';
        } else {
            icon.style.transform = 'rotate(0deg)';
            icon.style.opacity = '0.3';
        }
    });
}

function showLoading(show) {
    const loading = document.getElementById('loading');
    loading.classList.toggle('hidden', !show);
}

document.addEventListener('DOMContentLoaded', () => {
    filteredDevices = devices;
    populateSelectOptions(devices);

    const debouncedApplyFilters = debounce(applyFilters, 300);
    document.getElementById('deviceNameFilter').addEventListener('input', debouncedApplyFilters);
    document.getElementById('userPrincipalNameFilter').addEventListener('input', debouncedApplyFilters);
    document.getElementById('operatingSystemFilter').addEventListener('change', applyFilters);
    document.getElementById('osVersionFilter').addEventListener('input', debouncedApplyFilters);
    document.getElementById('manufacturerFilter').addEventListener('change', applyFilters);
    document.getElementById('modelFilter').addEventListener('change', applyFilters);
    document.getElementById('serialNumberFilter').addEventListener('input', debouncedApplyFilters);
    document.getElementById('wifiMacAddressFilter').addEventListener('input', debouncedApplyFilters);
    document.getElementById('lastSyncDateStart').addEventListener('change', applyFilters);
    document.getElementById('lastSyncDateEnd').addEventListener('change', applyFilters);
    document.getElementById('complianceStateFilter').addEventListener('change', applyFilters);
    document.getElementById('totalStorageMin').addEventListener('input', debouncedApplyFilters);
    document.getElementById('totalStorageMax').addEventListener('input', debouncedApplyFilters);
    document.getElementById('freeStorageMin').addEventListener('input', debouncedApplyFilters);
    document.getElementById('freeStorageMax').addEventListener('input', debouncedApplyFilters);

    document.getElementById('applyFilters').addEventListener('click', applyFilters);
    document.getElementById('clearFilters').addEventListener('click', () => {
        document.querySelectorAll('#filterPanel input, #folderPanel select').forEach(input => {
            if (input.type === 'text' || input.type === 'number' || input.type === 'datetime-local') {
                input.value = '';
            } else if (input.tagName === 'SELECT') {
                input.value = '';
            }
        });
        applyFilters();
    });

    document.getElementById('toggleFilters').addEventListener('click', () => {
        const panel = document.getElementById('filterPanel');
        const arrow = document.getElementById('toggleFilters').querySelector('.arrow');
        panel.classList.toggle('hidden');
        arrow.style.transform = panel.classList.contains('hidden') ? 'rotate(0deg)' : 'rotate(180deg)';
    });

    document.getElementById('toggleColumns').addEventListener('click', () => {
        const panel = document.getElementById('columnPanel');
        const arrow = document.getElementById('toggleColumns').querySelector('.arrow');
        panel.classList.toggle('hidden');
        arrow.style.transform = panel.classList.contains('hidden') ? 'rotate(0deg)' : 'rotate(180deg)';
    });

    document.getElementById('applyColumns').addEventListener('click', () => {
        visibleColumns = Array.from(document.querySelectorAll('.column-toggle:checked')).map(cb => cb.getAttribute('data-column'));
        document.getElementById('columnPanel').classList.add('hidden');
        document.getElementById('toggleColumns').querySelector('.arrow').style.transform = 'rotate(0deg)';
        renderPage();
    });

    document.getElementById('sortSelect').addEventListener('change', (e) => {
        sortDevices(e.target.value);
    });

    document.getElementById('toggleView').addEventListener('click', () => {
        isGridView = !isGridView;
        document.getElementById('toggleView').innerHTML = `
            <svg class="icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="${isGridView ? 'M3 3h18v18H3z' : 'M12 2l5 5-5 5-5-5 5-5zM7 12l5 5 5-5'}"></path>
            </svg>
            Ver como ${isGridView ? 'Tabela' : 'Grade'}
        `;
        renderPage();
    });

    document.querySelectorAll('#devicesTable th').forEach(header => {
        header.addEventListener('click', () => {
            const column = header.getAttribute('data-column');
            sortDevices(column);
        });
    });

    document.getElementById('prevPage').addEventListener('click', () => {
        if (currentPage > 1) {
            currentPage--;
            renderPage();
        }
    });

    document.getElementById('nextPage').addEventListener('click', () b=> {
        const totalPages = Math.ceil(filteredDevices.length / rowsPerPage);
        if (currentPage < totalPages) {
            currentPage++;
            renderPage();
        }
    });

    renderPage();
});
