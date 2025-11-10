{ python3Packages, python3 }:
python3Packages.buildPythonApplication {
  pname = "miniapp-factory-imagegen";
  version = "1.0";

  format = "pyproject";

  propagatedBuildInputs = with python3.pkgs; [
    setuptools
    diffusers
    transformers
    torch
    accelerate
  ];

  src = ../python-app;

  meta = {
    mainProgram = "miniapp-factory-imagegen";
  };
}
