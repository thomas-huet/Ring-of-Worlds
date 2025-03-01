CREATE TABLE users (
  email TEXT,
  username TEXT PRIMARY KEY,
  passhash TEXT,
  superuser BOOLEAN NOT NULL DEFAULT FALSE,
  contactable BOOLEAN NOT NULL DEFAULT FALSE,
  created TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE stats (
  user__username TEXT REFERENCES users UNIQUE,
  experience BIGINT DEFAULT 0
);

CREATE TABLE replays (
  id SERIAL PRIMARY KEY,
  replay TEXT,
  player_a__username TEXT REFERENCES users,
  player_b__username TEXT REFERENCES users,
  created TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE feedback (
  id SERIAL PRIMARY KEY,
  body TEXT,
  user__username TEXT REFERENCES users,
  created TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
