(function() {
    const session = AdminApi.ensureAdminSession();
    if (!session) return;

    const table = document.getElementById("walletsTable");

    window.searchWallets = function() {
        loadWallets();
    };

    async function loadWallets() {
        try {
            const search = (document.getElementById("searchInput")?.value || "").trim();
            const q = new URLSearchParams();
            if (search) q.set("search", search);

            const result = await AdminApi.request(`/api/admin/wallets?${q.toString()}`);
            const data = (result && result.data) || {};
            const wallets = data.wallets || [];
            const stats = data.stats || {};

            document.getElementById("totalBalance").textContent = AdminApi.fmtMoney(stats.totalBalance || 0);
            document.getElementById("activeWallets").textContent = String(stats.activeWallets || 0);
            document.getElementById("totalCredits").textContent = AdminApi.fmtMoney(stats.totalCredits || 0);
            document.getElementById("totalDebits").textContent = AdminApi.fmtMoney(stats.totalDebits || 0);

            if (table) {
                table.innerHTML = wallets.map(function(w) {
                    return `
                        <tr>
                            <td class="px-6 py-4 text-sm text-gray-900">${(w.firstName || "") + " " + (w.lastName || "")}</td>
                            <td class="px-6 py-4 text-sm text-gray-700">${w.email || "-"}</td>
                            <td class="px-6 py-4 text-sm font-semibold text-blue-700">${AdminApi.fmtMoney(w.balance || 0)}</td>
                            <td class="px-6 py-4 text-sm text-gray-700">${AdminApi.fmtDate(w.createdAt)}</td>
                            <td class="px-6 py-4 text-sm">
                                <a href="/Home/AdminWalletTransactions?userId=${w.userId}" class="text-blue-600 hover:text-blue-800 font-medium">View Transactions</a>
                            </td>
                        </tr>`;
                }).join("");
            }
        } catch (error) {
            AdminApi.showMessage(error.message, "error");
        }
    }

    loadWallets();
})();
