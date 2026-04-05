# PostgreSQL 16 — runs as a launchd user agent (starts at login, runs as your user).
{ pkgs, lib, ... }:

{
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;

    # User-local data directory (no sudo needed).
    dataDir = "/Users/naresh/.local/share/postgresql/16";

    # Listen on localhost TCP (for GUI clients like DataGrip, Postico, etc.)
    enableTCPIP = true;

    # Trust all local connections — this is a dev machine, not production.
    authentication = lib.mkOverride 10 ''
      # TYPE  DATABASE  USER  ADDRESS       METHOD
      local   all       all                 trust
      host    all       all   127.0.0.1/32  trust
      host    all       all   ::1/128       trust
    '';

    # Tuned for analytical workloads (loading snapshots, running aggregations).
    settings = {
      work_mem = "256MB";
      log_min_duration_statement = 1000;
    };
  };
}
