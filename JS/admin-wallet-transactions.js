(function() {
    const session = AdminApi.ensureAdminSession();
    if (!session) return;

    const table = document.getElementById("transactionsTable");

    window.applyFilters = function() {
        loadTransactions();
    };

    window.clearFilters = function() {
        ["typeFilter", "statusFilter", "searchInput"].forEach(function(id) {
            const el = document.getElementById(id);
            if (el) el.value = "";
        });
        loadTransactions();
    };

    async function loadTransactions() {
        try {
            const q = new URLSearchParams();
            const type = document.getElementById("typeFilter")?.value || "";
            const status = document.getElementById("statusFilter")?.value || "";
            const search = (document.getElementById("searchInput")?.value || "").trim();
            if (type) q.set("type", type);
            if (status) q.set("status", status);
            if (search) q.set("search", search);

            const result = await AdminApi.request(`/api/admin/wallet-transactions?${q.toString()}`);
            const transactions = (result && result.data && result.data.transactions) || [];

            if (table) {
                table.innerHTML = transactions.map(function(t) {
                    return `
                        <tr>
                            <td class="px-6 py-4 text-sm text-gray-900">${t.transactionId || t.id}</td>
                            <td class="px-6 py-4 text-sm text-gray-700">${((t.firstName || "") + " " + (t.lastName || "")).trim() || "-"}<div class="text-xs text-gray-500">${t.email || ""}</div></td>
                            <td class="px-6 py-4 text-sm text-gray-700">${AdminApi.fmtMoney(t.amount || 0)}</td>
                            <td class="px-6 py-4 text-sm text-gray-700">${t.type || "-"}</td>
                            <td class="px-6 py-4 text-sm text-gray-700">${t.status || "-"}</td>
                            <td class="px-6 py-4 text-sm text-gray-700">${t.description || "-"}</td>
                            <td class="px-6 py-4 text-sm text-gray-700">${AdminApi.fmtDate(t.createdAt)}</td>
                        </tr>`;
                }).join("");
            }
        } catch (error) {
            AdminApi.showMessage(error.message, "error");
        }
    }

    loadTransactions();
})();
