{ buildNpmPackage, fetchurl, lib }:

buildNpmPackage rec {
  pname = "context-mode";
  version = "1.0.103";

  src = fetchurl {
    url = "https://registry.npmjs.org/context-mode/-/context-mode-${version}.tgz";
    hash = "sha256-/oKIXsc2YL8uxhp6G9pK4+Jj5jzmjkP04/S/Y3ER1hU=";
  };

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-6ekYzKPJUZwVJL30t6ZvMTgthyL+KODf98uI7QdDdCY=";
  dontNpmBuild = true;
  npmInstallFlags = [ "--ignore-scripts" ];
  npmPackFlags = [ "--ignore-scripts" ];

  meta = {
    description = "Pi package for context-mode context engineering tools";
    homepage = "https://www.npmjs.com/package/context-mode";
    license = lib.licenses.mit;
  };
}
