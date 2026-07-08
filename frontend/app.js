"use strict";

/* ---------------------------------------------------------------------------
 * API client
 * ------------------------------------------------------------------------- */

const LS_KEY = "legacy_api_base";

function getApiBase() {
  const saved = localStorage.getItem(LS_KEY);
  if (saved !== null) return saved;
  return (window.APP_CONFIG && window.APP_CONFIG.API_BASE) || "";
}

function apiUrl(path) {
  const base = getApiBase().replace(/\/$/, "");
  return base + path;
}

async function apiFetch(path, options = {}) {
  const res = await fetch(apiUrl(path), {
    headers: { "Content-Type": "application/json" },
    ...options,
  });
  const text = await res.text();
  let data = null;
  try {
    data = text ? JSON.parse(text) : null;
  } catch (_) {
    data = { raw: text };
  }
  if (!res.ok) {
    const msg = (data && data.error) || `Request failed (${res.status})`;
    throw new Error(msg);
  }
  return data;
}

/* ---------------------------------------------------------------------------
 * Helpers
 * ------------------------------------------------------------------------- */

const $ = (id) => document.getElementById(id);

const money = (n) =>
  new Intl.NumberFormat(undefined, { style: "currency", currency: "USD" }).format(
    Number(n || 0)
  );

function timeAgo(iso) {
  if (!iso) return "-";
  const d = new Date(iso.endsWith("Z") || iso.includes("+") ? iso : iso + "Z");
  if (isNaN(d)) return iso;
  return d.toLocaleString();
}

function stockClass(stock) {
  if (stock <= 0) return "stock-out";
  if (stock < 20) return "stock-low";
  return "stock-ok";
}

function toast(message, type = "ok") {
  const el = document.createElement("div");
  el.className = `toast toast--${type === "err" ? "err" : "ok"}`;
  el.textContent = message;
  $("toasts").appendChild(el);
  setTimeout(() => {
    el.style.opacity = "0";
    el.style.transition = "opacity 0.3s ease";
    setTimeout(() => el.remove(), 300);
  }, 3200);
}

/* ---------------------------------------------------------------------------
 * Health
 * ------------------------------------------------------------------------- */

async function refreshHealth() {
  const badge = $("healthBadge");
  const text = $("healthText");
  try {
    const data = await apiFetch("/health");
    badge.className = "badge badge--ok";
    text.textContent = `healthy \u00b7 v${data.version || "?"}`;
  } catch (_) {
    badge.className = "badge badge--down";
    text.textContent = "unreachable";
  }
}

/* ---------------------------------------------------------------------------
 * Stats
 * ------------------------------------------------------------------------- */

async function refreshStats() {
  try {
    const s = await apiFetch("/api/v1/stats");
    $("statProducts").textContent = s.total_products ?? "-";
    $("statOrders").textContent = s.total_orders ?? "-";
    $("statRevenue").textContent = money(s.total_revenue);
    $("statUpdated").textContent = new Date().toLocaleTimeString();
  } catch (_) {
    $("statProducts").textContent = "-";
    $("statOrders").textContent = "-";
    $("statRevenue").textContent = "-";
  }
}

/* ---------------------------------------------------------------------------
 * Products
 * ------------------------------------------------------------------------- */

