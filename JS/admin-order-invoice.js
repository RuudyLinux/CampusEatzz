(function() {
    const session = AdminApi.ensureAdminSession();
    if (!session) return;

    function getOrderRef() {
        const params = new URLSearchParams(location.search);
        return params.get("orderRef") || params.get("id") || "";
    }

    function setText(id, value) {
        const el = document.getElementById(id);
        if (el) el.textContent = value == null ? "" : String(value);
    }

    function renderItems(items) {
        const table = document.getElementById("itemsTable");
        if (!table) return;
        table.innerHTML = (items || []).map(function(i) {
            const qty = Number(i.quantity || 0);
            const unit = Number(i.unitPrice || 0);
            const total = Number(i.totalPrice || qty * unit);
            return `
                <tr>
                    <td class="px-4 py-3 text-sm text-gray-900">${i.itemName || "Item"}</td>
                    <td class="px-4 py-3 text-center text-sm text-gray-700">${qty}</td>
                    <td class="px-4 py-3 text-right text-sm text-gray-700">${AdminApi.fmtMoney(unit)}</td>
                    <td class="px-4 py-3 text-right text-sm text-gray-700">${AdminApi.fmtMoney(total)}</td>
                </tr>`;
        }).join("");
    }

    window.goBack = function() {
        history.back();
    };

    async function load() {
        const orderRef = getOrderRef();
        if (!orderRef) {
            AdminApi.showMessage("Order reference is missing.", "error");
            return;
        }

        try {
            const result = await AdminApi.request(`/api/admin/orders/${encodeURIComponent(orderRef)}`);
            const o = (result && result.data) || {};

            setText("orderId", o.orderNumber || o.id || orderRef);
            setText("orderDate", AdminApi.fmtDate(o.createdAt));
            setText("customerName", o.customerName || "-");
            setText("customerPhone", o.customerPhone || "-");
            setText("customerEmail", o.customerEmail || "-");
            setText("canteenName", o.canteenName || "-");
            setText("subtotal", AdminApi.fmtMoney(o.subtotal || 0));
            setText("tax", AdminApi.fmtMoney(o.tax || 0));
            setText("total", AdminApi.fmtMoney(o.total || 0));
            setText("paymentMethod", o.paymentMethod || "-");
            setText("orderStatus", o.status || "-");

            if (o.specialInstructions) {
                document.getElementById("specialInstructionsDiv")?.classList.remove("hidden");
                setText("specialInstructions", o.specialInstructions);
            }

            renderItems(o.items || []);
        } catch (error) {
            AdminApi.showMessage(error.message, "error");
        }
    }

    load();
})();
