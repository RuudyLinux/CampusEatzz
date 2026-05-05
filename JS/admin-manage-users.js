// ── CSV Import ────────────────────────────────────────────────────────────────
let _csvFailedRows = [];

window.openImportModal = function() {
    resetImportModal();
    document.getElementById("csvImportModal").classList.remove("hidden");
};

window.closeImportModal = function() {
    document.getElementById("csvImportModal").classList.add("hidden");
};

window.resetImportModal = function() {
    _csvFailedRows = [];
    document.getElementById("csvFileInput").value = "";
    document.getElementById("csvFileName").textContent = "Click to choose a .csv file";
    document.getElementById("csvUploadBtn").disabled = true;
    document.getElementById("csvPickerSection").classList.remove("hidden");
    document.getElementById("csvProgress").classList.add("hidden");
    document.getElementById("csvResult").classList.add("hidden");
    document.getElementById("csvFailedList").classList.add("hidden");
    document.getElementById("csvFailedItems").innerHTML = "";
};

window.onCsvFileSelected = function(input) {
    const file = input.files[0];
    if (!file) return;
    if (!file.name.toLowerCase().endsWith(".csv")) {
        AdminApi.showMessage("Only .csv files are allowed.", "error");
        input.value = "";
        return;
    }
    document.getElementById("csvFileName").textContent = file.name;
    document.getElementById("csvUploadBtn").disabled = false;
};

window.uploadCsvFile = async function() {
    const input = document.getElementById("csvFileInput");
    const file = input.files[0];
    if (!file) return;

    document.getElementById("csvPickerSection").classList.add("hidden");
    document.getElementById("csvProgress").classList.remove("hidden");

    try {
        const formData = new FormData();
        formData.append("file", file);

        const result = await AdminApi.request("/api/admin/users/bulk-import", {
            method: "POST",
            body: formData
        });

        const data = result.data || {};
        _csvFailedRows = data.failedRows || [];

        document.getElementById("csvTotal").textContent    = data.total    ?? 0;
        document.getElementById("csvInserted").textContent = data.inserted ?? 0;
        document.getElementById("csvFailed").textContent   = data.failed   ?? 0;

        if (_csvFailedRows.length > 0) {
            const items = document.getElementById("csvFailedItems");
            items.innerHTML = _csvFailedRows.map(function(r) {
                return `<div class="flex gap-2 text-red-600 bg-red-50 px-2 py-1 rounded">
                    <span class="font-mono">Row ${r.row}</span>
                    <span class="text-gray-600">${r.email || ""}</span>
                    <span class="ml-auto">${r.reason}</span>
                </div>`;
            }).join("");
            document.getElementById("csvFailedList").classList.remove("hidden");
        }

        document.getElementById("csvProgress").classList.add("hidden");
        document.getElementById("csvResult").classList.remove("hidden");

        if (data.inserted > 0 && typeof window.__reloadUsers === "function") {
            window.__reloadUsers();
        }
    } catch (err) {
        document.getElementById("csvProgress").classList.add("hidden");
        document.getElementById("csvPickerSection").classList.remove("hidden");
        AdminApi.showMessage(err.message || "Upload failed.", "error");
    }
};

window.downloadFailedRows = function() {
    if (!_csvFailedRows.length) return;
    const header = "row,email,reason";
    const lines  = _csvFailedRows.map(function(r) {
        return `${r.row},"${(r.email||"").replace(/"/g,'""')}","${(r.reason||"").replace(/"/g,'""')}"`;
    });
    const csv  = [header, ...lines].join("\r\n");
    const blob = new Blob([csv], { type: "text/csv" });
    const url  = URL.createObjectURL(blob);
    const a    = document.createElement("a");
    a.href     = url;
    a.download = "failed_rows.csv";
    a.click();
    URL.revokeObjectURL(url);
};

window.downloadCsvTemplate = function() {
    const csv  = "first_name,last_name,email,password,contact,department,role,university_id\r\nJohn,Doe,john@example.com,secret123,9876543210,Computer Science,student,CS2024001\r\n";
    const blob = new Blob([csv], { type: "text/csv" });
    const url  = URL.createObjectURL(blob);
    const a    = document.createElement("a");
    a.href     = url;
    a.download = "users_template.csv";
    a.click();
    URL.revokeObjectURL(url);
};
// ─────────────────────────────────────────────────────────────────────────────

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

    window.__reloadUsers = load;

    if (form) {
        form.addEventListener("submit", function(e) {
            e.preventDefault();
            load();
        });
    }

    load();
})();
