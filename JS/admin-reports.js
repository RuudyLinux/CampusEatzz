(function() {
    const session = AdminApi.ensureAdminSession();
    if (!session) return;

    let period = "daily";

    // Translate a period label into fromDate/toDate strings (yyyy-MM-dd)
    function getDateRange(p) {
        const today = new Date();
        const pad = function(n) { return String(n).padStart(2, "0"); };
        const fmt = function(d) {
            return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate());
        };
        const todayStr = fmt(today);

        if (p === "daily") {
            return { fromDate: todayStr, toDate: todayStr };
        }
        if (p === "weekly") {
            const from = new Date(today);
            from.setDate(today.getDate() - 6);
            return { fromDate: fmt(from), toDate: todayStr };
        }
        if (p === "monthly") {
            const from = new Date(today);
            from.setDate(today.getDate() - 29);
            return { fromDate: fmt(from), toDate: todayStr };
        }
        return null;
    }

    function setSummary(summary) {
        document.getElementById("total-orders").textContent   = String(summary.totalOrders    || 0);
        document.getElementById("total-revenue").textContent  = AdminApi.fmtMoney(summary.totalRevenue   || 0);
        document.getElementById("total-tax").textContent      = AdminApi.fmtMoney(summary.totalTax       || 0);
        document.getElementById("avg-order-value").textContent = AdminApi.fmtMoney(summary.avgOrderValue || 0);
    }

    function setCanteens(rows) {
        const body = document.getElementById("canteen-sales-body");
        if (!body) return;
        body.innerHTML = rows.map(function(r) {
            return `<tr>
                <td class="px-6 py-4 text-sm text-gray-900">${r.canteenName || "Unknown"}</td>
                <td class="px-6 py-4 text-sm text-gray-700">${r.totalOrders || 0}</td>
                <td class="px-6 py-4 text-sm text-gray-700">${AdminApi.fmtMoney(r.revenue || 0)}</td>
                <td class="px-6 py-4 text-sm text-gray-700">${AdminApi.fmtMoney(r.avgOrderValue || 0)}</td>
            </tr>`;
        }).join("");
    }

    function setPayments(payments) {
        const map = {};
        (payments || []).forEach(function(p) { map[(p.method || "").toLowerCase()] = p; });
        const wallet = map.wallet || map.online || {};
        const upi    = map.upi   || {};
        const cash   = map.cash  || {};

        document.getElementById("wallet-count").textContent   = String(wallet.totalOrders || 0);
        document.getElementById("wallet-revenue").textContent = AdminApi.fmtMoney(wallet.revenue || 0);
        document.getElementById("upi-count").textContent      = String(upi.totalOrders    || 0);
        document.getElementById("upi-revenue").textContent    = AdminApi.fmtMoney(upi.revenue    || 0);
        document.getElementById("cash-count").textContent     = String(cash.totalOrders   || 0);
        document.getElementById("cash-revenue").textContent   = AdminApi.fmtMoney(cash.revenue   || 0);
    }

    async function load() {
        try {
            const q = new URLSearchParams();

            if (period === "custom") {
                const start = document.getElementById("start-date")?.value;
                const end   = document.getElementById("end-date")?.value;
                if (!start || !end) {
                    AdminApi.showMessage("Please select a start and end date.", "error");
                    return;
                }
                q.set("fromDate", start);
                q.set("toDate",   end);
            } else {
                const range = getDateRange(period);
                q.set("fromDate", range.fromDate);
                q.set("toDate",   range.toDate);
            }

            const result = await AdminApi.request("/api/admin/reports?" + q.toString());
            const data   = (result && result.data) || {};

            setSummary(data.summary          || {});
            setCanteens(data.canteenSales    || []);
            setPayments(data.paymentMethods  || []);
        } catch (error) {
            AdminApi.showMessage(error.message, "error");
        }
    }

    window.selectPeriod = function(nextPeriod) {
        period = nextPeriod;
        ["daily", "weekly", "monthly", "custom"].forEach(function(name) {
            const btn = document.getElementById("btn-" + name);
            if (!btn) return;
            btn.className = name === nextPeriod
                ? "px-4 py-2 border-2 border-blue-600 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
                : "px-4 py-2 border-2 border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors";
        });

        const custom = document.getElementById("custom-date-range");
        if (custom) custom.classList.toggle("hidden", nextPeriod !== "custom");

        if (nextPeriod !== "custom") {
            load();
        }
    };

    window.generateReport = load;
    selectPeriod("daily");
})();
