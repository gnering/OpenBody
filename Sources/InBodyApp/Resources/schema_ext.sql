-- Extensoes do app InBodyMac ao esquema do LookinBody (schema.sql, gerado).
-- Aqui vai SO o que o banco original NAO tem (contrato global 5).
-- Tudo IF NOT EXISTS: aplicado na criacao e reaplicavel em migracao (contrato 4).

-- Conta de operador (login local). O original guarda isso fora do .mdb; no app
-- fica aqui. Senha por PBKDF2 (hash+salt+iteracoes), nunca texto claro.
CREATE TABLE IF NOT EXISTS CONTA_TBL (
    ID          TEXT PRIMARY KEY,
    SENHA_HASH  TEXT NOT NULL,
    SALT        TEXT NOT NULL,
    ITER        TEXT NOT NULL,
    EMAIL       TEXT,
    EH_PADRAO   TEXT
);

-- Idempotencia de reimporte (contrato 7): SPHYG_DATA_TBL e BLOODSUGAR_TBL nao tem
-- PK no original (so indice em LOCAL_ID). Sem isto, reimportar duplicaria leituras.
CREATE UNIQUE INDEX IF NOT EXISTS ux_sphyg      ON SPHYG_DATA_TBL (LOCAL_ID, DATETIMES);
CREATE UNIQUE INDEX IF NOT EXISTS ux_bloodsugar ON BLOODSUGAR_TBL  (LOCAL_ID, DATETIMES);

-- Indices de busca (E3): o original so indexa LOCAL_ID/USER_ID/COUNTRY_CODE. Os modos
-- nome/celular/grupo varrem colunas sem indice. Barato e ajuda quando a base cresce.
CREATE INDEX IF NOT EXISTS ix_user_name  ON USER_INFO1_TBL (NAME);
CREATE INDEX IF NOT EXISTS ix_user_telhp ON USER_INFO1_TBL (TEL_HP);
CREATE INDEX IF NOT EXISTS ix_usergroup_local ON USER_GROUP_TBL (LOCAL_ID);
CREATE INDEX IF NOT EXISTS ix_bca_local  ON BCA_TBL (LOCAL_ID);
