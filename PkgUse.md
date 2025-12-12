using Pkg; cd(s"C:\Julia\TensorLogic"); Pkg.activate(pwd()); 
Pkg.add(["OMEinsum", "NNlib", "LinearAlgebra", "Dictionaries"]);
cd(s"s"C:\Julia\TensorLogic\TensorLogic.jl\src");
include("TensorLogic.jl");
using TensorLogic;

