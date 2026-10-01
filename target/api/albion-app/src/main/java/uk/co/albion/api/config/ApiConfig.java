package uk.co.albion.api.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.info.Info;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import uk.co.albion.domain.PolicyNumberNormalizer;

@Configuration
public class ApiConfig {

    /** Single shared normalisation component (see {@link PolicyNumberNormalizer}). */
    @Bean
    public PolicyNumberNormalizer policyNumberNormalizer() {
        return new PolicyNumberNormalizer();
    }

    @Bean
    public OpenAPI albionOpenApi() {
        return new OpenAPI().info(new Info()
                .title("Albion Policy/Party/Claim API")
                .version("1.0.0")
                .description("""
                        Target-state REST/JSON replacement for the frozen SOAP
                        PolicyInquiryService (api_legacy/soap/PolicyInquiryService.wsdl)
                        and its Oracle backend (api_legacy/plsql/pkg_policy_inquiry.sql).

                        Key contract changes vs the legacy rpc/encoded SOAP service:
                        * the overloaded 'customerRef' string is replaced by a typed
                          PartyIdentifier (party_id + explicit source scheme);
                        * dates are ISO-8601, not DD/MM/YYYY text;
                        * a single canonical active_policy_flag (with labelled variants);
                        * reads a fresh canonical domain store (dbt marts), not the
                          26h-stale ODS.""")
                .contact(new Contact().name("Albion Data Platform")));
    }
}
