
const modelImages = {
    // Adicione URLs de imagens para cada modelo conforme o log em device_models_*.log
    "Surface Pro 7": "https://via.placeholder.com/150",
    "Surface Laptop 4": "https://via.placeholder.com/150",
    "iPhone 12": "https://via.placeholder.com/150",
    // Adicione mais modelos conforme necessário
    "default": "https://via.placeholder.com/150?text=No+Image"
};

let currentPage = 1;
const rowsPerPage = 10;
let isGridView = false;
let filteredData = [];

function filterTable() {
    const input = document.getElementById('searchInput').value.toLowerCase();
    filteredData = deviceData.filter(device => 
        Object.values(device).some(value => 
            value.toString().toLowerCase().includes(input)
        )
    );
    currentPage = 1;
    renderPage();
}

function sortTable(key) {
    const sortKey = key || document.getElementById('sortSelect').value;
    filteredData.sort((a, b) => {
        let aValue = a[sortKey];
        let bValue = b[sortKey];
        if (sortKey === 'LastSyncDateTime') {
            aValue = new Date(aValue);
            bValue = new Date(bValue);
        } else if (sortKey === 'TotalStorageGB' || sortKey === 'FreeStorageGB') {
            aValue = parseFloat(aValue);
            bValue = parseFloat(bValue);
        }
        return aValue > bValue ? 1 : aValue < bValue ? -1 : 0;
    });
    currentPage = 1;
    renderPage();
}

function renderPage() {
    const start = (currentPage - 1) * rowsPerPage;
    const end = start + rowsPerPage;
    const pageData = filteredData.slice(start, end);
    const tbody = document.getElementById('tableBody');
    const grid = document.getElementById('devicesGrid');
    tbody.innerHTML = '';
    grid.innerHTML = '';

    pageData.forEach(device => {
        const row = document.createElement('tr');
        row.className = 'hover:bg-gray-50';
        row.innerHTML = `
            <td class="p-2" data-model="${device.Model}">${device.DeviceName}</td>
            <td class="p-2">${device.UserPrincipalName}</td>
            <td class="p-2">${device.OperatingSystem}</td>
            <td class="p-2">${device.OSVersion}</td>
            <td class="p-2">${device.Manufacturer}</td>
            <td class="p-2">${device.Model}</td>
            <td class="p-2">${device.SerialNumber}</td>
            <td class="p-2">${device.LastSyncDateTime}</td>
            <td class="p-2">${device.ComplianceState}</td>
            <td class="p-2">${device.TotalStorageGB}</td>
            <td class="p-2">${device.FreeStorageGB}</td>
        `;
        tbody.appendChild(row);

        const card = document.createElement('div');
        card.className = 'bg-white p-4 rounded-lg shadow-md device-card';
        card.dataset.model = device.Model;
        card.innerHTML = `
            <img class="w-full h-32 object-contain mb-2 device-image" src="${modelImages[device.Model] || modelImages['default']}" alt="${device.Model}">
            <h2 class="text-lg font-semibold">${device.DeviceName}</h2>
            <p><strong>User:</strong> ${device.UserPrincipalName}</p>
            <p><strong>OS:</strong> ${device.OperatingSystem} ${device.OSVersion}</p>
            <p><strong>Manufacturer:</strong> ${device.Manufacturer}</p>
            <p><strong>Model:</strong> ${device.Model}</p>
            <p><strong>Serial:</strong> ${device.SerialNumber}</p>
            <p><strong>Last Sync:</strong> ${device.LastSyncDateTime}</p>
            <p><strong>Compliance:</strong> ${device.ComplianceState}</p>
            <p><strong>Storage:</strong> ${device.TotalStorageGB} GB (Free: ${device.FreeStorageGB} GB)</p>
        `;
        grid.appendChild(card);
    });

    const totalPages = Math.ceil(filteredData.length / rowsPerPage);
    document.getElementById('pageInfo').textContent = `Page ${currentPage} of ${totalPages || 1}`;
    document.getElementById('prevPage').disabled = currentPage === 1;
    document.getElementById('nextPage').disabled = currentPage >= totalPages;
}

function toggleView() {
    isGridView = !isGridView;
    document.getElementById('devicesTable').classList.toggle('hidden', isGridView);
    document.getElementById('devicesGrid').classList.toggle('hidden', !isGridView);
    document.getElementById('toggleView').textContent = isGridView ? 'Switch to List View' : 'Switch to Grid View';
    renderPage();
}

// Configura eventos
document.addEventListener('DOMContentLoaded', () => {
    document.getElementById('searchInput').addEventListener('keyup', filterTable);
    document.getElementById('sortSelect').addEventListener('change', () => sortTable());
    document.getElementById('prevPage').addEventListener('click', () => {
        if (currentPage > 1) {
            currentPage--;
            renderPage();
        }
    });
    document.getElementById('nextPage').addEventListener('click', () => {
        currentPage++;
        renderPage();
    });
    document.getElementById('toggleView').addEventListener('click', toggleView);
});
