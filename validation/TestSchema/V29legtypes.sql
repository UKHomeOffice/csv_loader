CREATE TABLE legtypes (
  id INT4 NOT NULL PRIMARY KEY,
  description VARCHAR(60) NOT NULL,
  validfrom TIMESTAMP WITH TIME ZONE,
  validto TIMESTAMP WITH TIME ZONE
);

-- Table comment
COMMENT ON TABLE legtypes IS '{"description": "Mode of leg journey", "schemalastupdated": "06/03/2019", "dataversion": 1}';
-- Column comments
COMMENT ON COLUMN legtypes.id IS '{"label": "Identifier", "description": "Unique identifying column"}';
COMMENT ON COLUMN legtypes.description IS '{"label": "Description", "description": "Description of journey type"}';
COMMENT ON COLUMN legtypes.validfrom IS '{"label": "Valid from date", "description": "Item valid from date"}';
COMMENT ON COLUMN legtypes.validto IS '{"label": "Valid to date", "description": "Item valid to date"}';

-- GRANTs
GRANT SELECT ON legtypes TO ${anonuser};
GRANT SELECT ON legtypes TO ${serviceuser};
GRANT SELECT ON legtypes TO ${readonlyuser};
