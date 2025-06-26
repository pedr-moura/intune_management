const modelImages = {
    // Adicione URLs de imagens para cada modelo conforme o log
    "Surface Pro 7": "https://via.placeholder.com/150",
    "Surface Laptop 4": "https://via.placeholder.com/150",
    "iPhone 12": "https://via.placeholder.com/150",
    // Adicione mais modelos conforme necessário
    "default": "https://via.placeholder.com/150?text=No+Image"
};

let currentPage = 1;
const rowsPerPage = 10;
let isGridView = false;
let allRows = [];
let allCards = [];

function updateImages() {
    document.querySelectorAll('.device-card, [data-model]').forEach(element => {
        const model = element.dataset.model;
        const img = element.querySelector('.device-image');
        if (img) {
            img.src = modelImages[model] || modelImages['default'];
        }
    });
}

function filterTable() {
    const input = document.getElementById('searchInput').value.toLowerCase();
    allRows.forEach(row => {
        const cells = row.getElementsByTagName('td');
        let match = false;
        for (let j = 0; j < cells.length; j++) {
            if (cells[j].textContent.toLowerCase().includes(input)) {
                match = true;
                break;
            }
        }
        row.style.display = match ? '' : 'none';
    });
    allCards.forEach(card => {
        const texts = card.textContent.toLowerCase();
        card.style.display = texts.includes(input) ? '' : 'none';
    });
    currentPage = 1;
    paginate();
}

function sortTable(key) {
    const rows = Array.from(allRows);
    const cards = Array.from(allCards);
    const sortKey = key || document.getElementById('sortSelect').value;
    const sorter = (a, b) => {
        let aValue, bValue;
        if (isGridView) {
            aValue = a.querySelector(`[data-sort="${sortKey}"]`)?.textContent || a.textContent;
            bValue = b.querySelector(`[data-sort="${sortKey}"]`)?.textContent || b.textContent;
        } else {
            const index = {
                'DeviceName': 0, 'UserPrincipalName': 1, 'OperatingSystem': 2, 'OSVersion': 3,
                'Manufacturer': 4, 'Model': 5, 'SerialNumber': 6, 'LastSyncDateTime': 7,
                'ComplianceState': 8, 'TotalStorageGB': 9, 'FreeStorageGB': 10
            }[sortKey];
            aValue = a.cells[index].textContent;
            bValue = b.cells[index].textContent;
        }
        if (sortKey === 'LastSyncDateTime') {
            aValue = new Date(aValue);
            bValue = new Date(bValue);
        } else if (sortKey === 'TotalStorageGB' || sortKey === 'FreeStorageGB') {
            aValue = parseFloat(aValue);
            bValue = parseFloat(bValue);
        }
        return aValue > bValue ? 1 : aValue < bValue ? -1 : 0;
    };
    rows.sort(sorter);
    cards.sort(sorter);
    const tbody = document.getElementById('tableBody');
    tbody.innerHTML = '';
    rows.forEach(row => tbody.appendChild(row));
    const grid = document.getElementById('devicesGrid');
    grid.innerHTML = '';
    cards.forEach(card => grid.appendChild(card));
    currentPage = 1;
    paginate();
}

function paginate() {
    const totalRows = allRows.filter(row => row.style.display !== 'none').length;
    const totalPages = Math.ceil(totalRows / rowsPerPage);
    currentPage = Math.min(currentPage, totalPages) || 1;
    allRows.forEach((row, index) => {
        row.style.display = (index >= (currentPage - 1) * rowsPerPage && index < currentPage * rowsPerPage && row.style.display !== 'none') ? '' : 'none';
    });
    allCards.forEach((card, index) => {
        card.style.display = (index >= (currentPage - 1) * rowsPerPage && index < currentPage * rowsPerPage && card.style.display !== 'none') ? '' : 'none';
    });
    document.getElementById('pageInfo').textContent = `Page ${currentPage} of ${totalPages}`;
    document.getElementById('prevPage').disabled = currentPage === 1;
    document.getElementById('nextPage').disabled = currentPage === totalPages;
}

function toggleView() {
    isGridView = !isGridView;
    document.getElementById('devicesTable').classList.toggle('hidden', isGridView);
    document.getElementById('devicesGrid').classList.toggle('hidden', !isGridView);
    document.getElementById('toggleView').textContent = isGridView ? 'Switch to List View' : 'Switch to Grid View';
    paginate();
}

document.getElementById('prevPage').addEventListener('click', () => {
    if (currentPage > 1) {
        currentPage--;
        paginate();
    }
});

document.getElementById('nextPage').addEventListener('click', () => {
    currentPage++;
    paginate();
});

document.getElementById('toggleView').addEventListener('click', toggleView);

window.onload = () => {
    allRows = Array.from(document.getElementById('tableBody').getElementsByTagName('tr'));
    allCards = Array.from(document.getElementsByClassName('device-card'));
    allCards.forEach(card => {
        const model = card.dataset.model;
        const img = card.querySelector('.device-image');
        img.src = modelImages[model] || modelImages['default'];
    });
    paginate();
};
