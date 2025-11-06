{ python3Packages, python3 }:
python3Packages.buildPythonApplication {
  pname = "xnode-python-template";
  version = "1.0";

  format = "pyproject";

  propagatedBuildInputs = with python3.pkgs; [ setuptools ];

  src = ../python-app;

  meta = {
    mainProgram = "xnode-python-template";
  };
}
