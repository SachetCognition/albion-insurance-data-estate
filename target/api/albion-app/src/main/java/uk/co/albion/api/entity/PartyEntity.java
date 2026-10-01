package uk.co.albion.api.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.LocalDate;

/**
 * Canonical party record in the fresh domain store (mirrors dbt dim_party /
 * mart_policy_360 party columns). NINO is stored already masked (DQR-021):
 * an unmasked NINO never lands here.
 */
@Entity
@Table(name = "party")
public class PartyEntity {

    @Id
    @Column(name = "party_id")
    private String partyId;

    @Column(name = "first_name")
    private String firstName;

    @Column(name = "last_name")
    private String lastName;

    @Column(name = "date_of_birth")
    private LocalDate dateOfBirth;

    @Column(name = "nino_masked")
    private String ninoMasked;

    private String email;

    private String postcode;

    @Column(name = "legacy_client_no")
    private Long legacyClientNo;

    @Column(name = "apf_customer_id")
    private Long apfCustomerId;

    public String getPartyId() { return partyId; }
    public void setPartyId(String partyId) { this.partyId = partyId; }
    public String getFirstName() { return firstName; }
    public void setFirstName(String firstName) { this.firstName = firstName; }
    public String getLastName() { return lastName; }
    public void setLastName(String lastName) { this.lastName = lastName; }
    public LocalDate getDateOfBirth() { return dateOfBirth; }
    public void setDateOfBirth(LocalDate dateOfBirth) { this.dateOfBirth = dateOfBirth; }
    public String getNinoMasked() { return ninoMasked; }
    public void setNinoMasked(String ninoMasked) { this.ninoMasked = ninoMasked; }
    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }
    public String getPostcode() { return postcode; }
    public void setPostcode(String postcode) { this.postcode = postcode; }
    public Long getLegacyClientNo() { return legacyClientNo; }
    public void setLegacyClientNo(Long legacyClientNo) { this.legacyClientNo = legacyClientNo; }
    public Long getApfCustomerId() { return apfCustomerId; }
    public void setApfCustomerId(Long apfCustomerId) { this.apfCustomerId = apfCustomerId; }
}
