(function() {
    const session = AdminApi.ensureAdminSession();
    if (!session) return;

    const tbody = document.getElementById("userTableBody");
    const totalUsersEl = document.getElementById("totalUsers");
    const activeUsersEl = document.getElementById("activeUsers");
    const loading = document.getElementById("loadingIndicator");
    const form = document.getElementById("filterForm");
    const searchInput = document.getElementById("searchInput");
    const statusFilter = document.getElementById("statusFilter");

    window.closeUserModal = function() {
        const modal = document.getElementById("userModal");
        if (modal) modal.classList.add("hidden");
    };

    function render(users) {
        if (!tbody) return;
        tbody.innerHTML = users.map(function(u) {
            return `
                <tr>
                    <td class="px-6 py-4 text-sm text-gray-900">${u.fullName || "-"}</td>
                    <td class="px-6 py-4 text-sm text-gray-700">${u.contact || "-"}</td>
                    <td class="px-6 py-4 text-sm text-gray-700">${u.email || "-"}</td>
                    <td class="px-6 py-4 text-sm text-gray-700">${u.totalOrders || 0}</td>
                    <td class="px-6 py-4 text-sm text-gray-700">${AdminApi.fmtMoney(u.totalSpent || 0)}</td>
                    <td class="px-6 py-4 text-sm text-gray-700">${AdminApi.fmtDate(u.joinedAt)}</td>
                    <td class="px-6 py-4 text-sm">
                        <button class="text-red-600 hover:text-red-800" onclick="window.__deleteUser(${u.id})">Delete</button>
                    </td>
                </tr>`;
        }).join("");
    }

    window.__deleteUser = async function(id) {
        if (!confirm("Delete this user?")) return;
        try {
            await AdminApi.request(`/api/admin/users/${id}`, { method: "DELETE" });
            await load();
        } catch (error) {
            AdminApi.showMessage(error.message, "error");
        }
    };

    async function load() {
        try {
            if (loading) loading.classList.remove("hidden");
            const q = new URLSearchParams();
            if (searchInput && searchInput.value.trim()) q.set("search", searchInput.value.trim());
            if (statusFilter && statusFilter.value) q.set("status", statusFilter.value);

            const result = await AdminApi.request(`/api/admin/users?${q.toString()}`);
            const data = (result && result.data) || {};
            const users = data.users || [];
            render(users);
            if (totalUsersEl) totalUsersEl.textContent = String(data.total || users.length || 0);
            if (activeUsersEl) activeUsersEl.textContent = String(data.active || 0);
        } catch (error) {
            AdminApi.showMessage(error.message, "error");
        } finally {
            if (loading) loading.classList.add("hidden");
        }
    }

    if (form) {
        form.addEventListener("submit", function(e) {
            e.preventDefault();
            load();
        });
    }

    load();
})();
