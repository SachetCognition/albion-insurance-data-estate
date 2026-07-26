const $ = (id) => document.getElementById(id);
let page = 0;
const size = 10;

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function money(value) {
  return `£${Number(value).toLocaleString("en-GB", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2
  })}`;
}

async function api(url) {
  const response = await fetch(url);
  const data = await response.json();
  if (!response.ok) throw data;
  return data;
}

function renderSummary(summary) {
  const tiles = [
    ["Active policies", summary.activePolicyCount],
    ["Earned premium", money(summary.totalEarnedPremiumGbp)],
    ["Open claims", summary.openClaimsCount],
    ["Incurred total", money(summary.totalIncurredGbp)]
  ];
  $("tiles").innerHTML = tiles.map(([label, value]) => `
    <div class="tile"><span>${escapeHtml(label)}</span><strong>${escapeHtml(value)}</strong></div>
  `).join("");
  $("asOf").textContent = `As of ${escapeHtml(summary.asOfDate)}`;
  $("dq").innerHTML = Object.entries(summary.dqPassRates).map(([rule, rate]) => `
    <div><b>${escapeHtml((Number(rate) * 100).toFixed(2))}%</b><small>${escapeHtml(rule)}</small></div>
  `).join("");
  $("claimsTiles").innerHTML = [
    ["Open claims", summary.openClaimsCount],
    ["Total incurred", money(summary.totalIncurredGbp)]
  ].map(([label, value]) => `
    <div class="tile"><span>${escapeHtml(label)}</span><strong>${escapeHtml(value)}</strong></div>
  `).join("");
}

function renderPolicies(data) {
  $("policies").innerHTML = data.content.map((policy) => `
    <tr>
      <td><button class="link-button policy-link" type="button" data-policy-id="${escapeHtml(policy.policyId)}">${escapeHtml(policy.policyId)}</button></td>
      <td>${escapeHtml(policy.productCode)}</td><td><span class="badge">${escapeHtml(policy.status)}</span></td>
      <td>${escapeHtml(money(policy.annualPremiumGbp))}</td><td>${escapeHtml(policy.postcodeDqStatus)}</td><td>${escapeHtml(policy.sourceSystem)}</td>
    </tr>
  `).join("");
  $("pageLabel").textContent = `Page ${data.page + 1} of ${data.totalPages}`;
  $("prev").disabled = page === 0;
  $("next").disabled = page + 1 >= data.totalPages;
}

function renderClaims(claims) {
  $("claims").innerHTML = claims.length === 0
    ? `<tr><td colspan="6">No claims on the current page.</td></tr>`
    : claims.map((claim) => `
      <tr><td>${escapeHtml(claim.claimId)}</td><td>${escapeHtml(claim.policyId)}</td><td>${escapeHtml(claim.lossDate)}</td>
      <td><span class="badge">${escapeHtml(claim.status)}</span></td><td>${escapeHtml(money(claim.incurredGbp))}</td>
      <td><span class="badge ${claim.fraudFlag === "SUSPECTED" ? "fraud-suspected" : ""}">${escapeHtml(claim.fraudFlag)}</span></td></tr>
    `).join("");
  $("claimsMeta").textContent = `${claims.length} claims on this page`;
}

async function loadSummary() {
  renderSummary(await api("/api/v1/data-products/summary"));
}

async function loadPolicies() {
  const data = await api(`/api/v1/policies?page=${page}&size=${size}`);
  renderPolicies(data);
  const claims = await Promise.all(data.content.map((policy) =>
    api(`/api/v1/policies/${encodeURIComponent(policy.policyId)}/claims`)));
  renderClaims(claims.flat());
}

async function lookup(policyId) {
  const detail = $("detail");
  detail.classList.remove("hidden");
  try {
    const policy = await api(`/api/v1/policies/${encodeURIComponent(policyId)}`);
    const claims = await api(`/api/v1/policies/${encodeURIComponent(policyId)}/claims`);
    detail.innerHTML = `
      <div class="section-head"><h2>${escapeHtml(policy.policyId)}</h2><span class="badge">${escapeHtml(policy.status)}</span></div>
      <p>${escapeHtml(policy.productCode)} · ${escapeHtml(policy.postcode || "No postcode")} · ${escapeHtml(policy.sourceSystem)}</p>
      <h3>Claims (${escapeHtml(claims.length)})</h3>
      ${claims.map((claim) => `<div class="claim"><b>${escapeHtml(claim.claimId)}</b> · ${escapeHtml(claim.status)}
        · ${escapeHtml(money(claim.incurredGbp))} incurred · loss ${escapeHtml(claim.lossDate)}
        · fraud ${escapeHtml(claim.fraudFlag)}</div>`).join("") || "<p>No claims found.</p>"}
    `;
  } catch (error) {
    detail.innerHTML = `<div class="error">${escapeHtml(error.detail || "Policy could not be loaded.")}</div>`;
  }
}

$("lookupBtn").addEventListener("click", () => lookup($("policyId").value.trim()));
$("policies").addEventListener("click", (event) => {
  const button = event.target.closest(".policy-link");
  if (button) lookup(button.dataset.policyId);
});
$("prev").addEventListener("click", () => { page -= 1; loadPolicies(); });
$("next").addEventListener("click", () => { page += 1; loadPolicies(); });
Promise.all([loadSummary(), loadPolicies()]).catch((error) => {
  $("detail").classList.remove("hidden");
  $("detail").innerHTML = `<div class="error">${escapeHtml(error.detail || "Dashboard data could not be loaded.")}</div>`;
});
