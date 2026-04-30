(function() {
    const session = AdminApi.ensureAdminSession();
    if (!session) return;

    const tbody = document.getElementById("refundTableBody");
    const loading = document.getElementById("loadingIndicator");
    const noRefunds = document.getElementById("noRefunds");
    const statusFilter = document.getElementById("statusFilter");
    const searchInput = document.getElementById("searchInput");

    window.applyRefundFilters = function() {
        loadRefunds();
    };

    window.clearRefundFilters = function() {
        if (statusFilter) statusFilter.value = "";
        if (searchInput) searchInput.value = "";
        loadRefunds();
    };

    window.updateRefundStatus = async function(refundId, status) {
        const actionLabel = status === "approved" ? "approve" : "reject";
        const confirmed = window.confirm("Are you sure you want to " + actionLabel + " this refund?");
        if (!confirmed) return;

        const notes = window.prompt("Add admin note (optional):", "") || "";

        try {
            await AdminApi.request("/api/admin/refunds/" + refundId, {
                method: "PATCH",
                body: JSON.stringify({
                    status: status,
                    adminNotes: notes
                })
            });

            AdminApi.showMessage("Refund " + actionLabel + "d.", "success");
            loadRefunds();
        } catch (error) {
            AdminApi.showMessage(error.message, "error");
        }
    };

    function renderStats(stats) {
        if (!stats || typeof stats !== "object") return;

        const total = stats.total || 0;
        const pending = stats.pending || 0;
        const approved = stats.approved || 0;
        const rejected = stats.rejected || 0;
        const pendingAmount = stats.pendingAmount || 0;
        const approvedAmount = stats.approvedAmount || 0;

        const setText = function(id, value) {
            const el = document.getElementById(id);
            if (el) el.textContent = value;
        };

        setText("stat-totalRefunds", String(total));
        setText("stat-pendingRefunds", String(pending));
        setText("stat-approvedRefunds", String(approved));
        setText("stat-rejectedRefunds", String(rejected));
        setText("stat-pendingAmount", AdminApi.fmtMoney(pendingAmount) + " pending");
        setText("stat-approvedAmount", AdminApi.fmtMoney(approvedAmount) + " refunded");
    }

    function statusBadge(status) {
        const value = String(status || "").toLowerCase();
        if (value === "approved") {
            return "bg-green-100 text-green-700";
        }
        if (value === "rejected") {
            return "bg-red-100 text-red-700";
        }
        return "bg-yellow-100 text-yellow-700";
    }

    function renderRows(refunds) {
        if (!tbody) return;

        tbody.innerHTML = refunds.map(function(r) {
            const status = String(r.status || "pending").toLowerCase();
            const payment = (r.paymentMethod || "-") + " / " + (r.paymentStatus || "-");
            const notes = r.adminNotes ? "<div class=\"text-xs text-gray-500\">Notes: " + r.adminNotes + "</div>" : "";
            const reason = (r.reason || "-") + notes;
            const action = status === "pending"
                ? "<div class=\"flex gap-2\">"
                    + "<button class=\"px-3 py-1 rounded text-xs font-semibold bg-green-100 text-green-700 hover:bg-green-200\" onclick=\"updateRefundStatus(" + r.id + ",'approved')\">Approve</button>"
                    + "<button class=\"px-3 py-1 rounded text-xs font-semibold bg-red-100 text-red-700 hover:bg-red-200\" onclick=\"updateRefundStatus(" + r.id + ",'rejected')\">Reject</button>"
                    + "</div>"
                : "-";

            return ""
                + "<tr>"
                + "<td class=\"px-6 py-4 text-sm font-medium text-gray-900\">" + (r.id || "-") + "</td>"
                + "<td class=\"px-6 py-4 text-sm text-gray-700\">" + (r.orderNumber || r.orderId || "-") + "</td>"
                + "<td class=\"px-6 py-4 text-sm text-gray-700\">" + (r.customerName || "-")
                + "<div class=\"text-xs text-gray-500\">" + (r.customerEmail || "") + "</div></td>"
                + "<td class=\"px-6 py-4 text-sm text-gray-700\">" + AdminApi.fmtMoney(r.amount || 0) + "</td>"
                + "<td class=\"px-6 py-4 text-sm\"><span class=\"px-2 py-1 rounded " + statusBadge(status) + "\">" + status + "</span></td>"
                + "<td class=\"px-6 py-4 text-sm text-gray-700\">" + payment + "</td>"
                + "<td class=\"px-6 py-4 text-sm text-gray-700\">" + reason + "</td>"
                + "<td class=\"px-6 py-4 text-sm text-gray-700\">" + AdminApi.fmtDate(r.createdAt) + "</td>"
                + "<td class=\"px-6 py-4 text-sm text-gray-700\">" + (r.processedAt ? AdminApi.fmtDate(r.processedAt) : "-") + "</td>"
                + "<td class=\"px-6 py-4 text-sm\">" + action + "</td>"
                + "</tr>";
        }).join("");
    }

    function bindEvents() {
        if (statusFilter) statusFilter.addEventListener("change", loadRefunds);
        if (searchInput) {
            searchInput.addEventListener("input", function() {
                clearTimeout(searchInput.__timer);
                searchInput.__timer = setTimeout(loadRefunds, 250);
            });
        }
    }

    async function loadRefunds() {
        try {
            if (loading) loading.classList.remove("hidden");

            const q = new URLSearchParams();
            if (statusFilter && statusFilter.value) q.set("status", statusFilter.value);
            if (searchInput && searchInput.value.trim()) q.set("search", searchInput.value.trim());

            const result = await AdminApi.request("/api/admin/refunds?" + q.toString());
            const data = (result && result.data) || {};
            const refunds = data.refunds || [];

            renderRows(refunds);
            renderStats(data.stats || {});

            if (noRefunds) noRefunds.classList.toggle("hidden", refunds.length > 0);
        } catch (error) {
            AdminApi.showMessage(error.message, "error");
        } finally {
            if (loading) loading.classList.add("hidden");
        }
    }

    bindEvents();
    loadRefunds();
})();
