% Copyright (C) 2019, Jorge M. Perez Zerpa, J. Bruno Bazzano, Jean-Marc Battini, Joaquin Viera, Mauricio Vanzulli  
%
% This file is part of ONSAS.
%
% ONSAS is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% ONSAS is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with ONSAS.  If not, see <https://www.gnu.org/licenses/>.


% This script declares several matrices and vectors required for the analysis. In this script, the value of important magnitudes, such as internal forces, are computed for step/time 0.


tic ;

% ----------- fixeddofs and spring matrix computation ---------
fixeddofs = [] ;
KS      = sparse( 6*nnodes, 6*nnodes );  

for i=1:size(nodalSprings,1)
  aux = nodes2dofs ( nodalSprings (i,1) , 6 ) ;
  for k=1:6
    %
    if nodalSprings(i,k+1) == inf,
      fixeddofs = [ fixeddofs; aux(k) ] ;

    elseif nodalSprings(i,k+1) > 0,
      KS( aux(k), aux(k) ) = KS( aux(k), aux(k) ) + nodalSprings(i,k+1) ;

    end
  end
end

diridofs = fixeddofs ;
diridofs = unique( diridofs) ; % remove repeated dofs
%~ diridofs = [ diridofs ; releasesDofs] ;

neumdofs = zeros( 6*nnodes, 1 ) ;

for elem = 1:nelems
  
  aux = nodes2dofs( Conec( elem, 1:4), 6)' ;
  
  switch Conec( elem, 7)
  case 1
    neumdofs ( aux(1:2:11) ) = aux(1:2:11) ;
  case 2
    neumdofs ( aux(1:11) ) = aux(1:11) ;
  case 3
    neumdofs ( aux(1:2:(6*4-1) ) ) = aux(1:2:(6*4-1)) ;
  end  
end

neumdofs( diridofs ) = 0 ;

neumdofs = unique( neumdofs ) ;
if neumdofs(1) == 0,
  neumdofs(1)=[];
end
% -------------------------------------------------------------


loadFactors     = 0 ;
itersPerTime    = 0 ;
itersPerTimeVec = 0 ;
controlDisps    = 0 ;

timesVec = [ 0 ] ;

factorescriticos = [] ;

% create velocity and displacements vectors
Ut      = zeros( ndofpnode*nnodes,   1 ) ;  
Udott   = zeros( ndofpnode*nnodes,   1 ) ;  
Udotdott= zeros( ndofpnode*nnodes,   1 ) ;

if exist( 'nonHomogeneousInitialCondU0') ~=0
  for i=1:size(nonHomogeneousInitialCondU0,1)
    dofs= nodes2dofs(nonHomogeneousInitialCondU0(i,1),ndofpnode);
    Ut( dofs (nonHomogeneousInitialCondU0(i,2)))=nonHomogeneousInitialCondU0(i,3);
    
  end
end


if exist( 'nonHomogeneousInitialCondUdot0') ~=0 
  if dynamicAnalysisBoolean == 1
    for i=1:size(nonHomogeneousInitialCondUdot0,1)
       dofsdot= nodes2dofs(nonHomogeneousInitialCondUdot0(i,1),ndofpnode);
       Udott( dofsdot (nonHomogeneousInitialCondUdot0(i,2)))=nonHomogeneousInitialCondUdot0(i,3);
    end
  else
    error('Velocity initial conditions set for static analysis.');
  end
end


Utm1    = Ut ;  

Utp1    = zeros( ndofpnode*nnodes,   1 ) ;  

FintGt  = zeros( ndofpnode*nnodes,   1 ) ;  

matUts = Ut ;


dispsElemsMat = zeros(nelems,2*ndofpnode) ;
for i=1:nelems
  % obtains nodes and dofs of element
  nodeselem = Conec(i,1:2)' ;
  dofselem  = nodes2dofs( nodeselem , ndofpnode ) ;
  dispsElemsMat( i, : ) = Ut(dofselem)' ;
end

Stresst   = zeros(nelems,1) ;
Strainst  = zeros(nelems,1) ;
dsigdepst = zeros(nelems,1) ;

stopTimeIncrBoolean = 0 ;

currLoadFactor  = 0 ;
currTime        = 0 ;
timeIndex       = 1 ;
convDeltau      = zeros(nnodes*ndofpnode,1) ;

stopCritPar = 0;

loadFactors( timeIndex,1) = currLoadFactor ;
controlDisps(timeIndex,1) = Ut(controlDof)*controlDofFactor ;

[ FintGt, ~, Strainst, Stresst ] = assemblyFintVecTangMat ( Conec, secGeomProps, coordsElemsMat, hyperElasParamsMat, KS, Ut , bendStiff, 1 ) ;

factorCrit = 0 ;
factor_crit = 0 ;
nKeigpos   = 0 ;
nKeigneg   = 0 ;

if dynamicAnalysisBoolean == 0,
  nextLoadFactor  = currLoadFactor + targetLoadFactr / nLoadSteps ;

else 
  deltaT         = numericalMethodParams(2)        ;
  nextLoadFactor = loadFactorsFunc(currTime+deltaT);

end

systemDeltauMatrix = [];

% stores model data structures
modelCompress

indselems12 = find( ( Conec(:,7) == 1) | ( Conec(:,7) == 2) ) ;
Areas = secGeomProps(Conec(:,6),1) ;
currentNormalForces = modelCurrState.Stresst(:,1) .* Areas ;

matNts = currentNormalForces ;

tCallSolver = 0 ;
tStores = 0 ;
printsOutputScreen

tInitialDefs = toc ;
