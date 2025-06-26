const modelImages = {
    "Surface Pro 7": "https://via.placeholder.com/150?text=Surface+Pro+7",
    "Surface Laptop 4": "https://via.placeholder.com/150?text=Surface+Laptop+4",
    "iPhone 12": "https://via.placeholder.com/150?text=iPhone+12",
    "default": "https://via.placeholder.com/150?text=Sem+Imagem"
};

let currentPage = 1;
const rowsPerPage = 100; // Aumentado para melhor desempenho com muitos dispositivos
let isGridView = false;
let filteredDevices = [...devices]; // Assume que 'devices' vem do JSON inline
let sortKey = 'deviceName';
let sortOrder = 'asc';

// Função para formatar data no padrão brasileiro
function formatDate(dateStr) {
    if (dateStr === "N/A") return "N/A";
    const date = new Date(dateStr);
    return date.toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' });
}

// Função debounce para otimizar busca
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

// Exibe ou oculta o indicador de carregamento
function showLoading(show) {
    document.getElementById('loading').style.display = show ? 'block' : 'none';
}

// Renderiza apenas os dispositivos da página atual
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
    }, 100); // Atraso mínimo para feedback visual
}

// Filtra dispositivos com base na busca
function filterDevices() {
    const searchTerm = document.getElementById('searchInput').value.toLowerCase();
    filteredDevices = devices.filter(device =>
        Object.values(device).some(value =>
            value.toString().toLowerCase().includes(searchTerm)
        )
    );
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

// Adiciona debounce à busca
const debouncedFilter = debounce(filterDevices, 300);

// Adiciona eventos
document.getElementById('searchInput').addEventListener('input', debouncedFilter);
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

// Inicialização
window.onload = () => {
    renderPage();
    document.getElementById('toggleView').textContent = 'Ver como Grade';
};
