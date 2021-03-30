CREATE TABLE gender (
  id INTEGER NOT NULL PRIMARY KEY,
  gender VARCHAR(20) NOT NULL UNIQUE,
  code SMALLINT NOT NULL,
  validfrom TIMESTAMP WITH TIME ZONE,
  validto TIMESTAMP WITH TIME ZONE
);

-- Table comment
COMMENT ON TABLE gender IS '{"label": "Gender", "description": "A list of current groups on the gender spectrum.", "owner": "owner@example.com", "schemalastupdated": "03/12/2020", "dataversion": 1}';
-- Column comments
COMMENT ON COLUMN gender.id IS '{"label": "Identifier", "description": "Database unique identity record."}';
COMMENT ON COLUMN gender.gender IS '{"label": "Gender", "description": "The name of the gender."}';
COMMENT ON COLUMN gender.code IS '{"label": "Name", "description": "Short code / BusinessKey", "businesskey": "true"}';
COMMENT ON COLUMN gender.validfrom IS '{"label": "Valid from date", "description": "Item valid from date."}';
COMMENT ON COLUMN gender.validto IS '{"label": "Valid to date", "description": "Item valid to date."}';

-- GRANTs
GRANT SELECT ON gender TO ${anonuser};
GRANT SELECT,INSERT,UPDATE ON gender TO ${serviceuser};
GRANT SELECT ON gender TO ${readonlyuser};