async function refreshProducts() {
  const list = $("productsList");
  try {
    const data = await apiFetch("/api/v1/products");
    const products = data.products || [];
    $("productsCount").textContent = data.count ?? products.length;

    if (products.length === 0) {
      list.innerHTML = '<div class="empty">No products available.</div>';
      return;
    }

    list.innerHTML = "";
    for (const p of products) {
      const card = document.createElement("div");
      card.className = "product";
      card.innerHTML = `
        <div class="product-info">
          <h3>${escapeHtml(p.name)}</h3>
          <div class="product-meta">
            <span class="price">${money(p.price)}</span>
            <span class="${stockClass(p.stock)}">${p.stock} in stock</span>
          </div>
        </div>
        <div class="order-form">
          <input class="qty-input" type="number" min="1" max="${p.stock}" value="1"
                 aria-label="Quantity for ${escapeHtml(p.name)}" />
          <button class="btn btn--primary" ${p.stock <= 0 ? "disabled" : ""}>
            ${p.stock <= 0 ? "Sold out" : "Order"}
          </button>
        </div>
      `;
      const input = card.querySelector(".qty-input");
      const btn = card.querySelector("button");
      btn.addEventListener("click", () => placeOrder(p, Number(input.value), btn));
      list.appendChild(card);
    }
  } catch (err) {
    list.innerHTML = `<div class="empty">Failed to load products: ${escapeHtml(
      err.message
    )}</div>`;
  }
}

async function placeOrder(product, quantity, btn) {
  if (!quantity || quantity < 1) {
    toast("Enter a valid quantity", "err");
    return;
  }
  const original = btn.textContent;
  btn.disabled = true;
  btn.textContent = "Ordering\u2026";
  try {
    const order = await apiFetch("/api/v1/orders", {
      method: "POST",
      body: JSON.stringify({ product_id: product.id, quantity }),
    });
    toast(`Order #${order.id}: ${quantity} \u00d7 ${product.name}`, "ok");
    await Promise.all([refreshProducts(), refreshOrders(), refreshStats()]);
  } catch (err) {
    toast(err.message, "err");
    btn.disabled = false;
    btn.textContent = original;
  }
}

/* ---------------------------------------------------------------------------
 * Orders
 * ------------------------------------------------------------------------- */

async function refreshOrders() {
  const body = $("ordersBody");
  try {
    const data = await apiFetch("/api/v1/orders");
    const orders = (data.orders || []).slice().reverse();
    $("ordersCount").textContent = data.count ?? orders.length;

    if (orders.length === 0) {
      body.innerHTML = '<tr><td colspan="5" class="empty">No orders yet.</td></tr>';
      return;
    }

    body.innerHTML = "";
    for (const o of orders) {
      const tr = document.createElement("tr");
      tr.innerHTML = `
        <td>${o.id}</td>
        <td>${escapeHtml(o.product_name)}</td>
        <td class="num">${o.quantity}</td>
        <td class="num">${money(o.total_price)}</td>
        <td>${timeAgo(o.created_at)}</td>
      `;
      body.appendChild(tr);
    }
  } catch (err) {
    body.innerHTML = `<tr><td colspan="5" class="empty">Failed to load orders: ${escapeHtml(
      err.message
    )}</td></tr>`;
  }
}

/* ---------------------------------------------------------------------------
 * Utils / wiring
 * ------------------------------------------------------------------------- */

function escapeHtml(str) {
  return String(str)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

async function refreshAll() {
  await Promise.all([refreshHealth(), refreshStats(), refreshProducts(), refreshOrders()]);
}

function updateApiBaseLabel() {
  const base = getApiBase();
  $("apiBaseLabel").textContent = base || "(same origin)";
}

function changeApiBase() {
  const current = getApiBase();
  const next = window.prompt(
    "API base URL (leave empty to use same origin as this page):",
    current
  );
  if (next === null) return;
  const trimmed = next.trim();
  if (trimmed === "") {
    localStorage.removeItem(LS_KEY);
  } else {
    localStorage.setItem(LS_KEY, trimmed);
  }
  updateApiBaseLabel();
  refreshAll();
}

function init() {
  updateApiBaseLabel();
  $("refreshBtn").addEventListener("click", refreshAll);
  $("configBtn").addEventListener("click", changeApiBase);
  refreshAll();
  // Poll health + stats periodically so the console stays live.
  setInterval(refreshHealth, 15000);
  setInterval(refreshStats, 15000);
}

document.addEventListener("DOMContentLoaded", init);
