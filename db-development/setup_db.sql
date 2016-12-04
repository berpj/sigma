DROP DATABASE if exists search_engine;

CREATE DATABASE search_engine owner postgres;
\connect search_engine

CREATE TABLE repository(
  doc_id bigserial,
  url text,
  content text
);
CREATE INDEX repository_doc_id ON repository USING btree (doc_id);

CREATE TABLE errors(
  doc_id bigserial,
  url text,
  error integer,
  details text
);
CREATE INDEX errors_doc_id_from ON errors USING btree (doc_id);

CREATE TABLE doc_index (
  doc_id bigserial primary key,
  url text,
  title text,
  outgoing_links  integer,
  status varchar(4),
  parsed_at integer,
  sent_to_crawler_at integer
);
