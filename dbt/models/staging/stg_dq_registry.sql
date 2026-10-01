select * from (values
    ('DQR-007', 'Email format valid'),
    ('DQR-014', 'UK postcode valid'),
    ('DQR-021', 'NINO masked in analytical stores'),
    ('DQR-030', 'Policy status domain'),
    ('DQR-033', 'Loss date not in future'),
    ('DQR-041', 'Party duplicate check'),
    ('DQR-052', 'Date century derivation consistent')
) as t(rule_id, rule_name)
