CREATE TABLE IF NOT EXISTS cloud_projects (
    id uuid PRIMARY KEY,
    owner_id uuid NOT NULL,
    name text NOT NULL,
    revision integer NOT NULL CHECK (revision > 0),
    updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS cloud_projects_owner ON cloud_projects(owner_id);
CREATE TABLE IF NOT EXISTS cloud_revisions (
    project_id uuid NOT NULL REFERENCES cloud_projects(id) ON DELETE CASCADE,
    revision integer NOT NULL,
    sha256 text NOT NULL,
    content bytea NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (project_id, revision)
);
