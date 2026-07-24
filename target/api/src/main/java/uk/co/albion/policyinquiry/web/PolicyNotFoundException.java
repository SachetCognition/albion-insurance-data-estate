package uk.co.albion.policyinquiry.web;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

@ResponseStatus(HttpStatus.NOT_FOUND)
public class PolicyNotFoundException extends RuntimeException {

    public PolicyNotFoundException(String policyNo) {
        super("Policy not found: " + policyNo);
    }
}
