(function() {
    const session = AdminApi.ensureAdminSession();
    if (!session) return;

    let allMessages = [];
    let selectedId = null;
    let currentStatus = "all";

    const container = document.getElementById("messages-container");

    function render(messages) {
        if (!container) return;
        container.innerHTML = messages.map(function(m) {
            const unread = (m.status || "unread") === "unread";
            return `
                <div class="p-6 ${unread ? "bg-blue-50" : ""}">
                    <div class="flex justify-between items-start">
                        <div>
                            <h3 class="text-lg font-semibold text-gray-800">${m.subject || "No subject"}</h3>
                            <p class="text-sm text-gray-600">${m.name || "-"} · ${m.email || "-"}</p>
                            <p class="text-sm text-gray-700 mt-2 line-clamp-2">${m.message || ""}</p>
                        </div>
                        <div class="text-right">
                            <p class="text-xs text-gray-500">${AdminApi.fmtDate(m.createdAt)}</p>
                            <button class="mt-2 text-blue-700 text-sm" onclick="window.__openMessage(${m.id})">View</button>
                        </div>
                    </div>
                </div>`;
        }).join("");
    }

    function updateStats(messages) {
        document.getElementById("total-messages").textContent = String(messages.length);
        document.getElementById("unread-messages").textContent = String(messages.filter(function(m) { return (m.status || "unread") === "unread"; }).length);
    }

    function applyClientFilter() {
        const search = (document.getElementById("search-text")?.value || "").trim().toLowerCase();
        const filtered = allMessages.filter(function(m) {
            const byStatus = currentStatus === "all" || (m.status || "unread") === currentStatus;
            const hay = `${m.name || ""} ${m.email || ""} ${m.subject || ""} ${m.message || ""}`.toLowerCase();
            const bySearch = !search || hay.includes(search);
            return byStatus && bySearch;
        });
        render(filtered);
        updateStats(allMessages);
    }

    window.__openMessage = function(id) {
        const msg = allMessages.find(function(m) { return m.id === id; });
        if (!msg) return;
        selectedId = id;

        document.getElementById("modal-subject").textContent = msg.subject || "No subject";
        document.getElementById("modal-email").textContent = msg.email || "";
        document.getElementById("modal-name").textContent = msg.name || "";
        document.getElementById("modal-date").textContent = AdminApi.fmtDate(msg.createdAt);
        document.getElementById("modal-message").textContent = msg.message || "";
        document.getElementById("message-modal").classList.remove("hidden");
        document.getElementById("message-modal").classList.add("flex");

        const unreadBtn = document.getElementById("mark-unread-btn");
        const readBtn = document.getElementById("mark-read-btn");
        if ((msg.status || "unread") === "unread") {
            unreadBtn.classList.add("hidden");
            readBtn.classList.remove("hidden");
        } else {
            unreadBtn.classList.remove("hidden");
            readBtn.classList.add("hidden");
        }
    };

    window.closeModal = function() {
        document.getElementById("message-modal").classList.add("hidden");
        document.getElementById("message-modal").classList.remove("flex");
    };

    async function setStatus(status) {
        if (!selectedId) return;
        await AdminApi.request(`/api/admin/contact-messages/${selectedId}/status`, {
            method: "PATCH",
            body: JSON.stringify({ status: status })
        });
        await load();
        closeModal();
    }

    window.markAsRead = function() { setStatus("read"); };
    window.markAsUnread = function() { setStatus("unread"); };

    window.deleteMessage = async function() {
        if (!selectedId) return;
        if (!confirm("Delete this message?")) return;
        try {
            await AdminApi.request(`/api/admin/contact-messages/${selectedId}`, { method: "DELETE" });
            await load();
            closeModal();
        } catch (error) {
            AdminApi.showMessage(error.message, "error");
        }
    };

    window.filterStatus = function(status) {
        currentStatus = status;
        ["all", "unread", "read"].forEach(function(s) {
            const btn = document.getElementById(`filter-${s}`);
            if (!btn) return;
            const active = s === status;
            btn.className = active
                ? "px-4 py-2 border-2 border-blue-600 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
                : "px-4 py-2 border-2 border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors";
        });
        applyClientFilter();
    };

    window.searchMessages = applyClientFilter;

    async function load() {
        try {
            const result = await AdminApi.request("/api/admin/contact-messages");
            allMessages = (result && result.data && result.data.messages) || [];
            applyClientFilter();
        } catch (error) {
            AdminApi.showMessage(error.message, "error");
        }
    }

    load();
})();
