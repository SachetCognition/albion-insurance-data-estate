package uk.co.albion.api.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.LocalDate;

/** Canonical policy record (mirrors dbt mart_policy_360). POLICY_NO is stored canonical. */
@Entity
@Table(name = "policy")
public class PolicyEntity {

    @Id
    @Column(name = "policy_no")
    private String policyNo;

    @Column(name = "party_id")
    private String partyId;

    @Column(name = "product_cd")
    private String productCd;

    @Column(name = "product_name")
    private String productName;

    @Column(name = "broker_id")
    private String brokerId;

    private String channel;

    @Column(name = "inception_dt")
    private LocalDate inceptionDate;

    @Column(name = "expiry_dt")
    private LocalDate expiryDate;

    @Column(name = "policy_status")
    private String policyStatus;

    @Column(name = "annual_premium_gbp")
    private BigDecimal annualPremiumGbp;

    @Column(name = "ipt_rate")
    private BigDecimal iptRate;

    @Column(name = "payment_plan")
    private String paymentPlan;

    @Column(name = "uw_year")
    private Integer uwYear;

    @Column(name = "source_system")
    private String sourceSystem;

    @Column(name = "active_uw")
    private boolean activeUw;

    @Column(name = "active_finance")
    private boolean activeFinance;

    @Column(name = "active_claims")
    private boolean activeClaims;

    @Column(name = "active_policy_flag")
    private boolean activePolicyFlag;

    public String getPolicyNo() { return policyNo; }
    public void setPolicyNo(String policyNo) { this.policyNo = policyNo; }
    public String getPartyId() { return partyId; }
    public void setPartyId(String partyId) { this.partyId = partyId; }
    public String getProductCd() { return productCd; }
    public void setProductCd(String productCd) { this.productCd = productCd; }
    public String getProductName() { return productName; }
    public void setProductName(String productName) { this.productName = productName; }
    public String getBrokerId() { return brokerId; }
    public void setBrokerId(String brokerId) { this.brokerId = brokerId; }
    public String getChannel() { return channel; }
    public void setChannel(String channel) { this.channel = channel; }
    public LocalDate getInceptionDate() { return inceptionDate; }
    public void setInceptionDate(LocalDate inceptionDate) { this.inceptionDate = inceptionDate; }
    public LocalDate getExpiryDate() { return expiryDate; }
    public void setExpiryDate(LocalDate expiryDate) { this.expiryDate = expiryDate; }
    public String getPolicyStatus() { return policyStatus; }
    public void setPolicyStatus(String policyStatus) { this.policyStatus = policyStatus; }
    public BigDecimal getAnnualPremiumGbp() { return annualPremiumGbp; }
    public void setAnnualPremiumGbp(BigDecimal annualPremiumGbp) { this.annualPremiumGbp = annualPremiumGbp; }
    public BigDecimal getIptRate() { return iptRate; }
    public void setIptRate(BigDecimal iptRate) { this.iptRate = iptRate; }
    public String getPaymentPlan() { return paymentPlan; }
    public void setPaymentPlan(String paymentPlan) { this.paymentPlan = paymentPlan; }
    public Integer getUwYear() { return uwYear; }
    public void setUwYear(Integer uwYear) { this.uwYear = uwYear; }
    public String getSourceSystem() { return sourceSystem; }
    public void setSourceSystem(String sourceSystem) { this.sourceSystem = sourceSystem; }
    public boolean isActiveUw() { return activeUw; }
    public void setActiveUw(boolean activeUw) { this.activeUw = activeUw; }
    public boolean isActiveFinance() { return activeFinance; }
    public void setActiveFinance(boolean activeFinance) { this.activeFinance = activeFinance; }
    public boolean isActiveClaims() { return activeClaims; }
    public void setActiveClaims(boolean activeClaims) { this.activeClaims = activeClaims; }
    public boolean isActivePolicyFlag() { return activePolicyFlag; }
    public void setActivePolicyFlag(boolean activePolicyFlag) { this.activePolicyFlag = activePolicyFlag; }
}
