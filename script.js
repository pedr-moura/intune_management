(function () {
    // Check dependencies
    if (!window.Chart) {
        console.error('Erro: Chart.js não carregado.');
        document.getElementById('loading').innerHTML = 'Erro: Chart.js não carregado.';
        return;
    }
    if (!window.devices || !Array.isArray(window.devices)) {
        console.error('Erro: Dados dos dispositivos inválidos.');
        document.getElementById('loading').innerHTML = 'Erro ao carregar dados.';
        return;
    }

    // State
    let currentPage = 1;
    const rowsPerPage = 100;
    let isGridView = false;
    let filteredDevices = [...window.devices];
    let sortKey = 'deviceName';
    let sortOrder = 'asc';
    let visibleColumns = [
        'deviceName', 'userPrincipalName', 'operatingSystem', 'osVersion',
        'manufacturer', 'model', 'serialNumber', 'lastSyncDateTime',
        'complianceState', 'totalStorageGB', 'freeStorageGB'
    ];
    let charts = [];

    // Device model images
    const modelImages = {
        "Surface Pro 7": "https://placehold.co/150?text=Surface+Pro+7",
        "Latitude 3400": "https://placehold.co/150?text=Latitude+3400",
        "iPhone 12": "https://placehold.co/150?text=iPhone+12",
        "Galaxy S21": "https://placehold.co/150?text=Galaxy+S21",
        "EliteBook 840": "https://placehold.co/150?text=EliteBook+840",
        "default": "https://placehold.co/150?text=Device"
    };

    // Available fields for charting
    const chartFields = [
        { value: 'operatingSystem', label: 'Sistema Operacional', isNumeric: false },
        { value: 'complianceState', label: 'Conformidade', isNumeric: false },
        { value: 'model', label: 'Modelo', isNumeric: false },
        { value: 'manufacturer', label: 'Fabricante', isNumeric: false },
        { value: 'totalStorageGB', label: 'Armazenamento Total (GB)', isNumeric: true },
        { value: 'freeStorageGB', label: 'Armazenamento Livre (GB)', isNumeric: true }
    ];

    // Chart Management
    function createChart(config) {
        const chartId = `chart-${Date.now()}-${charts.length}`;
        const chartsContainer = document.getElementById('chartsContainer');
        if (!chartsContainer) {
            console.error('Erro: chartsContainer não encontrado.');
            return;
        }

        const chartCard = document.createElement('div');
        chartCard.className = 'chart-card animate-fade-in';
        chartCard.innerHTML = `
            <h3>${config.title || `${config.yField} por ${config.xField}`}</h3>
            <canvas id="${chartId}"></canvas>
            <button class="remove-chart-btn" data-chart-id="${chartId}">Remover</button>
        `;
        chartsContainer.appendChild(chartCard);

        const canvas = document.getElementById(chartId);
        if (!canvas) {
            console.error(`Erro: Canvas ${chartId} não encontrado.`);
            chartCard.remove();
            return;
        }

        try {
            const data = aggregateChartData(config);
            const isNumericY = chartFields.find(f => f.value === config.yField)?.isNumeric;
            const chart = new Chart(canvas, {
                type: config.type,
                data: {
                    labels: data.labels,
                    datasets: [{
                        label: config.title || `${config.yField} por ${config.xField}`,
                        data: data.values,
                        backgroundColor: config.type === 'bar' || config.type === 'line' ? config.color : [
                            config.color, '#22c55e', '#f59e0b', '#ef4444', '#8b5cf6', '#eab308'
                        ],
                        borderColor: config.type === 'line' ? config.color : 'var(--card-bg)',
                        borderWidth: config.type === 'line' ? 2 : 1,
                        fill: config.type === 'line' && config.aggregation !== 'count'
                    }]
                },
                options: {
                    responsive: true,
                    plugins: {
                        legend: { position: 'bottom', labels: { color: 'var(--text-color)', font: { size: 12 } } },
                        title: { display: false }
                    },
                    scales: {
                        x: { ticks: { color: 'var(--text-color)' } },
                        y: {
                            beginAtZero: true,
                            ticks: { color: 'var(--text-color)', stepSize: isNumericY ? undefined : 1 }
                        }
                    }
                }
            });

            charts.push({ id: chartId, chart, config });
            document.querySelector(`[data-chart-id="${chartId}"]`).addEventListener('click', () => {
                charts = charts.filter(c => c.id !== chartId);
                chart.destroy();
                chartCard.remove();
            });
        } catch (e) {
            console.error(`Erro ao criar gráfico ${chartId}: ${e.message}`);
            chartCard.remove();
        }
    }

    function aggregateChartData(config) {
        const { xField, yField, aggregation, excludeValues = [] } = config;
        const isNumericX = chartFields.find(f => f.value === xField)?.isNumeric;
        const isNumericY = chartFields.find(f => f.value === yField)?.isNumeric;

        // Filter out excluded values
        let data = filteredDevices.filter(device => !excludeValues.includes(device[xField]?.toString()));

        // Group by xField
        const grouped = data.reduce((acc, device) => {
            const xValue = device[xField] || 'N/A';
            if (isNumericX) {
                const bin = Math.floor(parseFloat(xValue) / 50) * 50;
                acc[bin] = acc[bin] || { count: 0, values: [] };
                acc[bin].count++;
                acc[bin].values.push(parseFloat(device[yField]) || 0);
            } else {
                acc[xValue] = acc[xValue] || { count: 0, values: [] };
                acc[xValue].count++;
                acc[xValue].values.push(parseFloat(device[yField]) || 0);
            }
            return acc;
        }, {});

        // Aggregate y values
        const labels = Object.keys(grouped).sort((a, b) => isNumericX ? parseFloat(a) - parseFloat(b) : a.localeCompare(b));
        const values = labels.map(label => {
            const group = grouped[label];
            if (aggregation === 'count' || !isNumericY) return group.count;
            if (aggregation === 'sum') return group.values.reduce((sum, val) => sum + val, 0);
            if (aggregation === 'avg') return group.values.reduce((sum, val) => sum + val, 0) / group.values.length;
            if (aggregation === 'min') return Math.min(...group.values);
            if (aggregation === 'max') return Math.max(...group.values);
            return 0;
        });

        return {
            labels: isNumericX ? labels.map(l => `${l}-${parseInt(l)+50} GB`) : labels,
            values
        };
    }

    function updateCharts() {
        charts.forEach(({ chart, config }) => {
            const data = aggregateChartData(config);
            chart.data.labels = data.labels;
            chart.data.datasets[0].data = data.values;
            chart.update();
        });
    }

    // Update exclusion filter dropdown
    function updateExcludeFilter() {
        const xField = document.getElementById('chartXField')?.value;
        const excludeSelect = document.getElementById('chartExcludeValues');
        if (!xField || !excludeSelect) return;

        excludeSelect.innerHTML = '<option value="">Nenhum</option>';
        const values = [...new Set(filteredDevices.map(d => d[xField]).filter(v => v && v !== "N/A"))].sort();
        values.forEach(value => {
            const option = document.createElement('option');
            option.value = value;
            option.textContent = value;
            excludeSelect.appendChild(option);
        });
    }

    // Particle Effects
    function initializeParticleEffects() {
        const particleContainer = document.getElementById('particle-container');
        const aura = document.getElementById('cursor-aura');
        if (!particleContainer || !aura) return;

        document.addEventListener('mousemove', (e) => {
            const particle = document.createElement('div');
            particle.className = 'particle';
            particle.style.left = `${e.clientX}px`;
            particle.style.top = `${e.clientY}px`;
            particleContainer.appendChild(particle);
            setTimeout(() => particle.remove(), 1000);
            aura.style.left = `${e.clientX}px`;
            aura.style.top = `${e.clientY}px`;
        });
    }

    // Utilities
    function formatDate(dateStr) {
        if (!dateStr || dateStr === "N/A") return "N/A";
        try {
            const date = new Date(dateStr);
            return isNaN(date) ? "N/A" : date.toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' });
        } catch {
            return "N/A";
        }
    }

    function debounce(func, wait) {
        let timeout;
        return function (...args) {
            clearTimeout(timeout);
            timeout = setTimeout(() => func(...args), wait);
        };
    }

    function showLoading(show) {
        const loading = document.getElementById('loading');
        if (loading) {
            loading.style.display = show ? 'flex' : 'none';
            if (show) loading.classList.add('animate-pulse');
            else loading.classList.remove('animate-pulse');
        }
    }

    // Populate Dropdowns
    function populateDropdowns() {
        const fields = ['operatingSystem', 'manufacturer', 'model'];
        fields.forEach(field => {
            const select = document.getElementById(`${field}Filter`);
            if (!select) return;
            const values = [...new Set(window.devices.map(d => d[field]).filter(v => v && v !== "N/A"))].sort();
            values.forEach(value => {
                const option = document.createElement('option');
                option.value = value;
                option.textContent = value;
                select.appendChild(option);
            });
        });

        // Populate chart axis selectors
        const xFieldSelect = document.getElementById('chartXField');
        const yFieldSelect = document.getElementById('chartYField');
        if (xFieldSelect && yFieldSelect) {
            chartFields.forEach(field => {
                const xOption = document.createElement('option');
                xOption.value = field.value;
                xOption.textContent = field.label;
                xFieldSelect.appendChild(xOption);

                const yOption = document.createElement('option');
                yOption.value = field.value;
                yOption.textContent = field.label + (field.isNumeric ? '' : ' (Contagem)');
                yFieldSelect.appendChild(yOption);
            });
        }
    }

    // Render Page
    function renderPage() {
        showLoading(true);
        setTimeout(() => {
            const devicesGrid = document.getElementById('devicesGrid');
            const tableBody = document.getElementById('tableBody');
            const devicesTable = document.getElementById('devicesTable');
            if (!devicesGrid || !tableBody || !devicesTable) {
                console.error('Erro: Elementos de renderização não encontrados.');
                showLoading(false);
                return;
            }

            const start = (currentPage - 1) * rowsPerPage;
            const end = start + rowsPerPage;
            const pageDevices = filteredDevices.slice(start, end);

            if (isGridView) {
                devicesGrid.innerHTML = pageDevices.map(device => `
                    <div class="device-card animate-fade-in">
                        <img class="device-image" src="${modelImages[device.model] || modelImages['default']}" alt="${device.model || 'Device'}">
                        <h2>${device.deviceName || 'N/A'}</h2>
                        ${visibleColumns.includes('userPrincipalName') ? `<p><strong>Usuário:</strong> ${device.userPrincipalName || 'N/A'}</p>` : ''}
                        ${visibleColumns.includes('operatingSystem') ? `<p><strong>SO:</strong> ${device.operatingSystem || 'N/A'} ${device.osVersion || ''}</p>` : ''}
                        ${visibleColumns.includes('manufacturer') ? `<p><strong>Fabricante:</strong> ${device.manufacturer || 'N/A'}</p>` : ''}
                        ${visibleColumns.includes('model') ? `<p><strong>Modelo:</strong> ${device.model || 'N/A'}</p>` : ''}
                        ${visibleColumns.includes('serialNumber') ? `<p><strong>Número de Série:</strong> ${device.serialNumber || 'N/A'}</p>` : ''}
                        ${visibleColumns.includes('lastSyncDateTime') ? `<p><strong>Última Sinc.:</strong> ${formatDate(device.lastSyncDateTime)}</p>` : ''}
                        ${visibleColumns.includes('complianceState') ? `<p><strong>Conformidade:</strong> ${device.complianceState || 'N/A'}</p>` : ''}
                        ${visibleColumns.includes('totalStorageGB') || visibleColumns.includes('freeStorageGB') ? `<p><strong>Armazenamento:</strong> ${device.totalStorageGB || 0} GB (Livre: ${device.freeStorageGB || 0} GB)</p>` : ''}
                    </div>
                `).join('');
                devicesTable.classList.add('hidden');
                devicesGrid.classList.remove('hidden');
            } else {
                tableBody.innerHTML = pageDevices.map(device => `
                    <tr class="animate-fade-in">
                        ${visibleColumns.includes('deviceName') ? `<td data-column="deviceName">${device.deviceName || 'N/A'}</td>` : ''}
                        ${visibleColumns.includes('userPrincipalName') ? `<td data-column="userPrincipalName">${device.userPrincipalName || 'N/A'}</td>` : ''}
                        ${visibleColumns.includes('operatingSystem') ? `<td data-column="operatingSystem">${device.operatingSystem || 'N/A'}</td>` : ''}
                        ${visibleColumns.includes('osVersion') ? `<td data-column="osVersion">${device.osVersion || 'N/A'}</td>` : ''}
                        ${visibleColumns.includes('manufacturer') ? `<td data-column="manufacturer">${device.manufacturer || 'N/A'}</td>` : ''}
                        ${visibleColumns.includes('model') ? `<td data-column="model">${device.model || 'N/A'}</td>` : ''}
                        ${visibleColumns.includes('serialNumber') ? `<td data-column="serialNumber">${device.serialNumber || 'N/A'}</td>` : ''}
                        ${visibleColumns.includes('lastSyncDateTime') ? `<td data-column="lastSyncDateTime">${formatDate(device.lastSyncDateTime)}</td>` : ''}
                        ${visibleColumns.includes('complianceState') ? `<td data-column="complianceState">${device.complianceState || 'N/A'}</td>` : ''}
                        ${visibleColumns.includes('totalStorageGB') ? `<td data-column="totalStorageGB">${device.totalStorageGB || 0}</td>` : ''}
                        ${visibleColumns.includes('freeStorageGB') ? `<td data-column="freeStorageGB">${device.freeStorageGB || 0}</td>` : ''}
                    </tr>
                `).join('');
                devicesGrid.classList.add('hidden');
                devicesTable.classList.remove('hidden');
            }

            const totalPages = Math.ceil(filteredDevices.length / rowsPerPage);
            const pageInfo = document.getElementById('pageInfo');
            if (pageInfo) pageInfo.textContent = `Página ${currentPage} de ${totalPages} (${filteredDevices.length} dispositivos)`;
            const prevPage = document.getElementById('prevPage');
            const nextPage = document.getElementById('nextPage');
            if (prevPage && nextPage) {
                prevPage.disabled = currentPage === 1;
                nextPage.disabled = currentPage === totalPages;
            }
            updateSortIndicators();
            updateCharts();
            showLoading(false);
        }, 100);
    }

    function updateSortIndicators() {
        document.querySelectorAll('th').forEach(th => {
            const sortIcon = th.querySelector('.sort-icon');
            if (sortIcon && th.dataset.column === sortKey) {
                sortIcon.style.transform = sortOrder === 'asc' ? 'rotate(0deg)' : 'rotate(180deg)';
            } else if (sortIcon) {
                sortIcon.style.transform = 'rotate(0deg)';
            }
        });
    }

    function validateNumberInput(input) {
        const value = input.value;
        if (value && (isNaN(value) || value < 0)) {
            input.classList.add('invalid');
            return false;
        }
        input.classList.remove('invalid');
        return true;
    }

    function applyFilters() {
        const filters = {
            deviceName: document.getElementById('deviceNameFilter')?.value.toLowerCase() || '',
            userPrincipalName: document.getElementById('userPrincipalNameFilter')?.value.toLowerCase() || '',
            operatingSystem: document.getElementById('operatingSystemFilter')?.value || '',
            osVersion: document.getElementById('osVersionFilter')?.value.toLowerCase() || '',
            manufacturer: document.getElementById('manufacturerFilter')?.value || '',
            model: document.getElementById('modelFilter')?.value || '',
            serialNumber: document.getElementById('serialNumberFilter')?.value.toLowerCase() || '',
            lastSyncDateStart: document.getElementById('lastSyncDateStart')?.value || '',
            lastSyncDateEnd: document.getElementById('lastSyncDateEnd')?.value || '',
            complianceState: document.getElementById('complianceStateFilter')?.value || '',
            totalStorageMin: parseFloat(document.getElementById('totalStorageMin')?.value) || -Infinity,
            totalStorageMax: parseFloat(document.getElementById('totalStorageMax')?.value) || Infinity,
            freeStorageMin: parseFloat(document.getElementById('freeStorageMin')?.value) || -Infinity,
            freeStorageMax: parseFloat(document.getElementById('freeStorageMax')?.value) || Infinity
        };

        filteredDevices = window.devices.filter(device => {
            return (
                (!filters.deviceName || (device.deviceName || '').toLowerCase().includes(filters.deviceName)) &&
                (!filters.userPrincipalName || (device.userPrincipalName || '').toLowerCase().includes(filters.userPrincipalName)) &&
                (!filters.operatingSystem || (device.operatingSystem || '') === filters.operatingSystem) &&
                (!filters.osVersion || (device.osVersion || '').toLowerCase().includes(filters.osVersion)) &&
                (!filters.manufacturer || (device.manufacturer || '') === filters.manufacturer) &&
                (!filters.model || (device.model || '') === filters.model) &&
                (!filters.serialNumber || (device.serialNumber || '').toLowerCase().includes(filters.serialNumber)) &&
                (!filters.complianceState || (device.complianceState || '') === filters.complianceState) &&
                ((device.totalStorageGB || 0) >= filters.totalStorageMin && (device.totalStorageGB || 0) <= filters.totalStorageMax) &&
                ((device.freeStorageGB || 0) >= filters.freeStorageMin && (device.freeStorageGB || 0) <= filters.freeStorageMax) &&
                (filters.lastSyncDateStart || filters.lastSyncDateEnd ? (
                    device.lastSyncDateTime !== "N/A" &&
                    (!filters.lastSyncDateStart || new Date(device.lastSyncDateTime) >= new Date(filters.lastSyncDateStart)) &&
                    (!filters.lastSyncDateEnd || new Date(device.lastSyncDateTime) <= new Date(filters.lastSyncDateEnd))
                ) : true)
            );
        });

        currentPage = 1;
        updateExcludeFilter();
        renderPage();
    }

    function sortDevices(key) {
        if (sortKey === key) sortOrder = sortOrder === 'asc' ? 'desc' : 'asc';
        else {
            sortKey = key;
            sortOrder = 'asc';
        }
        const sortSelect = document.getElementById('sortSelect');
        if (sortSelect) sortSelect.value = key;
        filteredDevices.sort((a, b) => {
            let aValue = a[sortKey] || '';
            let bValue = b[sortKey] || '';
            if (sortKey === 'lastSyncDateTime' && aValue !== "N/A" && bValue !== "N/A") {
                aValue = new Date(aValue);
                bValue = new Date(bValue);
            } else if (['totalStorageGB', 'freeStorageGB'].includes(sortKey)) {
                aValue = parseFloat(aValue) || 0;
                bValue = parseFloat(bValue) || 0;
            } else {
                aValue = aValue.toString().toLowerCase();
                bValue = bValue.toString().toLowerCase();
            }
            if (aValue === "N/A" || bValue === "N/A") {
                return aValue === bValue ? 0 : aValue === "N/A" ? 1 : -1;
            }
            return sortOrder === 'asc' ? aValue > bValue ? 1 : -1 : aValue < bValue ? 1 : -1;
        });
        renderPage();
    }

    function clearFilters() {
        document.querySelectorAll('#filterPanel input, #filterPanel select').forEach(el => {
            el.value = '';
            el.classList.remove('invalid');
        });
        applyFilters();
    }

    function applyColumns() {
        visibleColumns = Array.from(document.querySelectorAll('.column-toggle:checked')).map(cb => cb.dataset.column);
        localStorage.setItem('visibleColumns', JSON.stringify(visibleColumns));
        renderPage();
    }

    function toggleDropdown(buttonId, panelId) {
        const button = document.getElementById(buttonId);
        const panel = document.getElementById(panelId);
        if (!button || !panel) return;
        const isHidden = panel.classList.contains('hidden');
        document.querySelectorAll('.dropdown-content').forEach(p => p.classList.add('hidden'));
        document.querySelectorAll('.btn').forEach(b => {
            b.classList.remove('active');
            if (b.querySelector('.arrow')) b.querySelector('.arrow').style.transform = 'rotate(0deg)';
        });
        panel.classList.toggle('hidden', !isHidden);
        button.classList.toggle('active', isHidden);
        if (button.querySelector('.arrow')) {
            button.querySelector('.arrow').style.transform = isHidden ? 'rotate(180deg)' : 'rotate(0deg)';
        }
    }

    // Event Listeners
    function initializeEventListeners() {
        const toggleChartConfig = document.getElementById('toggleChartConfig');
        const addChart = document.getElementById('addChart');
        const toggleFilters = document.getElementById('toggleFilters');
        const toggleColumns = document.getElementById('toggleColumns');
        const applyFiltersBtn = document.getElementById('applyFilters');
        const clearFiltersBtn = document.getElementById('clearFilters');
        const applyColumnsBtn = document.getElementById('applyColumns');
        const toggleView = document.getElementById('toggleView');
        const prevPage = document.getElementById('prevPage');
        const nextPage = document.getElementById('nextPage');
        const sortSelect = document.getElementById('sortSelect');
        const chartXField = document.getElementById('chartXField');

        if (toggleChartConfig) {
            toggleChartConfig.addEventListener('click', () => toggleDropdown('toggleChartConfig', 'chartConfigPanel'));
        }
        if (addChart) {
            addChart.addEventListener('click', () => {
                const chartType = document.getElementById('chartType')?.value;
                const xField = document.getElementById('chartXField')?.value;
                const yField = document.getElementById('chartYField')?.value;
                const aggregation = document.getElementById('chartAggregation')?.value;
                const excludeValues = Array.from(document.getElementById('chartExcludeValues')?.selectedOptions || []).map(opt => opt.value);
                const chartColor = document.getElementById('chartColor')?.value;
                const chartTitle = document.getElementById('chartTitle')?.value;
                if (chartType && xField && yField && aggregation && chartColor) {
                    createChart({
                        type: chartType,
                        xField,
                        yField,
                        aggregation,
                        excludeValues,
                        color: chartColor,
                        title: chartTitle || `${yField} por ${xField}`
                    });
                    toggleDropdown('toggleChartConfig', 'chartConfigPanel');
                } else {
                    const errorMsg = document.getElementById('chartError');
                    if (errorMsg) {
                        errorMsg.textContent = 'Por favor, preencha todos os campos obrigatórios.';
                        setTimeout(() => errorMsg.textContent = '', 3000);
                    }
                }
            });
        }
        if (chartXField) {
            chartXField.addEventListener('change', updateExcludeFilter);
        }
        if (toggleFilters) {
            toggleFilters.addEventListener('click', () => toggleDropdown('toggleFilters', 'filterPanel'));
        }
        if (toggleColumns) {
            toggleColumns.addEventListener('click', () => toggleDropdown('toggleColumns', 'columnPanel'));
        }
        if (applyFiltersBtn) {
            applyFiltersBtn.addEventListener('click', applyFilters);
        }
        if (clearFiltersBtn) {
            clearFiltersBtn.addEventListener('click', clearFilters);
        }
        if (applyColumnsBtn) {
            applyColumnsBtn.addEventListener('click', applyColumns);
        }
        if (toggleView) {
            toggleView.addEventListener('click', () => {
                isGridView = !isGridView;
                toggleView.innerHTML = `
                    <svg class="icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <path d="${isGridView ? 'M3 6h18M6 12h12M9 18h6' : 'M12 2l10 6-10 6-10-6 10-6zM2 12l10 6 10-6'}"></path>
                    </svg>
                    Ver como ${isGridView ? 'Lista' : 'Grade'}
                `;
                renderPage();
            });
        }
        if (prevPage) {
            prevPage.addEventListener('click', () => {
                if (currentPage > 1) {
                    currentPage--;
                    renderPage();
                }
            });
        }
        if (nextPage) {
            nextPage.addEventListener('click', () => {
                if (currentPage < Math.ceil(filteredDevices.length / rowsPerPage)) {
                    currentPage++;
                    renderPage();
                }
            });
        }
        if (sortSelect) {
            sortSelect.addEventListener('change', (e) => sortDevices(e.target.value));
        }
        document.querySelectorAll('th').forEach(th => {
            th.addEventListener('click', () => {
                if (th.dataset.column) sortDevices(th.dataset.column);
            });
        });

        const debouncedApplyFilters = debounce(applyFilters, 300);
        ['deviceNameFilter', 'userPrincipalNameFilter', 'osVersionFilter', 'serialNumberFilter'].forEach(id => {
            const input = document.getElementById(id);
            if (input) input.addEventListener('input', debouncedApplyFilters);
        });
        ['operatingSystemFilter', 'manufacturerFilter', 'modelFilter', 'complianceStateFilter', 'lastSyncDateStart', 'lastSyncDateEnd'].forEach(id => {
            const input = document.getElementById(id);
            if (input) input.addEventListener('change', applyFilters);
        });
        ['totalStorageMin', 'totalStorageMax', 'freeStorageMin', 'freeStorageMax'].forEach(id => {
            const input = document.getElementById(id);
            if (input) {
                input.addEventListener('input', (e) => {
                    validateNumberInput(e.target);
                    debouncedApplyFilters();
                });
            }
        });

        document.addEventListener('click', (e) => {
            if (!e.target.closest('.control-card')) {
                document.querySelectorAll('.dropdown-content').forEach(p => p.classList.add('hidden'));
                document.querySelectorAll('.btn').forEach(b => {
                    b.classList.remove('active');
                    if (b.querySelector('.arrow')) b.querySelector('.arrow').style.transform = 'rotate(0deg)';
                });
            }
        });
    }

    // Initialize
    window.onload = () => {
        try {
            initializeParticleEffects();
            populateDropdowns();
            if (localStorage.getItem('visibleColumns')) {
                visibleColumns = JSON.parse(localStorage.getItem('visibleColumns'));
                document.querySelectorAll('.column-toggle').forEach(cb => {
                    if (cb.dataset.column) cb.checked = visibleColumns.includes(cb.dataset.column);
                });
            }
            initializeEventListeners();
            updateExcludeFilter();
            renderPage();
        } catch (e) {
            console.error(`Erro na inicialização: ${e.message}`);
            showLoading(false);
            document.getElementById('loading').innerHTML = 'Erro ao inicializar a página.';
        }
    };
})();
