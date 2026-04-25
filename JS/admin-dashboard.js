(function() {
    const session = AdminApi.ensureAdminSession();
    if (!session) return;

    function setText(id, value) {
        const el = document.getElementById(id);
        if (el) el.textContent = value == null ? "0" : String(value);
    }

    async function loadDashboard() {
        try {
            const result = await AdminApi.request("/api/admin/dashboard");
            const data = (result && result.data) || {};

            setText("stat-totalOrders",     data.totalOrders     || 0);
            setText("stat-pendingOrders",   data.pendingOrders   || 0);
            setText("stat-todayOrders",     data.todayOrders     || 0);
            setText("stat-totalRevenue",    AdminApi.fmtMoney(data.totalRevenue || 0));
            setText("stat-totalUsers",      data.totalUsers      || 0);
            setText("stat-completedOrders", data.completedOrders || 0);
            setText("stat-cancelledOrders", data.cancelledOrders || 0);
            setText("stat-unreadMessages",  data.unreadMessages  || 0);
        } catch (error) {
            AdminApi.showMessage(error.message, "error");
        }
    }

    loadDashboard();
})();
