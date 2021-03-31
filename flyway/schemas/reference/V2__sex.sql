CREATE TABLE sex (
  id SMALLINT NOT NULL PRIMARY KEY,
  name VARCHAR(20) NOT NULL,
  code VARCHAR(1) NOT NULL,
  validfrom TIMESTAMP WITH TIME ZONE,
  validto TIMESTAMP WITH TIME ZONE
);

-- Table comment
COMMENT ON TABLE sex IS '{"label": "Sex", "description": "Sex reference list.", "owner": "owner@example.com", "schemalastupdated": "03/12/2020", "dataversion": 1}';
-- Column comments
COMMENT ON COLUMN sex.id IS '{"label": "Identifier", "description": "Character unique identity reference.","aliases": "sexcharacter"}';
COMMENT ON COLUMN sex.name IS '{"label": "Name", "description": "The name of the sex."}';
COMMENT ON COLUMN sex.code IS '{"label": "Name", "description": "Short code / BusinessKey", "businesskey": "true"}';
COMMENT ON COLUMN sex.validfrom IS '{"label": "Valid from date", "description": "Item valid from date."}';
COMMENT ON COLUMN sex.validto IS '{"label": "Valid to date", "description": "Item valid to date."}';

-- MATERIALIZED VIEW
CREATE MATERIALIZED VIEW m_sex AS
SELECT * FROM sex
where (validfrom <= now()::date OR validfrom is null)
  AND (validto >= now()::date + interval '1d' OR validto is null);

CREATE UNIQUE INDEX ON m_sex (id);

-- GRANTs
GRANT SELECT ON sex TO ${anonuser};
GRANT SELECT,INSERT,UPDATE ON sex TO ${serviceuser};
GRANT SELECT ON sex TO ${readonlyuser};

-- VIEW GRANTs
GRANT SELECT,INSERT,UPDATE ON m_sex TO ${serviceuser};
GRANT SELECT ON m_sex TO ${readonlyuser};
GRANT SELECT ON m_sex TO ${anonuser};
