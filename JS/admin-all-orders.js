(function() {
    const session = AdminApi.ensureAdminSession();
    if (!session) return;

    const tbody = document.getElementById("orderTableBody");
    const loading = document.getElementById("loadingIndicator");
    const noOrders = document.getElementById("noOrders");
    const statusFilter = document.getElementById("statusFilter");
    const searchInput = document.getElementById("searchInput");

    function bindEvents() {
        if (statusFilter) statusFilter.addEventListener("change", loadOrders);
        if (searchInput) {
            searchInput.addEventListener("input", function() {
                clearTimeout(searchInput.__timer);
                searchInput.__timer = setTimeout(loadOrders, 250);
            });
        }
    }

    function renderRows(orders) {
        if (!tbody) return;
        tbody.innerHTML = orders.map(function(o) {
            const badge = String(o.status || "pending").toLowerCase();
            return `
                <tr>
                    <td class="px-6 py-4 text-sm font-medium text-gray-900">${o.orderNumber || o.id}</td>
                    <td class="px-6 py-4 text-sm text-gray-700">${o.customerName || "-"}</td>
                    <td class="px-6 py-4 text-sm text-gray-700">${o.canteenName || "-"}</td>
                    <td class="px-6 py-4 text-sm text-gray-700">${o.itemCount || (o.items || []).length}</td>
                    <td class="px-6 py-4 text-sm text-gray-700">${AdminApi.fmtMoney(o.total || 0)}</td>
                    <td class="px-6 py-4 text-sm"><span class="px-2 py-1 rounded bg-gray-100 text-gray-700">${badge}</span></td>
                    <td class="px-6 py-4 text-sm text-gray-700">${o.paymentStatus || "-"}</td>
                    <td class="px-6 py-4 text-sm text-gray-700">${AdminApi.fmtDate(o.createdAt)}</td>
                    <td class="px-6 py-4 text-sm">
                        <a class="text-blue-600 hover:text-blue-800" href="/Home/AdminOrderInvoice?orderRef=${encodeURIComponent(o.orderNumber || o.id)}">Invoice</a>
                    </td>
                </tr>`;
        }).join("");
    }

    async function loadOrders() {
        try {
            if (loading) loading.classList.remove("hidden");
            const q = new URLSearchParams();
            if (statusFilter && statusFilter.value) q.set("status", statusFilter.value);
            if (searchInput && searchInput.value.trim()) q.set("search", searchInput.value.trim());
            const result = await AdminApi.request(`/api/admin/orders?${q.toString()}`);
            const orders = (result && result.data && result.data.orders) || [];
            renderRows(orders);

            if (noOrders) noOrders.classList.toggle("hidden", orders.length > 0);
        } catch (error) {
            AdminApi.showMessage(error.message, "error");
        } finally {
            if (loading) loading.classList.add("hidden");
        }
    }

    bindEvents();
    loadOrders();
})();
