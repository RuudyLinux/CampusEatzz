(function() {
    const session = AdminApi.ensureAdminSession();
    if (!session) return;

    const container = document.getElementById("reviews-container");
    let allReviews = [];

    function renderStars(rating) {
        const full = Math.max(0, Math.min(5, Number(rating || 0)));
        return "★".repeat(full) + "☆".repeat(5 - full);
    }

    function render(list) {
        if (!container) return;
        if (list.length === 0) {
            container.innerHTML = '<p class="p-6 text-gray-500">No reviews found.</p>';
            return;
        }
        container.innerHTML = list.map(function(r) {
            return `
                <div class="p-6 border-b border-gray-100">
                    <div class="flex justify-between items-start">
                        <div>
                            <p class="font-semibold text-gray-900">${r.userName || "User"} &middot; ${r.canteenName || "Unknown"}</p>
                            <p class="text-yellow-500 text-lg">${renderStars(r.rating)}</p>
                            <p class="text-sm text-gray-700 mt-2">${r.reviewText || ""}</p>
                            ${r.adminResponse ? `<p class="text-sm text-blue-700 mt-2"><strong>Response:</strong> ${r.adminResponse}</p>` : ""}
                        </div>
                        <div class="text-right ml-4 flex-shrink-0">
                            <p class="text-xs text-gray-500">${AdminApi.fmtDate(r.createdAt)}</p>
                            <span class="text-xs px-2 py-1 rounded ${r.status === "hidden" ? "bg-gray-200 text-gray-600" : "bg-green-100 text-green-700"}">${r.status || "active"}</span>
                            <br>
                            <button class="mt-2 text-sm ${r.status === "hidden" ? "text-green-700 hover:underline" : "text-red-600 hover:underline"}"
                                onclick="window.__toggleReviewStatus(${r.id}, '${r.status}')">
                                ${r.status === "hidden" ? "Unhide" : "Hide"}
                            </button>
                        </div>
                    </div>
                </div>`;
        }).join("");
    }

    function applyClientFilters() {
        const canteenId = document.getElementById("filter-canteen")?.value || "";
        const search    = (document.getElementById("search-text")?.value || "").trim().toLowerCase();

        const filtered = allReviews.filter(function(r) {
            if (canteenId && String(r.canteenId) !== canteenId) return false;
            if (search) {
                const hay = (r.reviewText + " " + r.userName + " " + r.canteenName).toLowerCase();
                if (!hay.includes(search)) return false;
            }
            return true;
        });

        render(filtered);
        // stats reflect the filtered subset
        const avg = filtered.length === 0 ? 0 : filtered.reduce(function(s, r) { return s + r.rating; }, 0) / filtered.length;
        document.getElementById("total-reviews").textContent    = String(filtered.length);
        document.getElementById("avg-rating").textContent       = avg.toFixed(1);
        document.getElementById("positive-reviews").textContent = String(filtered.filter(function(r) { return r.rating >= 4; }).length);
        document.getElementById("responded-reviews").textContent = String(filtered.filter(function(r) { return !!r.adminResponse; }).length);
    }

    window.__toggleReviewStatus = async function(id, current) {
        const next = current === "hidden" ? "active" : "hidden";
        try {
            await AdminApi.request(`/api/admin/reviews/${id}/status`, {
                method: "PATCH",
                body: JSON.stringify({ status: next })
            });
            await load();
        } catch (error) {
            AdminApi.showMessage(error.message, "error");
        }
    };

    window.applyFilters = async function() {
        // rating and status filters go to the API; canteen + text search are client-side
        await load();
    };

    async function loadCanteens() {
        try {
            const result = await AdminApi.request("/api/admin/canteens");
            const canteens = (result && result.data && result.data.canteens) || [];
            const select = document.getElementById("filter-canteen");
            if (!select) return;
            select.innerHTML = '<option value="">All Canteens</option>' + canteens.map(function(c) {
                return `<option value="${c.id}">${c.name}</option>`;
            }).join("");
        } catch (_) {}
    }

    async function load() {
        try {
            const q = new URLSearchParams();
            const rating = document.getElementById("filter-rating")?.value;
            const status = document.getElementById("filter-status")?.value;
            if (rating) q.set("rating", rating);
            if (status) q.set("status", status);

            const result = await AdminApi.request(`/api/admin/reviews?${q.toString()}`);
            const data = (result && result.data) || {};
            allReviews = data.reviews || [];
            applyClientFilters();
        } catch (error) {
            AdminApi.showMessage(error.message, "error");
        }
    }

    // Re-filter in real time when canteen or search text changes
    const canteenSelect = document.getElementById("filter-canteen");
    if (canteenSelect) canteenSelect.addEventListener("change", applyClientFilters);
    const searchInput = document.getElementById("search-text");
    if (searchInput) {
        searchInput.addEventListener("input", function() {
            clearTimeout(searchInput.__timer);
            searchInput.__timer = setTimeout(applyClientFilters, 200);
        });
    }

    loadCanteens();
    load();
})();
