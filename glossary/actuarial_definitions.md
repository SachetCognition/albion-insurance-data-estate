# Actuarial Definitions (Group Actuarial, R. Osei)

- **Earned Premium** — daily pro-rata **365ths**. Authoritative for reserving,
  pricing and the SFCR narrative. Computed in `06_reserving_triangles.sas`
  from the *actuarial copy* of the policy master feed (CR-2014-311), not from
  the DWH. Finance report 1/12ths, billing recon reports 1/24ths; at year-end
  the three earned-premium figures differ by up to 1.8% by product.
- **Active Policy** — not used; actuarial work on exposure, not status flags.
- **Ultimate** — reported incurred x cumulative LDF x 1.05 tail (tail factor
  unchanged since the 2018 reserving review).
- **IBNR** — ultimate minus reported incurred, per `07_ibnr_projection.sas`.
- **Accident Year** — year of LOSS_DT (UK DD/MM/YYYY parse). Note the DWH
  Informatica path parses Guidewire loss dates as US-format (INC0067812), so
  DWH accident-year allocations differ from actuarial for day<=12 dates.
