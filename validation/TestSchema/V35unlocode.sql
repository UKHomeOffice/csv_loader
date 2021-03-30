CREATE TABLE unlocode (
  id UUID NOT NULL PRIMARY KEY,
  iso31661alpha2 VARCHAR(2) NULL,
  geolong NUMERIC,
  geolat NUMERIC,
  name VARCHAR(80) NOT NULL,
  namewodiacritics VARCHAR(80) NOT NULL,
  iata VARCHAR(3),
  locode VARCHAR(3) NOT NULL,
  seaport BOOLEAN NOT NULL,
  railterminal BOOLEAN NOT NULL,
  airport BOOLEAN NOT NULL,
  postexchange BOOLEAN NOT NULL,
  multimodal BOOLEAN NOT NULL,
  fixedtransport BOOLEAN NOT NULL,
  bordercrossing BOOLEAN NOT NULL,
  subdivision VARCHAR(3),
  roadterminal BOOLEAN NOT NULL,
  countryid INTEGER NULL REFERENCES country(id),
  validfrom TIMESTAMP WITH TIME ZONE,
  validto TIMESTAMP WITH TIME ZONE
);

-- Table comment
COMMENT ON TABLE unlocode IS '{"description": "United Nations location code list", "schemalastupdated": "06/03/2019", "dataversion": 1}';
-- Column comments
COMMENT ON COLUMN unlocode.id IS '{"label": "Identifier", "description": "Unique identifying column"}';
COMMENT ON COLUMN unlocode.name IS '{"label": "Name", "description": "Location name"}';
COMMENT ON COLUMN unlocode.geolat IS '{"label": "Latitude", "description": "Geographic latitude"}';
COMMENT ON COLUMN unlocode.geolong IS '{"label": "Longitude", "description": "Geographic longitude"}';
COMMENT ON COLUMN unlocode.namewodiacritics IS '{"label": "Name with diacritics", "description": "Location name including diacritics"}';
COMMENT ON COLUMN unlocode.iata IS '{"label": "IATA", "description": "IATA code"}';
COMMENT ON COLUMN unlocode.locode IS '{"label": "Locode", "description": "Location code"}';
COMMENT ON COLUMN unlocode.seaport IS '{"label": "Sea port", "description": "Is an sea port?"}';
COMMENT ON COLUMN unlocode.railterminal IS '{"label": "Rail terminal", "description": "Is an rail terminal?"}';
COMMENT ON COLUMN unlocode.airport IS '{"label": "Airport", "description": "Is an airport?"}';
COMMENT ON COLUMN unlocode.postexchange IS '{"label": "Post exchanget", "description": "Is an postal exchange?"}';
COMMENT ON COLUMN unlocode.multimodal IS '{"label": "Multi modal", "description": "Is multi modal?"}';
COMMENT ON COLUMN unlocode.fixedtransport IS '{"label": "Fixed transport", "description": "Is a fixed transport point?"}';
COMMENT ON COLUMN unlocode.bordercrossing IS '{"label": "Border crossing", "description": "Is a border crossing point?"}';
COMMENT ON COLUMN unlocode.subdivision IS '{"label": "County", "description": "Area of port", "aliases": "region"}';
COMMENT ON COLUMN unlocode.roadterminal IS '{"label": "Road terminal", "description": "Is a road terminal?"}';
COMMENT ON COLUMN unlocode.countryid IS '{"label": "Linked country id", "description": "Country link to Country dataset"}';
COMMENT ON COLUMN unlocode.validfrom IS '{"label": "Valid from date", "description": "Item valid from date"}';
COMMENT ON COLUMN unlocode.validto IS '{"label": "Valid to date", "description": "Item valid to date"}';
COMMENT ON COLUMN unlocode.iso31661alpha2 IS '{"label": "2 digit alpha code", "description": "Country 2 Character alpha code"}';

-- GRANTs
GRANT SELECT ON tdaapprovalstatus TO ${anonuser};
GRANT SELECT ON unlocode TO ${serviceuser};
GRANT SELECT ON unlocode TO ${readonlyuser};
