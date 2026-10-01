package uk.co.albion.api.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.LocalDate;

/** Canonical claim record (mirrors dbt dim_claim). Fraud flag is canonical Y/N. */
@Entity
@Table(name = "claim")
public class ClaimEntity {

    @Id
    @Column(name = "claim_no")
    private String claimNo;

    @Column(name = "policy_no")
    private String policyNo;

    @Column(name = "claimant_party_id")
    private String claimantPartyId;

    @Column(name = "loss_dt")
    private LocalDate lossDate;

    @Column(name = "notification_dt")
    private LocalDate notificationDate;

    @Column(name = "cause_cd")
    private String causeCd;

    @Column(name = "claim_status")
    private String claimStatus;

    @Column(name = "incurred_amt")
    private BigDecimal incurredAmt;

    @Column(name = "paid_amt")
    private BigDecimal paidAmt;

    @Column(name = "outstanding_reserve")
    private BigDecimal outstandingReserve;

    @Column(name = "fraud_flag")
    private String fraudFlag;

    public String getClaimNo() { return claimNo; }
    public void setClaimNo(String claimNo) { this.claimNo = claimNo; }
    public String getPolicyNo() { return policyNo; }
    public void setPolicyNo(String policyNo) { this.policyNo = policyNo; }
    public String getClaimantPartyId() { return claimantPartyId; }
    public void setClaimantPartyId(String claimantPartyId) { this.claimantPartyId = claimantPartyId; }
    public LocalDate getLossDate() { return lossDate; }
    public void setLossDate(LocalDate lossDate) { this.lossDate = lossDate; }
    public LocalDate getNotificationDate() { return notificationDate; }
    public void setNotificationDate(LocalDate notificationDate) { this.notificationDate = notificationDate; }
    public String getCauseCd() { return causeCd; }
    public void setCauseCd(String causeCd) { this.causeCd = causeCd; }
    public String getClaimStatus() { return claimStatus; }
    public void setClaimStatus(String claimStatus) { this.claimStatus = claimStatus; }
    public BigDecimal getIncurredAmt() { return incurredAmt; }
    public void setIncurredAmt(BigDecimal incurredAmt) { this.incurredAmt = incurredAmt; }
    public BigDecimal getPaidAmt() { return paidAmt; }
    public void setPaidAmt(BigDecimal paidAmt) { this.paidAmt = paidAmt; }
    public BigDecimal getOutstandingReserve() { return outstandingReserve; }
    public void setOutstandingReserve(BigDecimal outstandingReserve) { this.outstandingReserve = outstandingReserve; }
    public String getFraudFlag() { return fraudFlag; }
    public void setFraudFlag(String fraudFlag) { this.fraudFlag = fraudFlag; }
}
